
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
    @engine = Ruote::Engine.new()
    @engine.register_participant :alice, Ruote::Dm::DmParticipant
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

    wfid = @engine.launch(pdef)

    sleep 0.400

    assert_equal 1, Ruote::Dm::DmWorkitem.all.size
    assert_match /^.+|.+|.+$/, Ruote::Dm::DmWorkitem.first.fei
    assert_equal 0, @engine.process(wfid).errors.size
  end
end

