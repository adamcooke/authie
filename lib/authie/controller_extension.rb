module Authie
  module ControllerExtension
    
    def self.included(base)
      base.helper_method :logged_in?, :current_user, :auth_session
      base.before_filter :set_browser_id
    end
    
    private
    
    # Set a random browser ID for this browser. 
    def set_browser_id
      until cookies[:browser_id]
        proposed_browser_id = SecureRandom.uuid
        unless Session.where(:browser_id => proposed_browser_id).exists?
          cookies[:browser_id] = {:value => proposed_browser_id, :expires => 20.years.from_now}
        end
      end
    end
    
    # Return the currently logged in user object
    def current_user
      auth_session.user
    end
    
    # Set the currently logged in user
    def current_user=(user)
      if user
        unless logged_in?
          @auth_session = Session.start(self, :user => user)
        end
        @current_user = user
      else
        auth_session.destroy if logged_in?
        @current_user = nil
      end
    end
    
    # Is anyone currently logged in?
    def logged_in?
      auth_session.is_a?(Session)
    end
    
    # Return the currently logged in user session
    def auth_session
      @auth_session ||= Session.get_session(self)
    end
    
  end
end
