local M = {}

M.mru_list = {}

-- グローバル関数として登録しないとタブラインから呼べない (v:lua.Func)
_G.MruBufTab_close_buffer = function(bufnr)
  -- 数値に変換 (タブラインからは文字列で来る場合があるため)
  local b = tonumber(bufnr)
  if b and vim.api.nvim_buf_is_valid(b) then
    vim.api.nvim_buf_delete(b, { force = false })
  end
end

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

-- LSPの診断情報を取得する関数
local function get_diagnostics(bufnr)
  if not vim.diagnostic then return "" end

  local count = vim.diagnostic.get(bufnr)
  if #count == 0 then return "" end

  local err = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.ERROR })
  local warn = #vim.diagnostic.get(bufnr, { severity = vim.diagnostic.severity.WARN })

  local s = ""
  if err > 0 then s = s .. "%#DiagnosticError#E:" .. err .. " " end
  if warn > 0 then s = s .. "%#DiagnosticWarn#W:" .. warn .. " " end

  return s
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

    -- --- 厳密な固定幅ロジック ---
    local TAB_WIDTH = 25 -- 1つのタブの目標固定幅 (文字数)

    -- 既に表示した部分の幅 (左端スペース + 番号 + スペース + アイコン + スペース)
    local current_width = 2 + string.len(tostring(i)) + 2 + (icon_char ~= "" and 2 or 0)

    -- 右側の固定要素の幅 (LSP + 閉じるボタン + スペース)
    local diag_str = get_diagnostics(bufnr)

    -- LSPエリアを固定幅で予約する (例: 6文字分)
    -- E:1 W:1 でおよそ6-7文字。これを超える場合は溢れるが、基本は確保
    local RESERVED_DIAG_WIDTH = 6
    local current_diag_width = vim.fn.strdisplaywidth(diag_str:gsub("%%#.-#", "")) 

    -- 実際にLSPを表示する際のパディング
    local diag_padding = ""
    if current_diag_width < RESERVED_DIAG_WIDTH then
      diag_padding = string.rep(" ", RESERVED_DIAG_WIDTH - current_diag_width)
    end

    local close_width = 3 -- "✕  "
    local modified_width = (modified ~= "" and 2 or 0)

    -- ファイル名に使える残りの幅 (LSPエリアは常に RESERVED_DIAG_WIDTH 分引く)
    local available_name_width = TAB_WIDTH - current_width - RESERVED_DIAG_WIDTH - close_width - modified_width

    -- 最低でも5文字分はファイル名に残す
    if available_name_width < 5 then available_name_width = 5 end

    -- ファイル名の切り詰め処理
    local display_name = name
    if vim.fn.strdisplaywidth(name) > available_name_width then
      display_name = vim.fn.strcharpart(name, 0, available_name_width - 1) .. "…"
    end

    -- 実際に表示するファイル名の幅
    local actual_name_width = vim.fn.strdisplaywidth(display_name)

    -- 足りない分をパディング（空白）で埋める
    local padding_len = available_name_width - actual_name_width
    local padding = string.rep(" ", padding_len > 0 and padding_len or 0)

    -- 組み立て
    s = s .. name_hl .. display_name .. hl_group .. modified .. padding .. " "

    -- LSP情報の表示 (予約幅に合わせてパディング追加)
    if diag_str ~= "" then
      s = s .. diag_str .. hl_group .. diag_padding .. " "
    else
      -- 情報がない場合も、予約した幅の分だけスペースを埋める
      s = s .. string.rep(" ", RESERVED_DIAG_WIDTH) .. " "
    end

    -- 5. 閉じるボタン
    s = s .. "%" .. bufnr .. "@v:lua.MruBufTab_close_buffer@✕%X  "

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