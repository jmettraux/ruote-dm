
#
# testing ruote-dm
#
# Thu Feb  4 13:44:13 JST 2010
#

require 'rufus-json/automatic'
require 'ruote-dm'


case ENV['RUOTE_STORAGE_DEBUG']
  when 'log'
    FileUtils.rm('debug.log') rescue nil
    DataMapper::Logger.new('debug.log', :debug)
  when 'debug'
    DataMapper::Logger.new(STDOUT, :debug)
end

case ENV['RUOTE_STORAGE_DB'] || 'postgres'
  when 'pg', 'postgres'
    DataMapper.setup(:default, 'postgres://localhost/ruote_test')
  when 'my', 'mysql'
    #DataMapper.setup(:default, 'mysql://root:root@localhost/ruote_test')
    DataMapper.setup(:default, 'mysql://localhost/ruote_test')
  when 'mem', 'litemem'
    DataMapper.setup(:default, 'sqlite3::memory:')
  when 'file', 'litefile'
    DataMapper.setup(:default, 'sqlite3:ruote_test.db')
  when /:/
    DataMapper.setup(:default, ENV['RUOTE_STORAGE_DB'])
  else
    raise ArgumentError.new("unknown DB: #{ENV['RUOTE_STORAGE_DB'].inspect}")
end

#DataMapper.repository(:default) do
#  require 'dm-migrations' # gem install dm-migrations
#  Ruote::Dm::Document.all.destroy! rescue nil
#  Ruote::Dm::Document.auto_upgrade!
#end

def new_storage(opts)

  Ruote::Dm::Storage.new(:default, opts)
end

