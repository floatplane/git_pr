#!/usr/bin/env ruby

require 'mustache'

def usage(cmd)
  "$ #{cmd}\n#{`#{cmd}`}".strip
end

top_level = `git rev-parse --show-toplevel`.strip

template = File.read "#{top_level}/doc/README.template.md"
output = Mustache.render(template,
                         :basic_usage => usage("git pr help"),
                         :open_usage => usage("git pr help open"),
                         :list_usage => usage("git pr help list"),
                         :diff_usage => usage("git pr help diff"),
                         :status_usage => usage("git pr help status"),
                         :merge_usage => usage("git pr help merge"),
                        )

File.open "#{top_level}/README.md", "w+" do |f|
  f.write output
end
