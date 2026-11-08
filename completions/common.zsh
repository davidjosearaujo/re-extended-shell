# Zsh completion setup shared by every completions/<topic>.zsh file.
# Loaded first by config/completions.sh.

# compdef only exists once the completion system is initialised. Most setups
# (oh-my-zsh, prezto, ...) do that before this file is sourced; if not, do it.
if (( ! $+functions[compdef] )); then
    autoload -Uz compinit && compinit -i
fi
