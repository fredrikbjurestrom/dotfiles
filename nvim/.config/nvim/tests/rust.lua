-- Offline test: nvim --clean --headless -l tests/rust.lua
-- Stub plugin installation/APIs, but exercise real events and buffer mappings.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.g.mapleader = ' '
vim.cmd 'filetype plugin on'
local root = vim.fn.tempname()
for _, dir in ipairs { 'plugin/ftplugin', 'project', 'second', 'new', 'plain' } do
  vim.fn.mkdir(root .. '/' .. dir, 'p')
end
vim.fn.writefile({
  'vim.g.test_rust_ftplugins = (vim.g.test_rust_ftplugins or 0) + 1',
  'vim.g.rustaceanvim.server.on_attach({}, vim.api.nvim_get_current_buf())',
}, root .. '/plugin/ftplugin/rust.lua')
vim.fn.writefile({}, root .. '/plain/pyproject.toml')
vim.fn.writefile({}, root .. '/project/Cargo.lock')
vim.fn.writefile({}, root .. '/project/Cargo.toml')
vim.fn.writefile({}, root .. '/second/Cargo.toml')

local packs, updates, lsp_buffers, groups = {}, {}, {}, {}
vim.pack.add = function(specs)
  for _, spec in ipairs(specs) do
    packs[#packs + 1] = spec.src
    if spec.src:find('rustaceanvim', 1, true) then vim.opt.runtimepath:append(root .. '/plugin') end
  end
end
local conform = { formatters_by_ft = {} }
package.preload['conform'] = function() return conform end
package.preload['which-key'] = function()
  return { add = function(specs) vim.list_extend(groups, specs) end }
end
local crates_cfg
local crates = {
  setup = function(cfg) crates_cfg = cfg end,
  update = function(buf) updates[#updates + 1] = buf end,
}
for _, method in ipairs { 'show_popup', 'show_versions_popup', 'show_features_popup', 'update_crate', 'update_crates', 'update_all_crates', 'open_documentation' } do
  crates[method] = function() end
end
package.preload['crates'] = function() return crates end
package.preload['crates.lsp'] = function()
  return { start_server = function() lsp_buffers[#lsp_buffers + 1] = vim.api.nvim_get_current_buf() end }
end

local function equal(expected, actual) assert(vim.deep_equal(expected, actual), ('Expected %s, got %s'):format(vim.inspect(expected), vim.inspect(actual))) end
local function mapping(lhs, mode) return vim.fn.maparg(lhs, mode or 'n', false, true) end
local function rust_unloaded()
  assert(not package.loaded['custom.plugins.rust'])
  assert(not conform.formatters_by_ft.rust)
  assert(not vim.g.rustaceanvim)
end

require 'custom.plugins'
equal(0, #packs)
rust_unloaded()
assert(not package.loaded['custom.plugins.crates'])
equal({}, mapping '<leader>rr')
equal({}, mapping '<leader>cu')

vim.cmd.edit(root .. '/plain/pyproject.toml')
equal(0, #packs)
vim.cmd.edit(root .. '/project/Cargo.lock')
equal(0, #packs)
vim.cmd.edit(root .. '/project/Cargo.toml')
equal({ 'https://github.com/Saecki/crates.nvim' }, packs)
rust_unloaded()
equal(false, crates_cfg.autoload)
equal(true, crates_cfg.lsp.completion)
equal({ vim.api.nvim_get_current_buf() }, updates)
equal(updates, lsp_buffers)
equal(1, mapping('<leader>cu').buffer)
equal(1, mapping('<leader>cu', 'x').buffer)
equal(1, mapping('K').buffer)
equal({}, mapping '<leader>rr')

vim.cmd.edit(root .. '/second/Cargo.toml')
equal(2, #updates)
equal(1, #packs)
equal(1, mapping('<leader>cf').buffer)
vim.cmd.edit(root .. '/new/Cargo.toml')
equal(3, #updates)
equal(updates, lsp_buffers)
equal(1, mapping('<leader>cv').buffer)

vim.cmd.edit(root .. '/project/main.rs')
equal(2, #packs)
equal('https://github.com/mrcjkb/rustaceanvim', packs[2])
equal(1, vim.g.test_rust_ftplugins) -- first Rust buffer isn't missed
equal({ 'rustfmt' }, conform.formatters_by_ft.rust)
equal('clippy', vim.g.rustaceanvim.server.default_settings['rust-analyzer'].check.command)
equal(false, vim.g.rustaceanvim.dap.autoload_configurations)
equal(1, mapping('<leader>rr').buffer)
equal('<cmd>RustLsp run<CR>', mapping('<leader>rr').rhs)
equal(1, mapping('<leader>rt').buffer)
equal({}, mapping '<leader>cu')

vim.cmd.edit(root .. '/project/lib.rs')
equal(2, vim.g.test_rust_ftplugins) -- later Rust buffers use normal ftplugin loading
equal(2, #packs)
equal(1, mapping('<leader>rm').buffer)
vim.cmd.edit(root .. '/plain/readme.md')
equal({}, mapping '<leader>rr')
equal({}, mapping '<leader>cu')
equal({}, mapping 'K')
equal(2, #packs)
for _, group in ipairs(groups) do
  if group.group == '[R]ust' or group.group == '[C]rates' then assert(group.buffer) end
end
assert(not package.loaded['easy-dotnet'])
assert(not package.loaded['uv'])
assert(not package.loaded['dap'])
assert(not package.loaded['dapui'])
vim.fn.delete(root, 'rf')
print 'Rust lazy-loading tests passed'
