#!/usr/bin/env zsh

fzf-git-worktree() {
  local CWD=${PWD}
  local CWD_PARENT=${CWD:h}
  local CWD_NAME=${CWD:t}

  make_temp_dir() {
    mktemp -d -t "fzf-git-worktree-$(date +%Y%m%d-%H%M%S)"
  }

  trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
  }

  cwd_is_git_repo() {
    [[ -d "$CWD/.git" ]] && git rev-parse --is-inside-work-tree >/dev/null 2>&1
  }

  usage() {
    cat <<HEREDOC
Usage:
  work                    interactive switcher
  work i, init            setup "work" in cwd
  work new <n>            create new work tree and switch to it
  work rm, remove <n>     remove work tree
  work ls, list           list work trees
  work s, switch          switch to existing work tree interactively
  work s -c <name>        create new branch and work tree with <name>
  work help               print usage
HEREDOC
  }

  prepare() {
    if ! cwd_is_git_repo && [[ -d "$CWD/main" ]]; then
      cd main || return 1
      CWD=${PWD}
      CWD_PARENT=${CWD:h}
      CWD_NAME=${CWD:t}
    fi
    git worktree prune
  }

  handle_init() {
    if cwd_is_git_repo; then
      if [[ "$CWD_NAME" == "main" ]]; then
        echo "FATAL: cannot init in a directory called 'main'"
        return 1
      fi
      local TMP=$(make_temp_dir)
      mv ./* "$TMP"
      mkdir main
      mv "$TMP"/* main
      cd main || return 1
    else
      echo "FATAL: not in a git repository's root directory"
      return 1
    fi
  }

  handle_list() {
    git worktree list | sed -E 's/^(.*\/([^[:space:]]* ))/\1 \2/g' | awk '{printf "%-10s %s\n", $2, $4}'
  }

  handle_switch() {
    local SELECTION=$(git worktree list | \
        sed -E 's/^(.*\/([^[:space:]]* ))/\1 \2/g' | \
        fzf --with-nth=2,4 \
            --preview-window=right:50% \
            --ansi \
            --preview="echo '📦 Branch:' && \
                       git -C {1} branch --show-current && \
                       echo && \
                       echo '📝 Changed files:' && \
                       git -C {1} status --porcelain | head -10 && \
                       echo && \
                       echo '📚 Recent commits:' && \
                       git -C {1} log --oneline --decorate -10" )
    if [[ -z "$SELECTION" ]]; then
      return 0
    fi
    local DIR=${SELECTION%% *}
    cd "$DIR"
  }

  handle_new() {
    local NAME=$2
    if [[ -z "$NAME" ]]; then
      echo "FATAL: you need to provide a tree name"
      usage
      return 1
    fi
    local CURRENT_BRANCH=$(git branch --show-current)
    local NEW_DIR

    # Check if a branch with the given name exists
    if git branch --list "$NAME" | grep -q .; then
      # Branch exists, try to check it out
      if git worktree add "../$NAME" "$NAME" 2>/dev/null; then
        NEW_DIR=${CWD_PARENT}/${NAME}
      else
        # Branch is already checked out somewhere else
        echo "Branch '$NAME' is already checked out"
        return 1
      fi
    else
      # Branch doesn't exist, create it
      echo "Creating new branch: $NAME"
      git worktree add -b "$NAME" "../$NAME" "$CURRENT_BRANCH"
      NEW_DIR=${CWD_PARENT}/${NAME}
    fi

    if [[ -f "$CWD_PARENT/hook.sh" ]]; then
      bash "$CWD_PARENT/hook.sh" "$NEW_DIR"
    fi

    cd "$NEW_DIR"
  }

  handle_switch_command() {
    shift  # Remove 'switch' from arguments
    
    # Check for -c option
    if [[ "$1" == "-c" ]]; then
      local NAME=$2
      if [[ -z "$NAME" ]]; then
        echo "FATAL: you need to provide a branch/worktree name"
        usage
        return 1
      fi
      
      # Check if branch already exists
      if git branch --list "$NAME" | grep -q .; then
        echo "Branch '$NAME' already exists"
        return 1
      fi
      
      # Create new branch and worktree
      local CURRENT_BRANCH=$(git branch --show-current)
      git worktree add -b "$NAME" "../$NAME" "$CURRENT_BRANCH"
      if [[ $? -eq 0 ]]; then
        local NEW_DIR=${CWD_PARENT}/${NAME}
        
        if [[ -f "$CWD_PARENT/hook.sh" ]]; then
          bash "$CWD_PARENT/hook.sh" "$NEW_DIR"
        fi
        
        cd "$NEW_DIR"
      fi
    else
      # No -c option, switch to existing worktree
      handle_switch
    fi
  }

  handle_remove() {
    local NAME=$2
    if [[ -z "$NAME" ]]; then
      local SELECTION=$(git worktree list | \
          sed -E 's/^(.*\/([^[:space:]]* ))/\1 \2/g' | \
          fzf --with-nth=2,4 \
              --header="Select worktree to remove:" \
              --ansi \
              --preview-window=right:50% \
              --preview="echo '📦 Branch:' && \
                         git -C {1} branch --show-current && \
                         echo && \
                         echo '📝 Changed files:' && \
                         git -C {1} status --porcelain | head -10 && \
                         echo && \
                         echo '📚 Recent commits:' && \
                         git -C {1} log --oneline --decorate -10" )
      if [[ -z "$SELECTION" ]]; then
        return 0
      fi
      NAME=${SELECTION%% *}
    fi

    # Get the branch name before removing the worktree
    local WORKTREE_PATH
    if [[ "$NAME" =~ ^/ ]]; then
      # NAME is already a full path
      WORKTREE_PATH="$NAME"
    else
      # NAME is relative, find the full path
      WORKTREE_PATH=$(git worktree list | grep -E "/$NAME " | awk '{print $1}')
    fi

    local BRANCH_NAME=$(git -C "$WORKTREE_PATH" branch --show-current 2>/dev/null)

    # Always cd to the main worktree before removing
    local MAIN_WORKTREE=$(git worktree list | head -1 | awk '{print $1}')
    cd "$MAIN_WORKTREE"

    git worktree remove "$NAME"

    # If worktree removal succeeded and we have a branch name, delete the branch
    if [[ $? -eq 0 ]] && [[ -n "$BRANCH_NAME" ]]; then
      git branch -D "$BRANCH_NAME"
    fi
  }

  prepare

  local COMMAND=$1
  case "$COMMAND" in
    "")
      handle_switch
      ;;
    i|init)
      handle_init
      ;;
    ls|list)
      handle_list
      ;;
    new)
      handle_new "$@"
      ;;
    s|switch)
      handle_switch_command "$@"
      ;;
    rm|remove)
      handle_remove "$@"
      ;;
    help|--help|-h|*)
      usage
      ;;
  esac
}
