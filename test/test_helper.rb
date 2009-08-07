
#
# testing ruote-dm
#
# Wed Aug  5 22:46:29 JST 2009
#

require File.join(File.dirname(__FILE__), 'path_helper')

require 'test/unit'
require 'rubygems'

require 'dm-core'

DataMapper.setup(:default, 'mysql://localhost/test')

