module Authie
  class ControllerDelegate

    def initialize(controller)
      @controller = controller
    end

    # Set a random browser ID for this browser.
    def set_browser_id
      until cookies[Authie.config.browser_id_cookie_name]
        proposed_browser_id = SecureRandom.uuid
        unless Session.where(:browser_id => proposed_browser_id).exists?
          cookies[Authie.config.browser_id_cookie_name] = {
            :value => proposed_browser_id,
            :expires => 5.years.from_now,
            :httponly => true,
            :secure => @controller.request.ssl?
          }
          # Dispatch an event when the browser ID is set.
          Authie.config.events.dispatch(:set_browser_id, proposed_browser_id)
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
      create_auth_session(user)
      user
    end

    # Create a new session for the given user
    def create_auth_session(user)
      if user
        @auth_session = Session.start(@controller, :user => user)
      else
        auth_session.invalidate! if logged_in?
        @auth_session = :none
      end
    end

    # Invalidate an existing auth session
    def invalidate_auth_session
      if logged_in?
        auth_session.invalidate!
        @auth_session = :none
        true
      else
        false
      end
    end

    # Is anyone currently logged in?
    def logged_in?
      auth_session.is_a?(Session)
    end

    # Return the currently logged in user session
    def auth_session
      @auth_session ||= Session.get_session(@controller)
      @auth_session == :none ? nil : @auth_session
    end

    private

    # Return cookies for the controller
    def cookies
      @controller.send(:cookies)
    end

  end
end
