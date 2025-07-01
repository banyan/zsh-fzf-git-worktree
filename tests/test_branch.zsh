#!/usr/bin/env zsh

# Integration tests for branch subcommand

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

# Test branch command
test_branch_switches_to_existing_branch() {
    setup_worktree_repo

    # Create a new branch
    git checkout -b develop
    echo "develop" > develop.txt
    git add develop.txt
    git commit -m "Develop commit"

    # Switch back to master/main
    git checkout master 2>/dev/null || git checkout main

    # Use branch command to switch
    fzf-git-worktree branch develop
    local exit_code=$?

    assert_exit_code 0 $exit_code "branch switch should succeed"

    # Check current branch
    local current_branch=$(git branch --show-current)
    assert_equals "develop" "$current_branch" "Should be on develop branch"

    # Check that develop file exists
    assert_file_exists "develop.txt" "File from develop branch should exist"
}

test_branch_creates_new_branch_if_not_exists() {
    setup_worktree_repo

    # Switch to non-existent branch
    fzf-git-worktree branch new-feature
    local exit_code=$?

    assert_exit_code 0 $exit_code "branch creation should succeed"

    # Check current branch
    local current_branch=$(git branch --show-current)
    assert_equals "new-feature" "$current_branch" "Should be on new-feature branch"

    # Check that branch was created
    local branch_exists=$(git branch --list new-feature | wc -l | tr -d ' ')
    assert_equals "1" "$branch_exists" "Branch should exist"
}

test_branch_with_ignore_other_worktrees() {
    setup_worktree_repo

    # Create another worktree on a branch
    git checkout -b feature1
    git worktree add ../worktree1

    # Go back to main
    cd ../main

    # Try to switch to the same branch that's checked out elsewhere
    fzf-git-worktree branch feature1
    local exit_code=$?

    # Should succeed with --ignore-other-worktrees flag
    assert_exit_code 0 $exit_code "Should be able to switch with ignore flag"

    local current_branch=$(git branch --show-current)
    assert_equals "feature1" "$current_branch" "Should be on feature1 branch"
}

test_branch_preserves_uncommitted_changes() {
    setup_worktree_repo

    # Create a new branch for testing
    git checkout -b test-branch
    git checkout master 2>/dev/null || git checkout main

    # Make uncommitted changes
    echo "uncommitted" > uncommitted.txt

    # Try to switch branch
    local output=$(fzf-git-worktree branch test-branch 2>&1)

    # Check if switch happened (depends on git config)
    local current_branch=$(git branch --show-current)

    # If on test-branch, uncommitted changes should be preserved
    if [[ "$current_branch" == "test-branch" ]]; then
        assert_file_exists "uncommitted.txt" "Uncommitted changes should be preserved"
    fi
}

test_branch_switches_from_detached_head() {
    setup_worktree_repo

    # Create a branch and commit
    git checkout -b feature
    echo "feature" > feature.txt
    git add feature.txt
    git commit -m "Feature commit"

    # Go to detached HEAD state
    local commit_hash=$(git rev-parse HEAD~1)
    git checkout "$commit_hash"

    # Verify we're in detached HEAD
    local detached=$(git symbolic-ref -q HEAD 2>/dev/null || echo "detached")
    assert_equals "detached" "$detached" "Should be in detached HEAD state"

    # Switch to branch
    fzf-git-worktree branch feature

    # Should be on branch now
    local current_branch=$(git branch --show-current)
    assert_equals "feature" "$current_branch" "Should be on feature branch"
}

test_branch_handles_branch_with_slash() {
    setup_worktree_repo

    # Create branch with slash
    fzf-git-worktree branch feature/new-ui
    local exit_code=$?

    assert_exit_code 0 $exit_code "Should create branch with slash"

    local current_branch=$(git branch --show-current)
    assert_equals "feature/new-ui" "$current_branch" "Should be on branch with slash"
}

test_branch_handles_remote_tracking_branch() {
    setup_worktree_repo

    # Simulate remote branch
    git checkout -b origin/remote-feature
    git checkout master 2>/dev/null || git checkout main

    # Try to checkout remote branch style
    fzf-git-worktree branch remote-feature

    local current_branch=$(git branch --show-current)
    assert_equals "remote-feature" "$current_branch" "Should create local branch"
}

test_branch_from_different_worktree() {
    setup_worktree_repo

    # Create branches
    git checkout -b branch1
    git checkout -b branch2

    # Create another worktree
    git worktree add ../worktree1 branch1

    # Switch to the other worktree
    cd ../worktree1

    # Switch branch in worktree
    fzf-git-worktree branch branch2

    local current_branch=$(git branch --show-current)
    assert_equals "branch2" "$current_branch" "Should switch branch in worktree"

    # Check that main is unaffected
    cd ../main
    local main_branch=$(git branch --show-current)
    assert_not_equals "branch2" "$main_branch" "Main should not be affected"
}

test_branch_handles_special_characters() {
    setup_worktree_repo

    # Test branch with dashes and underscores
    fzf-git-worktree branch feature-with_special-chars

    local current_branch=$(git branch --show-current)
    assert_equals "feature-with_special-chars" "$current_branch" "Should handle special characters"
}

# Run all tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_test_suite "Branch Command Tests"
    print_test_summary
fi
