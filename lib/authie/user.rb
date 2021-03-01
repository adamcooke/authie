# frozen_string_literal: true

module Authie
  module User
    def self.included(base)
      base.has_many :user_sessions, class_name: 'Authie::Session', as: :user, dependent: :delete_all
    end
  end
end
