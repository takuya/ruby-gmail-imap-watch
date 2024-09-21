require_relative 'event-emitter'

module Takuya
  module ImapIdleEvents
    include Takuya::EventEmitter
    ##
    EV_IMAP_RESPONSE_UNTAGGED = 0x301
    EV_IMAP_RESPONSE_CONTINUATION = 0x302
    EV_IMAP_RESPONSE_UNKNOWN = 0x303
    EV_IMAP_IDLE_LOOP = 0x401
    EV_IMAP_IDLE_DONE_CALLED = 0x402
    EV_IMAP_IDLE_TERMINATED_IN_SUCCESS = 0x403

    def on_idle_done(&block)
      bind_event(EV_IMAP_IDLE_DONE_CALLED, &block)
    end
    def on_idle(&block)
      bind_event(EV_IMAP_IDLE_LOOP, &block)
    end

    protected

    def map_idle_done_to_imap_res_event
      on_idle_done do |res_idle_done, last_idle_response, imap|
        unless res_idle_done.raw_data && %w"ok idle terminated success".map { |e| /#{e}/i }.all? { |e| res_idle_done.raw_data=~e }
          raise "UnExpected response #{res_idle_done.raw_data}"
        end

        if last_idle_response.kind_of?(Net::IMAP::UntaggedResponse)
          trigger_event(EV_IMAP_RESPONSE_UNTAGGED, last_idle_response, imap)
        elsif last_idle_response.nil? &&
          res_idle_done.raw_data &&
          %w"ok idle terminated success".map { |e| /#{e}/i }.all? { |e| res_idle_done.raw_data=~e }
          trigger_event(EV_IMAP_IDLE_TERMINATED_IN_SUCCESS,res_idle_done, imap)
        else
          ## Net::IMAP::UntaggedResponse 以外が来るはずがない用に設計した。
          # Untagged以外の、あり得ないレスポンスが来たらエラーとする。
          trigger_event(EV_IMAP_RESPONSE_UNKNOWN, last_idle_response, imap)
        end
      end
    end

    def imap_idle_response_handler(holder = nil, imap = nil)
      imap ||= @imap
      holder ||= Struct.new(:response,:exception).new
      imap_idle_handler = lambda { |_imap, last_response|
        unless last_response.respond_to? :response=
          raise "idle受信メッセージを保存するために、ミュータブル・オブジェクトを渡してください"
        end
        lambda { |res|
          begin
            trigger_event(EV_IMAP_IDLE_LOOP, res)
          rescue Interrupt => ex
            ## interrupt は明示してキャッチする必要がある。
            imap.idle_done
            last_response.exception=ex
          rescue => e
            imap.idle_done
            last_response.exception=e
          end

          if res.kind_of?(Net::IMAP::ContinuationRequest)
            trigger_event(EV_IMAP_RESPONSE_CONTINUATION, res, _imap)
          else
            last_response.response = res
            _imap.idle_done
          end
        }
      }
      [holder, imap_idle_handler.call(imap, holder)]
    end
  end
end

