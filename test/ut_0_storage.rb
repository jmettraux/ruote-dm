
#
# Testing ruote-dm
#
# Wed Aug  5 22:44:26 JST 2009
#

require File.join(File.dirname(__FILE__), 'test_helper.rb')

require 'ruote/fei'
require 'ruote/workitem'
require 'ruote/exp/fe_sequence'
require 'ruote/dm/storage/dm_storage'

class TestDmStorage < Ruote::Dm::DmStorage
  def subscribe (eclass)
    # do nothing
  end
end

class StorageTest < Test::Unit::TestCase

  def test_store_expression

    storage = TestDmStorage.new
    storage.context = {}

    fei = Ruote::FlowExpressionId.from_h(
      'engine_id' => 'toto', 'wfid' => '12345-4566', 'expid' => '0_1_0')
    fexp = Ruote::SequenceExpression.new(
      nil, fei, nil, [ 'sequence', {}, [] ], {}, Ruote::Workitem.new)

    storage[fei] = fexp

    #DataMapper.repository(:default) do
    #  Ruote::Dm::DmExpression.public_methods.sort.each { |m| puts m }
    #end

    assert_equal 1, storage.size

    storage.delete(fei)

    assert_equal 0, storage.size
  end
end

