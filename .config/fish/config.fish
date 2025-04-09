set -U fish_greeting

set -gx EDITOR nvim

if status is-interactive
    eval (/opt/homebrew/bin/brew shellenv)
end

function bottom_prompt --on-event fish_prompt
  tput cup $LINES 0
end
function ctrl_l
  clear
  tput cup $LINES 0
  commandline -f repaint
end
bind \cl ctrl_l

function starship_transient_prompt_func
 starship module character
end
starship init fish | source
enable_transience

mise activate fish | source

source ~/.config/fish/abbr.fish

zoxide init fish | source

gopass completion fish | source
