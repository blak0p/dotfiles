package main

import (
	"fmt"
	"os"

	"github.com/Alejandro-M-P/axiom/internal"
)

func main() {
	cfg := internal.DefaultConfig()

	if len(os.Args) < 2 {
		usage()
		os.Exit(0)
	}

	cmd := os.Args[1]
	arg := ""
	if len(os.Args) >= 3 {
		arg = os.Args[2]
	}

	var err error
	switch cmd {
		case "create":
			err = requireName(cmd, arg)
			if err == nil {
				err = internal.Create(cfg, arg)
			}
		case "enter":
			err = requireName(cmd, arg)
			if err == nil {
				err = internal.Enter(cfg, arg)
			}
		case "sync":
			if arg == "--all" || arg == "" {
				err = internal.SyncAll(cfg)
			} else {
				err = internal.Sync(cfg, arg)
			}
		case "list", "ls":
			err = internal.List()
		case "delete", "rm":
			err = requireName(cmd, arg)
			if err == nil {
				err = internal.Delete(cfg, arg)
			}
		case "help", "--help", "-h":
			usage()
		default:
			fmt.Fprintf(os.Stderr, "Comando desconocido: %s\n\n", cmd)
			usage()
			os.Exit(1)
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func requireName(cmd, name string) error {
	if name == "" {
		return fmt.Errorf("axiom %s necesita un nombre. Ej: axiom %s mi-proyecto", cmd, cmd)
	}
	return nil
}

func usage() {
	fmt.Println(`axiom — gestión de entornos de desarrollo

	Uso:
	axiom create <nombre>   Crea el entorno y entra
	axiom enter  <nombre>   Entra al entorno
	axiom sync <nombre>     Sincroniza symlinks de un entorno
	axiom sync --all        Sincroniza symlinks de todos los entornos
	axiom list              Lista los entornos
	axiom delete <nombre>   Elimina el entorno (el código no se borra)
	axiom help              Muestra esta ayuda`)
}
