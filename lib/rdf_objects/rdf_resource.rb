require 'uri'
require 'date'
require 'curies'
require 'weakref'

module RDFObject
  class Resource < OpenStruct
    class << self
      def instances
        instances = {}
        ObjectSpace.each_object(self) { | rdf_object |
          next unless rdf_object.uri
          instances[rdf_object.uri] = rdf_object
        }        
        instances
      end

      def reset!
      #  @instances = {}
        ObjectSpace.each_object(self) { | rdf_object |
          rdf_object.uri = nil
          Curie.get_mappings.each do | prefix, uri |
            if rdf_object.respond_to?(prefix.to_sym)
              rdf_object.send("#{prefix}=".to_sym, nil)
            end
          end
        }
        ObjectSpace.garbage_collect        
      end

      def remove(resource)
        to_del = instances[resource.uri]      
        to_del.uri = nil
      end
    
      def exists?(uri)
        ObjectSpace.each_object(self) { | rdf_object |
          return true if rdf_object.uri == uri
        }
        false
      end
    end

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
      Parser.parse(rdf)
    end
  
    def empty_graph?
      Curie.get_mappings.each do | prefix, uri |
        return false if self.respond_to?(prefix.to_sym)
      end
      return true
    end
   
    def self.new(uri)
      #if self.exists?(uri)
      #  return self.instances[uri]
      #end
      if exists = self.instances[uri]
        return exists
      end
      super(uri)
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