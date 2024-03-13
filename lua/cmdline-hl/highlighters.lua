local M = {}
local ts = vim.treesitter
local config = require("cmdline-hl.config").get()
local utils = require("cmdline-hl.utils")

function M.cmdline(cmdinfo,cmdline, col)
    local retval = {}
    local p_cmd = cmdinfo.cmd
    local ctype = config.custom_types[p_cmd]
    local range, cmd = utils.split_range(cmdline)
    local code = nil
    if ctype then
        if ctype.code then
            code = ctype.code(cmd, cmdinfo)
        else
            code = cmd:match(ctype.pat or "%w*[%s/](.*)")
        end
    end
    if code then
        retval = M.ts(code, ctype.lang or "vim")
        local cmd_len = (#cmd - #code)
        if ctype.show_cmd then
            local cmd_tbl = M.ts(cmd:sub(1, cmd_len), "vim")
            local range_tbl = utils.str_to_tbl(range, config.range_hl)
            retval = utils.tbl_merge(range_tbl, cmd_tbl, retval)
        else
            if col ~= -1 then
                if col < #range + cmd_len then
                    local cmd_tbl = M.ts(cmd:sub(1, cmd_len), "vim")
                    local range_tbl = utils.str_to_tbl(range, config.range_hl)
                    retval = utils.tbl_merge(range_tbl, cmd_tbl)
                else
                    col = col - #range - cmd_len
                end
            end
        end
    else
        local range_tbl = utils.str_to_tbl(range, config.range_hl)
        retval = utils.tbl_merge(range_tbl, M.ts(cmd, "vim"))
    end
    return retval, col, code and p_cmd or nil
end

-- returns a list of {character,hl} for one line
-- doesn't handle injections
function M.ts(str, lang, default_hl)
    -- this is needed otherwise comments don't get parsed properly
    local source = str .. "\n"
    local tree = ts.get_string_parser(source, lang):parse()[1]
    local root = tree:root()
    local query = ts.query.get(lang, "highlights")
    if query == nil then
        return {}
    end
    local ret = {}
    for i = 1, #str, 1 do
        ret[i] = { str:sub(i, i), default_hl }
    end
    for id, node, _ in query:iter_captures(root, source, 0, 1) do
        local hl = "@" .. query.captures[id]
        -- skip invalid queries
        if hl:find("_") then
            goto continue
        end
        local hl_cleared =
            vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = hl }))
        if hl_cleared then
            goto continue
        end
        local _, start_col = node:start()
        local _, end_col = node:end_()
        -- it's on another row
        -- it's impossible for a node to have a range of 0,x .. 1,0
        -- when the command-line is one line
        if end_col == 0 then
            end_col = #str
        end
        for i = start_col, end_col - 1, 1 do
            ret[i + 1][2] = hl
        end
        ::continue::
    end
    return ret
end

return M
