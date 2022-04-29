# frozen_string_literal: true

require 'action_controller'
require 'action_controller/test_case'

module ControllerHelpers
  def make_controller
    controller_class = Class.new(ActionController::Base)
    controller = controller_class.new
    controller.set_request!(ActionController::TestRequest.create(controller_class))
    yield controller if block_given?
    controller
  end
end
