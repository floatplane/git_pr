require "git_pr/github"
require "git_pr/pull_request"
require "git_pr/version"

module GitPr
  # Your code goes here...

  def self.ensure_remote_for_project git, username, ssh_url, git_url
    # find or add a remote for the PR
    remote = git.remotes.find { |r| [git_url, ssh_url].include? r.url }
    unless remote
      puts "Adding remote '#{username}' from #{ssh_url}"
      remote = git.add_remote username, ssh_url
    end
    remote
  end
end
