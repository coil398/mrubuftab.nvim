# mrubuftab.nvim

最近使ったファイル順 (MRU: Most Recently Used) にバッファを並べ替えてタブラインに表示する Neovim プラグインです。
直前のバッファに戻ったり、履歴のN番目にジャンプする機能も提供します。

## インストール (lazy.nvim)

`lazy.nvim` を使用している場合の推奨設定です。

```lua
{
  "coil398/mrubuftab.nvim",
  config = function()
    require("mrubuftab").setup()

    -- キーマッピングの設定例
    -- <S-l>: 直前のバッファ（履歴の2番目）へ移動。 3<S-l> で3番目の履歴へ移動。
    vim.keymap.set("n", "<S-l>", "<Cmd>MruNext<CR>", { desc = "MRU Next" })
    
    -- <S-h>: 一番古いバッファ（履歴の末尾）へ移動。
    vim.keymap.set("n", "<S-h>", "<Cmd>MruPrev<CR>", { desc = "MRU Prev" })
  end,
}
```

## 使い方

プラグインをインストールすると、自動的にタブラインがMRU順の表示に切り替わります。
左端（番号1）が現在開いているファイル、その右（番号2）が直前に開いていたファイル...という順番になります。

### コマンド

- `:MruNext`
    - 引数なし: 履歴の2番目（直前のバッファ）に移動します。
    - 引数あり (`:3MruNext`): 履歴の指定した番号（例: 3番目）に移動します。
- `:MruPrev`
    - 引数なし: 履歴の一番最後（最も昔に触ったバッファ）に移動します。
    - 引数あり (`:2MruPrev`): 後ろから指定した番号（例: 後ろから2番目）に移動します。
