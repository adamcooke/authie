# frozen_string_literal: true

class PagesController < ApplicationController
  def index
    render plain: 'Hello world!'
  end

  def authenticated
    render plain: "Hello #{current_user.username}!"
  end

  def request_count
    render plain: "Count: #{auth_session.requests}"
  end

  def logged_in
    if logged_in?
      render plain: 'Logged in'
    else
      render plain: 'Not logged in'
    end
  end
end
