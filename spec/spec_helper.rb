# frozen_string_literal: true

require 'active_record'
require 'timecop'

ENV['RAILS_ENV'] = 'test'

if %w[yes true 1].include?(ENV['COVERAGE'])
  require 'simplecov'
  require 'simplecov-console'
  require 'simplecov_json_formatter'

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::JSONFormatter,
      SimpleCov::Formatter::Console
    ]
  )

  SimpleCov.start 'test_frameworks' do
    enable_coverage :branch
  end
end

ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'
ActiveRecord::Migration.verbose = false
RSpec::Mocks.configuration.allow_message_expectations_on_nil = true

require_relative 'dummy/config/environment'
require_relative 'support/controller_helpers'
require_relative 'support/user_model'

require 'rspec/rails'

RSpec.configure do |config|
  config.color = true
  config.include ControllerHelpers

  config.expect_with :rspec do |expectations|
    expectations.max_formatted_output_length = 1_000_000
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before(:suite) do
    ActiveRecord::MigrationContext.new(File.expand_path('../db/migrate', __dir__),
                                       ActiveRecord::SchemaMigration).migrate(nil)
  end
end
