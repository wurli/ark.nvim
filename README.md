# ark.nvim

![demo](https://github.com/user-attachments/assets/f78dc9f9-da78-40eb-aad8-e63d1cccb9f5)

This is a _very_ basic proof-of-concept plugin which lets you use Neovim with R
via the [Ark Jupyter kernel](https://github.com/posit-dev/ark). In particular,
this plugin lets you communicate with Ark via Neovim's built-in terminal, and
also benefit from Ark's lovely LSP server which updates to reflect the packages
and objects loaded in your R session.

## Prerequisites

You'll need to have Ark installed as a Jupyter kernel. Ark provides some
[documentation](https://github.com/posit-dev/ark) on how to do this.

You'll need to have a Python installation with the `jupyter_client` and
`jupyter_console` libraries installed. Sorry for this.

You'll need to have R installed somewhere Ark can find it. If Ark fails to
locate your R installation you should be able to fix this by setting your
`R_HOME` environmental variable.

## Installation

Using lazy.nvim:
``` lua
{
    "wurli/ark.nvim",
    dependencies = { "blink.cmp" }, -- or "nvim-cmp"
    config = function()
        require("ark").setup({
            -- Or for nvim-cmp:
            -- lsp_capabilities = require("cmp_nvim_lsp").default_capabilities()
            lsp_capabilities = require('blink.cmp').get_lsp_capabilities(),
        })
    end
}
```

## Configuration

```` lua
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
---
---You should adjust this depending on the completion engine you use. E.g.
---`require("cmp_nvim_lsp").default_capabilities()` or
---`require('blink.cmp').get_lsp_capabilities()`.
---@field lsp_capabilities? table
local config = {
    r_startup_file = true,
    log_file = true,
    ark_args = "",
    python_cmd = "python3",
    auto_start = true,
    lsp_capabilities = nil,
}
````

## API

<table>
    <tr>
        <td>Vim</td>
        <td>Lua</td>
        <td>Description</td>
    </tr>
    <tr>
        <td>`:ArkOpen`</td>
        <td>`require("ark").open()`</td>
        <td>Start the Ark kernel and open the R console.</td>
    </tr>
    <tr>
        <td>`:ArkStartKernel`</td>
        <td>`require("ark").start_kernel()`</td>
        <td>Start the Ark kernel without opening the R console.</td>
    </tr>
    <tr>
        <td>`:ArkStartLsp`</td>
        <td>`require("ark").start_lsp()`</td>
        <td>Start the Ark kernel and attach an LSP client.</td>
    </tr>
    <tr>
        <td>`:ArkKill`</td>
        <td>`require("ark").kill(job_only)`</td>
        <td>
            Quit Ark.
            *   `job_only`: Defaults to `false`; if `true` then the
                buffer/window used for the R console will be left open.
        </td>
    </tr>
    <tr>
        <td>`:ArkRestart`</td>
        <td>`require("ark").restart()`</td>
        <td>
            A convenience function to any Ark session which is already running
            and start another one if things get messed up.
        </td>
    </tr>
    <tr>
        <td></td>
        <td>`require("ark").is_running()`</td>
        <td>Detect whether there is an Ark/R session in use</td>
    </tr>
    <tr>
        <td></td>
        <td>`require("ark").execute_lines(data)`</td>
        <td>
            Send some code to the console. Note that this works even if the
            console isn't visible.

            *   `data`: Code to send. If a string, append `\n` to actually
                execute the code. If a table, append `""` to actually
                execute the code.
        </td>
    </tr>
    <tr>
        <td></td>
        <td>`require("ark").execute_current()`</td>
        <td>
            Sends code from the current R script to the console:

            * In visual mode, sends the current selection
            * In normal more, sends the current expression

            This isn't bound to a keymap by default, but you can easily do so
            yourself, e.g. using

            ``` lua
            vim.api.nvim_create_autocmd("BufEnter", {
                pattern = "*.R",
                callback = function()
                    vim.keymap.set(
                        { "n", "v" }, "<Enter>",
                        require("ark").execute_current,
                        { buffer = 0, desc = "Send code to the R console" }
                    )
                end
            })
            ```

        </td>
    </tr>
</table>


## Troubleshooting

1.  Make sure Ark is running properly in Positron. If not, you probably have
    bigger fish to fry. On an M1 Macbook I found I needed to make sure I was
    using an arm64 R installation for Ark to start correctly.

2.  Make sure your Python environment is set up. My (working) environment is
    defined by [helpers/requirements.txt](/helpers/requirements.txt), and I'm
    using Python 3.12.7.

3.  After this I'm afraid you're probably pretty much on your own. Good luck!

## Limitations

MANY. This plugin is currently pre-alpha, proof-of-concept, and amounts to
little more than a thin wrapper for a few lines of Python. I'm currently
rewriting this plugin with a more sophisticated architecture; until then please
feel free to test it, but if you discover any issues you'd like to be fixed,
please submit a PR rather than an issue.

Some significant issues that highlight just how proof-of-concept this plugin
really is:

*   Plots (probably the best bit of R) don't work interactively. This is
    because Ark communicates with Positron about plots using a home-grown
    system which would be some work to reimplement in Neovim. I'm up for this,
    but not before rewriting the plugin.

*   No debugger for the same reasons.

*   You can't turn off syntax highlighting in the console input text. Some might
    like this but I'm not sure I do.

*   Etc.

## See also

*   [R.nvim](https://github.com/R-nvim/R.nvim) for an actually usable R plugin

*   [Ark](https://github.com/posit-dev/ark)

*   [Positron](https://github.com/posit-dev/positron)

