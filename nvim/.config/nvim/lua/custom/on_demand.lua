-- Small on-demand loader for vim.pack-backed configuration modules.
-- Modules keep their normal vim.pack.add/setup calls; only their require is deferred.
local M = {}
local modules = {}
local group = vim.api.nvim_create_augroup('custom-on-demand', { clear = true })

function M.load(name)
  local spec = assert(modules[name], 'Unknown on-demand module: ' .. name)
  if spec.loaded then return true end
  if spec.loading then return false end
  spec.loading = true

  -- A dependency may already have replaced a proxy (e.g. .NET loads DAP).
  -- Only remove our own commands, never a real command installed meanwhile.
  local commands = vim.api.nvim_get_commands {}
  for command, definition in pairs(spec.proxies) do
    if commands[command] and commands[command].definition == definition then vim.api.nvim_del_user_command(command) end
  end
  spec.proxies = {}

  local ok, err = pcall(require, spec.module)
  spec.loading = false
  if not ok then
    package.loaded[spec.module] = nil
    spec.register_commands()
    vim.notify(('Could not load %s:\n%s'):format(name, err), vim.log.levels.ERROR)
    return false
  end

  spec.loaded = true
  for _, autocmd in ipairs(spec.autocmds) do
    vim.api.nvim_del_autocmd(autocmd)
  end
  spec.autocmds = {}
  return true
end

function M.register(name, spec)
  assert(not modules[name], 'On-demand module already registered: ' .. name)
  modules[name] = spec
  spec.proxies = {}
  spec.autocmds = {}

  function spec.register_commands()
    for _, command in ipairs(spec.commands or {}) do
      if vim.fn.exists(':' .. command) == 0 then
        vim.api.nvim_create_user_command(command, function(args)
          if not M.load(name) then return end
          local info = vim.api.nvim_get_commands({})[command]
          -- nargs=1/? treats the entire argument string as one argument.
          local single = info and (info.nargs == '1' or info.nargs == '?')
          local cmd = {
            cmd = command,
            args = single and args.args ~= '' and { args.args } or args.fargs,
            bang = args.bang,
            mods = args.smods,
          }
          if args.range > 0 then cmd.range = { args.line1, args.line2 } end
          vim.api.nvim_cmd(cmd, {})
        end, {
          nargs = '*',
          bang = true,
          range = true,
          desc = 'Load ' .. name .. ' and run ' .. command,
          complete = function(_, line, pos)
            if not M.load(name) then return {} end
            return vim.fn.getcompletion(line:sub(1, pos), 'cmdline')
          end,
        })
        spec.proxies[command] = vim.api.nvim_get_commands({})[command].definition
      end
    end
  end
  spec.register_commands()

  -- The real module replaces these mappings. Invoke its new mapping on the
  -- first press too, rather than making the user press the key a second time.
  for _, key in ipairs(spec.keys or {}) do
    local modes = type(key.mode) == 'table' and key.mode or { key.mode or 'n' }
    for _, mode in ipairs(modes) do
      local proxy
      proxy = function()
        if not M.load(name) then return end
        local mapping = vim.fn.maparg(key[1], mode, false, true)
        if mapping.callback == proxy or (not mapping.callback and not mapping.rhs) then
          vim.notify(('Module %s did not define %s'):format(name, key[1]), vim.log.levels.ERROR)
          return
        end
        if mapping.callback then
          mapping.callback()
        else
          vim.api.nvim_feedkeys(vim.keycode(mapping.rhs), mapping.noremap == 1 and 'n' or 'm', false)
        end
      end
      vim.keymap.set(mode, key[1], proxy, { desc = key[2], silent = true })
    end
  end

  if spec.filetypes then
    spec.autocmds[#spec.autocmds + 1] = vim.api.nvim_create_autocmd('FileType', {
      group = group,
      pattern = spec.filetypes,
      desc = 'Load ' .. name .. ' on demand',
      callback = function() M.load(name) end,
    })
  end
  -- Exact basenames, not all TOML files (e.g. crates.nvim only needs Cargo.toml).
  if spec.filenames then
    spec.autocmds[#spec.autocmds + 1] = vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
      group = group,
      pattern = spec.filenames,
      desc = 'Load ' .. name .. ' on demand',
      callback = function() M.load(name) end,
    })
  end
  -- Also support sourcing the configuration after a file is already open.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local matches_ft = spec.filetypes and vim.tbl_contains(spec.filetypes, vim.bo[buf].filetype)
    local matches_name = spec.filenames and vim.tbl_contains(spec.filenames, vim.fs.basename(vim.api.nvim_buf_get_name(buf)))
    if vim.api.nvim_buf_is_loaded(buf) and (matches_ft or matches_name) then
      vim.api.nvim_buf_call(buf, function() M.load(name) end)
      break
    end
  end
end

function M.names() return vim.tbl_keys(modules) end

function M.status()
  local lines = {}
  local names = M.names()
  table.sort(names)
  for _, name in ipairs(names) do
    lines[#lines + 1] = ('%s: %s'):format(name, modules[name].loaded and 'loaded' or 'not loaded')
  end
  return table.concat(lines, '\n')
end

return M
