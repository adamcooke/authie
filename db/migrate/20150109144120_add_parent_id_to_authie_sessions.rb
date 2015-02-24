class AddParentIdToAuthieSessions < ActiveRecord::Migration
  def change
    add_column :authie_sessions, :parent_id, :integer
  end
end
