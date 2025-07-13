#!/usr/bin/env zsh

# Integration tests for remove subcommand

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

# Test remove command
test_remove_with_name_argument() {
    setup_worktree_repo

    # Create a worktree to remove
    git worktree add ../feature1

    # Verify it exists
    assert_dir_exists "../feature1" "Worktree should exist before removal"

    # Remove the worktree
    fzf-git-worktree remove feature1
    local exit_code=$?

    assert_exit_code 0 $exit_code "remove should succeed"
    assert_dir_not_exists "../feature1" "Worktree directory should be removed"

    # Verify it's not in the list
    local worktree_list=$(git worktree list)
    assert_not_contains "$worktree_list" "feature1" "Worktree should not be in list after removal"
}

test_remove_with_path_argument() {
    setup_worktree_repo

    # Create a worktree
    git worktree add ../feature1

    # Remove using path instead of name
    fzf-git-worktree remove ../feature1
    local exit_code=$?

    assert_exit_code 0 $exit_code "remove should succeed with path"
    assert_dir_not_exists "../feature1" "Worktree directory should be removed"
}

test_remove_switches_directory_when_removing_current() {
    setup_worktree_repo

    # Create a worktree and cd to it
    git worktree add ../feature1
    cd ../feature1

    # Store the path
    local feature_path="$PWD"

    # Remove current worktree
    fzf-git-worktree remove feature1

    # Should have changed directory
    local new_path="$PWD"
    assert_not_equals "$feature_path" "$new_path" "Should change directory when removing current"

    # Should be in main worktree
    local main_path=$(git worktree list | head -1 | awk '{print $1}')
    assert_equals "$main_path" "$new_path" "Should be in main worktree"

    # Worktree should be removed
    assert_dir_not_exists "$feature_path" "Worktree directory should be removed"
}

test_remove_nonexistent_worktree() {
    setup_worktree_repo

    # Try to remove non-existent worktree
    local output=$(fzf-git-worktree remove nonexistent 2>&1)
    local exit_code=$?

    # Git will return an error
    assert_exit_code 128 $exit_code "remove should fail for non-existent worktree"
    assert_contains "$output" "fatal:" "Should show git error message"
}

test_remove_main_worktree_fails() {
    setup_worktree_repo

    # Try to remove main worktree
    local output=$(fzf-git-worktree remove main 2>&1)
    local exit_code=$?

    # Should fail - can't remove main worktree
    assert_exit_code 128 $exit_code "Should not be able to remove main worktree"
}

test_remove_with_uncommitted_changes() {
    setup_worktree_repo

    # Create a worktree
    git worktree add ../feature1
    cd ../feature1

    # Make uncommitted changes
    echo "uncommitted" > uncommitted.txt

    cd ../main

    # Try to remove - by default git worktree remove will fail
    local output=$(fzf-git-worktree remove feature1 2>&1)
    local exit_code=$?

    # Should fail due to uncommitted changes
    assert_exit_code 128 $exit_code "Should fail with uncommitted changes"
    assert_dir_exists "../feature1" "Worktree should still exist"
}

test_remove_with_untracked_files() {
    setup_worktree_repo

    # Create a worktree
    git worktree add ../feature1
    cd ../feature1

    # Create untracked file
    echo "untracked" > untracked.txt

    cd ../main

    # Remove should succeed with just untracked files (git behavior)
    fzf-git-worktree remove feature1
    local exit_code=$?

    # Git worktree remove will remove directory with untracked files
    assert_exit_code 0 $exit_code "Should succeed with untracked files"
    assert_dir_not_exists "../feature1" "Worktree should be removed"
}

test_remove_locked_worktree() {
    setup_worktree_repo

    # Create a worktree
    git worktree add ../feature1

    # Lock the worktree
    git worktree lock ../feature1

    # Try to remove locked worktree
    local output=$(fzf-git-worktree remove feature1 2>&1)
    local exit_code=$?

    # Should fail
    assert_exit_code 128 $exit_code "Should fail to remove locked worktree"
    assert_contains "$output" "locked" "Should mention worktree is locked"
    assert_dir_exists "../feature1" "Locked worktree should still exist"

    # Unlock for cleanup
    git worktree unlock ../feature1
}

test_remove_multiple_worktrees_sequentially() {
    setup_worktree_repo

    # Create multiple worktrees
    git worktree add ../feature1
    git worktree add ../feature2
    git worktree add ../feature3

    # Remove them one by one
    fzf-git-worktree remove feature1
    assert_dir_not_exists "../feature1" "feature1 should be removed"

    fzf-git-worktree remove feature2
    assert_dir_not_exists "../feature2" "feature2 should be removed"

    fzf-git-worktree remove feature3
    assert_dir_not_exists "../feature3" "feature3 should be removed"

    # Only main should remain
    local worktree_count=$(git worktree list | wc -l | tr -d ' ')
    assert_equals "1" "$worktree_count" "Only main worktree should remain"
}

test_remove_deletes_branch() {
    setup_worktree_repo

    # Create a worktree with a new branch
    git worktree add -b feature-branch ../feature1

    # Verify branch exists
    git branch --list "feature-branch" | grep -q "feature-branch"
    assert_exit_code 0 $? "Branch feature-branch should exist"

    # Remove the worktree
    fzf-git-worktree remove feature1

    # Verify branch is deleted
    git branch --list "feature-branch" | grep -q "feature-branch"
    assert_exit_code 1 $? "Branch feature-branch should be deleted"
}

test_remove_deletes_branch_with_custom_name() {
    setup_worktree_repo

    # Create a worktree with existing branch
    git branch custom-branch
    git worktree add ../myworktree custom-branch

    # Verify branch exists
    git branch --list "custom-branch" | grep -q "custom-branch"
    assert_exit_code 0 $? "Branch custom-branch should exist"

    # Remove the worktree
    fzf-git-worktree remove myworktree

    # Verify branch is deleted
    git branch --list "custom-branch" | grep -q "custom-branch"
    assert_exit_code 1 $? "Branch custom-branch should be deleted"
}

test_remove_preserves_main_branch() {
    setup_worktree_repo

    # Create a worktree on main branch (will create new branch)
    git worktree add ../feature1 main

    # Get the actual branch name created
    local branch_name=$(git -C ../feature1 branch --show-current)

    # Remove the worktree
    fzf-git-worktree remove feature1

    # Verify main branch still exists
    git branch --list "main" | grep -q "main"
    assert_exit_code 0 $? "Main branch should still exist"

    # Verify the created branch is deleted
    git branch --list "$branch_name" | grep -q "$branch_name"
    assert_exit_code 1 $? "Created branch $branch_name should be deleted"
}

test_remove_always_uses_main_worktree() {
    setup_worktree_repo

    # Store main worktree path
    local main_path="$PWD"

    # Create multiple worktrees
    git worktree add ../feature1
    git worktree add ../feature2

    # Switch to feature2
    cd ../feature2

    # Remove feature1 (not current)
    fzf-git-worktree remove feature1

    # Should be in main worktree, not feature2
    local new_path="$PWD"
    assert_equals "$main_path" "$new_path" "Should be in main worktree after remove"

    # feature1 should be removed
    assert_dir_not_exists "../feature1" "feature1 should be removed"

    # feature2 should still exist
    assert_dir_exists "$(dirname $main_path)/feature2" "feature2 should still exist"
}

# Run all tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_test_suite "Remove Command Tests"
    print_test_summary
fi
