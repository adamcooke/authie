class AddIndexToTokenHashesOnAuthieSessions < ActiveRecord::Migration
  def change
    add_index :authie_sessions, :token_hash, :length => 10
  end
end
