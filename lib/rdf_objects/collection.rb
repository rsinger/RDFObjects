module RDFObject
  class Collection < Hash
    def uris
      return self.keys
    end
    def find_by_predicate(predicate)
      if predicate.could_be_a_safe_curie?
        predicate = Curie.parse predicate
      end      
      matches = self.find_all {|r| 
        if r[1][predicate]
          r[1]
        end
      }
      resources = Collection.new
      matches.each do | match |
        resources[match[0]] = match[1]
      end
      return resources
    end
    
    def find_by_predicate_and_object(predicate, object)
      if predicate.could_be_a_safe_curie?
        predicate = Curie.parse predicate
      end      
      if object.could_be_a_safe_curie?
        object = Curie.parse object
      end
      object = self[object] if self[object]      
      matches = self.find_all {|r| [*r[1][predicate]].index(object) }

      resources = Collection.new
      matches.each do | match |
        resources[match[0]] = match[1]
      end
      return resources
    end    

    def find_or_create(uri)
      if uri.could_be_a_safe_curie?
        uri = Curie.parse uri
      end
      if BlankNode.is_bnode_id?(uri)
        bnode = BlankNode.new(uri)
        self[bnode.uri] = bnode unless self[bnode.uri]
        return self[bnode.uri]
      else
        self[uri] = Resource.new(uri) unless self[uri]        
      end
      self[uri]
    end  
    
    def remove(resource)
      self.delete(resource.uri)
    end
    
    def parse(data, options={})
      parser = Parser.init_parser(data, options)
      parser.collection = self
      parser.parse
      nil
    end
    
    def to_ntriples
      ntriples = ""
      self.each_pair do | uri, resource |
        ntriples << resource.to_ntriples
      end
      ntriples
    end
    
    def to_xml(depth=0)
      namespaces = {}
      rdf_data = ""
      self.values.each do | resource |
        ns, desc = resource.rdf_description_block(depth)
        namespaces.merge!(ns)
        rdf_data << desc
      end
      unless namespaces["xmlns:rdf"]
        if  x = namespaces.index("http://www.w3.org/1999/02/22-rdf-syntax-ns#")
          namespaces.delete(x)
        end
        namespaces["xmlns:rdf"] = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
      end

      rdf = "<rdf:RDF"
      namespaces.each_pair {|key, value| rdf << " #{key}=\"#{value}\""}
      rdf <<">"
      rdf << rdf_data
      rdf << "</rdf:RDF>"
      rdf      
    end    
  end
end