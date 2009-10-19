#--
# Copyright (c) 2005-2009, John Mettraux, jmettraux@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Made in Japan.
#++

require 'dm-core'
require 'dm-aggregates'

require 'ruote/engine/context'
require 'ruote/queue/subscriber'
require 'ruote/storage/base'
require 'ruote/dm/ticket'


module Ruote
module Dm

  #
  # The datamapper resource class for Ruote expressions.
  #
  class DmExpression
    include DataMapper::Resource

    property :fei, String, :key => true
    property :wfid, String, :index => :wfid
    property :expclass, String, :index => :expclass
    property :svalue, Object, :length => 2**32 - 1, :lazy => false

    def as_ruote_expression (context)

      fe = svalue
      fe.context = context

      fe
    end

    # Saves the expression as a DataMapper record.
    #
    # Returns false if the exact same expression is already stored.
    # Returns true if the record got created or updated (exp modified).
    #
    def self.from_ruote_expression (fexp)

      e = DmExpression.first(:fei => fexp.fei.to_s) || DmExpression.new

      e.fei = fexp.fei.to_s
      e.wfid = fexp.fei.parent_wfid
      e.expclass = fexp.class.name
      e.svalue = fexp

      e.save
    end

    # Sets the table name for expressions to 'dm_expressions'.
    #
    def self.storage_name (repository_name=default_repository_name)

      'dm_expressions'
    end
  end

  #
  # DataMapper persistence for Ruote expressions.
  #
  # == Ruote::Dm::DmExpression.auto_upgrade!
  #
  # You might want to run
  #
  #   Ruote::Dm::DmExpression.auto_upgrade!
  #
  # before your first run for Ruote::Dm::DmStorage (usually
  # Ruote::Dm::DmPersistedEngine)
  #
  class DmStorage

    include EngineContext
    include StorageBase
    include Subscriber

    def context= (c)

      @context = c

      @dm_repository =
        c[:expstorage_dm_repository] || c[:dm_repository] || :default

      #DataMapper.repository(@dm_repository) do
      #  DmExpression.auto_upgrade!
      #end
        # this is costly, and it's now left to the integrator

      subscribe(:expressions)
    end

    def find_expressions (query={})

      conditions = {}

      if m = query[:responding_to]
        # NOTE: Using dm-aggregates would be cleaner, but if it's not
        # available then using this SQL directly will be equivalent.
        # It should run on any of DM's adapters, and will work within
        # any defined repositories or field naming conventions.
        expclass_list = if DmExpression.respond_to?(:aggregate)
          DmExpression.aggregate(:expclass, :repository => @dm_repository)
        else
          table = DmExpression.storage_name(@dm_repository)
          field = DmExpression.properties(@dm_repository)[:expclass].field
          DmExpression.repository(@dm_repository).adapter.query("SELECT #{field} FROM #{table} GROUP BY #{field}")
        end.select do |expclass_name|
          ::Object.const_get(expclass_name).instance_methods.include?(m.to_s) rescue false
        end

        return [] if expclass_list.empty?
        conditions[:expclass] = expclass_list
      end

      if i = query[:wfid]
        conditions[:wfid] = i
      end
      if c = query[:class]
        conditions[:expclass] = c.to_s
      end

      DataMapper.repository(@dm_repository) {
        DmExpression.all(conditions)
      }.collect { |e|
        e.as_ruote_expression(@context)
      }

    end

    def []= (fei, fexp)

      DataMapper.repository(@dm_repository) do
        DmExpression.from_ruote_expression(fexp)
      end
    end

    def [] (fei)

      if fexp = find(fei)
        fexp.as_ruote_expression(@context)
      else
        nil
      end
    end

    def delete (fei)

      if e = find(fei)
        e.destroy
      end
    end

    def size

      DataMapper.repository(@dm_repository) do
        #DmExpression.count
          # dm-aggregates is in dm-core and dm-core is no ruby 1.9.1 friend

          # jpr5: 10/16/09: Actually, dm-aggregates is in dm-more.
          # This may have been rectified by now..
        DmExpression.all.size
      end
    end

    # A dangerous method, deletes all the expressions and all the tickets.
    # Mostly used for tearing down test sets.
    #
    def purge!

      DataMapper.repository(@dm_repository) do
        DmExpression.all.destroy!
        Ticket.all.destroy!
      end
    end

    def to_s

      find_expressions.inject('') do |s, fexp|
        s << "#{fexp.fei.to_s} => #{fexp.class}\n"
        s
      end
    end

    #--
    # ticket methods
    #++

    def draw_ticket (fexp)

      Ruote::Dm::Ticket.draw(self.object_id.to_s, fexp.fei.to_s)
    end

    def discard_all_tickets (fei)

      Ruote::Dm::Ticket.discard_all(fei.to_s)
    end

    protected

    def find (fei)

      DataMapper.repository(@dm_repository) do
        DmExpression.first(:fei => fei.to_s)
      end
    end
  end

end
end

