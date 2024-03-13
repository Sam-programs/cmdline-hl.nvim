local M = {}
local last_command = nil
function M.Bang_command(opts)
    opts = opts or {}
    vim.api.nvim_create_user_command("Bang",
        function(args)
            local cmdstr = args.args
            if (args.args:match("^!%s*")) then
                if (last_command == nil) then
                    vim.api.nvim_err_writeln("E34: No previous command")
                    return
                end
                cmdstr = last_command
            end
            last_command = cmdstr
            local buf = vim.api.nvim_create_buf(true, true)
            local rows = vim.o.lines
            if vim.o.stl ~= '' then
                rows = rows - 1
            end
            local row = 0
            if vim.o.tabline ~= '' then
                rows = rows - 1
                row = 1
            end
            local cols = vim.o.columns
            local win = vim.api.nvim_open_win(buf, true, {
                relative = 'editor',
                row = rows - vim.o.ch,
                col = 0,
                height = 2,
                width = cols,
            })
            vim.wo[win].nu = false
            vim.wo[win].rnu = false
            vim.wo[win].fillchars = "eob: "
            vim.bo[buf].bufhidden = 'wipe'
            local dont_render = false
            local function resize_win()
                if dont_render then
                    return
                end
                if not vim.api.nvim_win_is_valid(win) then
                    return
                end
                vim.api.nvim_win_set_buf(win, buf)
                local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                local bufrows = #lines
                for i = bufrows, 1, -1 do
                    if(lines[i]:match("%[Process exited %d+%]")) then
                        vim.api.nvim_input('<C-\\><C-n>ggGi')
                        dont_render = true
                    end
                    if (lines[i] ~= '') then
                        bufrows = i
                        break
                    end
                end
                local height = math.min(bufrows + 1, rows - vim.o.ch)
                vim.api.nvim_win_set_config(win, {
                    relative = 'editor',
                    row = rows - height,
                    col = 0,
                    height = height,
                    width = cols,
                })
            end
            vim.api.nvim_buf_attach(buf, false, {
                on_lines = function()
                    if(not vim.api.nvim_buf_is_valid(buf)) then
                        return true
                    end
                    vim.schedule(function()
                        resize_win()
                    end)
                end
            })
            vim.api.nvim_win_call(win, function()
                vim.api.nvim_buf_call(buf, function()
                    local echo = ''
                    if opts.echo then
                        echo = ("echo \'!%s\';"):format(cmdstr)
                    end
                    vim.fn.termopen(echo .. cmdstr, {
                        on_stdout = function(_, data)
                            data = table.concat(data, "")
                            -- tui key
                            -- self-note 1049h is the start 1049l is the end
                            if (data:find("\27[?1049", 1, true)) then
                                -- make the window full screen if a tui wants it
                                vim.api.nvim_win_set_config(win, {
                                    relative = 'editor',
                                    row = row,
                                    col = 0,
                                    height = rows - vim.o.ch,
                                    width = cols,
                                })
                                dont_render = not dont_render
                            end
                        end,
                    })
                end)
            end)
        end, {
            nargs = 1,
            complete = "shellcmd",
        })
end

function M.Cd_command(opts)
    opts = opts or {}
    vim.api.nvim_create_user_command("Cd",
        function(args)
            args = args.fargs
            if (#args == 0) then
                vim.cmd.cd()
                return
            end
            local cwd = vim.fn.getcwd()
            local cmd = {
                'zoxide', 'query', '--exclude', cwd, args[1], args[2]
            }
            if (#args == 1 and vim.fn.isdirectory(args[1]) or
                    args[1]:match('^[-+][0-9]$')) then
                vim.cmd.cd(args[1])
                return
            end
            local out = vim.system(cmd):wait()
            if (out.stderr ~= '') then
                vim.api.nvim_err_writeln(out.stderr)
                return
            end
            local path = vim.trim(out.stdout)
            local add = {
                'zoxide', 'add', path
            }
            vim.system(add)
            vim.cmd.cd(path)
        end, {
            nargs = "*",
            complete =
                function(_, cmdline)
                    local args = vim.split(cmdline, " ")
                    local cwd = vim.fn.getcwd()
                    args[1] = 'zoxide'
                    table.insert(args, 2, 'query')
                    table.insert(args, 3, '--exclude')
                    table.insert(args, 4, cwd)
                    table.insert(args, 5, '--list')
                    args[6] = vim.fn.expand(args[6])
                    if (args[7]) then
                        args[7] = vim.fn.expand(args[7])
                    end
                    local stdout = vim.system(args):wait().stdout or ''
                    local output = vim.split(stdout, '\n')
                    for i = 1, #output, 1 do
                        local home = vim.env.HOME
                        output[i] = output[i] .. "/"
                        if (output[i]:sub(1, #cwd) == cwd) then
                            output[i] = output[i]:sub(#cwd + 2)
                        end
                        if (output[i]:sub(1, #home) == home) then
                            output[i] = "~" .. output[i]:sub(#home + 1)
                        end
                    end
                    return output
                end,
        })
end

return M
