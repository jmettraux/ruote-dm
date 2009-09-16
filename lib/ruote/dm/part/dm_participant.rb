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

require 'ruote/engine/context'
require 'ruote/part/local_participant'
require 'ruote/util/json'
require 'ruote/dm/error'


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

    property :wi_fields, Text, :length => 2**32 - 1, :nullable => false
    property :keywords, Text, :length => 2**32 - 1, :nullable => false
    property :key_field, String, :index => :key_field, :nullable => true

    property :dispatch_time, DateTime, :nullable => false
    property :last_modified, DateTime, :nullable => false

    property :store_name, String, :index => :store_name

    # Turns this Ruote::Dm::DmWorkitem instance into a Ruote::Workitem
    # instance.
    #
    def to_ruote_workitem

      wi = Ruote::Workitem.new

      wi.fei = Ruote::FlowExpressionId.from_s(fei)
      wi.fields = Ruote::Json.decode(wi_fields)
      wi.participant_name = participant_name

      wi
    end

    def self.from_ruote_workitem (workitem, opts={})

      store_name = opts[:store_name]
      key_field = opts[:key_field]

      wi = self.first(:fei => workitem.fei.to_s) || self.new

      wi.fei = workitem.fei.to_s
      wi.wfid = workitem.fei.parent_wfid
      wi.engine_id = workitem.fei.engine_id
      wi.participant_name = workitem.participant_name

      wi.wi_fields = Ruote::Json.encode(workitem.fields)

      wi.dispatch_time ||= Time.now
      wi.last_modified = Time.now

      wi.keywords = determine_keywords(
        workitem.participant_name, workitem.fields)

      wi.store_name = store_name
      wi.key_field = key_field

      wi.save || raise(Ruote::Dm::Error.new('failed to save', wi))
    end

    def self.search (query, store_names=nil)

      opts = {}
      opts[:keywords.like] = "%#{query}%"
      opts[:store_name] = Array(store_names) if store_names

      self.all(opts)
    end

    # Sets the table name for the workitems to 'dm_workitems'.
    #
    def self.storage_name (repository_name=default_repository_name)

      'dm_workitems'
    end

    protected

    def self.determine_keywords (pname, fields)

      dk(fields.merge('participant' => pname)).gsub(/\|+/, '|')
    end

    def self.dk (o)

      case o
      when Hash
        keys = o.keys.collect { |k| k.to_s }.sort
        "|#{keys.collect { |k| "#{dk(k)}:#{dk(o[k])}" }.join('|')}|"
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
  #   alice = engine.register_participant(
  #     'alice',
  #     Ruote::Dm::DmParticipant.new(
  #       :store_name => 'engineers',
  #       :dm_repository => 'whateversql'))
  #
  # or simply
  #
  #   alice = engine.register_participant('bob', Ruote::Dm::DmParticipant)
  #
  # == :key_field
  #
  # The DmParticipant understands a :key_field option when
  # initialized/registered.
  #
  #   alice = engine.register_participant(
  #     :alice, Ruote::Dm::DmParticipant, :key_field => 'brand')
  #
  # This alice participant will place the value in the workitem field named
  # 'brand' in the key_field column of the Ruote::Dm::DmWorkitem.
  #
  # This key_field column is indexed and should thus be efficiently queried.
  #
  # Note that :key_field can leverage composite values.
  #
  #   bob = engine.register_participant(
  #     :bob, Ruote::Dm::DmParticipant, :key_field => '${brand} ${year}')
  #
  # For bob, the key_field column will hold a concatenation of the workitem
  # field 'brand', a space and the workitem field 'year'.
  #
  # This technique may also be used to look deeper into workitems :
  #
  #   charly = engine.register_participant(
  #     :charly, Ruote::Dm::DmParticipant, :key_field => '${car.brand}')
  #
  # For a workitem whose payload look like
  #
  #   { 'car' => { 'brand' => 'toyota', :type => 'prius' }, 'dossier' => 3423 }
  #
  # You can also use that trick to do things like
  #
  #   doug = engine.register_participant(
  #     :doug, Ruote::Dm::DmParticipant, :key_field => 'brand::${brand}')
  #   elsa = engine.register_participant(
  #     :elsa, Ruote::Dm::DmParticipant, :key_field => 'rank::${rank}')
  #
  # That adds a bit more of info to the key_field value, even if there's only
  # one workitem field involved.
  #
  #
  # == :dm_workitem_class
  #
  # Perhaps not the best option to change !
  #
  # By default, DmParticipant uses Ruote::Dm::DmWorkitem
  # (a DataMapper::Resource extending class) to store workitems.
  #
  # Provided this other class as a class method .from_ruote_workitem(wi), and
  # replies to #all, #first and .autoupgrade! as a DataMapper::Resource does,
  # it's OK to set another class.
  #
  #   fred = engine.register_participant(
  #     'fred',
  #     Ruote::Dm::DmParticipant,
  #     :dm_workitem_class => MyRuote::DmWorkitem)
  #
  # Use at your own risk !
  #
  #
  # == Ruote::Dm::DmWorkitem.auto_upgrade!
  #
  # You might want to run
  #
  #   Ruote::Dm::DmWorkitem.auto_upgrade!
  #
  # before registering any DmParticipant in the engine, in order to prepare
  # the database table.
  #
  #   DataMapper.repository(:my_repository) do
  #     Ruote::Dm::DmWorkitem.auto_upgrade!
  #   end
  #
  class DmParticipant

    include EngineContext
    include LocalParticipant

    attr_reader :store_name
    attr_accessor :dm_repository

    def initialize (opts)

      @store_name = opts[:store_name]
      @dm_repository = opts[:dm_repository] || :default
      @key_field = opts[:key_field]
      @dm_workitem_class = opts[:dm_workitem_class] || Ruote::Dm::DmWorkitem

      #DataMapper.repository(@dm_repository) do
      #  @dm_workitem_class.auto_upgrade!
      #end
        #
        # not Ruote::Dm::DmParticipant responsibility anymore
    end

    # Method called by the workflow engine directly.
    #
    def consume (workitem)

      DataMapper.repository(@dm_repository) do

        kf = if @key_field and expstorage and @key_field.match(/\$\{[^\}]+\}/)
          Ruote.dosub(@key_field, expstorage[workitem.fei], workitem)
        elsif @key_field
          workitem.fields[@key_field]
        else
          nil
        end

        kf = kf ? kf.to_s : nil

        @dm_workitem_class.from_ruote_workitem(
          workitem, :store_name => @store_name, :key_field => kf)
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

      workitem = workitem.to_ruote_workitem \
        if workitem.respond_to?(:to_ruote_workitem)

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
        @dm_workitem_class.first(:fei => fei.to_s)
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
        @dm_workitem_class.all(opts)
      end
    end
  end
end
end

