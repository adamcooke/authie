module Authie
  class Engine < ::Rails::Engine

    initializer 'authie.initialize' do |app|
      config.paths["db/migrate"].expanded.each do |expanded_path|
        app.config.paths["db/migrate"] << expanded_path
      end

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
