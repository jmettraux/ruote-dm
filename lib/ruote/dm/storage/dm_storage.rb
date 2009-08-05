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

      subscribe(:expressions)
    end

    def find_expressions (query={})

      # TODO : implement me

      # query[:wfid]
      # query[:class]

      # query[:responding_to]
    end

    def []= (fei, fexp)

      # TODO : implement me
    end

    def [] (fei)

      # TODO : implement me
    end

    def delete (fei)

      # TODO : implement me
    end

    def size

      all_filenames.size
    end

    def to_s

      all_filenames.inject('') do |s, fn|
        fexp = load_fexp(fn)
        s << "#{fn} => #{fexp.class}\n"
      end
    end
  end

end
end

