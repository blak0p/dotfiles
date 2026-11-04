.PHONY: all check lint install help

all: check

help:
	@echo "Available targets:"
	@echo "  make check              - Run linter and installer smoke check"
	@echo "  make lint               - Run shellcheck on shell scripts"
	@echo "  make install            - Run installer (--all)"

lint:
	@which shellcheck >/dev/null 2>&1 || (echo "shellcheck is not installed" && exit 1)
	shellcheck *.sh

check: lint
	bash ./install.sh --help >/dev/null

install:
	./install.sh --all
