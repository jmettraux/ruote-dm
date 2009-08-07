
#
# testing ruote-dm
#
# Wed Aug  5 22:42:11 JST 2009
#

#
# runs all the unit tests
#

dirpath = File.dirname(__FILE__)

ts = Dir.new(dirpath).entries.select { |e| e.match(/^ut\_.*\.rb$/) }.sort

ts.each { |e| load(File.join(dirpath, e)) }

