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

require 'ruote/err/ejournal'


module Ruote
module Dm

  #
  # Storing process errors in DataMapper.
  #
  class DmProcessError
    include DataMapper::Resource

    property :fei, String, :key => true
    property :wfid, String, :index => :wfid
    property :created_at, DateTime, :nullable => false
    property :svalue, Object, :length => 2**32 - 1, :lazy => false
  end

  #
  # Stores process errors in DataMapper for a ruote engine.
  #
  # Uses the dm repository specified in the engine option
  # :ejournal_dm_repository or :dm_repository
  #
  # Those error journal classes are never used directly (hence the poor rdoc).
  #
  class DmErrorJournal < Ruote::HashErrorJournal

    def context= (c)

      @context = c
      subscribe(:errors)

      @dm_repository =
        c[:ejournal_dm_repository] || c[:dm_repository] || :default
    end

    #
    # Returns a collection of Ruote::ProcessError instances (if there
    # are errors) for the given process.
    #
    def process_errors (wfid)

      DataMapper.repository(@dm_repository) do

        DmProcessError.all(:wfid => wfid).collect do |dpe|
          Ruote::ProcessError.new(dpe.svalue)
        end
      end
    end

    def purge_process (wfid)

      DataMapper.repository(@dm_repository) do

        DmProcessError.all(:wfid => wfid).destroy!
      end
    end

    # Clears this error journal completely. Mostly used by the testing
    # framework.
    #
    def purge!

      DataMapper.repository(@dm_repository) do

        DmProcessError.all.destroy!
      end
    end

    protected

    def record (fei, eargs)

      DataMapper.repository(@dm_repository) do

        dpe = DmProcessError.new

        dpe.fei = fei.to_s
        dpe.wfid = fei.parent_wfid
        dpe.created_at = Time.now
        dpe.svalue = eargs

        dpe.save
          # TODO : handle error ?
      end
    end

    def remove (fei)

      DataMapper.repository(@dm_repository) do

        DmProcessError.first(:fei => fei.to_s).destroy!
      end
    end
  end
end
end

