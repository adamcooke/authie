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

  describe '#ip_lookup_method' do
    it 'returns the default value' do
      expect(config.ip_lookup_method).to eq :ip
    end

    it 'returns an overriden value' do
      config.ip_lookup_method = :remote_ip
      expect(config.ip_lookup_method).to eq :remote_ip
    end
  end

  describe '#resolve_ip' do
    let(:request) do
      double('request', remote_ip: '1.2.3.4', ip: '5.6.7.8', custom_ip: '9.10.11.12')
    end

    it 'returns remote_ip when ip_lookup_method is :remote_ip' do
      config.ip_lookup_method = :remote_ip
      expect(config.resolve_ip(request)).to eq '1.2.3.4'
    end

    it 'returns ip when ip_lookup_method is :ip' do
      config.ip_lookup_method = :ip
      expect(config.resolve_ip(request)).to eq '5.6.7.8'
    end

    it 'calls any method name on the request object' do
      config.ip_lookup_method = :custom_ip
      expect(config.resolve_ip(request)).to eq '9.10.11.12'
    end

    it 'calls a proc with the request object' do
      config.ip_lookup_method = ->(req) { req.remote_ip.reverse }
      expect(config.resolve_ip(request)).to eq '4.3.2.1'
    end
  end

  describe '#lookup_ip_country' do
    it 'returns nil when no backend is configured' do
      expect(config.lookup_ip_country('1.2.3.4')).to be_nil
    end

    it 'calls the backend when configured' do
      config.lookup_ip_country_backend = ->(ip) { "Country:#{ip}" }
      expect(config.lookup_ip_country('1.2.3.4')).to eq 'Country:1.2.3.4'
    end
  end
end
