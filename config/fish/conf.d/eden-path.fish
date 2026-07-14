# Eden PATH — host only (Eden app lives on host filesystem)
if set -q BUNKER
    return
end
set -gx PATH $PATH $HOME/.local/share/eden-app
