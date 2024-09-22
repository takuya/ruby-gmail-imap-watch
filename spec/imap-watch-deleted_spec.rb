RSpec.describe 'IMAP Watcher IMAP EXPUNGE Detection' do
  ENV.delete 'DEBUG'
  Thread.report_on_exception = false

  it "can be called on_message_deleted." do

    uuid = SecureRandom.uuid
    imap = imap_connect
    trash_name = find_mbox_name(imap, :Trash)
    append_new_mail = lambda { append_mail(imap, uuid) }
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
    ##
    watcher = Takuya::GmailIMAPWatcher.new
    watcher.err_out = StringIO.new
    watcher.imap_idle_timeout = 100
    append_new_mail.call

    ##
    watcher.on_watch_start{
      delete_mail.call
    }
    message_deleted_called = false
    watcher.on_message_deleted{
      message_deleted_called = true
      watcher.stop
    }
    watcher.start
    ##
    expect(message_deleted_called).to be true
    query = ["SUBJECT", uuid]
    expect(mail_exists?(imap, query)).to be false
    expect(mail_exists?(imap, query, trash_name)).to be true

  end
end