# git_pr

A command-line utility for creating, viewing, diffing, and merging GitHub pull requests.

## tl;dr

[![asciicast](https://asciinema.org/a/2owcxgz5r5275woapwrrdg5nz.png)](https://asciinema.org/a/2owcxgz5r5275woapwrrdg5nz?autoplay=1&speed=3)

## Installation

`sudo gem install git_pr`

## Usage

```
{{{basic_usage}}}
```

### Opening a pull request

```
{{{open_usage}}}
```

### Listing open pull requests

```
{{{list_usage}}}
```

### Diffing a pull request

```
{{{diff_usage}}}
```

If the pull request doesn't exist locally, git_pr will fetch the branch, setting
up a remote if necessary. Not surprisingly, `git pr difftool` is identical in
behavior, except for invoking `git difftool` under the covers.

### Getting CI status

```
{{{status_usage}}}
```

Note that you can also use `git pr list --status`, although it's quite a bit
slower, as it involves an additional request per open PR.

### Merging

```
{{{merge_usage}}}
```

__Note__: `git pr merge` is opinionated, and tries to perform a "clean" merge in order to
maintain linear history. When you run `git pr merge`, the following happens:

1. Source and target branches are updated
1. Source branch is rebased on top of the target branch
1. Source branch is pushed to its remote
1. Source branch is merged into the target branch (with `--no-ff`, so a merge
   commit is always created)
1. User is prompted to confirm the merge (see screencast above)

## Useful tips

- You can shorten command words quite a bit:

Command | Accepted abbreviations
--- | ---
`list` | `l`, `ls`
`open` | `o`, `web`
`diff` | `d`
`difftool` | `dt`
`status` | `s`
`merge` | `m`

- Most commands will look at the current branch and try to do the right thing,
  without requiring you to pass a PR number or a branch. This includes `open`,
  `diff`, `difftool`, `status` and `merge`.

- You can force a merge even if CI fails with `git pr merge --yolo`

## Configuration

git_pr tries to make sane assumptions about your setup, but can get confused by
non-standard names for remotes. In particular, you may need to specify which
GitHub project is the target for pull requests. This can be done on a one-time
basis with the `--project` option:

```bash
$ git pr --project floatplane/git_pr ls
#39 from floatplane: Add a readme, finally
```

You can also set this value on a per-repository basis via `git config`. See
[Usage](#usage) for details.
