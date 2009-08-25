
#
# Testing ruote-dm
#
# Tue Aug 25 13:34:05 JST 2009
#

require File.join(File.dirname(__FILE__), 'test_helper.rb')

require 'ruote/dm/exclusive'


class ExclusiveTest < Test::Unit::TestCase

  def setup
  end
  def teardown
    Ruote::Dm::Lock.all.destroy!
  end

  def test_one_lock

    lock = Ruote::Dm.lock('locker', 'locked')

    assert_not_nil lock
    assert_equal true, lock.locked?
  end

  def test_two_locks

    l0 = Ruote::Dm.lock('locker0', 'locked')
    l1 = Ruote::Dm.lock('locker1', 'locked')

    assert_equal false, l1.locked?
    assert_equal true, l0.locked?

    l0.destroy

    assert_equal true, l1.locked?
  end
end

