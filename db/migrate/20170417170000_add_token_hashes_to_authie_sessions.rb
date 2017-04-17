class AddTokenHashesToAuthieSessions < ActiveRecord::Migration
  def change
    add_column :authie_sessions, :token_hash, :string
  end
end
