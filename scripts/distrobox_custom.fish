# Normalizar HOME al path del enlace (/home/alejandro) para que Starship renderice la tilde (~) correctamente
if test "$HOME" = "/var/home/alejandro"
    set -gx HOME /home/alejandro
end

# Alias d para entrar a Distrobox y navegar directo a ~/dev
alias d="cd ~/dev && distrobox enter dev"

# Si estamos dentro de un contenedor (como Distrobox), usamos un archivo de configuración de Starship personalizado
if test -f /run/.containerenv
    set -gx STARSHIP_CONFIG /home/alejandro/.config/starship_distrobox.toml
end
