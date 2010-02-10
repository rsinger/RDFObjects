require File.dirname(__FILE__) + '/../lib/rdf_objects'
include RDFObject
describe "An RDFObject Parser" do

  it "should identify and parse an rdf/xml document from I/O" do
    rdf = open(File.dirname(__FILE__) + '/files/Semantic_Web.rdf')
    resources = Parser.parse(rdf)
    resources.should be_kind_of(Collection)
    resources.should be_kind_of(Hash)    
    resources.uris.length.should equal(51)
  end
  it "should identify and parse an rdf/xml document from a string" do
    rdf = open(File.dirname(__FILE__) + '/files/Semantic_Web.rdf').read
    resources = Parser.parse(rdf)
    resources.should be_kind_of(Collection)
    resources.uris.length.should equal(51)
  end  
  
  it "should identify and parse an ntriples list from I/O" do
    nt = open(File.dirname(__FILE__) + '/files/lcsh.nt')
    resources = Parser.parse(nt)
    resources.should be_kind_of(Collection)
    resources.uris.length.should equal(41)    
  end
  it "should identify and parse an ntriples list from string" do
    nt = open(File.dirname(__FILE__) + '/files/lcsh.nt').read
    resources = Parser.parse(nt)
    resources.should be_kind_of(Collection)
    resources.uris.length.should equal(41)    
  end  
  
  it "should have created resources from an rdf/xml I/O and set their values properly" do
    rdf = open(File.dirname(__FILE__) + '/files/Semantic_Web.rdf')
    resources = Parser.parse(rdf)
    r1 = resources['http://dbpedia.org/resource/Semantic_Web']
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
    resources.should be_kind_of(Collection)
    resources.uris.length.should equal(11)
  end
  
  it "should have created resources from a JSON I/O and set their values properly" do 
    json = open(File.dirname(__FILE__) + '/files/lcsubjects.json')
    resources = Parser.parse(json)    
    r1 = resources["http://lcsubjects.org/subjects/sh85068937#concept"]
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
    resources.should be_kind_of(Collection)
    resources.uris.length.should equal(80)    
  end
  
  it "should correctly find and build nested resources in an RSS 1.0 document" do
    rss = open(File.dirname(__FILE__) + '/files/rss10-2.xml')
    resources = Parser.parse(rss)
    resources.should be_kind_of(Collection)
    r1 = resources["http://lcsubjects.org/subjects/sh85068937#concept"]
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
    r1 = resources['http://example/q?abc=1&def=2']
    rdf = open(File.dirname(__FILE__) + '/rdfxml_test_cases/amp-in-url/test001.rdf')
    resources2 = Parser.parse(rdf)
    r2 = resources['http://example/q?abc=1&def=2']
    r2.should be_kind_of(RDFObject::Resource)
    r1.should == r2
  end
  
  it "should make two identical Resource objects from 'datatypes' test #1" do
    nt = open(File.dirname(__FILE__) + '/rdfxml_test_cases/datatypes/test001.nt')
    resources = Parser.parse(nt)
    r1 = resources["http://example.org/foo"]

    rdf = open(File.dirname(__FILE__) + '/rdfxml_test_cases/datatypes/test001.rdf')
    resources2 = Parser.parse(rdf)
    r2 = resources2["http://example.org/foo"]
    r2.should be_kind_of(RDFObject::Resource)
    r1.should == r2
  end  
  
  it "should detect and set the xml:base attribute in an RDF/XML document" do
    rdf = open(File.dirname(__FILE__) + '/files/xml-base.rdf')
    resources = Parser.parse(rdf)
    resources.keys.should include("http://viaf.org/viaf/46946176.rwo")
    schemes = []
    
    [*resources["http://viaf.org/viaf/46946176.rwo"]["http://www.w3.org/2004/02/skos/core#inScheme"]].each do | scheme |
      schemes << scheme.uri
    end
    schemes.should include("http://viaf.org/viaf-scheme/#concept")
  end
  
  it "should allow a base URI to be set explicitly" do
    rdf = open(File.dirname(__FILE__) + '/files/no-uri-context.rdf')
    resources = Parser.parse(rdf)
    resources.should_not include('http://www.bbc.co.uk/music/artists/72c536dc-7137-4477-a521-567eeb840fa8#artist')
    rdf.rewind
    resources = Parser.parse(rdf, :base_uri=>"http://www.bbc.co.uk/")
    resources.should include('http://www.bbc.co.uk/music/artists/72c536dc-7137-4477-a521-567eeb840fa8#artist')    
    resources.should include('http://www.bbc.co.uk/music/reviews/55mq#review')
  end
  
  it "should throw errors from 'datatypes' test #2" do
    nt = open(File.dirname(__FILE__) + '/rdfxml_test_cases/datatypes/test002.nt')
    lambda {Parser.parse(nt)}.should raise_error(ArgumentError)

    rdf = open(File.dirname(__FILE__) + '/rdfxml_test_cases/datatypes/test002.rdf')
    lambda {Parser.parse(rdf)}.should raise_error(ArgumentError)
  end  
  
  it "should recognize a URI and retrieve the RDF from it" do
    lambda{Parser.parse("http://dbpedia.org/resource/Semantic_Web")}.should_not raise_exception()
  end
  
  it "should identify and parse blank nodes from RDF/XML" do
    collection = Parser.parse("http://rdf.freebase.com/rdf/en.dashiell_hammett")
    i = 0
    collection.values.each {|v| i+=1 if v.is_a?(BlankNode)}
    i.should >=(1)
  end

  it "should identify and parse blank nodes from n-triples" do
    nt = open(File.dirname(__FILE__) + '/files/bnodes.nt')
    collection = Parser.parse(nt)
    i = 0
    collection.values.each {|v| i+=1 if v.is_a?(BlankNode)}
    i.should >=(1)
    collection.keys.should include("_:genid18")
    collection["_:genid18"].should be_kind_of(BlankNode)
  end
end