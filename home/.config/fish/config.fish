if status is-interactive && not set -q ZELLIJ
    zellij --session (random)
end

set fish_greeting ""

if not set -q XDG_CONFIG_HOME
    set -gx XDG_CONFIG_HOME $HOME/.config
end

functions -e fastfetch

fish_add_path ~/.local/bin
fish_add_path /usr/bin

if command -v brew >/dev/null
    brew shellenv fish | source
end

set -gx OPENCODE_CONFIG "$XDG_CONFIG_HOME/opencode/user-overrides.json"
if not test -d "$HOME/.cache/opencode/tmp"
    mkdir -p "$HOME/.cache/opencode/tmp"
end
set -gx TMPDIR "$HOME/.cache/opencode/tmp"
set -gx ANTHROPIC_BASE_URL "https://api.ollama.com"
set -gx ANTHROPIC_AUTH_TOKEN "ollama"
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx OLLAMA_MAX_LOADED_MODELS 1
set -gx OLLAMA_KEEP_ALIVE 0
set -gx AGENT_ZELLIJ_RENAME_TAB 1

if test -f ~/.secrets/ssh.sh
    bash ~/.secrets/ssh.sh >/dev/null 2>&1
end
if test -f ~/.secrets/github.sh
    for line in (bash -c 'source ~/.secrets/github.sh >/dev/null 2>&1; env | grep -E "^(GITHUB|GITBOOK)_"')
        set -gx (string split "=" $line)[1] (string split "=" $line)[2..-1] | string join "="
    end
end

for f in ~/.secrets/*.sh
    test -f "$f" || continue
    switch $f
        case "*/ssh.sh" "*/github.sh"
            continue
    end
    bash -c "source $f >/dev/null 2>&1; env" | while read -l var
        set -gx (string split "=" $var)[1] (string split "=" $var)[2..-1] | string join "="
    end 2>/dev/null
end

zoxide init fish | source
atuin init fish | source
oh-my-posh init fish --config $XDG_CONFIG_HOME/oh-my-posh/mi_tema.omp.json | source

alias ls "eza --color=always --group-directories-first --icons"
alias ll "eza -la --icons --git --group-directories-first"
alias lt "eza --tree --level=2 --icons --group-directories-first"
alias cat "bat --paging=never"
alias lg "lazygit"
alias cd "z"
alias zi "z -i"
alias convertir-nsz "~/scripts/convertir-nsz"

if status is-interactive
    bind -e \n -M default 2>/dev/null
    bind -e \n -M insert 2>/dev/null
    bind -e \n -M visual 2>/dev/null
    bind \n accept-autosuggestion
    bind -M insert \n accept-autosuggestion
    fastfetch --config $XDG_CONFIG_HOME/fastfetch/config.jsonc
end
