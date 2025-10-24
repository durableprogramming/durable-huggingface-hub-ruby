# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"

# Test tasks
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
  t.warning = false
end

namespace :test do
  desc "Run tests with coverage"
  task :coverage do
    ENV["COVERAGE"] = "true"
    Rake::Task[:test].execute
  end

  desc "Run integration tests"
  Rake::TestTask.new(:integration) do |t|
    t.libs << "test"
    t.libs << "lib"
    t.test_files = FileList["test/integration/**/*_test.rb"]
    t.verbose = true
    t.warning = false
  end
end

# RuboCop tasks
RuboCop::RakeTask.new do |task|
  task.options = ["--display-cop-names"]
  task.fail_on_error = true
end

namespace :rubocop do
  desc "Auto-correct RuboCop offenses"
  RuboCop::RakeTask.new(:autocorrect) do |task|
    task.options = ["--auto-correct", "--display-cop-names"]
  end

  desc "Auto-correct RuboCop offenses (including unsafe)"
  RuboCop::RakeTask.new(:autocorrect_all) do |task|
    task.options = ["--auto-correct-all", "--display-cop-names"]
  end
end

# YARD documentation tasks
begin
  require "yard"

  YARD::Rake::YardocTask.new(:yard) do |t|
    t.files = ["lib/**/*.rb"]
    t.options = ["--output-dir", "doc", "--readme", "README.md"]
  end

  namespace :yard do
    desc "Generate YARD documentation and open in browser"
    task :server do
      sh "yard server --reload"
    end

    desc "List undocumented objects"
    task :stats do
      sh "yard stats --list-undoc"
    end
  end
rescue LoadError
  # YARD not available
end

# Default task
task default: %i[rubocop test]

# Build task
desc "Build the gem"
task :build do
  sh "gem build huggingface_hub.gemspec"
end

# Install task
desc "Build and install the gem locally"
task install: :build do
  sh "gem install huggingface_hub-*.gem"
end

# Clean task
desc "Clean up generated files"
task :clean do
  sh "rm -f huggingface_hub-*.gem"
  sh "rm -rf doc/"
  sh "rm -rf coverage/"
  sh "rm -rf tmp/"
end

# Console task for interactive testing
desc "Open an IRB console with the gem loaded"
task :console do
  require "irb"
  require "huggingface_hub"
  ARGV.clear
  IRB.start
end
