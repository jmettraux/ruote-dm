
require 'dm-core'

DataMapper.setup(:default, 'mysql://localhost/test')
#DataObjects::Mysql.logger = DataObjects::Logger.new('dm.log', :debug)

require 'ruote/dm/storage/dm_storage.rb'
require 'ruote/dm/part/dm_participant.rb'

DataMapper.repository(:default) do
  Ruote::Dm::DmExpression.auto_upgrade!
  Ruote::Dm::DmWorkitem.auto_upgrade!
end

