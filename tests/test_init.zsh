#!/usr/bin/env zsh

# Integration tests for init subcommand

# Source the test framework
source "${0:A:h}/test_framework.zsh"

# Set the plugin path
PLUGIN_PATH="${0:A:h}/../zsh-fzf-git-worktree.zsh"

# Source the plugin
source_plugin

# Test init command
test_init_fails_outside_git_repo() {
    # Make sure we're not in a git repo
    mkdir not_a_repo
    cd not_a_repo

    local output=$(fzf-git-worktree init 2>&1)
    local exit_code=$?

    assert_exit_code 1 $exit_code "init should fail outside git repo"
    assert_contains "$output" "not in a git repository" "Should show appropriate error message"
}

test_init_fails_in_main_directory() {
    # Create a git repo named 'main'
    mkdir main
    cd main
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add test.txt
    git commit -m "Initial commit"

    local output=$(fzf-git-worktree init 2>&1)
    local exit_code=$?

    assert_exit_code 1 $exit_code "init should fail in directory named 'main'"
    assert_contains "$output" "cannot init in a directory called 'main'" "Should show appropriate error message"
}

test_init_moves_files_to_main() {
    # Create a git repo with some files
    mkdir test_repo
    cd test_repo
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create some test files
    echo "file1" > file1.txt
    echo "file2" > file2.txt
    mkdir subdir
    echo "file3" > subdir/file3.txt

    git add .
    git commit -m "Initial commit"

    # Run init
    fzf-git-worktree init
    local exit_code=$?

    # Check that init succeeded
    assert_exit_code 0 $exit_code "init should succeed"

    # Check that we're now in main directory
    local current_dir=$(basename "$PWD")
    assert_equals "main" "$current_dir" "Should be in main directory after init"

    # Check that files were moved
    assert_file_exists "file1.txt" "file1.txt should exist in main"
    assert_file_exists "file2.txt" "file2.txt should exist in main"
    assert_file_exists "subdir/file3.txt" "subdir/file3.txt should exist in main"

    # Check that parent directory doesn't have the files anymore
    cd ..
    assert_file_not_exists "file1.txt" "file1.txt should not exist in parent"
    assert_file_not_exists "file2.txt" "file2.txt should not exist in parent"
    assert_dir_exists "main" "main directory should exist"
}

test_init_preserves_git_history() {
    # Create a git repo with history
    mkdir test_repo_history
    cd test_repo_history
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create multiple commits
    echo "commit1" > file1.txt
    git add file1.txt
    git commit -m "First commit"

    echo "commit2" > file2.txt
    git add file2.txt
    git commit -m "Second commit"

    # Store the commit hash
    local last_commit=$(git rev-parse HEAD)

    # Run init
    fzf-git-worktree init

    # Check that git history is preserved
    local new_last_commit=$(git rev-parse HEAD)
    assert_equals "$last_commit" "$new_last_commit" "Git history should be preserved"

    # Check that we can see the history
    local log_count=$(git log --oneline | wc -l | tr -d ' ')
    assert_equals "2" "$log_count" "Should have 2 commits in history"
}

test_init_handles_hidden_files() {
    # Create a git repo with hidden files
    mkdir test_repo_hidden
    cd test_repo_hidden
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create hidden files
    echo "hidden1" > .hidden1
    echo "hidden2" > .hidden2
    mkdir .hidden_dir
    echo "hidden3" > .hidden_dir/hidden3.txt

    git add -A
    git commit -m "Initial commit with hidden files"

    # Run init
    fzf-git-worktree init

    # Check that hidden files were moved (except .git)
    assert_file_exists ".hidden1" ".hidden1 should exist in main"
    assert_file_exists ".hidden2" ".hidden2 should exist in main"
    assert_dir_exists ".hidden_dir" ".hidden_dir should exist in main"
    assert_file_exists ".hidden_dir/hidden3.txt" "hidden3.txt should exist in .hidden_dir"
}

test_init_handles_empty_repo() {
    # Create an empty git repo (no commits)
    mkdir test_repo_empty
    cd test_repo_empty
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Run init
    fzf-git-worktree init
    local exit_code=$?

    # Should succeed even with empty repo
    assert_exit_code 0 $exit_code "init should succeed with empty repo"

    # Check that we're in main directory
    local current_dir=$(basename "$PWD")
    assert_equals "main" "$current_dir" "Should be in main directory"
}

# Run all tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_test_suite "Init Command Tests"
    print_test_summary
fi
