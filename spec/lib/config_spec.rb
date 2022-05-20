# frozen_string_literal: true

require 'spec_helper'
require 'authie/config'

RSpec.describe Authie::Config do
  subject(:config) { described_class.new }

  after do
    Authie.instance_variable_set('@config', nil)
  end

  describe Authie do
    describe '.config' do
      it 'returns a config instance' do
        expect(described_class.config).to be_a Authie::Config
      end
    end

    describe '.configure' do
      it 'yields a block with the configuration object' do
        described_class.configure { |c| c.session_inactivity_timeout = 5.minutes }
        expect(described_class.config.session_inactivity_timeout).to eq 5.minutes
      end
    end
  end

  describe '#session_inactivity_timeout' do
    it 'returns the default value' do
      expect(config.session_inactivity_timeout).to eq 12.hours
    end

    it 'returns an overriden value' do
      config.session_inactivity_timeout = 24.hours
      expect(config.session_inactivity_timeout).to eq 24.hours
    end
  end

  describe '#persistent_session_length' do
    it 'returns the default value' do
      expect(config.persistent_session_length).to eq 2.months
    end

    it 'returns an overriden value' do
      config.persistent_session_length = 12.months
      expect(config.persistent_session_length).to eq 12.months
    end
  end

  describe '#sudo_session_timeout' do
    it 'returns the default value' do
      expect(config.sudo_session_timeout).to eq 10.minutes
    end

    it 'returns an overriden value' do
      config.sudo_session_timeout = 1.hour
      expect(config.sudo_session_timeout).to eq 1.hour
    end
  end

  describe '#browser_id_cookie_name' do
    it 'returns the default value' do
      expect(config.browser_id_cookie_name).to eq :browser_id
    end

    it 'returns an overriden value' do
      config.browser_id_cookie_name = :auth_browser_id
      expect(config.browser_id_cookie_name).to eq :auth_browser_id
    end
  end
end
