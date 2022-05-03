# frozen_string_literal: true

require 'spec_helper'
require 'authie/session'

RSpec.describe Authie::Session do
  subject(:browser_id) { SecureRandom.uuid }
  subject(:user) { User.create!(username: 'adam') }
  subject(:session_model) { Authie::SessionModel.create!(user: user, browser_id: browser_id) }
  subject(:controller) { make_controller { |c| c.send(:cookies)[:browser_id] = browser_id } }
  subject(:session) { described_class.new(controller, session_model) }
  subject(:set_cookies) { controller.send(:cookies).instance_variable_get('@set_cookies') }

  describe '#validate' do
    it 'raises an error if the browser ID does not match' do
      controller.send(:cookies)[:browser_id] = 'invalid'
      expect { session.validate }.to raise_error Authie::Session::BrowserMismatch
    end

    it 'dispatches an event if the browser ID does not match' do
      controller.send(:cookies)[:browser_id] = 'invalid'
      expect(Authie.config.events).to receive(:dispatch).with(:browser_id_mismatch_error, session)
      begin
        session.validate
      rescue StandardError
        nil
      end
    end

    it 'raises an error if the session is not valid' do
      session_model.update!(active: false)
      expect { session.validate }.to raise_error Authie::Session::InactiveSession
    end

    it 'dispatches an event if the session is not valid' do
      session_model.update!(active: false)
      expect(Authie.config.events).to receive(:dispatch).with(:invalid_session_error, session)
      begin
        session.validate
      rescue StandardError
        nil
      end
    end

    it 'raises an error if the session has expired' do
      session_model.update!(expires_at: 5.minutes.ago)
      expect { session.validate }.to raise_error Authie::Session::ExpiredSession
    end

    it 'dispatches an event if the session has expired' do
      session_model.update!(expires_at: 5.minutes.ago)
      expect(Authie.config.events).to receive(:dispatch).with(:expired_session_error, session)
      begin
        session.validate
      rescue StandardError
        nil
      end
    end

    it 'raises an error if the session is inactive' do
      session_model.update!(last_activity_at: 13.hours.ago, active: true)
      expect { session.validate }.to raise_error Authie::Session::InactiveSession
    end

    it 'dispatches an event if the session is inactive' do
      session_model.update!(last_activity_at: 13.hours.ago, active: true)
      expect(Authie.config.events).to receive(:dispatch).with(:inactive_session_error, session)
      begin
        session.validate
      rescue StandardError
        nil
      end
    end

    it 'raises an error if the hostname does not match the session' do
      session_model.update!(host: 'example.com')
      expect { session.validate }.to raise_error Authie::Session::HostMismatch
    end

    it 'returns true if the session is OK' do
      session_model.update!(host: 'example.com')
      controller.request.headers['Host'] = 'example.com'
      expect(session.validate).to eq session
    end
  end

  describe '#persist' do
    it 'sets the expired time on the session' do
      expect(session_model.expires_at).to be nil
      session.persist
      expect(session_model.expires_at).to be_a Time
    end

    it 'sets the cookie to include the new expiry time' do
      session.start
      expect(set_cookies['user_session'][:expires]).to be nil
      session.persist
      expect(set_cookies['user_session'][:expires]).to be_a Time
      expect(set_cookies['user_session'][:expires]).to eq session_model.expires_at
    end
  end

  describe '#invalidate' do
    it 'invalidates the session' do
      expect(session_model.active?).to be true
      session.invalidate
      expect(session_model.active?).to be false
    end

    it 'deletes the cookie' do
      expect(session_model.active?).to be true
      session.start
      expect(controller.send(:cookies)['user_session']).to eq session_model.temporary_token
      session.invalidate
      expect(controller.send(:cookies)['user_session']).to be nil
    end
  end

  describe '#touch' do
    it 'not call the validate method as it previously did' do
      expect(session).to_not receive(:validate)
      session.touch
    end

    it 'sets the last activity IP' do
      allow(controller.request).to receive(:ip).and_return('1.2.3.4')
      session.touch
      expect(session.last_activity_ip).to eq '1.2.3.4'
    end

    it 'sets the last activity path' do
      allow(controller.request).to receive(:path).and_return('/blah/blah')
      session.touch
      expect(session.last_activity_path).to eq '/blah/blah'
    end

    it 'sets the last activity time' do
      time = Time.new(2022, 3, 2, 12, 32, 22)
      Timecop.freeze(time) do
        session.touch
        expect(session.last_activity_at).to eq time
      end
    end

    it 'increments the request counter' do
      4.times do |i|
        session.touch
        expect(session.requests).to eq i + 1
      end
    end

    it 'dispatches an event' do
      expect(Authie.config.events).to receive(:dispatch).with(:session_touched, session)
      session.touch
    end

    context 'when session expiry extension is not enabled' do
      subject(:session_model) do
        Authie::SessionModel.create!(user: user, browser_id: browser_id, expires_at: 4.hours.from_now)
      end

      before { allow(Authie.config).to receive(:extend_session_expiry_on_touch).and_return(false) }

      it 'does not extend the expiry date on the session' do
        original_time = session_model.expires_at
        Timecop.freeze(original_time + 10.hours) { session.touch }
        session.session.reload
        expect(session.expires_at.to_i).to eq original_time.to_i
      end

      it 'does not set the expiry time' do
        expect(session.session).to_not receive(:expires_at=)
        session.touch
      end

      it 'does not update the cookie' do
        expect(session).to_not receive(:set_cookie)
        session.touch
      end
    end

    context 'when session expiry extension is enabled' do
      subject(:session_model) do
        Authie::SessionModel.create!(user: user, browser_id: browser_id, expires_at: Time.now)
      end

      before { allow(Authie.config).to receive(:extend_session_expiry_on_touch).and_return(true) }

      it 'does not set the expiry time' do
        expect(session.session).to receive(:expires_at=).and_call_original
        session.touch
      end

      it 'extends the expiry date on the session' do
        time = session_model.created_at
        Timecop.freeze(time) { session.touch }
        session.session.reload
        expect(session.expires_at.to_i).to eq (time + Authie.config.persistent_session_length).to_i
      end

      it 'updates the cookie' do
        time = session_model.created_at
        Timecop.freeze(time) { session.touch }
        expect(set_cookies['user_session'][:expires]).to eq time + Authie.config.persistent_session_length
      end
    end
  end

  describe '#see_password' do
    it 'sets the password seen at time' do
      time = Time.new(2022, 3, 2, 12, 32, 22)
      Timecop.freeze(time) do
        session.see_password
        expect(session.password_seen_at).to eq time
      end
    end

    it 'dispatches an event' do
      expect(Authie.config.events).to receive(:dispatch).with(:seen_password, session)
      session.see_password
    end
  end

  describe '#mark_as_two_factored' do
    it 'sets the two factored time' do
      time = Time.new(2022, 3, 2, 12, 32, 22)
      Timecop.freeze(time) do
        session.mark_as_two_factored
        expect(session.two_factored_at).to eq time
      end
    end

    it 'sets the ip address' do
      allow(controller.request).to receive(:ip).and_return('1.2.3.4')
      session.mark_as_two_factored
      expect(session.two_factored_ip).to eq '1.2.3.4'
    end

    it 'it dispatched an event' do
      expect(Authie.config.events).to receive(:dispatch).with(:marked_as_two_factor, session)
      session.mark_as_two_factored
    end

    it 'can set the skip two factor boolean to true if provided' do
      session.mark_as_two_factored(skip: true)
      expect(session.skip_two_factor?).to eq true
    end

    it 'can set the skip two factor boolean to false if provided' do
      session.update!(skip_two_factor: true) # default is false, set to true to check it does actually change
      session.mark_as_two_factored(skip: false)
      expect(session.skip_two_factor?).to eq false
    end

    it 'does not override the two factor boolean if not provided' do
      session.update!(skip_two_factor: true)
      session.mark_as_two_factored
      expect(session.skip_two_factor?).to eq true
    end
  end

  describe '#reset_token' do
    it 'sets a new token on the session' do
      expect(session.session).to receive(:reset_token)
      session.reset_token
    end

    it 'updates the cookie' do
      original_cookie_value = controller.send(:cookies)[:user_session]
      session.reset_token
      expect(controller.send(:cookies)[:user_session]).to_not eq original_cookie_value
      expect(controller.send(:cookies)[:user_session]).to eq session.temporary_token
    end

    it 'returns itself' do
      expect(session.reset_token).to be session
    end
  end

  describe '.start' do
    it 'creates a new session with details from the request' do
      time = Time.new(2022, 3, 4, 2, 31, 22)
      allow(controller.request).to receive(:ip).and_return('1.2.3.4')
      Timecop.freeze(time) do
        session = described_class.start(controller, user: user)
        expect(session).to be_a Authie::Session
        expect(session.session.user).to eq user
        expect(session.session.browser_id).to eq browser_id
        expect(session.session.login_at).to eq time
        expect(session.session.login_ip).to eq '1.2.3.4'
        expect(session.session.host).to eq 'test.host'
        expect(session.session.user_agent).to eq 'Rails Testing'
      end
    end

    it 'invalidates all other sessions for the same browser' do
      existing_session = Authie::SessionModel.create!(user: user, active: true, browser_id: browser_id)
      described_class.start(controller, user: user)
      expect(existing_session.reload.active?).to be false
    end

    it 'allows persistent sessions to be created' do
      time = Time.new(2022, 3, 4, 2, 31, 22)
      Timecop.freeze(time) do
        session = described_class.start(controller, user: user, persistent: true)
        expect(session.persistent?).to be true
        expect(session.expires_at).to eq time + 2.months
      end
    end

    it 'allows password to be seen' do
      time = Time.new(2022, 3, 4, 2, 31, 22)
      Timecop.freeze(time) do
        session = described_class.start(controller, user: user, see_password: true)
        expect(session.password_seen_at).to eq time
      end
    end
  end

  describe '.get_session' do
    it 'returns nil if there is no user session cookie' do
      expect(described_class.get_session(controller)).to be nil
    end

    it 'returns nil if there is no session matching the value in the cookie' do
      controller.send(:cookies)[:user_session] = 'invalid'
      expect(described_class.get_session(controller)).to be nil
    end

    it 'returns a session object if a session is found' do
      controller.send(:cookies)[:user_session] = session_model.temporary_token
      expect(described_class.get_session(controller)).to be_a Authie::Session
      expect(described_class.get_session(controller).session).to eq session_model
    end

    it 'sets the temporary token on the underlying session' do
      controller.send(:cookies)[:user_session] = session_model.temporary_token
      expect(described_class.get_session(controller).session.temporary_token).to eq session_model.temporary_token
    end
  end
end
