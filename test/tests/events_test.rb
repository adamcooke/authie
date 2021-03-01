# frozen_string_literal: true

require 'authie/session'

class EventsTest < Minitest::Test
  def test_callbacks_are_executed
    session_via_callback = false
    callback = Authie.config.events.on(:start_session) { |s| session_via_callback = s }
    begin
      controller = FakeController.new
      session = Authie::Session.start(controller)
      assert_equal session, session_via_callback
    ensure
      Authie.config.events.remove(:start_session, callback)
    end
  end
end
