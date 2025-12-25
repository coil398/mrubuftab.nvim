local M = {}

M.mru_list = {}

-- 1. アイコンと色情報(ハイライトグループ)を返す関数
local get_icon_data = function(_, _) return "", "" end

-- プラグインがあるか一度だけチェック
local has_devicons, devicons = pcall(require, "nvim-web-devicons")
if has_devicons then
  get_icon_data = function(name, ext)
    local icon, icon_hl = devicons.get_icon(name, ext, { default = true })
    return icon or "", icon_hl or ""
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

    -- 2. アイコン・未保存マークの取得
    local icon_char, icon_hl = get_icon_data(name, ext)
    local modified = vim.bo[bufnr].modified and " ●" or ""

    -- 3. ハイライトと装飾の設定
    local hl_group = (bufnr == cur) and "%#TabLineSel#" or "%#TabLine#"
    
    -- ベースの色を設定
    s = s .. hl_group
    
    if bufnr == cur then
      s = s .. "▎  " -- 左端のアクセント + 多めの余白
    else
      s = s .. "   " -- 非選択時も位置を合わせるためにスペースを増やす
    end

    -- 1. 番号
    s = s .. i .. "  " -- 番号の後ろも少し空ける

    -- 2. アイコン (色付き)
    if icon_char ~= "" then
      if icon_hl ~= "" then
        s = s .. "%#" .. icon_hl .. "#" .. icon_char .. "  " .. hl_group -- アイコンの後ろも2マス
      else
        s = s .. icon_char .. "  "
      end
    end

    -- 3. ファイル名 (選択中は斜体)
    local name_hl = hl_group
    if bufnr == cur then
       name_hl = "%#TabLineSelItalic#"
    end
    
    s = s .. name_hl .. name .. hl_group .. modified .. "  " -- 右側の余白も増やす
    
    -- 背景色リセット
    s = s .. "%#TabLineFill#"
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
  -- ハイライトを設定する関数
  local function set_highlights()
    local function create_italic_hl(target, source)
      -- 既存の色情報を取得 (リンク先も解決する)
      local hl = vim.api.nvim_get_hl(0, { name = source, link = false })
      -- 斜体を追加
      hl.italic = true
      -- 新しいグループとして定義
      vim.api.nvim_set_hl(0, target, hl)
    end

    create_italic_hl("TabLineSelItalic", "TabLineSel")
    create_italic_hl("TabLineItalic", "TabLine")
  end

  -- 初回実行
  set_highlights()

  -- カラースキームが変更されたら再設定する (色がリセットされるのを防ぐ)
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = set_highlights,
  })

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
