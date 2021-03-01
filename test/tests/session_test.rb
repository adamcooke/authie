# frozen_string_literal: true

require 'authie/session'

class SessionTest < Minitest::Test
  def test_session_can_be_started
    controller = FakeController.new
    # Test session can be started
    assert session = Authie::Session.start(controller)
    # Test that session is persisted
    assert session.persisted?
    # Test that login details are set
    assert_equal Time, session.login_at.class
    assert_equal '127.0.0.1', session.login_ip
    # Test the user agent is set
    assert_equal 'TestSuite', session.user_agent
    # Test newly created sessions are active
    assert_equal true, session.active?
    # Test newly created sessions are not persisted
    assert_equal false, session.persistent?
    # Test that the login cookie is set in cookies
    assert_equal session.token_hash, Authie::Session.hash_token(controller.cookies[:user_session])
  end

  def test_sessions_can_be_retreived_from_controller
    controller = FakeController.new
    # Make a session to get an ID
    assert session = Authie::Session.start(controller)
    # Check we can retrived it
    assert_equal session, Authie::Session.get_session(controller)
  end

  def test_using_a_session_from_another_browser_fails
    controller = FakeController.new(browser_id: 'old')
    # Make a new session
    assert session = Authie::Session.start(controller)
    # Make a new controller/browser session with a new browser ID
    other_controller = FakeController.new(browser_id: 'new')
    # Load the session ID into the new controller to simulate someone
    # stealing the cookie into a new browser
    other_controller.cookies[:user_session] = session.temporary_token
    assert new_session = Authie::Session.get_session(other_controller)
    # Test that the security check raises an error
    assert_raises Authie::Session::BrowserMismatch do
      new_session.check_security!
    end
    # Test the new session has been invalidated
    assert_equal false, new_session.active?
  end

  def test_new_cookie_is_written_when_persisting
    controller = FakeController.new
    # Test session can be started
    assert session = Authie::Session.start(controller)
    # Test newly created sessions are not persisted
    assert_equal false, session.persistent?
    assert_nil controller.cookies.expiry_for(:user_session)
    assert_equal session.token_hash, Authie::Session.hash_token(controller.cookies[:user_session])
    # Persist
    session.persist!
    # Check the new cookie is suitable
    assert controller.cookies.expiry_for(:user_session).is_a?(Time)
    assert_equal session.token_hash, Authie::Session.hash_token(controller.cookies[:user_session])
  end

  def test_the_raw_token_is_available_when_looked_up
    controller = FakeController.new
    # Put a session into our controller
    original_session = Authie::Session.start(controller)
    assert controller.cookies[:user_session].is_a?(String)
    assert_equal 44, controller.cookies[:user_session].size
    # Get it back out again
    session = Authie::Session.get_session(controller)
    assert session.temporary_token.is_a?(String)
    assert_equal original_session.temporary_token, session.temporary_token
  end

  def test_using_inactive_sessions_fails
    controller = FakeController.new
    # Make a session
    assert session = Authie::Session.start(controller)
    # Invalidate the session
    assert session.invalidate!
    assert_equal false, session.active?
    # Test that the security check raises an appropriate error
    assert_raises Authie::Session::InactiveSession do
      session.check_security!
    end
  end

  def test_using_persistent_token_after_expiry_fails
    controller = FakeController.new
    # Make a session
    assert session = Authie::Session.start(controller)
    # Mark as persistent
    assert session.persist!
    # Expire the token
    assert session.update(expires_at: 10.minutes.ago)
    # Test that the security check raises an appropriate error
    assert_raises Authie::Session::ExpiredSession do
      session.check_security!
    end
  end

  def test_using_inactive_session_fails
    controller = FakeController.new
    # Make a session
    assert session = Authie::Session.start(controller)
    # Don't use the session for an hour
    assert session.update(last_activity_at: (Authie.config.session_inactivity_timeout + 1.minute).ago)
    # Test that the security check raises an appropriate error
    assert_raises Authie::Session::InactiveSession do
      session.check_security!
    end
  end

  def test_using_session_from_another_host_fails
    # Make a session
    controller = FakeController.new(host: 'host1.example.com')
    assert session = Authie::Session.start(controller)
    # Check the session from another controller
    controller = FakeController.new(host: 'host2.example.com', browser_id: session.browser_id,
                                    user_session: session.temporary_token)
    assert session = Authie::Session.get_session(controller)
    assert_raises Authie::Session::HostMismatch do
      session.check_security!
    end
  end

  def test_sessions_are_expired
    controller = FakeController.new
    # Make a session
    assert session = Authie::Session.start(controller)
    # Don't use the session for an hour
    assert session.update(expires_at: 10.minutes.ago)
    assert_equal true, session.expired?
  end

  def test_sessions_are_inactive
    controller = FakeController.new
    # Make a session
    assert session = Authie::Session.start(controller)
    # Don't use the session for an hour
    assert session.update(last_activity_at: (Authie.config.session_inactivity_timeout + 1.minute).ago)
    assert_equal true, session.inactive?
  end

  def test_cookie_properties_are_set
    controller = FakeController.new
    # Make a session
    assert session = Authie::Session.start(controller)
    # Test the values on the cookie
    assert_equal true, controller.cookies.raw[:user_session][:httponly]
    assert_equal true, controller.cookies.raw[:user_session][:secure]
    assert_equal session.token_hash, Authie::Session.hash_token(controller.cookies.raw[:user_session][:value])
    assert_nil controller.cookies.raw[:user_session][:expires]
  end

  def test_touching_sessions
    controller = FakeController.new
    # Make a session
    assert session = Authie::Session.start(controller)
    # Test sessions start without any activity
    assert_nil session.last_activity_at
    assert_nil session.last_activity_ip
    assert_nil session.last_activity_path
    # Test when sessions are touched, the last activity values are populated
    assert session.touch!
    assert_equal Time, session.last_activity_at.class
    assert_equal '127.0.0.1', session.last_activity_ip
    assert_equal '/demo', session.last_activity_path
  end

  def test_touching_sessions_while_invalid_raises_an_error
    controller = FakeController.new
    # Make a session
    assert session = Authie::Session.start(controller)
    # Test the session can be touched
    assert session.touch!
    # Invalidate the session
    session.invalidate!
    # Test that touching the session causes an error to be
    # raised about the inactive session.
    assert_raises Authie::Session::InactiveSession do
      session.touch!
    end
  end

  def test_sessions_can_have_arbitary_data_stored_within
    controller = FakeController.new
    # Make a session
    assert session = Authie::Session.start(controller)
    # Test there's no data to start with
    assert_nil session.get(:hello)
    # Test setting data returns the set value
    assert session.set(:hello, 'world')
    # Test retriving the data from the current instance
    assert_equal 'world', session.get(:hello)
    # Test retriving the data from a newly instanticated instance
    new_session = Authie::Session.get_session(controller)
    assert_equal 'world', new_session.get(:hello)
  end

  def test_cookie_is_removed_from_controller_when_session_is_destroyed
    controller = FakeController.new
    # Make a session
    assert session = Authie::Session.start(controller)
    # Test that is exists to begin with
    assert controller.cookies[:user_session]
    # Remove the session
    assert session.destroy
    # Test that it no longer exists
    assert_nil controller.cookies[:user_session]
  end

  def test_sessions_can_be_associated_with_users
    user = User.create(username: 'tester')
    controller = FakeController.new
    # Make a session
    assert session = Authie::Session.start(controller, user: user)
    # Test that the user is set
    assert_equal user, session.user
    # Test the user has the session associated
    assert_equal 1, user.sessions.count
    assert_equal session, user.sessions.first
  end

  def test_request_count_increments_on_touch
    controller = FakeController.new
    assert session = Authie::Session.start(controller)
    # Test we start with no rrequests
    assert_equal 0, session.requests
    assert session.touch!
    assert_equal 1, session.requests
    assert session.touch!
    assert_equal 2, session.requests
  end

  def test_sessions_can_invalidate_all_other_sessions_for_a_user
    user = User.create(username: 'tester')
    # Make some sessions for a new in lots of controllers
    assert session1 = Authie::Session.start(FakeController.new(browser_id: 'b1'), user: user)
    assert session2 = Authie::Session.start(FakeController.new(browser_id: 'b2'), user: user)
    assert session3 = Authie::Session.start(FakeController.new(browser_id: 'b3'), user: user)
    # Reload all the sessions
    session1.reload
    session2.reload
    session3.reload
    # Test they're all active
    assert_equal true, session1.active?
    assert_equal true, session2.active?
    assert_equal true, session3.active?
    # Test that invalidating all sessions for a given session invalidates all
    # but the current session
    assert session1.invalidate_others!
    session1.reload
    session2.reload
    session3.reload
    assert_equal true, session1.active?
    assert_equal false, session2.active?
    assert_equal false, session3.active?
  end

  def test_sudo_functions!
    user = User.create(username: 'tester')
    controller = FakeController.new
    # Make a session
    assert session = Authie::Session.start(controller, user: user)
    assert_nil session.password_seen_at
    assert_equal false, session.recently_seen_password?
    # Test that you can mark as password as seen
    assert session.see_password!
    assert_equal Time, session.password_seen_at.class
    assert_equal true, session.recently_seen_password?
    # Test that older passwords are not seen recently
    session.update!(password_seen_at: 2.hours.ago)
    assert_equal false, session.recently_seen_password?
  end

  def test_two_factor_functions
    user = User.create(username: 'tester')
    controller = FakeController.new
    assert session = Authie::Session.start(controller, user: user)
    # Test that the session isn't two factored
    assert_equal false, session.two_factored?
    # Mark the session has two-factored
    assert session.mark_as_two_factored!
    # Test that the session is now marked as two factored
    assert_equal true, session.two_factored?
    assert_equal Time, session.two_factored_at.class
    assert_equal '127.0.0.1', session.two_factored_ip
  end

  def test_user_impersonation
    user1 = User.create(username: 'tester1')
    user2 = User.create(username: 'tester2')
    controller = FakeController.new
    # Make a new session for the original user
    assert session = Authie::Session.start(controller, user: user1)
    # Impersonate a user and test that a new session is returned
    assert new_session = session.impersonate!(user2)
    assert_equal Authie::Session, new_session.class
    assert_equal session, new_session.parent
    assert_equal user2, new_session.user
    # Test that the controller's session cookie is the new session
    assert_equal new_session.token_hash, Authie::Session.hash_token(controller.cookies[:user_session])
    # Test reverting to the parent controller
    new_session.reload
    assert original_session = new_session.revert_to_parent!
    assert_equal original_session, session
    assert_equal session.token_hash, Authie::Session.hash_token(controller.cookies[:user_session])
    assert_equal user1, original_session.user
  end

  def test_first_session_for_browser
    user = User.create(username: 'tester1')
    controller = FakeController.new(browser_id: 'browser1')
    assert session = Authie::Session.start(controller, user: user)
    assert_equal session.first_session_for_browser?, true
    assert session = Authie::Session.start(controller, user: user)
    assert_equal session.first_session_for_browser?, false
  end

  def test_first_session_for_ip
    user = User.create(username: 'tester1')
    controller = FakeController.new(browser_id: 'browser1')
    assert session = Authie::Session.start(controller, user: user)
    assert_equal session.first_session_for_ip?, true
    assert session = Authie::Session.start(controller, user: user)
    assert_equal session.first_session_for_ip?, false
  end
end
