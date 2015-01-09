require "git_pr/git"
require "git_pr/github"
require "git_pr/pull_request"
require "git_pr/version"
require "git_pr/merge"
require "git_pr/diff"

module GitPr
  # Your code goes here...

  def self.run_command(cmd,
                       args = {
                         :failure => lambda {},
                         :force_print_output => false
                       })
    puts cmd.green if $verbose
    result = `#{cmd}`
    puts result if $verbose || args[:force_print_output]
    puts '' if $verbose
    if $?.exitstatus != 0
      args[:failure].call()
      exit -1
    end
  end

  def self.get_char
    state = `stty -g`
    `stty raw -echo -icanon isig`

    STDIN.getc.chr
  ensure
    `stty #{state}`
    puts ""
  end

  def self.prompt prompt
    print prompt
    return GitPr.get_char.downcase == 'y'
  end

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
