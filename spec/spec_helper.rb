# frozen_string_literal: true

require "simplecov"

# Configure SimpleCov for 100% coverage tracking
SimpleCov.start do
  enable_coverage :branch
  minimum_coverage 100
  add_filter "/spec/"
  add_filter "/vendor/"

  add_group "Core", ["lib/twelvedata_ruby.rb", "lib/twelvedata_ruby/version.rb"]
  add_group "Client", "lib/twelvedata_ruby/client.rb"
  add_group "API", ["lib/twelvedata_ruby/endpoint.rb", "lib/twelvedata_ruby/request.rb", "lib/twelvedata_ruby/response.rb"]
  add_group "Utilities", ["lib/twelvedata_ruby/utils.rb", "lib/twelvedata_ruby/error.rb"]
end

require "webmock/rspec"
require "httpx/adapters/webmock"
require "pry"

# Load the gem
require "twelvedata_ruby"

# Load support files
Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Use expect syntax
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Use modern should syntax
  config.mock_with :rspec do |c|
    c.verify_partial_doubles = true
  end

  # Enable global DSL for better readability in specs
  config.expose_dsl_globally = true

  # Configure WebMock
  WebMock.enable!
  WebMock.disable_net_connect!(allow_localhost: false)

  # Include support modules
  config.include FixtureHelpers
  config.include HttpStubHelpers

  # Clean up after each test
  config.after(:each) do
    WebMock.reset!
    # Reset client instance for clean state
    TwelvedataRuby::Client.instance.instance_eval do
      @configuration = {}
      @endpoint_methods_defined = Set.new
      send(:reset_configuration)
    end
  end

  # Configure test environment
  config.before(:suite) do
    # Set test API key to avoid environment pollution
    ENV["TWELVEDATA_API_KEY"] = "test-api-key-12345"
  end

  config.after(:suite) do
    # Clean up test environment
    ENV.delete("TWELVEDATA_API_KEY")
  end

  # Filter out gems from backtraces
  config.filter_gems_from_backtrace "webmock", "httpx", "simplecov"

  # Randomize test order
  config.order = :random
  Kernel.srand config.seed

  # Show slowest examples
  config.profile_examples = 10 if ENV["PROFILE"]

  # Verbose output for CI
  config.default_formatter = "progress" unless ENV["CI"]
end

# Shared examples and contexts

RSpec.shared_context "with valid API key" do
  before do
    ENV["TWELVEDATA_API_KEY"] = "valid-test-key"
  end
end

RSpec.shared_context "without API key" do
  before do
    ENV.delete("TWELVEDATA_API_KEY")
  end
end

RSpec.shared_examples "a successful API response" do
  it "returns a Response object" do
    expect(subject).to be_a(TwelvedataRuby::Response)
  end

  it "has no error" do
    expect(subject.error).to be_nil
  end

  it "is successful" do
    expect(subject).to be_success
  end
end

RSpec.shared_examples "an API error response" do |error_code|
  it "returns a Response object with error" do
    expect(subject).to be_a(TwelvedataRuby::Response)
    expect(subject.error).not_to be_nil
    expect(subject.status_code).to eq(error_code) if error_code
  end
end

RSpec.shared_examples "invalid request parameters" do
  it "returns a hash with errors" do
    expect(subject).to be_a(Hash)
    expect(subject).to have_key(:errors)
  end
end




# Shared examples for request validation
RSpec.shared_examples "a valid request" do
  it "is valid" do
    expect(subject).to be_valid
  end

  it "has no errors" do
    expect(subject.errors).to be_empty
  end

  it "returns proper HTTP verb" do
    expect(subject.http_verb).not_to be_nil
  end

  it "returns proper URLs" do
    expect(subject.relative_url).not_to be_nil
    expect(subject.full_url).not_to be_nil
  end

  it "returns proper params" do
    expect(subject.params).not_to be_nil
  end

  it "can be built for HTTP client" do
    expect(subject.build).to be_an(Array)
  end
end

RSpec.shared_examples "an invalid request with missing parameters" do
  it "is not valid" do
    expect(subject).not_to be_valid
  end

  it "has required parameter errors" do
    expect(subject.errors).to have_key(:required_parameters)
  end

  it "returns nil for HTTP methods" do
    expect(subject.http_verb).to be_nil
    expect(subject.params).to be_nil
    expect(subject.build).to be_nil
  end
end

RSpec.shared_examples "an invalid request with invalid parameters" do
  it "is not valid" do
    expect(subject).not_to be_valid
  end

  it "has parameter key errors" do
    expect(subject.errors).to have_key(:parameters_keys)
  end
end

RSpec.shared_examples "an invalid request with invalid endpoint" do
  it "is not valid" do
    expect(subject).not_to be_valid
  end

  it "has endpoint name errors" do
    expect(subject.errors).to have_key(:name)
  end
end
