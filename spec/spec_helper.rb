# frozen_string_literal: true

require 'pry'
require 'digest/md5'
require 'dotenv/load'
require 'securerandom'
##
require_relative '../lib/takuya/gmail-imap-watcher'
RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.raise_errors_for_deprecations!
  Dotenv.load('.env', '.env.sample')
  ENV['user_id'] = ENV['user_id'].strip
  ##
  unless File.exist?(ENV['token_path']) || File.exist?(ENV['client_secret_path'])
    ## try to decrypt
    raise 'no password.' if ENV['openssl_enc_pass'].empty?
    require 'openssl/utils'
    [ENV['token_path'], ENV['client_secret_path']].each{|out_file |
      enc_file=out_file+".enc"
      iter_cnt =1000 * 1000
      OpenSSLEncryption.decrypt_by_ruby(
        passphrase: ENV['openssl_enc_pass'],
        file_enc: enc_file, file_out: out_file, iterations: iter_cnt,
        base64:true
      )
    }
  end
  raise "Empty file (#{ENV['token_path']})." unless YAML.load_file(ENV['token_path'])
  ENV['client_secret_path'] = File.realpath ENV['client_secret_path']
  ENV['token_path'] = File.realpath ENV['token_path']
  ENV['user_id'] = YAML.load_file(ENV['token_path']).keys[0] if ENV['user_id'].empty?
  # ENV["DEBUG"] = '1'
  # Thread.abort_on_exception = true

  def mbox_attrs(imap)
    imap.list('', '*').map(&:attr).flatten.uniq.sort
  end
  def find_mbox_name(imap,key=:Trash)
    imap.list('', '*').find { |e| e.attr.include?(key) }.name
  end
  def list_subject_in_mbox(imap,mbox='INBOX')
    mbox = find_mbox_name(imap,mbox) if mbox.is_a? Symbol
    imap.select(mbox)
    seq_numbers = imap.search(['ALL'])
    seq_numbers.map do |seq_num|
      # シーケンス番号でメールのヘッダー情報を取得
      envelope = imap.fetch(seq_num, "ENVELOPE")[0].attr["ENVELOPE"]
      envelope.subject
    end
  end
  # @param imap [Net::IMAP]
  def list_subjects_in_trash(imap)
    list_subject_in_mbox(imap,:Trash)
  end

  # @return imap [Net::IMAP]
  def imap_connect
    client_secret_path ||= ENV['client_secret_path']
    token_path ||= ENV['token_path']
    user_id ||= ENV['user_id']
    Net::IMAP.debug = true if ENV['DEBUG']
    imap = Takuya::XOAuth2::GMailXOAuth2.imap(client_secret_path, token_path, user_id)
  end
  def append_mail(imap,uuid=nil,mbox="INBOX")
    uuid = SecureRandom.uuid unless uuid
    # メッセージを追加する受信トレイを選択
    imap.select(mbox)
    # メッセージを構築
    message = <<~MESSAGE_END
      From: sender@example.com
      To: your_email@example.com
      Subject: Test Message #{uuid}
      Date: #{Time.now.rfc2822}
      Message-ID: <#{uuid}.example.mail>

      This is a test message.
    MESSAGE_END
    # メッセージを受信トレイに追加
    imap.append(mbox, message, nil, Time.now)

    ## 追加したメッセージを確認
    query = ['SUBJECT', uuid]
    raise unless mail_exists?(imap,query,mbox)
    query
  end
  def mail_exists?(imap,query,mbox="INBOX")
    imap.select(mbox)
    message_ids = imap.search(query)
    ! message_ids.empty?
  end
  def delete_mail(imap,uuid,mbox="INBOX")
    query = ['SUBJECT', uuid]
    trash_name = find_mbox_name(imap,:Trash)
    raise unless mail_exists?(imap,query)
    ##
    imap.select(mbox)
    message_ids = imap.search(query)
    message_ids.each do |m_id|
      imap.store(m_id, "+FLAGS", [:Seen])
      imap.store(m_id, "+FLAGS", [:Deleted])
      imap.copy(m_id, trash_name)
      imap.expunge
    end

    raise if mail_exists?(imap,query)
    raise unless mail_exists?(imap,query,trash_name)

    true

  end
end

