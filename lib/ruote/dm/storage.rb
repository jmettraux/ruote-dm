#--
# Copyright (c) 2005-2010, John Mettraux, jmettraux@gmail.com
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

require 'ruote/storage/base'
require 'ruote/dm/version'


module Ruote
module Dm

  class DmStorage

    include Ruote::StorageBase

    attr_reader :repository

    def initialize (repository=nil, opts={})

      @repository = repository
    end

    def put (doc, opts={})

      #@dbs[doc['type']].put(doc, opts)
    end

    def get (type, key)

      #@dbs[type].get(key)
    end

    def delete (doc)

      #db = @dbs[doc['type']]
      #raise ArgumentError.new("no database for type '#{doc['type']}'") unless db
      #db.delete(doc)
    end

    def get_many (type, key=nil, opts={})

      #@dbs[type].get_many(key, opts)
    end

    #def ids (type)
    #  #@dbs[type].ids
    #end

    def purge!

      #@dbs.values.each { |db| db.purge! }
    end

    #def dump (type)
    #  @dbs[type].dump
    #end

    def shutdown

      #@dbs.values.each { |db| db.shutdown }
    end

    # Mainly used by ruote's test/unit/ut_17_storage.rb
    #
    #def add_type (type)
    #  @dbs[type] = Database.new(
    #    @host, @port, type, "#{@prefix}ruote_#{type}", false)
    #end

    # Nukes a db type and reputs it (losing all the documents that were in it).
    #
    def purge_type! (type)

      #if db = @dbs[type]
      #  db.purge_docs!
      #end
    end

    # A provision made for workitems, allow to query them directly by
    # participant name.
    #
    def by_participant (type, participant_name)

      #raise NotImplementedError if type != 'workitems'
      #@dbs['workitems'].by_participant(participant_name)
    end

    def by_field (type, field, value=nil)

      #raise NotImplementedError if type != 'workitems'
      #@dbs['workitems'].by_field(field, value)
    end
  end
end

