# frozen_string_literal: true

require 'authie/event_manager'

module Authie
  class Config
    def initialize
      @callbacks = {}
    end

    def session_inactivity_timeout
      @session_inactivity_timeout || 12.hours
    end
    attr_writer :session_inactivity_timeout, :persistent_session_length, :sudo_session_timeout, :browser_id_cookie_name

    def persistent_session_length
      @persistent_session_length || 2.months
    end

    def sudo_session_timeout
      @sudo_session_timeout || 10.minutes
    end

    def user_relationship_options
      @user_relationship_options ||= {}
    end

    def browser_id_cookie_name
      @browser_id_cookie_name || :browser_id
    end

    def events
      @events ||= EventManager.new
    end
  end

  def self.config
    @config ||= Config.new
  end

  def self.configure(&block)
    block.call(config)
    config
  end
end
