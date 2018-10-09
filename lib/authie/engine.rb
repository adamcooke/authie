module Authie
  class Engine < ::Rails::Engine

    engine_name 'authie'

    config.autoload_paths += Dir["#{config.root}/lib/**/"]

    initializer 'authie.initialize' do |app|
      ActiveSupport.on_load :action_controller do
        require 'authie/controller_extension'
        include Authie::ControllerExtension
      end
    end

  end
end
