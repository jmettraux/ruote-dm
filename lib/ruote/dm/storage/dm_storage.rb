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
require 'ruote/queue/subscriber'
require 'ruote/storage/base'


module Ruote
module Dm

  #
  # The datamapper resource class for Ruote expressions.
  #
  class DmExpression
    include DataMapper::Resource

    property :fei, String, :key => true
    property :wfid, String, :index => :wfid
    property :expid, String, :index => :expid
    property :expclass, String, :index => :expclass
    property :svalue, Text

    def svalue= (fexp)

      attribute_set(:svalue, Base64.encode64(Marshal.dump(fexp)))
    end

    def as_ruote_expression (context)

      fe = Marshal.load(Base64.decode64(self.svalue))
      fe.context = context
      fe
    end

    def self.storage_name (repository_name = default_repository_name)

      'dm_expressions'
    end
  end

  #
  # DataMapper persistence for Ruote expressions.
  #
  class DmStorage

    include EngineContext
    include StorageBase
    include Subscriber

    def context= (c)

      @context = c

      @dm_repository = c[:expstorage_dm_repository] || :default

      DataMapper.repository(@dm_repository) do
        DmExpression.auto_upgrade!
      end

      subscribe(:expressions)
    end

    def find_expressions (query={})

      # TODO : implement me

      # query[:wfid]
      # query[:class]

      # query[:responding_to]
    end

    def []= (fei, fexp)

      DataMapper.repository(@dm_repository) do

        e = find(fei) || DmExpression.new

        e.fei = fei.to_s
        e.wfid = fei.parent_wfid
        e.expid = fei.expid
        e.expclass = fexp.class.name
        e.svalue = fexp

        e.save
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
        DmExpression.all.size # dm 0.9 :(
      end
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

