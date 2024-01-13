local M = {}
local ts = vim.treesitter

-- returns a list of {character,hl} for one line
-- doesn't handle injections
function M.ts_get_hl(str, lang, default_hl)
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
        if (hl == "@spell") then
            goto continue
        end
        local _, start_col = node:start()
        local _, end_col = node:end_()
        -- it's probably on another row
        -- i really doubt a node it gonna have a range of 0,0
        if (end_col == 0) then
            end_col = #str
        end
        for i = start_col, end_col - 1, 1 do
            ret[i + 1][2] = hl
        end
        ::continue::
    end
    return ret
end

function M.is_search(char)
    return char == '/' or char == '?'
end

-- returns a table with {range,cmd + args}
-- whitespace at the start is considered a part of the range
-- doesn't handle pattern range errors that well
function M.split_range(cmdline)
    -- the range end
    local i = 1
    local in_range_pat = false
    while (i <= #cmdline) do
        local char = cmdline:sub(i, i)
        -- is this a good idea programmatically? it's incorrectly using the function but i feel like it's fine
        if M.is_search(char) then
            in_range_pat = not in_range_pat
        end
        if(in_range_pat) then
            goto continue
        end
        if (char:match("%w")) then
            local prev_char = cmdline:sub(i - 1, i - 1)
            -- if it's not a mark then it's the start of the command
            if(prev_char ~= '\'') then
                break;
            end
        end
        ::continue::
        i = i + 1
    end
    return cmdline:sub(1, i - 1), cmdline:sub(i)
end

-- translates a string into a table for nvim_echo
function M.str_to_tbl(str,hl)
    local tbl = {}
    for i = 1,#str,1 do
        table.insert(tbl,{str:sub(i,i),hl})
    end
    return tbl
end

return M
