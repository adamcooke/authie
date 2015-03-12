module Authie
  class ControllerDelegate

    def initialize(controller)
      @controller = controller
    end

    # Set a random browser ID for this browser.
    def set_browser_id
      until cookies[:browser_id]
        proposed_browser_id = SecureRandom.uuid
        unless Session.where(:browser_id => proposed_browser_id).exists?
          cookies[:browser_id] = {:value => proposed_browser_id, :expires => 20.years.from_now}
        end
      end
    end

    # Touch the auth session on each request if logged in
    def touch_auth_session
      if logged_in?
        auth_session.touch!
      end
    end

    # Return the currently logged in user object
    def current_user
      logged_in? ? auth_session.user : nil
    end

    # Set the currently logged in user
    def current_user=(user)
      if user
        unless logged_in?
          @auth_session = Session.start(@controller, :user => user)
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
      @auth_session ||= Session.get_session(@controller)
    end

    private

    # Return cookies for the controller
    def cookies
      @controller.send(:cookies)
    end

  end
end
