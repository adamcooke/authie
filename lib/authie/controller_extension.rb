require 'authie/controller_delegate'

module Authie
  module ControllerExtension

    def self.included(base)
      base.helper_method :logged_in?, :current_user, :auth_session
      before_action_method = base.respond_to?(:before_action) ? :before_action : :before_filter
      base.public_send(before_action_method, :set_browser_id, :touch_auth_session)
    end

    private

    def auth_session_delegate
      @auth_session_delegate ||= Authie::ControllerDelegate.new(self)
    end

    def set_browser_id
      auth_session_delegate.set_browser_id
    end

    def touch_auth_session
      auth_session_delegate.touch_auth_session
    end

    def current_user
      auth_session_delegate.current_user
    end

    def current_user=(user)
      auth_session_delegate.current_user = user
    end

    def logged_in?
      auth_session_delegate.logged_in?
    end

    def auth_session
      auth_session_delegate.auth_session
    end

  end
end
