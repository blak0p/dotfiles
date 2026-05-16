# 🚀 Dotfiles de Alejandro-M-P

Este repositorio contiene mi configuración personal, scripts unificados y herramientas de hardware.

## 📁 Estructura
- `home/`: Archivos de configuración de la raíz (`.bashrc`, `.zshrc`, `.gitconfig`).
- `config/`: Configuraciones de aplicaciones (`kitty`, `fastfetch`, `axiom`, `starship`, etc.).
- `scripts/`: Mis utilitarios personales (audio, micro, gestión de juegos).
- `hardware/`: Controladores para la pantalla del disipador Deepcool AK620.
- `dev/`: Código fuente de proyectos personales (Axiom).

## 🛠️ Instalación rápida
Para restaurar estos archivos en un sistema nuevo, puedes usar el script de setup o crear enlaces manuales:

```bash
# Ejemplo para bash
ln -sf ~/dotfiles/home/.bashrc ~/.bashrc

# Ejemplo para scripts
ln -sf ~/dotfiles/scripts ~/scripts
```

## 🎮 Gestión de Juegos (Switch)
He unificado los scripts de gestión de ROMs para que sea más fácil:
- `auto_nsz.sh`: Servicio que vigila la carpeta y convierte NSZ a NSP automáticamente.
- `convertir-nsz`: Script "maestro" para organizar, convertir y limpiar nombres.
- `organizar.sh`: Separa juegos base de actualizaciones/DLCs.

---
*Configuración privada para uso personal.*
