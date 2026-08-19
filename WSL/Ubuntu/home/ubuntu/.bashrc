# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# >>> Codex lazy NVM >>>
# Keep Bash startup fast; initialize NVM only when a Node command is first used.
export NVM_DIR="$HOME/.nvm"

__codex_load_nvm() {
    unset -f nvm node npm npx

    if [ -s "$NVM_DIR/nvm.sh" ]; then
        source "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
    else
        printf 'NVM was not found at %s\n' "$NVM_DIR" >&2
        return 127
    fi
}

nvm()  { __codex_load_nvm && nvm "$@"; }
node() { __codex_load_nvm && node "$@"; }
npm()  { __codex_load_nvm && npm "$@"; }
npx()  { __codex_load_nvm && npx "$@"; }
# <<< Codex lazy NVM <<<

# >>> Codex WSL enhancements >>>
# Small, practical Linux CLI setup. Remove this marked block to disable it.
export PATH="$HOME/.local/bin:$PATH"

# VS Code-inspired fuzzy finder appearance.
export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border=rounded --info=inline --prompt=❯  --pointer=◆ --marker=✓ --color=bg+:#202328,bg:#0f1113,spinner:#d4d4d4,hl:#ff6b6b,fg:#d4d4d4,header:#ff6b6b,info:#c792ea,pointer:#f0f0f0,marker:#ffd700,fg+:#f0f0f0,prompt:#c792ea,hl+:#e879d2'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'

# fzf: Ctrl+R history, Ctrl+T files, and Alt+C directories.
[ -r /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
[ -r /usr/share/doc/fzf/examples/completion.bash ] && source /usr/share/doc/fzf/examples/completion.bash

# Inline history suggestions and live syntax highlighting for Bash.
if [ -r "$HOME/.local/share/blesh/ble.sh" ]; then
    source "$HOME/.local/share/blesh/ble.sh" --noattach
fi

# Smart directory navigation: z project-name.
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"

# Modern listings and useful short Git commands.
alias ls='eza --icons=auto --group-directories-first'
alias ll='eza --long --all --icons=auto --git --group-directories-first'
alias la='eza --all --icons=auto --group-directories-first'
alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
alias top='btop'
alias lg='lazygit'
alias gs='git status --short --branch'
alias gl='git log --oneline --graph --decorate --all -20'
alias gd='git diff'
alias gds='git diff --staged'

# Compact Ubuntu/Git prompt. It only shows Git details inside repositories.
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"

# Attach ble.sh only after the prompt and other shell integrations are ready.
# Disabled: ble-attach provides inline autosuggestions. Uncomment this line to restore it.
# <<< Codex WSL enhancements <<<
