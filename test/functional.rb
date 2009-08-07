
#
# Testing ruote-dm
#
# Fri Aug  7 16:21:24 JST 2009
#

require File.join(File.dirname(__FILE__), 'path_helper')

require 'ruote/dm/engine'

$ruote_engine_class = Ruote::Dm::DmPersistedEngine

ruote = File.expand_path(File.dirname(__FILE__) + '/../../ruota')
ruote = File.expand_path(File.dirname(__FILE__) + '/../../ruote') \
  unless File.exist?(ruote)

require 'dm-core'

DataMapper.setup(:default, 'mysql://localhost/test')

require File.join(ruote, *%w[ test functional test ])

