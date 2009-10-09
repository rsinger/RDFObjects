module RDFObject
  require 'rubygems'
  require 'ostruct'
  require 'curies'
  require File.dirname(__FILE__) + '/rdf_objects/parsers'
  require File.dirname(__FILE__) + '/rdf_objects/rdf_resource'
  require File.dirname(__FILE__) + '/rdf_objects/curies'
  require File.dirname(__FILE__) + '/rdf_objects/data_types'
  require File.dirname(__FILE__) + '/rdf_objects/http_client' 
  require File.dirname(__FILE__) + '/rdf_objects/collection'      
  Curie.remove_prefixes!(:http)
end
