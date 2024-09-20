require 'pry'
require 'digest/md5'
require 'dotenv/load'
##
require_relative '../lib/takuya/gmail-imap-watcher'

# main
Dotenv.load('.env', '.env.sample')
ENV['client_secret_path'] = File.realpath ENV['client_secret_path']
ENV['token_path'] = File.realpath ENV['token_path']
ENV['user_id'] = ENV['user_id'].strip
##
raise "Empty file (#{ENV['token_path']})." unless YAML.load_file(ENV['token_path'])
ENV['user_id'] = YAML.load_file(ENV['token_path']).keys[0] if ENV['user_id'].empty?

###
# ENV['DEBUG']='1'



watcher = Takuya::GmailIMAPWatcher.new
watcher.on_message_flagged do |mail,flags|
  # @type mail [Mail]
  # @type flags [Array]
  puts "#######################"
  p [ mail:mail, flags:flags ]
  puts :on_message_flagged
end
watcher.on_message_received do |mail|
  # @type mail [Mail]
  puts "############ new message delivered."
  puts mail.message_id
end
watcher.start

