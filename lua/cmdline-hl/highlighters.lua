local M = {}
local ts = vim.treesitter
local config = require("cmdline-hl.config").get()
local utils = require("cmdline-hl.utils")

function M.cmdline(cmdinfo, cmdline, col)
    local retval = {}
    local p_cmd = cmdinfo.cmd
    local ctype = config.custom_types[p_cmd]
    local range, cmd = utils.split_range(cmdline)
    local code = nil
    if ctype then
        if ctype.code then
            code = ctype.code(cmd, cmdinfo)
        else
            code = cmd:match(ctype.pat or "%w*[%s/]([^|]*)")
        end
    end
    if code then
        retval = M.ts(code, ctype.lang or "vim")
        local cmd_len = (#cmd - #code)
        if ctype.show_cmd then
            local cmd_tbl = M.ts(cmd:sub(1, cmd_len), "vim")
            retval = utils.tbl_merge(cmd_tbl, retval)
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
        retval = M.ts(cmdline, "vim")
    end
    return retval, col, code and p_cmd or nil
end

local hl_cache = {}
-- returns a list of {character,hl} for one line
function M.ts(str, language, default_hl)
    -- this is needed otherwise comments don't get parsed properly
    str = str .. "\n"
    local ret = {}
    for i = 1, #str, 1 do
        ret[i] = { str:sub(i, i), default_hl }
    end
    local priority_list = {}
    local parent_tree = ts.get_string_parser(str, language)
    parent_tree:parse(true)
    parent_tree:for_each_tree(function(tstree,tree)
        if not tstree then
            return
        end
        local lang = tree:lang()
        if hl_cache[lang] == nil then
            hl_cache[lang] = ts.query.get(lang, "highlights")
            if hl_cache[lang] == nil then
                return
            end
        end
        local query = hl_cache[lang]
        local level = 0
        local t = tree:parent()
        while t  do
            t = t:parent()
            level = level + 1
        end
        local pattern_offset = level * 1000
        for pattern, match, _ in query:iter_matches(tstree:root(), str, 0, 1,{ all = true}) do
            for id, nodes in pairs(match) do
                for _, node in ipairs(nodes) do
                    -- `node` was captured by the `name` capture in the match
                    local hl = "@" .. query.captures[id]
                    if hl:find("_") then
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
                    local priority = pattern_offset + pattern 
                    for i = start_col, end_col - 1, 1 do
                        if (priority_list[i + 1] or 0) <= priority then
                            ret[i + 1][2] = hl
                            priority_list[i + 1] = priority 
                        end
                    end
                    ::continue::
                end
            end
        end
    end)
    -- remove \n
    ret[#ret] =nil;
    return ret
end

return M
