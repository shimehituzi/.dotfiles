#!/bin/sh

dotfiles_path="$HOME/.dotfiles"

install_dotfiles() {
  [[ -e ~/.dotfiles ]] || git clone git@github.com:shimehituzi/.dotfiles.git ~/.dotfiles
}

install_gitsubmodule() {
  git submodule init
  git submodule update
}

install_pkg_manager() {
  which -s brew
  if [[ $? != 0 ]] ; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
}

install_packages() {
  brew bundle --no-lock
}

generate_symlink() {
  for file in `ls -a ${dotfiles_path}`; do
    [ $file = '.' ] && continue
    [ $file = '..' ] && continue
    [ $file = '.git' ] && continue
    [ $file = '.gitmodules' ] && continue
    [ $file = '.gitignore' ] && continue
    [ $file = 'README.md' ] && continue
    [ $file = 'install.sh' ] && continue
    ln -snf ${dotfiles_path}/${file} $HOME
  done
}


main() {

  install_dotfiles()

  pushd ${dotfiles_path}

  install_gitsubmodule()

  generate_symlink()

  pushd $HOME

  install_pkg_manager()

  install_packages()

}

main "$@"
