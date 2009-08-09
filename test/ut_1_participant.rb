
#
# Testing ruote-dm
#
# Sun Aug  9 19:39:16 JST 2009
#

require File.join(File.dirname(__FILE__), 'test_helper.rb')

require 'ruote/fei'
require 'ruote/workitem'
require 'ruote/dm/part/dm_participant'


class ParticipantTest < Test::Unit::TestCase

  def setup
    @participant = Ruote::Dm::DmParticipant.new({})
    @participant.context = {}
    #DataObjects::Mysql.logger = DataObjects::Logger.new(STDOUT, :debug)
    DataObjects::Mysql.logger = DataObjects::Logger.new('dm.log', :debug)
  end
  def teardown
    DataMapper.repository(:default) do
      Ruote::Dm::DmWorkitem.all.destroy!
    end
  end

  def test_consume

    wi = new_wi('12345-678', '0_0', 'toto', { 'a' => 'A' })

    @participant.consume(wi)

    assert_equal 1, Ruote::Dm::DmWorkitem.all.size
    assert_not_nil Ruote::Dm::DmWorkitem.first.last_modified
  end

  def test_cancel

    wi = new_wi('12345-678', '0_0', 'alice', { 'a' => 'A' })
    @participant.consume(wi)

    @participant.cancel(wi.fei, nil)

    assert_equal 0, Ruote::Dm::DmWorkitem.all.size
  end

  def test_keywords

    @participant.consume(new_wi('123', '0_0', 'alice', {
      'animals' => %w[ lion boar beef zebra gnu ], 'cars' => { 'bmw' => true }
    }))

    assert_equal(
      '|animals:|lion|boar|beef|zebra|gnu|cars:|bmw:true|participant:|',
      Ruote::Dm::DmWorkitem.first.keywords)
  end

  def test_search

    @participant.consume(new_wi('123', '0_0', 'alice', {
      'animals' => %w[ lion boar beef zebra gnu ], 'cars' => { 'bmw' => true }
    }))

    assert_equal 1, Ruote::Dm::DmWorkitem.search('bmw:true').size
  end

  protected

  def new_wi (wfid, expid, participant_name, fields)

    fei = Ruote::FlowExpressionId.from_h(
      'engine_id' => 'my_engine', 'wfid' => wfid, 'expid' => expid)

    wi = Ruote::Workitem.new
    wi.fei = fei
    wi.fields = fields

    wi
  end
end

