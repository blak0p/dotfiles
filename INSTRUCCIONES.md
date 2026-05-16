# 🛠️ Guía Rápida: Cómo usar mis Dotfiles

Si estás en una PC nueva y querés tener todo como lo tenés ahora, seguí estos pasos:

### 1. Descargar el repositorio
```bash
git clone git@github.com:Alejandro-M-P/dotfiles.git ~/dotfiles
```

### 2. Instalar (crear enlaces)
Copiá y pegá estos comandos para que el sistema reconozca tus configuraciones:

```bash
# Bash y Shell
ln -sf ~/dotfiles/home/.bashrc ~/.bashrc
ln -sf ~/dotfiles/home/.zshrc ~/.zshrc
ln -sf ~/dotfiles/home/.bashrc.d ~/.bashrc.d
ln -sf ~/dotfiles/home/.bash_profile ~/.bash_profile

# Scripts Personales
ln -sf ~/dotfiles/scripts ~/scripts

# Aplicaciones (Kitty, Btop, etc.)
ln -sf ~/dotfiles/config/kitty ~/.config/kitty
ln -sf ~/dotfiles/config/btop ~/.config/btop
ln -sf ~/dotfiles/config/fastfetch ~/.config/fastfetch
ln -sf ~/dotfiles/config/lazygit ~/.config/lazygit
ln -sf ~/dotfiles/config/oh-my-posh ~/.config/oh-my-posh
ln -sf ~/dotfiles/config/starship.tom ~/.config/starship.tom

# Axiom y Hardware
ln -sf ~/dotfiles/config/axiom ~/.config/axiom
ln -sf ~/dotfiles/dev/axiom ~/Documentos/dev/axiom
ln -sf ~/dotfiles/hardware/deepcool-ak620 ~/deepcool-ak620-digital-linux
```

---

## 🧹 Registro de Limpieza (Lo que quité)

Para que el sistema sea más eficiente, eliminé/moví estas cosas redundantes:

1.  **Archivos de Bash inútiles:**
    *   `~/.bashrcs` (Estaba vacío).
    *   `~/.bashrc_temp` (Configuración vieja de ZSH).
2.  **Scripts Redundantes:**
    *   `~/.scripts/`: Borré la carpeta entera. Los scripts `toggle_audio.sh` y `toggle_mic.sh` ahora viven en `~/scripts/` (unificados con el resto).
    *   `~/scripts/convertit.sh`: Borrado (reemplazado por el más potente `convertir-nsz`).
    *   `~/scripts/convertit updates y dlc.sh`: Borrado (reemplazado por el más potente `convertir-nsz`).

*Nota: Los archivos borrados se guardaron una copia en `~/dotfiles/backups/` por si alguna vez necesitás ver qué tenían, pero ya no molestan en tu sistema principal.*
