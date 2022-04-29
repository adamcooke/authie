# frozen_string_literal: true

ActiveRecord::Migration.create_table :users do |t|
  t.string :username
end

require 'authie/user'

class User < ActiveRecord::Base
  include Authie::User
end
