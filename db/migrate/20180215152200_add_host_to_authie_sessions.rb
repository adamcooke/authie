class AddHostToAuthieSessions < ActiveRecord::Migration[4.2]
  def change
    add_column :authie_sessions, :host, :string
  end
end
