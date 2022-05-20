# frozen_string_literal: true

require 'spec_helper'
require 'authie/controller_delegate'
require 'action_controller'
require 'action_controller/test_case'

RSpec.describe Authie::ControllerDelegate do
  subject(:controller) { make_controller }
  subject(:delegate) { described_class.new(controller) }

  context 'when a user is logged in' do
    subject(:user) { User.create!(username: 'adam') }
    before { delegate.create_auth_session(user) }

    describe '#current_user' do
      it 'returns the current user' do
        expect(delegate.current_user).to eq user
      end
    end

    describe '#logged_in' do
      it 'returns true' do
        expect(delegate.logged_in?).to be true
      end
    end

    describe '#invalidate_auth_session' do
      it 'retuns true' do
        expect(delegate.invalidate_auth_session).to be true
      end

      it 'invalidates the session' do
        expect(delegate.auth_session).to receive(:invalidate).and_call_original
        delegate.invalidate_auth_session
      end

      it 'removes the cached session immediately' do
        expect(delegate.instance_variable_get('@auth_session')).to be_a Authie::Session
        delegate.invalidate_auth_session
        expect(delegate.instance_variable_get('@auth_session')).to be nil
      end
    end

    describe '#touch_auth_session' do
      it 'will call the touch method on the underlying' do
        expect(delegate.auth_session).to receive(:touch)
        delegate.touch_auth_session
      end

      it 'will call a block before running touch' do
        count = 0
        delegate.touch_auth_session { count += 1 }
        expect(count).to eq 1
      end

      it 'will return the return value of the executed block' do
        expect(delegate.touch_auth_session { 1234 }).to eq 1234
      end

      it 'will not touch the session if disabled' do
        delegate.touch_auth_session_enabled = false
        expect(delegate.auth_session).to_not receive(:touch)
        delegate.touch_auth_session
      end
    end
  end

  context 'when a user is not logged in' do
    describe '#current_user' do
      it 'returns nil if nobody is logged in' do
        expect(delegate.current_user).to be nil
      end
    end

    describe '#logged_in' do
      it 'returns false' do
        expect(delegate.logged_in?).to be false
      end
    end

    describe '#invalidate_auth_session' do
      it 'does nothing' do
        expect(delegate.invalidate_auth_session).to be false
      end
    end

    describe '#touch_auth_session' do
      it 'will execute the block and return the value' do
        expect(delegate.touch_auth_session { 'abcdef' }).to eq 'abcdef'
      end
    end
  end

  describe '#set_browser_id' do
    subject(:set_cookies) { controller.send(:cookies).instance_variable_get('@set_cookies') }

    it 'sets a unique browser ID into the cookie' do
      new_browser_id = delegate.set_browser_id
      expect(new_browser_id).to match(/\A[a-f0-9-]{36}\z/)
      expect(controller.send(:cookies)[:browser_id]).to eq new_browser_id
    end

    it 'sets the cookie as httponly' do
      delegate.set_browser_id
      expect(set_cookies['browser_id'][:httponly]).to be true
    end

    it 'sets the cookie as secure if the request is SSL' do
      allow(controller.request).to receive(:ssl?).and_return true
      delegate.set_browser_id
      expect(set_cookies['browser_id'][:secure]).to be true
    end

    it 'sets the cookie with a long expiry time' do
      time = Time.new(2022, 3, 2, 20, 22, 33)
      Timecop.freeze(time) { delegate.set_browser_id }
      expect(set_cookies['browser_id'][:expires]).to eq time + 5.years
    end

    it 'does not use brower IDs that already exist' do
      existing_session = Authie::SessionModel.create!(browser_id: SecureRandom.uuid)
      allow(SecureRandom).to receive(:uuid).and_return(existing_session.browser_id, SecureRandom.uuid)
      expect(delegate.set_browser_id).to_not eq existing_session.browser_id
    end

    it 'dispatches an event' do
      expect(Authie).to receive(:notify).with(:set_browser_id, hash_including(browser_id: /\A[a-f0-9-]{36}\z/))
      delegate.set_browser_id
    end
  end

  describe '#auth_session' do
    it 'returns the value from the Authie::Session.get_session method' do
      allow(Authie::Session).to receive(:get_session).and_return(1234)
      expect(delegate.auth_session).to eq 1234
    end

    it 'retuns a cached value if one exists' do
      delegate.instance_variable_set('@auth_session', 9876)
      expect(delegate.auth_session).to eq 9876
    end
  end

  describe '#create_auth_session' do
    context 'when a user is provided' do
      it 'creates a new auth session' do
        user = User.create!(username: 'adam')
        session = delegate.create_auth_session(user)
        expect(session).to be_a Authie::Session
        expect(session.user).to eq user
        expect(controller.send(:cookies)[:user_session]).to eq session.temporary_token
      end

      it 'can receive other options for the session too' do
        expiry_time = 6.months.from_now
        user = User.create!(username: 'adam')
        session = delegate.create_auth_session(user, expires_at: expiry_time)
        expect(session).to be_a Authie::Session
        expect(session.persistent?).to be true
        expect(session.expires_at).to eq expiry_time
      end
    end

    context 'when nil is provided' do
      context 'when no user is logged in' do
        it 'will return none' do
          expect(delegate.create_auth_session(nil)).to eq nil
        end
      end

      context 'when a user is logged in' do
        it 'will invalidate their existing session' do
          allow(delegate).to receive(:logged_in?).and_return(true)
          expect(delegate.auth_session).to receive(:invalidate).and_return(true)
          expect(delegate.create_auth_session(nil)).to be nil
        end
      end
    end
  end
end
