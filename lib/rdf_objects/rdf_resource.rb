require 'uri'
require 'date'
require 'curies'

module RDFObject
  class Resource < OpenStruct
    def initialize(uri)        
      if uri.could_be_a_safe_curie?
        uri = Curie.parse uri
      end
      super(:uri=>uri)
    end
  
    def assert(predicate, object)
      curied_predicate = case
      when predicate.could_be_a_safe_curie? then Curie.new_from_curie(predicate)
      when Curie.curie_from_uri(predicate) then Curie.curie_from_uri(predicate)
      else Curie.create_from_uri(predicate)
      end
      self.register_vocabulary(curied_predicate.prefix)
      pred_attr = self.send(curied_predicate.prefix.to_sym)
      if object.is_a?(Resource)
        object = ResourceReference.new(object)
      end
      return if assertion_exists?(predicate, object)
      if pred_attr[curied_predicate.reference]
        unless pred_attr[curied_predicate.reference].is_a?(Array)
          pred_attr[curied_predicate.reference] = [pred_attr[curied_predicate.reference]]
        end
        pred_attr[curied_predicate.reference] << object
      else
        pred_attr[curied_predicate.reference] = object
      end
    end
    
    def assertion_exists?(predicate, object)
      return false unless self[predicate]
      if self[predicate].is_a?(Array)
        return true if self[predicate].index(object)
      else
        return true if self[predicate] == object
      end
      return false
    end
  
    def [](uri)
      curie = case
      when uri.could_be_a_safe_curie? then Curie.new_from_curie(uri)
      when Curie.curie_from_uri(uri) then Curie.curie_from_uri(uri)
      else 
        return nil
      end
      vocab = self.send(curie.prefix.to_sym)
      return nil unless vocab
      return vocab if curie.reference.empty?
      return vocab[curie.reference]
    end
  
    def prefix_for(uri)
      Curie.prefix_for(uri)
    end
  
    def register_vocabulary(name)
      return if self.respond_to?(name.to_sym)
      self.new_ostruct_member(name)
      self.send("#{name}=".to_sym, {})
    end
  
    def relate(predicate, resource)
      unless resource.is_a?(self.class)
        resource = self.class.new(resource)
      end
      self.assert(predicate, resource)
    end
  
    def describe
      rdf = HTTPClient.fetch(self.uri)
      local_collection = Parser.parse(rdf)
      local_collection[self.uri].assertions.each do | predicate, object |
        [*object].each do | obj |
          self.assert(predicate, object) unless self.assertion_exists?(predicate, object)
        end
      end
    end
    
    def assertions
      assertions = {}
      Curie.get_mappings.each do | prefix, uri |
        if self[uri]
          self[uri].keys.each do | pred |
            assertions["#{uri}#{pred}"] = self[uri][pred]
          end
        end
      end
      assertions
    end
  
    def empty_graph?
      Curie.get_mappings.each do | prefix, uri |
        return false if self.respond_to?(prefix.to_sym)
      end
      return true
    end
  end
  
  class ResourceReference
    def initialize(resource)
      @resource = resource
      @inspect = "\"#{@resource.uri}\""
    end
    
    def ==(resource)
      return resource == @resource
    end
    
    def inspect
      @inspect
    end
    
    def resource
      @resource
    end
    
    def method_missing(method, *args)
      @resource.send(method, *args)
    end
  end
end