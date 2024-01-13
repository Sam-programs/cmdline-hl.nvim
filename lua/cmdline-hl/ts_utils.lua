local M = {}
local ts = vim.treesitter

-- returns a list of {character,hl} for one line
-- doesn't handle injections
function M.get_hl(str, lang, default_hl)
    -- this is needed otherwise comments don't get parsed properly
    local source = str .. "\n"
    local tree = ts.get_string_parser(source, lang):parse()[1]
    local root = tree:root()
    local query = ts.query.get(lang, 'highlights')
    if (query == nil) then
        return {}
    end
    local ret = {}
    for i = 1, #str, 1 do
        ret[i] = { str:sub(i, i), default_hl }
    end
    for id, node, _ in query:iter_captures(root, source, 0, 1) do
        local hl = "@" .. query.captures[id]
        if(hl == "@spell") then
            goto continue
        end
        local _, start_col = node:start()
        local _, end_col = node:end_()
        -- it's probably on another row
        -- i really doubt a node it gonna have a range of 0,0
        if(end_col == 0) then
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
