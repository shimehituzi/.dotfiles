#!/usr/bin/env fish
mkdir -p ~/.gnupg
ln -sf ~/.dotfiles/.config/gnupg/gpg-agent.conf ~/.gnupg/gpg-agent.conf
chmod 700 ~/.gnupg
gpgconf --kill gpg-agent
