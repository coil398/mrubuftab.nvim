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
  if err > 0 then s = s .. "%#DiagnosticError# " .. err .. " " end
  if warn > 0 then s = s .. "%#DiagnosticWarn# " .. warn .. " " end

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

local function to_superscript(num)
  local supers = {
    ["0"] = "⁰", ["1"] = "¹", ["2"] = "²", ["3"] = "³", ["4"] = "⁴",
    ["5"] = "⁵", ["6"] = "⁶", ["7"] = "⁷", ["8"] = "⁸", ["9"] = "⁹"
  }
  return tostring(num):gsub(".", supers)
end

function M.render()
  local columns = vim.o.columns
  local cur = vim.api.nvim_get_current_buf()

  -- 1. 有効なバッファリストの作成と更新
  local valid_mru = {}
  for _, bufnr in ipairs(M.mru_list) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted then
      table.insert(valid_mru, bufnr)
    end
  end
  M.mru_list = valid_mru

  -- 2. 各タブの描画内容と幅を計算してリスト化
  local tabs = {}
  local total_req_width = 0
  local current_idx = 1

  -- --- 設定値 ---
  local TAB_BASE_WIDTH = 25 -- 基本幅
  local TAB_MAX_WIDTH = 40  -- 最大幅
  -- --------------

  for i, bufnr in ipairs(M.mru_list) do
    if bufnr == cur then current_idx = i end

    local filename = vim.api.nvim_buf_get_name(bufnr)
    local name = vim.fn.fnamemodify(filename, ":t")
    local ext = vim.fn.fnamemodify(filename, ":e")
    if name == "" then name = "[No Name]" end

    -- アイコン・未保存マーク
    local icon_char, icon_hl = get_icon_data(name, ext)
    local modified = vim.bo[bufnr].modified and " ●" or ""
    
    -- ハイライト
    local hl_group = (bufnr == cur) and "%#TabLineSel#" or "%#TabLine#"
    local name_hl = (bufnr == cur) and "%#TabLineSelItalic#" or hl_group

    -- 番号 (上付き文字)
    local num_str = to_superscript(i)

    -- コンテンツ幅の計算 (スペースやアイコン含む)
    -- "▎ " or "  " (2) + num (var) + " " (1) + icon (var) + " " (1) = base
    local prefix_width = 2 + vim.fn.strdisplaywidth(num_str) + 1 + (icon_char ~= "" and 2 or 0)
    
    local diag_str = get_diagnostics(bufnr)
    local current_diag_width = vim.fn.strdisplaywidth(diag_str:gsub("%%#.-#", ""))
    local close_width = 3 -- "✕  "
    local modified_width = (modified ~= "" and 2 or 0)

    -- 目標幅の決定
    local target_width = TAB_BASE_WIDTH
    if current_diag_width > 0 then
      target_width = math.min(TAB_BASE_WIDTH + current_diag_width, TAB_MAX_WIDTH)
    end

    -- ファイル名表示幅
    local available_name_width = target_width - prefix_width - close_width - current_diag_width - modified_width
    if available_name_width < 5 then available_name_width = 5 end

    local display_name = name
    if vim.fn.strdisplaywidth(name) > available_name_width then
      display_name = vim.fn.strcharpart(name, 0, available_name_width - 1) .. "…"
    end
    local actual_name_width = vim.fn.strdisplaywidth(display_name)

    -- パディング計算
    local used_width = prefix_width + actual_name_width + modified_width + current_diag_width + close_width
    local padding_total = target_width - used_width
    if padding_total < 0 then padding_total = 0 end

    local padding_left_len = math.floor(padding_total * 0.6)
    local padding_right_len = padding_total - padding_left_len
    local padding_left = string.rep(" ", padding_left_len)
    local padding_right = string.rep(" ", padding_right_len)

    -- 文字列構築
    local s = ""
    s = s .. hl_group
    s = s .. "  " -- 装飾文字 ▎ を削除し、スペースに変更
    s = s .. num_str .. " "

    if icon_char ~= "" then
      if icon_hl ~= "" then
        s = s .. "%#" .. icon_hl .. "#" .. icon_char .. " " .. hl_group
      else
        s = s .. icon_char .. " "
      end
    end

    s = s .. name_hl .. padding_left .. display_name .. hl_group .. modified .. padding_right .. " "
    if diag_str ~= "" then s = s .. diag_str .. " " end
    s = s .. "%" .. bufnr .. "@v:lua.MruBufTab_close_buffer@✕%X  "
    s = s .. "%#TabLineFill#"

    -- リストに追加
    table.insert(tabs, {
      str = s,
      width = target_width -- パディングで埋めているのでtarget_widthが実際の幅になるはず（ただし計算違いで多少ずれる可能性はあるが一旦これで）
    })
    total_req_width = total_req_width + target_width
  end

  -- 3. 表示範囲の計算
  -- 安全マージンを含めて少し広めに取る
  local INDICATOR_WIDTH = 6 -- "  " or "  " + margin
  local available_width = columns - (INDICATOR_WIDTH * 2)

  local left, right
  local is_scroll_needed = false

  if (total_req_width + (INDICATOR_WIDTH * 2)) <= columns then
    -- 全て収まる場合
    left = 1
    right = #tabs
    is_scroll_needed = false
  else
    -- 収まらない場合: スクロール計算
    is_scroll_needed = true
    left = current_idx
    right = current_idx
    local current_len = tabs[current_idx].width

    -- 中心から広げていく (available_widthに収まるように)
    while true do
      local changed = false
      -- 左へ
      if left > 1 and (current_len + tabs[left-1].width) <= available_width then
        left = left - 1
        current_len = current_len + tabs[left].width
        changed = true
      end
      -- 右へ
      if right < #tabs and (current_len + tabs[right+1].width) <= available_width then
        right = right + 1
        current_len = current_len + tabs[right].width
        changed = true
      end
      
      if not changed then break end
      if current_len >= available_width then break end
    end
  end

  -- 4. 結合
  local final_s = ""
  
  -- 左インジケータ (常に表示)
  final_s = final_s .. "%#TabLine#  "

  for i = left, right do
    final_s = final_s .. tabs[i].str
  end

  -- 余白を埋める (スクロールが必要な場合のみ右端固定)
  if is_scroll_needed then
    final_s = final_s .. "%="
  end

  -- 右インジケータ (常に表示)
  final_s = final_s .. "%#TabLine#  "

  return final_s .. "%#TabLineFill#"
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