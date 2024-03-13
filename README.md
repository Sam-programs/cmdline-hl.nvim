# cmdline highligher
Highlight your cmdline!!  
![preview/preview1](preview/preview1.png)  
![preview/preview2](preview/preview2.png)  
![preview/preview3](preview/preview3.png)  
![preview/preview4](preview/preview4.png)  
## Installation
Requires:   
treesitter `regex` parser  
nvim-0.9.0+
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
        event = 'VimEnter',
        config = function()
            local cmdline_hl = require('cmdline-hl')
            cmdline_hl.setup({
                -- custom prefixes for builtin-commands
                type_signs = {
                    [":"] = { " ", "Title" },
                    ["/"] = { " ", "Title" },
                    ["?"] = { " ", "Title" },
                    ["="] = { " ", "Title" },
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
                    -- e.g. in '<,>'s/foo/bar/
                    -- pat is checked against s/foo/bar
                    -- you could also use the 'code' function to extract the part that needs highlighting
                    ["lua"] = {
                        pat = "lua[%s=](.*)",
                        icon = " ",
                        lang = "lua",
                    },
                    ["Exec"] = {
                        icon = "!",
                        lang = "bash",
                        show_cmd = false,
                    },
                    ["="] = { pat = "=(.*)", lang = "lua", show_cmd = true },
                    ["help"] = { icon = "? " },
                    ["substitute"] = { pat = "%w(.*)", lang = "regex", show_cmd = true },
                    --["lua"] = false, -- set an option  to false to disable it
                },
                aliases = {
                    -- str is unmapped keys do with that knowledge what you will
                    -- read aliases.md for examples
                    -- ["cd"] = { str = "Cd" },
                },
                -- vim.ui.input() vim.fn.input etc
                input_hl = "Title",
                -- you can use this to format input like the type_signs table
                input_format = function(input) return input end,
                -- used to highlight the range in the command e.g. '<,>' in '<,>'s
                range_hl = "Constant",
                ghost_text = true,
                ghost_text_hl = "Comment",
                inline_ghost_text = false,
                -- history works like zsh-autosuggest you can complete it by pressing <up>
                ghost_text_provider = require("cmdline-hl.ghost_text").history,
                -- you can also use this to get the wildmenu(default completion)'s suggestion
                -- ghost_text_provider = require("cmdline-hl.ghost_text").history,
                })
        end
    }
}
```
## Aliasing
You can alias builtin commands you can read [aliases.md](/aliases.md) for examples.

## Known issues
Since this uses messages if something echos anything the command-line will disappear, But that's unlikely to happen while editing the command-line, 
I still made a function `disable_msgs` to disable messages in the command-line you can call it with `require('cmdline-hl').disable_msgs()` make sure to call it before your notification plugin loads if you have any.

~~The Press-Enter prompt appears incorrectly when using multiptle commands e.g. `:ls<cr>:ls` you could fix it by pressing space once u see the prompt.~~
🔨 got fixed by some sort of side effect? (this is why you should make good git commits)

Errors in nested command-lines will still render the command-line, e.g. `:<C-r>=f<cr>` raises an error the plugin will keep rendering the cmdline until the user exits the command-line,  
When the Press-Enter bug happens this issue is fixed.
