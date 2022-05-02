# frozen_string_literal: true

require 'active_record/base'
require 'securerandom'
require 'authie/config'

module Authie
  class SessionModel < ActiveRecord::Base
    attr_accessor :temporary_token

    self.table_name = 'authie_sessions'

    belongs_to :parent, class_name: 'Authie::SessionModel', optional: true

    scope :active, -> { where(active: true) }
    scope :asc, -> { order(last_activity_at: :desc) }
    scope :for_user, ->(user) { where(user_type: user.class.name, user_id: user.id) }

    # Attributes
    serialize :data, Hash

    before_validation :shorten_strings
    before_create :set_new_token

    # Return the user that
    def user
      return unless user_id && user_type
      return @user if instance_variable_defined?('@user')

      @user = user_type.constantize.find_by(id: user_id)
    end

    # Set the user
    def user=(user)
      @user = user
      if user
        self.user_type = user.class.name
        self.user_id = user.id
      else
        self.user_type = nil
        self.user_id = nil
      end
    end

    def expired?
      expires_at.present? &&
        expires_at < Time.now
    end

    def inactive?
      expires_at.nil? &&
        last_activity_at.present? &&
        last_activity_at < Authie.config.session_inactivity_timeout.ago
    end

    def persistent?
      !!expires_at
    end

    def activate!
      self.active = true
      save!
    end

    def invalidate!
      self.active = false
      save!
      true
    end

    def set(key, value)
      self.data ||= {}
      self.data[key.to_s] = value
      save!
    end

    def get(key)
      (self.data ||= {})[key.to_s]
    end

    def invalidate_others!
      self.class.where('id != ?', id).for_user(user).each(&:invalidate!).inspect
    end

    # Have we seen the user's password recently in this sesion?
    def recently_seen_password?
      !!(password_seen_at && password_seen_at >= Authie.config.sudo_session_timeout.ago)
    end

    # Is two factor authentication required for this request?
    def two_factored?
      !!(two_factored_at || parent_id)
    end

    # Is this the first session for this session's browser?
    def first_session_for_browser?
      self.class.where('id < ?', id).for_user(user).where(browser_id: browser_id).empty?
    end

    # Is this the first session for the IP?
    def first_session_for_ip?
      self.class.where('id < ?', id).for_user(user).where(login_ip: login_ip).empty?
    end

    # Reset a new token for the session and return the new token
    #
    # @return [String]
    def reset_token
      set_new_token
      save!
      temporary_token
    end

    private

    def shorten_strings
      self.user_agent = user_agent[0, 255] if user_agent.is_a?(String)
      self.last_activity_path = last_activity_path[0, 255] if last_activity_path.is_a?(String)
    end

    def set_new_token
      self.temporary_token = SecureRandom.alphanumeric(Authie.config.session_token_length)
      self.token_hash = self.class.hash_token(temporary_token)
    end

    class << self
      # Find a session from the database for the given controller instance.
      # Returns a session object or :none if no session is found.

      # Find a session by a token (either from a hash or from the raw token)
      def find_session_by_token(token)
        return nil if token.blank?

        active.where(token_hash: hash_token(token)).first
      end

      # Cleanup any old sessions.
      def cleanup
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
      def hash_token(token)
        Digest::SHA256.hexdigest(token)
      end
    end
  end
end
