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

  #
  # All the ruote data is stored in a single ruote_dm_document table.
  #
  # The doc/data itself is stored in the 'doc' column, as JSON.
  #
  # Yajl-ruby is recommended for fast {de|en}coding with JSON.
  #
  class Document
    include DataMapper::Resource

    property :ide, String, :key => true, :length => 255, :required => true
    property :rev, Integer, :key => true, :required => true
    property :typ, String, :key => true, :required => true
    property :doc, Text, :length => 2**32 - 1, :required => true, :lazy => false

    property :wfid, String, :index => true
    property :participant_name, String, :length => 512

    def to_h
      Rufus::Json.decode(doc)
    end
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
  class Storage

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

        insert(doc, 1)
      end

      nil
    end

    def put_schedule (flavour, owner_fei, s, msg)

      # put_schedule is a unique action, no need for all the complexity of put

      doc = prepare_schedule_doc(flavour, owner_fei, s, msg)

      return nil unless doc

      DataMapper.repository(@repository) do

        insert(doc, 1)

        doc['_id']
      end
    end

    def put (doc, opts={})

      DataMapper.repository(@repository) do

        current = do_get(doc['type'], doc['_id'])

        rev = doc['_rev'].to_i

        return true if current.nil? && rev > 0
        return current.to_h if current && rev != current.rev

        nrev = rev + 1

        begin

          insert(doc, nrev)

          current.destroy! if current

          doc['_rev'] = nrev if opts[:update_rev]

          return nil

        rescue DataObjects::IntegrityError => ie
          #p :clash
        end

        get(doc['type'], doc['_id'])
      end
    end

    def get (type, key)

      DataMapper.repository(@repository) do
        d = do_get(type, key)
        d ? d.to_h : nil
      end
    end

    def delete (doc)

      raise ArgumentError.new('no _rev for doc') unless doc['_rev']

      DataMapper.repository(@repository) do

        r = put(doc)

        #p [ 0, true, doc['_id'], Thread.current.object_id.to_s[-3..-1] ] if r

        return true unless r.nil?

        r = Document.all(:typ => doc['type'], :ide => doc['_id']).destroy!

        #p [ 1, r ? nil : true, doc['_id'], Thread.current.object_id.to_s[-3..-1] ]

        r ? nil : true
      end
    end

    def get_many (type, key=nil, opts={})

      q = { :typ => type }

      if l = opts[:limit]; q[:limit] = l; end
      if s = opts[:skip]; q[:offset] = s; end

      keys = key ? Array(key) : nil
      q[:wfid] = keys if keys && keys.first.is_a?(String)

      DataMapper.repository(@repository) do

        return Document.all(q).count if opts[:count]

        docs = Document.all(q)
        docs = docs.reverse if opts[:descending]
        docs = docs.collect { |d| d.to_h }

        keys && keys.first.is_a?(Regexp) ?
          docs.select { |doc| keys.find { |key| key.match(doc['_id']) } } :
          docs
      end
    end

    def ids (type)

      DataMapper.repository(@repository) do
        Document.all(:typ => type).collect { |d| d.ide }.sort
      end
    end

    def purge!

      DataMapper.repository(@repository) do
        Document.all.destroy!
      end
    end

    def dump (type)

      "=== #{type} ===\n" +
      get_many(type).map { |h| "  #{h['_id']} => #{h.inspect}" }.join("\n")
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
    def by_participant (type, participant_name, opts)

      raise NotImplementedError if type != 'workitems'

      query = {
        :typ => type, :participant_name => participant_name
      }.merge(opts)

      Document.all(query).collect { |d| d.to_h }
    end

    # Querying workitems by field (warning, goes deep into the JSON structure)
    #
    def by_field (type, field, value=nil)

      raise NotImplementedError if type != 'workitems'

      like = [ '%"', field, '":' ]
      like.push(Rufus::Json.encode(value)) if value
      like.push('%')

      Document.all(:typ => type, :doc.like => like.join).collect { |d| d.to_h }
    end

    def query_workitems (criteria)

      cr = { :typ => 'workitems' }

      return Document.all(cr).count if criteria['count']

      offset = criteria.delete('offset')
      limit = criteria.delete('limit')

      wfid =
        criteria.delete('wfid')
      pname =
        criteria.delete('participant_name') || criteria.delete('participant')

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

      Document.all(cr).collect { |d| Ruote::Workitem.new(d.to_h) }
    end

    protected

    def insert (doc, rev)

      Document.new(
        :ide => doc['_id'],
        :rev => rev,
        :typ => doc['type'],
        :doc => Rufus::Json.encode(doc.merge(
          '_rev' => rev,
          'put_at' => Ruote.now_to_utc_s)),
        :wfid => extract_wfid(doc),
        :participant_name => doc['participant_name']
      ).save!
    end

    def extract_wfid (doc)

      doc['wfid'] || (doc['fei'] ? doc['fei']['wfid'] : nil)
    end

    def do_get (type, key)

      Document.first(:typ => type, :ide => key, :order => :rev.desc)
    end

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

  #
  # Ruote::Dm::Storage should be used, but until ruote-dm 2.1.12, it
  # was Ruote::Dm::DmStorage. This class is here for 'backward compatibility'.
  #
  class DmStorage < Storage
  end
end
end

