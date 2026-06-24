export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(zsh-autosuggestions zsh-syntax-highlighting)

zstyle ':omz:update' mode disabled
source $ZSH/oh-my-zsh.sh

PROMPT="%{$fg_bold[white]%}%m%}%{$fg[cyan]%} %c %{$reset_color%}"