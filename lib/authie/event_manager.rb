module Authie
  class EventManager

    def initialize
      @callbacks = {}
    end

    def dispatch(event, *args)
      if callbacks = @callbacks[event.to_sym]
        callbacks.each do |cb|
          cb.call(*args)
        end
      end
    end

    def on(event, &block)
      @callbacks[event.to_sym] ||= []
      @callbacks[event.to_sym] << block
    end

    def remove(event, block)
      if cb = @callbacks[event.to_sym]
        cb.delete(block)
      end
    end

  end
end
