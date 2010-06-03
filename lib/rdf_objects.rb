module RDFObject
  require 'rubygems'
  require 'ostruct'
  require 'curies'
  require 'rdf'
  require 'rdfa_parser'
  require 'addressable/uri'
  require File.dirname(__FILE__) + '/rdf_objects/parsers'
  require File.dirname(__FILE__) + '/rdf_objects/rdf_resource'
  require File.dirname(__FILE__) + '/rdf_objects/curies'
  require File.dirname(__FILE__) + '/rdf_objects/http_client' 
  require File.dirname(__FILE__) + '/rdf_objects/collection'      
  Curie.remove_prefixes!(:http)
end
