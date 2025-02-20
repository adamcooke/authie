# frozen_string_literal: true

module Authie
  class Config
    attr_accessor :session_inactivity_timeout
    attr_accessor :persistent_session_length
    attr_accessor :sudo_session_timeout
    attr_accessor :browser_id_cookie_name
    attr_accessor :session_token_length
    attr_accessor :extend_session_expiry_on_touch
    attr_accessor :lookup_ip_country_backend
    attr_accessor :serialize_coder

    def initialize
      set_defaults
    end

    def lookup_ip_country(ip)
      return nil if @lookup_ip_country_backend.nil?

      @lookup_ip_country_backend.call(ip)
    end

    def set_defaults
      @session_inactivity_timeout = 12.hours
      @persistent_session_length = 2.months
      @sudo_session_timeout = 10.minutes
      @browser_id_cookie_name = :browser_id
      @session_token_length = 64
      @extend_session_expiry_on_touch = false
      @lookup_ip_country_backend = nil
      @serialize_coder = ActiveRecord::Coders::YAMLColumn
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
