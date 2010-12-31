
$:.unshift('.') # 1.9.2

require 'rubygems'

require 'rake'
require 'rake/clean'
require 'rake/rdoctask'


#
# clean

CLEAN.include('pkg', 'rdoc')


#
# test / spec

task :test do

  puts
  puts "to test ruote-dm, head to your ruote/ dir and run"
  puts
  puts "  ruby test/test.rb -- --dm"
  puts
  puts "but first, make sure your ruote-dm/test/functional_connection.rb"
  puts "is set correctly."
  puts
end

task :default => [ :test ]


#
# gem

GEMSPEC_FILE = Dir['*.gemspec'].first
GEMSPEC = eval(File.read(GEMSPEC_FILE))
GEMSPEC.validate


desc %{
  builds the gem and places it in pkg/
}
task :build do

  sh "gem build #{GEMSPEC_FILE}"
  sh "mkdir pkg" rescue nil
  sh "mv #{GEMSPEC.name}-#{GEMSPEC.version}.gem pkg/"
end

desc %{
  builds the gem and pushes it to rubygems.org
}
task :push => :build do

  sh "gem push pkg/#{GEMSPEC.name}-#{GEMSPEC.version}.gem"
end


#
# rdoc
#
# make sure to have rdoc 2.5.x to run that

Rake::RDocTask.new do |rd|

  rd.main = 'README.rdoc'
  rd.rdoc_dir = 'rdoc'

  rd.rdoc_files.include(
    'README.rdoc', 'CHANGELOG.txt', 'CREDITS.txt', 'lib/**/*.rb')

  rd.title = "#{GEMSPEC.name} #{GEMSPEC.version}"
end


#
# upload_rdoc

desc %{
  upload the rdoc to rubyforge
}
task :upload_rdoc => [ :clean, :rdoc ] do

  account = 'jmettraux@rubyforge.org'
  webdir = '/var/www/gforge-projects/ruote'

  sh "rsync -azv -e ssh rdoc/#{GEMSPEC.name}_rdoc #{account}:#{webdir}/"
end

