# frozen_string_literal: true

class AddTwoFactorRequiredToSessions < ActiveRecord::Migration[6.1]
  def change
    add_column :authie_sessions, :skip_two_factor, :boolean, default: false
  end
end
