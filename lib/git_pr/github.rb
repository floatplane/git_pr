require 'io/console'
require 'octokit'
require 'netrc'

module GitPr
  module GitHub

    AUTH_KEY_NAME = "git-merge-pull"
    NETRC_KEY = "#{AUTH_KEY_NAME}.api.github.com"
    DEFAULT_REMOTE_KEY = "pr.defaultremote"

    def self.test_credentials
      n = Netrc.read
      user, oauth_token = n[NETRC_KEY]
      client = Octokit::Client.new :access_token => oauth_token
      begin
        client.user
      rescue
        return false
      end
      return true
    end

    def self.prompt_for_credentials(args = {})
      user = args[:user]
      pass = args[:pass]
      needs_otp = args[:needs_otp]
      headers = {}

      unless user
        print "Enter your github username: "
        user = STDIN.gets.chomp!
        print "Enter github password for #{user} (never stored): "
        pass = STDIN.noecho(&:gets).chomp!
        puts "\n"
      end

      if needs_otp
        print "Enter an OTP code: "
        otp = STDIN.gets.chomp!
        headers = { "X-GitHub-OTP" => "#{otp}" }
      end

      client = Octokit::Client.new :login => user, :password => pass
      begin
        hostname = `hostname`.strip!
        auth = client.create_authorization(:scopes => ["user", "repo"],
                                           :note => "#{AUTH_KEY_NAME} (#{hostname})",
                                           :fingerprint => "#{hostname} #{Time.now}",
                                           :headers => headers)
      rescue Octokit::Unauthorized
        puts "Invalid username or password."
        return false
      rescue Octokit::OneTimePasswordRequired
        # Clients that receive OTP codes via SMS won't get one when we do a get request to client.authorizations
        # We have to make a post to the authorizations endpoint to trigger the sending of the SMS code.
        # https://github.com/github/hub/commit/3d29989
        begin
          result = client.post "authorizations"
        rescue Octokit::OneTimePasswordRequired
        end

        # Come back through this method, prompting for an OTP
        return prompt_for_credentials :user => user, :pass => pass, :needs_otp => true
      end

      n = Netrc.read
      n[NETRC_KEY] = user, auth[:token]
      n.save

      return true
    end

    def self.initialize_octokit
      n = Netrc.read
      user, oauth_token = n[NETRC_KEY]
      Octokit.configure do |c|
        c.access_token = oauth_token
      end
    end

    def self.determine_project_name_from_command_line git, project_name, default_remotes
      # Figure out what GitHub project we're dealing with. First, did they pass us a name of
      # an existing remote, or did they pass a GitHub project?
      default_remote_from_gitconfig = git.config DEFAULT_REMOTE_KEY
      if project_name
        project_remote = git.remotes.find { |x| x.name == project_name }
      elsif !default_remote_from_gitconfig.empty?
        puts "Using #{DEFAULT_REMOTE_KEY} setting '#{default_remote_from_gitconfig}' from gitconfig" if $verbose
        project_remote = git.remotes.find { |x| x.name == default_remote_from_gitconfig }
        unless project_remote
          puts "The remote '#{default_remote_from_gitconfig}' doesn't exist.".red
          puts "Fix the value of '#{DEFAULT_REMOTE_KEY}' in gitconfig.".red
          exit -1
        end
      else
        project_remote = git.remotes.find { |x| default_remotes.include? x.name }
      end
      if project_remote
        # Regex comment: match the github_user/repository non-greedily (.*?), and
        # accept an optional .git at the end, but don't capture it (?:\.git).
        url_match = project_remote.url.match /^git@github.com:(.*?)(?:\.git)?$/
        unless url_match
          puts "Specified remote '#{project_remote}' is not a GitHub remote.".red
          puts "Remote URL: #{project_remote.url}".red if $verbose
          exit -1
        end
        github_project = url_match[1]
      else
        github_project = project_name
      end

      unless github_project
        puts "Unable to determine the active GitHub project.".red
        puts "For more help, run: git pr -h"
        exit -1
      end

      begin
        github_repo = Octokit.repo "#{github_project}"
      rescue
        puts "Project '#{github_project}' is not a valid GitHub project.".red
        exit -1
      end

      github_project
    end

    def self.query_for_pull_to_merge(pulls)
      puts
      pull_to_merge = nil
      choose do |menu|
        menu.prompt = "Select PR to merge: "
        pulls.each do |pull|
          menu.choice(pull_summary(pull)) { pull_to_merge = pull }
        end
        menu.choice(:Quit, "Exit program.") { exit }
      end
      pull_to_merge
    end

    def self.find_or_prompt_for_pull_request github_project, pull_request
      pulls = Octokit.pulls "#{github_project}"
      unless pulls.length > 0
        puts "No open pull requests found for '#{github_project}'.".yellow
        exit
      end
      if pull_request
        pull_request = pull_request
        pull = pulls.find { |p| p[:number] == pull_request }
        unless pull
          puts "Pull request #{pull_request} not found in project '#{github_project}'!".red
          exit -1
        end
      else
        pull = self.query_for_pull_to_merge pulls
      end
      pull
    end

  end
end
