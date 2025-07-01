# zsh-fzf-git-worktree Tests

This directory contains comprehensive tests for the zsh-fzf-git-worktree plugin.

## Test Structure

- `test_framework.zsh` - Core testing framework with assertion functions
- `test_unit.zsh` - Unit tests for helper functions
- `test_init.zsh` - Integration tests for init subcommand
- `test_new.zsh` - Integration tests for new subcommand
- `test_list.zsh` - Integration tests for list subcommand
- `test_remove.zsh` - Integration tests for remove subcommand
- `test_branch.zsh` - Integration tests for branch subcommand
- `run_tests.zsh` - Main test runner script
- `example_simple_test.zsh` - Simple example showing basic test approach

## Running Tests

### Run all tests
```bash
./run_tests.zsh
```

### Run specific test suite
```bash
./run_tests.zsh -s unit
./run_tests.zsh -s init
```

### Run with verbose output
```bash
./run_tests.zsh -v
```

### Stop on first failure
```bash
./run_tests.zsh -b
```

### Run individual test file
```bash
./test_unit.zsh
```

### Run simple example
```bash
./example_simple_test.zsh
```

## Test Framework Features

The test framework provides:
- Colored output for better readability
- Assertion functions (assert_equals, assert_contains, etc.)
- Automatic test environment setup/teardown
- Test counters and summary reports
- Isolated test execution in temporary directories

## Writing New Tests

1. Create a new test file following the naming pattern `test_*.zsh`
2. Source the test framework
3. Write test functions starting with `test_`
4. Use assertion functions to verify behavior
5. Run tests using the test runner

Example:
```zsh
#!/usr/bin/env zsh

source "${0:A:h}/test_framework.zsh"
PLUGIN_PATH="${0:A:h}/../zsh-fzf-git-worktree.zsh"
source_plugin

test_my_feature() {
    # Test implementation
    assert_equals "expected" "actual" "Test description"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_test_suite "My Feature Tests"
    print_test_summary
fi
```