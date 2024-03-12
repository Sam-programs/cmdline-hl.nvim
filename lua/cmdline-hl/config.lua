local M = {}

M.config = {
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
            icon_hl = "Title",
            lang = "lua",
        },
        ["="] = { pat = "=(.*)", lang = "lua", show_cmd = true },
        ["help"] = { icon = "? " },
        ["substitute"] = { pat = "%w(.*)", lang = "regex", show_cmd = true },
        --["lua"] = false, -- set an option  to false to disable it
    },
    -- vim.ui.input() vim.fn.input etc
    input_hl = "Title",
    input_format = function(input) return input end,
    -- used to highlight the range in the command e.g. '<,>' in '<,>'s
    range_hl = "Constant",
    ghost_text = true,
    ghost_text_hl = "Comment",
    inline_ghost_text = false,
    ghost_text_provider = require("cmdline-hl.ghost_text").history,
    -- this is set in where the function is defined
}

function M.set(config)
    M.config = vim.tbl_deep_extend("force", M.config, config or {})
end

function M.get()
    return M.config
end

return M
