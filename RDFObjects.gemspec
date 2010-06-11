# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile.rb, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rdfobjects}
  s.version = "0.11.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Ross Singer"]
  s.date = %q{2010-06-09}
  s.description = %q{RDFObjects are intended to simplify working with RDF data by providing a (more) Ruby-like interface to resources (thanks to OpenStruct).}
  s.email = %q{rossfsinger@gmail.com}
  s.extra_rdoc_files = [
    "LICENSE",
     "README"
  ]
  s.files = [
    "LICENSE",
     "README",
     "lib/rdf_objects.rb",
     "lib/rdf_objects/collection.rb",
     "lib/rdf_objects/curies.rb",
     "lib/rdf_objects/data_types.rb",
     "lib/rdf_objects/http_client.rb",
     "lib/rdf_objects/parsers.rb",
     "lib/rdf_objects/rdf_resource.rb",
     "lib/rdf_objects/serializers.rb",
     "lib/xsl/RDFa2RDFXML.xsl",
     "lib/xsl/rdf2nt.xsl",
     "lib/xsl/rdf2r3x.xsl"
  ]
  s.homepage = %q{http://github.com/rsinger/RDFObjects/tree}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.requirements = ["json, json_pure or json-ruby required for parsing RDF/JSON"]
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{A DSL for working with RDF resources.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<nokogiri>, [">= 0"])
      s.add_runtime_dependency(%q<curies>, [">= 0"])
      s.add_runtime_dependency(%q<addressable>, [">= 0"])
      s.add_runtime_dependency(%q<rdf>, [">= 0"])
      s.add_runtime_dependency(%q<rdfa_parser>, [">= 0"])
    else
      s.add_dependency(%q<nokogiri>, [">= 0"])
      s.add_dependency(%q<curies>, [">= 0"])
      s.add_dependency(%q<addressable>, [">= 0"])
      s.add_dependency(%q<rdf>, [">= 0"])
      s.add_dependency(%q<rdfa_parser>, [">= 0"])
    end
  else
    s.add_dependency(%q<nokogiri>, [">= 0"])
    s.add_dependency(%q<curies>, [">= 0"])
    s.add_dependency(%q<addressable>, [">= 0"])
    s.add_dependency(%q<rdf>, [">= 0"])
    s.add_dependency(%q<rdfa_parser>, [">= 0"])
  end
end

