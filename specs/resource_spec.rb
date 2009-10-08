require File.dirname(__FILE__) + '/../lib/rdf_objects'
include RDFObject
describe "An RDFObject Resource" do
  before(:all) do
    Resource.reset!
  end  
  
  it "should initialize a resource with a URI" do
    Resource.new('http://example.org/1234').should be_a_kind_of(RDFObject::Resource)
  end
  it "should inherit from OpenStruct" do
    Resource.new('http://example.org/1234').should be_a_kind_of(OpenStruct)    
  end
  it "should populate a master hash of defined resources" do
    Resource.instances.should be_a_kind_of(Hash)
    r1 = Resource.new('http://example.org/1234')
    Resource.instances['http://example.org/1234'].should equal(r1)
  end
  it "should reuse existing resources with the same URI" do
    Resource.instances.size.should equal(1)
    r1 = Resource.new('http://example.org/1234')
    Resource.instances.size.should equal(1)
    r2 = Resource.new('http://example.org/5678')
    Resource.instances.size.should equal(2)
    r1.object_id.should_not equal(r2.object_id)
    r3 = Resource.new('http://example.org/1234')
    Resource.instances.size.should equal(2)
    r1.object_id.should equal(r3.object_id)
  end
  
  it "should create a new resource object when passed the :force argument" do
    r1 = Resource.new('http://example.org/1234')
    r2 = Resource.new('http://example.org/1234')
    r1.object_id.should equal(r2.object_id)
    r2 = Resource.new('http://example.org/1234', :force)
    r1.object_id.should_not equal(r2.object_id)
  end
  it "should remove one resource from the resource cache" do
    r2 = Resource.new('http://example.org/5678')
    Resource.remove(r2)
    Resource.instances.size.should equal(1)
    Resource.instances.keys[0].should match('http://example.org/1234')
  end
  it "should clear the resource cache" do
    Resource.instances.size.should equal(1)
    Resource.reset!
    Resource.instances.size.should equal(0)
    Resource.instances.empty?.should be_true
  end
  
  it "should initialize from a safe curie" do
    r1 = Resource.new("[foaf:Person]")
    r1.uri.should match('http://xmlns.com/foaf/0.1/Person')
    Resource.instances.has_key?('http://xmlns.com/foaf/0.1/Person').should be_true
    Resource.instances.has_key?('[foaf:Person]').should be_false
  end
  
  it "should tell us if a resource exists" do
    Resource.exists?('http://xmlns.com/foaf/0.1/Person').should be_true
    Resource.exists?('http://xmlns.com/foaf/0.1/Organization').should be_false
    Resource.reset!
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
    r1['[dc:creator]'].should match('William Shakespeare')
  end  
  it "should return all assertions within a namespace by passing the namespace URI as a hash key" do
    r1 = Resource.new('http://example.org/1234')
    r1.assert('http://purl.org/dc/terms/dateCopyrighted', '2009')
    r1['http://purl.org/dc/terms/'].should be_kind_of(Hash)
    dct = r1['http://purl.org/dc/terms/']
    dct.has_key?('title').should be_true
    dct.has_key?('dateCopyrighted').should be_true    
    dct.has_key?('subject').should be_false
    dct['title'].should match('Foobar')
  end  
  it "should return all assertions within a namespace by passing the safe curie prefix as a hash key" do
    r1 = Resource.new('http://example.org/1234')
    r1['[dc:]'].should be_kind_of(Hash)
    dc = r1["[dc:]"]
    dc['creator'].should match("William Shakespeare")
  end
  it "should turn an already set predicate into an array if there are multiple assertions" do
    r1 = Resource.new('http://example.org/1234')
    r1["[dc:creator]"].should be_kind_of(String)
    r1.assert("http://purl.org/dc/elements/1.1/creator", "Silliam Whakespeare")
    r1["[dc:creator]"].should be_kind_of(Array)
  end
  it "should let us know if a graph is not empty" do
    r1 = Resource.new('http://example.org/1234')
    r1.empty_graph?.should be_false
  end  
  after(:all) do
    Resource.reset!
  end  
end