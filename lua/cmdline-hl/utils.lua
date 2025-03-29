local M = {}
local config = require("cmdline-hl.config")
M.config = config.get()

function M.tbl_merge(...)
    local retval = {}
    for _, tbl in ipairs({ select(1, ...) }) do
        for i = 1, #tbl, 1 do
            retval[#retval + 1] = vim.deepcopy(tbl[i])
        end
    end
    return retval
end

function M.issearch(char)
    return char == "/" or char == "?"
end

function M.iswhite(char)
    return char == " " or char == "\t"
end
-- stylua: ignore
local utflen_table = {
    [0] =
  -- ?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9 ?A ?B ?C ?D ?E ?F
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 0?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 1?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 2?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 3?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 4?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 5?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 6?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 7?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 8?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- 9?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- A?
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  -- B?
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  -- C?
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  -- D?
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3,  -- E?
  4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 1, 1,  -- F?
}

function M.utflen(char)
    return utflen_table[char:byte(1)]
end

-- returns a table with {range,cmd + args}
-- white space at the start is considered a part of the range
-- doesn't handle pattern range errors that well
function M.split_range(cmdline)
    local i = 1
    local in_range_pat = false
    -- skip white space
    while M.iswhite(cmdline:sub(i, i)) do
        i = i + 1
    end
    while i <= #cmdline do
        local char = cmdline:sub(i, i)
        if M.issearch(char) then
            in_range_pat = not in_range_pat
        end
        if in_range_pat then
            goto continue
        end
        if char:match("%w") then
            local prev_char = cmdline:sub(i - 1, i - 1)
            -- if it's not a mark then it's the start of the command
            if prev_char ~= "'" then
                break
            end
        end
        ::continue::
        if not char:match("[%w/\\\\?%%$.<>\'\",+-]") then
            break
        end
        i = i + 1
    end
    return cmdline:sub(1, i - 1), cmdline:sub(i)
end

-- translates a string into a table for nvim_echo
function M.str_to_tbl(str, hl)
    local tbl = {}
    for i = 1, #str, 1 do
        table.insert(tbl, { str:sub(i, i), hl })
    end
    return tbl
end

return M
