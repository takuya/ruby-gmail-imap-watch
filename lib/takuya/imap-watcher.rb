require 'takuya/xoauth2'
require 'mail'

module Takuya
  ;
end

require_relative 'imap-idle-events'
require_relative 'message-events'

module Takuya
  class IMAPWatcher
    include Takuya::ImapIdleEvents
    include Takuya::MessageEvents

    attr_accessor :max_retry_reconnect
    attr_accessor :imap_idle_timeout
    attr_accessor :err_out

    def initialize(id, pass, server, port = 993, ssl = true)

      @imap_params = { type: "LOGIN", id: id, pass: pass, server: server, port: port, ssl: ssl }
      if ENV['DEBUG']
        Net::IMAP.debug = true
      end
      @max_retry_reconnect = 100
      @imap_idle_timeout = 300
      @err_out = $stderr

    end

    def start(mbox = "INBOX")
      ## mapping imap event handlers
      mapping_events
      # @type [Net::IMAP]
      @imap = connect_imap

      watch(mbox) { |res|
        @err_out.puts res.raw_data
      }
    rescue Interrupt => e
      @err_out.puts :Interrupted
    end

    protected

    def mapping_events
      ## event handlers
      map_idle_done_to_imap_res_event
      map_idle_response_to_imap_event
      map_imap_event_to_message_event
    end

    def watch(mbox, &idle_loop_callback)

      @mbox = mbox
      bind_event(EV_IMAP_IDLE_LOOP, &idle_loop_callback) if idle_loop_callback
      ## #####################################
      ## imap idle push notification main loop
      ## #####################################
      begin
        while imap.noop.name=='OK'
          begin
            imap.examine(@mbox)
            @last_uids = get_uids_in_mbox(@mbox)
            last_response_holder, idle_callback = imap_idle_response_handler
            res_idle_done = imap.idle(@imap_idle_timeout, &idle_callback)
            trigger_event(EV_IMAP_IDLE_DONE, res_idle_done, last_response_holder, imap)
          rescue => ex
            raise ex
          end
        end
        @err_out.puts :loop_end
      rescue OpenSSL::SSL::SSLError, Errno::ECONNRESET, IOError # TCP Connection Error
        try_reconnect
        retry
      rescue => e
        raise e
      ensure
        @err_out.puts "ensure logout."
        imap.logout
        imap.disconnect
      end
    end

    def try_reconnect
      retry_cnt = 0
      begin
        sleep 10 * retry_cnt
        @err_out.puts 'trying reconnecting...'
        connect_imap
      rescue OpenSSL::SSL::SSLError, Errno::ECONNRESET, Errno::ECONNREFUSED # TCP Connection Error
        retry_cnt += 1
        raise "tcp reconnecting Gave up." if retry_cnt>@max_retry_reconnect
        retry
      end
    end

    # @return [Net::IMAP]
    def start_imap
      imap = Net::IMAP.new(@imap_params[:server], port: @imap_params[:port], ssl: @imap_params[:ssl])
      imap.authenticate(@imap_params[:type], @imap_params[:id], @imap_params[:pass])
      imap.noop
      imap
    end

    # @return [bool]
    def disconnect_imap
      return unless @imap
      @imap.logout
      @imap.disconnect
      @imap.disconnected?
    end

    #
    # @return [Net::IMAP]
    def connect_imap
      disconnect_imap unless @imap.disconnected? if @imap
      @imap = start_imap
    end
  end
end
