# クールダウン付きアップデート運用

目的: **これからインストール・更新するものが汚染版でないことを、インストールの時点で担保する。**

手段は「クールダウン」= リリース(またはコミット)から **7日** 未満のバージョンを採用しないこと。
悪意あるバージョンは公開から概ね1週間以内に検出・削除されるため、クールダウンで攻撃の大半を
回避できる(根拠: [Woodruff "We should all be using dependency cooldowns"](https://blog.yossarian.net/2025/11/21/We-should-all-be-using-dependency-cooldowns)、
liteLLM の汚染版は最長約5時間、axios は約3時間で削除された)。

## レイヤー1: 常時有効(設定ファイルで自動適用、何もしなくても効く)

| 経路 | 設定ファイル | 設定 | 適用範囲 |
|---|---|---|---|
| npm / npx | [.npmrc](.npmrc) | `min-release-age=7` | install / -g / npx / **推移的依存も** |
| bun | [.bunfig.toml](.bunfig.toml) | `minimumReleaseAge = 604800`(秒) | bun add / -g(bunx は効かない→npx を使う) |
| uv / uvx | [.config/uv/uv.toml](.config/uv/uv.toml) | `exclude-newer = "P7D"` | uvx / uv tool / uv add / **推移的依存も** |
| mise | [.config/mise/config.toml](.config/mise/config.toml) | `minimum_release_age = "7d"` | mise up --bump 時の版解決 |

mcphub の MCP サーバー(npx/uvx 起動)はバージョン厳密固定済みのため、
初回解決時の推移的依存も上記 npm / uv の設定で守られる。

**緊急で7日未満の版が必要なとき**(セキュリティ修正の即時適用など):
- npm: `npm install --min-release-age=0 pkg@ver`
- uv: `UV_EXCLUDE_NEWER=false uvx ...`
- mise: `mise install node@x.y.z`(明示バージョン指定はフィルタを通らない仕様)

## 日常のワークフロー(fish の abbr)

| 操作 | 今まで | これから |
|---|---|---|
| パッケージを入れる | `brew install X` → `bbd` | **`bbi X`**(7日判定 → install → Brewfile 更新まで一括。formula/cask 自動判別) |
| 入れる前に判定だけ | — | **`bbk X`**(可 / 保留(適格日) / 判定不能 を表示) |
| 日々の更新 | `bb`(brew bundle) | **`bb`**(7日判定つき更新。別マシンで Brewfile に足した分も判定つきで導入) |
| 月1回のフル更新 | nvim で Lazy/Mason + mise up | **`bba`**(brew + nvim + mise + pins 一括) |
| Brewfile 再生成 | `bbd` | **`bbd`**(そのまま使える。npm/go/cargo/説明コメントを出さない設定を fish の universal 変数に追加済み) |
| 不要パッケージ削除 | Brewfile から行削除 → `bbc` | **同じ**(削除にクールダウンは不要) |
| 緊急で7日未満の版を入れる | — | `FORCE=1 ~/.dotfiles/update.sh install X` |

## レイヤー2: update.sh が判定するもの(ネイティブ機構がない経路)

```sh
bba    # = cd ~/.dotfiles && ./update.sh  (月1回程度)
```

> 前提: バンプ日の確認に GitHub API を使うため、**各マシンで `gh auth login` が必要**。
> 認証が無効なら brew の更新・導入は明確なエラーで中断する(何もインストールしない)。

| 経路 | 方法 |
|---|---|
| Homebrew formula/cask | バージョンバンプのコミット日時を GitHub API で確認し、7日未満なら**保留** |
| lazy.nvim(54個のHEAD追従プラグイン) | 各プラグインの「**7日前時点のブランチ先端コミット**」を計算してロックに書き、`:Lazy restore` で適用 |
| Mason | レジストリを「**7日以上前のスナップショットリリース**」にピン([mason-registry-pin.txt](.config/nvim/mason-registry-pin.txt))。バージョン未指定インストールや :Mason の更新はスナップショット時点の版までしか進まない |
| treesitter パーサー | 本体コミットの lockfile.json でリビジョン固定(本体が上のクールダウンに従うため自動的に安全) |

## バージョン固定しているもの(更新は明示的に)

- mcphub の MCP サーバー(servers.json)、`mcp-hub`(lua/plugins/llm.lua の build 行)、
  avante / mcphub.nvim / mason 等の spec 固定プラグイン
- `./update.sh pins` がクールダウン通過済みの最新版を表示するので、それを見て固定値を書き換える
- **`@latest` や無指定でのインストールは禁止**(npx / npm -g / uvx すべて)
- **ts_ls 用 TypeScript フォールバック**: mason 同梱の typescript 7.x は tsserver.js を
  持たないため、`~/.local/share/nvim/ts-fallback` に typescript 5.x を置いている
  (lua/plugins/lsp.lua の `fallbackPath` が参照)。消えた場合の再インストール:
  `npm install --prefix ~/.local/share/nvim/ts-fallback typescript@5`
  (レイヤー1の min-release-age が効く。mise の node バンプや mason 更新の影響は受けない)

## 新規インストール時のルール

- **brew**: `bbi <pkg>` を使う(判定・インストール・Brewfile 更新まで自動)。
  `brew install` を直接叩かない
- **例外: 自己更新型のベンダー一次配布 cask**(claude / claude-code など)。
  バンプ間隔が7日未満のためゲートは永遠に開かず、かつインストール後はアプリ自身が
  ベンダーのチャネルから自動更新する(= ゲートしても翌日には最新になる)。
  この種類は `FORCE=1 ./update.sh install <pkg>` で初回導入してよい。
  bb の出力に「保留」として出続けることがあるが、実更新はアプリ側が行うため無視してよい
- **lazy.nvim の新プラグイン**: 初回インストールは HEAD を取ってしまうため、
  7日以上前のコミット/タグを `commit =` / `tag =` で指定して追加する
- **npm / uv 系**: レイヤー1が自動で効くのでそのまま入れてよい

## クールダウンが効かない残存経路(正直な限界)

| 経路 | 状況 | 対応 |
|---|---|---|
| rust(mise) | リリースにタイムスタンプが無くフィルタ素通り | 厳密固定済み。bump 時に[リリース日](https://github.com/rust-lang/rust/releases)を目視確認 |
| cask アプリの自己更新 | Obsidian / Docker / iTerm2 等はアプリ内アップデータで brew の外から更新される | 急ぎでなければアプリ内自動更新をオフにして手動更新 |
| Obsidian コミュニティプラグイン | 固定機構なし。更新は手動実行時のみ | 「Check for updates」を押すのを急がない(7日待つ) |
| Claude Code 本体 | 自動更新 | 公式配布で署名済み。リスク受容 |
| Homebrew の依存連鎖 | 許可した formula の依存は判定なしで連鎖更新される | リスク受容(homebrew-core はメンテナ審査あり) |
| ghcup | クールダウン機構なし | recommended チャンネル(実績版)のみ使う |

## インシデントを踏んだ疑いがあるとき

更新を止めれば現状より悪化しない(全経路が固定 or クールダウン済みのため)。
汚染が公表されたら、公表された影響バージョンと
lazy-lock.json / mason-lock.json / servers.json / mise config.toml の固定値を照合する。
該当したら、その機器のシークレット(SSH鍵・APIキー・クラウド認証情報)を全てローテーションする。
