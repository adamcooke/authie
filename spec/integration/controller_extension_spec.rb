# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PagesController, type: :controller do
  it 'sets a browser ID is set on every page request' do
    get :index
    expect(cookies[:browser_id]).to match(/\A[a-f0-9-]{36}\z/)
    expect(response.body).to eq 'Hello world!'
  end

  it 'can access the current user' do
    setup_session
    get :authenticated
    expect(response.body).to eq 'Hello adam!'
  end

  it 'can check logged in state' do
    get :logged_in
    expect(response.body).to eq 'Not logged in'
  end

  it 'can check logged in state' do
    setup_session
    get :logged_in
    expect(response.body).to eq 'Logged in'
  end

  it 'touches the session on each page request' do
    setup_session
    3.times do |i|
      get :request_count
      expect(response.body).to eq "Count: #{i}"
    end
  end

  it 'touches the session even if there is an error' do
    session = setup_session
    time = Time.new(2022, 2, 4, 2, 11)
    Timecop.freeze(time) do
      expect { get :error }.to raise_error ZeroDivisionError
    end
    session.reload
    expect(session.last_activity_path).to eq '/error'
    expect(session.last_activity_at).to eq time
  end

  it 'raises an error if the browser ID mismatches' do
    setup_session { |s| s.browser_id = 'abc' }
    expect { get(:authenticated) }.to raise_error Authie::Session::BrowserMismatch
  end

  it 'raises an error if the session has expired' do
    setup_session { |s| s.expires_at = 2.week.ago }
    expect { get(:authenticated) }.to raise_error Authie::Session::ExpiredSession
  end

  it 'raises an error if the session has become inactive' do
    setup_session { |s| s.last_activity_at = 2.week.ago }
    expect { get(:authenticated) }.to raise_error Authie::Session::InactiveSession
  end

  it 'raises an error if the host is not the same' do
    setup_session { |s| s.host = 'example.com' }
    expect { get(:authenticated) }.to raise_error Authie::Session::HostMismatch
  end

  def setup_session
    browser_id = SecureRandom.uuid
    user = User.create!(username: 'adam')
    session = Authie::SessionModel.create!(user: user, browser_id: browser_id, active: true)
    if block_given?
      yield(session)
      session.save!
    end
    cookies[:browser_id] = browser_id
    cookies[:user_session] = session.temporary_token
    session
  end
end
