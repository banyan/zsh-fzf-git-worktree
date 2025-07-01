#!/usr/bin/env zsh

# Main test runner for zsh-fzf-git-worktree

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get the directory of this script
TEST_DIR="${0:A:h}"
PLUGIN_PATH="${TEST_DIR}/../zsh-fzf-git-worktree.zsh"

# Check if plugin exists
if [[ ! -f "$PLUGIN_PATH" ]]; then
    echo "${RED}Error: Plugin not found at $PLUGIN_PATH${NC}"
    exit 1
fi

# Test suite tracking
SUITES_RUN=0
SUITES_PASSED=0
SUITES_FAILED=0

# Overall test tracking
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0

# Function to run a test suite
run_suite() {
    local suite_file="$1"
    local suite_name="${suite_file:t:r}"

    echo
    echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${CYAN}Running Test Suite: $suite_name${NC}"
    echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    ((SUITES_RUN++))

    # Run the test suite in a subshell to isolate it
    (
        cd "$TEST_DIR"
        zsh "$suite_file"
    )
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        ((SUITES_PASSED++))
        echo "${GREEN}✓ Suite passed: $suite_name${NC}"
    else
        ((SUITES_FAILED++))
        echo "${RED}✗ Suite failed: $suite_name${NC}"
    fi

    return $exit_code
}

# Parse command line arguments
VERBOSE=0
SPECIFIC_SUITE=""
BAIL_ON_FAIL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -b|--bail)
            BAIL_ON_FAIL=1
            shift
            ;;
        -s|--suite)
            SPECIFIC_SUITE="$2"
            shift 2
            ;;
        -h|--help)
            cat << EOF
Usage: $0 [OPTIONS]

Options:
  -v, --verbose      Show verbose output
  -b, --bail         Stop on first test failure
  -s, --suite NAME   Run only specific test suite
  -h, --help         Show this help message

Available test suites:
  unit      - Unit tests for helper functions
  init      - Tests for init subcommand
  new       - Tests for new subcommand
  list      - Tests for list subcommand
  remove    - Tests for remove subcommand
  branch    - Tests for branch subcommand

Examples:
  $0                    # Run all tests
  $0 -s unit            # Run only unit tests
  $0 -v -b              # Verbose output, stop on first failure
EOF
            exit 0
            ;;
        *)
            echo "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Header
echo "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo "${BLUE}║       zsh-fzf-git-worktree Test Runner             ║${NC}"
echo "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo
echo "Test directory: $TEST_DIR"
echo "Plugin path: $PLUGIN_PATH"
echo

# Determine which test files to run
if [[ -n "$SPECIFIC_SUITE" ]]; then
    TEST_FILES=("${TEST_DIR}/test_${SPECIFIC_SUITE}.zsh")
    if [[ ! -f "${TEST_FILES[1]}" ]]; then
        echo "${RED}Error: Test suite '$SPECIFIC_SUITE' not found${NC}"
        exit 1
    fi
else
    # Find all test files
    TEST_FILES=(${TEST_DIR}/test_*.zsh)
fi

# Run test suites
START_TIME=$(date +%s)

for test_file in "${TEST_FILES[@]}"; do
    if [[ -f "$test_file" ]]; then
        run_suite "$test_file"
        if [[ $? -ne 0 && $BAIL_ON_FAIL -eq 1 ]]; then
            echo "${RED}Bailing out due to test failure${NC}"
            break
        fi
    fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Final summary
echo
echo "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo "${BLUE}║                  Test Summary                      ║${NC}"
echo "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo
echo "Test Suites:  ${GREEN}$SUITES_PASSED passed${NC}, ${RED}$SUITES_FAILED failed${NC}, $SUITES_RUN total"
echo "Duration:     ${DURATION}s"
echo

if [[ $SUITES_FAILED -eq 0 ]]; then
    echo "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${GREEN}               ALL TESTS PASSED! 🎉                 ${NC}"
    echo "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
else
    echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${RED}               TESTS FAILED! 💔                     ${NC}"
    echo "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi
