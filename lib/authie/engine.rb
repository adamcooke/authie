module Authie
  class Engine < ::Rails::Engine

    engine_name 'authie'

    initializer 'authie.initialize' do |app|
      ActiveSupport.on_load :active_record do
        require 'authie/session'
      end

      ActiveSupport.on_load :action_controller do
        require 'authie/controller_extension'
        include Authie::ControllerExtension
      end

    end

  end
end
