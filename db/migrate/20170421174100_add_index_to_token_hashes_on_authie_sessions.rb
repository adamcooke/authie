# frozen_string_literal: true

class AddIndexToTokenHashesOnAuthieSessions < ActiveRecord::Migration[6.1]
  def change
    add_index :authie_sessions, :token_hash, length: 10
  end
end
