-- Dependency hints, completion and actions only for Cargo.toml, not all TOML.
vim.pack.add({
  { src = 'https://github.com/Saecki/crates.nvim', version = 'stable' },
}, { load = true })

local crates = require 'crates'
crates.setup {
  -- Handle both existing and new manifests ourselves; upstream only autoloads
  -- on BufRead. The in-process LSP feeds the existing blink.cmp LSP source.
  autoload = false,
  lsp = { enabled = true, completion = true, hover = true, actions = true },
}

local function attach(buf)
  if not vim.api.nvim_buf_is_loaded(buf) or vim.fs.basename(vim.api.nvim_buf_get_name(buf)) ~= 'Cargo.toml' then return end
  vim.api.nvim_buf_call(buf, function()
    require('crates.lsp').start_server()
    crates.update(buf)
    local function map(lhs, action, desc, mode)
      vim.keymap.set(mode or 'n', lhs, function() action() end, { buffer = buf, silent = true, desc = 'Crates: ' .. desc })
    end
    map('K', crates.show_popup, 'Crate details')
    map('<leader>cv', crates.show_versions_popup, '[V]ersions')
    map('<leader>cf', crates.show_features_popup, '[F]eatures')
    map('<leader>cu', crates.update_crate, '[U]pdate crate (compatible version)')
    map('<leader>cu', crates.update_crates, '[U]pdate selected crates', 'x')
    map('<leader>cU', crates.update_all_crates, '[U]pdate all crates (compatible versions)')
    map('<leader>cd', crates.open_documentation, 'Open [D]ocs')
    require('which-key').add { { '<leader>c', group = '[C]rates', buffer = buf } }
  end)
end

vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
  group = vim.api.nvim_create_augroup('custom-crates', { clear = true }),
  pattern = 'Cargo.toml',
  callback = function(event) attach(event.buf) end,
})
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  attach(buf)
end
