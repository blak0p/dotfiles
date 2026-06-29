package internal

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/BurntSushi/toml"
)

func TestSafeHomeDir(t *testing.T) {
	tests := []struct {
		name     string
		homeDir  string
		hostHome string
		want     bool
	}{
		{
			name:     "valid home directory with .entorno",
			homeDir:  "/home/user/.entorno/unity",
			hostHome: "/home/user",
			want:     true,
		},
		{
			name:     "invalid home directory without .entorno",
			homeDir:  "/home/user/unity",
			hostHome: "/home/user",
			want:     false,
		},
		{
			name:     "invalid equal to host home",
			homeDir:  "/home/user",
			hostHome: "/home/user",
			want:     false,
		},
		{
			name:     "empty home directory",
			homeDir:  "",
			hostHome: "/home/user",
			want:     false,
		},
		{
			name:     "empty host home",
			homeDir:  "/home/user/.entorno/unity",
			hostHome: "",
			want:     false,
		},
		{
			name:     "relative path containing .entorno",
			homeDir:  "./.entorno/unity",
			hostHome: "/home/user",
			want:     true,
		},
		{
			name:     "subfolder of host home without .entorno but containing it as substring",
			homeDir:  "/home/user/not.entorno/unity",
			hostHome: "/home/user",
			want:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := safeHomeDir(tt.homeDir, tt.hostHome)
			if got != tt.want {
				t.Errorf("safeHomeDir(%q, %q) = %v; want %v", tt.homeDir, tt.hostHome, got, tt.want)
			}
		})
	}
}

func TestTranslatePath(t *testing.T) {
	tests := []struct {
		name     string
		path     string
		hostHome string
		want     string
	}{
		{
			name:     "absolute path",
			path:     "/etc/configs",
			hostHome: "/home/user",
			want:     "/run/host/etc/configs",
		},
		{
			name:     "tilde home path",
			path:     "~/.ssh",
			hostHome: "/home/user",
			want:     "/run/host/home/user/.ssh",
		},
		{
			name:     "relative path",
			path:     ".config/nvim",
			hostHome: "/home/user",
			want:     "/run/host/home/user/.config/nvim",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := translateHostPath(tt.path, tt.hostHome)
			if got != tt.want {
				t.Errorf("translateHostPath(%q, %q) = %q; want %q", tt.path, tt.hostHome, got, tt.want)
			}
		})
	}
}

func TestExpandContainerPath(t *testing.T) {
	tests := []struct {
		name          string
		path          string
		containerHome string
		want          string
	}{
		{
			name:          "absolute path in container",
			path:          "/etc/configs",
			containerHome: "/home/user/.entorno/unity",
			want:          "/etc/configs",
		},
		{
			name:          "tilde path in container",
			path:          "~/.ssh",
			containerHome: "/home/user/.entorno/unity",
			want:          "/home/user/.entorno/unity/.ssh",
		},
		{
			name:          "relative path in container",
			path:          ".config/nvim",
			containerHome: "/home/user/.entorno/unity",
			want:          "/home/user/.entorno/unity/.config/nvim",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := expandContainerPath(tt.path, tt.containerHome)
			if got != tt.want {
				t.Errorf("expandContainerPath(%q, %q) = %q; want %q", tt.path, tt.containerHome, got, tt.want)
			}
		})
	}
}

func TestBunkerExists(t *testing.T) {
	oldLookPath := lookPath
	oldExecCommand := execCommand
	defer func() {
		lookPath = oldLookPath
		execCommand = oldExecCommand
	}()

	// 1. Podman exists and says container exists (returns exit status 0)
	lookPath = func(file string) (string, error) {
		if file == "podman" {
			return "/usr/bin/podman", nil
		}
		return "", fmt.Errorf("not found")
	}
	execCommand = func(name string, arg ...string) *exec.Cmd {
		if name == "podman" && len(arg) == 3 && arg[0] == "container" && arg[1] == "exists" && arg[2] == "unity" {
			return exec.Command("true")
		}
		return exec.Command("false")
	}

	exists, err := bunkerExists("unity")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if !exists {
		t.Errorf("expected container to exist via podman")
	}

	// 2. Podman exists and says container does NOT exist (exits with 1)
	execCommand = func(name string, arg ...string) *exec.Cmd {
		if name == "podman" && len(arg) == 3 && arg[0] == "container" && arg[1] == "exists" && arg[2] == "unity" {
			return exec.Command("false")
		}
		return exec.Command("false")
	}
	exists, err = bunkerExists("unity")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if exists {
		t.Errorf("expected container to not exist via podman exit status 1")
	}

	// 3. Podman is not found, but docker is found and container exists
	lookPath = func(file string) (string, error) {
		if file == "docker" {
			return "/usr/bin/docker", nil
		}
		return "", fmt.Errorf("not found")
	}
	execCommand = func(name string, arg ...string) *exec.Cmd {
		if name == "docker" && len(arg) == 2 && arg[0] == "inspect" && arg[1] == "unity" {
			return exec.Command("true")
		}
		return exec.Command("false")
	}
	exists, err = bunkerExists("unity")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if !exists {
		t.Errorf("expected container to exist via docker")
	}

	// 4. Neither podman nor docker exist, falls back to distrobox list
	lookPath = func(file string) (string, error) {
		return "", fmt.Errorf("not found")
	}
	execCommand = func(name string, arg ...string) *exec.Cmd {
		if name == distroboxBin && len(arg) == 1 && arg[0] == "list" {
			return exec.Command("echo", "ID           | NAME                 | STATUS     | IMAGE\n1234567890ab | unity                | running    | archlinux:latest")
		}
		return exec.Command("false")
	}
	exists, err = bunkerExists("unity")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if !exists {
		t.Errorf("expected container to exist via distrobox list fallback")
	}
}

func TestLoadSharedConfig(t *testing.T) {
	tmpDir := t.TempDir()
	tomlPath := filepath.Join(tmpDir, "shared.toml")

	content := `symlinks = [
		".ssh",
		".gitconfig"
	]`
	if err := os.WriteFile(tomlPath, []byte(content), 0644); err != nil {
		t.Fatalf("failed to write temp file: %v", err)
	}

	var sc SharedConfig
	if _, err := toml.DecodeFile(tomlPath, &sc); err != nil {
		t.Fatalf("failed to parse TOML: %v", err)
	}

	if len(sc.Symlinks) != 2 {
		t.Errorf("expected 2 symlinks, got %d", len(sc.Symlinks))
	}
	if sc.Symlinks[0] != ".ssh" || sc.Symlinks[1] != ".gitconfig" {
		t.Errorf("unexpected content: %v", sc.Symlinks)
	}
}



