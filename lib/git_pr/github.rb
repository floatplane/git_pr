require 'io/console'
require 'octokit'
require 'netrc'

module GitPr
  module GitHub

    AUTH_KEY_NAME = "git-merge-pull"
    NETRC_KEY = "#{AUTH_KEY_NAME}.api.github.com"

    def self.test_credentials
      n = Netrc.read
      user, oauth_token = n[NETRC_KEY]
      client = Octokit::Client.new :access_token => oauth_token
      begin
        client.user
      rescue
        n.delete NETRC_KEY
        n.save
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
        print "Password: "
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
        authorizations = client.authorizations :headers => headers
        auth = authorizations.find { |x| x[:app][:name].match "^#{AUTH_KEY_NAME}" }
        unless auth
          auth = client.create_authorization(:scopes => ["user", "repo"], :note => AUTH_KEY_NAME, :headers => headers)
        end
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

  end
end
