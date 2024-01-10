# cmdline highligher
Highlight your cmdline!!
![preview/preview1](preview/preview1.png)
![preview/preview2](preview/preview2.png)
![preview/preview3](preview/preview3.png)
![preview/preview4](preview/preview4.png)
## Installation
```lua
return {
    {
        'Sam-programs/cmdline-hl.nvim',
        event = 'UiEnter',
        opts = {}
    }
}
```
Default config:
```lua
return {
    {
        'Sam-programs/cmdline-hl.nvim',
        event = 'UiEnter',
        opts = {
            -- table used for prefixes
            type_signs = {
                [":"] = { " ", "FloatFooter" },
                ["/"] = { " ", "FloatFooter" },
                ["?"] = { " ", "FloatFooter" },
                ["="] = { " ", "FloatFooter" },
            },
            -- convert vim syntax highlight to treesitter highlights
            convert_hls = true,
            -- highlight used for vim.input
            input_hl = "FloatFooter",
        }
    }
}
```
You might want to change input_hl to something else because some colorschemes don't define FloatFooter for nvim 0.9.5.
## How it works
This uses a hacky method to display colors in the cmdline with `nvim_echo`, Also uses vim's syntax highlighting because i couldn't get treesitter to work in hidden buffers.

## Known issues
Since this uses messages if something echos anything the command-line will disappear, But that's unlikely to happen while editing the command-line, 
I still made a function `disable_msgs` to disable messages in the command-line you can call it with `require('cmdline-hl).disable_msgs()` make sure to call it before your notification plugin loads if you have any.

The Press-Enter prompt appears incorrectly when using multiptle commands e.g. `:ls<cr>:ls` you could fix it by pressing space once u see the prompt.

Errors in nested command-lines will still render the command-line, e.g. `:<C-r>=f<cr>` raises an error the plugin will keep rendering the cmdline until the user exits the command-line,  
When the Press-Enter bug happens this issue is fixed.

