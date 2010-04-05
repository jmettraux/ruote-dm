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

require 'dm-core'
require 'ruote/storage/base'
require 'ruote/dm/version'


module Ruote
module Dm

  class Document
    include DataMapper::Resource

    property :ide, String, :key => true, :length => 2048, :required => true
    property :rev, Integer, :key => true, :required => true
    property :typ, String, :key => true, :required => true
    property :doc, Text, :length => 2**32 - 1, :required => true, :lazy => false

    property :participant_name, String, :length => 512
  end

  #
  # A datamapper-powered storage for ruote.
  #
  #   require 'rubygems'
  #   require 'json' # gem install json
  #   require 'ruote'
  #   require 'ruote-dm' # gem install ruote-dm
  #
  #   #DataMapper.setup(:default, 'sqlite3::memory:')
  #   #DataMapper.setup(:default, 'sqlite3:ruote_test.db')
  #   DataMapper.setup(:default, 'postgres://localhost/ruote_test')
  #
  #   engine = Ruote::Engine.new(
  #     Ruote::Worker.new(
  #       Ruote::Dm::DmStorage.new(:default)))
  #
  class DmStorage

    include Ruote::StorageBase

    attr_reader :repository

    def initialize (repository=nil, options={})

      @options = options
      @repository = repository

      put_configuration
    end

    def put_msg (action, options)

      # put_msg is a unique action, no need for all the complexity of put

      DataMapper.repository(@repository) do

        doc = prepare_msg_doc(action, options)

        d = Document.new(
          :ide => doc['_id'],
          :rev => 1,
          :typ => 'msgs',
          :doc => Rufus::Json.encode(doc.merge(
            '_rev' => 1,
            'put_at' => Ruote.now_to_utc_s))
        ).save
      end

      nil
    end

    def put_schedule (flavour, owner_fei, s, msg)

      # put_schedule is a unique action, no need for all the complexity of put

      if doc = prepare_schedule_doc(flavour, owner_fei, s, msg)

        DataMapper.repository(@repository) do

          d = Document.new(
            :ide => doc['_id'],
            :rev => 1,
            :typ => 'schedules',
            :doc => Rufus::Json.encode(doc.merge(
              '_rev' => 1,
              'put_at' => Ruote.now_to_utc_s))
          ).save

          return doc['_id']
        end
      end

      nil
    end

    def put (doc, opts={})

      DataMapper.repository(@repository) do

        d = Document.first(
          :typ => doc['type'], :ide => doc['_id'], :order => :rev.desc)

        rev = doc['_rev'].to_i
        current_rev = d ? d.rev : 0

        return true if current_rev == 0 && rev > 0
        return Rufus::Json.decode(d.doc) if d && rev != current_rev

        nrev = rev + 1

        Document.new(
          :ide => doc['_id'],
          :rev => nrev,
          :typ => doc['type'],
          :doc => Rufus::Json.encode(doc.merge(
            '_rev' => nrev, 'put_at' => Ruote.now_to_utc_s)),
          :participant_name => doc['participant_name']
        ).save

        d.destroy! if d

        doc['_rev'] = nrev if opts[:update_rev]

        nil
      end
    end

    def get (type, key)

      DataMapper.repository(@repository) do
        d = Document.first(:typ => type, :ide => key, :order => :rev.desc)
        d ? Rufus::Json.decode(d.doc) : nil
      end
    end

    def delete (doc)

      raise ArgumentError.new('no _rev for doc') unless doc['_rev']

      DataMapper.repository(@repository) do

        d = Document.first(
          :typ => doc['type'], :ide => doc['_id'], :rev => doc['_rev'])

        return true unless d

        d.destroy! ? nil : true
      end
    end

    def get_many (type, key=nil, opts={})

      q = { :typ => type }

      if l = opts[:limit]
        q[:limit] = l
      end

      if key
        q[:ide.like] = if m = key.source.match(/(.+)\$$/)
          "%#{m[1]}"
        elsif m = key.source.match(/^\^(.+)/)
          "#{m[1]}%"
        else
          "%#{key.source}%"
        end
      end

      DataMapper.repository(@repository) do
        Document.all(q).collect { |d| Rufus::Json.decode(d.doc) }
      end
    end

    def ids (type)

      DataMapper.repository(@repository) do
        Document.all(:typ => type).collect { |d| d.ide }
      end
    end

    def purge!

      DataMapper.repository(@repository) do
        Document.all.destroy!
      end
    end

    def dump (type)

      s = "=== #{type} ===\n"

      get_many(type).inject(s) do |s1, h|
        s1 << "  #{Ruote::FlowExpressionId.to_storage_id(h['fei'])}"
        s1 << " => #{h['original_tree'].first} #{h['_rev']}\n"
      end
    end

    def shutdown

      #@dbs.values.each { |db| db.shutdown }
    end

    # Mainly used by ruote's test/unit/ut_17_storage.rb
    #
    def add_type (type)

      # does nothing, types are differentiated by the 'typ' column
    end

    # Nukes a db type and reputs it (losing all the documents that were in it).
    #
    def purge_type! (type)

      DataMapper.repository(@repository) do
        Document.all(:typ => type).destroy!
      end
    end

    # A provision made for workitems, allow to query them directly by
    # participant name.
    #
    def by_participant (type, participant_name)

      raise NotImplementedError if type != 'workitems'

      Document.all(
        :typ => type, :participant_name => participant_name
      ).collect { |d|
        Rufus::Json.decode(d.doc)
      }
    end

    # Querying workitems by field (warning, goes deep into the JSON structure)
    #
    def by_field (type, field, value=nil)

      raise NotImplementedError if type != 'workitems'

      like = [ '%"', field, '":' ]
      like.push(Rufus::Json.encode(value)) if value
      like.push('%')

      Document.all(:typ => type, :doc.like => like.join).collect { |d|
        Rufus::Json.decode(d.doc)
      }
    end

    def query_workitems (criteria)

      offset = criteria.delete('offset')
      limit = criteria.delete('limit')

      wfid =
        criteria.delete('wfid')
      pname =
        criteria.delete('participant_name') || criteria.delete('participant')

      cr = { :typ => 'workitems' }

      cr[:ide.like] = "%!#{wfid}" if wfid
      cr[:offset] = offset if offset
      cr[:limit] = limit if limit
      cr[:participant_name] = pname if pname

      likes = criteria.collect do |k, v|
        "%\"#{k}\":#{Rufus::Json.encode(v)}%"
      end
      cr[:conditions] = [
        ([ 'doc LIKE ?' ] * likes.size).join(' AND '), *likes
      ] unless likes.empty?

      Document.all(cr).collect { |d|
        Ruote::Workitem.new(Rufus::Json.decode(d.doc))
      }
    end

    protected

    # Don't put configuration if it's already in
    #
    # (avoid storages from trashing configuration...)
    #
    def put_configuration

      return if get('configurations', 'engine')

      conf = { '_id' => 'engine', 'type' => 'configurations' }.merge(@options)
      put(conf)
    end
  end
end
end

