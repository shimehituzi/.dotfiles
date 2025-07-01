#!/bin/sh

dotfiles_path="$HOME/.dotfiles"
fonts_dir_path="$HOME/Library/Fonts"
tmp_fonts_path="$dotfiles_path/.tmp_fonts"

my_dotfils_url="https://github.com/shimehituzi/.dotfiles.git"
homebrew_install_sh_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
fonts_release_url="https://github.com/yuru7/udev-gothic/releases/download/v1.3.1/UDEVGothic_NF_v1.3.1.zip"

require_fonts_name="UDEVGothicNFLG-Regular.ttf"


install_dotfiles() {
  [[ -e $dotfiles_path ]] || git clone $my_dotfils_url $dotfiles_path
}

install_gitsubmodule() {
  git submodule init
  git submodule update
}

generate_symlink() {
  for file in `ls -a $dotfiles_path`; do
    [ $file = '.' ] && continue
    [ $file = '..' ] && continue
    [ $file = '.git' ] && continue
    [ $file = '.gitmodules' ] && continue
    [ $file = '.gitignore' ] && continue
    [ $file = 'README.md' ] && continue
    [ $file = 'install.sh' ] && continue
    [ $file = '.claude' ] && mkdir -p ~/.claude && ln -snf $dotfiles_path/.claude/CLAUDE.md ~/.claude/ && continue
    ln -snf $dotfiles_path/$file $HOME
  done
}

install_pkg_manager() {
  which -s brew
  if [[ $? != 0 ]] ; then
    /bin/bash -c "$(curl -fsSL $homebrew_install_sh_url)"
  fi
}

install_packages() {
  which -s brew
  if [[ $? != 0 ]] ; then
    echo "brew is not installed" >&2
    exit 1
  fi
  brew bundle --no-lock
}

install_font() {
  which -s fc-cache
  if [[ $? != 0 ]] ; then
    echo "fc-cache is not installed" >&2
    exit 1
  fi
  if [[ ! -e "$fonts_dir_path/$require_fonts_name" ]]; then
    mkdir -p $fonts_dir_path
    mkdir -p $tmp_fonts_path
    cd $tmp_fonts_path
    curl -LO $fonts_release_url
    unzip $(basename $fonts_release_url)
    mv $(basename $fonts_release_url | sed 's/.zip$//')/*.ttf $fonts_dir_path
    cd $dotfiles_path
    rm -rf $tmp_fonts_path
    fc-cache -fv
  fi
}

install_runtimes() {
  which -s mise
  if [[ $? != 0 ]] ; then
    echo "mise not is installed" >&2
    exit 1
  fi
  mise i
}

setup_bat_cache() {
  which -s bat
  if [[ $? != 0 ]] ; then
    echo "bat is not installed" >&2
    return 1
  fi
  echo "Building bat cache..."
  bat cache --build
}

install_gnupg_symlink() {
  local src="$dotfiles_path/.config/gnupg/gpg-agent.conf"
  local dest="$HOME/.gnupg/gpg-agent.conf"

  mkdir -p "$(dirname "$dest")"
  chmod 700 "$(dirname "$dest")"

  ln -sf "$src" "$dest"

  gpgconf --kill gpg-agent
}

main() {
  install_dotfiles
  cd $dotfiles_path
  install_gitsubmodule
  generate_symlink
  cd $HOME
  install_pkg_manager
  install_packages
  install_font
  install_runtimes
  setup_bat_cache
  install_gnupg_symlink 
}

main "$@"
