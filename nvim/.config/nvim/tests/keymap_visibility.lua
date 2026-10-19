-- Run from the config directory: nvim --clean --headless -l tests/keymap_visibility.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.g.mapleader = ' '
local visibility = require 'custom.keymap_visibility'
local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/python/src', 'p')
vim.fn.mkdir(root .. '/dotnet/src', 'p')
vim.fn.mkdir(root .. '/plain', 'p')
vim.fn.writefile({}, root .. '/python/pyproject.toml')
vim.fn.writefile({}, root .. '/dotnet/Example.slnx')
vim.cmd.cd(root .. '/plain')

local function check(dotnet, python)
  assert(visibility.filter { lhs = '<leader>n' } == dotnet)
  assert(visibility.filter { lhs = '<Space>nb' } == dotnet)
  assert(visibility.filter { lhs = ' nr' } == dotnet)
  assert(visibility.filter { lhs = '<leader>x' } == python)
  assert(visibility.filter { lhs = '<Space>xr' } == python)
  assert(visibility.filter { lhs = ' xs' } == python)
  assert(visibility.filter { lhs = '<leader>d' })
  assert(visibility.filter { lhs = '<leader>f' })
  assert(visibility.filter { lhs = '<leader>u' })
end

check(false, false)
vim.bo.filetype = 'python'
check(false, true)
vim.bo.filetype = 'cs'
check(true, false)
vim.bo.filetype = 'razor'
check(true, false)
vim.bo.filetype = 'lua'
check(false, false)

-- Project hints are useful in other filetypes, e.g. a project's README/JSON.
vim.api.nvim_buf_set_name(0, root .. '/python/src/main.js')
vim.bo.filetype = 'javascript'
check(false, true)
vim.cmd.cd(root .. '/dotnet')
check(false, true) -- current file's project wins over cwd

vim.cmd.enew()
check(true, false) -- unnamed buffer uses cwd
vim.api.nvim_buf_set_name(0, root .. '/dotnet/src/app.json')
vim.bo.filetype = 'json'
check(true, false)
vim.cmd.cd(root .. '/plain')
check(true, false)

vim.api.nvim_buf_set_name(0, root .. '/plain/analysis.ipynb')
check(false, true)
vim.api.nvim_buf_set_name(0, root .. '/plain/readme.md')
vim.bo.filetype = 'markdown'
check(false, false)

-- Creating a project marker invalidates the context after a write.
vim.fn.writefile({}, root .. '/plain/uv.lock')
vim.api.nvim_exec_autocmds('BufWritePost', { buffer = 0 })
check(false, true)
vim.fn.writefile({}, root .. '/plain/App.csproj')
vim.api.nvim_exec_autocmds('BufWritePost', { buffer = 0 })
check(true, true)

-- Loading a module never forces its hints to stay visible in other projects.
package.loaded['easy-dotnet'] = {}
package.loaded['uv'] = {}
vim.fn.delete(root .. '/plain/uv.lock')
vim.fn.delete(root .. '/plain/App.csproj')
vim.api.nvim_exec_autocmds('BufWritePost', { buffer = 0 })
check(false, false)
package.loaded['easy-dotnet'] = nil
package.loaded['uv'] = nil

vim.g.mapleader = '_'
assert(not visibility.filter { lhs = '_nb' })
assert(not visibility.filter { lhs = '<leader>xr' })
vim.bo.filetype = 'python'
assert(visibility.filter { lhs = '_xr' })
assert(visibility.filter { lhs = '<leader>x' })
assert(visibility.filter { lhs = '<Space>nb' }) -- not the current leader

assert(not package.loaded['custom.on_demand'])
assert(not package.loaded['easy-dotnet'])
assert(not package.loaded['uv'])
assert(not package.loaded['dap'])
vim.fn.delete(root, 'rf')
print 'Keymap visibility tests passed'
