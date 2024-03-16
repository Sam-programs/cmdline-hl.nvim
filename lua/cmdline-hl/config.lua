local M = {}

local config = {
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
            icon = " ",
            lang = "lua",
            show_cmd = true
        },
        ["="] = { pat = "=(.*)", lang = "lua", show_cmd = true },
        ["help"] = { icon = "? " },
        ["substitute"] = { lang = "regex", show_cmd = true },
        --["lua"] = false, -- set an option  to false to disable it
    },
    aliases = {
        -- str is unmapped keys do with that knowledge what you will
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
}

function M.set(new_config)
    new_config = vim.tbl_deep_extend("force", config, new_config or {})
    -- write to the old pointer
    for key, value in pairs(new_config) do
        config[key] = value
    end
    local alias = require('cmdline-hl.alias')
    alias.handle_config()
end

function M.get()
    return config
end

return M
