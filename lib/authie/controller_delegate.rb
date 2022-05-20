# frozen_string_literal: true

require 'securerandom'
require 'authie/session'
require 'authie/config'
require 'authie/session_model'

module Authie
  # The controller delegate implements methods that can be used by a controller. These are then
  # extended into controllers as needed (see ControllerExtension).
  class ControllerDelegate
    attr_accessor :touch_auth_session_enabled

    # @param controller [ActionController::Base]
    # @return [Authie::ControllerDelegate]
    def initialize(controller)
      @controller = controller
      @touch_auth_session_enabled = true
    end

    # Sets a browser ID. This must be performed on any page request where AUthie will be used.
    # It should be triggered before any other Authie provided methods. This will ensure that
    # the given browser ID is unique.
    #
    # @return [String] the generated browser ID
    def set_browser_id
      until cookies[Authie.config.browser_id_cookie_name]
        proposed_browser_id = SecureRandom.uuid
        next if Authie::SessionModel.where(browser_id: proposed_browser_id).exists?

        cookies[Authie.config.browser_id_cookie_name] = {
          value: proposed_browser_id,
          expires: 5.years.from_now,
          httponly: true,
          secure: @controller.request.ssl?
        }
        Authie.notify(:set_browser_id,
                      browser_id: proposed_browser_id,
                      controller: @controller)
      end
      proposed_browser_id
    end

    # Validate the auth session to ensure that it is current validate and raise an error if it
    # is not suitable for use.
    #
    # @return [Authie::Session, false]
    def validate_auth_session
      return auth_session.validate if logged_in?

      false
    end

    # Touch the session to update details on the latest activity.
    #
    # @return [Authie::Session, false]
    def touch_auth_session
      yield if block_given?
    ensure
      auth_session.touch if @touch_auth_session_enabled && logged_in?
    end

    # Return the user for the currently logged in user or nil if no user is logged in
    #
    # @return [ActiveRecord::Base, nil]
    def current_user
      return nil unless logged_in?

      auth_session.session.user
    end

    # Create a new session for the given user. If nil is provided as a user, the existing session
    # will be invalidated.
    #
    # @return [Authie::Session, nil]
    def create_auth_session(user, **kwargs)
      if user
        @auth_session = Authie::Session.start(@controller, user: user, **kwargs)
        return @auth_session
      end

      invalidate_auth_session
      nil
    end

    # Invalidate the existing auth session if one exists. Return true if a sesion has been invalidated
    # otherwise return false.
    #
    # @return [Boolean]
    def invalidate_auth_session
      if logged_in?
        auth_session.invalidate
        @auth_session = nil
        return true
      end

      false
    end

    # Is anyone currently logged in? Return true if there is an auth session present.
    #
    # Note: this does not check the validatity of the session. You must always ensure that the `validate`
    # or `touch` method is invoked to ensure that the session that has been found is active.
    #
    # @return [Boolean]
    def logged_in?
      auth_session.is_a?(Session)
    end

    # Return an auth session that has been found in the current cookies.
    #
    # @return [Authie::Session]
    def auth_session
      return @auth_session if instance_variable_defined?('@auth_session')

      @auth_session = Authie::Session.get_session(@controller)
    end

    private

    def cookies
      @controller.send(:cookies)
    end
  end
end
