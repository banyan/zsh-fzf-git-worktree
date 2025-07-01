#!/usr/bin/env zsh

# Integration tests for new subcommand

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

# Test new command
test_new_requires_name_argument() {
    setup_worktree_repo

    local output=$(fzf-git-worktree new 2>&1)
    local exit_code=$?

    assert_exit_code 1 $exit_code "new should fail without name argument"
    assert_contains "$output" "you need to provide a tree name" "Should show appropriate error message"
}

test_new_creates_worktree_with_current_branch() {
    setup_worktree_repo

    # Create a new worktree
    fzf-git-worktree new feature1
    local exit_code=$?

    assert_exit_code 0 $exit_code "new should succeed with valid name"

    # Check that we're in the new worktree
    local current_dir=$(basename "$PWD")
    assert_equals "feature1" "$current_dir" "Should be in new worktree directory"

    # Check that the worktree exists
    cd ../main
    local worktree_list=$(git worktree list)
    assert_contains "$worktree_list" "feature1" "Worktree list should contain new worktree"

    # Check that we're on the same branch
    local main_branch=$(git branch --show-current)
    cd ../feature1
    local feature_branch=$(git branch --show-current)
    assert_equals "$main_branch" "$feature_branch" "Should be on same branch as main"
}

test_new_creates_new_branch_when_current_branch_already_checked_out() {
    setup_worktree_repo

    # Get current branch name
    local current_branch=$(git branch --show-current)

    # Create first worktree
    fzf-git-worktree new feature1

    # Go back to main and try to create another worktree
    cd ../main

    # Capture output to check for branch creation message
    local output=$(fzf-git-worktree new feature2 2>&1)
    local exit_code=$?

    assert_exit_code 0 $exit_code "new should succeed even when branch is checked out"
    assert_contains "$output" "Branch '$current_branch' is already checked out" "Should show branch already checked out message"
    assert_contains "$output" "creating new branch: feature2/$current_branch" "Should show new branch creation"

    # Verify we're in the new worktree
    local current_dir=$(basename "$PWD")
    assert_equals "feature2" "$current_dir" "Should be in new worktree directory"

    # Check that new branch was created
    local new_branch=$(git branch --show-current)
    assert_equals "feature2/$current_branch" "$new_branch" "Should be on new branch"
}

test_new_handles_paths_correctly() {
    setup_worktree_repo

    # Store parent path
    local parent_path=$(dirname "$PWD")

    # Create a worktree
    fzf-git-worktree new feature1

    # Check that worktree is created in parent directory
    assert_dir_exists "$parent_path/feature1" "Worktree should be created in parent directory"

    # Check current directory
    local current_path="$PWD"
    assert_equals "$parent_path/feature1" "$current_path" "Should cd to new worktree"
}

test_new_with_different_branch() {
    setup_worktree_repo

    # Create a new branch first
    git checkout -b develop
    echo "develop" > develop.txt
    git add develop.txt
    git commit -m "Develop branch"

    # Create worktree while on develop branch
    fzf-git-worktree new feature1

    # Check that we're on develop branch in new worktree
    local branch=$(git branch --show-current)
    assert_equals "develop" "$branch" "Should be on develop branch in new worktree"

    # Check that develop.txt exists
    assert_file_exists "develop.txt" "File from develop branch should exist"
}

test_new_runs_hook_script_if_exists() {
    setup_worktree_repo

    # Create a hook script in parent directory
    cd ..
    cat > hook.sh << 'EOF'
#!/bin/bash
echo "Hook executed for: $1" > "$1/hook_executed.txt"
EOF
    chmod +x hook.sh

    # Go back to main and create new worktree
    cd main
    fzf-git-worktree new feature1

    # Check that hook was executed
    assert_file_exists "hook_executed.txt" "Hook should have created file"

    # Check hook file content
    local hook_content=$(cat hook_executed.txt)
    assert_contains "$hook_content" "Hook executed for:" "Hook should have written expected content"
}

test_new_handles_special_characters_in_name() {
    setup_worktree_repo

    # Test with dashes
    fzf-git-worktree new feature-with-dashes
    assert_equals "feature-with-dashes" "$(basename "$PWD")" "Should handle dashes in name"

    cd ../main

    # Test with underscores
    fzf-git-worktree new feature_with_underscores
    assert_equals "feature_with_underscores" "$(basename "$PWD")" "Should handle underscores in name"
}

test_new_preserves_uncommitted_changes_in_main() {
    setup_worktree_repo

    # Make some uncommitted changes in main
    echo "uncommitted" > uncommitted.txt

    # Create new worktree
    fzf-git-worktree new feature1

    # Check that we're in new worktree
    assert_equals "feature1" "$(basename "$PWD")" "Should be in new worktree"
    assert_file_not_exists "uncommitted.txt" "Uncommitted file should not exist in new worktree"

    # Go back to main and check uncommitted changes still exist
    cd ../main
    assert_file_exists "uncommitted.txt" "Uncommitted file should still exist in main"
}

# Run all tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_test_suite "New Command Tests"
    print_test_summary
fi
