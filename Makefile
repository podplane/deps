# Podplane <https://podplane.dev>
# Copyright The Podplane Authors
# SPDX-License-Identifier: Apache-2.0

.PHONY: setup precommit build clean

setup: ## Verify required tools and enable git hooks
	@command -v curl >/dev/null 2>&1 || { echo "curl is required but not installed"; exit 1; }
	@command -v gh >/dev/null 2>&1 || { echo "gh is required but not installed"; exit 1; }
	@command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed"; exit 1; }
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck is required but not installed"; exit 1; }
	@echo "All required tools are installed."
	@cp scripts/git-hooks/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "Git hooks installed."

precommit: ## Run pre-commit checks
	shellcheck scripts/*.sh scripts/git-hooks/pre-commit
	find config $(if $(wildcard dist),dist) -name '*.json' -print0 | xargs -0 -n1 jq empty

build:
	bash scripts/build.sh

clean:
	rm -rf dist
