RSpec.describe 'IMAP Watcher start/stop' do
  ENV.delete 'DEBUG'
  Thread.report_on_exception = false

  it "can become idle successfully and catch Exception successfully" do
    uuid = SecureRandom.uuid
    watcher = Takuya::GmailIMAPWatcher.new
    watcher.err_out = StringIO.new
    watcher.max_retry_reconnect = 0
    watcher.imap_idle_timeout = 10
    res_body = nil
    watcher.on_idle_callback { |res|
      res_body = res.raw_data
      raise "imap.idle_called:#{uuid}"
    }
    begin
      watcher.start
    rescue RuntimeError => e
      msg = e.message
    end
    expect(msg).to eq "imap.idle_called:#{uuid}"
    expect(res_body).to eq "+ idling\r\n"
    expect(watcher.err_out.string).to include "ensure disconnect.\n"
  end
  it "can timeout" do
    uuid = SecureRandom.uuid
    timeout = 1
    watcher = Takuya::GmailIMAPWatcher.new
    watcher.err_out = StringIO.new
    watcher.max_retry_reconnect = 0
    watcher.imap_idle_timeout = timeout

    timestamps = {}
    res_body = nil

    watcher.on_idle_callback { |res|
      timestamps[:on_idle_start] = Time.now
      sleep timeout
      timestamps[:on_idle_end] = Time.now
    }
    watcher.on_idle_done { |res|
      raise "Something strange be occurred." unless res.data.text=="IDLE terminated (Success)"
      res_body = res.data.text
      timestamps[:on_idle_done_start] = Time.now
      raise uuid
    }

    ex = nil
    begin
      watcher.start
    rescue => e
      ex = e
    end

    ## スリープして直後に例外で中断されることをテスト
    expect(ex.class).to eq RuntimeError
    expect(ex.message).to eq uuid
    expect(res_body).to eq "IDLE terminated (Success)"
    expect(timestamps[:on_idle_end] - timestamps[:on_idle_start]>=1).to be true
    expect(timestamps[:on_idle_end] - timestamps[:on_idle_start]<2).to be true
    expect(timestamps[:on_idle_done_start] - timestamps[:on_idle_end]>0).to be true
    expect(timestamps[:on_idle_done_start] - timestamps[:on_idle_end]<2).to be true

  end
  it "can be Interrupted " do
    ENV.delete 'DEBUG'

    watcher = Takuya::GmailIMAPWatcher.new
    watcher.err_out = StringIO.new
    watcher.max_retry_reconnect = 0
    watcher.imap_idle_timeout = 10

    watcher.on_idle_callback { raise Interrupt }
    begin
      Thread.report_on_exception = false
      Thread.new { Thread.pass; watcher.start }.join
    rescue Interrupt
      interrupted = true
    end

    expect(interrupted).to be true
  end
  it "can be #stop " do

    watcher = Takuya::GmailIMAPWatcher.new
    watcher.err_out = StringIO.new
    watcher.max_retry_reconnect = 0
    watcher.imap_idle_timeout = 10

    watcher.on_idling { watcher.stop }
    watcher.start
    thread = watcher.instance_variable_get(:@thread)
    expect(thread.alive?).to be false
  end

end