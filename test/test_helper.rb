require 'minitest/autorun'
require 'active_record'
require 'authie'

ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
ActiveRecord::Migrator.migrate(File.expand_path('../../db/migrate', __FILE__))
ActiveRecord::Migration.create_table :users do |t|
  t.string :username
end

class User < ActiveRecord::Base
  has_many :sessions, :class_name => 'Authie::Session', :foreign_key => 'user_id', :dependent => :destroy
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
    "127.0.0.1"
  end

  def user_agent
    "TestSuite"
  end

  def ssl?
    true
  end

  def path
    "/demo"
  end
end

class FakeCookieJar
  def initialize(options = {})
    @options = options
    @raw = {}
    if @options[:browser_id]
      @raw[:browser_id] = @options[:browser_id]
    end
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

  def []=(key, value)
    @raw[key.to_sym] = value
  end

  def delete(key)
    @raw.delete(key.to_sym)
  end
end
