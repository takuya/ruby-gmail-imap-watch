require_relative 'imap-events'
require_relative 'imap-mbox'

module Takuya
  module MessageEvents
    include Takuya::ImapEvents
    include Takuya::ImapMbox

    EV_MESSAGE_DELETED = 0x001
    EV_MESSAGE_RECEIVED = 0x002
    EV_MESSAGE_FLAGGED = 0x003
    EV_MESSAGE_ARCHIVED = 0x004
    # @type @last_uids [Array<int>]
    @last_uids

    def map_imap_event_to_message_event
      # @type imap [Net::IMAP]
      # @type res  [Net::IMAP::FetchData]
      on_fetch { |res, imap|
        trigger_event(
          EV_MESSAGE_FLAGGED,
          get_message(res.attr['UID'], imap, @mbox),
          res.attr['FLAGS']
        ) if handler_exists(EV_MESSAGE_FLAGGED)
      }

      on_exists { |res, imap|
        current_uids = get_inbox.uids
        last_uids = @last_uids.uids
        received_uid = current_uids - last_uids
        received_uid.each { |uid|
          trigger_event(EV_MESSAGE_RECEIVED, get_message(uid, imap, @mbox)) if handler_exists(EV_MESSAGE_RECEIVED)
        }
        ## uid からメールの追跡はできない。
        removed_uids = last_uids - current_uids
        removed_uids.each { |uid| trigger_event(EV_MESSAGE_ARCHIVED, uid) if handler_exists(EV_MESSAGE_ARCHIVED) }
      }

      on_expunge { |res, imap|
        current_uids = get_inbox.uids
        last_uids = @last_uids.uids
        removed_uids = last_uids - current_uids
        ## uid からメールの追跡はできない。
        removed_uids.each { |uid|
          trigger_event(EV_MESSAGE_DELETED,uid ) if handler_exists(EV_MESSAGE_DELETED)
        }
      }

    end

    def on_message_received(&block)
      bind_event(EV_MESSAGE_RECEIVED, &block)
    end

    def on_message_deleted(&block)
      bind_event(EV_MESSAGE_DELETED, &block)
    end

    def on_message_flagged(&block)
      bind_event(EV_MESSAGE_FLAGGED, &block)
    end

  end
end

