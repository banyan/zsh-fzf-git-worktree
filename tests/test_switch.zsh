#!/usr/bin/env zsh

# Integration tests for switch subcommand

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

# Test switch command with -c option to create new branch and worktree
test_switch_creates_new_branch_and_worktree() {
    setup_worktree_repo

    # Create new branch and worktree
    fzf-git-worktree switch -c feature-branch
    local exit_code=$?

    assert_exit_code 0 $exit_code "switch -c should succeed"

    # Check current directory is the new worktree
    local current_dir=$(basename "$PWD")
    assert_equals "feature-branch" "$current_dir" "Should be in feature-branch directory"

    # Check current branch
    local current_branch=$(git branch --show-current)
    assert_equals "feature-branch" "$current_branch" "Should be on feature-branch"

    # Check that worktree was created
    cd ../main
    local worktree_count=$(git worktree list | grep -c "feature-branch")
    assert_equals "1" "$worktree_count" "Worktree should exist"
}

test_switch_fails_when_branch_already_exists() {
    setup_worktree_repo

    # Create an existing branch
    git checkout -b existing-branch
    git checkout master 2>/dev/null || git checkout main

    # Try to create with same name
    fzf-git-worktree switch -c existing-branch 2>/dev/null
    local exit_code=$?

    assert_exit_code 1 $exit_code "switch -c should fail for existing branch"
}

test_switch_requires_name_with_c_option() {
    setup_worktree_repo

    # Try to use -c without a name
    fzf-git-worktree switch -c 2>&1 | grep -q "FATAL"
    local exit_code=$?

    assert_exit_code 0 $exit_code "Should show error message for missing name"
}

test_switch_creates_worktree_in_parent_directory() {
    setup_worktree_repo

    # Remember parent directory
    local parent_dir="$(dirname "$PWD")"

    # Create new worktree
    fzf-git-worktree switch -c my-feature

    # Check we're in the right location
    local current_path="$PWD"
    assert_equals "${parent_dir}/my-feature" "$current_path" "Worktree should be in parent directory"
}

test_switch_inherits_from_current_branch() {
    setup_worktree_repo

    # Create and switch to a develop branch
    git checkout -b develop
    echo "develop content" > develop.txt
    git add develop.txt
    git commit -m "Develop commit"

    # Create new worktree from develop
    fzf-git-worktree switch -c feature-from-develop

    # Should have develop content
    assert_file_exists "develop.txt" "Should inherit files from develop branch"
    
    # Verify parent branch
    local merge_base=$(git merge-base HEAD develop)
    local develop_head=$(git rev-parse develop)
    assert_equals "$develop_head" "$merge_base" "Should be based on develop branch"
}

test_switch_handles_branch_with_slash() {
    setup_worktree_repo

    # Create worktree with slash in name
    fzf-git-worktree switch -c feature/new-ui
    local exit_code=$?

    assert_exit_code 0 $exit_code "Should create worktree with slash"

    local current_branch=$(git branch --show-current)
    assert_equals "feature/new-ui" "$current_branch" "Should be on branch with slash"

    # Check directory name
    local current_dir=$(basename "$PWD")
    assert_equals "new-ui" "$current_dir" "Directory should be last part of branch name"
}

test_switch_runs_hook_if_present() {
    setup_worktree_repo

    # Create a hook script
    cat > ../hook.sh << 'EOF'
#!/bin/bash
echo "Hook executed for: $1" > "$1/hook_ran.txt"
EOF
    chmod +x ../hook.sh

    # Create new worktree
    fzf-git-worktree switch -c with-hook

    # Check hook was executed
    assert_file_exists "hook_ran.txt" "Hook should have created file"
    local hook_content=$(cat hook_ran.txt)
    assert_contains "$hook_content" "Hook executed" "Hook should have run"
}

test_switch_from_different_worktree() {
    setup_worktree_repo

    # Create another worktree
    git worktree add ../worktree1
    cd ../worktree1

    # Create new worktree from within a worktree
    fzf-git-worktree switch -c from-worktree

    # Should be in new worktree
    local current_dir=$(basename "$PWD")
    assert_equals "from-worktree" "$current_dir" "Should be in new worktree"

    # Verify it's properly registered
    cd ../../main
    local worktree_exists=$(git worktree list | grep -c "from-worktree")
    assert_equals "1" "$worktree_exists" "New worktree should be registered"
}

test_switch_handles_special_characters() {
    setup_worktree_repo

    # Test worktree with dashes and underscores
    fzf-git-worktree switch -c feature-with_special-chars

    local current_branch=$(git branch --show-current)
    assert_equals "feature-with_special-chars" "$current_branch" "Should handle special characters"

    local current_dir=$(basename "$PWD")
    assert_equals "feature-with_special-chars" "$current_dir" "Directory should match branch name"
}

# Run all tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_test_suite "Switch Command Tests"
    print_test_summary
fi
