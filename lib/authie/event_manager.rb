# frozen_string_literal: true

module Authie
  class EventManager
    def initialize
      @callbacks = {}
    end

    def dispatch(event, *args)
      callbacks = @callbacks[event.to_sym]
      return if callbacks.nil?

      callbacks.each do |cb|
        cb.call(*args)
      end
    end

    def on(event, &block)
      @callbacks[event.to_sym] ||= []
      @callbacks[event.to_sym] << block
    end

    def remove(event, block)
      cb = @callbacks[event.to_sym]
      return if cb.nil?

      cb.delete(block)
    end
  end
end
