module RDFObject
  class Collection < Hash
    def uris
      return self.keys
    end
    def find_by_type(type)
      self.find_all {|r| r}
    end

    def find_or_create(uri)
      if uri.could_be_a_safe_curie?
        uri = Curie.parse uri
      end
      self[uri] = Resource.new(uri) unless self[uri]
      self[uri]
    end  
    
    def remove(resource)
      self.delete(resource.uri)
    end
    
    def parse(data, format=nil)
      parser = Parser.init_parser(data, format)
      parser.collection = self
      parser.parse
      nil
    end
  end
end