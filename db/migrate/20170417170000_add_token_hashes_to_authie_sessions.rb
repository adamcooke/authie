# frozen_string_literal: true

class AddTokenHashesToAuthieSessions < ActiveRecord::Migration[4.2]
  def change
    add_column :authie_sessions, :token_hash, :string
  end
end
