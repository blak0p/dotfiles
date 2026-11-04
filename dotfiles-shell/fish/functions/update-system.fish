function update-system --description "Actualiza distrobox Fedora (dnf) y Homebrew"
    echo "==> 1/2 DNF"
    sudo dnf upgrade --refresh -y

    echo "==> 2/2 Homebrew"
    if command -q brew
        brew update
        brew upgrade
        brew cleanup
    else
        echo "brew no instalado, lo salteo"
    end

    echo "Listo, distrobox actualizado."
end
