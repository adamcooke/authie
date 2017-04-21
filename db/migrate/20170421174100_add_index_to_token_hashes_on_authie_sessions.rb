class AddIndexToTokenHashesOnAuthieSessions < ActiveRecord::Migration
  def change
    add_index :authie_sessions, :token_hash
  end
end
