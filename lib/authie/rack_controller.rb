# If you're dealing with your authentication in a middleware and you only have
# access to your rack environment, this will wrap around rack and make it look
# close enough to an ActionController to work with Authie
#
# Usage:
#
# controller = Authie::RackController.new(@env)
# controller.current_user = user

module Authie
  class RackController

    attr_reader :request

    def initialize(env)
      @env = env
      @request = ActionDispatch::Request.new(@env)
      set_browser_id
    end

    def cookies
      @request.cookie_jar
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

    def current_user=(user)
      Session.start(self, :user => user)
    end

    def current_user
      if auth_session.is_a?(Session)
        auth_session.user
      else
        nil
      end
    end

    def auth_session
      @auth_session ||= Session.get_session(self)
    end

  end
end
