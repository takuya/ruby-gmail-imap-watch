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
  ENV['client_secret_path'] = File.realpath ENV['client_secret_path']
  ENV['token_path'] = File.realpath ENV['token_path']
  ENV['user_id'] = ENV['user_id'].strip
  ##
  raise "Empty file (#{ENV['token_path']})." unless YAML.load_file(ENV['token_path'])
  ENV['user_id'] = YAML.load_file(ENV['token_path']).keys[0] if ENV['user_id'].empty?
  # ENV["DEBUG"] = '1'
  # Thread.abort_on_exception = true

  #
  # def append_mail(uuid)
  #   imap = Takuya::XOAuth2::GMailXOAuth2.imap(client_secret_path,token_path,user_id)
  #   imap.select('INBOX')
  #   message = <<~MESSAGE_END
  #     From: sender@example.com
  #     To: your_email@example.com
  #     Subject: Test Message
  #     Date: #{Time.now.rfc2822}
  #     Message-ID: <#{uuid}>
  #
  #     This is a test message.
  #   MESSAGE_END
  #   imap.append('INBOX', message, nil, Time.now)
  #   imap.logout
  #   imap.disconnect
  # end

end