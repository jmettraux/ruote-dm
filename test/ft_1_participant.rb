
#
# Testing ruote-dm
#
# Tue Aug 11 15:07:26 JST 2009
#

require File.join(File.dirname(__FILE__), 'test_helper.rb')

require 'ruote/engine'
require 'ruote/dm/part/dm_participant'


class FtParticipantTest < Test::Unit::TestCase

  def setup
    DataMapper.repository(:default) do
      Ruote::Dm::DmWorkitem.auto_upgrade!
    end
    @engine = Ruote::Engine.new()
    @alice = @engine.register_participant :alice, Ruote::Dm::DmParticipant
  end
  def teardown
    @engine.shutdown
    DataMapper.repository(:default) do
      Ruote::Dm::DmWorkitem.all.destroy!
    end
    FileUtils.rm_rf('work')
  end

  def test_participant_in_flow

    pdef = Ruote::process_definition :name => 'test' do
      alice
    end

    wfid = @engine.launch(pdef, :fields => { 'toto' => 'nada' })

    sleep 0.400

    assert_equal 1, Ruote::Dm::DmWorkitem.all.size
    assert_equal 0, @engine.process(wfid).errors.size

    dwi = Ruote::Dm::DmWorkitem.first

    assert_match /^.+|.+|.+$/, dwi.fei
    assert_equal '|params:|ref:alice|participant:alice|toto:nada|', dwi.keywords

    @alice.reply(dwi)

    sleep 0.400

    assert_equal 0, Ruote::Dm::DmWorkitem.all.size
    assert_nil @engine.process(wfid)
  end

  def test_composite_key_field

    @bravo = @engine.register_participant(
      :bravo, Ruote::Dm::DmParticipant, :key_field => '${f:brand} ${f:year}')

    pdef = Ruote::process_definition :name => 'test' do
      bravo
    end

    %w[ alfa-romeo citroen maserati citroen ford toyota ].each do |brand|
      @engine.launch(pdef, :fields => { 'brand' => brand, 'year' => 1970 })
    end

    sleep 0.400

    #p Ruote::Dm::DmWorkitem.all.collect { |dwi| dwi.key_field }

    assert_equal 6, Ruote::Dm::DmWorkitem.all.size
    assert_equal 1, Ruote::Dm::DmWorkitem.all(:key_field => 'ford 1970').size
    assert_equal 2, Ruote::Dm::DmWorkitem.all(:key_field => 'citroen 1970').size
  end
end

