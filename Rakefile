# frozen_string_literal: true

task :default do
  $LOAD_PATH.unshift(File.expand_path('lib', __dir__))
  $LOAD_PATH.unshift(File.expand_path('test', __dir__))
  require 'test_helper'
  require 'tests/session_test'
  require 'tests/controller_delegate_test'
  require 'tests/controller_extension_test'
  require 'tests/events_test'
end
