require 'takuya/xoauth2'
require 'mail'
module Takuya
  module EventEmitter
    def bind_event(ev, &block)
      raise if block.nil?
      @event_handlers ||= {}
      @event_handlers[ev] ||= []
      @event_handlers[ev] << block
    end

    def unbind_event(ev, &block)
      return unless @event_handlers && @event_handlers[ev]
      @event_handlers[ev].delete(block)
    end

    def trigger_event(ev, *args)
      return unless handler_exists(ev)

      @event_handlers[ev].map do |listener|
        listener.call(*args)
      end
    end

    def handler_exists(ev)
      @event_handlers.has_key?(ev) && @event_handlers[ev].size>0
    end

    ## イベントの管理系の名前は「百花繚乱」すぎて、理解の妨げになることがある。
    ### EventEmitter の名前パターンをメモ側に書いておく
    ##
    alias_method :on, :bind_event
    alias_method :emit, :trigger_event
    ##
    alias_method :observe, :bind_event
    alias_method :signal, :trigger_event
    ##
    alias_method :listen, :bind_event
    alias_method :notify, :trigger_event
    ##
    alias_method :handle, :bind_event
    alias_method :raise_event, :trigger_event
    ##
    alias_method :fire, :trigger_event
    alias_method :invoke, :trigger_event
    alias_method :dispatch, :trigger_event

  end
end

