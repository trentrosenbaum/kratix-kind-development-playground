#!/usr/bin/env bash
#
# Documentation quality checks
# Runs markdown linting (vale), spell checking (typos), and link validation (lychee)
#
# Usage:
#   ./scripts/check-docs.sh [command]
#
# Commands:
#   all         Run all checks (default)
#   lint        Run markdown linting only (vale)
#   spell       Run spell checking only (typos)
#   links       Run link validation only (lychee)
#   help        Show this help message
#
# Install tools:
#   brew install vale typos-cli lychee

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall status
FAILED=0

print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}! $1${NC}"
}

check_tool() {
    local tool=$1
    if ! command -v "$tool" &> /dev/null; then
        return 1
    fi
    return 0
}

check_prerequisites() {
    local missing=0

    print_header "Checking prerequisites"

    if check_tool "vale"; then
        print_success "vale found"
    else
        print_error "vale is not installed (brew install vale)"
        missing=1
    fi

    if check_tool "typos"; then
        print_success "typos found"
    else
        print_error "typos is not installed (brew install typos-cli)"
        missing=1
    fi

    if check_tool "lychee"; then
        print_success "lychee found"
    else
        print_error "lychee is not installed (brew install lychee)"
        missing=1
    fi

    if [[ $missing -eq 1 ]]; then
        echo ""
        print_warning "Install missing tools: brew install vale typos-cli lychee"
        return 1
    fi

    return 0
}

run_markdown_lint() {
    print_header "Running Markdown linting (vale)"

    if ! check_tool "vale"; then
        print_error "vale not installed, skipping"
        FAILED=1
        return
    fi

    cd "$PROJECT_ROOT"

    # Sync vale packages if needed
    if [[ ! -d "$SCRIPT_DIR/.vale/styles" ]]; then
        echo "Syncing vale packages..."
        vale --config "$SCRIPT_DIR/.vale.ini" sync
    fi

    if vale --config "$SCRIPT_DIR/.vale.ini" .; then
        print_success "Markdown linting passed"
    else
        print_error "Markdown linting failed"
        FAILED=1
    fi
}

run_spell_check() {
    print_header "Running spell check (typos)"

    if ! check_tool "typos"; then
        print_error "typos not installed, skipping"
        FAILED=1
        return
    fi

    cd "$PROJECT_ROOT"

    if typos --config "$SCRIPT_DIR/typos.toml" .; then
        print_success "Spell check passed"
    else
        print_error "Spell check failed"
        FAILED=1
    fi
}

run_link_check() {
    print_header "Running link validation (lychee)"

    if ! check_tool "lychee"; then
        print_error "lychee not installed, skipping"
        FAILED=1
        return
    fi

    cd "$PROJECT_ROOT"

    # Find all markdown files and pass them to lychee
    if find . -name "*.md" -not -path "./.git/*" -not -path "./node_modules/*" | xargs lychee --config "$SCRIPT_DIR/.lychee.toml"; then
        print_success "Link validation passed"
    else
        print_error "Link validation failed"
        FAILED=1
    fi
}

show_help() {
    head -18 "$0" | tail -15
}

run_all() {
    if ! check_prerequisites; then
        exit 1
    fi

    run_markdown_lint
    run_spell_check
    run_link_check

    echo ""
    if [[ $FAILED -eq 0 ]]; then
        print_success "All checks passed!"
    else
        print_error "Some checks failed"
        exit 1
    fi
}

# Main
cd "$PROJECT_ROOT"

case "${1:-all}" in
    all)
        run_all
        ;;
    lint)
        run_markdown_lint
        [[ $FAILED -eq 0 ]] || exit 1
        ;;
    spell)
        run_spell_check
        [[ $FAILED -eq 0 ]] || exit 1
        ;;
    links)
        run_link_check
        [[ $FAILED -eq 0 ]] || exit 1
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
