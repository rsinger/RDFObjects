require File.dirname(__FILE__) + '/../lib/rdf_objects'
include RDFObject
describe "An RDFObject Parser" do
  before(:each) do
    Resource.reset!
  end  
  it "should identify and parse an rdf/xml document from I/O" do
    rdf = open(File.dirname(__FILE__) + '/files/Semantic_Web.rdf')
    resources = Parser.parse(rdf)
    resources.should be_kind_of(Array)
    resources.length.should equal(21)
  end
  it "should identify and parse an rdf/xml document from a string" do
    rdf = open(File.dirname(__FILE__) + '/files/Semantic_Web.rdf').read
    resources = Parser.parse(rdf)
    resources.should be_kind_of(Array)
    resources.length.should equal(21)
  end  
  
  it "should identify and parse an ntriples list from I/O" do
    nt = open(File.dirname(__FILE__) + '/files/lcsh.nt')
    resources = Parser.parse(nt)
    resources.should be_kind_of(Array)
    resources.length.should equal(13)    
  end
  it "should identify and parse an ntriples list from string" do
    nt = open(File.dirname(__FILE__) + '/files/lcsh.nt').read
    resources = Parser.parse(nt)
    resources.should be_kind_of(Array)
    resources.length.should equal(13)    
  end  
  it "should have created resources from an rdf/xml I/O and set their values properly" do
    rdf = open(File.dirname(__FILE__) + '/files/Semantic_Web.rdf')
    resources = Parser.parse(rdf)
    r1 = Resource.instances['http://dbpedia.org/resource/Semantic_Web']
    r1.should be_kind_of(RDFObject::Resource)  
    r1.uri.should match("http://dbpedia.org/resource/Semantic_Web")
    r1["http://www.w3.org/2000/01/rdf-schema#label"].should be_kind_of(Array)
    pending("get language attributes working in rdf/xml")
    r1["http://www.w3.org/2000/01/rdf-schema#label"].first.language.should match('zh')
  end
  
  it "should identify and parse a JSON response from I/O" do
    json = open(File.dirname(__FILE__) + '/files/lcsubjects.json')
    resources = Parser.parse(json)
    resources.should be_kind_of(Array)
    resources.length.should equal(11)
    r1 = Resource.instances["http://lcsubjects.org/subjects/sh85068937#concept"]
    r1.should be_kind_of(RDFObject::Resource)
    r1.uri.should match("http://lcsubjects.org/subjects/sh85068937#concept")
    r1["http://www.w3.org/2004/02/skos/core#narrower"].length.should equal(3)
    r1["http://www.w3.org/2004/02/skos/core#narrower"].first.should be_kind_of(RDFObject::Resource)
    r1["http:\/\/www.w3.org\/2004\/02\/skos\/core#prefLabel"].should be_kind_of(String)
    r1["http:\/\/www.w3.org\/2004\/02\/skos\/core#prefLabel"].should respond_to(:set_data_type)
    r1["http:\/\/www.w3.org\/2004\/02\/skos\/core#prefLabel"].language.should match("en")
  end
  after(:all) do
    Resource.reset!
  end
end