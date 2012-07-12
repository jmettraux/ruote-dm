
#
# testing ruote-dm
#
# Thu Feb  4 13:44:13 JST 2010
#

require 'yajl' rescue require 'json'
require 'rufus-json'
Rufus::Json.detect_backend

require 'ruote-dm'

if ARGV.include?('-l') || ARGV.include?('--l')
  FileUtils.rm('debug.log') rescue nil
  DataMapper::Logger.new('debug.log', :debug)
elsif ARGV.include?('-ls') || ARGV.include?('--ls')
  DataMapper::Logger.new(STDOUT, :debug)
end

DataMapper.setup(:default, 'postgres://localhost/ruote_test')
#DataMapper.setup(:default, 'mysql://root:root@localhost/ruote_test')
#DataMapper.setup(:default, 'sqlite3::memory:')
#DataMapper.setup(:default, 'sqlite3:ruote_test.db')

#DataMapper.repository(:default) do
#  require 'dm-migrations' # gem install dm-migrations
#  Ruote::Dm::Document.all.destroy! rescue nil
#  Ruote::Dm::Document.auto_upgrade!
#end

def new_storage(opts)

  Ruote::Dm::Storage.new(:default, opts)
end

