# frozen_string_literal: true

require 'authie/session_model'
require 'authie/error'
require 'authie/config'
require 'active_support/core_ext/module/delegation'

module Authie
  class Session
    # The underlying session model instance
    #
    # @return [Authie::SessionModel]
    attr_reader :session

    # A parent class that encapsulates all session validity errors.
    class ValidityError < Error; end

    # Raised when a session is used but it is no longer active
    class InactiveSession < ValidityError; end

    # Raised when a session is used but it has expired
    class ExpiredSession < ValidityError; end

    # Raised when a session is used but the browser ID does not match
    class BrowserMismatch < ValidityError; end

    # Raised when a session is used but the hostname does not match
    # the session hostname
    class HostMismatch < ValidityError; end

    # Initialize a new session object
    #
    # @param controller [ActionController::Base] any controller
    # @param session [Authie::SessionModel] an Authie session model instance
    # @return [Authie::Session]
    def initialize(controller, session)
      @controller = controller
      @session = session
    end

    # Validate that the session is valid and raise and error if not
    #
    # @raises [Authie::Session::BrowserMismatch]
    # @raises [Authie::Session::InactiveSession]
    # @raises [Authie::Session::ExpiredSession]
    # @raises [Authie::Session::HostMismatch]
    # @return [Authie::Session]
    def validate
      if cookies[:browser_id] != @session.browser_id
        invalidate
        Authie.config.events.dispatch(:browser_id_mismatch_error, self)
        raise BrowserMismatch, 'Browser ID mismatch'
      end

      unless @session.active?
        invalidate
        Authie.config.events.dispatch(:invalid_session_error, self)
        raise InactiveSession, 'Session is no longer active'
      end

      if @session.expired?
        invalidate
        Authie.config.events.dispatch(:expired_session_error, self)
        raise ExpiredSession, 'Persistent session has expired'
      end

      if @session.inactive?
        invalidate
        Authie.config.events.dispatch(:inactive_session_error, self)
        raise InactiveSession, 'Non-persistent session has expired'
      end

      if @session.host && @session.host != @controller.request.host
        invalidate
        Authie.config.events.dispatch(:host_mismatch_error, self)
        raise HostMismatch, "Session was created on #{@session.host} but accessed using #{@controller.request.host}"
      end

      self
    end

    # Mark the current session as persistent. Will set the expiry time of the underlying
    # session and update the cookie.
    #
    # @raises [ActiveRecord::RecordInvalid]
    # @return [Authie::Session]
    def persist
      @session.expires_at = Authie.config.persistent_session_length.from_now
      @session.save!
      set_cookie
      self
    end

    # Invalidates the current session by marking it inactive and removing the current cookie.
    #
    # @raises [ActiveRecord::RecordInvalid]
    # @return [Authie::Session]
    def invalidate
      @session.invalidate!
      cookies.delete(:user_session)
      self
    end

    # Touches the current session to ensure it is currently valid and to update attributes
    # which should be updatd on each request. This will raise the same errors as the #validate
    # method. It will set the last activity time, IP and path as well as incrementing
    # the request counter.
    #
    # @raises [Authie::Session::BrowserMismatch]
    # @raises [Authie::Session::InactiveSession]
    # @raises [Authie::Session::ExpiredSession]
    # @raises [Authie::Session::HostMismatch]
    # @raises [ActiveRecord::RecordInvalid]
    # @return [Authie::Session]
    def touch
      validate
      @session.last_activity_at = Time.now
      @session.last_activity_ip = @controller.request.ip
      @session.last_activity_path = @controller.request.path
      @session.requests += 1
      @session.save!
      Authie.config.events.dispatch(:session_touched, self)
      self
    end

    # Mark the session's password as seen at the current time
    #
    # @raises [ActiveRecord::RecordInvalid]
    # @return [Authie::Session]
    def see_password
      @session.password_seen_at = Time.now
      @session.save!
      Authie.config.events.dispatch(:seen_password, self)
      self
    end

    # Mark this request as two factored by setting the time and the current
    # IP address.
    #
    # @raises [ActiveRecord::RecordInvalid]
    # @return [Authie::Session]
    def mark_as_two_factored
      @session.two_factored_at = Time.now
      @session.two_factored_ip = @controller.request.ip
      @session.save!
      Authie.config.events.dispatch(:marked_as_two_factor, self)
      self
    end

    # Starts a new session by setting the cookie. This should be invoked whenever
    # a new session begins. It usually does not need to be called directly as it
    # will be taken care of by the class-level start method.
    #
    # @return [Authie::Session]
    def start
      set_cookie
      Authie.config.events.dispatch(:start_session, session)
      self
    end

    private

    # rubocop:disable Naming/AccessorMethodName
    def set_cookie(value = @session.temporary_token)
      cookies[:user_session] = {
        value: value,
        secure: @controller.request.ssl?,
        httponly: true,
        expires: @session.expires_at
      }
      Authie.config.events.dispatch(:session_cookie_updated, self)
      true
    end
    # rubocop:enable Naming/AccessorMethodName

    def cookies
      @controller.send(:cookies)
    end

    class << self
      # Create a new session within the given controller for the
      #
      # @param controller [ActionController::Base]
      # @option params [ActiveRecord::Base] user
      # @return [Authie::Session]
      def start(controller, params = {})
        cookies = controller.send(:cookies)
        SessionModel.active.where(browser_id: cookies[:browser_id]).each(&:invalidate!)
        user_object = params.delete(:user)

        session = SessionModel.new(params)
        session.user = user_object
        session.browser_id = cookies[:browser_id]
        session.login_at = Time.now
        session.login_ip = controller.request.ip
        session.host = controller.request.host
        session.user_agent = controller.request.user_agent
        session.save!

        new(controller, session).start
      end

      # Lookup a session for a given controller and return the session
      # object.
      #
      # @param controller [ActionController::Base]
      # @return [Authie::Session]
      def get_session(controller)
        cookies = controller.send(:cookies)
        return nil if cookies[:user_session].blank?

        session = SessionModel.find_session_by_token(cookies[:user_session])
        return nil if session.blank?

        session.temporary_token = cookies[:user_session]
        new(controller, session)
      end

      delegate :hash_token, to: SessionModel
    end

    # Backwards compatibility with Authie < 4.0. These methods were all available on sessions
    # in previous versions of Authie. They have been maintained for backwards-compatibility but
    # will be removed entirely in Authie 5.0.
    alias check_security! validate
    alias persist! persist
    alias invalidate! invalidate
    alias touch! touch
    alias set_cookie! set_cookie
    alias see_password! see_password
    alias mark_as_two_factored! mark_as_two_factored

    # Delegate key methods back to the underlying session model. Previous behaviour in Authie
    # exposed all methods on the session model. It is useful that these methods can be accessed
    # easily from this session proxy model so these are maintained as delegated methods.
    delegate :active?, to: :session
    delegate :browser_id, to: :session
    delegate :expired?, to: :session
    delegate :first_session_for_browser?, to: :session
    delegate :first_session_for_ip?, to: :session
    delegate :get, to: :session
    delegate :inactive?, to: :session
    delegate :invalidate_others!, to: :session
    delegate :last_activity_at, to: :session
    delegate :last_activity_ip, to: :session
    delegate :last_activity_path, to: :session
    delegate :login_at, to: :session
    delegate :login_ip, to: :session
    delegate :password_seen_at, to: :session
    delegate :persisted?, to: :session
    delegate :persistent?, to: :session
    delegate :recently_seen_password?, to: :session
    delegate :requests, to: :session
    delegate :set, to: :session
    delegate :temporary_token, to: :session
    delegate :token_hash, to: :session
    delegate :two_factored_at, to: :session
    delegate :two_factored_ip, to: :session
    delegate :two_factored?, to: :session
    delegate :update, to: :session
    delegate :update!, to: :session
    delegate :user_agent, to: :session
    delegate :user, to: :session
  end
end
