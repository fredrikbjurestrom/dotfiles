-- Run from the config directory: nvim --clean --headless -l tests/on_demand.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.g.mapleader = ' '
local on_demand = require 'custom.on_demand'
local notifications = {}
vim.notify = function(message) notifications[#notifications + 1] = message end

local function equal(expected, actual) assert(vim.deep_equal(expected, actual), ('Expected %s, got %s'):format(vim.inspect(expected), vim.inspect(actual))) end

local loads, calls = 0, 0
package.preload['test.on-demand.filetype'] = function()
  loads = loads + 1
  vim.keymap.set('n', '<leader>zz', function() calls = calls + 1 end)
  return true
end
on_demand.register('filetype', {
  module = 'test.on-demand.filetype',
  filetypes = { 'python', 'cs' },
  keys = { { '<leader>zz', 'Test action' } },
})
equal(0, loads)
vim.fn.maparg('<leader>zz', 'n', false, true).callback()
equal(1, loads)
equal(1, calls)
vim.bo.filetype = 'python'
vim.bo.filetype = 'cs'
on_demand.load 'filetype'
equal(1, loads)

local ft_loads = 0
package.preload['test.on-demand.first-buffer'] = function()
  ft_loads = ft_loads + 1
  return true
end
on_demand.register('first-buffer', { module = 'test.on-demand.first-buffer', filetypes = { 'javascript' } })
equal(0, ft_loads)
vim.bo.filetype = 'javascript'
equal(1, ft_loads)
vim.bo.filetype = 'lua'
vim.bo.filetype = 'javascript'
equal(1, ft_loads)

local existing_loads = 0
package.preload['test.on-demand.existing-buffer'] = function()
  existing_loads = existing_loads + 1
  return true
end
on_demand.register('existing-buffer', { module = 'test.on-demand.existing-buffer', filetypes = { 'javascript' } })
equal(1, existing_loads)

-- Filename triggers must not load for unrelated files with the same filetype.
local manifests = vim.fn.tempname()
vim.fn.mkdir(manifests .. '/existing', 'p')
vim.fn.mkdir(manifests .. '/new', 'p')
vim.fn.writefile({}, manifests .. '/existing/Cargo.toml')
vim.fn.writefile({}, manifests .. '/existing/pyproject.toml')
local filename_loads = 0
package.preload['test.on-demand.filename'] = function()
  filename_loads = filename_loads + 1
  return true
end
on_demand.register('filename', { module = 'test.on-demand.filename', filenames = { 'Cargo.toml' } })
vim.cmd.edit(manifests .. '/existing/pyproject.toml')
vim.bo.filetype = 'toml'
equal(0, filename_loads)
vim.cmd.edit(manifests .. '/existing/Cargo.toml')
equal(1, filename_loads)
vim.cmd.edit(manifests .. '/new/Cargo.toml')
equal(1, filename_loads)

local new_file_loads = 0
package.preload['test.on-demand.new-file'] = function()
  new_file_loads = new_file_loads + 1
  return true
end
on_demand.register('new-file', { module = 'test.on-demand.new-file', filenames = { 'NewCargo.toml' } })
vim.cmd.edit(manifests .. '/new/NewCargo.toml')
equal(1, new_file_loads)

-- Re-sourcing with a matching non-current buffer must use that buffer's context.
local existing_manifest = vim.fn.bufnr(manifests .. '/existing/Cargo.toml')
vim.fn.bufload(existing_manifest)
local loaded_in
package.preload['test.on-demand.existing-file'] = function()
  loaded_in = vim.api.nvim_get_current_buf()
  return true
end
on_demand.register('existing-file', { module = 'test.on-demand.existing-file', filenames = { 'Cargo.toml' } })
equal(existing_manifest, loaded_in)
assert(vim.api.nvim_get_current_buf() ~= loaded_in)
vim.fn.delete(manifests, 'rf')

local command_loads, received = 0, nil
package.preload['test.on-demand.command'] = function()
  command_loads = command_loads + 1
  vim.api.nvim_create_user_command('TestOnDemand', function(args) received = args end, { nargs = '*', bang = true, range = true })
  return true
end
on_demand.register('command', { module = 'test.on-demand.command', commands = { 'TestOnDemand' } })
equal(0, command_loads)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'two', 'three' })
vim.cmd '1,2TestOnDemand! alpha beta'
equal(1, command_loads)
equal({ 'alpha', 'beta' }, received.fargs)
equal(true, received.bang)
equal(1, received.line1)
equal(2, received.line2)
vim.cmd 'TestOnDemand gamma'
equal(1, command_loads)
equal('gamma', received.args)

local single_argument
package.preload['test.on-demand.single-argument'] = function()
  vim.api.nvim_create_user_command('TestSingleArgument', function(args) single_argument = args.args end, { nargs = 1 })
  return true
end
on_demand.register('single-argument', { module = 'test.on-demand.single-argument', commands = { 'TestSingleArgument' } })
vim.cmd 'TestSingleArgument alpha beta'
equal('alpha beta', single_argument)

local completion_loads = 0
package.preload['test.on-demand.completion'] = function()
  completion_loads = completion_loads + 1
  vim.api.nvim_create_user_command('TestCompletion', function() end, {
    nargs = '*',
    complete = function() return { 'hello' } end,
  })
  return true
end
on_demand.register('completion', { module = 'test.on-demand.completion', commands = { 'TestCompletion' } })
equal({ 'hello' }, vim.fn.getcompletion('TestCompletion h', 'cmdline'))
equal(1, completion_loads)

-- A dependency can install real commands before its own setup module loads.
package.preload['test.on-demand.dependency'] = function() return true end
on_demand.register('dependency', { module = 'test.on-demand.dependency', commands = { 'TestDependency' } })
local dependency_calls = 0
vim.api.nvim_create_user_command('TestDependency', function() dependency_calls = dependency_calls + 1 end, {})
assert(on_demand.load 'dependency')
vim.cmd 'TestDependency'
equal(1, dependency_calls)

local string_calls, visual_calls = 0, 0
vim.api.nvim_create_user_command('TestStringMapping', function() string_calls = string_calls + 1 end, {})
package.preload['test.on-demand.string-mapping'] = function()
  vim.keymap.set('n', '<leader>zy', '<cmd>TestStringMapping<CR>')
  vim.keymap.set('v', '<leader>zv', function() visual_calls = visual_calls + 1 end)
  return true
end
on_demand.register('string-mapping', {
  module = 'test.on-demand.string-mapping',
  keys = { { '<leader>zy', 'String mapping' }, { '<leader>zv', 'Visual mapping', mode = 'v' } },
})
local visual_proxy = vim.fn.maparg('<leader>zv', 'v', false, true).callback
vim.fn.maparg('<leader>zy', 'n', false, true).callback()
vim.api.nvim_feedkeys('', 'x', false)
equal(1, string_calls)
visual_proxy()
equal(1, visual_calls)

-- First-use visual string mappings must preserve the selection and mode.
local selection
vim.api.nvim_create_user_command('TestSelection', function() selection = { vim.fn.line "'<", vim.fn.line "'>" } end, {})
package.preload['test.on-demand.selection'] = function()
  vim.keymap.set('v', '<leader>zw', ':<C-u>TestSelection<CR>')
  return true
end
on_demand.register('selection', {
  module = 'test.on-demand.selection',
  keys = { { '<leader>zw', 'Test selection', mode = 'v' } },
})
vim.api.nvim_feedkeys(vim.keycode 'ggVj zw', 'xt', false)
equal({ 1, 2 }, selection)

local attempts, retry_calls = 0, 0
package.preload['test.on-demand.retry'] = function()
  attempts = attempts + 1
  if attempts == 1 then error 'Expected test failure' end
  vim.api.nvim_create_user_command('TestRetry', function() retry_calls = retry_calls + 1 end, {})
  return true
end
on_demand.register('retry', { module = 'test.on-demand.retry', commands = { 'TestRetry' } })
vim.cmd 'TestRetry'
equal(1, attempts)
equal(0, retry_calls)
vim.cmd 'TestRetry'
equal(2, attempts)
equal(1, retry_calls)
equal(1, #notifications)
assert(notifications[1]:find('Expected test failure', 1, true))
assert(on_demand.status():find('retry: loaded', 1, true))

print 'On-demand loader tests passed'
