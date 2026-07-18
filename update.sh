#!/bin/bash
#
# クールダウン付き安全アップデート
# 方針: 「リリース/コミットから COOLDOWN_DAYS 日未満のバージョンはインストールしない」
# 仕組みの全体像と根拠は UPDATE.md を参照
#
# 使い方 (fish の abbr: bb / bbi / bba に対応):
#   ./update.sh brew           # [bb]  formula/cask をバンプ日判定つきで更新 + Brewfile の未導入分も判定つきで導入
#   ./update.sh install <pkg>… # [bbi] 新規パッケージを判定つきでインストールし Brewfile を更新 (formula/cask 自動判別)
#   ./update.sh check <pkg>…   #       インストールせず判定だけ表示
#   ./update.sh dump           #       Brewfile を現在のインストール状態から再生成
#   ./update.sh nvim           # lazy.nvim を「7日前時点のブランチ先端」へ、Mason をスナップショットへ
#   ./update.sh mise           # mise up --bump (minimum_release_age 適用)
#   ./update.sh pins           # 手動固定パッケージの「クールダウン通過済み最新版」を表示
#   ./update.sh all            # [bba] brew → nvim → mise → pins
#
# 7日未満の新パッケージを緊急で入れる場合: FORCE=1 ./update.sh install <pkg>

set -u

COOLDOWN_DAYS=7
dotfiles_path="$HOME/.dotfiles"
nvim_config_path="$dotfiles_path/.config/nvim"
mason_data_path="$HOME/.local/share/nvim/mason"
cutoff_iso=$(date -u -v-${COOLDOWN_DAYS}d +%Y-%m-%dT%H:%M:%SZ)

# ---------------------------------------------------------------- Homebrew 共通
# クールダウン判定。formula/cask は自動判別
# 結果: gate_kind / gate_date (グローバル)。戻り値 0=可 1=保留 2=判定不能
# 注意: 変数名に path を使わないこと (zsh では PATH 連動の特殊変数)
brew_gate() {
  local pkg=$1 info repo rbpath jqkey
  gate_kind="" gate_date=""
  info=$(brew info --json=v2 "$pkg" 2>/dev/null) || return 2
  if [ "$(printf '%s' "$info" | jq '.formulae | length')" != 0 ]; then
    gate_kind=formula jqkey=formulae repo="Homebrew/homebrew-core"
  elif [ "$(printf '%s' "$info" | jq '.casks | length')" != 0 ]; then
    gate_kind=cask jqkey=casks repo="Homebrew/homebrew-cask"
  else
    return 2
  fi
  rbpath=$(printf '%s' "$info" | jq -r ".${jqkey}[0].ruby_source_path // empty")
  [ -z "$rbpath" ] && return 2 # 空のまま API を叩くとリポジトリ先端の日付を拾ってしまう
  gate_date=$(gh api "repos/$repo/commits?path=${rbpath}&per_page=1" --jq '.[0].commit.committer.date' 2>/dev/null)
  [ -z "$gate_date" ] && return 2
  if [[ "$gate_date" < "$cutoff_iso" ]]; then return 0; else return 1; fi
}

gate_eligible_date() { # gate_date + COOLDOWN_DAYS 日 (この日以降なら入れてよい)
  date -u -j -v+${COOLDOWN_DAYS}d -f "%Y-%m-%dT%H:%M:%SZ" "$gate_date" +%Y-%m-%d 2>/dev/null || echo "?"
}

dump_brewfile() {
  # go/cargo/npm セクションと説明コメントは出さない (fish の universal 変数にも設定済み)
  HOMEBREW_BUNDLE_DUMP_NO_GO=1 HOMEBREW_BUNDLE_DUMP_NO_CARGO=1 \
  HOMEBREW_BUNDLE_DUMP_NO_NPM=1 HOMEBREW_BUNDLE_NO_DESCRIBE=1 \
    brew bundle dump --force --file "$dotfiles_path/Brewfile"
  echo "==> Brewfile を再生成した (git diff で確認すること)"
}

# ---------------------------------------------------------------- brew (bb)
update_brew() {
  echo "==> brew update (メタデータのみ)"
  brew update --quiet

  local pkg rc
  echo "==> 更新: バンプから ${COOLDOWN_DAYS} 日未満のものは保留"
  for pkg in $(brew outdated --quiet); do
    brew_gate "$pkg"; rc=$?
    case $rc in
      0) echo "  更新: $pkg (バンプ $gate_date)"
         brew upgrade --$gate_kind "$pkg" ;;
      1) echo "  保留: $pkg (バンプ $gate_date → $(gate_eligible_date) 以降に適格)" ;;
      *) echo "  判定不能: $pkg (保留)" ;;
    esac
  done

  # Brewfile にあって未インストールのもの (別マシンで追加した分など) も判定つきで導入
  local kind flag listflag
  for kind in formula cask; do
    if [ "$kind" = formula ]; then flag=--brews listflag=--formula; else flag=--casks listflag=--cask; fi
    for pkg in $(brew bundle list $flag --file "$dotfiles_path/Brewfile" 2>/dev/null); do
      brew list $listflag "$pkg" >/dev/null 2>&1 && continue
      brew_gate "$pkg"; rc=$?
      case $rc in
        0) echo "  新規導入: $pkg (バンプ $gate_date)"
           if [ "$kind" = cask ]; then brew install --cask "$pkg"; else brew install "$pkg"; fi ;;
        1) echo "  新規保留: $pkg (バンプ $gate_date → $(gate_eligible_date) 以降に適格)" ;;
        *) echo "  判定不能: $pkg (保留)" ;;
      esac
    done
  done
}

# ---------------------------------------------------------------- install (bbi) / check
cmd_install() {
  [ $# -eq 0 ] && { echo "使い方: ./update.sh install <pkg>..." >&2; return 1; }
  local pkg rc did=0
  for pkg in "$@"; do
    brew_gate "$pkg"; rc=$?
    if [ $rc -eq 0 ] || { [ $rc -eq 1 ] && [ "${FORCE:-0}" = 1 ]; }; then
      [ $rc -eq 1 ] && echo "  FORCE=1 のためクールダウンを無視して入れる: $pkg"
      echo "==> brew install: $pkg ($gate_kind, バンプ $gate_date)"
      if [ "$gate_kind" = cask ]; then brew install --cask "$pkg"; else brew install "$pkg"; fi && did=1
    elif [ $rc -eq 1 ]; then
      echo "  保留: $pkg はバンプ ($gate_date) から ${COOLDOWN_DAYS} 日未満。$(gate_eligible_date) 以降に入れること"
      echo "        緊急なら: FORCE=1 ./update.sh install $pkg"
    else
      echo "  判定不能: $pkg (名前を確認: brew search $pkg)"
    fi
  done
  [ $did -eq 1 ] && dump_brewfile
}

cmd_check() {
  [ $# -eq 0 ] && { echo "使い方: ./update.sh check <pkg>..." >&2; return 1; }
  local pkg rc
  for pkg in "$@"; do
    brew_gate "$pkg"; rc=$?
    case $rc in
      0) echo "  可:     $pkg ($gate_kind, バンプ $gate_date)" ;;
      1) echo "  保留:   $pkg ($gate_kind, バンプ $gate_date → $(gate_eligible_date) 以降に適格)" ;;
      *) echo "  判定不能: $pkg" ;;
    esac
  done
}

# ---------------------------------------------------------------- lazy.nvim
# 各プラグインを「7日前時点のブランチ先端コミット」に合わせる。
# spec で version/tag/commit/pin 固定しているプラグインは対象外
# (固定の変更はユーザーが明示的に行う)
update_lazy() {
  local lock="$nvim_config_path/lazy-lock.json"
  local plugdir="$HOME/.local/share/nvim/lazy"

  echo "==> lazy.nvim: ${COOLDOWN_DAYS}日前時点のブランチ先端へ"
  local pinned
  pinned=$(nvim --headless "+lua for n,p in pairs(require('lazy.core.config').plugins) do if p.version or p.tag or p.commit or p.pin then io.write(n..'\n') end end" +qa 2>/dev/null)

  local tmp name dir branch sha cur
  tmp=$(mktemp)
  cp "$lock" "$tmp"
  for name in $(jq -r 'keys[]' "$lock"); do
    if grep -qxF "$name" <<< "$pinned"; then
      continue # spec 固定 → ユーザーが固定値を変えたときだけ動く
    fi
    dir="$plugdir/$name"
    [ -d "$dir/.git" ] || { echo "  未取得: $name (スキップ)"; continue; }
    # build フックが追跡ファイルを汚していると restore が警告・失敗するため毎回戻す
    git -C "$dir" checkout -q -- . 2>/dev/null
    branch=$(jq -r --arg p "$name" '.[$p].branch' "$lock")
    git -C "$dir" fetch -q origin "$branch" 2>/dev/null || { echo "  fetch失敗: $name (スキップ)"; continue; }
    sha=$(git -C "$dir" rev-list -1 --first-parent --before="$cutoff_iso" "origin/$branch" 2>/dev/null)
    cur=$(jq -r --arg p "$name" '.[$p].commit' "$lock")
    if [ -n "$sha" ] && [ "$sha" != "$cur" ]; then
      jq --arg p "$name" --arg c "$sha" '.[$p].commit = $c' "$tmp" > "$tmp.new" && mv "$tmp.new" "$tmp"
      echo "  更新: $name ${cur:0:8} -> ${sha:0:8}"
    fi
  done
  mv "$tmp" "$lock"

  echo "==> Lazy restore (ロックの状態を適用。build フックの npm も ~/.npmrc の min-release-age が効く)"
  nvim --headless "+Lazy! restore" +qa
  echo ""
  echo "==> treesitter パーサー更新 (リビジョンは本体コミットの lockfile.json で固定済み)"
  nvim --headless "+TSUpdate" +qa
  echo ""
}

# ---------------------------------------------------------------- Mason
# レジストリを「7日以上前のスナップショットリリース」にピンする。
# バージョン未指定インストールはスナップショットが指す版になるため、
# :Mason での更新も含めてクールダウンが成立する
update_mason() {
  echo "==> Mason: レジストリを${COOLDOWN_DAYS}日以上前のスナップショットへピン"
  local tag="" page
  for page in 1 2 3 4 5; do
    tag=$(gh api "repos/mason-org/mason-registry/releases?per_page=100&page=$page" \
      --jq "[.[] | select(.published_at <= \"$cutoff_iso\")] | sort_by(.published_at) | last | .tag_name // empty" 2>/dev/null)
    [ -n "$tag" ] && break
  done
  if [ -n "$tag" ]; then
    echo "$tag" > "$nvim_config_path/mason-registry-pin.txt"
    echo "  ピン: $tag"
  else
    echo "  ピン取得失敗: 既存ピン $(cat "$nvim_config_path/mason-registry-pin.txt" 2>/dev/null) を維持"
  fi
  nvim --headless -c "MasonUpdate" -c "qall"
  echo ""

  # スナップショットとバージョンが違うパッケージだけ入れ直す
  local registry_json="$mason_data_path/registries/github/mason-org/mason-registry/registry.json"
  local to_update="" p want have
  for p in $(ls "$mason_data_path/packages" 2>/dev/null); do
    want=$(jq -r --arg n "$p" 'map(select(.name == $n)) | .[0].source.id // empty' "$registry_json" | tr 'A-Z' 'a-z')
    have=$(jq -r '.primary_source.id // empty' "$mason_data_path/packages/$p/mason-receipt.json" 2>/dev/null | tr 'A-Z' 'a-z')
    [ -n "$want" ] && [ "$want" != "$have" ] && to_update="$to_update $p" &&
      echo "  更新対象: $p ($have -> $want)"
  done
  if [ -n "$to_update" ]; then
    echo "==> MasonInstall$to_update"
    nvim --headless -c "MasonInstall$to_update" -c "qall"
    echo ""
  else
    echo "  Mason パッケージは全てスナップショットと一致"
  fi
}

# ---------------------------------------------------------------- mise
update_mise() {
  echo "==> mise up --bump (minimum_release_age=${COOLDOWN_DAYS}d が適用される)"
  echo "    注意: rust はリリースタイムスタンプが無くクールダウン対象外 (UPDATE.md 参照)"
  mise up --bump
  # mise の node 更新で旧 node のグローバル npm パッケージが消えるため復旧
  if ! command -v mcp-hub >/dev/null 2>&1; then
    echo "==> mcp-hub 再インストール (lua/plugins/llm.lua の build と同じ固定バージョン)"
    npm install -g mcp-hub@4.2.0
  fi
}

# ---------------------------------------------------------------- pins
# 手動でバージョン固定しているパッケージについて、
# クールダウンを通過した最新版を表示する (書き換えはユーザーが行う)
check_pins() {
  echo "==> 手動固定パッケージの更新候補 (${COOLDOWN_DAYS}日経過済みの最新版)"
  echo "    反映先: .config/mcphub/servers.json / nvim の lua/plugins/llm.lua (build 行)"
  local pkg v
  for pkg in mcp-hub @modelcontextprotocol/server-memory @modelcontextprotocol/server-github @modelcontextprotocol/server-sequential-thinking; do
    v=$(npm view "$pkg" time --json 2>/dev/null | jq -r --arg c "$cutoff_iso" \
      'to_entries | map(select(.key | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) | select(.value <= $c)) | sort_by(.value) | last | .key // "?"')
    echo "  npm: $pkg -> $v"
  done
  for pkg in mcp-server-git mcp-server-time; do
    v=$(curl -s "https://pypi.org/pypi/$pkg/json" | jq -r --arg c "$cutoff_iso" \
      '[.releases | to_entries[] | select((.value|length) > 0) | {v: .key, t: .value[0].upload_time_iso_8601}] | map(select(.t <= $c)) | sort_by(.t) | last | .v // "?"')
    echo "  uvx: $pkg -> $v"
  done
}

cmd=${1:-all}
[ $# -gt 0 ] && shift
case "$cmd" in
  brew)    update_brew ;;
  install) cmd_install "$@" ;;
  check)   cmd_check "$@" ;;
  dump)    dump_brewfile ;;
  nvim)    update_lazy; update_mason ;;
  mise)    update_mise ;;
  pins)    check_pins ;;
  all)
    update_brew
    update_lazy
    update_mason
    update_mise
    check_pins
    echo ""
    echo "==> 完了。変更されたファイル (lazy-lock.json / mason-registry-pin.txt / mise config.toml) を確認してコミットすること"
    ;;
  *)
    echo "使い方: ./update.sh [all|brew|install <pkg>…|check <pkg>…|dump|nvim|mise|pins]" >&2
    exit 1
    ;;
esac
