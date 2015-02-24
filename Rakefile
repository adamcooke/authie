task :default do
  $LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))
  $LOAD_PATH.unshift(File.expand_path('../test', __FILE__))
  require 'test_helper'
  require 'tests/session_test'
  require 'tests/controller_delegate_test'
  require 'tests/controller_extension_test'
end
