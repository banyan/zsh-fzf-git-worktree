# zsh-fzf-git-worktree

>A Zsh plugin for managing Git worktrees with fzf integration.

![Demo](assets/demo.gif)

## Features

- Interactive worktree management with fzf integration
- Create, switch, remove worktrees and manage branches

## Prerequisites

- Zsh
- Git
- fzf

## Installation

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/banyan/zsh-fzf-git-worktree.git ~/path/to/zsh-fzf-git-worktree

# Add to your ~/.zshrc
source ~/path/to/zsh-fzf-git-worktree/zsh-fzf-git-worktree.zsh
```

### Zinit

```bash
# Add to your ~/.zshrc
zinit light banyan/zsh-fzf-git-worktree
```

## Usage

After installation, the `fzf-git-worktree` command will be available:

```bash
fzf-git-worktree                    # Interactive worktree switcher
fzf-git-worktree i, init            # Setup "fzf-git-worktree" in current directory
fzf-git-worktree new <name>         # Create new worktree with branch <name> if it doesn't exist
fzf-git-worktree rm, remove <name>  # Remove worktree
fzf-git-worktree ls, list           # List worktrees
fzf-git-worktree help               # Print usage
```

### Getting Started

1. In your Git repository, run `fzf-git-worktree init` to set up the worktree structure
2. Use `fzf-git-worktree new feature-x` to create a new worktree for your feature
3. Switch between worktrees with `fzf-git-worktree` (interactive)

## Testing

This project includes a comprehensive test suite. To run the tests:

```bash
# Run all tests
./tests/run_tests.zsh
```

## Acknowledgments

This project was based on [3rd/work](https://github.com/3rd/work) and inspired by [this blog post](https://sushichan044.hateblo.jp/entry/2025/06/06/003325).

## License

MIT License - see [LICENSE](LICENSE) file for details.
