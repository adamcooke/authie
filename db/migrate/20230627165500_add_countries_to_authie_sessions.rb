# frozen_string_literal: true

class AddCountriesToAuthieSessions < ActiveRecord::Migration[6.1]
  def change
    add_column :authie_sessions, :login_ip_country, :string
    add_column :authie_sessions, :two_factored_ip_country, :string
    add_column :authie_sessions, :last_activity_ip_country, :string
  end
end
