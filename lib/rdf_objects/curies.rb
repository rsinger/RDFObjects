require 'rubygems'
require 'curies'
class Curie
  @@namespace_counter = 0
  
  # Returns a Curie object from a fully qualified uri (assuming it is registered)
  def self.curie_from_uri(uri_string)
    @@mappings.each do | prefix, uri |
      if m = uri_string.match(/^#{uri}(.*)/)
        return self.new(prefix, m[1]) if m[1]
      end
    end
    false
  end
  
  # Returns the Curie prefix for a URI
  def self.prefix_for(uri_string)
    @@mappings.each do | prefix, uri |
      if m = uri_string.match(/^#{uri}(.*)/)
        return prefix
      end
    end
    false
  end
  
  # Automatically tries to build a safe curie from a uri string.
  # Assumes an RDF Schema and a flat hierarchy.
  def self.create_from_uri(uri_string, prefix=nil)
    if curie = self.curie_from_uri(uri_string)
      return curie
    end
    uri = URI.parse(uri_string)
    ns = nil
    elem = nil    
    if uri.fragment
      ns, elem = uri.to_s.split('#')
      ns << '#'
    else
      elem = uri.path.split('/').last
      ns = uri.to_s.sub(/#{elem}$/, '')
    end  
    unless prefix
      prefix = "n#{@@namespace_counter}"
      @@namespace_counter += 1
    end
    Curie.add_prefixes!  prefix.to_s => ns
    self.curie_from_uri(uri_string)
  end
  
  def self.get_mappings
    return @@mappings
  end
  
  # Return a Curie object from a safe curie string.
  def self.new_from_curie(curie_string)
    unless curie_string.could_be_a_safe_curie?
      raise "not a real curie"
    end
    prefix, resource = curie_string.curie_parts
    return Curie.new(prefix, resource)
  end
end