local M = {}
local ts = vim.treesitter

-- returns a list of {character,hl} for one line
-- doesn't handle injections
function M.get_hl(str,lang,default_hl)
    -- this is needed otherwise comments don't get parsed properly
    local source = str .. "\n"
    local tree = ts.get_string_parser(source,lang):parse()[1]
    local root = tree:root()
    local query = ts.query.get(lang,'highlights')
    if(query == nil) then
        return
    end
    local ret = {}
    for i = 1,#str,1 do
        ret[i] = {str:sub(i,i),default_hl}
    end
    for id,node,_ in query:iter_captures(root,source,0,1) do
        local hl = "@" .. query.captures[id]
        local _,start_col = node:start()
        local _,end_col = node:end_()
        for i = start_col,end_col - 1,1 do
            ret[i + 1][2] = hl
        end
    end
    return ret
end

return M
