class AddTwoFactorAuthFieldsToAuthie < ActiveRecord::Migration
  def change
    add_column :authie_sessions, :two_factored_at, :datetime
    add_column :authie_sessions, :two_factored_ip, :string
    add_column :authie_sessions, :requests, :integer, :default => 0
    add_column :authie_sessions, :password_seen_at, :datetime
  end
end
