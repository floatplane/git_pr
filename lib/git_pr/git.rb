require 'git'

# Add some methods to the git class that operate a lot faster than the defaults
class Git::Base

  # Default implementation of is_local_branch? will create O(N) Git::Branch
  # objects for all branches, local *and* remote. All we care about is
  # existence, so we don't need all that.
  def is_local_branch_fast?(branch)
    self.chdir do
      local_branches = `git branch`.split.map { |b| b.gsub('*', '').strip }
      local_branches.include? branch
    end
  end

  # Shortcut to create a remote for a particular branch, if the branch has an upstream. 
  def find_remote_for_local_branch(branch)
    self.chdir do
      remote_name = `git for-each-ref --format='%(upstream:short)' refs/heads/#{branch}`.strip.sub(/\/#{branch}$/, '')
      remote_name.empty? ? nil : Git::Remote.new(self, remote_name)
    end
  end

end
