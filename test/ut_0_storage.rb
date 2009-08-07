
#
# Testing ruote-dm
#
# Wed Aug  5 22:44:26 JST 2009
#

require File.join(File.dirname(__FILE__), 'test_helper.rb')

require 'ruote/fei'
require 'ruote/workitem'
require 'ruote/exp/expression_map'
require 'ruote/dm/storage/dm_storage'

class TestDmStorage < Ruote::Dm::DmStorage
  def subscribe (eclass)
    # do nothing
  end
end

class StorageTest < Test::Unit::TestCase

  def setup
    @storage = TestDmStorage.new
    @storage.context = {}
  end
  def teardown
    DataMapper.repository(:default) do
      Ruote::Dm::DmExpression.all.destroy!
    end
  end

  def test_store_unstore_expression

    fexp = new_expression('0_0')

    @storage[fexp.fei] = fexp

    assert_equal 1, @storage.size

    @storage.delete(fexp.fei)

    assert_equal 0, @storage.size
  end

  def test_find_expressions

    fexp = new_expression('0_0')
    @storage[fexp.fei] = fexp

    fexp = new_expression('0_0', :wfid => 'abcd-5')
    @storage[fexp.fei] = fexp

    fexp = new_expression('0_0', :wfid => 'abcd-5_0')
    @storage[fexp.fei] = fexp

    fexp = new_expression('0_1', :class => Ruote::WaitExpression)
    @storage[fexp.fei] = fexp

    assert_equal 2, @storage.find_expressions(:wfid => '1245-6789').size
    assert_equal 2, @storage.find_expressions(:wfid => 'abcd-5').size

    assert_equal(
      Ruote::SequenceExpression,
      @storage.find_expressions(:wfid => 'abcd-5').first.class)

    assert_equal(
      3,
      @storage.find_expressions(:class => Ruote::SequenceExpression).size)

    assert_equal(
      1,
      @storage.find_expressions(:responding_to => :reschedule).size)
  end

  protected

  def new_expression (expid, opts={})

    opts[:wfid] ||= '1245-6789'
    opts[:class] ||= Ruote::SequenceExpression

    fei = Ruote::FlowExpressionId.from_h(
      'engine_id' => 'toto', 'wfid' => opts[:wfid], 'expid' => expid)
    opts[:class].new(
      nil, fei, nil, [ 'sequence', {}, [] ], {}, Ruote::Workitem.new)
  end
end

