require 'takuya/xoauth2'
require 'mail'

module Takuya
  ;
end

require_relative 'imap-idle-events'
require_relative 'message-events'
require_relative 'imap-watcher'

module Takuya
  class GmailIMAPWatcher<IMAPWatcher
    def initialize(client_secret_path = nil, token_path = nil, user_id = nil)

      client_secret_path ||= ENV['client_secret_path']
      token_path ||= ENV['token_path']
      user_id ||= ENV['user_id']
      @client_secret_path ||= client_secret_path
      @token_path ||= token_path
      @user_id ||= user_id

      super(user_id,'','')
    end

    # @return [Net::IMAP]
    def start_imap
      imap = Takuya::XOAuth2::GMailXOAuth2.imap(@client_secret_path, @token_path, @user_id)
      imap.noop
      imap
    end

  end
end

