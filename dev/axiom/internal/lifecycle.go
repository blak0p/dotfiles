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

func applySymlinks(hostHome, homeDir string, sc SharedConfig) {
	if !safeHomeDir(homeDir, hostHome) {
		fmt.Printf("⚠ applySymlinks: ruta sospechosa '%s', abortando\n", homeDir)
		return
	}

	if err := os.MkdirAll(filepath.Join(homeDir, ".config"), 0700); err != nil {
		fmt.Printf("  ⚠ No se pudo crear .config: %v\n", err)
	}

	for _, l := range sc.Symlinks {
		src := filepath.Join(hostHome, l.Src)
		dst := filepath.Join(homeDir, l.Dst)

		absSrc, _ := filepath.Abs(src)
		absDst, _ := filepath.Abs(dst)
		if absSrc == absDst {
			fmt.Printf("  ⚠ Symlink circular ignorado: %s\n", l.Src)
			continue
		}

		if _, err := os.Stat(src); os.IsNotExist(err) {
			continue
		}

		if err := os.MkdirAll(filepath.Dir(dst), 0700); err != nil {
			fmt.Printf("  ⚠ No se pudo crear directorio para %s: %v\n", l.Src, err)
			continue
		}

		if err := exec.Command("podman", "unshare", "rm", "-rf", dst).Run(); err != nil {
			fmt.Printf("  ⚠ podman unshare no pudo remover %s: %v\n", dst, err)
		}
		if err := os.Remove(dst); err != nil && !os.IsNotExist(err) {
			fmt.Printf("  ⚠ No se pudo remover %s: %v\n", dst, err)
		}

		if err := os.Symlink(src, dst); err != nil {
			fmt.Printf("  ⚠ No se pudo enlazar %s: %v\n", l.Src, err)
		} else {
			fmt.Printf("  → %s\n", l.Src)
		}
	}
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
	content := fmt.Sprintf("export AXIOM_BUNKER=1\nexport PATH=\"/home/alejandro/.local/bin:/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH\"\ncd /%s 2>/dev/null || true\n", name)
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

	bashrcContent := fmt.Sprintf("export AXIOM_BUNKER=1\n[ -f %s ] && source %s\n", hostBashrc, hostBashrc)
	if err := os.WriteFile(bunkerBashrc, []byte(bashrcContent), 0644); err != nil {
		fmt.Printf("⚠ No se pudo escribir .bashrc del bunker: %v\n", err)
	}
}

func Create(cfg Config, name string) error {
	codeDir := cfg.CodeDir(name)
	homeDir := cfg.HomeDir(name)
	sc := LoadSharedConfig()
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

		packages := "git github-cli nano"
		fmt.Printf("→ Creando entorno '%s' con paquetes: %s...\n", name, packages)

		cmd := exec.Command(distroboxBin, "create",
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
		initCmd := exec.Command(distroboxBin, "enter", name, "--", "true")
		initCmd.Stdout = os.Stdout
		initCmd.Stderr = os.Stderr
		if err := initCmd.Run(); err != nil {
			fmt.Printf("⚠ Aviso durante inicialización: %v\n", err)
		}

		fmt.Println("→ Limpiando home del entorno...")
		cleanupCmd := exec.Command("podman", "unshare", "rm", "-rf",
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
		applySymlinks(hostHome, homeDir, sc)
	} else {
		fmt.Printf("→ El entorno '%s' ya existe, actualizando configuración...\n", name)
		applySymlinks(hostHome, homeDir, sc)
	}

	writeAxiomEnv(homeDir, name)

	fmt.Printf("✓ Entorno '%s' listo\n", name)
	fmt.Println("→ Usa 'axiom enter <nombre>' para entrar.")
	return nil
}

func Sync(cfg Config, name string) error {
	homeDir := cfg.HomeDir(name)
	hostHome, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("no se pudo determinar el home del host: %w", err)
	}
	sc := LoadSharedConfig()

	if !safeHomeDir(homeDir, hostHome) {
		return fmt.Errorf("homeDir '%s' no es seguro, abortando", homeDir)
	}

	exists, err := bunkerExists(name)
	if err != nil {
		return fmt.Errorf("no se pudo verificar si existe el entorno: %w", err)
	}
	if !exists {
		return fmt.Errorf("el entorno '%s' no existe", name)
	}

	fmt.Printf("→ Sincronizando symlinks de '%s'...\n", name)
	applySymlinks(hostHome, homeDir, sc)
	writeAxiomEnv(homeDir, name)
	fmt.Printf("✓ '%s' sincronizado\n", name)
	return nil
}

func SyncAll(cfg Config) error {
	hostHome, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("no se pudo determinar el home del host: %w", err)
	}
	sc := LoadSharedConfig()

	entries, err := os.ReadDir(cfg.EntornoDir)
	if err != nil {
		return fmt.Errorf("no se pudo leer %s: %w", cfg.EntornoDir, err)
	}

	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		name := e.Name()
		homeDir := cfg.HomeDir(name)

		if !safeHomeDir(homeDir, hostHome) {
			fmt.Printf("⚠ Saltando '%s': homeDir sospechoso\n", name)
			continue
		}

		fmt.Printf("→ Sincronizando '%s'...\n", name)
		applySymlinks(hostHome, homeDir, sc)
		writeAxiomEnv(homeDir, name)
		fmt.Printf("✓ '%s' listo\n", name)
	}
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

	cmd := exec.Command(distroboxBin, "enter", name)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func List() error {
	cmd := exec.Command(distroboxBin, "list")
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

	cmd := exec.Command(distroboxBin, "rm", name, "--force")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("distrobox rm falló: %w", err)
	}

	if err := exec.Command("podman", "unshare", "rm", "-rf", homeDir).Run(); err != nil {
		fmt.Printf("⚠ Aviso: podman unshare no pudo remover %s: %v\n", homeDir, err)
	}
	if err := os.RemoveAll(homeDir); err != nil {
		fmt.Printf("⚠ Aviso: no se pudo remover completamente %s: %v\n", homeDir, err)
	}
	return nil
}

// bunkerExists comprueba match exacto de nombre contra el output de distrobox list.
func bunkerExists(name string) (bool, error) {
	out, err := exec.Command(distroboxBin, "list").Output()
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
