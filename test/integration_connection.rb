
#
# makes sure the db is ready for tests
#

require 'dm-core'

DataMapper.setup(:default, 'mysql://localhost/test')
#DataObjects::Mysql.logger = DataObjects::Logger.new('dm.log', :debug)

require 'ruote/dm/storage/dm_storage'
require 'ruote/dm/part/dm_participant'
require 'ruote/dm/err/dm_errorjournal'
require 'ruote/dm/ticket'

DataMapper.repository(:default) do
  Ruote::Dm::DmExpression.auto_upgrade!
  Ruote::Dm::DmWorkitem.auto_upgrade!
  Ruote::Dm::DmProcessError.auto_upgrade!
  Ruote::Dm::Ticket.auto_upgrade!
end

