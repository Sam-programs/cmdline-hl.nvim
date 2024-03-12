local M = {}
local ts = vim.treesitter

function M.format_table(tbl)
    return tbl
end

function M.tbl_merge(...)
    local retval = {}
    for _, tbl in ipairs({ select(1, ...) }) do
        for i = 1, #tbl, 1 do
            retval[#retval + 1] = vim.deepcopy(tbl[i])
        end
    end
    return retval
end

function M.cmdline_get_hl(cmdline, col)
    local retval = {}
    local ok, cmdinfo = pcall(vim.api.nvim_parse_cmd, cmdline, {})
    if not ok then
        cmdinfo = { cmd = "?" }
    end
    local p_cmd = cmdinfo.cmd
    local ctype = M.config.custom_types[p_cmd]
    local range, cmd = M.split_range(cmdline)
    local code = nil
    if (ctype) then
        if (ctype.code) then
            code = ctype.code(cmd, cmdinfo)
        else
            code = cmd:match(ctype.pat or ('%w*%s*(.*)'))
        end
    end
    if code then
        retval = M.ts_get_hl(code, ctype.lang or "vim")
        local cmd_len = (#cmd - #code)
        if (ctype.show_cmd) then
            local cmd_tbl = M.get_ts_hl(cmd:sub(1, cmd_len))
            local range_tbl = M.str_to_tbl(range, M.config.range_hl)
            retval = M.tbl_merge(range_tbl, cmd_tbl, retval)
        else
            if col ~= -1 then
                if (col < #range + cmd_len) then
                    local cmd_tbl = M.get_ts_hl(cmd:sub(1, cmd_len))
                    local range_tbl = M.str_to_tbl(range, M.config.range_hl)
                    retval = M.tbl_merge(range_tbl, cmd_tbl)
                else
                    col = col - #range - cmd_len
                end
            end
        end
    else
        local range_tbl = M.str_to_tbl(range, M.config.range_hl)
        retval = M.tbl_merge(range_tbl, M.ts_get_hl(cmd, 'vim'))
    end
    return retval, col, ctype and p_cmd or nil
end

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
        -- skip invalid queries
        if (hl:find("_")) then
            goto continue
        end
        local hl_cleared = vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = hl }))
        if (hl_cleared) then
            goto continue
        end
        local _, start_col = node:start()
        local _, end_col = node:end_()
        -- it's on another row
        -- it's impossible for a node to have a range of 0,x .. 1,0
        -- when the command-line is one line
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

function M.issearch(char)
    return char == '/' or char == '?'
end

function M.iswhite(char)
    return char == ' ' or char == '\t'
end

-- returns a table with {range,cmd + args}
-- white space at the start is considered a part of the range
-- doesn't handle pattern range errors that well
function M.split_range(cmdline)
    local i = 1
    local in_range_pat = false
    -- skip white space
    while (M.iswhite(cmdline:sub(i, i))) do i = i + 1 end
    while (i <= #cmdline) do
        local char = cmdline:sub(i, i)
        if M.issearch(char) then
            in_range_pat = not in_range_pat
        end
        if (in_range_pat) then
            goto continue
        end
        if (char:match("%w")) then
            local prev_char = cmdline:sub(i - 1, i - 1)
            -- if it's not a mark then it's the start of the command
            if (prev_char ~= '\'') then
                break;
            end
        end
        ::continue::
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
