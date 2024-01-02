#!/bin/sh

dotfiles_path="$HOME/.dotfiles"
fonts_dir_path="$HOME/Library/Fonts"
tmp_fonts_path="$dotfiles_path/.tmp_fonts"

my_dotfils_url="git@github.com:shimehituzi/.dotfiles.git"
homebrew_install_sh_url="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
fonts_release_url="https://github.com/yuru7/udev-gothic/releases/download/v1.3.1/UDEVGothic_NF_v1.3.1.zip"

require_fonts_name="UDEVGothicNFLG-Regular.ttf"


install_dotfiles() {
  [[ -e ~/.dotfiles ]] || git clone $my_dotfils_url $dotfiles_path
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
  brew bundle --no-lock
}

install_font() {
  if [[ ! -e "$fonts_dir_path/$require_fonts_name" ]]; then
    mkdir -p $fonts_dir_path
    mkdir -p $tmp_fonts_path
    cd $tmp_fonts_path
    curl -LO $fonts_release_url
    unzip $(basename $fonts_release_url)
    mv $(basename $fonts_release_url | sed 's/.zip$//') $fonts_dir_path
    cd $dotfiles_path
    rm -rf $tmp_fonts_path
    fc-cache -fv
  fi
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
}

main "$@"
