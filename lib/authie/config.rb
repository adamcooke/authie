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
    
    def user_model_class_name
      @user_model_class_name || 'User'
    end
    attr_writer :user_model_class_name
    
  end
  
  def self.config
    @config ||= Config.new
  end
end
