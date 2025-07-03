# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

# RSpec tasks
RSpec::Core::RakeTask.new(:spec) do |task|
  task.rspec_opts = [
    "--format", "progress",
    "--color",
    "--require", "spec_helper"
  ]
end

# RuboCop tasks
RuboCop::RakeTask.new(:rubocop) do |task|
  task.options = ["--display-cop-names"]
end

RuboCop::RakeTask.new("rubocop:auto_correct") do |task|
  task.options = ["--auto-correct"]
end

# Quality assurance task
desc "Run all quality checks"
task :qa do
  puts "🔍 Running RuboCop..."
  Rake::Task["rubocop"].invoke

  puts "\n🧪 Running tests..."
  Rake::Task["spec"].invoke

  puts "\n✅ All quality checks passed!"
rescue SystemExit => e
  puts "\n❌ Quality checks failed!"
  exit e.status
end

# Documentation tasks
begin
  require "yard"

  YARD::Rake::YardocTask.new(:doc) do |task|
    task.files = ["lib/**/*.rb"]
    task.options = [
      "--markup", "markdown",
      "--markup-provider", "kramdown",
      "--main", "README.md",
      "--output-dir", "doc"
    ]
  end

  desc "Generate and open documentation"
  task docs: :doc do
    system("open doc/index.html") if RUBY_PLATFORM.include?("darwin")
  end
rescue LoadError
  puts "YARD not available. Install it with: gem install yard"
end

# Coverage task
desc "Run tests with coverage report"
task :coverage do
  ENV["COVERAGE"] = "true"
  Rake::Task["spec"].invoke
end

# Development setup task
desc "Set up development environment"
task :setup do
  puts "📦 Installing dependencies..."
  system("bundle install")

  puts "🔧 Setting up git hooks..."
  setup_git_hooks

  puts "✅ Development environment ready!"
end

# Release preparation task
desc "Prepare for release"
task :release_prep do
  puts "🔍 Running quality checks..."
  Rake::Task["qa"].invoke

  puts "📚 Generating documentation..."
  Rake::Task["doc"].invoke if defined?(YARD)

  puts "✅ Ready for release!"
end

# Console task for development
desc "Start interactive console with gem loaded"
task :console do
  require "irb"
  require "twelvedata_ruby"
  ARGV.clear
  IRB.start
end

# Default task
task default: :qa

# Helper methods
def setup_git_hooks
  hooks_dir = File.join(__dir__, ".git", "hooks")
  return unless Dir.exist?(hooks_dir)

  pre_commit_hook = File.join(hooks_dir, "pre-commit")
  File.write(pre_commit_hook, <<~HOOK)
    #!/bin/sh
    echo "Running pre-commit checks..."
    bundle exec rubocop --format simple
  HOOK

  File.chmod(0o755, pre_commit_hook) if File.exist?(pre_commit_hook)
end
