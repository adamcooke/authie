# frozen_string_literal: true

require 'secure_random_string'

module Authie
  class Session < ActiveRecord::Base
    # Errors which will be raised when there's an issue with a session's
    # validity in the request.
    class ValidityError < Error; end

    class InactiveSession < ValidityError; end

    class ExpiredSession < ValidityError; end

    class BrowserMismatch < ValidityError; end

    class HostMismatch < ValidityError; end

    class NoParentSessionForRevert < Error; end

    # Set table name
    self.table_name = 'authie_sessions'

    # Relationships
    parent_options = { class_name: 'Authie::Session' }
    parent_options[:optional] = true if ActiveRecord::VERSION::MAJOR >= 5
    belongs_to :parent, **parent_options

    # Scopes
    scope :active, -> { where(active: true) }
    scope :asc, -> { order(last_activity_at: :desc) }
    scope :for_user, ->(user) { where(user_type: user.class.name, user_id: user.id) }

    # Attributes
    serialize :data, Hash
    attr_accessor :controller, :temporary_token

    before_validation do
      self.user_agent = user_agent[0, 255] if user_agent.is_a?(String)

      self.last_activity_path = last_activity_path[0, 255] if last_activity_path.is_a?(String)
    end

    before_create do
      self.temporary_token = SecureRandomString.new(44)
      self.token_hash = self.class.hash_token(temporary_token)
      if controller
        self.user_agent = controller.request.user_agent
        set_cookie!
      end
    end

    before_destroy do
      cookies.delete(:user_session) if controller
    end

    # Return the user that
    def user
      return unless user_id && user_type

      @user ||= user_type.constantize.find_by(id: user_id) || :none
      @user == :none ? nil : @user
    end

    # Set the user
    def user=(user)
      if user
        self.user_type = user.class.name
        self.user_id = user.id
      else
        self.user_type = nil
        self.user_id = nil
      end
    end

    # This method should be called each time a user performs an
    # action while authenticated with this session.
    def touch!
      check_security!
      self.last_activity_at = Time.now
      self.last_activity_ip = controller.request.ip
      self.last_activity_path = controller.request.path
      self.requests += 1
      save!
      Authie.config.events.dispatch(:session_touched, self)
      true
    end

    # Sets the cookie on the associated controller.
    # rubocop:disable Naming/AccessorMethodName
    def set_cookie!(value = temporary_token)
      cookies[:user_session] = {
        value: value,
        secure: controller.request.ssl?,
        httponly: true,
        expires: expires_at
      }
      Authie.config.events.dispatch(:session_cookie_updated, self)
      true
    end
    # rubocop:enable Naming/AccessorMethodName

    # Sets the cookie for the parent session on the associated controller.
    def set_parent_cookie!
      cookies[:parent_user_session] = {
        value: cookies[:user_session],
        secure: controller.request.ssl?,
        httponly: true,
        expires: expires_at
      }
      Authie.config.events.dispatch(:parent_session_cookie_updated, self)
      true
    end

    # Check the security of the session to ensure it can be used.
    def check_security!
      raise Authie::Error, 'Cannot check security without a controller' unless controller

      if cookies[:browser_id] != browser_id
        invalidate!
        Authie.config.events.dispatch(:browser_id_mismatch_error, self)
        raise BrowserMismatch, 'Browser ID mismatch'
      end

      unless active?
        invalidate!
        Authie.config.events.dispatch(:invalid_session_error, self)
        raise InactiveSession, 'Session is no longer active'
      end

      if expired?
        invalidate!
        Authie.config.events.dispatch(:expired_session_error, self)
        raise ExpiredSession, 'Persistent session has expired'
      end

      if inactive?
        invalidate!
        Authie.config.events.dispatch(:inactive_session_error, self)
        raise InactiveSession, 'Non-persistent session has expired'
      end

      if host && host != controller.request.host
        invalidate!
        Authie.config.events.dispatch(:host_mismatch_error, self)
        raise HostMismatch, "Session was created on #{host} but accessed using #{controller.request.host}"
      end

      true
    end

    # Has this persistent session expired?
    def expired?
      expires_at &&
        expires_at < Time.now
    end

    # Has a non-persistent session become inactive?
    def inactive?
      expires_at.nil? &&
        last_activity_at &&
        last_activity_at < Authie.config.session_inactivity_timeout.ago
    end

    # Allow this session to persist rather than expiring at the end of the
    # current browser session
    def persist!
      self.expires_at = Authie.config.persistent_session_length.from_now
      save!
      set_cookie!
    end

    # Is this a persistent session?
    def persistent?
      !!expires_at
    end

    # Activate an old session
    def activate!
      self.active = true
      save!
    end

    # Mark this session as invalid
    def invalidate!
      self.active = false
      save!
      cookies.delete(:user_session) if controller
      Authie.config.events.dispatch(:session_invalidated, self)
      true
    end

    # Set some additional data in this session
    def set(key, value)
      self.data ||= {}
      self.data[key.to_s] = value
      save!
    end

    # Get some additional data from this session
    def get(key)
      (self.data ||= {})[key.to_s]
    end

    # Invalidate all sessions but this one for this user
    def invalidate_others!
      self.class.where('id != ?', id).for_user(user).each(&:invalidate!)
    end

    # Note that we have just seen the user enter their password.
    def see_password!
      self.password_seen_at = Time.now
      save!
      Authie.config.events.dispatch(:seen_password, self)
      true
    end

    # Have we seen the user's password recently in this sesion?
    def recently_seen_password?
      !!(password_seen_at && password_seen_at >= Authie.config.sudo_session_timeout.ago)
    end

    # Is two factor authentication required for this request?
    def two_factored?
      !!(two_factored_at || parent_id)
    end

    # Mark this request as two factor authoritsed
    def mark_as_two_factored!
      self.two_factored_at = Time.now
      self.two_factored_ip = controller.request.ip
      save!
      Authie.config.events.dispatch(:marked_as_two_factored, self)
      true
    end

    # Create a new session for impersonating for the given user
    def impersonate!(user)
      set_parent_cookie!
      self.class.start(controller, user: user, parent: self)
    end

    # Revert back to the parent session
    def revert_to_parent!
      unless parent && cookies[:parent_user_session]
        raise NoParentSessionForRevert, 'Session does not have a parent therefore cannot be reverted.'
      end

      invalidate!
      parent.activate!
      parent.controller = controller
      parent.set_cookie!(cookies[:parent_user_session])
      cookies.delete(:parent_user_session)
      parent
    end

    # Is this the first session for this session's browser?
    def first_session_for_browser?
      self.class.where('id < ?', id).for_user(user).where(browser_id: browser_id).empty?
    end

    # Is this the first session for the IP?
    def first_session_for_ip?
      self.class.where('id < ?', id).for_user(user).where(login_ip: login_ip).empty?
    end

    # Find a session from the database for the given controller instance.
    # Returns a session object or :none if no session is found.
    def self.get_session(controller)
      cookies = controller.send(:cookies)
      if cookies[:user_session] && (session = find_session_by_token(cookies[:user_session]))
        session.temporary_token = cookies[:user_session]
        session.controller = controller
        session
      else
        :none
      end
    end

    # Find a session by a token (either from a hash or from the raw token)
    def self.find_session_by_token(token)
      return nil if token.blank?

      active.where('token = ? OR token_hash = ?', token, hash_token(token)).first
    end

    # Create a new session and return the newly created session object.
    # Any other sessions for the browser will be invalidated.
    def self.start(controller, params = {})
      cookies = controller.send(:cookies)
      active.where(browser_id: cookies[:browser_id]).each(&:invalidate!)
      user_object = params.delete(:user)

      session = new(params)
      session.user = user_object
      session.controller = controller
      session.browser_id = cookies[:browser_id]
      session.login_at = Time.now
      session.login_ip = controller.request.ip
      session.host = controller.request.host
      session.save!
      Authie.config.events.dispatch(:start_session, session)
      session
    end

    # Cleanup any old sessions.
    def self.cleanup
      Authie.config.events.dispatch(:before_cleanup)
      # Invalidate transient sessions that haven't been used
      active.where('expires_at IS NULL AND last_activity_at < ?',
                   Authie.config.session_inactivity_timeout.ago).each(&:invalidate!)
      # Invalidate persistent sessions that have expired
      active.where('expires_at IS NOT NULL AND expires_at < ?', Time.now).each(&:invalidate!)
      Authie.config.events.dispatch(:after_cleanup)
      true
    end

    # Return a hash of a given token
    def self.hash_token(token)
      Digest::SHA256.hexdigest(token)
    end

    # Convert all existing active sessions to store their tokens in the database
    def self.convert_tokens_to_hashes
      active.where(token_hash: nil).where('token is not null').each do |s|
        hash = hash_token(s.token)
        where(id: s.id).update_all(token_hash: hash, token: nil)
      end
    end

    private

    # Return all cookies on the associated controller
    def cookies
      controller.send(:cookies)
    end
  end
end
