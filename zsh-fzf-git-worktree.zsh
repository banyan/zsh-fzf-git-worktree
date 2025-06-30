#!/usr/bin/env zsh

fzf-git-worktree() {
  local CWD=${PWD}
  local CWD_PARENT=${CWD:h}
  local CWD_NAME=${CWD:t}

  make_temp_dir() {
    mktemp -d -t "git-worktree-init-$(date +%Y%m%d-%H%M%S)"
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
  work b, branch [name]   switch current work tree to branch
                          if [name] is provided, switch to branch or create it
                          if [name] is not provided, select branch interactively
  work help               print usage
HEREDOC
  }

  prepare() {
    if ! cwd_is_git_repo && [[ -d "$CWD/main" ]]; then
      cd main || return 1
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

    if git worktree add "../$NAME" "$CURRENT_BRANCH" 2>/dev/null; then
      NEW_DIR=${CWD_PARENT}/${NAME}
    else
      local NEW_BRANCH="${NAME}/${CURRENT_BRANCH}"
      echo "Branch '$CURRENT_BRANCH' is already checked out, creating new branch: $NEW_BRANCH"
      git worktree add -b "$NEW_BRANCH" "../$NAME" "$CURRENT_BRANCH"
      NEW_DIR=${CWD_PARENT}/${NAME}
    fi

    if [[ -f "$CWD_PARENT/hook.sh" ]]; then
      bash "$CWD_PARENT/hook.sh" "$NEW_DIR"
    fi

    cd "$NEW_DIR"
  }

  handle_branch() {
    local BRANCH=$2
    if [[ -z "$BRANCH" ]]; then
      BRANCH=$(trim "$(git branch --all --sort=-committerdate | grep -v "^\*" | sed "s/remotes\/origin\///g" | awk '!x[$0]++' | grep -v HEAD | fzf)")
      if [[ -z "$BRANCH" ]]; then
        return 0
      fi
    fi

    if git branch --list "$BRANCH" | grep -q .; then
      git checkout --ignore-other-worktrees "$BRANCH"
    else
      git checkout --ignore-other-worktrees -b "$BRANCH"
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

    local CURRENT_DIR=$(pwd)
    if [[ "$NAME" == "$CURRENT_DIR" ]]; then
      cd ..
    fi

    git worktree remove "$NAME"
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
    b|branch)
      handle_branch "$@"
      ;;
    rm|remove)
      handle_remove "$@"
      ;;
    help|--help|-h|*)
      usage
      ;;
  esac
}
