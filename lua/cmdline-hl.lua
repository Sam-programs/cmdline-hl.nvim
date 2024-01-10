local M = {}
M.config = {
    type_signs = {
        [":"] = { " ", "FloatFooter" },
        ["/"] = { " ", "FloatFooter" },
        ["?"] = { " ", "FloatFooter" },
        ["="] = { " ", "FloatFooter" },
    },
    convert_hls = true,
    input_hl = "FloatFooter",
}
local cmdline_ns = vim.api.nvim_create_namespace('cmdline')

M.disable_msgs = function()
    local nvim_echo = vim.api.nvim_echo
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

    local vprint = vim.notify
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

local call_c = 0
local cmdtype = ""
local data = ""
local last_ctx = { prefix = "", cmdline = "", cursor = -1 }
local cmdbuf = vim.api.nvim_create_buf(false, true)

local get_highlighted_cmdline = function(cmdline, syntax)
    vim.bo[cmdbuf].syntax = syntax
    vim.api.nvim_buf_set_lines(cmdbuf, 0, -1, false, { cmdline })
    local highlights = {}
    for i = 1, #cmdline, 1 do
        local captures = vim.inspect_pos(cmdbuf, 0, i - 1,
                { syntax = true, treesitter = false, semantic_tokens = false, extmarks = false })
            .syntax
        local capture = captures[#captures] and (captures[#captures].hl_group_link)
        -- TODO: properly pick highlights
        highlights[i] = { cmdline:sub(i, i), capture or 'MsgArea' }
    end
    return highlights;
end

local function is_search(cmdtype)
    return cmdtype == '/' or cmdtype == '?'
end

local redrawing = false
local draw_cmdline = function(prefix, cmdline, cursor)
    if redrawing then
        return
    end
    local hl_cmdline = {}
    if (prefix == ':') then
        hl_cmdline = get_highlighted_cmdline(cmdline, 'vim')
    else
        if is_search(prefix) then
            local hl = string.format("s/%s/", cmdline)
            hl_cmdline = get_highlighted_cmdline(hl, 'vim')
            -- TODO: add a range for get_highlighted_cmdline
            -- remove s/ /
            table.remove(hl_cmdline, 1)
            table.remove(hl_cmdline, 1)
            -- end
            table.remove(hl_cmdline)
        else
            if prefix == '=' then
                local hls = vim.api.nvim_parse_expression(cmdline, "", true).highlight
                for i = 1, #cmdline, 1 do
                    hl_cmdline[i] = {}
                    hl_cmdline[i][1] = cmdline:sub(i, i)
                end
                for _, hl in pairs(hls) do
                    for i = hl[2] + 1, hl[3], 1 do
                        hl_cmdline[i][2] = hl[4]
                    end
                end
            else
                for i = 1, #cmdline, 1 do
                    hl_cmdline[i] = { cmdline:sub(i, i) }
                end
            end
        end
    end
    if (cursor ~= -1 and hl_cmdline[cursor]) then
        local cur_hl = vim.api.nvim_get_hl(0, { name = hl_cmdline[cursor][2], link = false })
        if (cur_hl.fg) then
            local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
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
    -- clear the older cmdlines
    if (#last_ctx.cmdline + #last_ctx.prefix) > vim.o.columns then
        redrawing = true
        vim.cmd.mode()
        redrawing = false
    end
    last_ctx = { prefix = prefix, cmdline = cmdline, cursor = cursor }
    if M.config.type_signs[prefix] then
        table.insert(hl_cmdline, 1, { M.config.type_signs[prefix][1], M.config.type_signs[prefix][2] })
    else
        table.insert(hl_cmdline, 1, { prefix, M.config.input_hl })
    end
    nvim_echo(
        hl_cmdline,
        false, {})
end

local draw_lastcmdline = function()
    draw_cmdline(last_ctx.prefix, last_ctx.cmdline, last_ctx.cursor, true)
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

local k = function(str)
    return vim.api.nvim_replace_termcodes(str, true, true, true)
end
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
vim.api.nvim_create_autocmd('CmdlineLeave', {
    pattern = "*",
    callback = function()
        abort = vim.v.event.abort
    end
})

vim.api.nvim_create_autocmd('CmdlineEnter', {
    pattern = "*",
    callback = function()
        abort = false
    end
})

local handler = {
    ["cmdline_hide"] = function()
        if abort then
            return
        end
        call_c = 0
        if (is_search(cmdtype)) then
            -- search renders an extra /search we need to wait a bit to overwrite it
            vim.schedule(function()
                draw_cmdline(cmdtype, data, -1)
            end)
        else
            draw_cmdline(cmdtype, data, -1)
        end
    end,
    -- only useful for forward movement outside of cmd preview
    ["cmdline_pos"] = function(cursor, _)
        draw_cmdline(cmdtype, data, cursor + 1)
    end,
    -- self note runs before on_win
    ["cmdline_show"] = function(content, cursor, type, prompt, _, level)
        if mapping_has_cr then
            return
        end
        call_c = call_c + 1
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
M.syntax_hls_to_ts_hls = function()
    vim.api.nvim_set_hl(0, 'vimCommand', { link = '@keyword.vim' })
    vim.api.nvim_set_hl(0, 'vimUsrCmd', { link = '@function.macro.vim' })

    vim.api.nvim_set_hl(0, 'vimFunction', { link = '@function' })
    vim.api.nvim_set_hl(0, 'vimUsrFunction', { link = '@function' })

    vim.api.nvim_set_hl(0, 'vimParenSep', { link = '@punctuation.bracket.vim' })
    -- "this" is what the highlight is for
    -- s/this/
    vim.api.nvim_set_hl(0, 'vimSubstpat', { link = 'Constant' })
    vim.api.nvim_set_hl(0, 'vimCollection', { link = '@function' })

    -- s/x/this
    vim.api.nvim_set_hl(0, 'vimSubstRep4', { link = 'Constant' })
    -- the / in s/
    vim.api.nvim_set_hl(0, 'vimSubstDelim', { link = '@operator' })
end
local ui_attached = false
M.setup = function(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.config, opts)
    if M.config.convert_hls then
        M.syntax_hls_to_ts_hls()
    end
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

return M
