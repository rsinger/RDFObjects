require File.dirname(__FILE__) + '/../lib/rdf_objects'
include RDFObject
require 'rexml/document'
describe "RDFObjects should" do
  it "serialize a single object to n-triples" do
    resource = Resource.new('http://example.org/ex/1234')
    resource.relate("[rdf:type]","[foaf:Person]")
    foaf_name = Literal.new("John Doe")
    foaf_name.language = "en"
    resource.assert("[foaf:name]", foaf_name)
    resource.relate("[foaf:pastProject]","http://dbtune.org/musicbrainz/resource/artist/ddd553d4-977e-416c-8f57-e4b72c0fc746")
    resource.relate("[foaf:hompage]","http://www.theejohndoe.com/")
    ntriples = resource.to_ntriples
    ntriples.should be_kind_of(String)
    ntriples.split("\n").length.should equal(4)
    ntriples[0,29].should ==("<http://example.org/ex/1234> ")
  end
  it "parse the outputted ntriples into an identical resource" do
    resource = Resource.new('http://example.org/ex/1234')
    resource.relate("[rdf:type]","[foaf:Person]")
    foaf_name = Literal.new("John Doe")
    foaf_name.language = "en"
    resource.assert("[foaf:name]", foaf_name)
    resource.relate("[foaf:pastProject]","http://dbtune.org/musicbrainz/resource/artist/ddd553d4-977e-416c-8f57-e4b72c0fc746")
    resource.relate("[foaf:hompage]","http://www.theejohndoe.com/")
    ntriples = resource.to_ntriples
    collection = Parser.parse(ntriples)
    collection['http://example.org/ex/1234'].should ==(resource)
  end
  it "serialize a collection to n-triples" do
    nt = open(File.dirname(__FILE__) + '/files/lcsh.nt').read
    resources = Parser.parse(nt)
    ntriples = resources.to_ntriples
    ntriples.should be_kind_of(String)
    ntriples.split("\n").length.should equal(nt.split("\n").length)
  end  
  
  it "parse the outputted ntriples into an identical collection" do    
    nt = open(File.dirname(__FILE__) + '/files/lcsh.nt').read
    resources = RDFObject::Parser.parse(nt)
    ntriples = resources.to_ntriples
    collection = RDFObject::Parser.parse(ntriples) 
    resources.should ==(collection)
  end
  
  it "serialize a single object to rdf/xml" do
    resource = Resource.new('http://example.org/ex/1234')
    resource.relate("[rdf:type]","[foaf:Person]")
    foaf_name = Literal.new("John Doe")
    foaf_name.language = "en"
    resource.assert("[foaf:name]", foaf_name)
    resource.relate("[foaf:pastProject]","http://dbtune.org/musicbrainz/resource/artist/ddd553d4-977e-416c-8f57-e4b72c0fc746")
    resource.relate("[foaf:hompage]","http://www.theejohndoe.com/")    
    resource.to_xml.should be_kind_of(String)
    lambda { REXML::Document.new(resource.to_xml)}.should_not raise_error
    collection = Parser.parse(resource.to_xml)
    collection['http://example.org/ex/1234'].should ==(resource)
  end
  it "serialize a collection to rdf/xml" do
    nt = open(File.dirname(__FILE__) + '/files/lcsh.nt').read
    resources = RDFObject::Parser.parse(nt)   
    resources.to_xml.should be_kind_of(String)
    lambda { REXML::Document.new(resources.to_xml)}.should_not raise_error    
    collection = Parser.parse(resources.to_xml)
    collection.should ==(resources)
  end  
end
