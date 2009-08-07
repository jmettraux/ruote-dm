
#
# testing ruote-dm
#
# Wed Aug  5 22:46:29 JST 2009
#

ruote_lib = File.expand_path(File.dirname(__FILE__) + '/../../ruota/lib')
ruote_lib = File.expand_path(File.dirname(__FILE__) + '/../../ruote/lib') \
  unless File.exist?(ruote_lib)

ruote_dm_lib = File.expand_path(File.dirname(__FILE__) + '/../lib')

$:.unshift(ruote_lib) unless $:.include?(ruote_lib)
$:.unshift(ruote_dm_lib) unless $:.include?(ruote_dm_lib)

