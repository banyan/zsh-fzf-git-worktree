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

test_new_creates_worktree_with_new_branch_if_not_exists() {
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

    # Check that we're on a new branch named feature1
    cd ../feature1
    local feature_branch=$(git branch --show-current)
    assert_equals "feature1" "$feature_branch" "Should be on new branch named feature1"
}

test_new_creates_worktree_with_existing_branch() {
    setup_worktree_repo

    # Create a branch first
    git checkout -b feature-existing
    echo "feature" > feature.txt
    git add feature.txt
    git commit -m "Feature commit"
    git checkout main

    # Create worktree with existing branch name
    fzf-git-worktree new feature-existing
    local exit_code=$?

    assert_exit_code 0 $exit_code "new should succeed with existing branch"

    # Verify we're in the new worktree
    local current_dir=$(basename "$PWD")
    assert_equals "feature-existing" "$current_dir" "Should be in new worktree directory"

    # Check that we're on the existing branch
    local new_branch=$(git branch --show-current)
    assert_equals "feature-existing" "$new_branch" "Should be on existing branch"

    # Check that feature.txt exists (from the existing branch)
    assert_file_exists "feature.txt" "File from existing branch should exist"
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

test_new_creates_branch_based_on_current_branch() {
    setup_worktree_repo

    # Create a new branch first
    git checkout -b develop
    echo "develop" > develop.txt
    git add develop.txt
    git commit -m "Develop branch"

    # Create worktree while on develop branch
    fzf-git-worktree new feature1

    # Check that we're on new branch named feature1
    local branch=$(git branch --show-current)
    assert_equals "feature1" "$branch" "Should be on new branch named feature1"

    # Check that develop.txt exists (branch created from develop)
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

test_new_fails_when_branch_already_checked_out() {
    setup_worktree_repo

    # Create a branch and check it out in a worktree
    git checkout -b feature-branch
    git checkout main
    fzf-git-worktree new feature-branch

    # Go back to main and try to create another worktree with same branch
    cd ../main
    local output=$(fzf-git-worktree new feature-branch 2>&1)
    local exit_code=$?

    assert_exit_code 1 $exit_code "new should fail when branch is already checked out"
    assert_contains "$output" "Branch 'feature-branch' is already checked out" "Should show appropriate error message"
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
