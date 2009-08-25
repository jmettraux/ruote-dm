
#
# Testing ruote-dm
#
# Tue Aug 25 13:34:05 JST 2009
#

require File.join(File.dirname(__FILE__), 'test_helper.rb')

#require 'ruote/dm/lock'


class ExclusiveTest < Test::Unit::TestCase

  def setup
    Ruote::Dm::Lock.all.destroy!
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

  def test_wait

    time_line = []

    job = lambda do |locker, sec|

      lock = Ruote::Dm.lock(locker, 'locked')

      loop do
        time_line << [ locker, :acquired, lock.id ]

        sleep(sec)
        time_line << [ locker, :woke_up ]

        time_line << [ locker, :locked?, lock.locked? ]

        if lock.locked?
          time_line << [ locker, :job_done ]
          lock.destroy
          break
        end

        time_line << [ locker, :passing ]
        sleep 0.100
      end
    end

    t0 = Thread.new { job.call('a', 0.1) }
    t1 = Thread.new { job.call('b', 0.05) }

    sleep 1

    assert_equal 0, Ruote::Dm::Lock.all.size

    #time_line.each { |e| p e }

    assert_equal 1, time_line.select { |e| e == [ 'a', :job_done ] }.size
    assert_equal 1, time_line.select { |e| e == [ 'b', :job_done ] }.size
  end
end

