package internal

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

var distroboxBin string
var execCommand = exec.Command
var lookPath = exec.LookPath

func init() {
	path, err := exec.LookPath("distrobox")
	if err != nil {
		distroboxBin = "/usr/bin/distrobox"
	} else {
		distroboxBin = path
	}
}

// safeHomeDir verifica que homeDir sea seguro para escribir:
// debe contener ".entorno" como segmento del path y no puede ser
// igual al home del host.
func safeHomeDir(homeDir, hostHome string) bool {
	if homeDir == "" || hostHome == "" {
		return false
	}
	absHome, err1 := filepath.Abs(homeDir)
	absHost, err2 := filepath.Abs(hostHome)
	if err1 != nil || err2 != nil {
		return false
	}
	if absHome == absHost {
		return false
	}
	for _, part := range strings.Split(absHome, string(filepath.Separator)) {
		if part == ".entorno" {
			return true
		}
	}
	return false
}

func translateHostFilePath(path, hostHome string) string {
	if path == "" {
		return ""
	}
	if strings.HasPrefix(path, hostHome) {
		return filepath.Join("/run/host", path)
	}
	if strings.HasPrefix(path, "~/") {
		return filepath.Join("/run/host", hostHome, path[2:])
	}
	return path
}

func writeAxiomEnv(homeDir, name string) {
	hostHome, err := os.UserHomeDir()
	if err != nil {
		fmt.Printf("⚠ writeAxiomEnv: no se pudo determinar el home del host: %v\n", err)
		return
	}

	if !safeHomeDir(homeDir, hostHome) {
		fmt.Printf("⚠ writeAxiomEnv: ruta sospechosa '%s', abortando\n", homeDir)
		return
	}

	envFile := filepath.Join(homeDir, ".axiom-env.sh")

	// Translate XDG_CONFIG_HOME
	hostXdgConfig := os.Getenv("XDG_CONFIG_HOME")
	if hostXdgConfig == "" {
		hostXdgConfig = filepath.Join(hostHome, ".config")
	}
	xdgConfigHome := filepath.Join("/run/host", hostXdgConfig)

	// Translate GIT_CONFIG_GLOBAL
	gitConfigGlobal := filepath.Join("/run/host", hostHome, ".gitconfig")

	// Translate XAUTHORITY
	xauth := os.Getenv("XAUTHORITY")
	if xauth != "" {
		xauth = translateHostFilePath(xauth, hostHome)
	}

	content := fmt.Sprintf(`export AXIOM_BUNKER=1
export XDG_CONFIG_HOME=%s
export GIT_CONFIG_GLOBAL=%s
export XDG_DATA_HOME=$HOME/.local/share
export XDG_STATE_HOME=$HOME/.local/state
export XDG_CACHE_HOME=$HOME/.cache
`, xdgConfigHome, gitConfigGlobal)

	if os.Getenv("DISPLAY") != "" {
		content += fmt.Sprintf("export DISPLAY=%s\n", os.Getenv("DISPLAY"))
	}
	if os.Getenv("WAYLAND_DISPLAY") != "" {
		content += fmt.Sprintf("export WAYLAND_DISPLAY=%s\n", os.Getenv("WAYLAND_DISPLAY"))
	}
	if xauth != "" {
		content += fmt.Sprintf("export XAUTHORITY=%s\n", xauth)
	}

	// Write code wrapper script to .local/bin/code
	localBinDir := filepath.Join(homeDir, ".local", "bin")
	if err := os.MkdirAll(localBinDir, 0755); err != nil {
		fmt.Printf("⚠ No se pudo crear .local/bin: %v\n", err)
	}
	codeScriptPath := filepath.Join(localBinDir, "code")
	codeScriptContent := `#!/bin/bash
if [ -x /usr/bin/code ]; then
  exec /usr/bin/code "$@"
else
  echo "VS Code no está instalado en este bunker. Podés instalarlo con: sudo pacman -S code"
  exit 1
fi
`

	if err := os.WriteFile(codeScriptPath, []byte(codeScriptContent), 0755); err != nil {
		fmt.Printf("⚠ No se pudo escribir wrapper de code: %v\n", err)
	}

	content += fmt.Sprintf("\nexport PATH=\"/home/alejandro/.local/bin:$PATH:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin\"\n")
	content += fmt.Sprintf("cd /%s 2>/dev/null || true\n", name)

	if err := os.WriteFile(envFile, []byte(content), 0644); err != nil {
		fmt.Printf("⚠ No se pudo escribir .axiom-env.sh: %v\n", err)
	}

	hostBashrc := filepath.Join(hostHome, ".bashrc")
	bunkerBashrc := filepath.Join(homeDir, ".bashrc")

	hostContent, err := os.ReadFile(hostBashrc)
	if err == nil && strings.Contains(string(hostContent), "AXIOM_BUNKER=1") &&
		!strings.Contains(string(hostContent), "bashrc.d") {
		fmt.Printf("⚠ El .bashrc del host parece corrupto, no se sobreescribe el del bunker\n")
		return
	}

	// Remover symlink previo antes de escribir, para no sobrescribir el .bashrc del host
	if err := os.Remove(bunkerBashrc); err != nil && !os.IsNotExist(err) {
		fmt.Printf("⚠ No se pudo remover %s: %v\n", bunkerBashrc, err)
	}

	bashrcContent := fmt.Sprintf(`export AXIOM_BUNKER=1
[ -f $HOME/.axiom-env.sh ] && source $HOME/.axiom-env.sh
[ -f %s ] && source %s
`, hostBashrc, hostBashrc)
	if err := os.WriteFile(bunkerBashrc, []byte(bashrcContent), 0644); err != nil {
		fmt.Printf("⚠ No se pudo escribir .bashrc del bunker: %v\n", err)
	}

	// === FISH SHELL SUPPORT ===
	fishContent := fmt.Sprintf(`set -x AXIOM_BUNKER 1
set -x XDG_CONFIG_HOME %s
set -x GIT_CONFIG_GLOBAL %s
set -x XDG_DATA_HOME $HOME/.local/share
set -x XDG_STATE_HOME $HOME/.local/state
set -x XDG_CACHE_HOME $HOME/.cache
`, xdgConfigHome, gitConfigGlobal)

	if os.Getenv("DISPLAY") != "" {
		fishContent += fmt.Sprintf("set -x DISPLAY %s\n", os.Getenv("DISPLAY"))
	}
	if os.Getenv("WAYLAND_DISPLAY") != "" {
		fishContent += fmt.Sprintf("set -x WAYLAND_DISPLAY %s\n", os.Getenv("WAYLAND_DISPLAY"))
	}
	if xauth != "" {
		fishContent += fmt.Sprintf("set -x XAUTHORITY %s\n", xauth)
	}

	fishContent += "\nset -x PATH /home/alejandro/.local/bin $PATH /home/linuxbrew/.linuxbrew/bin /home/linuxbrew/.linuxbrew/sbin\n"
	fishContent += fmt.Sprintf("cd /%s 2>/dev/null || true\n", name)

	fishEnvFile := filepath.Join(homeDir, ".axiom-env.fish")
	if err := os.WriteFile(fishEnvFile, []byte(fishContent), 0644); err != nil {
		fmt.Printf("⚠ No se pudo escribir .axiom-env.fish: %v\n", err)
	}

	fishConfigDir := filepath.Join(homeDir, ".config", "fish")
	if err := os.MkdirAll(fishConfigDir, 0755); err != nil {
		fmt.Printf("⚠ No se pudo crear directorio de config de fish: %v\n", err)
	}

	hostFishConfig := filepath.Join(hostHome, ".config", "fish", "config.fish")
	bunkerFishConfig := filepath.Join(fishConfigDir, "config.fish")

	if err := os.Remove(bunkerFishConfig); err != nil && !os.IsNotExist(err) {
		fmt.Printf("⚠ No se pudo remover %s: %v\n", bunkerFishConfig, err)
	}

	fishConfigContent := fmt.Sprintf(`set -x AXIOM_BUNKER 1
if test -f $HOME/.axiom-env.fish
    source $HOME/.axiom-env.fish
end
if test -f %s
    source %s
end
`, hostFishConfig, hostFishConfig)

	if err := os.WriteFile(bunkerFishConfig, []byte(fishConfigContent), 0644); err != nil {
		fmt.Printf("⚠ No se pudo escribir config.fish del bunker: %v\n", err)
	}
}

func cleanRelativeHomePath(p, home string) string {
	if strings.HasPrefix(p, "~/") {
		return p[2:]
	}
	if p == "~" {
		return ""
	}
	if filepath.IsAbs(p) {
		rel, err := filepath.Rel(home, p)
		if err == nil && !strings.HasPrefix(rel, "..") {
			return rel
		}
		return p
	}
	return p
}

func runSetupScript(cfg Config, name string) error {
	hostHome, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("no se pudo determinar el home del host: %w", err)
	}
	homeDir := cfg.HomeDir(name)
	setupFile := filepath.Join(homeDir, ".axiom-setup.sh")

	script := `#!/bin/sh
setup_symlink() {
  local target="$1"
  local dest="$2"

  case "$dest" in
    \~/*)
      dest="$HOME/${dest#\~/}"
      ;;
    \~)
      dest="$HOME"
      ;;
    /*)
      ;;
    *)
      dest="$HOME/$dest"
      ;;
  esac

  local cmd_prefix=""
  if [ "${dest#/home/}" = "$dest" ] && [ "${dest#/root/}" = "$dest" ]; then
    cmd_prefix="sudo"
  fi

  $cmd_prefix mkdir -p "$(dirname "$dest")"

  if [ -L "$dest" ]; then
    local current_target
    current_target=$(readlink "$dest")
    if [ "$current_target" = "$target" ]; then
      return 0
    fi
    echo "⚠ Warning: Symlink $dest points to $current_target instead of $target. Backing up and overwriting."
    $cmd_prefix mv "$dest" "${dest}.bak.$(date +%s)"
  elif [ -e "$dest" ]; then
    echo "⚠ Warning: File or directory exists at $dest. Backing up and overwriting."
    $cmd_prefix mv "$dest" "${dest}.bak.$(date +%s)"
  fi

  $cmd_prefix ln -sf "$target" "$dest"
}

`
	// Mandatory symlinks
	vscodeTarget := filepath.Join("/run/host", hostHome, ".vscode", "extensions")
	script += fmt.Sprintf("setup_symlink %q %q\n", vscodeTarget, "~/.vscode/extensions")

	nvimShareTarget := filepath.Join("/run/host", hostHome, ".local", "share", "nvim")
	script += fmt.Sprintf("setup_symlink %q %q\n", nvimShareTarget, "~/.local/share/nvim")

	nvimStateTarget := filepath.Join("/run/host", hostHome, ".local", "state", "nvim")
	script += fmt.Sprintf("setup_symlink %q %q\n", nvimStateTarget, "~/.local/state/nvim")

	// Custom TOML symlinks
	sc := LoadSharedConfig()
	for _, p := range sc.Symlinks {
		if p == "" {
			continue
		}
		rel := cleanRelativeHomePath(p, hostHome)
		if rel == "" {
			continue
		}

		var target string
		var dest string

		if filepath.IsAbs(rel) {
			target = filepath.Join("/run/host", rel)
			dest = rel
		} else {
			target = filepath.Join("/run/host", hostHome, rel)
			dest = filepath.Join("~", rel)
		}

		script += fmt.Sprintf("setup_symlink %q %q\n", target, dest)
	}

	// Clean and reconstruct Homebrew directories, filtering out 'code' symlink

	if err := os.WriteFile(setupFile, []byte(script), 0755); err != nil {
		return fmt.Errorf("no se pudo escribir .axiom-setup.sh: %w", err)
	}

	cmd := execCommand(distroboxBin, "enter", name, "--", "sh", "-c", "[ -f ~/.axiom-setup.sh ] && sh ~/.axiom-setup.sh")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("no se pudo ejecutar .axiom-setup.sh dentro del contenedor: %w", err)
	}

	return nil
}

func Create(cfg Config, name string) error {
	codeDir := cfg.CodeDir(name)
	homeDir := cfg.HomeDir(name)
	hostHome, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("no se pudo determinar el home del host: %w", err)
	}

	if !safeHomeDir(homeDir, hostHome) {
		return fmt.Errorf("homeDir '%s' no es seguro, abortando", homeDir)
	}

	dirs := []string{codeDir, homeDir}
	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0700); err != nil {
			return fmt.Errorf("no se pudo crear el directorio %s: %w", dir, err)
		}
	}

	exists, err := bunkerExists(name)
	if err != nil {
		return fmt.Errorf("no se pudo verificar si existe el entorno: %w", err)
	}

	if !exists {
		sshSocket := os.Getenv("SSH_AUTH_SOCK")
		flags := fmt.Sprintf("--volume %s:/%s:z", codeDir, name)
		if sshSocket != "" {
			flags += fmt.Sprintf(" --volume %s:%s:ro", sshSocket, sshSocket)
		}
		flags += " --volume /var/home/linuxbrew/.linuxbrew:/home/linuxbrew/.linuxbrew:ro"
		flags += " --env AXIOM_BUNKER=1"

		packages := packagesForImage(cfg.Image)
		fmt.Printf("→ Creando entorno '%s' con paquetes: %s...\n", name, packages)

		cmd := execCommand(distroboxBin, "create",
			"--name", name,
			"--image", cfg.Image,
			"--home", homeDir,
			"--additional-flags", flags,
			"--additional-packages", packages,
			"--yes",
		)
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("distrobox create falló: %w", err)
		}

		fmt.Println("→ Inicializando home del entorno...")
		initCmd := execCommand(distroboxBin, "enter", name, "--", "true")
		initCmd.Stdout = os.Stdout
		initCmd.Stderr = os.Stderr
		if err := initCmd.Run(); err != nil {
			fmt.Printf("⚠ Aviso durante inicialización: %v\n", err)
		}

		fmt.Println("→ Limpiando home del entorno...")
		cleanupCmd := execCommand("podman", "unshare", "rm", "-rf",
			filepath.Join(homeDir, ".bashrc"),
			filepath.Join(homeDir, ".bashrc.d"),
			filepath.Join(homeDir, ".nanorc"),
			filepath.Join(homeDir, ".gitconfig"),
			filepath.Join(homeDir, ".git-credentials"),
			filepath.Join(homeDir, ".fzf.bash"),
			filepath.Join(homeDir, ".bash"),
			filepath.Join(homeDir, ".engram"),
			filepath.Join(homeDir, ".config"),
		)
		if err := cleanupCmd.Run(); err != nil {
			fmt.Printf("⚠ Aviso durante limpieza del home: %v\n", err)
		}

		fmt.Println("→ Enlazando configuraciones...")
		if err := runSetupScript(cfg, name); err != nil {
			fmt.Printf("⚠ Aviso al enlazar configuraciones: %v\n", err)
		}
	} else {
		fmt.Printf("→ El entorno '%s' ya existe, actualizando configuración...\n", name)
		if err := runSetupScript(cfg, name); err != nil {
			fmt.Printf("⚠ Aviso al actualizar configuraciones: %v\n", err)
		}
	}

	writeAxiomEnv(homeDir, name)

	fmt.Printf("✓ Entorno '%s' listo\n", name)
	fmt.Println("→ Usa 'axiom enter <nombre>' para entrar.")
	return nil
}

func Enter(cfg Config, name string) error {
	exists, err := bunkerExists(name)
	if err != nil {
		return err
	}
	if !exists {
		return fmt.Errorf("el entorno '%s' no existe", name)
	}

	homeDir := cfg.HomeDir(name)
	writeAxiomEnv(homeDir, name)
	if err := runSetupScript(cfg, name); err != nil {
		fmt.Printf("⚠ Aviso al sincronizar symlinks: %v\n", err)
	}

	cmd := execCommand(distroboxBin, "enter", name)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func List() error {
	cmd := execCommand(distroboxBin, "list")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func Delete(cfg Config, name string) error {
	homeDir := cfg.HomeDir(name)
	hostHome, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("no se pudo determinar el home del host: %w", err)
	}

	if !safeHomeDir(homeDir, hostHome) {
		return fmt.Errorf("homeDir '%s' no es seguro, abortando", homeDir)
	}

	fmt.Printf("¿Eliminar '%s'? (El código en %s NO se borrará) [s/N]: ", name, cfg.CodeDir(name))

	reader := bufio.NewReader(os.Stdin)
	confirm, err := reader.ReadString('\n')
	if err != nil {
		return fmt.Errorf("error leyendo confirmación: %w", err)
	}
	confirm = strings.TrimSpace(confirm)

	if strings.ToLower(confirm) != "s" {
		fmt.Println("Operación cancelada.")
		return nil
	}

	cmd := execCommand(distroboxBin, "rm", name, "--force")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("distrobox rm falló: %w", err)
	}

	if err := execCommand("podman", "unshare", "rm", "-rf", homeDir).Run(); err != nil {
		fmt.Printf("⚠ Aviso: podman unshare no pudo remover %s: %v\n", homeDir, err)
	}
	if err := os.RemoveAll(homeDir); err != nil {
		fmt.Printf("⚠ Aviso: no se pudo remover completamente %s: %v\n", homeDir, err)
	}
	return nil
}

// packagesForImage devuelve los paquetes básicos según la imagen.
func packagesForImage(image string) string {
	img := strings.ToLower(image)
	if strings.Contains(img, "archlinux") || strings.Contains(img, "arch") {
		return "git github-cli nano code jq"
	}
	return "git nano"
}

// bunkerExists comprueba match exacto de nombre contra el output de distrobox list.
func bunkerExists(name string) (bool, error) {
	// 1. Check podman
	if _, err := lookPath("podman"); err == nil {
		cmd := execCommand("podman", "container", "exists", name)
		runErr := cmd.Run()
		if runErr == nil {
			return true, nil
		}
		if runErr != nil {
			if exitErr, ok := runErr.(*exec.ExitError); ok {
				if exitErr.ExitCode() == 1 {
					return false, nil
				}
			}
		}
	}
	// 2. Check docker
	if _, err := lookPath("docker"); err == nil {
		cmd := execCommand("docker", "inspect", name)
		runErr := cmd.Run()
		if runErr == nil {
			return true, nil
		}
		if runErr != nil {
			if exitErr, ok := runErr.(*exec.ExitError); ok {
				if exitErr.ExitCode() == 1 {
					return false, nil
				}
			}
		}
	}
	// 3. Fallback to distrobox list
	cmd := execCommand(distroboxBin, "list")
	out, err := cmd.Output()
	if err != nil {
		return false, err
	}
	for _, line := range strings.Split(string(out), "\n") {
		fields := strings.Fields(line)
		for _, f := range fields {
			if f == name {
				return true, nil
			}
		}
	}
	return false, nil
}

func translateHostPath(src string, hostHome string) string {
	var fullPath string
	if src == "~" {
		fullPath = hostHome
	} else if strings.HasPrefix(src, "~/") {
		fullPath = filepath.Join(hostHome, src[2:])
	} else if filepath.IsAbs(src) {
		fullPath = src
	} else {
		fullPath = filepath.Join(hostHome, src)
	}
	return filepath.Join("/run/host", filepath.Clean(fullPath))
}

func expandContainerPath(dst string, containerHome string) string {
	if dst == "~" {
		return containerHome
	} else if strings.HasPrefix(dst, "~/") {
		return filepath.Join(containerHome, dst[2:])
	} else if filepath.IsAbs(dst) {
		return filepath.Clean(dst)
	} else {
		return filepath.Join(containerHome, dst)
	}
}


