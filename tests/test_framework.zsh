#!/usr/bin/env zsh

# Test framework for zsh-fzf-git-worktree

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test state
CURRENT_TEST=""
TEST_FAILED=0

# Temporary test directory
TEST_DIR=""

# Assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo "${RED}✗ $message${NC}"
        echo "  Expected: '$expected'"
        echo "  Actual:   '$actual'"
        TEST_FAILED=1
        return 1
    fi
}

assert_not_equals() {
    local unexpected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"

    if [[ "$unexpected" != "$actual" ]]; then
        return 0
    else
        echo "${RED}✗ $message${NC}"
        echo "  Value should not be: '$unexpected'"
        TEST_FAILED=1
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"

    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        echo "${RED}✗ $message${NC}"
        echo "  String: '$haystack'"
        echo "  Should contain: '$needle'"
        TEST_FAILED=1
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should not contain substring}"

    if [[ "$haystack" != *"$needle"* ]]; then
        return 0
    else
        echo "${RED}✗ $message${NC}"
        echo "  String: '$haystack'"
        echo "  Should not contain: '$needle'"
        TEST_FAILED=1
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Exit code should match}"

    if [[ "$expected" -eq "$actual" ]]; then
        return 0
    else
        echo "${RED}✗ $message${NC}"
        echo "  Expected exit code: $expected"
        echo "  Actual exit code:   $actual"
        TEST_FAILED=1
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory should exist}"

    if [[ -d "$dir" ]]; then
        return 0
    else
        echo "${RED}✗ $message${NC}"
        echo "  Directory not found: '$dir'"
        TEST_FAILED=1
        return 1
    fi
}

assert_dir_not_exists() {
    local dir="$1"
    local message="${2:-Directory should not exist}"

    if [[ ! -d "$dir" ]]; then
        return 0
    else
        echo "${RED}✗ $message${NC}"
        echo "  Directory should not exist: '$dir'"
        TEST_FAILED=1
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"

    if [[ -f "$file" ]]; then
        return 0
    else
        echo "${RED}✗ $message${NC}"
        echo "  File not found: '$file'"
        TEST_FAILED=1
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist}"

    if [[ ! -f "$file" ]]; then
        return 0
    else
        echo "${RED}✗ $message${NC}"
        echo "  File should not exist: '$file'"
        TEST_FAILED=1
        return 1
    fi
}

# Test runner functions
run_test() {
    local test_name="$1"
    CURRENT_TEST="$test_name"
    TEST_FAILED=0
    ((TESTS_RUN++))

    echo -n "  $test_name ... "

    # Run the test in a subshell to isolate it
    (
        # Setup test environment
        setup_test_env

        # Run the test
        $test_name
    )
    local exit_code=$?

    # Cleanup test environment
    cleanup_test_env

    if [[ $exit_code -eq 0 && $TEST_FAILED -eq 0 ]]; then
        echo "${GREEN}✓${NC}"
        ((TESTS_PASSED++))
    else
        echo "${RED}✗${NC}"
        ((TESTS_FAILED++))
    fi
}

run_test_suite() {
    local suite_name="$1"
    echo "${BLUE}Running test suite: $suite_name${NC}"

    # Run all functions starting with test_
    for test_func in $(typeset -f | grep "^test_" | awk '{print $1}'); do
        run_test "$test_func"
    done
}

skip_test() {
    local test_name="$1"
    local reason="${2:-No reason given}"
    echo "  $test_name ... ${YELLOW}SKIPPED${NC} ($reason)"
    ((TESTS_SKIPPED++))
}

# Setup and teardown
setup_test_env() {
    # Create a temporary directory for the test
    TEST_DIR=$(mktemp -d -t "fzf-git-worktree-test-XXXXXX")
    cd "$TEST_DIR" || exit 1
}

cleanup_test_env() {
    # Clean up the temporary directory
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Report functions
print_test_summary() {
    echo
    echo "==============================="
    echo "Test Summary"
    echo "==============================="
    echo "Total tests:   $TESTS_RUN"
    echo "${GREEN}Passed:        $TESTS_PASSED${NC}"
    echo "${RED}Failed:        $TESTS_FAILED${NC}"
    echo "${YELLOW}Skipped:       $TESTS_SKIPPED${NC}"
    echo "==============================="

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo "${RED}FAILED${NC}"
        return 1
    else
        echo "${GREEN}PASSED${NC}"
        return 0
    fi
}

# Helper to create a git repository for testing
create_test_repo() {
    local repo_name="${1:-test-repo}"
    mkdir -p "$repo_name"
    cd "$repo_name" || return 1
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add test.txt
    git commit -m "Initial commit"
    cd ..
}

# Helper to source the plugin in test mode
source_plugin() {
    # Source the plugin file
    source "${PLUGIN_PATH:-../zsh-fzf-git-worktree.zsh}"
}
