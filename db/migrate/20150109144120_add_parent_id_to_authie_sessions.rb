# frozen_string_literal: true

class AddParentIdToAuthieSessions < ActiveRecord::Migration[4.2]
  def change
    add_column :authie_sessions, :parent_id, :integer
  end
end
