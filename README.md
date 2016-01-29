# git_pr

A command-line utility for creating, viewing, diffing, and merging GitHub pull requests.

## tl;dr

[![asciicast](https://asciinema.org/a/2owcxgz5r5275woapwrrdg5nz.png)](https://asciinema.org/a/2owcxgz5r5275woapwrrdg5nz?autoplay=1&speed=3)

## Installation

`sudo gem install git_pr`

## Usage

```
$ git pr help
git_pr version 0.0.14

Usage: git pr [options] command [options]

Global options
    -p, --project [REMOTE|PROJECT]   The GitHub project to access. Can be a named remote, or a GitHub project in
                                     <user>/<project> form. Defaults to the GitHub project that the "origin"
                                     or "upstream" remote points to. You can override the default remote
                                     with git config. Run: 'git config --add pr.defaultremote <remote_name>'
    -h, --help                       Show help
    -v, --verbose                    Verbose output
    -V, --version                    Print version

Valid commands:
    diff:     Use "git diff" to display a diff for a pull request
    difftool: Like "diff", but uses "git difftool" instead
    list:     List open pull requests
    status:   Show the detailed status for a pull request
    merge:    Merge and close a pull request
    open:     Open a PR page on the web

Run "git pr help <command>" for more detailed help.
```

### Opening a pull request

```
$ git pr help open
Usage: git pr open [pr_number|branch]

Open a pull request page, if one exists, for the passed in PR number or
branch. Otherwise, open a diff page where a pull request can be created. If no
argument is passed, open a PR page for the current branch.
```

### Listing open pull requests

```
$ git pr help list
Usage: git pr list [options]

List command options
    -u, --user [USERNAME]            Only list PRs for the named GitHub user
    -s, --[no-]status                Include PR status in the output. Including status is slower,
                                     as each PR's status must be queried individually. You can set
                                     the default behavior with git config:
                                     
                                     git config --bool --add pr.liststatus true
```

### Diffing a pull request

```
$ git pr help diff
Usage: git pr diff [PR number] [-- [additional options]]

Fetch the latest changes for the specified PR, and then run "git
diff". Additional options are passed to the "git diff" command.
```

If the pull request doesn't exist locally, git_pr will fetch the branch, setting
up a remote if necessary. Not surprisingly, `git pr difftool` is identical in
behavior, except for invoking `git difftool` under the covers.

### Getting CI status

```
$ git pr help status
Usage: git pr status [pr_number|branch]

Report detailed pull request status for the passed in PR number or
branch.
```

Note that you can also use `git pr list --status`, although it's quite a bit
slower, as it involves an additional request per open PR.

### Merging

```
$ git pr help merge
Usage: git pr merge [PR number]

If a PR number isn't passed, a menu of open PRs will be displayed.

Merge command options
    -y, --yolo                       Don't check PR status before merging
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
