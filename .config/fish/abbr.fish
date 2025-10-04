# abbr
abbr --add ls eza
abbr --add ll eza -l
abbr --add la eza -la
abbr --add tree eza --tree
abbr --add trel eza --tree --level
abbr --add grep rg
abbr --add find fd
abbr --add cd z
abbr --add cat bat
abbr --add ja trans -b -s en -t ja
abbr --add en trans -b -s ja -t en
abbr --add e $EDITOR
abbr --add rt trash
abbr --add de delta
abbr --add bb brew bundle
abbr --add bbd brew bundle dump --force
abbr --add bbc brew bundle cleanup --force
abbr --add kr "gk graph --gitkraken"
abbr --add abl abbr --show
abbr --add md "ls *.md | entr -c glow"
abbr --add rmds "rm .DS_Store"
abbr --add vi nvim
abbr --add vim nvim
abbr --add --position command --set-cursor ob 'codex -C ~/obsidian %'
abbr --add obe 'nvim --cmd "cd ~/obsidian"'

# git
abbr --add gs git status
abbr --add ga git add
abbr --add gc git commit
abbr --add gca git commit --amend
abbr --add gcm git commit -m
abbr --add gp git push
abbr --add gpl git pull
abbr --add gch git checkout
abbr --add gr git reset
abbr --add gbr git branch
abbr --add gcl git clean
abbr --add gsm git submodule update --remote
abbr --add gd git diff

# lang
abbr --add dts deno task start
abbr --add dtt deno task test
