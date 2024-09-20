require_relative 'event-emitter'

module Takuya
  module ImapIdleEvents
    include Takuya::EventEmitter
    ##
    EV_IMAP_RESPONSE_UNTAGGED = 0x301
    EV_IMAP_RESPONSE_CONTINUATION = 0x302
    EV_IMAP_RESPONSE_UNKNOWN = 0x303
    EV_IMAP_IDLE_LOOP = 0x401
    EV_IMAP_IDLE_DONE = 0x402

    def on_idle_done(&block)
      bind_event(EV_IMAP_IDLE_DONE,&block)
    end

    protected

    def map_idle_done_to_imap_res_event
      on_idle_done do |res_idle_done, last_idle_response,imap|
        unless res_idle_done.raw_data && %w"ok idle terminated success".map { |e| /#{e}/i }.all? { |e| res_idle_done.raw_data=~e }
          raise "UnExpected response #{res_idle_done.raw_data}"
        end
        if last_idle_response.body.kind_of?(Net::IMAP::UntaggedResponse)
          trigger_event(EV_IMAP_RESPONSE_UNTAGGED, last_idle_response.body, imap)
        end
      end
    end

    def imap_idle_response_handler(holder=nil,imap=nil)
      imap ||= @imap
      holder ||= Struct.new(:body).new
      imap_idle_handler = lambda{|_imap,last_response|
        unless last_response.respond_to? :body=
          raise "idle受信メッセージを保存するために、ミュータブル・オブジェクトを渡してください"
        end
        lambda { |res|
          trigger_event(EV_IMAP_IDLE_LOOP, res) if handler_exists(EV_IMAP_IDLE_LOOP)

          if res.kind_of?(Net::IMAP::ContinuationRequest)
            trigger_event(EV_IMAP_RESPONSE_CONTINUATION, res, _imap)
          else
            last_response.body = res
            _imap.idle_done
          end
        }
      }
      [holder,imap_idle_handler.call(imap,holder)]
    end
  end
end

