local M = {}
local utils = require("cmdline-hl.utils")
local highlighters = require("cmdline-hl.highlighters")
local alias = require("cmdline-hl.alias")
local config = require("cmdline-hl.config")
M.config = config.get()

local cmdline_ns = vim.api.nvim_create_namespace("cmdline")

local nvim_echo = vim.api.nvim_echo

local cmdtype = ""
local data = ""
local last_ctx = { prefix = "", cmdline = " ", cursor = -1 }
local ch_before = -1
local draw_cmdline = function(prefix, cmdline, cursor, force)
    if vim.fn.getcmdtype() == "" and not force then
        return
    end
    local hl_cmdline = {}
    local ctype = nil
    local render_cursor = cursor
    if prefix == ":" then
        local ok, cmdinfo = pcall(vim.api.nvim_parse_cmd, cmdline, {})
        if (not ok) then
            cmdinfo = { cmd = "?" }
        end
        local render_cmdline = alias.cmdline(cmdinfo, cmdline)
        hl_cmdline, render_cursor, ctype = highlighters.cmdline(cmdinfo, render_cmdline, cursor)
    end
    if utils.issearch(prefix) then
        hl_cmdline = highlighters.ts(cmdline, "regex")
    end
    if prefix == "=" then
        local hls =
            vim.api.nvim_parse_expression(cmdline, "E", true).highlight
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
    end
    if M.config.type_signs[prefix] == nil then
        -- prompts
        for i = 1, #cmdline, 1 do
            hl_cmdline[i] = { cmdline:sub(i, i) }
        end
    end
    if cursor == -1 then
        goto theend
    end
    if M.config.ghost_text then
        if
            ((#hl_cmdline + 1) == render_cursor or M.config.inline_ghost_text)
        then
            local ghost_text = M.config.ghost_text_provider(
                prefix,
                cmdline,
                cursor
            ) or ""
            for i = #ghost_text, 1, -1 do
                table.insert(
                    hl_cmdline,
                    render_cursor,
                    { ghost_text:sub(i, i), M.config.ghost_text_hl }
                )
            end
        end
    end
    if render_cursor <= #hl_cmdline then
        local cur_hl = vim.api.nvim_get_hl(
            0,
            { name = hl_cmdline[render_cursor][2], link = false }
        )
        if cur_hl.fg then
            local normal_hl =
                vim.api.nvim_get_hl(0, { name = "MsgArea", link = false })
            local bg = cur_hl.bg
            cur_hl.bg = cur_hl.fg
            cur_hl.fg = bg or normal_hl.bg
        else
            cur_hl = { link = "Cursor" }
        end
        vim.api.nvim_set_hl(0, "InvertCur", cur_hl)
        hl_cmdline[render_cursor][2] = "InvertCur"
    else
        hl_cmdline[#hl_cmdline + 1] = { " ", "Cursor" }
    end
    ::theend::
    last_ctx = { prefix = prefix, cmdline = cmdline, cursor = cursor }
    if ctype then
        table.insert(hl_cmdline, 1, {
            M.config.custom_types[ctype].icon or M.config.type_signs[":"][1],
            M.config.custom_types[ctype].icon_hl or M.config.type_signs[":"][2],
        })
    else
        if M.config.type_signs[prefix] then
            table.insert(hl_cmdline, 1, M.config.type_signs[prefix])
        else
            table.insert(hl_cmdline, 1, { M.config.input_format(prefix), M.config.input_hl })
        end
    end
    local len     = 0
    -- the prefix doesn't follow the 1 item 1 character style so this is needed
    len           = len + #hl_cmdline[1][1]
    len           = len + #hl_cmdline - 1
    local last_ch = vim.o.ch
    local new_ch  = math.ceil((len + 1) / vim.o.columns)
    if (last_ch ~= new_ch) then
        if (ch_before == -1) then
            ch_before = last_ch
        end
        vim.o.ch = new_ch
        -- redraw the statusline properly
        vim.cmd.redraw()
    end
    nvim_echo(hl_cmdline, false, {})
end

local draw_lastcmdline = function()
    draw_cmdline(last_ctx.prefix, last_ctx.cmdline, last_ctx.cursor)
end

-- resizing clears messages
vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
        vim.schedule(function()
            draw_lastcmdline()
        end)
    end,
})

local k = function(str)
    return vim.api.nvim_replace_termcodes(str, true, true, true)
end
-- non-silent mappings that end with <cr> won't appear in the command-line
local mapping_has_cr = false
vim.api.nvim_create_autocmd("CmdlineChanged", {
    callback = function()
        mapping_has_cr = vim.fn.getcharstr(1) == k("<cr>")
    end,
})
vim.api.nvim_create_autocmd("CmdlineEnter", {
    callback = function()
        mapping_has_cr = false
        last_ctx.cmdline = "not empty"
    end,
})

local cmdline_init = false
vim.api.nvim_create_autocmd("CmdlineLeave", {
    callback = function()
        if not cmdline_init then
            return
        end
        cmdline_init = false
        pcall(draw_cmdline, cmdtype, data, -1, true)
        if ch_before ~= -1 then
            vim.o.ch = ch_before
        end
        ch_before = -1
    end,
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
    config.set(opts)
    if not ui_attached then
        -- we render our own cursor
        vim.api.nvim_set_hl(0, "HIDDEN", { blend = 100, nocombine = true })
        vim.opt_global.guicursor:append({ "ci:HIDDEN", "c:HIDDEN", "cr:HIDDEN" })
        ui_attached = true
        vim.ui_attach(cmdline_ns, { ext_cmdline = true }, function(name, ...)
            if handler[name] then
                local vargs = utils.pack(...)
                xpcall(function()
                        handler[name](unpack(vargs))
                    end,
                    function(msg)
                        if msg == nil then
                            return
                        end
                        local backtrace = debug.traceback(msg, 1)
                        vim.schedule(
                            function()
                                vim.notify(
                                    'cmdline-hl.nvim: Disabling cmdline highlighting please open an issue with this backtrace, you can copy it with lmouse:\n' ..
                                    backtrace,
                                    vim.log.levels.ERROR, {})
                                vim.api.nvim_input('<esc>:messages<cr>')
                                M.disable()
                            end)
                    end)
            end
        end)
    end
end

M.disable = function()
    if ui_attached then
        vim.opt_global.guicursor:remove({ "ci:HIDDEN", "c:HIDDEN", "cr:HIDDEN" })
        vim.ui_detach(cmdline_ns)
        ui_attached = false
    end
end

M.disable_msgs = function()
    ---@diagnostic disable-next-line: duplicate-set-field
    function vim.api.nvim_echo(...)
        if vim.fn.getcmdtype() == "" then
            nvim_echo(...)
        end
    end

    local notify = vim.notify
    ---@diagnostic disable-next-line: duplicate-set-field
    function vim.notify(...)
        if vim.fn.getcmdtype() == "" then
            notify(...)
        end
    end

    local vprint = vim.print
    ---@diagnostic disable-next-line: duplicate-set-field
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
    ---@diagnostic disable-next-line: duplicate-set-field
    function vim.api.nvim_err_write(...)
        if vim.fn.getcmdtype() == "" then
            nvim_err_write(...)
        end
    end

    local nvim_err_writeln = vim.api.nvim_err_write
    ---@diagnostic disable-next-line: duplicate-set-field
    function vim.api.nvim_err_writeln(...)
        if vim.fn.getcmdtype() == "" then
            nvim_err_writeln(...)
        end
    end
end

return M
