module GitPr

  def self.ensure_remotes_for_pull_request git, pull
    source_remote = GitPr.ensure_remote_for_project(git,
                                                    pull[:head][:user][:login],
                                                    pull[:head][:repo][:git_url],
                                                    pull[:head][:repo][:ssh_url])

    target_remote = GitPr.ensure_remote_for_project(git,
                                                    pull[:base][:user][:login],
                                                    pull[:base][:repo][:git_url],
                                                    pull[:base][:repo][:ssh_url])

    [source_remote, target_remote]
  end

  def self.merge_pull_cleanly git, pull

    pull_number = pull[:number]
    source_branch = pull[:head][:ref]
    source_repo_ssh_url = pull[:head][:repo][:git_url]
    source_repo_clone_url = pull[:head][:repo][:clone_url]

    target_branch = pull[:base][:ref]
    target_repo_ssh_url = pull[:base][:repo][:git_url]
    target_repo_clone_url = pull[:base][:repo][:clone_url]

    puts "Merging #{pull_summary(pull)}".cyan
    puts "#{target_repo_ssh_url}/#{target_branch} <= #{source_repo_ssh_url}/#{source_branch}\n".cyan

    # find or add a remote for the PR
    source_remote, target_remote = self.ensure_remotes_for_pull_request git, pull

    # Fetch latest changes from source & target remotes. Useful in case one of source or target
    # branches doesn't exist locally yet, or if we've never pulled from one of the remotes.
    puts "Fetching latest changes from '#{source_remote}'"
    source_remote.fetch
    unless target_remote.name == source_remote.name
      puts "Fetching latest changes from '#{target_remote}'"
      target_remote.fetch
    end

    # Get the target branch up to date
    puts "Update branch '#{target_branch}' from remote"
    GitPr.run_command "git checkout -q #{target_branch}"
    GitPr.run_command "git pull --no-rebase --ff-only", :failure => lambda {
      "Unable to update local target branch '#{target_branch}'. Please repair manually before continuing.".red
    }

    # If the local target branch differs from the remote target branch, they
    # must be reconciled manually.
    remote_target_branch = "#{target_remote}/#{target_branch}"
    if git.diff("remotes/#{remote_target_branch}", target_branch).any?
      puts "Local branch '#{target_branch}' differs from remote branch '#{remote_target_branch}'. Please reconcile before continuing.".red
      exit -1
    end

    # If a local branch exists with the name source_branch, check that it has the
    # same contents as the remote source branch. If not, it must be reconciled
    # manually.
    remote_source_branch = "#{source_remote}/#{source_branch}"
    if git.is_branch? source_branch and
        git.diff("remotes/#{remote_source_branch}", source_branch).any?
      puts "Local branch '#{source_branch}' differs from remote branch '#{remote_source_branch}'. Please reconcile before continuing.".red
      exit -1
    end

    # Check out the remote source branch using a temporary branch name,
    # failing if the temporary name already exists.
    rebase_branch = "#{source_branch}-rebase"
    puts "Create temporary branch '#{rebase_branch}'"
    if git.is_branch? rebase_branch
      puts "Local rebase branch '#{rebase_branch}' already exists. Please remove before continuing.".red
      exit -1
    end
    GitPr.run_command "git checkout -q -b #{rebase_branch} #{remote_source_branch}"

    # Add an at_exit handler to blow away the temp branch when we exit
    at_exit do
      if git.is_branch? rebase_branch
        puts "Removing temporary branch #{rebase_branch}" if $verbose
        GitPr.run_command "git checkout -q #{target_branch}"
        GitPr.run_command "git branch -D #{rebase_branch}"
      end
    end

    # Rebase the rebase branch on top of the target branch
    puts "Rebasing '#{rebase_branch}' on top of '#{target_branch}'"
    GitPr.run_command "git rebase #{target_branch} 2>&1", :failure => lambda {
      GitPr.run_command "git rebase --abort"

      puts "Unable to automatically rebase #{remote_source_branch} on top of #{target_branch}. Rebase manually and push before trying again.".red
      puts "Run: " + "git checkout #{source_branch}".yellow
      puts "     " + "git rebase #{target_branch}".yellow + " and fix up any conflicts."
      puts "     " + "git push -f".yellow
    }

    # Force push the rebased branch to the source remote.
    puts "Pushing changes from '#{rebase_branch}' to '#{source_remote.name}/#{source_branch}'"
    GitPr.run_command "git push -f #{source_remote.name} HEAD:#{source_branch} 2>&1"

    # Merge the source branch into the target. Use --no-ff so that an explicit
    # merge commit is created.
    puts "Merging changes from '#{rebase_branch}' to '#{target_branch}'"
    GitPr.run_command "git checkout -q #{target_branch}"
    GitPr.run_command "git merge --no-ff #{rebase_branch} -m 'Merge #{pull_summary(pull)}'"

    # Print a log of the merge with branch structure visible. Jump through hoops to
    # get the right branch to start the log revision range with. If origin/develop
    # is a merge commit, we need the right parent of the merge.
    #
    # The goal is to get output like this:
    #
    # *   5be2a77 (HEAD, develop) PR #1269. Merge branch floatplane/feature/categories into develop.
    # |\
    # | * 2242141 (floatplane/feature/categories, feature/categories) Process CR feedback. Remove StaticCreatorListDataSource, will just rework Streamed* version to meet needs instead.
    # | * d7cf231 Implement StaticCreatorListDataSource for categories, rename CreatorListDataSource => StreamedCreatorListDataSource
    # | * ef034d0 Don't animate profile pic transitions when we're re-using a cell and needing to replace someone else's picture. Only animate from the blank thumbnail to an actual picture.
    # | * 25cda8b Refactor CreatorListViewController.
    # | * 682b7ba Adjust search dialog size and default position. Remove temp close button. Stub categories into search dialog.
    # | * e8ba0b1 Rename CollaboratorsListViewController => CreatorListViewController. Add CollaboratorListViewController as a subclass of CreatorListViewController, will refactor behavior into it in future commits.
    # | * e901256 Make dismissWithBackgroundTouch work for all CustomModalDialogs, even those that don't set useCustomPopover. Fix latent bug in ApplicationInfoNavigationController's implementation of the same.
    # |/
    # * 8d5ecbc (origin/develop, origin/HEAD) Merge branch 'feature/schemaUpgradeUtils' into develop
    #
    # where the log stops at origin/develop, no matter whether it's a merge commit or not.
    #
    puts "\nVerify that the merge looks clean:\n".cyan
    origin_parent = `git rev-list --abbrev-commit --parents -n 1 #{target_remote}/#{target_branch}`.split().last
    GitPr.run_command "git log --graph --decorate --pretty=oneline --abbrev-commit --color #{target_branch} #{origin_parent}..#{target_branch}", :force_print_output => true

    if GitPr.prompt "\nDo you want to proceed with the merge (y/n)? ".cyan
      puts "Pushing changes to '#{target_remote}'"
      GitPr.run_command "git push #{target_remote} #{target_branch} 2>&1"
      if GitPr.prompt "\nDo you want to delete the feature branch (y/n)? ".cyan
        source_branch_sha = git.branches["#{source_remote}/#{source_branch}"].gcommit.sha[0..6]
        GitPr.run_command "git push #{source_remote} :#{source_branch} 2>&1"
        if git.is_branch? source_branch
          source_branch_sha = git.branches[source_branch].gcommit.sha[0..6]
          GitPr.run_command "git branch -D #{source_branch}"
        end
        puts "Feature branch '#{source_branch}' deleted. To restore it, run: " + "git branch #{source_branch} #{source_branch_sha}".green
      end
      puts "\nMerge complete!".cyan
    else
      puts "\nUndoing local merge"
      GitPr.run_command "git reset --hard #{target_remote}/#{target_branch}"
    end
  end

end
