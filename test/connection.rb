
require 'dm-core'

DataMapper.setup(:default, 'mysql://localhost/test')
#DataObjects::Mysql.logger = DataObjects::Logger.new('dm.log', :debug)

