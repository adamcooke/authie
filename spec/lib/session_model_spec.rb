# frozen_string_literal: true

require 'spec_helper'
require 'authie/session_model'

RSpec.describe Authie::SessionModel do
  subject(:user) { User.create!(username: 'adam') }
  subject(:session_model) { described_class.new(user: user) }

  context '#on creation' do
    it 'limits the size of user agents to 255 characters' do
      session_model.user_agent = 'A' * 500
      session_model.save!
      expect(session_model.user_agent.size).to eq 255
    end

    it 'limits the size of last activity paths to 255 characters' do
      session_model.last_activity_path = 'A' * 500
      session_model.save!
      expect(session_model.last_activity_path.size).to eq 255
    end
    it 'generates a new token' do
      session_model.save!
      expect(session_model.temporary_token).to be_a String
      expect(session_model.temporary_token).to match(/\A[A-Za-z0-9]{64}\z/)
    end

    it 'stores the newly generated token as a SHA256 hash' do
      session_model.save!
      expect(session_model.token_hash).to be_a String
      expect(session_model.token_hash).to match(/\A[a-f0-9]{64}\z/)
      expect(session_model.token_hash).to eq Digest::SHA256.hexdigest(session_model.temporary_token)
    end
  end

  context '#user' do
    it 'returns the user object' do
      expect(session_model.user).to eq user
    end

    it 'looks up the user object from the database' do
      session_model.save!
      new_session_model = described_class.find_by(id: session_model.id)
      expect(new_session_model.user).to eq user
    end

    it 'returns nil if user_id is nil' do
      session_model.user_id = nil
      expect(session_model.user).to be nil
    end

    it 'returns nil if user_type is nil' do
      session_model.user_type = nil
      expect(session_model.user).to be nil
    end
  end

  context '#user=' do
    it 'sets the user type and ID' do
      user = User.create!(username: 'other')
      session_model.user = user
      expect(session_model.user_type).to eq 'User'
      expect(session_model.user_id).to eq user.id
    end

    it 'caches the value in an instance variable' do
      user = User.create!(username: 'other')
      session_model.user = user
      expect(session_model.instance_variable_get('@user')).to eq user
    end

    it 'sets the user type and ID to nil if nil is provided' do
      session_model.user = nil
      expect(session_model.user_type).to be nil
      expect(session_model.user_id).to be nil
      expect(session_model.instance_variable_get('@user')).to be nil
    end
  end

  context '#expired?' do
    it 'returns false if there is no expiry time' do
      expect(session_model.expired?).to be false
    end

    it 'returns false if the expiry time is in the future' do
      session_model.expires_at = 2.hours.from_now
      expect(session_model.expired?).to be false
    end

    it 'returns true if the expiry time is in the past' do
      session_model.expires_at = 2.hours.ago
      expect(session_model.expired?).to be true
    end
  end

  context '#inactive?' do
    it 'returns false if there is an expiry time given' do
      session_model.expires_at = 2.hours.from_now
      expect(session_model.inactive?).to be false
    end

    it 'returns false if there is no last activity time' do
      expect(session_model.inactive?).to be false
    end

    it 'returns false if the last activity time is within the inactivity timeout' do
      session_model.last_activity_at = 2.hours.ago
      expect(session_model.inactive?).to be false
    end

    it 'returns true if the last activity time is more than the inactivity timeout' do
      session_model.last_activity_at = 13.hours.ago
      expect(session_model.inactive?).to be true
    end
  end

  context '#persistent?' do
    it 'returns true if there is an expiry date' do
      session_model.expires_at = 2.hours.from_now
      expect(session_model.persistent?).to be true
    end

    it 'returns false if there is no expiry date' do
      expect(session_model.persistent?).to be false
    end
  end

  context '#activate!' do
    it 'sets the active boolean to true' do
      session_model.active = false
      session_model.activate!
      expect(session_model.active).to be true
    end
  end

  context '#invalidate!' do
    it 'sets the active boolean to false' do
      session_model.active = true
      session_model.invalidate!
      expect(session_model.active).to be false
    end
  end

  context '#set' do
    it 'sets the given value in the data hash' do
      session_model.set('hello', 'world')
      expect(session_model.data['hello']).to eq 'world'
    end

    it 'converts symbols to strings in keys' do
      session_model.set(:hello, 'world')
      expect(session_model.data['hello']).to eq 'world'
    end
  end

  context '#get' do
    it 'reads a value from the data hash' do
      session_model.data = { 'hello' => 'world' }
      expect(session_model.get('hello')).to eq 'world'
    end

    it 'works with symbols for keys' do
      session_model.data = { 'hello' => 'world' }
      expect(session_model.get(:hello)).to eq 'world'
    end
  end

  context '#invalidate_others!' do
    before do
      @other_session1 = described_class.create!(active: true, user: user)
      @other_session2 = described_class.create!(active: true, user: user)
      session_model.save!
    end

    it 'marks all other sessions for the same user as inaactive' do
      session_model.invalidate_others!
      @other_session1.reload
      @other_session2.reload
      expect(@other_session1.active?).to be false
      expect(@other_session2.active?).to be false
    end

    it 'does not mark the current session as inactive' do
      session_model.invalidate_others!
      session_model.reload
      @other_session1.reload
      @other_session2.reload
      expect(@other_session1.active?).to be false
      expect(@other_session2.active?).to be false
      expect(session_model.active?).to be true
    end

    it 'does not mark sessions for other users as inactive' do
      other_user_session = described_class.create!(active: true, user: User.create!(username: 'bob'))
      session_model.invalidate_others!
      @other_session1.reload
      @other_session2.reload
      other_user_session.reload
      expect(@other_session1.active?).to be false
      expect(@other_session2.active?).to be false
      expect(other_user_session.active?).to be true
    end
  end

  context '#recently_seen_password?' do
    it 'returns true if we have seen the password within the sudo timeout' do
      session_model.password_seen_at = 5.minutes.ago
      expect(session_model.recently_seen_password?).to be true
    end

    it 'returns false if we have never seen the password' do
      expect(session_model.recently_seen_password?).to be false
    end

    it 'returns false if we last saw a password more than than sudo timeout' do
      session_model.password_seen_at = 15.minutes.ago
      expect(session_model.recently_seen_password?).to be false
    end
  end

  context '#two_factored?' do
    it 'returns true if there is a two factored time stamp' do
      session_model.two_factored_at = 15.minutes.ago
      expect(session_model.two_factored?).to be true
    end

    it 'returns false if there is no factored time stamp' do
      expect(session_model.two_factored?).to be false
    end
  end

  context '#first_session_for_browser?' do
    it 'returns true if there are no other sessions for the browser ID created before this one' do
      session_model.browser_id = SecureRandom.uuid
      session_model.save!
      expect(session_model.first_session_for_browser?).to be true
    end

    it 'returns false if there is another session for the browser ID before this one' do
      id = SecureRandom.uuid
      described_class.create!(user: user, active: true, browser_id: id)
      session_model.browser_id = id
      session_model.save!
      expect(session_model.first_session_for_browser?).to be false
    end
  end

  context '#first_session_for_ip?' do
    it 'returns true if there are no other sessions for the login IP address created before this one' do
      session_model.login_ip = '2.2.2.2'
      session_model.save!
      expect(session_model.first_session_for_ip?).to be true
    end

    it 'returns false if there is another session for the login IP address before this one' do
      ip = '2.2.2.2'
      described_class.create!(user: user, active: true, login_ip: ip)
      session_model.login_ip = ip
      session_model.save!
      expect(session_model.first_session_for_ip?).to be false
    end
  end

  context '#reset_token' do
    it 'sets a new token' do
      original_token = session_model.temporary_token
      session_model.reset_token
      expect(session_model.temporary_token).to_not eq original_token
    end

    it 'sets a new token hash' do
      token = session_model.reset_token
      expect(session_model.token_hash).to eq described_class.hash_token(token)
    end

    it 'saves the record to the database' do
      token = session_model.reset_token
      expect(described_class.find_by(token_hash: described_class.hash_token(token))).to eq session_model
    end
  end

  context '.find_session_by_token' do
    it 'returns nil if the given token is blank' do
      expect(described_class.find_session_by_token(nil)).to be nil
    end

    it 'returns a session if one exists' do
      session = described_class.create!
      expect(described_class.find_session_by_token(session.temporary_token)).to eq session
    end

    it 'returns nil if no session can be found with the given token' do
      expect(described_class.find_session_by_token('abcdef1234123123')).to be nil
    end
  end

  context '.cleanup' do
    it 'invalidates all sessions that have no had recently activity and are not persistent' do
      session1 = described_class.create!(last_activity_at:  10.months.ago, active: true)
      session2 = described_class.create!(last_activity_at:  5.minutes.ago, active: true)
      described_class.cleanup
      expect(session1.reload.active?).to be false
      expect(session2.reload.active?).to be true
    end

    it 'invalidates all sessions which have expired' do
      session1 = described_class.create!(expires_at: 10.months.ago, active: true)
      session2 = described_class.create!(expires_at: 5.minutes.from_now, active: true)
      described_class.cleanup
      expect(session1.reload.active?).to be false
      expect(session2.reload.active?).to be true
    end

    it 'dispatches an event before and after' do
      expect(Authie.config.events).to receive(:dispatch).with(:before_cleanup)
      expect(Authie.config.events).to receive(:dispatch).with(:after_cleanup)
      described_class.cleanup
    end
  end
end
