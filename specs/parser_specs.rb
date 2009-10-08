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
    resources.length.should equal(51)
  end
  it "should identify and parse an rdf/xml document from a string" do
    rdf = open(File.dirname(__FILE__) + '/files/Semantic_Web.rdf').read
    resources = Parser.parse(rdf)
    resources.should be_kind_of(Array)
    resources.length.should equal(51)
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
    r1["http://www.w3.org/2000/01/rdf-schema#label"].first.language.should match('zh')
    r1["http://www.w3.org/2002/07/owl#sameAs"].should be_kind_of(RDFObject::ResourceReference)
    r1["http://www.w3.org/2002/07/owl#sameAs"].uri.should match("http://rdf.freebase.com/ns/guid.9202a8c04000641f8000000000039a20")
  end
  
  it "should identify and parse a JSON response from I/O" do
    json = open(File.dirname(__FILE__) + '/files/lcsubjects.json')
    resources = Parser.parse(json)
    resources.should be_kind_of(Array)
    resources.length.should equal(11)
  end
  
  it "should have created resources from a JSON I/O and set their values properly" do 
    json = open(File.dirname(__FILE__) + '/files/lcsubjects.json')
    resources = Parser.parse(json)    
    r1 = Resource.instances["http://lcsubjects.org/subjects/sh85068937#concept"]
    r1.should be_kind_of(RDFObject::Resource)
    r1.uri.should match("http://lcsubjects.org/subjects/sh85068937#concept")
    r1["http://www.w3.org/2004/02/skos/core#narrower"].length.should equal(3)
    r1["http://www.w3.org/2004/02/skos/core#narrower"].first.should be_kind_of(RDFObject::ResourceReference)
    r1["http:\/\/www.w3.org\/2004\/02\/skos\/core#prefLabel"].should be_kind_of(String)
    r1["http:\/\/www.w3.org\/2004\/02\/skos\/core#prefLabel"].should respond_to(:set_data_type)
    r1["http:\/\/www.w3.org\/2004\/02\/skos\/core#prefLabel"].language.should match("en")    
  end
  
  it "should identify and parse an RSS 1.0 document from I/O" do
    rss = open(File.dirname(__FILE__) + '/files/rss10.xml')
    resources = Parser.parse(rss)
    resources.should be_kind_of(Array)
    resources.length.should equal(75)    
  end
  
  it "should correctly find and build nested resources in an RSS 1.0 document" do
    rss = open(File.dirname(__FILE__) + '/files/rss10-2.xml')
    resources = Parser.parse(rss)
    resources.should be_kind_of(Array)
    r1 = Resource.instances["http://lcsubjects.org/subjects/sh85068937#concept"]
    r1["http://www.w3.org/2004/02/skos/core#prefLabel"].should == ("Italy--History--To 476")
    r1["http://www.w3.org/2004/02/skos/core#narrower"].should be_kind_of(Array)
    r1["http://www.w3.org/2004/02/skos/core#narrower"].first.should be_kind_of(RDFObject::ResourceReference)
    r1["http://www.w3.org/2004/02/skos/core#narrower"].first.uri.should == ("http://lcsubjects.org/subjects/sh85142643#concept")
    r2 = r1["http://www.w3.org/2004/02/skos/core#narrower"].first
    r2.rdf["type"].uri.should == ("http://www.w3.org/2004/02/skos/core#Concept")
    r2["http://www.w3.org/2004/02/skos/core#prefLabel"].should == ("Veneti (Italic people)")
    r2["http://www.w3.org/2004/02/skos/core#prefLabel"].language.should == ("en")
    r2["http://www.w3.org/2004/02/skos/core#broader"].first.resource.should equal(r1)
  end
    
  it "should make two identical Resource objects from the 'amp-in-url' test" do
    nt = open(File.dirname(__FILE__) + '/rdfxml_test_cases/amp-in-url/test001.nt')
    resources = Parser.parse(nt)
    r1 = Resource.instances['http://example/q?abc=1&def=2']
    r1_raw = Marshal.dump(r1)
    Resource.reset!
    rdf = open(File.dirname(__FILE__) + '/rdfxml_test_cases/amp-in-url/test001.rdf')
    resources = Parser.parse(rdf)
    r1 = Resource.instances['http://example/q?abc=1&def=2']
    r1.should be_kind_of(RDFObject::Resource)
    r2 = Marshal.load r1_raw
    r1.should == r2
  end
  
  it "should make two identical Resource objects from 'datatypes' test #1" do
    nt = open(File.dirname(__FILE__) + '/rdfxml_test_cases/datatypes/test001.nt')
    resources = Parser.parse(nt)
    r1 = Resource.instances["http://example.org/foo"]
    r1_raw = Marshal.dump(r1)
    Resource.reset!
    rdf = open(File.dirname(__FILE__) + '/rdfxml_test_cases/datatypes/test001.rdf')
    resources = Parser.parse(rdf)
    r1 = Resource.instances["http://example.org/foo"]
    r1.should be_kind_of(RDFObject::Resource)
    r2 = Marshal.load r1_raw
    r1.should == r2
  end  

  it "should throw errors from 'datatypes' test #2" do
    nt = open(File.dirname(__FILE__) + '/rdfxml_test_cases/datatypes/test002.nt')
    lambda {Parser.parse(nt)}.should raise_error(ArgumentError)

    Resource.reset!
    rdf = open(File.dirname(__FILE__) + '/rdfxml_test_cases/datatypes/test002.rdf')
    lambda {Parser.parse(rdf)}.should raise_error(ArgumentError)
  end  
  after(:all) do
    Resource.reset!
  end
end