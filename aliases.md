## Aliasing
## Examples
### Make ! run in a terminal
```lua
require('cmdline-hl.scripts').Bang_command({ 
    -- wether !cmd should be echoed before running the command 
    -- might cause issues because it's echoed like this
    -- echo 'cmd'
    -- if cmd misses a quote you get an unmatched quote error
    echo = true
})
cmdline_hl.setup({
    custom_types = {
        ['Bang'] = { icon = "!", lang = "bash", show_cmd = false }
    },
    aliases = {
        ['!'] = { str = 'Bang ' }
    }
})
```
requires treesitter bash parser

### Make cd act as zoxide
```lua
require('cmdline-hl.scripts').Cd_command()
cmdline_hl.setup({
    custom_types = {
        ['Cd'] = { show_cmd = true }
    },
    aliases = {
        ['cd'] = { str = 'Cd' }
    }
})
```
