-- Required on the first LazyGit command or <leader>lg.
vim.pack.add({
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/kdheepak/lazygit.nvim',
}, { load = true })

vim.keymap.set('n', '<leader>lg', function() vim.cmd 'LazyGit' end, { desc = 'LazyGit' })
