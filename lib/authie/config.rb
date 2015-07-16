module Authie
  class Config

    def session_inactivity_timeout
      @session_inactivity_timeout || 12.hours
    end
    attr_writer :session_inactivity_timeout

    def persistent_session_length
      @persistent_session_length || 2.months
    end
    attr_writer :persistent_session_length

    def sudo_session_timeout
      @sudo_session_timeout || 10.minutes
    end
    attr_writer :sudo_session_timeout

    def user_relationship_options
      @user_relationship_options ||= {}
    end

  end

  def self.config
    @config ||= Config.new
  end
end
