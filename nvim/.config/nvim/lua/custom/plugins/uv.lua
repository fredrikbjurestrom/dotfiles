-- Required once, on the first Python file, UV command, or UV mapping.
vim.pack.add({
  'https://github.com/nvim-telescope/telescope.nvim',
  'https://github.com/benomahony/uv.nvim',
}, { load = true })

require('uv').setup {
  picker_integration = true,
}
