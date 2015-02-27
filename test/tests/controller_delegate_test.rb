require 'authie/controller_delegate'

class ControllerDelegateTest < Minitest::Test

  def setup
    @controller = FakeController.new
    @delegate = Authie::ControllerDelegate.new(@controller)
  end

  def test_users_can_be_logged_in
    # Test nobody is logged in by default
    assert_equal false, @delegate.logged_in?
    # Create a user and log them in
    user = User.create(:username => 'tester')
    @delegate.current_user = user
    # Test that we're now logged in
    assert_equal true, @delegate.logged_in?
    assert_equal user, @delegate.current_user
    assert_equal Authie::Session, @delegate.auth_session.class
  end

  def test_browser_id_can_be_set
    # Test that there's no browser ID to begin
    assert_equal nil, @controller.cookies[:browser_id]
    # Set the browser ID
    @delegate.set_browser_id
    # Test the browser ID looks like a UUID
    assert @controller.cookies[:browser_id] =~ /\A[a-f0-9\-]{36}\z/
  end

  def test_touching_auth_sessions
    @delegate.current_user = User.create(:username => 'dave')
    assert_equal nil, @delegate.auth_session.last_activity_at
    @delegate.touch_auth_session
    assert_equal Time, @delegate.auth_session.last_activity_at.class
    assert_equal '127.0.0.1', @delegate.auth_session.last_activity_ip
  end

  def test_touching_auth_sessions_raises_errors
    @delegate.current_user = User.create(:username => 'dave')
    assert @delegate.auth_session.invalidate!
    assert_raises Authie::Session::InactiveSession do
      @delegate.touch_auth_session
    end
  end

end
