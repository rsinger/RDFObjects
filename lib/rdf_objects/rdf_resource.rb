require 'uri'
require 'builder'
require 'date'
require 'curies'

module RDFObject
class Resource < OpenStruct
  class << self
    attr_reader :instances

    def instances
      @instances ||= {}
      @instances
    end

    def reset!
      @instances = {}
    end

    def register(resource)
      instances
      @instances[resource.uri] = resource
    end

    def remove(resource)
      instances      
      @instances.delete(resource.uri)
    end
    
    def exists?(uri)
      instances
      if @instances.has_key?(uri)
        true
      else
        false
      end
    end
  end

  def initialize(uri)        
    if uri.could_be_a_safe_curie?
      uri = Curie.parse uri
    end
    super(:uri=>uri)
    self.class.register(self)
  end
  
  def assert(predicate, object)
    curied_predicate = case
    when predicate.could_be_a_safe_curie? then Curie.new_from_curie(predicate)
    when Curie.curie_from_uri(predicate) then Curie.curie_from_uri(predicate)
    else Curie.create_from_uri(predicate)
    end
    self.register_vocabulary(curied_predicate.prefix)
    pred_attr = self.send(curied_predicate.prefix.to_sym)
    if pred_attr[curied_predicate.reference]
      unless pred_attr[curied_predicate.reference].is_a?(Array)
        pred_attr[curied_predicate.reference] = [pred_attr[curied_predicate.reference]]
      end
      pred_attr[curied_predicate.reference] << object
    else
      pred_attr[curied_predicate.reference] = object
    end
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
    unless self.empty_graph?
      raise "Cannot describe a Resource with attributes already set!"
    end
  
    rdf = HTTPClient.fetch(self.uri)
    Parser.parse(rdf)
  end
  
  def empty_graph?
    Curie.get_mappings.each do | prefix, uri |
      return false if self.respond_to?(prefix.to_sym)
    end
    return true
  end
  
  def to_xml
    doc = Builder::XmlMarkup.new
    xmlns = {}
    i = 1
    @namespaces.each do | ns |
      next if ns == 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
      xmlns["xmlns:n#{i}"] = ns
      i += 1
    end
    doc.rdf :Description,xmlns.merge({:about=>uri}) do | rdf |
      self.instance_variables.each do | ivar |
        next unless ivar =~ /^@n[0-9]*_/
        prefix, tag = ivar.split('_',2)
        attrs = {}
        curr_attr = self.instance_variable_get("#{ivar}")
        prefix.sub!(/^@/,'')
        prefix = 'rdf' if prefix == 'n0'
        unless curr_attr.is_a?(Array)
          curr_attr = [curr_attr]
        end
        curr_attr.each do | val |
          if val.is_a?(RDFResource)
            attrs['rdf:resource'] = val.uri
          end
          if @modifiers[val.object_id]
            if @modifiers[val.object_id][:language]
              attrs['xml:lang'] = @modifiers[val.object_id][:language]
            end
            if @modifiers[val.object_id][:type]
              attrs['rdf:datatype'] = @modifiers[val.object_id][:type]
            end          
          end
          unless attrs['rdf:resource']
            rdf.tag!("#{prefix}:#{tag}", attrs, val)
          else
            rdf.tag!("#{prefix}:#{tag}", attrs)
          end
        end
      end
    end
    doc.target!
  end
  
  def to_rss
    doc = Builder::XmlMarkup.new
    xmlns = {}
    i = 1
    @namespaces.each do | ns |
      next if ns == 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
      xmlns["xmlns:n#{i}"] = ns
      i += 1
    end
    xmlns["xmlns:rss"] = "http://purl.org/rss/1.0/"
    doc.rdf :RDF, xmlns do | rdf |
      rdf.item :about=>uri do | item |
        self.instance_variables.each do | ivar |
          next unless ivar =~ /^@n[0-9]*_/
          prefix, tag = ivar.split('_',2)
          attrs = {}
          curr_attr = self.instance_variable_get("#{ivar}")
          prefix.sub!(/^@/,'')
          prefix = 'rdf' if prefix == 'n0'
          unless curr_attr.is_a?(Array)
            curr_attr = [curr_attr]
          end
          curr_attr.each do | val |
            if val.is_a?(RDFResource)
              attrs['rdf:resource'] = val.uri
            end
            if @modifiers[val.object_id]
              if @modifiers[val.object_id][:language]
                attrs['xml:lang'] = @modifiers[val.object_id][:language]
              end
              if @modifiers[val.object_id][:type]
                attrs['rdf:datatype'] = @modifiers[val.object_id][:type]
              end          
            end
            unless attrs['rdf:resource']
              item.tag!("#{prefix}:#{tag}", attrs, val)
            else
              item.tag!("#{prefix}:#{tag}", attrs)
            end
          end
        end
      end
    end
    doc.target!
  end    
  def self.new(uri)
    if self.exists?(uri)
      return self.instances[uri]
    end
    super(uri)
  end
  
   
end
end