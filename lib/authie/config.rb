# frozen_string_literal: true

module Authie
  class Config
    attr_accessor :session_inactivity_timeout
    attr_accessor :persistent_session_length
    attr_accessor :sudo_session_timeout
    attr_accessor :browser_id_cookie_name
    attr_accessor :session_cookie_name
    attr_accessor :session_token_length
    attr_accessor :extend_session_expiry_on_touch

    def initialize
      @session_inactivity_timeout = 12.hours
      @persistent_session_length = 2.months
      @sudo_session_timeout = 10.minutes
      @browser_id_cookie_name = :browser_id
      @session_cookie_name = :user_session
      @session_token_length = 64
      @extend_session_expiry_on_touch = false
    end
  end

  class << self
    def config
      @config ||= Config.new
    end

    def configure(&block)
      block.call(config)
      config
    end

    def notify(event, args = {}, &block)
      ActiveSupport::Notifications.instrument("#{event}.authie", args, &block)
    end
  end
end
