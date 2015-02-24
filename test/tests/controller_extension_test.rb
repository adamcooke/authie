require 'authie/controller_extension'

class ExtendedController < FakeController

  def self.before_filters
    @before_filters ||= []
  end

  def self.before_filter(*names)
    names.each { |n| before_filters << n }
  end

  def self.helper_methods
    @helper_methods ||= []
  end

  def self.helper_method(*names)
    names.each { |n| helper_methods << n }
  end

  include Authie::ControllerExtension

end

class ControllerExtensionTest < Minitest::Test

  def setup
    @controller = ExtendedController.new
  end

  def test_the_delegate_is_added
    assert_equal Authie::ControllerDelegate, @controller.send(:auth_session_delegate).class
  end

  def test_before_filters_are_added
    assert @controller.class.before_filters.include?(:set_browser_id)
    assert @controller.class.before_filters.include?(:touch_auth_session)
  end

  def test_helper_methods_are_added
    assert @controller.class.helper_methods.include?(:logged_in?)
    assert @controller.class.helper_methods.include?(:current_user)
    assert @controller.class.helper_methods.include?(:auth_session)
  end

end
