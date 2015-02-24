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
    assert_equal session.token, controller.cookies[:user_session]
  end

  def test_sessions_can_be_retreived_from_controller
    controller = FakeController.new
    # Make a session to get an ID
    assert session = Authie::Session.start(controller)
    # Check we can retrived it
    assert_equal session, Authie::Session.get_session(controller)
  end

  def test_using_a_session_from_another_browser_fails
    controller = FakeController.new(:browser_id => 'old')
    # Make a new session
    assert session = Authie::Session.start(controller)
    # Make a new controller/browser session with a new browser ID
    other_controller = FakeController.new(:browser_id => 'new')
    # Load the session ID into the new controller to simulate someone
    # stealing the cookie into a new browser
    other_controller.cookies[:user_session] = session.token
    assert new_session = Authie::Session.get_session(other_controller)
    # Test that the security check raises an error
    assert_raises Authie::Session::BrowserMismatch do
      new_session.check_security!
    end
    # Test the new session has been invalidated
    assert_equal false, new_session.active?
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
    assert session.update(:expires_at => 10.minutes.ago)
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
    assert session.update(:last_activity_at => (Authie.config.session_inactivity_timeout + 1.minute).ago)
    # Test that the security check raises an appropriate error
    assert_raises Authie::Session::InactiveSession do
      session.check_security!
    end
  end

  def test_cookie_properties_are_set
    controller = FakeController.new
    # Make a session
    assert session = Authie::Session.start(controller)
    # Test the values on the cookie
    assert_equal true, controller.cookies.raw[:user_session][:httponly]
    assert_equal true, controller.cookies.raw[:user_session][:secure]
    assert_equal session.token, controller.cookies.raw[:user_session][:value]
    assert_equal session.expires_at, controller.cookies.raw[:user_session][:expires]
  end

  def test_touching_sessions
    controller = FakeController.new
    # Make a session
    assert session = Authie::Session.start(controller)
    # Test sessions start without any activity
    assert_equal nil, session.last_activity_at
    assert_equal nil, session.last_activity_ip
    assert_equal nil, session.last_activity_path
    # Test when sessions are touched, the last activity values are populated
    assert session.touch!
    assert_equal Time, session.last_activity_at.class
    assert_equal "127.0.0.1", session.last_activity_ip
    assert_equal "/demo", session.last_activity_path
  end

  def test_sessions_can_have_arbitary_data_stored_within
    controller = FakeController.new
    # Make a session
    assert session = Authie::Session.start(controller)
    # Test there's no data to start with
    assert_equal nil, session.get(:hello)
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
    assert_equal nil, controller.cookies[:user_session]
  end

  def test_sessions_can_be_associated_with_users
    user = User.create(:username => 'tester')
    controller = FakeController.new
    # Make a session
    assert session = Authie::Session.start(controller, :user => user)
    # Test that the user is set
    assert_equal user, session.user
    # Test the user has the session associated
    assert_equal 1, user.sessions.count
    assert_equal session, user.sessions.first
  end

end
