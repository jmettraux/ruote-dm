
#
# Testing ruote-dm
#
# Sat Oct  3 13:36:33 JST 2009
#

require File.join(File.dirname(__FILE__), 'test_helper.rb')

require 'ruote/engine'
require 'ruote/dm/err/dm_errorjournal'


class FtErrorJournalTest < Test::Unit::TestCase

  class TestEngine < Ruote::FsPersistedEngine
    def build_error_journal
      add_service(:s_ejournal, Ruote::Dm::DmErrorJournal)
    end
  end

  def setup
    @engine = TestEngine.new
  end
  def teardown
    @engine.shutdown
    DataMapper.repository(:default) do
      Ruote::Dm::DmProcessError.all.destroy!
    end
    FileUtils.rm_rf('work')
  end

  def test_error_and_replay

    pdef = Ruote::process_definition :name => 'test' do
      nada
    end

    wfid = @engine.launch(pdef)

    sleep 0.400

    assert_equal 1, Ruote::Dm::DmProcessError.all.size
    assert_equal 1, @engine.process(wfid).errors.size

    assert_equal(
      "unknown expression 'nada'",
      @engine.process(wfid).errors.first.error_message)

    seen = false

    @engine.register_participant :nada do |workitem|
      seen = true
    end

    @engine.replay_at_error(@engine.process(wfid).errors.first)

    sleep 0.400

    assert_equal true, seen # longish, but I prefer the fail message

    assert_nil @engine.process(wfid)
  end

  def test_error_on_replay

    pdef = Ruote::process_definition :name => 'test' do
      nada
    end

    wfid = @engine.launch(pdef)

    sleep 0.400

    first_time = Ruote::Dm::DmProcessError.first.created_at

    sleep 1.010

    @engine.replay_at_error(@engine.process(wfid).errors.first)

    sleep 0.400

    assert_equal 1, Ruote::Dm::DmProcessError.all.size
    assert_equal 1, @engine.process(wfid).errors.size

    assert_not_equal first_time, Ruote::Dm::DmProcessError.first.created_at
  end

  def test_process_cancellation

    pdef = Ruote::process_definition :name => 'test' do
      nada
    end

    wfid = @engine.launch(pdef)

    sleep 0.400

    assert_equal 1, Ruote::Dm::DmProcessError.all.size

    @engine.cancel_process(wfid)

    sleep 0.400

    assert_nil @engine.process(wfid)
    assert_equal 0, Ruote::Dm::DmProcessError.all.size
  end
end

