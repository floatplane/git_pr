# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'git_pr/version'

Gem::Specification.new do |spec|
  spec.name          = "git_pr"
  spec.version       = GitPr::VERSION
  spec.authors       = ["Brian Sharon"]
  spec.email         = ["brian@floatplane.us"]
  spec.summary       = %q{A tool for listing and merging GitHub pull requests.}
  spec.description   = %q{}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  [ "colorize", "tty", "git", "netrc", "octokit", "highline" ].each do |dep|
    spec.add_runtime_dependency dep
  end

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end
