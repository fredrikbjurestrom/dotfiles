-- Rust-only helpers. Required on the first Rust buffer, never at startup.
-- Prerequisites: rustup component add rust-analyzer rust-src clippy rustfmt
-- rustaceanvim owns the LSP; do not also enable lspconfig's rust_analyzer.
vim.g.rustaceanvim = {
  server = {
    default_settings = {
      ['rust-analyzer'] = {
        check = { command = 'clippy' },
        cargo = { buildScripts = { enable = true } },
        procMacro = { enable = true },
      },
    },
    on_attach = function(_, bufnr)
      local function map(lhs, command, desc)
        vim.keymap.set('n', lhs, '<cmd>RustLsp ' .. command .. '<CR>', { buffer = bufnr, silent = true, desc = 'Rust: ' .. desc })
      end
      map('K', 'hover actions', 'Hover actions')
      map('<leader>rr', 'run', '[R]un target under cursor')
      map('<leader>rR', 'runnables', 'Pick [R]unnable')
      map('<leader>rt', 'testables', 'Pick [T]est')
      map('<leader>ra', 'codeAction', 'Code [A]ctions')
      map('<leader>rm', 'expandMacro', 'Expand [M]acro')
      map('<leader>re', 'explainError', '[E]xplain error')
      map('<leader>rc', 'flyCheck run', '[C]heck with Clippy')
      map('<leader>ro', 'openCargo', '[O]pen Cargo.toml')
      map('<leader>rd', 'openDocs', 'Open [D]ocs')
      require('which-key').add { { '<leader>r', group = '[R]ust', buffer = bufnr } }
    end,
  },
  -- Don't load the generic debugger just because a Rust file was opened.
  dap = { autoload_configurations = false },
}

vim.pack.add({
  { src = 'https://github.com/mrcjkb/rustaceanvim', version = vim.version.range '^9' },
}, { load = true })

-- Reuse the existing <leader>f mapping; no format-on-save policy change.
require('conform').formatters_by_ft.rust = { 'rustfmt' }

-- FileType's normal ftplugin handler has already run when this module loads.
-- Source the newly added ftplugin for existing Rust buffers too, so the FIRST
-- Rust file gets its LSP immediately. Future buffers use normal ftplugin loading.
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'rust' then vim.api.nvim_buf_call(buf, function() vim.cmd 'runtime! ftplugin/rust.lua' end) end
end
