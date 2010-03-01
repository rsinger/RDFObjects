require 'uri'
require 'date'
require 'curies'

module RDFObject
  module Node
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
      unless resource.is_a?(Resource) or resource.is_a?(BlankNode) or resource.is_a?(ResourceReference)
        if BlankNode.is_bnode_id?(resource)
          resource = BlankNode.new(resource)
        else
          resource = Resource.new(resource)
        end
      end
      self.assert(predicate, resource)
    end
  
    def describe
      response = HTTPClient.fetch(self.uri)
      local_collection = Parser.parse(response[:content], {:base_uri=>response[:uri]})
      return unless local_collection && local_collection[self.uri]
      local_collection[self.uri].assertions.each do | predicate, object |
        [*object].each do | obj |
          self.assert(predicate, obj) unless self.assertion_exists?(predicate, obj)
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
    
    def to_ntriples
      ntriples = ""
      Curie.get_mappings.each do | prefix, uri |
        if self[uri]
          self[uri].keys.each do | pred |    
            if self[uri][pred].is_a?(Array)
              objects = self[uri][pred]
            else
              objects = [self[uri][pred]]
            end
            objects.each do | object |           
              line = "#{ntriples_format} <#{uri}#{pred}> "
              if object.is_a?(ResourceReference)
                line << object.ntriples_format
              else
                line << "#{object.to_json}"
                if (object.respond_to?(:data_type) || object.respond_to?(:language))
                  if object.data_type
                    line << "^^<#{object.data_type}>"
                  end
                  if object.language
                    line << "@#{object.language}"
                  end
                end
              end
              line << ".\n"
              ntriples << line              
            end
          end
        end
      end 
      ntriples     
    end
    
    def to_xml(depth=0)
      namespaces, rdf_data = rdf_description_block(depth)
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
    
    def rdf_description_block(depth=0)
      rdf = "<rdf:Description #{xml_subject_attribute}>"
      namespaces = {}
      Curie.get_mappings.each_pair do |key, value|
        if self.respond_to?(key.to_sym)
          self.send(key.to_sym).each_pair do | predicate, objects |
            [*objects].each do | object |
              rdf << "<#{key}:#{predicate}"
              namespaces["xmlns:#{key}"] = "#{Curie.parse("[#{key}:]")}"
              if object.is_a?(RDFObject::ResourceReference)
                if depth == 0
                  rdf << " #{object.xml_object_attribute} />"
                else
                  rdf << ">"
                  ns, rdf_data = object.resource.rdf_description_block(depth-1)
                  namespaces.merge!(ns)
                  rdf << rdf_data
                  rdf << "</#{key}:#{predicate}>"
                end
              else
                if object.language
                  rdf << " xml:lang=\"#{object.language}\""
                end
                if object.data_type
                  rdf << " rdf:datatype=\"#{object.data_type}\""
                end
                rdf << ">#{CGI.escapeHTML(object.to_s)}</#{key}:#{predicate}>"
              end
            end
          end
        end
      end
      rdf << "</rdf:Description>"
      [namespaces, rdf]
    end    
    
    def ==(other)
      return false unless other.is_a?(self.class) or other.is_a?(ResourceReference)
      return false unless self.uri == other.uri
      Curie.get_mappings.each do | prefix, uri |
        next unless self[uri] or other[uri]
        return false if self[uri] && !other[uri]
        return false if !self[uri] && other[uri]     
        return false if self[uri].class != other[uri].class  
        if self[uri] != other[uri]
          if self[uri].is_a?(Hash)            
            return false unless self[uri].keys.eql?(other[uri].keys)
            self[uri].keys.each do | pred |
              if self[uri][pred].is_a?(Array)
                return false unless self[uri][pred].length == other[uri][pred].length
                self[uri][pred].each do | idx |
                  return false unless other[uri][pred].index(idx)
                end
                other[uri][pred].each do | idx |
                  return false unless self[uri][pred].index(idx)
                end
              else
                if self[uri][pred].is_a?(Resource) or self[uri][pred].is_a?(BlankNode) or self[uri][pred].is_a?(ResourceReference)
                  return false unless other[uri][pred].is_a?(Resource) or self[uri][pred].is_a?(BlankNode) or other[uri][pred].is_a?(ResourceReference)
                  return false unless self[uri][pred].uri == other[uri][pred].uri
                else
                  return false unless self[uri][pred] == other[uri][pred]
                end
              end
            end
          else
            return false 
          end
        end
      end
      true
    end
  end    
  
  class Resource < OpenStruct
    include RDFObject::Node
    attr_reader :table
    def initialize(uri)        
      if uri.could_be_a_safe_curie?
        uri = Curie.parse uri
      end
      super(:uri=>uri)
    end

    def xml_subject_attribute
      "rdf:about=\"#{CGI.escapeHTML(self.uri)}\""
    end
    
    def xml_object_attribute
      "rdf:resource=\"#{CGI.escapeHTML(self.uri)}\""
    end   
    
    def ntriples_format
      "<#{uri}>" 
    end  
  end
  
  class BlankNode < OpenStruct
    include RDFObject::Node
    require 'digest/md5'
    def initialize(node_id = nil)        
      super(:node_id=>sanitize_bnode_id(node_id||Digest::MD5.hexdigest(self.object_id.to_s + "/" + DateTime.now.to_s).to_s))
    end    
    
    def describe; end
    
    def uri
      "_:#{self.node_id}"
    end
    
    def xml_subject_attribute
      "rdf:nodeID=\"#{self.node_id}\""
    end
    
    def xml_object_attribute
      xml_subject_attribute
    end
    
    def ntriples_format
      uri
    end
    
    def self.is_bnode_id?(str)
      return true if str =~ /^_\:/
      if str.could_be_a_safe_curie?
        str = Curie.parse str
      end
      begin
        uri = URI.parse(str)
        return true unless uri.scheme
      rescue URI::InvalidURIError
        return true
      end
      return false  
    end
    
    def sanitize_bnode_id(str)
      str.sub(/^_\:/,"")
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