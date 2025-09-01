# Homelab System Development Makefile

.PHONY: help run test check format deps clean install dev new-feature push-feature

# Default target
help:
	@echo "Homelab System - Available Commands:"
	@echo "  make run           - Run the application"
	@echo "  make test          - Run all tests"
	@echo "  make check         - Type check code"
	@echo "  make format        - Format all source code"
	@echo "  make deps          - Update dependencies"
	@echo "  make dev           - Run development cycle (format, check, test)"
	@echo "  make clean         - Clean build artifacts"
	@echo "  make install       - Install dependencies"
	@echo ""
	@echo "Git Workflow Commands:"
	@echo "  make new-feature FEATURE=name  - Create new feature branch"
	@echo "  make push-feature              - Push current branch to origin"
	@echo "  make commit-check              - Pre-commit validation"

# Development commands
run:
	gleam run

test:
	gleam test

check:
	gleam check

format:
	gleam format

deps:
	gleam deps download

install: deps

# Complete development cycle
dev: format check test
	@echo "✅ Development cycle complete - all checks passed!"

# Cleanup
clean:
	rm -rf build/
	rm -rf .crush/crush.db*

# Git workflow helpers
new-feature:
	@if [ -z "$(FEATURE)" ]; then \
		echo "❌ Error: Please specify FEATURE name"; \
		echo "Usage: make new-feature FEATURE=server-monitoring"; \
		exit 1; \
	fi
	@echo "🌟 Creating new feature branch: feature/$(FEATURE)"
	@git checkout main
	@git pull origin main || true
	@git checkout -b feature/$(FEATURE)
	@echo "✅ Ready to develop feature/$(FEATURE)"

push-feature:
	@BRANCH=$$(git branch --show-current); \
	if [ "$$BRANCH" = "main" ]; then \
		echo "❌ Cannot push main branch directly"; \
		exit 1; \
	fi; \
	echo "🚀 Pushing $$BRANCH to origin..."; \
	git push origin $$BRANCH

commit-check: dev
	@echo "🔍 Running pre-commit checks..."
	@git add -A
	@echo "✅ Ready to commit!"

# CI/CD simulation
ci: format check test
	@echo "🚀 CI pipeline simulation complete!"