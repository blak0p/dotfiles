# 🚀 Dotfiles de Alejandro-M-P

Este repositorio contiene mi configuración personal, scripts unificados y herramientas de hardware.

## 📁 Estructura
- `home/`: Archivos de configuración de la raíz (`.bashrc`, `.zshrc`, `.gitconfig`).
- `config/`: Configuraciones de aplicaciones (`kitty`, `fastfetch`, `axiom`, `starship`, etc.).
- `scripts/`: Mis utilitarios personales (audio, micro, gestión de juegos).
- `hardware/`: Controladores para la pantalla del disipador Deepcool AK620.
- `dev/`: Código fuente de proyectos personales (Axiom).

## 🛠️ Instalación Automática
Para instalar todo en una máquina nueva, simplemente ejecutá este comando:

```bash
git clone git@github.com:Alejandro-M-P/dotfiles.git ~/dotfiles && bash ~/dotfiles/install.sh
```

El script se encargará de:
1. Crear los enlaces simbólicos (symlinks).
2. Hacer un backup automático de cualquier archivo existente que pueda entrar en conflicto.
3. Organizar las carpetas necesarias (`.config`, `dev`, etc.).

---

## 🧹 Registro de Limpieza (Lo que se unificó)

Para mantener el sistema limpio, se realizaron los siguientes cambios:
- **Scripts:** `~/.scripts/` se movió a `~/scripts/` para evitar duplicidad.
- **Switch:** `convertir-nsz` es ahora el script único de gestión (reemplaza a `convertit.sh`).
- **Bash:** Se eliminaron archivos temporales vacíos (`.bashrcs`, `.bashrc_temp`).

---
*Configuración privada para uso personal.*
