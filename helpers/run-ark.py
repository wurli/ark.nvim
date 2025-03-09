import asyncio
import sys

import jupyter_client
import jupyter_console.ptshell as shell
from pygments.token import Token

ark_extra_args = []
lsp_channel = "127.0.0.1:0"
for s in sys.argv[1:]:
    if s.startswith("--lsp-channel="):
        lsp_channel = s.removeprefix("--lsp-channel=")
    else:
        ark_extra_args.append(s)

kernel_manager = jupyter_client.KernelManager(kernel_name = "ark")
kernel_manager.start_kernel(extra_arguments = ark_extra_args)

client = kernel_manager.client()
client.start_channels()
client.wait_for_ready(timeout = 10)

# Tell Ark to start the LSP on the given channel
client.shell_channel.send(client.session.msg("comm_open", {
    "target_name": "positron.lsp",
    "comm_id": "lsp",
    "data": { "client_address": lsp_channel }
}))

# Set a prompt which feels a bit more like R
class RConsole(shell.ZMQTerminalInteractiveShell):
    def get_prompt_tokens(self, ec = None):
        return [(Token.Prompt, "> ")]
    def get_continuation_tokens(self, width):
        return [(Token.Prompt, "+ ")]
    def get_out_prompt_tokens(self):
        return [(Token.OutPrompt, "")]

# Start the console
console = RConsole(client = client)
asyncio.run(console.interact())

