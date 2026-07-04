# Alias d para entrar a Distrobox
alias d="distrobox enter dev"

# Si estamos dentro de un contenedor (como Distrobox), usamos un archivo de configuración de Starship personalizado
if test -f /run/.containerenv
    set -gx STARSHIP_CONFIG /home/alejandro/.config/starship_distrobox.toml
end
