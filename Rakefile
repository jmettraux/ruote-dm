
require 'rubygems'
require 'rake'

require 'lib/ruote/dm/version.rb'

#
# CLEAN

require 'rake/clean'
CLEAN.include('pkg', 'tmp', 'html')
task :default => [ :clean ]


#
# GEM

require 'jeweler'

Jeweler::Tasks.new do |gem|

  gem.version = Ruote::Dm::VERSION
  gem.name = 'ruote-dm'
  gem.summary = 'datamapper storage for ruote (a ruby workflow engine)'
  gem.description = %{
datamapper storage for ruote (a ruby workflow engine)
  }.strip
  gem.email = 'jmettraux@gmail.com'
  gem.homepage = 'http://github.com/jmettraux/ruote-dm'
  gem.authors = [ 'John Mettraux' ]
  gem.rubyforge_project = 'ruote'

  gem.test_file = 'test/test.rb'

  gem.add_dependency 'ruote', ">= #{Ruote::Dm::VERSION}"
  gem.add_dependency 'dm-core'
  #gem.add_dependency 'dm-aggregates'
  #gem.add_dependency 'dm-types'
  gem.add_development_dependency 'yard'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'jeweler'

  # gemspec spec : http://www.rubygems.org/read/chapter/20
end
Jeweler::GemcutterTasks.new


#
# DOC

begin

  require 'yard'

  YARD::Rake::YardocTask.new do |doc|
    doc.options = [
      '-o', 'html/ruote-dm', '--title',
      "ruote-dm #{Ruote::Dm::VERSION}"
    ]
  end

rescue LoadError

  task :yard do
    abort "YARD is not available : sudo gem install yard"
  end
end


#
# TO THE WEB

task :upload_website => [ :clean, :yard ] do

  account = 'jmettraux@rubyforge.org'
  webdir = '/var/www/gforge-projects/ruote'

  sh "rsync -azv -e ssh html/ruote-dm #{account}:#{webdir}/"
end

