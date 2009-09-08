require "rake"

require "spec/rake/spectask"



desc "Run all specs"

Spec::Rake::SpecTask.new("specs") do |t|

  t.spec_files = FileList["specs/*.rb"]

end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "rdfobjects"
    gemspec.summary = "A DSL for working with RDF resources."
    gemspec.description = "RDFObjects are intended to simplify working with RDF data by providing a (more) Ruby-like interface to resources (thanks to OpenStruct)."
    gemspec.email = "rossfsinger@gmail.com"
    gemspec.homepage = "http://github.com/rsinger/RDFObjects/tree"
    gemspec.authors = ["Ross Singer"]
    gemspec.add_dependency('nokogiri')
    gemspec.add_dependency('curies')  
    gemspec.add_dependency('json')    
    gemspec.files = Dir.glob("{lib,spec}/**/*") + ["README", "LICENSE"]
    gemspec.require_path = 'lib'    
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

