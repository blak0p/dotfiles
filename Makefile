.PHONY: all check lint update-submodules install help

all: check

help:
	@echo "Available targets:"
	@echo "  make check              - Run linter and verify submodules status"
	@echo "  make lint               - Run shellcheck on shell scripts"
	@echo "  make update-submodules  - Fetch and update all submodules to remote HEAD"
	@echo "  make install            - Run umbrella installer (--all)"

lint:
	@which shellcheck >/dev/null 2>&1 || (echo "shellcheck is not installed" && exit 1)
	shellcheck *.sh

check: lint
	git submodule status

update-submodules:
	git submodule update --remote --merge

install:
	./install.sh --all
