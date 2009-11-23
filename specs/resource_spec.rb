require File.dirname(__FILE__) + '/../lib/rdf_objects'
include RDFObject
describe "An RDFObject Resource" do

  it "should initialize a resource with a URI" do
    Resource.new('http://example.org/1234').should be_a_kind_of(RDFObject::Resource)
  end
  it "should inherit from OpenStruct" do
    Resource.new('http://example.org/1234').should be_a_kind_of(OpenStruct)    
  end

  it "should initialize from a safe curie" do
    r1 = Resource.new("[foaf:Person]")
    r1.uri.should match('http://xmlns.com/foaf/0.1/Person')
  end
  
  it "should let us know if a graph is empty" do
    r1 = Resource.new('http://example.org/1234')
    r1.empty_graph?.should be_true
  end
  it "should let us assert a literal with a full URI" do
    r1 = Resource.new('http://example.org/1234')
    r1.assert('http://purl.org/dc/terms/title', 'Foobar')
    r1['http://purl.org/dc/terms/title'].should match('Foobar')
  end
  it "should let us assert a literal with a safe curie" do
    r1 = Resource.new('http://example.org/1234')
    r1.assert('[dc:creator]', 'William Shakespeare')
    r1['http://purl.org/dc/elements/1.1/creator'].should match('William Shakespeare')
  end  
  it "should let us access an object by using a safe curie of the predicate as a hash key" do
    r1 = Resource.new('http://example.org/1234')
    r1.assert('http://purl.org/dc/elements/1.1/creator', 'William Shakespeare')
    r1['[dc:creator]'].should match('William Shakespeare')
  end  
  it "should return all assertions within a namespace by passing the namespace URI as a hash key" do
    r1 = Resource.new('http://example.org/1234')
    r1.assert('http://purl.org/dc/terms/dateCopyrighted', '2009')
    r1.assert('http://purl.org/dc/terms/title', 'Foobar')
    r1['http://purl.org/dc/terms/'].should be_kind_of(Hash)
    dct = r1['http://purl.org/dc/terms/']
    dct.has_key?('title').should be_true
    dct.has_key?('dateCopyrighted').should be_true    
    dct.has_key?('subject').should be_false
    dct['title'].should match('Foobar')
  end  
  it "should return all assertions within a namespace by passing the safe curie prefix as a hash key" do
    r1 = Resource.new('http://example.org/1234')
    r1.assert('[dc:creator]', 'William Shakespeare')
    r1['[dc:]'].should be_kind_of(Hash)
    dc = r1["[dc:]"]
    dc['creator'].should match("William Shakespeare")
  end
  it "should turn an already set predicate into an array if there are multiple assertions" do
    r1 = Resource.new('http://example.org/1234')
    r1.assert('[dc:creator]', 'William Shakespeare')
    r1["[dc:creator]"].should be_kind_of(String)
    r1.assert("http://purl.org/dc/elements/1.1/creator", "Silliam Whakespeare")
    r1["[dc:creator]"].should be_kind_of(Array)
  end
  it "should let us know if a graph is not empty" do
    r1 = Resource.new('http://example.org/1234')
    r1.assert("[foaf:name]", "Test Tester")
    r1.empty_graph?.should be_false
  end  
  
  it "should match two graphs with identical assertions set" do
    r1 = Resource.new("http://dbpedia.org/resource/William_Shakespeare")
    r1.assert("[foaf:name]", "William Shakespeare")
    r1.relate("[rdf:type]", "[foaf:Person]")
    r1.relate("http://www.w3.org/2002/07/owl#sameAs","http://rdf.freebase.com/ns/guid.9202a8c04000641f8000000000040628")
    r2 = Resource.new("http://dbpedia.org/resource/William_Shakespeare")
    r2.assert("[foaf:name]", "William Shakespeare")
    r2.relate("[rdf:type]", "[foaf:Person]")
    r2.relate("http://www.w3.org/2002/07/owl#sameAs","http://rdf.freebase.com/ns/guid.9202a8c04000641f8000000000040628")    
    r1.object_id.should_not equal(r2.object_id)
    r1.should == r2
  end
  
  it "should not match two graphs with different assertions set" do
    r1 = Resource.new("http://dbpedia.org/resource/William_Shakespeare")
    r1.assert("[foaf:name]", "William Shakespeare")
    r1.relate("[rdf:type]", "[foaf:Person]")
    r1.relate("http://www.w3.org/2002/07/owl#sameAs","http://rdf.freebase.com/ns/guid.9202a8c04000641f8000000000040628")
    r2 = Resource.new("http://dbpedia.org/resource/William_Shakespeare")
    r2.assert("[foaf:name]", "William Shakespeare")
    r2.relate("[rdf:type]", "[foaf:Person]")
    r2.relate("http://www.w3.org/2002/07/owl#sameAs","http://viaf.org/viaf/96994048.rwo")
    r1.object_id.should_not equal(r2.object_id)
    r1.should_not == r2
  end  

end