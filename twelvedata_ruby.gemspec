# frozen_string_literal: true

require_relative "lib/twelvedata_ruby/version"

Gem::Specification.new do |spec|
  spec.name = "twelvedata_ruby"
  spec.version = TwelvedataRuby::VERSION
  spec.authors = ["Kenneth C. Demanawa, KCD"]
  spec.email = ["kenneth.c.demanawa@gmail.com"]

  spec.summary = "A Ruby client library for accessing Twelve Data's financial API"
  spec.description = <<~DESC
    TwelvedataRuby provides a convenient Ruby interface for accessing Twelve Data's
    comprehensive financial API, including stock, forex, crypto, and other market data.
    Features real-time data access, historical data retrieval, and technical indicators.
  DESC
  spec.homepage = "https://kanutocd.github.io/twelvedata_ruby"
  spec.license = "MIT"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/kanutocd/twelvedata_ruby",
    "changelog_uri" => "https://github.com/kanutocd/twelvedata_ruby/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "https://github.com/kanutocd/twelvedata_ruby/issues",
    "documentation_uri" => "https://kanutocd.github.io/twelvedata_ruby/doc/",
    "wiki_uri" => "https://github.com/kanutocd/twelvedata_ruby/wiki",
    "rubygems_mfa_required" => "true",
  }

  spec.required_ruby_version = ">= 3.4.0"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
