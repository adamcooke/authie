# frozen_string_literal: true

require 'spec_helper'
require 'authie/config'

RSpec.describe Authie::EventManager do
  subject(:manager) { described_class.new }

  describe '#on' do
    it 'adds new blocks for events' do
      block = proc { 1 + 1 }
      manager.on(:test_event, &block)
      expect(manager.callbacks[:test_event]).to eq [block]
    end
  end

  describe '#remove' do
    it 'removes existing callbacks with the same block' do
      block = proc { 1 + 1 }
      manager.on(:test_event, &block)
      manager.remove(:test_event, block)
      expect(manager.callbacks[:test_event]).to eq []
    end

    it 'returns nil if there are no events' do
      expect(manager.remove(:test_event, proc {})).to be nil
    end
  end

  describe '#dispatch' do
    it 'calls all the registered blocks' do
      manager.on(:add_value) { |c| c << 1 }
      manager.on(:add_value) { |c| c << 2 }
      value = []
      manager.dispatch(:add_value, value)
      expect(value).to eq [1, 2]
    end

    it 'does not call blocks associated with other events' do
      manager.on(:add_one) { |c| c << 1 }
      manager.on(:add_two) { |c| c << 2 }
      value = []
      manager.dispatch(:add_one, value)
      expect(value).to eq [1]
    end

    it 'returns nil if there are no registered events' do
      expect(manager.dispatch(:test_event)).to be nil
    end
  end
end
