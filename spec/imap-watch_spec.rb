RSpec.describe 'IMAP Watcher' do
  ENV.delete 'DEBUG'
  Thread.report_on_exception = false

  it "can be append a sample mail." do
    expect {
      imap = imap_connect
      query = append_mail(imap)
      uuid = query[1]
      delete_mail(imap,uuid)
    }.not_to raise_error
  end
  it "can be called on_message_received." do

    uuid = SecureRandom.uuid
    imap = imap_connect
    trash_name = find_mbox_name(imap, :Trash)
    ##
    watcher = Takuya::GmailIMAPWatcher.new
    watcher.err_out = StringIO.new
    watcher.imap_idle_timeout = 100

    append_new_mail = lambda { append_mail(imap, uuid) }
    flag_mail = lambda {
      ## mark as :SEEN
      imap.select("INBOX")
      res = imap.search(['SUBJECT', uuid])
      imap.store(res[0], "+FLAGS", [:Seen])
    }
    delete_mail = lambda {
      ## delete message
      imap.select("INBOX")
      ids = imap.search(['SUBJECT', uuid])
      ids.each { |m_id|
        imap.store(m_id, "+FLAGS", [:Seen])
        imap.store(m_id, "+FLAGS", [:Deleted])
        imap.copy(m_id, trash_name)
        imap.expunge
      }
    }
    test_mail_works = [
      append_new_mail,
      flag_mail,
      delete_mail
    ]
    watcher.on_idling {
      if test_mail_works.empty?
        watcher.stop
      else
        func = test_mail_works.shift
        func.call
      end
    }
    received_msg = nil
    flagged_msg = nil
    on_message_deleted_called = false
    on_watch_stopped_called = false
    watcher.on_message_received { |message|
      received_msg = message
    }
    watcher.on_message_flagged { |message|
      flagged_msg = message
    }
    watcher.on_message_deleted {
      on_message_deleted_called = true
    }
    watcher.on_watch_stopped{
      on_watch_stopped_called = true
    }
    watcher.start

    ##
    expect(received_msg).not_to be nil
    expect(received_msg.subject).to include uuid
    expect(flagged_msg).not_to be nil
    expect(flagged_msg.subject).to include uuid
    expect(on_message_deleted_called).to be true
    expect(on_watch_stopped_called).to be true
    ##
    query = ["SUBJECT", uuid]
    expect(mail_exists?(imap, query)).to be false
    expect(mail_exists?(imap, query, trash_name)).to be true

  end

end