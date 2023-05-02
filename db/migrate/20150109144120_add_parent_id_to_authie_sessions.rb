# frozen_string_literal: true

class AddParentIdToAuthieSessions < ActiveRecord::Migration[6.1]
  def change
    add_column :authie_sessions, :parent_id, :bigint
  end
end
