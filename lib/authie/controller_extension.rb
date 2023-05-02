# frozen_string_literal: true

require 'authie/controller_delegate'

module Authie
  module ControllerExtension
    class << self
      def included(base)
        base.helper_method :logged_in?, :current_user, :auth_session if base.respond_to?(:helper_method)

        base.before_action :set_browser_id, :validate_auth_session
        base.around_action :touch_auth_session

        base.delegate :set_browser_id, to: :auth_session_delegate
        base.delegate :validate_auth_session, to: :auth_session_delegate
        base.delegate :touch_auth_session, to: :auth_session_delegate
        base.delegate :current_user, to: :auth_session_delegate
        base.delegate :create_auth_session, to: :auth_session_delegate
        base.delegate :invalidate_auth_session, to: :auth_session_delegate
        base.delegate :logged_in?, to: :auth_session_delegate
        base.delegate :auth_session, to: :auth_session_delegate
      end
    end

    private

    def auth_session_delegate
      @auth_session_delegate ||= Authie::ControllerDelegate.new(self)
    end

    def skip_touch_auth_session!
      auth_session_delegate.touch_auth_session_enabled = false
    end
  end
end
