# frozen_string_literal: true

require 'minitest/autorun'
require 'active_record'
require 'authie'

ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'

if ActiveRecord.version < Gem::Version.create('6.0.0')
  ActiveRecord::Migrator.migrate(File.expand_path('../db/migrate', __dir__))
else
  ActiveRecord::MigrationContext.new(File.expand_path('../db/migrate', __dir__),
                                     ActiveRecord::SchemaMigration).migrate(nil)
end

ActiveRecord::Migration.create_table :users do |t|
  t.string :username
end

class User < ActiveRecord::Base
  has_many :sessions, class_name: 'Authie::Session', foreign_key: 'user_id', dependent: :destroy
end

class FakeController
  def initialize(options = {})
    @options = options
  end

  def cookies
    @cookies ||= FakeCookieJar.new(@options)
  end

  def request
    @request ||= FakeRequest.new(@options)
  end
end

class FakeRequest
  def initialize(options)
    @options = options
  end

  def ip
    '127.0.0.1'
  end

  def user_agent
    'TestSuite'
  end

  def ssl?
    true
  end

  def path
    '/demo'
  end

  def host
    @options[:host] || 'test.example.com'
  end
end

class FakeCookieJar
  def initialize(options = {})
    @options = options
    @raw = {}
    @raw[:browser_id] = @options[:browser_id] if @options[:browser_id]

    @raw[:user_session] = @options[:user_session] if @options[:user_session]
  end

  attr_reader :raw

  def [](key)
    key = @raw[key.to_sym]
    if key.is_a?(Hash)
      key[:value]
    else
      key
    end
  end

  def expiry_for(key)
    value = @raw[key.to_sym]
    value[:expires] if value.is_a?(Hash)
  end

  def []=(key, value)
    @raw[key.to_sym] = value
  end

  def delete(key)
    @raw.delete(key.to_sym)
  end
end
