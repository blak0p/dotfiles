package internal

import (
	"os"
	"path/filepath"

	"github.com/BurntSushi/toml"
)

type Config struct {
	BaseDir    string
	EntornoDir string
	ModelsDir  string
	SSHKey     string
	Image      string
}

type SymlinkEntry struct {
	Src string `toml:"src"`
	Dst string `toml:"dst"`
}

type SharedConfig struct {
	Symlinks []SymlinkEntry `toml:"symlinks"`
}

func DefaultConfig() Config {
	home, _ := os.UserHomeDir()
	base := filepath.Join(home, "Documentos", "dev")
	return Config{
		BaseDir:    base,
		EntornoDir: filepath.Join(base, ".entorno"),
		ModelsDir:  filepath.Join(base, "ai_config", "models"),
		SSHKey:     filepath.Join(home, ".ssh", "id_ed25519"),
		Image:      "archlinux:latest",
	}
}

func LoadSharedConfig() SharedConfig {
	home, _ := os.UserHomeDir()
	path := filepath.Join(home, ".config", "axiom", "shared.toml")
	var sc SharedConfig
	if _, err := toml.DecodeFile(path, &sc); err != nil {
		return SharedConfig{}
	}
	return sc
}

func (c Config) CodeDir(name string) string {
	return filepath.Join(c.BaseDir, name)
}

func (c Config) HomeDir(name string) string {
	return filepath.Join(c.EntornoDir, name)
}
