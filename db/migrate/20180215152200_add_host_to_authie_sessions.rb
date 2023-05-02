# frozen_string_literal: true

class AddHostToAuthieSessions < ActiveRecord::Migration[6.1]
  def change
    add_column :authie_sessions, :host, :string
  end
end
