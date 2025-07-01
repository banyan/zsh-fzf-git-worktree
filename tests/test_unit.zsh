#!/usr/bin/env zsh

# Unit tests for helper functions

# Source the test framework
source "${0:A:h}/test_framework.zsh"

# Set the plugin path
PLUGIN_PATH="${0:A:h}/../zsh-fzf-git-worktree.zsh"

# Source the plugin to get access to functions
source_plugin

# Unit tests for trim function
test_trim_removes_leading_spaces() {
    local result=$(trim "   hello")
    assert_equals "hello" "$result" "trim should remove leading spaces"
}

test_trim_removes_trailing_spaces() {
    local result=$(trim "hello   ")
    assert_equals "hello" "$result" "trim should remove trailing spaces"
}

test_trim_removes_both_ends() {
    local result=$(trim "   hello world   ")
    assert_equals "hello world" "$result" "trim should remove spaces from both ends"
}

test_trim_preserves_internal_spaces() {
    local result=$(trim "  hello   world  ")
    assert_equals "hello   world" "$result" "trim should preserve internal spaces"
}

test_trim_handles_empty_string() {
    local result=$(trim "")
    assert_equals "" "$result" "trim should handle empty string"
}

test_trim_handles_only_spaces() {
    local result=$(trim "     ")
    assert_equals "" "$result" "trim should return empty for only spaces"
}

test_trim_handles_tabs_and_newlines() {
    local result=$(trim "	hello
")
    assert_equals "hello" "$result" "trim should handle tabs and newlines"
}

# Unit tests for make_temp_dir function
test_make_temp_dir_creates_directory() {
    local temp_dir=$(make_temp_dir)
    assert_dir_exists "$temp_dir" "make_temp_dir should create a directory"

    # Cleanup
    [[ -d "$temp_dir" ]] && rm -rf "$temp_dir"
}

test_make_temp_dir_unique_names() {
    local temp_dir1=$(make_temp_dir)
    local temp_dir2=$(make_temp_dir)

    assert_not_equals "$temp_dir1" "$temp_dir2" "make_temp_dir should create unique directories"

    # Cleanup
    [[ -d "$temp_dir1" ]] && rm -rf "$temp_dir1"
    [[ -d "$temp_dir2" ]] && rm -rf "$temp_dir2"
}

test_make_temp_dir_contains_prefix() {
    local temp_dir=$(make_temp_dir)
    local basename=$(basename "$temp_dir")

    assert_contains "$basename" "fzf-git-worktree-" "Directory name should contain prefix"

    # Cleanup
    [[ -d "$temp_dir" ]] && rm -rf "$temp_dir"
}

# Unit tests for cwd_is_git_repo function
test_cwd_is_git_repo_true_in_git_repo() {
    # Create a git repo
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add test.txt
    git commit -m "Initial commit"

    cwd_is_git_repo
    assert_exit_code 0 $? "cwd_is_git_repo should return 0 in a git repo"
}

test_cwd_is_git_repo_false_outside_git_repo() {
    # Make sure we're not in a git repo
    mkdir not_a_repo
    cd not_a_repo

    cwd_is_git_repo
    assert_exit_code 1 $? "cwd_is_git_repo should return 1 outside a git repo"
}

test_cwd_is_git_repo_true_in_subdirectory() {
    # Create a git repo with subdirectory
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add test.txt
    git commit -m "Initial commit"
    mkdir subdir
    cd subdir

    cwd_is_git_repo
    assert_exit_code 0 $? "cwd_is_git_repo should return 0 in a subdirectory of git repo"
}

# Run all tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_test_suite "Unit Tests"
    print_test_summary
fi
