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

    # @overload initialize()
    def initialize(client_secret_path = nil, token_path = nil, user_id = nil)

      client_secret_path ||= ENV['client_secret_path']
      token_path ||= ENV['token_path']
      user_id ||= ENV['user_id']
      @client_secret_path ||= client_secret_path
      @token_path ||= token_path
      @user_id ||= user_id

      super(user_id, access_token, 'imap.gmail.com', '993')
    end

    def access_token
      obj = Takuya::XOAuth2::GMailXOAuth2.new(@client_secret_path, @token_path, @user_id)
      obj.client_access_token(@user_id)
    end

    # @overload start_imap()
    # @return [Net::IMAP]
    def start_imap
      @imap_params[:pass] = access_token
      @imap_params[:type] = "XOAUTH2"
      super
    end

  end
end

