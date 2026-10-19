-- debug.lua
--
-- Generic DAP (Debug Adapter Protocol) setup: nvim-dap + nvim-dap-ui.
-- Language specific adapters are registered elsewhere, e.g. C# in
-- `lua/custom/plugins/dotnet.lua` (via easy-dotnet.nvim + netcoredbg).
--
-- Keymaps are Rider-inspired:
--   F5          Start / Continue          (C# : picks project & starts debugging)
--   Shift+F5    Stop debugging
--   F9          Resume (continue)
--   F8          Step over
--   F7          Step into
--   Shift+F8    Step out
--   Ctrl+F8     Toggle breakpoint
--
-- Plus everything under <leader>d (see which-key).

-- Required on the first debug command or mapping, not at startup.
vim.pack.add({
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/rcarriga/nvim-dap-ui',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/mason-org/mason.nvim',
  'https://github.com/jay-babu/mason-nvim-dap.nvim',
}, { load = true })

local dap = require 'dap'
local dapui = require 'dapui'

---Start a new session, or continue if one is already running.
---For .NET projects we let easy-dotnet build + launch the selected project.
local function start_or_continue()
  if dap.session() then return dap.continue() end
  -- :Dotnet is an on-demand command, so F5 also works from a project folder
  -- before opening a C# file. Don't require easy-dotnet just to probe for it.
  local dotnet = package.loaded['easy-dotnet']
  local path = vim.api.nvim_buf_get_name(0) ~= '' and 0 or vim.fn.getcwd()
  local root = vim.fs.root(path, function(name) return name:match '%.slnx?$' ~= nil or name:match '%.csproj$' ~= nil end)
  if vim.bo.filetype == 'cs' or vim.bo.filetype == 'razor' or root or (dotnet and dotnet.is_dotnet_project()) then
    vim.cmd 'Dotnet debug default'
    return
  end
  dap.continue()
end

local function map(lhs, rhs, desc, mode) vim.keymap.set(mode or 'n', lhs, rhs, { desc = 'Debug: ' .. desc }) end

-- Function keys (Rider style). Some terminals send <F13>-<F24>/<F25>-<F36> for Shift/Ctrl + Fn,
-- so both variants are mapped.
map('<F5>', start_or_continue, 'Start/Continue')
map('<S-F5>', dap.terminate, 'Stop')
map('<F17>', dap.terminate, 'Stop')
map('<F9>', dap.continue, 'Resume')
map('<F8>', dap.step_over, 'Step Over')
map('<F7>', dap.step_into, 'Step Into')
map('<S-F8>', dap.step_out, 'Step Out')
map('<F20>', dap.step_out, 'Step Out')
map('<C-F8>', dap.toggle_breakpoint, 'Toggle Breakpoint')
map('<F32>', dap.toggle_breakpoint, 'Toggle Breakpoint')

-- Leader mappings
map('<leader>dc', start_or_continue, '[C]ontinue / Start')
map('<leader>db', dap.toggle_breakpoint, 'Toggle [B]reakpoint')
map('<leader>dB', function() dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, 'Conditional [B]reakpoint')
map('<leader>dl', function() dap.set_breakpoint(nil, nil, vim.fn.input 'Log point message: ') end, '[L]og point')
map('<leader>dx', dap.clear_breakpoints, 'Clear all breakpoints')
map('<leader>dL', function()
  require('dap').list_breakpoints()
  vim.cmd 'copen'
end, '[L]ist breakpoints')
map('<leader>do', dap.step_over, 'Step [O]ver')
map('<leader>di', dap.step_into, 'Step [I]nto')
map('<leader>dO', dap.step_out, 'Step [O]ut')
map('<leader>dC', dap.run_to_cursor, 'Run to [C]ursor')
map('<leader>dk', dap.up, 'Stack frame up')
map('<leader>dj', dap.down, 'Stack frame down')
map('<leader>dq', dap.terminate, '[Q]uit / Stop')
map('<leader>dR', dap.restart, '[R]estart')
map('<leader>dr', dap.repl.toggle, 'Toggle [R]EPL')
map('<leader>du', function() dapui.toggle() end, 'Toggle [U]I')
-- Evaluate expression under cursor / selection (like hovering in Rider)
map('<leader>de', function() dapui.eval() end, '[E]valuate', { 'n', 'v' })

require('mason-nvim-dap').setup {
  -- Don't auto-install/configure adapters through Mason; the C# debugger
  -- (netcoredbg) is bundled with easy-dotnet and registered by it.
  automatic_installation = false,
  handlers = {},
  ensure_installed = {},
}

-- Dap UI setup
-- For more information, see |:help nvim-dap-ui|
---@diagnostic disable-next-line: missing-fields
dapui.setup {
  icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
  ---@diagnostic disable-next-line: missing-fields
  controls = {
    icons = {
      pause = '⏸',
      play = '▶',
      step_into = '⏎',
      step_over = '⏭',
      step_out = '⏮',
      step_back = 'b',
      run_last = '▶▶',
      terminate = '⏹',
      disconnect = '⏏',
    },
  },
}

-- Breakpoint icons / colors
vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
vim.api.nvim_set_hl(0, 'DapStoppedLine', { bg = '#3a3a1e' })
local breakpoint_icons = vim.g.have_nerd_font and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
  or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
for type, icon in pairs(breakpoint_icons) do
  local tp = 'Dap' .. type
  local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
  vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl, linehl = (type == 'Stopped') and 'DapStoppedLine' or nil })
end

dap.listeners.after.event_initialized['dapui_config'] = dapui.open
dap.listeners.before.event_terminated['dapui_config'] = dapui.close
dap.listeners.before.event_exited['dapui_config'] = dapui.close
