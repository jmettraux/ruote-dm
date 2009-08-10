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

require 'base64'
require 'dm-core'
require 'dm-types'

require 'ruote/engine/context'
require 'ruote/part/local_participant'


module Ruote
module Dm

  #
  # Wrapping a ruote Workitem for inserstion in a DataMapper repository.
  #
  class DmWorkitem
    include DataMapper::Resource

    property :fei, String, :key => true
    property :wfid, String, :index => :wfid, :nullable => false
    property :engine_id, String, :index => :engine_id, :nullable => false
    property :participant_name, String, :index => :participant_name, :nullable => false

    property :wi_fields, Yaml, :nullable => false
    property :keywords, Text, :nullable => false

    property :dispatch_time, DateTime, :nullable => false
    property :last_modified, DateTime, :nullable => false

    property :store_name, String, :index => :store_name

    before :save, :pre_save

    # Turns this Ruote::Dm::DmWorkitem instance into a Ruote::Workitem
    # instance.
    #
    def to_ruote_workitem

      wi = Ruote::Workitem.new

      wi.fei = Ruote::FlowExpressionId.from_s(fei)
      wi.fields = wi_fields
      wi.participant_name = participant_name

      class << wi
        attr_reader :dispatch_time, :last_modified
      end
      wi.instance_variable_set(:@dispatch_time, dispatch_time)
      wi.instance_variable_set(:@last_modified, last_modified)
        #
        # not sure about that...

      wi
    end

    def self.from_ruote_workitem (workitem, store_name=nil)

      wi = DmWorkitem.first(:fei => fei.to_s) || DmWorkitem.new

      wi.fei = workitem.fei.to_s
      wi.wfid = workitem.fei.parent_wfid
      wi.engine_id = workitem.fei.engine_id
      wi.participant_name = workitem.participant_name
      wi.wi_fields = workitem.fields

      wi.dispatch_time ||= Time.now

      #wi.keywords = ...
      #wi.last_modified = Time.now
        # done by DmWorkitem#save

      wi.store_name = store_name

      wi.save
    end

    def self.search (query, store_names=nil)
    #def self.search (query, store_names)

      opts = {}
      opts[:keywords.like] = "%#{query}%"
      opts[:store_name] = Array(store_names) if store_names

      DmWorkitem.all(opts)
    end

    # Sets the table name for the workitems to 'dm_workitems'.
    #
    def self.storage_name (repository_name=default_repository_name)

      'dm_workitems'
    end

    protected

    # Steps done before the actual #save
    #
    def pre_save

      self.last_modified = Time.now
      self.keywords = determine_keywords(participant_name, wi_fields)
    end

    def determine_keywords (pname, fields)

      dk(fields.merge('participant' => pname)).gsub(/\|+/, '|')
    end

    def dk (o)

      case o
      when Hash
        "|#{o.keys.sort.collect { |k| "#{dk(k)}:#{dk(o[k])}" }.join('|')}|"
      when Array
        "|#{o.collect { |e| dk(e) }.join('|')}|"
      else
        o.to_s.gsub(/[\|:]/, '')
      end
    end
  end

  #
  # This participant will store ruote workitems into a DataMapper repository.
  #
  # Two initialization options are recognized : :dm_repository, the name of a
  # DataMapper configured repository (defaults to :default) and :store_name,
  # an optional store_name to differentiate workitems stored by this participant
  # from other workitems stored by other participants in the same DataMapper
  # repository.
  #
  #     alice = engine.register_participant(
  #       'alice',
  #       Ruote::Dm::DmParticipant.new(
  #         :store_name => 'engineers',
  #         :dm_repository => 'whateversql'))
  #
  # or simply
  #
  #     alice = engine.register_participant('bob', Ruote::Dm::DmParticipant)
  #
  class DmParticipant

    include EngineContext
    include LocalParticipant

    attr_reader :store_name
    attr_accessor :dm_repository

    def initialize (opts)

      @store_name = opts[:store_name]
      @dm_repository = opts[:dm_repository] || :default

      DataMapper.repository(@dm_repository) do
        DmWorkitem.auto_upgrade!
      end
    end

    # Method called by the workflow engine directly.
    #
    def consume (workitem)

      DataMapper.repository(@dm_repository) do
        DmWorkitem.from_ruote_workitem(workitem, @store_name)
      end
    end

    # Method called by the workflow engine directly.
    #
    def cancel (fei, flavour)

      destroy(fei)
    end

    # Let the participant remove the workitem from the DataMapper repository
    # and reply to the engine (with the workitem that will resume in its flow).
    #
    def reply (workitem)

      destroy(workitem.fei)
      reply_to_engine(workitem)
    end

    def size

      all.size
    end

    def purge

      all.destroy!
    end

    protected

    def find (fei)

      DataMapper.repository(@dm_repository) do
        DmWorkitem.first(:fei => fei.to_s)
      end
    end

    def destroy (fei)

      if wi = find(fei)
        wi.destroy
      end
    end

    def all

      DataMapper.repository(@dm_repository) do
        opts = {}
        opts[:store_name] = @store_name if @store_name
        DmWorkitem.all(opts)
      end
    end
  end
end
end

