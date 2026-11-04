function gentle --description "Gentle Shell helper: actualiza y abre gentle-shell"
    if not command -q gentle-shell
        echo "Error: gentle-shell no está instalado o no se encuentra en el PATH." >&2
        return 1
    end

    set -l cmd "$argv[1]"
    switch "$cmd"
        case shell
            set -e argv[1]
            gentle-shell upgrade && gentle-shell update --extensions && command gentle-shell $argv
        case '*'
            command gentle-shell $argv
    end
end
