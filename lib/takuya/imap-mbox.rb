module Takuya
  module ImapMbox
    protected
    ## select の場合は、容赦なく既読 read(:seen)　にされる
    ## examine の場合は、変更されない。
    # 不安定なので、 BODY.PEEK を使うべき
    def get_message(uid, imap = nil, mbox = nil, keep_unread = true)
      # @type [Net::IMAP]
      imap ||= @imap
      imap.select(mbox) if (mbox)
      if keep_unread
        envelope = imap.uid_fetch(uid, "BODY.PEEK[]")[0].attr['BODY[]']
      else
        envelope = imap.uid_fetch(uid, 'RFC822')[0].attr['RFC822']
      end
      mail = Mail.read_from_string(envelope)
    end
    def get_mbox_i18n_name(key,imap=nil)
      imap ||= @imap
      imap.list('','*').find {|e| e.attr.include? key }.name
    end

    # @param mbox [String] i18n name in Gmail.
    # @param imap [Net::IMAP]
    def get_uids_in_mbox(mbox,imap=nil)
      imap ||= @imap
      imap.examine(mbox)
      uids = imap.uid_search(["ALL"])
      result = Struct.new(:uids, :last_fetched_at).new(*[uids, Time.now])
    end
    # @param imap [Net::IMAP]
    def get_inbox(imap = nil)
      imap ||= @imap
      get_uids_in_mbox("INBOX",imap)
    end

  end
end