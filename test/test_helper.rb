
#
# testing ruote-dm
#
# Wed Aug  5 22:46:29 JST 2009
#

ruote_dm_lib = File.expand_path(File.dirname(__FILE__) + '/../lib')
$:.unshift(ruote_dm_lib) unless $:.include?(ruote_dm_lib)

require 'test/unit'
require 'rubygems'

