M = {}

local helper_file = function(file)
    local curr_file = debug.getinfo(1).source:gsub("^@", "")
    local pkg_dir = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(curr_file)))
    local path = vim.fs.joinpath(pkg_dir, "helpers", file)
    if vim.fn.filereadable(path) == 0 then
        error("Can't find helper file " .. path)
    end
    return path
end

---@class ArkConfig
---The startup file to use with R. Set this to `false` if you don't want to use
---a startup file. The default `true` will use ark.nvim's startup file, which
---sets the following options:
---``` R
---options(cli.default_num_colors = 256L)
---options(cli.hyperlink = TRUE)
---```
---@field r_startup_file? string | boolean
---
---A log file to be used by Ark, or `true` to use one chosen by ark.nvim.
---@field log_file? string | boolean
---
---Extra command line arguments passed to ark, as a single string. Run
---`ark --help` to see the full list of available options. Note: you shouldn't
---use the `--startup-file` or `--log` arguments here.
---@field ark_args? string
---
---The command to use to start Python.
---@field python_cmd? string
---
---If `true`, Ark will automatically be started (in a hidden buffer) and the
---LSP attached when opening an R file.
---@field auto_start? boolean
local config = {
    r_startup_file = true,
    log_file = true,
    ark_args = "",
    python_cmd = "python3",
    auto_start = true,
}

M.setup = function(cfg)
    config = vim.tbl_extend("force", config, cfg)
    vim.validate({
        r_startup_file = { config.r_startup_file, { "string", "boolean" } },
        ark_args = { config.ark_args, "string" },
        python_cmd = { config.python_cmd, "string" }
    })

    if config.r_startup_file == true then
        config.r_startup_file = helper_file("startup.R")
    end

    if config.log_file == true then
        config.log_file = vim.fn.tempname() .. "ark.log"
    end

    vim.api.nvim_create_user_command("ArkStartKernel", function() M.start_kernel() end, {})
    vim.api.nvim_create_user_command("ArkOpen", function() M.open() end, {})
    vim.api.nvim_create_user_command("ArkKill", function() M.kill() end, {})
    vim.api.nvim_create_user_command("ArkRestart", function() M.restart() end, {})

    if config.auto_start then
        vim.api.nvim_create_autocmd("BufEnter", {
            pattern = "*.R",
            group = vim.api.nvim_create_augroup("ark", {}),
            callback = function() M.start_lsp() end,
        })
    end
end

M.process = { channel = nil, lsp_port = nil, client_id = nil, buf = -1, win = -1 }

local get_available_port = function()
    vim.print(helper_file("get-available-port.py"))
    local cmd = { config.python_cmd, helper_file("get-available-port.py") }
    local res = vim.system(cmd, { text = true }):wait().stdout
    return tonumber(vim.fn.trim(res))
end

M.is_running = function()
    return M.process.channel ~= nil
end

M.start_kernel = function()
    if M.is_running() then
        print("Ark is already running. Use :ArkOpen to open the current process")
        vim.fn.getchar()
        return
    end

    M.process.lsp_port = get_available_port()
    vim.print({port = M.process.lsp_port})
    M.process.buf = vim.api.nvim_create_buf(false, false)

    vim.api.nvim_buf_call(M.process.buf, function()
        M.process.channel = vim.fn.termopen(
            config.python_cmd .. " " .. helper_file("run-ark.py") .. " "
            -- NB, this isn't an _Ark_ cmdline option, it's pulled from the
            -- list and used differently in the Python script
            .. "--lsp-channel=127.0.0.1:" .. M.process.lsp_port .. " "
            .. "--log " .. config.log_file .. " "
            .. "--startup-file " .. config.r_startup_file .. " "
            .. config.ark_args
        )
    end)
    vim.api.nvim_create_autocmd("ExitPre", {
        group = vim.api.nvim_create_augroup("ark", {}),
        callback = function() M.kill(true) end,
    })
end

M.start_lsp = function()
    local defer = 0
    if not M.is_running() then
        M.start_kernel()
        -- Need to give the kernel a chance to start the server. Yes, ideally
        -- we should just wait until it's done, but this is a POC plugin so I
        -- don't give a hoot.
        defer = 3000
    end
    vim.defer_fn(function()
        M.process.client_id = vim.lsp.start({
            cmd = vim.lsp.rpc.connect("127.0.0.1", M.process.lsp_port),
            name = "ark",
            filetypes = { "r" },
            root_dir = vim.fs.root(0, { ".git", ".Rproj" })
        })
    end, defer)
end

---@param opts? table Passed to |nvim_open_win()|
M.open = function(opts)
    if not M.is_running() then
        M.start_kernel()
    end

    opts = vim.tbl_extend("keep", opts or {}, {
        split = "right",
        width = math.floor(vim.api.nvim_win_get_width(0) / 2)
    })

    if not vim.api.nvim_win_is_valid(M.process.win) then
        M.process.win = vim.api.nvim_open_win(M.process.buf, true, opts)
        vim.wo[M.process.win].number = false
        vim.wo[M.process.win].relativenumber = false
    end
end

M.kill = function(job_only)
    if M.is_running() then
        local ctrlc_termcode = "\3"
        vim.fn.chansend(M.process.channel, { ctrlc_termcode, "", "quit()", "" })
        pcall(vim.fn.jobstop, M.process.channel)
    end
    if vim.api.nvim_win_is_valid(M.process.win) and not job_only then
        vim.api.nvim_win_close(M.process.win, true)
    end
    if vim.api.nvim_buf_is_valid(M.process.buf) and not job_only then
        vim.api.nvim_buf_delete(M.process.buf, { force = true })
    end
    vim.lsp.stop_client(M.process.client_id, true)
    M.process = { buf = -1, win = -1 }
end

M.restart = function()
    M.kill()
    M.open()
end

---@param lines string | string[] Code to send to Ark. If this is a string,
---  append `\n` to execute the code. If a table, append `""` to execute the
---  code.
M.execute = function(lines)
    if not M.is_running() then
        print("Ark is not running - use :ArkOpen to start Ark.")
        return
    end
    vim.fn.chansend(M.process.channel, lines)
end

return M
