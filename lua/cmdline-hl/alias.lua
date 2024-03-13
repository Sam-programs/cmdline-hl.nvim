local M = {}
local config = require('cmdline-hl.config')
local utils = require('cmdline-hl.utils')
M.config = config.get()

function M.cmdline(cmdinfo, cmdline)
    local range, cmd = utils.split_range(cmdline)
    local ctype = M.config.custom_types[cmdinfo.cmd]
    if not ctype or ctype.show_cmd then
        for render_cmd, alias in pairs(M.config.aliases) do
            if (cmd:sub(1, #alias.str) == alias.str) then
                return range .. render_cmd .. cmd:sub(#alias.str + 1)
            end
        end
    end
    return cmdline
end

function M.handle_config()
    for render_cmd, alias in pairs(M.config.aliases) do
        vim.keymap.set("c", render_cmd:sub(#render_cmd, #render_cmd), function()
            if (vim.fn.getcmdtype() ~= ':') then
                return render_cmd:sub(#render_cmd, #render_cmd)
            end
            local cmdline = vim.fn.getcmdline()
            local _, cmd = utils.split_range(cmdline)
            if (#render_cmd == 1) then
                if cmd == "" then
                    return alias.str
                else
                    return render_cmd:sub(#render_cmd, #render_cmd)
                end
            end
            if (cmd:sub(#cmd - (#render_cmd - 2), #cmd ) == render_cmd:sub(1, #render_cmd - 1)) then
                return ("<bs>"):rep(#render_cmd - 1) .. alias.str
            end
            return render_cmd:sub(#render_cmd, #render_cmd)
        end, { expr = true })
    end
end

return M
