# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authie::User do
  subject(:user) { User.create!(username: 'adam') }

  describe '#user_sessions' do
    it 'returns sessions belonging to the user' do
      session = Authie::SessionModel.create!(user: user)
      expect(user.user_sessions).to eq [session]
    end

    it 'deletes all sessions when the user is deleted' do
      session = Authie::SessionModel.create!(user: user)
      user.destroy!
      expect { session.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
