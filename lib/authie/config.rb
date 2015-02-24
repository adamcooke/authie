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

  end

  def self.config
    @config ||= Config.new
  end
end
