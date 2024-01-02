# My dotfiles

**dotfiles for me**

## Install Command

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/shimehituzi/.dotfiles/master/install.sh)"
```

## Manual setteings

### iTerm Load Setting file

iTerm -> Preferences -> Preferences
Load preferences from a custom folder or URL: `/Users/[username]/.config/iterm2`

### install runtimes and nvim plugins

```bash
rtx i
nvim

```

## Note: Update Submodule

in `~/.dotfiles`

```bash
git submodule update --remote
```
