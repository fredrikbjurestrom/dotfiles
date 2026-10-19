-- Keep stack-specific mappings usable globally, but only advertise them in
-- which-key for a relevant buffer/project. This never loads language plugins.
local M = {}
local cached

vim.api.nvim_create_autocmd({ 'BufEnter', 'FileType', 'BufFilePost', 'DirChanged', 'BufWritePost' }, {
  group = vim.api.nvim_create_augroup('custom-keymap-visibility', { clear = true }),
  callback = function() cached = nil end,
})

local function context()
  local buf = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  local ft, bt = vim.bo[buf].filetype, vim.bo[buf].buftype
  local cwd = vim.fn.getcwd()
  local key = { buf, name, ft, bt, cwd }
  if cached and vim.deep_equal(cached.key, key) then return cached end

  -- A real file determines its own project, even when cwd is elsewhere.
  -- Unnamed buffers, terminals and plugin windows use the current folder.
  local path = name ~= '' and bt == '' and not name:match '^%a+://' and name or cwd
  cached = {
    key = key,
    dotnet = ft == 'cs'
      or ft == 'razor'
      or vim.fs.root(path, function(entry) return entry:match '%.slnx?$' ~= nil or entry:match '%.csproj$' ~= nil end) ~= nil,
    python = ft == 'python' or ft == 'ipynb' or name:match '%.ipynb$' ~= nil or vim.fs.root(path, {
      'pyproject.toml',
      'uv.lock',
      'requirements.txt',
      'Pipfile',
      'setup.py',
      'setup.cfg',
    }) ~= nil,
  }
  return cached
end

function M.filter(mapping)
  local leader = vim.g.mapleader or '\\'
  local lhs = (mapping.lhs or ''):gsub('<[Ll]eader>', function() return leader end)
  lhs = vim.keycode(lhs)
  leader = vim.keycode(leader)
  if lhs:sub(1, #leader + 1) == leader .. 'n' then return context().dotnet end
  if lhs:sub(1, #leader + 1) == leader .. 'x' then return context().python end
  return true
end

return M
