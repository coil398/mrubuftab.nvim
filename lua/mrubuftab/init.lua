local M = {}

M.mru_list = {}

-- 1. アイコン取得用の関数をあらかじめ定義しておく
local get_icon = function(_, _) return "" end

-- プラグインがあるか一度だけチェック
local has_devicons, devicons = pcall(require, "nvim-web-devicons")
if has_devicons then
  get_icon = function(name, ext)
    local icon, _ = devicons.get_icon(name, ext, { default = true })
    return icon and (icon .. " ") or ""
  end
end

local function remove_value(list, value)
  for i, v in ipairs(list) do
    if v == value then
      table.remove(list, i)
      return
    end
  end
end

function M.render()
  local s = ""
  local cur = vim.api.nvim_get_current_buf()
  
  local valid_mru = {}
  for _, bufnr in ipairs(M.mru_list) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted then
      table.insert(valid_mru, bufnr)
    end
  end
  M.mru_list = valid_mru

  for i, bufnr in ipairs(M.mru_list) do
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local name = vim.fn.fnamemodify(filename, ":t")
    local ext = vim.fn.fnamemodify(filename, ":e")
    if name == "" then name = "[No Name]" end

    -- 2. アイコン・未保存マークの取得 (定義済みの関数を呼ぶだけなので高速)
    local icon = get_icon(name, ext)
    local modified = vim.bo[bufnr].modified and " ●" or ""

    -- 3. ハイライトの設定
    if bufnr == cur then
      s = s .. "%#TabLineSel#"
    else
      s = s .. "%#TabLine#"
    end

    -- 表示の組み立て (例:   1:init.lua ● )
    s = s .. " " .. icon .. i .. ":" .. name .. modified .. " "
    
    -- バッファ間の区切り線
    s = s .. "%#TabLine#|"
  end

  s = s .. "%#TabLineFill#"
  return s
end

function M.jump(count)
  local target_idx = (count and count > 0) and count or 2
  local target_buf = M.mru_list[target_idx]
  if target_buf and vim.api.nvim_buf_is_valid(target_buf) then
    vim.api.nvim_set_current_buf(target_buf)
  end
end

function M.next(count)
  -- カウントが指定されていればその番号へ、なければ2番目（直前のバッファ）へ
  local target = (count and count > 0) and count or 2
  M.jump(target)
end

function M.prev(count)
  -- カウントが指定されていれば「後ろからN番目」、なければ「一番最後」
  local c = (count and count > 0) and count or 1
  local target_idx = #M.mru_list - (c - 1)
  
  if target_idx < 1 then target_idx = 1 end

  local target_buf = M.mru_list[target_idx]
  if target_buf and vim.api.nvim_buf_is_valid(target_buf) then
    vim.api.nvim_set_current_buf(target_buf)
  end
end

function M.setup(opts)
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = vim.api.nvim_create_augroup("MruTabline", { clear = true }),
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      if not vim.bo[bufnr].buflisted or vim.bo[bufnr].buftype ~= "" then return end
      remove_value(M.mru_list, bufnr)
      table.insert(M.mru_list, 1, bufnr)
      vim.cmd("redrawtabline")
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = vim.api.nvim_create_augroup("MruTablineCleanup", { clear = true }),
    callback = function(args)
      remove_value(M.mru_list, args.buf)
      vim.cmd("redrawtabline")
    end,
  })

  vim.opt.tabline = "%!v:lua.require(\"mrubuftab\").render()"

  vim.api.nvim_create_user_command("MruNext", function(opts)
    require("mrubuftab").next(opts.count > 0 and opts.count or nil)
  end, { count = true })

  vim.api.nvim_create_user_command("MruPrev", function(opts)
    require("mrubuftab").prev(opts.count > 0 and opts.count or nil)
  end, { count = true })
end

return M
