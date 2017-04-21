module Authie
  class Session < ActiveRecord::Base

    # Define some errors which may be used
    class InactiveSession < Error; end
    class ExpiredSession < Error; end
    class BrowserMismatch < Error; end
    class NoParentSessionForRevert < Error; end

    # Set table name
    self.table_name = "authie_sessions"

    # Relationships
    user_options = {:polymorphic => true}.merge(Authie.config.user_relationship_options)
    user_options[:optional] = true if ActiveRecord::VERSION::MAJOR >= 5
    belongs_to :user, user_options

    parent_options = {:class_name => "Authie::Session"}
    parent_options[:optional] = true if ActiveRecord::VERSION::MAJOR >= 5
    belongs_to :parent, parent_options

    # Scopes
    scope :active, -> { where(:active => true) }
    scope :asc, -> { order(:last_activity_at => :desc) }

    # Attributes
    serialize :data, Hash
    attr_accessor :controller
    attr_accessor :temporary_token

    before_validation do
      if self.user_agent.is_a?(String)
        self.user_agent = self.user_agent[0,255]
      end
    end

    before_create do
      self.temporary_token = SecureRandom.base64(32)
      self.token_hash = self.class.hash_token(self.temporary_token)
      if controller
        self.user_agent = controller.request.user_agent
        set_cookie!
      end
    end

    before_destroy do
      cookies.delete(:user_session) if controller
    end

    # This method should be called each time a user performs an
    # action while authenticated with this session.
    def touch!
      self.check_security!
      self.last_activity_at = Time.now
      self.last_activity_ip = controller.request.ip
      self.last_activity_path = controller.request.path
      self.requests += 1
      self.save!
    end

    # Sets the cookie on the associated controller.
    def set_cookie!
      cookies[:user_session] = {
        :value => self.temporary_token,
        :secure => controller.request.ssl?,
        :httponly => true,
        :expires => self.expires_at
      }
    end

    # Check the security of the session to ensure it can be used.
    def check_security!
      if controller
        if cookies[:browser_id] != self.browser_id
          invalidate!
          raise BrowserMismatch, "Browser ID mismatch"
        end

        unless self.active?
          invalidate!
          raise InactiveSession, "Session is no longer active"
        end

        if self.expired?
          invalidate!
          raise ExpiredSession, "Persistent session has expired"
        end

        if self.inactive?
          invalidate!
          raise InactiveSession, "Non-persistent session has expired"
        end
      end
    end

    # Has this persistent session expired?
    def expired?
      self.expires_at &&
      self.expires_at < Time.now
    end

    # Has a non-persistent session become inactive?
    def inactive?
      self.expires_at.nil? &&
      self.last_activity_at &&
      self.last_activity_at < Authie.config.session_inactivity_timeout.ago
    end

    # Allow this session to persist rather than expiring at the end of the
    # current browser session
    def persist!
      self.expires_at = Authie.config.persistent_session_length.from_now
      self.save!
      set_cookie!
    end

    # Is this a persistent session?
    def persistent?
      !!expires_at
    end

    # Activate an old session
    def activate!
      self.active = true
      self.save!
    end

    # Mark this session as invalid
    def invalidate!
      self.active = false
      self.save!
      if controller
        cookies.delete(:user_session)
      end
    end

    # Set some additional data in this session
    def set(key, value)
      self.data ||= {}
      self.data[key.to_s] = value
      self.save!
    end

    # Get some additional data from this session
    def get(key)
      (self.data ||= {})[key.to_s]
    end

    # Invalidate all sessions but this one for this user
    def invalidate_others!
      self.class.where("id != ?", self.id).where(:user => self.user).each do |s|
        s.invalidate!
      end
    end

    # Note that we have just seen the user enter their password.
    def see_password!
      self.password_seen_at = Time.now
      self.save!
    end

    # Have we seen the user's password recently in this sesion?
    def recently_seen_password?
      !!(self.password_seen_at && self.password_seen_at >= Authie.config.sudo_session_timeout.ago)
    end

    # Is two factor authentication required for this request?
    def two_factored?
      !!(two_factored_at || self.parent_id)
    end

    # Mark this request as two factor authoritsed
    def mark_as_two_factored!
      self.two_factored_at = Time.now
      self.two_factored_ip = controller.request.ip
      self.save!
    end

    # Create a new session for impersonating for the given user
    def impersonate!(user)
      self.class.start(controller, :user => user, :parent => self)
    end

    # Revert back to the parent session
    def revert_to_parent!
      if self.parent
        self.invalidate!
        self.parent.activate!
        self.parent.controller = self.controller
        self.parent.set_cookie!
        self.parent
      else
        raise NoParentSessionForRevert, "Session does not have a parent therefore cannot be reverted."
      end
    end

    # Find a session from the database for the given controller instance.
    # Returns a session object or :none if no session is found.
    def self.get_session(controller)
      cookies = controller.send(:cookies)
      if cookies[:user_session] && session = self.find_session_by_token(cookies[:user_session])
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
      self.active.where("token = ? OR token_hash = ?", token, self.hash_token(token)).first
    end

    # Create a new session and return the newly created session object.
    # Any other sessions for the browser will be invalidated.
    def self.start(controller, params = {})
      cookies = controller.send(:cookies)
      self.where(:browser_id => cookies[:browser_id]).each(&:invalidate!)
      session = self.new(params)
      session.controller = controller
      session.browser_id = cookies[:browser_id]
      session.login_at = Time.now
      session.login_ip = controller.request.ip
      session.save!
      session
    end

    # Cleanup any old sessions.
    def self.cleanup
      # Invalidate transient sessions that haven't been used
      self.active.where("expires_at IS NULL AND last_activity_at < ?", Authie.config.session_inactivity_timeout.ago).each(&:invalidate!)
      # Invalidate persistent sessions that have expired
      self.active.where("expires_at IS NOT NULL AND expires_at < ?", Time.now).each(&:invalidate!)
    end

    # Return a hash of a given token
    def self.hash_token(token)
      Digest::SHA256.hexdigest(token)
    end

    # Convert all existing active sessions to store their tokens in the database
    def self.convert_tokens_to_hashes
      active.where(:token_hash => nil).where("token is not null").each do |s|
        hash = self.hash_token(s.token)
        self.where(:id => s.id).update_all(:token_hash => hash, :token => nil)
      end
    end

    private

    # Return all cookies on the associated controller
    def cookies
      controller.send(:cookies)
    end

  end
end
