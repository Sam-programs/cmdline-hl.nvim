local M = {}
local utils = require('cmdline-hl.utils')
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
        ["lua"] = { icon = " ", icon_hl = "Title", lang = "lua" },
        ["help"] = { icon = "? ", icon_hl = "Title" },
        ["substitute"] = { pat = "%w(.*)", lang = "regex", show_cmd = true },
        --["lua"] = false, -- set an option  to false to disable it
    },
    input_hl = "Title",
    -- used to highlight the range in the command e.g. '<,>' in '<,>'s
    range_hl = "FloatBorder",
    ghost_text = false,
    ghost_text_hl = 'Comment',
    --ghost_text_provider = M.calculate_ghost_text
    -- this is set in where the function is defined
}

local k = function(str)
    return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local cmdline_ns = vim.api.nvim_create_namespace('cmdline')

local nvim_echo = vim.api.nvim_echo

local cmdtype = ""
local data = ""
local last_ctx = { prefix = "", cmdline = " ", cursor = -1 }
local unpack = unpack or table.unpack
local ghost_text = ''
local ch_before = -1
local draw_cmdline = function(prefix, cmdline, cursor, force)
    if vim.fn.getcmdtype() == "" and (not force) then
        return
    end
    local hl_cmdline = {}
    local p_cmd = ""
    local should_use_custom_type = false
    if (prefix == ':') then
        local ok, parsed = pcall(vim.api.nvim_parse_cmd, cmdline, {})
        if not ok then
            parsed = { cmd = "?" }
        end
        p_cmd = parsed.cmd
        local range, cmd = utils.split_range(cmdline)
        local ctype = M.config.custom_types[p_cmd]
        if ctype and (cmd:match('^%w*%s') or ctype.show_cmd) then
            should_use_custom_type = true
            local code = ''
            if (ctype.code) then
                code = ctype.code(cmd)
            else
                code = cmd:match(ctype.pat or ('%w*%s*(.*)')) or ''
            end
            hl_cmdline = { unpack(utils.ts_get_hl(code, ctype.lang or "vim")) }
            local cmd_len = (#cmd - #code)
            -- TODO: remove repeated code
            if (ctype.show_cmd) then
                local cmd_tbl = utils.str_to_tbl(cmd:sub(1, cmd_len), "@keyword")
                for i = #cmd_tbl, 1, -1 do
                    table.insert(hl_cmdline, 1, cmd_tbl[i])
                end
                local range_tbl = utils.str_to_tbl(range, M.config.range_hl)
                for i = #range_tbl, 1, -1 do
                    table.insert(hl_cmdline, 1, range_tbl[i])
                end
            else
                -- make sure it's a valid cursor first
                if cursor ~= -1 then
                    cursor = cursor - cmd_len - #range
                    if (cursor < 1) then
                        cursor = cursor + cmd_len + #range
                        -- restore the command in case the cursor went too far back
                        local cmd_tbl = utils.str_to_tbl(cmd:sub(1, cmd_len), "@keyword")
                        for i = #cmd_tbl, 1, -1 do
                            table.insert(hl_cmdline, 1, cmd_tbl[i])
                        end
                        local range_tbl = utils.str_to_tbl(range, M.config.range_hl)
                        for i = #range_tbl, 1, -1 do
                            table.insert(hl_cmdline, 1, range_tbl[i])
                        end
                    end
                end
            end
        end
        if not should_use_custom_type then
            hl_cmdline = utils.ts_get_hl(cmd, 'vim')
            for i = #range, 1, -1 do
                table.insert(hl_cmdline, 1, { range:sub(i, i), M.config.range_hl })
            end
        end
    else
        if utils.is_search(prefix) then
            hl_cmdline = utils.ts_get_hl(cmdline, 'regex')
        else
            if prefix == '=' then
                local hls = vim.api.nvim_parse_expression(cmdline, "", true).highlight
                for i = 1, #cmdline, 1 do
                    hl_cmdline[i] = { cmdline:sub(i, i) }
                end
                for _, hl in pairs(hls) do
                    -- hl[2] is the start 0-indexed
                    -- hl[3] is the end 1-indexed
                    -- hl[4] is the highlight
                    for i = hl[2] + 1, hl[3], 1 do
                        hl_cmdline[i][2] = hl[4]
                    end
                end
            else
                -- prompts
                for i = 1, #cmdline, 1 do
                    hl_cmdline[i] = { cmdline:sub(i, i) }
                end
            end
        end
    end
    if M.config.ghost_text then
        if cursor ~= -1 then
            ghost_text = M.config.ghost_text_provider(prefix, cmdline, cursor)
            for i = #ghost_text, 1, -1 do
                table.insert(hl_cmdline, cursor, { ghost_text:sub(i, i), M.config.ghost_text_hl })
            end
        end
    end
    if (cursor ~= -1 and hl_cmdline[cursor]) then
        local cur_hl = vim.api.nvim_get_hl(0, { name = hl_cmdline[cursor][2], link = false })
        if (cur_hl.fg) then
            local normal_hl = vim.api.nvim_get_hl(0, { name = "MsgArea", link = false })
            local bg = cur_hl.bg
            cur_hl.bg = cur_hl.fg
            cur_hl.fg = bg or normal_hl.bg
        else
            cur_hl = { link = 'Cursor' }
        end
        vim.api.nvim_set_hl(0, 'InvertCur', cur_hl)
        hl_cmdline[cursor][2] = 'InvertCur'
    else
        -- if it's not in the array it must be at the end
        if cursor ~= -1 then
            hl_cmdline[#hl_cmdline + 1] = { ' ', 'Cursor' }
        end
    end
    last_ctx = { prefix = prefix, cmdline = cmdline, cursor = cursor }
    if should_use_custom_type then
        table.insert(hl_cmdline, 1, {
            M.config.custom_types[p_cmd].icon or M.config.type_signs[":"][1],
            M.config.custom_types[p_cmd].icon_hl or M.config.type_signs[":"][2]
        })
    else
        if M.config.type_signs[prefix] then
            table.insert(hl_cmdline, 1,M.config.type_signs[prefix])
        else
            table.insert(hl_cmdline, 1, { prefix, M.config.input_hl })
        end
    end
    local len     = 0
    -- the prefix doesn't follow the 1 item 1 character style so this is needed
    len           = len + #hl_cmdline[1][1]
    len           = len + #hl_cmdline - 1
    local last_ch = vim.o.ch
    local new_ch  = math.ceil(len / vim.o.columns)
    if (last_ch ~= new_ch) then
        if (ch_before == -1) then
            ch_before = last_ch
        end
        vim.o.ch = new_ch
        -- redraw the statusline properly
        vim.cmd.redraw()
    end
    nvim_echo(
        hl_cmdline,
        false, {})
end

M.calculate_ghost_text = function(type, cmdline, cursor)
    ghost_text = ''
    if #type > 1 then
        return ''
    end
    if (#cmdline == 0) then
        return vim.fn.histget(type, -1)
    end
    local pos = cursor - 1
    local prefix = cmdline:sub(1, pos)
    for i = vim.fn.histnr(type), 1, -1 do
        local item = vim.fn.histget(type, i)
        if item:sub(1, pos) == prefix then
            ghost_text = item:sub(pos + 1, #item)
            return ghost_text
        end
    end
    return ''
end
M.config.ghost_text_provider = M.calculate_ghost_text

local draw_lastcmdline = function()
    draw_cmdline(last_ctx.prefix, last_ctx.cmdline, last_ctx.cursor)
end

-- resizing clears messages
vim.api.nvim_create_autocmd('VimResized', {
    pattern = "*",
    callback = function()
        vim.schedule(function()
            draw_lastcmdline()
        end)
    end
})

-- non-silent mappings that end with <cr> won't appear in the command-line
local mapping_has_cr = false
vim.api.nvim_create_autocmd('CmdlineChanged', {
    pattern = "*",
    callback = function()
        mapping_has_cr = vim.fn.getcharstr(1) == k '<cr>'
    end
})

vim.api.nvim_create_autocmd('CmdlineEnter', {
    pattern = "*",
    callback = function()
        mapping_has_cr = false
    end
})

local abort = false
local cmdline_init = false
vim.api.nvim_create_autocmd('CmdlineLeave', {
    pattern = "*",
    callback = function()
        abort = vim.v.event.abort
        if not cmdline_init then
            return
        end
        cmdline_init = false
        if (utils.is_search(cmdtype)) then
            draw_cmdline(cmdtype, data, -1, true)
        else
            draw_cmdline(cmdtype, data, -1, true)
        end
        if (ch_before ~= -1) then
            vim.o.ch = ch_before
        end
        ch_before = -1
        if abort then
            return
        end
    end
})

vim.api.nvim_create_autocmd('CmdlineEnter', {
    pattern = "*",
    callback = function()
        last_ctx.cmdline = "not empty"
        abort = false
    end
})

local handler = {
    ["cmdline_pos"] = function(cursor, _)
        draw_cmdline(cmdtype, data, cursor + 1)
    end,
    -- self note runs before on_win
    ["cmdline_show"] = function(content, cursor, type, prompt, _, _)
        if mapping_has_cr then
            return
        end
        cmdline_init = true
        -- index it
        cursor = cursor + 1
        if type == "" then
            cmdtype = prompt
        else
            cmdtype = type
        end
        -- parse the argument
        data = ""
        for i = 1, #content, 1 do
            data = data .. content[i][2]
        end
        draw_cmdline(cmdtype, data, cursor)
    end,
}

local ui_attached = false
M.setup = function(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.config, opts)
    if not ui_attached then
        -- we render our own cursor
        vim.api.nvim_set_hl(0, 'HIDDEN', { blend = 100, nocombine = true })
        vim.opt_global.guicursor:append { 'ci:HIDDEN', 'c:HIDDEN', 'cr:HIDDEN' }
        ui_attached = true
        vim.ui_attach(cmdline_ns, { ext_cmdline = true },
            function(name, ...)
                if handler[name] then
                    handler[name](...)
                end
            end
        )
    end
end

M.disable_msgs = function()
    function vim.api.nvim_echo(...)
        if vim.fn.getcmdtype() == "" then
            nvim_echo(...)
        end
    end

    local notify = vim.notify
    function vim.notify(...)
        if vim.fn.getcmdtype() == "" then
            notify(...)
        end
    end

    local vprint = vim.print
    function vim.print(...)
        if vim.fn.getcmdtype() == "" then
            vprint(...)
        end
    end

    local lprint = print
    function print(...)
        if vim.fn.getcmdtype() == "" then
            lprint(...)
        end
    end

    local nvim_err_write = vim.api.nvim_err_write
    function vim.api.nvim_err_write(...)
        if vim.fn.getcmdtype() == "" then
            nvim_err_write(...)
        end
    end

    local nvim_err_writeln = vim.api.nvim_err_write
    function vim.api.nvim_err_writeln(...)
        if vim.fn.getcmdtype() == "" then
            nvim_err_writeln(...)
        end
    end
end

return M
