# frozen_string_literal: true

require_relative "lib/loo_parser/version"

Gem::Specification.new do |spec|
  spec.name = "loo_parser"
  spec.version = LooParser::VERSION
  spec.authors = ["BrownOps"]
  spec.email = ["nethersoul.dev@gmail.com"]

  spec.summary = "A Ruby tool for parsing WhatsApp chat exports to track bathroom usage patterns."
  spec.description = <<~DESCRIPTION
    Loo Parser processes WhatsApp chat logs to extract, track, and analyze messages containing 💩 and 🚽 emojis according to a specific syntax.
    It helps keep track of bathroom usage over time by different chat participants, including timing and frequency analysis.
  DESCRIPTION
  spec.homepage = "https://github.com/BrownOps/loo_parser.rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/BrownOps/loo_parser.rb"
  spec.metadata["changelog_uri"] = "https://github.com/BrownOps/loo_parser.rb/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 1.2"
  spec.add_dependency "zeitwerk", "~> 2.6"

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata["rubygems_mfa_required"] = "true"
end
