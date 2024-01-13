# cmdline highligher
Highlight your cmdline!!  
![preview/preview1](preview/preview1.png)  
![preview/preview2](preview/preview2.png)  
![preview/preview3](preview/preview3.png)  
NOTE: This is still in development things like custom commands don't work with `:help :bar` or ranges with `:help :bar`.
Tbh i made this plugin just because i didn't know how to access treesitter in the c code for neovim and nvim_parse_cmd isn't enough, Also just wanted to find a good use-case of `vim.ui_attach` noice has a ton of flickering.
## Installation
```lua
return {
    {
        'Sam-programs/cmdline-hl.nvim',
        event = 'VimEnter',
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
            -- custom prefixes for builtin-commands
            type_signs = {
                [":"] = { " ", "FloatFooter" },
                ["/"] = { " ", "FloatFooter" },
                ["?"] = { " ", "FloatFooter" },
                ["="] = { " ", "FloatFooter" },
            },
            -- custom formatting/highlight for commands
            custom_types = {
                -- ["command-name"] = {
                -- [icon],[icon_hl], default to `:` icon and highlight
                -- [lang], defaults to vim
                -- [showcmd], defaults to false
                -- [pat], defaults to "%w*%s*(.*)"
                -- [code], defaults to nil
                -- }
                -- lang is the treesitter language to use for the commands
                -- showcmd is true if the command should be displayed or to only show the icon
                -- pat is used to extract the part of the command that needs highlighting
                -- the part is matched against the raw command you don't need to worry about ranges
                -- e.g. in 's,>'s/foo/bar/
                -- pat is checked against s/foo/bar
                -- you could also use the 'code' function to extract the part that needs highlighting
                ["lua"] = { icon = " ", icon_hl = "FloatFooter", lang = "lua" },
                ["help"] = { icon = "? ", icon_hl = "FloatFooter"},
                ["substitute"] = { pat = "%w(.*)", lang = "regex", show_cmd = true },
            },
            input_hl = "FloatFooter",
            -- used to highlight the range in the command e.g. '<,>' in '<,>'s
            range_hl = "FloatBorder",
        }
    }
}
```
You might want to change input_hl to something else because some colorschemes don't define FloatFooter for nvim 0.9.5.
## How it works
This uses a hacky method to display colors in the cmdline with `nvim_echo`.

## Known issues
Since this uses messages if something echos anything the command-line will disappear, But that's unlikely to happen while editing the command-line, 
I still made a function `disable_msgs` to disable messages in the command-line you can call it with `require('cmdline-hl').disable_msgs()` make sure to call it before your notification plugin loads if you have any.

The Press-Enter prompt appears incorrectly when using multiptle commands e.g. `:ls<cr>:ls` you could fix it by pressing space once u see the prompt.

Errors in nested command-lines will still render the command-line, e.g. `:<C-r>=f<cr>` raises an error the plugin will keep rendering the cmdline until the user exits the command-line,  
When the Press-Enter bug happens this issue is fixed.

