# encoding: utf-8

Gem::Specification.new do |s|

  s.name = 'ruote-dm'

  s.version = File.read(
    File.expand_path('../lib/ruote/dm/version.rb', __FILE__)
  ).match(/ VERSION *= *['"]([^'"]+)/)[1]

  s.platform = Gem::Platform::RUBY
  s.authors = [ 'John Mettraux' ]
  s.email = [ 'jmettraux@gmail.com' ]
  s.homepage = 'http://ruote.rubyforge.org'
  s.rubyforge_project = 'ruote'
  s.summary = 'datamapper storage for ruote (a workflow engine)'
  s.description = %q{
datamapper storage for ruote (a workflow engine)
}

  #s.files = `git ls-files`.split("\n")
  s.files = Dir[
    'Rakefile',
    'lib/**/*.rb', 'spec/**/*.rb', 'test/**/*.rb',
    '*.gemspec', '*.txt', '*.rdoc', '*.md'
  ]

  s.add_runtime_dependency 'dm-core', '1.1.0'
  s.add_runtime_dependency 'dm-migrations', '1.1.0'
  s.add_runtime_dependency 'ruote', ">= #{s.version}"

  s.add_development_dependency 'rake'

  s.require_path = 'lib'
end

