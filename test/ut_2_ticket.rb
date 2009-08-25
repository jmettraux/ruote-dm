
#
# Testing ruote-dm
#
# Tue Aug 25 13:34:05 JST 2009
#

require File.join(File.dirname(__FILE__), 'test_helper.rb')

#require 'ruote/dm/ticket'


class ExclusiveTest < Test::Unit::TestCase

  def setup
    Ruote::Dm::Ticket.all.destroy!
  end
  def teardown
    Ruote::Dm::Ticket.all.destroy!
  end

  def test_one_ticket

    ticket = Ruote::Dm::Ticket.draw('ticketer', 'target')

    #p ticket

    assert_not_nil ticket
    assert_not_nil ticket.created_at
    assert_equal true, ticket.consumable?
  end

  def test_two_tickets

    l0 = Ruote::Dm::Ticket.draw('ticketer0', 'target')
    l1 = Ruote::Dm::Ticket.draw('ticketer1', 'target')

    assert_equal false, l1.consumable?
    assert_equal true, l0.consumable?

    l0.destroy

    assert_equal true, l1.consumable?
  end

  def test_same_same

    Ruote::Dm::Ticket.draw('ticketer1', 'target')
    Ruote::Dm::Ticket.draw('ticketer1', 'target')

    assert_equal 1, Ruote::Dm::Ticket.all.size
  end

  def test_wait

    time_line = []

    job = lambda do |holder, sec|

      begin
        ticket = Ruote::Dm::Ticket.draw(holder, 'target')

        loop do
          time_line << [ holder, :drawn, ticket.id ]

          sleep(sec)
          time_line << [ holder, :woke_up ]

          time_line << [ holder, :consumable?, ticket.consumable? ]

          if ticket.consumable?
            time_line << [ holder, :job_done ]
            ticket.consume
            break
          end

          time_line << [ holder, :passing ]
          sleep 0.100
        end
      rescue Exception => e
        p e
      end
    end

    t0 = Thread.new { job.call('a', 0.10) }
    t1 = Thread.new { job.call('b', 0.05) }

    sleep 1

    assert_equal 0, Ruote::Dm::Ticket.all.size

    #time_line.each { |e| p e }

    assert_equal 1, time_line.select { |e| e == [ 'a', :job_done ] }.size
    assert_equal 1, time_line.select { |e| e == [ 'b', :job_done ] }.size
  end
end

