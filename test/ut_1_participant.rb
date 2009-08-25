
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
    #DataObjects::Mysql.logger = DataObjects::Logger.new('dm.log', :debug)
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

  def test_consume_non_string_field_keys

    wi = new_wi('12345-678', '0_0', 'toto', { :a => 'A' })

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
      '|animals:|lion|boar|beef|zebra|gnu|cars:|bmw:true|participant:alice|',
      Ruote::Dm::DmWorkitem.first.keywords)
  end

  def test_store_names

    wi = new_wi('12346-678', '0_0', 'bob', { 'b' => 'B' })
    @participant.consume(wi)

    @participant.instance_variable_set(:@store_name, 'store0')
      # just testing...

    wi = new_wi('12345-678', '0_0', 'alice', { 'a' => 'A' })
    @participant.consume(wi)


    assert_equal 1, @participant.size

    assert_equal(
      [ 'store0', nil ],
      Ruote::Dm::DmWorkitem.all.collect { |dwi| dwi.store_name })
  end

  def test_search

    @participant.consume(new_wi('123', '0_0', 'alice', {
      'animals' => %w[ lion boar beef zebra gnu ], 'cars' => { 'bmw' => true }
    }))

    assert_equal 1, Ruote::Dm::DmWorkitem.search('bmw:true').size
  end

  def test_search_with_store_names

    Ruote::Dm::DmWorkitem.from_ruote_workitem(
      new_wi('123', '0_0', 'alice', { 'a' => 'A' }), :store_name => 'store0')
    Ruote::Dm::DmWorkitem.from_ruote_workitem(
      new_wi('124', '0_0', 'alice', { 'a' => 'A' }), :store_name => 'store1')
    Ruote::Dm::DmWorkitem.from_ruote_workitem(
      new_wi('125', '0_0', 'bob', { 'a' => 'A' }), :store_name => 'store0')

    assert_equal 3, Ruote::Dm::DmWorkitem.search('a:A').size
    assert_equal 1, Ruote::Dm::DmWorkitem.search('a:A', 'store1').size
    assert_equal 1, Ruote::Dm::DmWorkitem.search('a:A', %w[ store1 ]).size
    assert_equal 2, Ruote::Dm::DmWorkitem.search('a:A', %w[ store0 ]).size
  end

  def test_workitem_override

    Ruote::Dm::DmWorkitem.from_ruote_workitem(
      new_wi('123', '0_0', 'alice', { 'a' => 'A' }), :store_name => 'store0')

    assert_equal 1, Ruote::Dm::DmWorkitem.all.size

    Ruote::Dm::DmWorkitem.from_ruote_workitem(
      new_wi('123', '0_0', 'alice', { 'a' => 'A' }), :store_name => 'store0')

    assert_equal 1, Ruote::Dm::DmWorkitem.all.size
  end

  def test_no_key_field

    @participant.consume(new_wi('123', '0_0', 'alice', {
      'animals' => %w[ lion boar beef zebra gnu ], 'cars' => { 'bmw' => true }
    }))

    dwi = Ruote::Dm::DmWorkitem.first

    assert_nil dwi.key_field
  end

  def test_key_field

    @participant = Ruote::Dm::DmParticipant.new(
      :key_field => 'brand')
    @participant.context = {}

    %w[ alfa-romeo citroen maserati citroen ].each_with_index do |b, i|
      @participant.consume(new_wi('123', "0_#{i}", 'alice', {
        'animals' => %w[ lion boar beef zebra gnu ], 'brand' => b
      }))
    end

    #p Ruote::Dm::DmWorkitem.all.collect { |dwi| dwi.key_field }

    assert_equal 1, Ruote::Dm::DmWorkitem.all(:key_field => 'alfa-romeo').size
    assert_equal 2, Ruote::Dm::DmWorkitem.all(:key_field => 'citroen').size
  end

  protected

  def new_wi (wfid, expid, participant_name, fields)

    fei = Ruote::FlowExpressionId.from_h(
      'engine_id' => 'my_engine', 'wfid' => wfid, 'expid' => expid)

    wi = Ruote::Workitem.new
    wi.fei = fei
    wi.fields = fields
    wi.participant_name = participant_name

    wi
  end
end

