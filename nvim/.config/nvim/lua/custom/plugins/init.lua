-- Register triggers, not plugins. Add new modules explicitly below; files in
-- this directory are no longer automatically required at startup.
local on_demand = require 'custom.on_demand'

-- No global command/key proxies: these tools only load for Rust/Cargo buffers
-- (or explicitly through :OnDemand), and their mappings stay buffer-local.
on_demand.register('rust', {
  module = 'custom.plugins.rust',
  filetypes = { 'rust' },
})
on_demand.register('crates', {
  module = 'custom.plugins.crates',
  filenames = { 'Cargo.toml' },
})

on_demand.register('dotnet', {
  module = 'custom.plugins.dotnet',
  filetypes = { 'cs', 'razor' },
  commands = { 'Dotnet', 'DotnetStop' },
  keys = {
    { '<leader>nr', '.NET: [R]un (default project)' },
    { '<leader>nR', '.NET: [R]un with launch profile' },
    { '<leader>nd', '.NET: [D]ebug (default project)' },
    { '<leader>nD', '.NET: [D]ebug with launch profile' },
    { '<leader>na', '.NET: Debug [A]ttach to process' },
    { '<leader>nb', '.NET: [B]uild (default project)' },
    { '<leader>nB', '.NET: [B]uild solution' },
    { '<leader>nt', '.NET: [T]est runner' },
    { '<leader>nT', '.NET: [T]est solution' },
    { '<leader>nw', '.NET: [W]atch' },
    { '<leader>ns', '.NET: [S]top running app' },
    { '<leader>nc', '.NET: [C]lean' },
    { '<leader>no', '.NET: Rest[o]re' },
    { '<leader>np', '.NET: Add NuGet [P]ackage' },
    { '<leader>nP', '.NET: Remove NuGet [P]ackage' },
    { '<leader>nn', '.NET: [N]ew project/template' },
    { '<leader>nS', '.NET: User [S]ecrets' },
    { '<leader>ne', '.NET: Solution [E]rrors' },
    { '<leader>nE', '.NET: Solution [E]rrors + warnings' },
    { '<leader>nx', '.NET: Reset selected solution/project' },
    { '<leader>ni', '.NET: New [I]tem (class/interface/...) here' },
  },
})

on_demand.register('python', {
  module = 'custom.plugins.uv',
  filetypes = { 'python' },
  commands = {
    'UVInit',
    'UVRunSelection',
    'UVRunFunction',
    'UVRunFile',
    'UVAddPackage',
    'UVRemovePackage',
    'UVAutoActivateToggle',
    'UVAutoActivateToggleBuffer',
  },
  keys = {
    { '<leader>x', 'UV Commands (Telescope)', mode = { 'n', 'v' } },
    { '<leader>xr', 'UV Run Current File' },
    { '<leader>xs', 'UV Run Selection', mode = 'v' },
    { '<leader>xf', 'UV Run Function' },
    { '<leader>xe', 'UV Environment (Telescope)' },
    { '<leader>xi', 'UV Init' },
    { '<leader>xa', 'UV Add Package' },
    { '<leader>xd', 'UV Remove Package' },
    { '<leader>xc', 'UV Sync Packages' },
    { '<leader>xC', 'UV Sync All Extras, Groups and Packages' },
  },
})

on_demand.register('debug', {
  module = 'kickstart.plugins.debug',
  commands = {
    'DapContinue',
    'DapToggleBreakpoint',
    'DapClearBreakpoints',
    'DapToggleRepl',
    'DapStepOver',
    'DapStepInto',
    'DapStepOut',
    'DapTerminate',
    'DapDisconnect',
    'DapRestartFrame',
    'DapPause',
    'DapNew',
    'DapEval',
    'DapSetLogLevel',
    'DapShowLog',
  },
  keys = {
    { '<F5>', 'Debug: Start/Continue' },
    { '<S-F5>', 'Debug: Stop' },
    { '<F17>', 'Debug: Stop' },
    { '<F9>', 'Debug: Resume' },
    { '<F8>', 'Debug: Step Over' },
    { '<F7>', 'Debug: Step Into' },
    { '<S-F8>', 'Debug: Step Out' },
    { '<F20>', 'Debug: Step Out' },
    { '<C-F8>', 'Debug: Toggle Breakpoint' },
    { '<F32>', 'Debug: Toggle Breakpoint' },
    { '<leader>dc', 'Debug: [C]ontinue / Start' },
    { '<leader>db', 'Debug: Toggle [B]reakpoint' },
    { '<leader>dB', 'Debug: Conditional [B]reakpoint' },
    { '<leader>dl', 'Debug: [L]og point' },
    { '<leader>dx', 'Debug: Clear all breakpoints' },
    { '<leader>dL', 'Debug: [L]ist breakpoints' },
    { '<leader>do', 'Debug: Step [O]ver' },
    { '<leader>di', 'Debug: Step [I]nto' },
    { '<leader>dO', 'Debug: Step [O]ut' },
    { '<leader>dC', 'Debug: Run to [C]ursor' },
    { '<leader>dk', 'Debug: Stack frame up' },
    { '<leader>dj', 'Debug: Stack frame down' },
    { '<leader>dq', 'Debug: [Q]uit / Stop' },
    { '<leader>dR', 'Debug: [R]estart' },
    { '<leader>dr', 'Debug: Toggle [R]EPL' },
    { '<leader>du', 'Debug: Toggle [U]I' },
    { '<leader>de', 'Debug: [E]valuate', mode = { 'n', 'v' } },
  },
})

on_demand.register('lazygit', {
  module = 'custom.plugins.lazygit',
  commands = { 'LazyGit', 'LazyGitLog', 'LazyGitCurrentFile', 'LazyGitFilter', 'LazyGitFilterCurrentFile', 'LazyGitConfig' },
  keys = { { '<leader>lg', 'LazyGit' } },
})

require('which-key').add {
  { '<leader>n', group = '.[N]ET' },
  { '<leader>d', group = '[D]ebug', mode = { 'n', 'v' } },
}

-- :OnDemand lists what has been loaded; :OnDemand dotnet loads it manually.
vim.api.nvim_create_user_command('OnDemand', function(args)
  if args.args == '' then
    vim.notify(on_demand.status(), vim.log.levels.INFO)
  elseif vim.tbl_contains(on_demand.names(), args.args) then
    on_demand.load(args.args)
  else
    vim.notify('Unknown module: ' .. args.args, vim.log.levels.ERROR)
  end
end, {
  nargs = '?',
  desc = 'Show or load on-demand modules',
  complete = function() return on_demand.names() end,
})
