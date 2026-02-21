SHELL := /bin/bash

.PHONY: lint lint-shell lint-compose

lint: lint-shell lint-compose

lint-shell:
	@command -v shellcheck >/dev/null 2>&1 || { \
		echo "Error: shellcheck is required. Install it first."; \
		exit 1; \
	}
	@bash -n devbox.sh
	@shellcheck devbox.sh

lint-compose:
	@docker compose config >/dev/null
