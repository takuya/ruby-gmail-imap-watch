require_relative 'event-emitter'
require_relative 'imap-idle-events'
module Takuya
  module ImapEvents
    include Takuya::EventEmitter
    include Takuya::ImapIdleEvents

    IMAP_EVENT_EXISTS = 0x101
    IMAP_EVENT_FETCH = 0x102
    IMAP_EVENT_EXPUNGE = 0x103

    public

    def on_exists(&block)
      bind_event(IMAP_EVENT_EXISTS, &block)
    end

    def on_fetch(&block)
      bind_event(IMAP_EVENT_FETCH, &block)
    end

    def on_expunge(&block)
      bind_event(IMAP_EVENT_EXPUNGE, &block)
    end

    protected

    def map_idle_response_to_imap_event
      untagged_handler = lambda { |res, imap|
        return unless res.kind_of?(Net::IMAP::UntaggedResponse)
        case res.name
          when 'FETCH'
            responses = imap.responses['FETCH']
            responses.each { |response| trigger_event(IMAP_EVENT_FETCH, response, imap) }
          when 'EXISTS'
            trigger_event(IMAP_EVENT_EXISTS, res, imap)
          when 'EXPUNGE'
            trigger_event(IMAP_EVENT_EXPUNGE, res, imap)
          else
            raise "UnKnown name #{res.name}"
        end
      }
      idling_handler = lambda { |res|
        if res.kind_of?(Net::IMAP::ContinuationRequest) && res.data.text=="idling"
          p :imap_is_idling
        end
      }
      unknown_handler = lambda { |res|
        raise "Unknown response #{res.raw_data}"
      }
      bind_event(EV_IMAP_RESPONSE_UNTAGGED, &untagged_handler)
      bind_event(EV_IMAP_RESPONSE_CONTINUATION, &idling_handler)
      bind_event(EV_IMAP_RESPONSE_UNKNOWN, &unknown_handler)
    end

  end
end

