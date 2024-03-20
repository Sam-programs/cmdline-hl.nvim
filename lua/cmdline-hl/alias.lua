local M = {}
local config = require('cmdline-hl.config')
local utils = require('cmdline-hl.utils')
M.config = config.get()

function M.cmdline(cmdinfo, cmdline,cursor)
    local range, cmd = utils.split_range(cmdline)
    local ctype = M.config.custom_types[cmdinfo.cmd]
    if not ctype or ctype.show_cmd then
        for render_cmd, alias in pairs(M.config.aliases) do
            if (cmd:sub(1, #alias.str) == alias.str) then
                cursor = cursor + (#render_cmd - #alias.str)
                return range .. render_cmd .. cmd:sub(#alias.str + 1),cursor
            end
        end
    end
    return cmdline,cursor
end

function M.handle_config()
    for render_cmd, _ in pairs(M.config.aliases) do
        local key = render_cmd:sub(#render_cmd, #render_cmd)
        vim.keymap.set("c", key, function()
            if (vim.fn.getcmdtype() ~= ':') then
                return key
            end
            local cmdline = vim.fn.getcmdline()
            local _, cmd = utils.split_range(cmdline)
            -- TODO: maybe keep a list of aliases that have a key as the end key?
            for render_cmd, alias in pairs(M.config.aliases) do
                if render_cmd:sub(#render_cmd, #render_cmd) ~= key then
                    goto continue
                end
                if (#render_cmd == 1) then
                    if cmd == "" then
                        return alias.str
                    else
                        return key
                    end
                end
                cmd = cmd:match("%s*(.*)")
                if (cmd:sub(1,#render_cmd - 1) == render_cmd:sub(1, #render_cmd - 1)) then
                    return ("<bs>"):rep(#render_cmd - 1) .. alias.str
                end
                ::continue::
            end
            return key
        end, { expr = true })
    end
end

return M
