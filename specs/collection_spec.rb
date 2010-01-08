require File.dirname(__FILE__) + '/../lib/rdf_objects'
include RDFObject
describe "An RDFObject Collection" do

  it "should populate a master hash of defined resources" do
    collection = Collection.new
    collection.should be_a_kind_of(Hash)
    collection.should be_a_kind_of(RDFObject::Collection)
    r1 = collection.find_or_create('http://example.org/1234')
    collection['http://example.org/1234'].should equal(r1)
  end
  it "should reuse existing resources with the same URI" do
    collection = Collection.new
    r1 = collection.find_or_create('http://example.org/1234')
    collection.uris.length.should equal(1)
    r2 = collection.find_or_create('http://example.org/5678')
    collection.uris.length.should equal(2)
    r1.object_id.should_not equal(r2.object_id)
    r3 = collection.find_or_create('http://example.org/1234')
    collection.uris.length.should equal(2)
    r1.object_id.should ==(r3.object_id)
  end
  
  it "should initialize from a safe curie" do
    collection = Collection.new
    collection.find_or_create("[foaf:Person]")
    collection.has_key?('http://xmlns.com/foaf/0.1/Person').should be_true
    collection.has_key?('[foaf:Person]').should be_false
  end  
  
  it "should remove one resource from the Collection" do
    collection = Collection.new
    r1 = collection.find_or_create('http://example.org/1234')
    collection.uris.length.should equal(1)
    r2 = collection.find_or_create('http://example.org/5678')
    collection.uris.length.should equal(2)
    collection.remove(r2)
    collection.uris.length.should equal(1)
    collection.uris[0].should match('http://example.org/1234')
    collection.uris.should_not include('http://example.org/5678')
  end  
  
end