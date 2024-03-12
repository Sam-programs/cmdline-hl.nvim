local M = {}
M.history_ghost_text = function(type, cmdline, cursor)
    if #type > 1 then
        return ""
    end
    if #cmdline == 0 then
        return vim.fn.histget(type, -1)
    end
    local pos = cursor - 1
    local prefix = cmdline:sub(1, pos)
    for i = vim.fn.histnr(type), 1, -1 do
        local item = vim.fn.histget(type, i)
        if item:sub(1, pos) == prefix then
            return item:sub(pos + 1, #item)
        end
    end
    return ""
end
---@diagnostic disable-next-line: unused-local
M.wildmenu_ghost_text = function(type, cmdline, cursor)
    if vim.fn.getcmdcompltype() == "" then
        return
    end
    local item = vim.fn.getcompletion(cmdline, vim.fn.getcmdcompltype(), 1)[1]
        or ""
    for i = #cmdline, 1, -1 do
        if cmdline:sub(i, i) == item:sub(1, 1) then
            local part = cmdline:sub(i)
            if item:sub(1, #part) == part then
                return item:sub(#part + 1)
            end
        end
    end
    return item
end
return M
