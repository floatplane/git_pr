module GitPr

  class PullRequest
    def initialize(pull)
      @pull = pull
    end

    def status
      unless @_status
        @_status = Octokit.status(@pull.base.repo.full_name, @pull.head.sha, :accept => Octokit::Client::Statuses::COMBINED_STATUS_MEDIA_TYPE)
      end
      @_status
    end

    def statuses
      self.status.statuses
    end

    def self.summary_icon(state)
      case state
      when "failure"
        STDOUT.tty? ? "\u2717".red : "-"
      when "success"
        STDOUT.tty? ? "\u2713".green : "+"
      else
        STDOUT.tty? ? "\u25CF".yellow : "O"
      end
    end

    def summary(include_status = false)
      if include_status
        status_string = "#{PullRequest.summary_icon(self.state)} "
      else
        status_string = ""
      end
      "#{status_string}##{@pull.number} from #{@pull.user.login}: #{@pull.title}"
    end

    def method_missing(method_name, *args, &block)
      @pull.send method_name, *args, &block
    end

  end

end
