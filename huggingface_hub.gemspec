# frozen_string_literal: true

require_relative "lib/durable_huggingface_hub/version"

Gem::Specification.new do |spec|
  spec.name = "durable_huggingface_hub"
  spec.version = DurableHuggingfaceHub::VERSION.to_s
  spec.authors = ["David Berube"]
  spec.email = ["commercial@durableprogramming.com"]

  spec.summary = "Pure Ruby client for HuggingFace Hub"
  spec.description = <<~DESC
    A complete, production-ready Ruby implementation of the HuggingFace Hub client library.
    Download models, datasets, and manage repositories with zero Python dependencies.
    Features smart caching, authentication, progress tracking, and comprehensive error handling.
  DESC
  spec.homepage = "https://github.com/durableprogramming/huggingface-hub-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/durableprogramming/huggingface-hub-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/durableprogramming/huggingface-hub-ruby/blob/master/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/huggingface_hub"
  spec.metadata["bug_tracker_uri"] = "https://github.com/durableprogramming/huggingface-hub-ruby/issues"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile reference/ philosophy/ durableprogramming-coding-standards/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"
  spec.add_dependency "faraday-retry", "~> 2.0"
  spec.add_dependency "dry-struct", "~> 1.6"
  spec.add_dependency "dry-types", "~> 1.7"
  spec.add_dependency "ruby-progressbar", "~> 1.13"
  spec.add_dependency "zeitwerk", "~> 2.6"

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-reporters", "~> 1.6"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "vcr", "~> 6.1"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "rubocop-minitest", "~> 0.31"
  spec.add_development_dependency "rubocop-rake", "~> 0.6"
  spec.add_development_dependency "yard", "~> 0.9"
  spec.add_development_dependency "simplecov", "~> 0.22"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
