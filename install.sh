#!/bin/sh

[[ -e ~/.dotfiles ]] || git clone git@github.com:shimehituzi/.dotfiles.git ~/.dotfiles
pushd ~/.dotfiles

git submodule init
git submodule update
for file in `ls -a`; do
  [ $file = '.' ] && continue
  [ $file = '..' ] && continue
  [ $file = '.git' ] && continue
  [ $file = '.gitmodules' ] && continue
  [ $file = '.gitignore' ] && continue
  [ $file = 'README.md' ] && continue
  [ $file = 'install.sh' ] && continue
  ln -snf ~/.dotfiles/$file ~/
done

pushd ~/

which -s brew
if [[ $? != 0 ]] ; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
brew bundle --no-lock

popd

popd
