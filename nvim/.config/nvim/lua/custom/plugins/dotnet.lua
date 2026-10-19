-- dotnet.lua
--
-- C# / .NET support via easy-dotnet.nvim:
--   * Roslyn LSP (same language server as VS Code / Visual Studio)
--   * Debugging with netcoredbg (bundled with easy-dotnet-server), wired into nvim-dap
--   * Build / run / test runner / NuGet / user-secrets / EF commands (`:Dotnet`)
--
-- Prerequisites (one-time):
--   dotnet tool install -g EasyDotnet
--   dotnet tool install -g roslyn-language-server --prerelease   (auto-installed if missing)
-- Check status with `:checkhealth easy-dotnet`.

-- Make sure global dotnet tools (dotnet-easydotnet, roslyn-language-server, ...) are found,
-- even if ~/.dotnet/tools isn't on the shell PATH.
local dotnet_tools = vim.fs.joinpath(vim.env.HOME, '.dotnet', 'tools')
if vim.uv.fs_stat(dotnet_tools) and not vim.env.PATH:find(dotnet_tools, 1, true) then vim.env.PATH = dotnet_tools .. ':' .. vim.env.PATH end

-- Required on the first C#/Razor file, Dotnet command, or .NET mapping.
vim.pack.add({
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/GustavEikaas/easy-dotnet.nvim',
}, { load = true })

local dotnet = require 'easy-dotnet'
local debug_ui_loaded = package.loaded['dapui'] ~= nil

dotnet.setup {
  picker = 'telescope',
  lsp = {
    enabled = true, -- Roslyn LSP
    roslynator_enabled = true,
    auto_refresh_codelens = false, -- hide the "N references" CodeLens above methods
  },
  debugger = {
    -- Uses the netcoredbg bundled with easy-dotnet-server
    engine = 'netcoredbg',
    console = 'integratedTerminal', -- program output in dap-ui console
    auto_register_dap = true,
  },
  test_runner = {
    viewmode = 'float',
    -- Buffer-local mappings inside test files. Remapped so they don't shadow
    -- the global <leader>d (debug) / <leader>t (toggle) groups.
    mappings = {
      run_test_from_buffer = { lhs = '<leader>rt', desc = 'Run test under cursor' },
      run_all_tests_from_buffer = { lhs = '<leader>rT', desc = 'Run all tests in file' },
      debug_test_from_buffer = { lhs = '<leader>dt', desc = 'Debug test under cursor' },
      peek_stack_trace_from_buffer = { lhs = '<leader>rp', desc = 'Peek test stack trace' },
    },
  },
  auto_bootstrap_namespace = {
    type = 'file_scoped',
    enabled = true,
  },
}

-- A session started through :Dotnet debug bypasses the generic debug mappings.
-- Load the UI before DAP handles its first initialized event as well.
require('dap').listeners.before.event_initialized['custom-on-demand-debug'] = function()
  if require('custom.on_demand').load 'debug' then
    -- easy-dotnet registers these during setup only if dapui is available.
    if not debug_ui_loaded then require('easy-dotnet.netcoredbg.sys_monitor_dap_ui').setup() end
    return true -- remove this one-shot listener
  end
end

-- Show the active .NET project/profile and whether it is running or debugging
-- in mini.statusline's file-info area.
local statusline = require 'mini.statusline'
local original_fileinfo = statusline.section_fileinfo
statusline.section_fileinfo = function(args)
  local fileinfo = original_fileinfo(args)
  local active_project = require('easy-dotnet.active-project').lualine()
  local sessions = require('easy-dotnet.running-sessions').projects

  local state
  if #sessions > 0 then
    state = vim.iter(sessions):any(function(session) return session.isDebugging end) and 'DEBUG' or 'RUN'
  elseif active_project ~= '' then
    state = 'IDLE'
  else
    return fileinfo
  end

  local project = active_project
  if project == '' then project = table.concat(vim.tbl_map(function(session) return session.name end, sessions), ', ') end
  local dotnet_info = ('NET %s: %s'):format(state, project)
  return fileinfo == '' and dotnet_info or (fileinfo .. '  ' .. dotnet_info)
end

-- [[ Keymaps: <leader>n = .NET ]]
local function cmd(lhs, command, desc) vim.keymap.set('n', lhs, '<cmd>Dotnet ' .. command .. '<CR>', { desc = '.NET: ' .. desc }) end

cmd('<leader>nr', 'run default', '[R]un (default project)')
cmd('<leader>nR', 'run profile', '[R]un with launch profile')
cmd('<leader>nd', 'debug default', '[D]ebug (default project)')
cmd('<leader>nD', 'debug profile', '[D]ebug with launch profile')
cmd('<leader>na', 'debug attach', 'Debug [A]ttach to process')
cmd('<leader>nb', 'build default quickfix', '[B]uild (default project)')
cmd('<leader>nB', 'build solution quickfix', '[B]uild solution')
cmd('<leader>nt', 'testrunner', '[T]est runner')
cmd('<leader>nT', 'test solution', '[T]est solution')
cmd('<leader>nw', 'watch default', '[W]atch')
vim.keymap.set('n', '<leader>ns', dotnet.stop, { desc = '.NET: [S]top running app' })
vim.api.nvim_create_user_command('DotnetStop', dotnet.stop, { desc = 'Stop running .NET apps' })
cmd('<leader>nc', 'clean', '[C]lean')
cmd('<leader>no', 'restore', 'Rest[o]re')
cmd('<leader>np', 'add package', 'Add NuGet [P]ackage')
cmd('<leader>nP', 'remove package', 'Remove NuGet [P]ackage')
cmd('<leader>nn', 'new', '[N]ew project/template')
cmd('<leader>nS', 'secrets', 'User [S]ecrets')
cmd('<leader>ne', 'diagnostic', 'Solution [E]rrors')
cmd('<leader>nE', 'diagnostic warnings', 'Solution [E]rrors + warnings')
cmd('<leader>nx', 'reset', 'Reset selected solution/project')
vim.keymap.set('n', '<leader>ni', function()
  local dir = vim.fn.expand '%:p:h'
  if dir == '' then dir = vim.fn.getcwd() end
  dotnet.create_item(dir)
end, { desc = '.NET: New [I]tem (class/interface/...) here' })

require('which-key').add {
  { '<leader>n', group = '.[N]ET' },
  { '<leader>d', group = '[D]ebug', mode = { 'n', 'v' } },
  { '<leader>r', group = '[R]un tests' },
}
