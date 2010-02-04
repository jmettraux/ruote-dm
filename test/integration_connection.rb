
#
# testing ruote-dm
#
# Thu Feb  4 13:44:13 JST 2010
#

require 'yajl' rescue require 'json'
require 'rufus-json'
Rufus::Json.detect_backend

require 'ruote-dm'


def new_storage (opts)

  DataMapper.setup(:default, 'postgres://localhost/ruote_test')
  #DataMapper.setup(:default, 'sqlite3::memory:')
  #DataMapper.setup(:default, 'sqlite3:ruote_test.db')

  if ARGV.include?('-dmlog')
    DataMapper::Logger.new(STDOUT, :debug)
    #FileUtils.rm('debug.log') rescue nil
    #DataMapper::Logger.new('debug.log', :debug)
  end

  DataMapper.repository(:default) do
    Ruote::Dm::Document.auto_upgrade!
    Ruote::Dm::Document.all.destroy!
  end

  Ruote::Dm::DmStorage.new(:default)
end

