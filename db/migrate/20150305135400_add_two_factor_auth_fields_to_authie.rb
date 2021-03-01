# frozen_string_literal: true

class AddTwoFactorAuthFieldsToAuthie < ActiveRecord::Migration[4.2]
  def change
    add_column :authie_sessions, :two_factored_at, :datetime
    add_column :authie_sessions, :two_factored_ip, :string
    add_column :authie_sessions, :requests, :integer, default: 0
    add_column :authie_sessions, :password_seen_at, :datetime
  end
end
