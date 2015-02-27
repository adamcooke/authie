module Authie
  class Session < ActiveRecord::Base

    # Define some errors which may be used
    class InactiveSession < Error; end
    class ExpiredSession < Error; end
    class BrowserMismatch < Error; end

    # Set table name
    self.table_name = "authie_sessions"

    # Relationships
    belongs_to :user, :polymorphic => true
    belongs_to :parent, :class_name => "Authie::Session"

    # Scopes
    scope :active, -> { where(:active => true) }
    scope :asc, -> { order(:last_activity_at => :desc) }

    # Attributes
    serialize :data, Hash
    attr_accessor :controller

    before_create do
      self.token = SecureRandom.base64(32)
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
      self.save!
    end

    # Sets the cookie on the associated controller.
    def set_cookie!
      cookies[:user_session] = {
        :value => token,
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

        if self.expires_at && self.expires_at < Time.now
          invalidate!
          raise ExpiredSession, "Persistent session has expired"
        end

        if self.expires_at.nil? && self.last_activity_at && self.last_activity_at < Authie.config.session_inactivity_timeout.ago
          invalidate!
          raise InactiveSession, "Non-persistent session has expired"
        end
      end
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

    # Find a session from the database for the given controller instance.
    # Returns a session object or :none if no session is found.
    def self.get_session(controller)
      cookies = controller.send(:cookies)
      if cookies[:user_session] && session = self.active.where(:token => cookies[:user_session]).first
        session.controller = controller
        session
      else
        cookies.delete(:user_session)
        :none
      end
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
      session.save
      session
    end

    # Cleanup any old sessions.
    def self.cleanup
      self.active.where("expires_at IS NULL AND last_activity_at < ?", Authie.config.session_inactivity_timeout.ago).each(&:invalidate!)
    end

    private

    # Return all cookies on the associated controller
    def cookies
      controller.send(:cookies)
    end

  end
end
