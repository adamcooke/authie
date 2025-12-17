# frozen_string_literal: true

require 'spec_helper'
require 'authie/controller_extension'

RSpec.describe Authie::ControllerExtension do
  describe '.included' do
    let(:base_class) do
      Class.new do
        def self.before_action(*); end
        def self.around_action(*); end
        def self.delegate(*); end
      end
    end

    context 'when base lacks helper_method' do
      it 'includes without error' do
        expect { base_class.include(described_class) }.not_to raise_error
      end
    end

    context 'when base responds to helper_method' do
      before do
        base_class.define_singleton_method(:helper_method) { |*_args| nil }
        allow(base_class).to receive(:helper_method)
      end

      it 'registers helper methods' do
        base_class.include(described_class)
        expect(base_class).to have_received(:helper_method) do |*args|
          expect(args).to contain_exactly(:logged_in?, :current_user, :auth_session)
        end
      end
    end

    describe 'before_action registration' do
      before do
        allow(base_class).to receive(:before_action)
      end

      it 'registers set_browser_id and validate_auth_session' do
        base_class.include(described_class)
        expect(base_class).to have_received(:before_action) do |*args|
          expect(args).to contain_exactly(:set_browser_id, :validate_auth_session)
        end
      end
    end

    describe 'around_action registration' do
      before do
        allow(base_class).to receive(:around_action)
      end

      it 'registers touch_auth_session' do
        base_class.include(described_class)
        expect(base_class).to have_received(:around_action) do |*args|
          expect(args).to contain_exactly(:touch_auth_session)
        end
      end
    end

    describe 'delegate registration' do
      before do
        allow(base_class).to receive(:delegate)
      end

      it 'delegates set_browser_id to auth_session_delegate' do
        base_class.include(described_class)
        expect(base_class).to have_received(:delegate)
          .with(:set_browser_id, to: :auth_session_delegate)
      end

      it 'delegates validate_auth_session to auth_session_delegate' do
        base_class.include(described_class)
        expect(base_class).to have_received(:delegate)
          .with(:validate_auth_session, to: :auth_session_delegate)
      end

      it 'delegates touch_auth_session to auth_session_delegate' do
        base_class.include(described_class)
        expect(base_class).to have_received(:delegate)
          .with(:touch_auth_session, to: :auth_session_delegate)
      end

      it 'delegates current_user to auth_session_delegate' do
        base_class.include(described_class)
        expect(base_class).to have_received(:delegate)
          .with(:current_user, to: :auth_session_delegate)
      end

      it 'delegates create_auth_session to auth_session_delegate' do
        base_class.include(described_class)
        expect(base_class).to have_received(:delegate)
          .with(:create_auth_session, to: :auth_session_delegate)
      end

      it 'delegates invalidate_auth_session to auth_session_delegate' do
        base_class.include(described_class)
        expect(base_class).to have_received(:delegate)
          .with(:invalidate_auth_session, to: :auth_session_delegate)
      end

      it 'delegates logged_in? to auth_session_delegate' do
        base_class.include(described_class)
        expect(base_class).to have_received(:delegate)
          .with(:logged_in?, to: :auth_session_delegate)
      end

      it 'delegates auth_session to auth_session_delegate' do
        base_class.include(described_class)
        expect(base_class).to have_received(:delegate)
          .with(:auth_session, to: :auth_session_delegate)
      end
    end
  end

  describe '#auth_session_delegate' do
    let(:controller) do
      Class.new do
        def self.before_action(*); end
        def self.around_action(*); end
        def self.delegate(*); end

        include Authie::ControllerExtension
      end.new
    end

    it 'returns a ControllerDelegate instance' do
      delegate = controller.send(:auth_session_delegate)
      expect(delegate).to be_a(Authie::ControllerDelegate)
    end

    it 'memoizes the delegate' do
      first_call = controller.send(:auth_session_delegate)
      second_call = controller.send(:auth_session_delegate)
      expect(first_call).to be(second_call)
    end
  end

  describe '#skip_touch_auth_session!' do
    let(:controller) do
      Class.new do
        def self.before_action(*); end
        def self.around_action(*); end
        def self.delegate(*); end

        include Authie::ControllerExtension
      end.new
    end

    it 'disables touch_auth_session on the delegate' do
      controller.send(:skip_touch_auth_session!)
      delegate = controller.send(:auth_session_delegate)
      expect(delegate.touch_auth_session_enabled).to be(false)
    end
  end
end
