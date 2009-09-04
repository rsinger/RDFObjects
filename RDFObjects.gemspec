Gem::Specification.new do |s|
  s.add_dependency('nokogiri')
  s.add_dependency('curies')  
  s.add_dependency('json')
  s.add_dependency('builder')  
  s.name = 'rdfobjects'
  s.version = '0.1'
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.date = %q{2009-08-07}
  s.author = 'Ross Singer'
  s.email = 'rossfsinger@gmail.com'
  s.homepage = 'http://github.com/rsinger/RDFObjects/tree'
  s.platform = Gem::Platform::RUBY
  s.summary = 'RDFObjects are intended to simplify working with RDF data by providing a (more) Ruby-like interface to resources (thanks to OpenStruct).'
  s.files = Dir.glob("{lib,spec}/**/*") + ["README", "LICENSE"]
  s.require_path = 'lib'
  s.has_rdoc = true
  s.required_ruby_version = '>= 1.8.6'
  s.bindir = 'bin'
end
