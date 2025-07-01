#!/usr/bin/env zsh

# Integration tests for list subcommand

# Source the test framework
source "${0:A:h}/test_framework.zsh"

# Set the plugin path
PLUGIN_PATH="${0:A:h}/../zsh-fzf-git-worktree.zsh"

# Source the plugin
source_plugin

# Setup function for worktree tests
setup_worktree_repo() {
    # Create a proper worktree structure
    mkdir worktree_test
    cd worktree_test
    mkdir main
    cd main
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add test.txt
    git commit -m "Initial commit"
}

# Test list command
test_list_shows_main_worktree() {
    setup_worktree_repo

    local output=$(fzf-git-worktree list)
    local exit_code=$?

    assert_exit_code 0 $exit_code "list should succeed"
    assert_contains "$output" "main" "Output should contain main worktree"
}

test_list_shows_multiple_worktrees() {
    setup_worktree_repo

    # Create multiple worktrees
    git worktree add ../feature1
    git worktree add ../feature2

    local output=$(fzf-git-worktree list)

    # Check all worktrees are listed
    assert_contains "$output" "main" "Output should contain main worktree"
    assert_contains "$output" "feature1" "Output should contain feature1 worktree"
    assert_contains "$output" "feature2" "Output should contain feature2 worktree"
}

test_list_shows_branch_names() {
    setup_worktree_repo

    # Create branches and worktrees
    git checkout -b develop
    git worktree add ../feature1
    git checkout -b feature-branch
    git worktree add ../feature2

    local output=$(fzf-git-worktree list)

    # Check that branch names are shown
    assert_contains "$output" "develop" "Output should show develop branch"
    assert_contains "$output" "feature-branch" "Output should show feature-branch"
}

test_list_format_is_correct() {
    setup_worktree_repo

    # Create a worktree with known branch
    git checkout -b test-branch
    git worktree add ../test-worktree

    local output=$(fzf-git-worktree list)

    # Check format: should have worktree name and branch
    local line_count=$(echo "$output" | grep -c "test-worktree")
    assert_equals "1" "$line_count" "test-worktree should appear once"

    # The output format should be: worktree-name branch-name
    assert_contains "$output" "test-worktree" "Should contain worktree name"
    assert_contains "$output" "test-branch" "Should contain branch name"
}

test_list_handles_detached_head() {
    setup_worktree_repo

    # Create a worktree with detached HEAD
    local commit_hash=$(git rev-parse HEAD)
    git worktree add ../detached "$commit_hash"

    local output=$(fzf-git-worktree list)

    # Should show detached worktree
    assert_contains "$output" "detached" "Output should contain detached worktree"
    # Should show part of commit hash or (detached)
    local detached_line=$(echo "$output" | grep "detached")
    assert_not_equals "" "$detached_line" "Should have line for detached worktree"
}

test_list_after_prune() {
    setup_worktree_repo

    # Create worktrees
    git worktree add ../feature1
    git worktree add ../feature2

    # Manually remove a worktree directory (simulating corruption)
    rm -rf ../feature1

    # The prepare function in the plugin calls git worktree prune
    # So calling list should clean up the missing worktree
    local output=$(fzf-git-worktree list)

    # Should not show the removed worktree
    assert_not_contains "$output" "feature1" "Should not show pruned worktree"
    assert_contains "$output" "feature2" "Should still show existing worktree"
    assert_contains "$output" "main" "Should still show main worktree"
}

test_list_empty_worktree_list() {
    # Create a bare repo (no worktrees)
    mkdir bare_repo
    cd bare_repo
    git init --bare

    # This should fail since we can't run worktree commands in bare repo
    local output=$(fzf-git-worktree list 2>&1)
    local exit_code=$?

    # Should handle gracefully (might fail or show empty)
    # The exact behavior depends on git version
    if [[ $exit_code -eq 0 ]]; then
        # If it succeeds, output should be minimal
        assert_equals "" "$output" "Bare repo should have empty worktree list"
    else
        # If it fails, that's also acceptable
        assert_exit_code 128 $exit_code "Expected git error code for bare repo"
    fi
}

test_list_with_spaces_in_paths() {
    # Create repo with spaces in path
    mkdir "worktree test"
    cd "worktree test"
    mkdir main
    cd main
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > test.txt
    git add test.txt
    git commit -m "Initial commit"

    # Create worktree with spaces
    git worktree add "../feature with spaces"

    local output=$(fzf-git-worktree list)

    # Should handle spaces correctly
    assert_contains "$output" "main" "Should show main"
    assert_contains "$output" "feature with spaces" "Should show worktree with spaces"
}

# Run all tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_test_suite "List Command Tests"
    print_test_summary
fi
