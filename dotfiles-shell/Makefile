.PHONY: all check lint install help

all: check

help:
	@echo "Available targets:"
	@echo "  make check    - Run linting and validations"
	@echo "  make lint     - Run shellcheck on shell scripts"
	@echo "  make install  - Run installer locally"

lint:
	@which shellcheck >/dev/null 2>&1 || (echo "shellcheck is not installed" && exit 1)
	shellcheck install.sh deps/*.sh

check: lint

install:
	./install.sh
