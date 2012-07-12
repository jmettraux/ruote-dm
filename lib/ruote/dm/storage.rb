#--
# Copyright (c) 2005-2012, John Mettraux, jmettraux@gmail.com
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

    def to_wi
      Ruote::Workitem.from_json(doc)
    end

    def <=>(other)
      self.ide <=> other.ide
    end
  end

  # Seems like DataMapper 1.2 wants that
  #
  DataMapper.finalize

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
  #       Ruote::Dm::Storage.new(:default)))
  #
  class Storage

    include Ruote::StorageBase

    attr_reader :repository

    def initialize(repository=nil, options={})

      #@options = options
      @repository = repository

      replace_engine_configuration(options)
    end

    def put_msg(action, options)

      # put_msg is a unique action, no need for all the complexity of put

      DataMapper.repository(@repository) do

        do_insert(prepare_msg_doc(action, options) , 1)
      end

      nil
    end

    def put_schedule(flavour, owner_fei, s, msg)

      # put_schedule is a unique action, no need for all the complexity of put

      doc = prepare_schedule_doc(flavour, owner_fei, s, msg)

      return nil unless doc

      DataMapper.repository(@repository) do

        do_insert(doc, 1)

        doc['_id']
      end
    end

    def put(doc, opts={})

      DataMapper.repository(@repository) do

        if doc['_rev']

          d = get(doc['type'], doc['_id'])

          return true unless d
          return d if d['_rev'] != doc['_rev']
            # failures
        end

        nrev = doc['_rev'].to_i + 1

        begin

          do_insert(doc, nrev)

        rescue DataObjects::IntegrityError => ie

          return (get(doc['type'], doc['_id']) || true)
            # failure
        end

        Document.all(
          :typ => doc['type'], :ide => doc['_id'], :rev.lt => nrev
        ).destroy

        doc['_rev'] = nrev if opts[:update_rev]

        nil
          # success
      end
    end

    def get(type, key)

      DataMapper.repository(@repository) do

        d = do_get(type, key)

        d ? d.to_h : nil
      end
    end

    def delete(doc)

      raise ArgumentError.new('no _rev for doc') unless doc['_rev']

      count = DataMapper.repository(@repository).adapter.delete(
        Document.all(:typ => doc['type'], :ide => doc['_id']))

      return (get(doc['type'], doc['_id']) || true) if count < 1

      nil
        # success
    end

    def get_many(type, key=nil, opts={})

      q = { :typ => type }

      if l = opts[:limit]; q[:limit] = l; end
      if s = opts[:skip]; q[:offset] = s; end

      keys = key ? Array(key) : nil
      q[:wfid] = keys if keys && keys.first.is_a?(String)

      q[:order] = (
        opts[:descending] ? [ :ide.desc, :rev.desc ] : [ :ide.asc, :rev.asc ]
      ) unless opts[:count]

      DataMapper.repository(@repository) do

        return select_last_revs(Document.all(q)).size if opts[:count]

        docs = Document.all(q)
        docs = select_last_revs(docs, opts[:descending])
        docs = docs.collect { |d| d.to_h }

        keys && keys.first.is_a?(Regexp) ?
          docs.select { |doc| keys.find { |key| key.match(doc['_id']) } } :
          docs
      end
    end

    def ids(type)

      DataMapper.repository(@repository) do

        Document.all(:typ => type).collect { |d| d.ide }.uniq.sort
      end
    end

    def purge!

      DataMapper.repository(@repository) do

        Document.all.destroy!
      end
    end

    def shutdown

      #@dbs.values.each { |db| db.shutdown }
    end

    # Mainly used by ruote's test/unit/ut_17_storage.rb
    #
    def add_type(type)

      # does nothing, types are differentiated by the 'typ' column
    end

    # Nukes a db type and reputs it (losing all the documents that were in it).
    #
    def purge_type!(type)

      DataMapper.repository(@repository) do

        Document.all(:typ => type).destroy!
      end
    end

    # A provision made for workitems, allow to query them directly by
    # participant name.
    #
    def by_participant(type, participant_name, opts={})

      raise NotImplementedError if type != 'workitems'

      count = opts.delete(:count)
      skip = opts.delete(:skip)
      opts[:offset] = skip if skip

      query = {
        :typ => type, :participant_name => participant_name
      }.merge(opts)

      res = select_last_revs(Document.all(query))

      count ? res.size : res.collect { |d| d.to_wi }
    end

    # Querying workitems by field (warning, goes deep into the JSON structure)
    #
    def by_field(type, field, value, opts={})

      raise NotImplementedError if type != 'workitems'

      count = opts.delete(:count)
      skip = opts.delete(:skip)
      opts[:offset] = skip if skip

      like = [ '%"', field, '":' ]
      like.push(Rufus::Json.encode(value)) if value
      like.push('%')

      res = Document.all({ :typ => type, :doc.like => like.join }.merge(opts))
      res = select_last_revs(res)

      count ? res.size : res.collect { |d| d.to_wi }
    end

    def query_workitems(criteria)

      cr = { :typ => 'workitems' }

      count = criteria.delete('count')

      offset = criteria.delete('offset') || criteria.delete('skip')
      limit = criteria.delete('limit')

      wfid =
        criteria.delete('wfid')
      pname =
        criteria.delete('participant_name') || criteria.delete('participant')

      cr[:ide.like] = "%!#{wfid}" if wfid
      cr[:offset] = offset if offset
      cr[:limit] = limit if limit
      cr[:participant_name] = pname if pname

      likes = criteria.collect { |k, v|
        "%\"#{k}\":#{Rufus::Json.encode(v)}%"
      }
      cr[:conditions] = [
        ([ 'doc LIKE ?' ] * likes.size).join(' AND '), *likes
      ] unless likes.empty?

      res = select_last_revs(Document.all(cr))

      count ? res.size : res.collect { |d| d.to_wi }
    end

    protected

    def do_insert(doc, rev)

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

    def extract_wfid(doc)

      doc['wfid'] || (doc['fei'] ? doc['fei']['wfid'] : nil)
    end

    def do_get(type, key)

      Document.first(:typ => type, :ide => key, :order => :rev.desc)
    end

    def select_last_revs(docs, reverse=false)

      docs = docs.inject({}) { |h, doc| h[doc.ide] = doc; h }.values.sort

      reverse ? docs.reverse : docs
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

