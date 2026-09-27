# Lazy NVM: Node, npm, npx, and nvm load on first use instead of delaying every shell prompt.
export NVM_DIR="$HOME/.nvm"
__kaura_load_nvm() {
  unset -f nvm node npm npx
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
  else
    printf "NVM was not found at %s\n" "$NVM_DIR" >&2
    return 127
  fi
}
nvm()  { __kaura_load_nvm && nvm "$@"; }
node() { __kaura_load_nvm && node "$@"; }
npm()  { __kaura_load_nvm && npm "$@"; }
npx()  { __kaura_load_nvm && npx "$@"; }

export ZSH="/home/ubuntu/.oh-my-zsh"
ZSH_THEME="neon-cyberpunk"

plugins=(
  git
  extract
  zsh-autosuggestions
  zsh-history-substring-search
  you-should-use
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# >>> modern zsh setup >>>
# Prompt, smarter directory jumps, and FZF key bindings/completion.
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
[[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[[ -r /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
# <<< modern zsh setup <<<
