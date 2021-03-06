export ZSH="$HOME/.oh-my-zsh"

plugins=(git)

ZSH_THEME=awesomepanda

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
alias python=/usr/bin/python3

alias pip=/usr/bin/pip3
source $ZSH/oh-my-zsh.sh

