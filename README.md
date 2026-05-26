# 🚀 Dotfiles de Alejandro-M-P

Configuración personal modular. Cada módulo es autónomo: incluye scripts, configs y systemd.

## 📦 Instalación

```bash
git clone git@github.com:Alejandro-M-P/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

Elegís los módulos que querés con una checklist. Solo eso se instala.

## 📁 Estructura

```
dotfiles/
├── install.sh          # Instalador con checklist de módulos
├── doctor.sh           # Diagnóstico modular
├── home/               # Base para shell-core
├── config/             # Base para módulos (legacy)
├── scripts/            # Base para módulos (legacy)
├── modules/
│   ├── shell-core/     # bashrc, bashrc.d, zshrc, nanorc, gitconfig
│   ├── prompt/         # oh-my-posh, starship
│   ├── apps/           # kitty, btop, fastfetch
│   ├── gaming/         # Steam autopicture, ROM tools, systemd
│   ├── ai/             # Gentle AI, Ollama
│   ├── dev/            # LazyGit, Axiom, scripts
│   └── hardware/       # Deepcool AK620 + daemon
├── install.d.legacy/   # Scripts viejos (referencia)
├── backups/            # Backups automáticos
└── hardware/           # Deepcool (legacy)
```

## 🧩 Módulos

| Módulo | shell | scripts | config | systemd | bashrc.d |
|--------|-------|---------|--------|---------|----------|
| shell-core | ✅ | — | — | — | ✅ |
| prompt | — | — | ✅ | — | ✅ |
| apps | — | — | ✅ | — | — |
| gaming | — | ✅ | ✅ | ✅ | — |
| ai | — | ✅ | — | — | ✅ |
| dev | — | ✅ | ✅ | ✅ | ✅ |
| hardware | — | — | ✅ | ✅ | — |

Cada `modules/*/install.sh` sabe exactamente qué linkear y habilitar.

## 🩺 Diagnóstico

```bash
~/dotfiles/doctor.sh
```

Detecta automáticamente los módulos instalados y verifica symlinks + dependencias.

---

*Configuración privada para uso personal.*
