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
      elsif !object.is_a?(ResourceReference) && !object.is_a?(BlankNode)
        object = RDF::Literal.new(object) unless object.is_a?(RDF::Literal)
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
              if object.is_a?(ResourceReference) || object.is_a?(BlankNode)
                line << object.ntriples_format
              else
                object = RDF::Literal.new(object) unless object.is_a?(RDF::Literal)
                line << "#{object.value.to_json}"
                line << "^^<#{object.datatype}>" if object.has_datatype?
                line << "@#{object.language}" if object.has_language?
              end
              line << " .\n"
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
    
    def to_json_hash
      j_hash = {self.uri=>{}}
      self.assertions.each_pair do |pred,objects|
        j_hash[self.uri][pred] = []
        if objects.is_a?(Array)
          objects.each do |object|
            j_hash[self.uri][pred] << object_to_json_hash(object)              
          end
        else
          j_hash[self.uri][pred] << object_to_json_hash(objects)   
        end
      end
      j_hash
    end
    
    def object_to_json_hash(object)
      if object.is_a?(Resource) or object.is_a?(ResourceReference)
        o = {:type=>"uri", :value=>object.uri}
      elsif object.is_a?(BlankNode)
        o = {:type=>"bnode", :value=>object.uri}
      else
        object = RDF::Literal.new(object) unless object.is_a?(RDF::Literal)
        o = {:type=>"literal", :value=>object.value}
        o[:lang] = object.language.to_s if object.has_language?
        o[:datatype] = object.datatype.to_s if object.has_datatype?        
      end
      o
    end
      
    
    def to_json
      JSON.generate(to_json_hash)
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
              if object.is_a?(RDFObject::ResourceReference) || object.is_a?(RDFObject::BlankNode)
                if depth == 0
                  rdf << " #{object.xml_object_attribute} />"
                else
                  rdf << ">"                  
                  ns, rdf_data = object.rdf_description_block(depth-1)
                  namespaces.merge!(ns)
                  rdf << rdf_data
                  rdf << "</#{key}:#{predicate}>"
                end
              else
                object = RDF::Literal.new(object) unless object.is_a?(RDF::Literal)
                if object.language
                  rdf << " xml:lang=\"#{object.language}\""
                end
                if object.datatype
                  rdf << " rdf:datatype=\"#{object.datatype}\""
                end
                rdf << ">#{CGI.escapeHTML(object.value)}</#{key}:#{predicate}>"
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
      return false unless self.assertions.keys.sort == other.assertions.keys.sort
      self.assertions.each_pair do |pred, objects|
        return false if objects.class != other[pred].class
        objects = [objects] unless objects.is_a?(Array)
        objects.each do | o |
          match = false
          [*other[pred]].each do |oo|
            next unless oo
            next unless o.class == oo.class
            if oo.is_a?(RDF::Literal)
              match = o == oo
            else
              match = o.uri == oo.uri
            end
            break if match
          end
          return false unless match
        end

      end
      return true      
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
        uri = Addressable::URI.parse(str).normalize
        return true if uri.scheme.nil? or !uri.scheme =~ /[A-z]/
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