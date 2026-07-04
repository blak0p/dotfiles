# Redirigir a ~/dev al entrar a un contenedor de Distrobox
if status is-interactive
    if test -f /run/.containerenv
        # Si entramos al contenedor y estamos en el home, nos movemos directo a ~/dev
        # Esto evita perder el contexto si entramos desde una subcarpeta de un proyecto
        if test "$PWD" = "$HOME"; or test "$PWD" = "/var/home/alejandro"
            cd ~/dev
        end
    end
end
