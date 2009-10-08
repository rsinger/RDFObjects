# encoding: utf-8
require 'rubygems'
require 'strscan'
require 'iconv'
require 'uri'
require 'json'
require 'nokogiri'
require 'cgi'
if RUBY_VERSION < '1.9.0'
  $KCODE = 'u'
  require 'jcode'
end

class UTF8Parser < StringScanner
  STRING = /(([\x0-\x1f]|[\\\/bfnrt]|\\u[0-9a-fA-F]{4}|[\x20-\xff])*)/nx
  UNPARSED = Object.new      
  UNESCAPE_MAP = Hash.new { |h, k| h[k] = k.chr }
  UNESCAPE_MAP.update({
    ?"  => '"',
    ?\\ => '\\',
    ?/  => '/',
    ?b  => "\b",
    ?f  => "\f",
    ?n  => "\n",
    ?r  => "\r",
    ?t  => "\t",
    ?u  => nil, 
  })        
  UTF16toUTF8 = Iconv.new('utf-8', 'utf-16be')                
  def initialize(str)
    super(str)
    @string = str
  end
  def parse_string
    if scan(STRING)
      return '' if self[1].empty?
      string = self[1].gsub(%r((?:\\[\\bfnrt"/]|(?:\\u(?:[A-Fa-f\d]{4}))+|\\[\x20-\xff]))n) do |c|
        if u = UNESCAPE_MAP[$&[1]]
          u
        else # \uXXXX
          bytes = ''
          i = 0
          while c[6 * i] == ?\\ && c[6 * i + 1] == ?u
            bytes << c[6 * i + 2, 2].to_i(16) << c[6 * i + 4, 2].to_i(16)
            i += 1
          end
          UTF16toUTF8.iconv(bytes)
        end
      end
      if string.respond_to?(:force_encoding)
        string.force_encoding(Encoding::UTF_8)
      end
      string
    else
      UNPARSED
    end
  rescue Iconv::Failure => e
    raise StandardError, "Caught #{e.class}: #{e}"
  end  
end
module RDFObject
class NTriplesParser
  attr_reader :ntriple, :subject, :predicate, :data_type, :language, :literal
  attr_accessor :object
  def initialize(line)
    @ntriple = line
    if @ntriple.respond_to?(:force_encoding)
      @ntriple.force_encoding("ASCII-8BIT")
    end
    parse_ntriple
  end
  
  def parse_ntriple
    scanner = StringScanner.new(@ntriple)
    @subject = scanner.scan_until(/> /)
    @subject.sub!(/^</,'')
    @subject.sub!(/> $/,'')
    @predicate = scanner.scan_until(/> /)
    @predicate.sub!(/^</,'')
    @predicate.sub!(/> $/,'')
    if scanner.match?(/</)
      object = scanner.scan_until(/>\s?\.\s*\n?$/)
      object.sub!(/^</,'')
      object.sub!(/>\s?\.\s*\n?$/,'')
      @object = Resource.new(object)
    else
      @literal = true
      scanner.getch
      object = scanner.scan_until(/("\s?\.\s*\n?$)|("@[A-z])|("\^\^)/)
      scanner.pos=(scanner.pos-2)
      object.sub!(/"..$/,'')
      if object.respond_to?(:force_encoding)
        object.force_encoding('utf-8').chomp!
      else
        uscan = UTF8Parser.new(object)
        object = uscan.parse_string.chomp
      end
      if scanner.match?(/@/)
        scanner.getch
        @language = scanner.scan_until(/\s?\.\n?$/)
        @language.sub!(/\s?\.\n?$/,'')
      elsif scanner.match?(/\^\^/)
        scanner.skip_until(/</)
        @data_type = scanner.scan_until(/>/)
        @data_type.sub!(/>$/,'')
      end
      @object = Literal.new(object,{:data_type=>@data_type,:language=>@language})      
    end
  end
  
  def self.parse(resources)
    collection = []
    if resources.is_a?(String)
      assertions = resources.split("\n")
    elsif resources.is_a?(Array)
      assertions = resources
    elsif resources.respond_to?(:read)
      assertions = resources.readlines
    end
    assertions.each do | assertion |
      next if assertion[0, 1] == "#" # Ignore comments
      triple = self.new(assertion)
      resource = Resource.new(triple.subject)
      resource.assert(triple.predicate, triple.object)
      collection << resource
    end
    collection.uniq
  end
end

class XMLParser
  #
  # A very unsophisticated RDF/XML Parser -- currently only parses RDF/XML that conforms to 
  # the SimpleRdfXml convention:  http://esw.w3.org/topic/SimpleRdfXml.  This is a pragmatic
  # rather than dogmatic decision.  If it is not working with your RDF/XML let me know and we
  # can probably fix it.
  #
  def self.parse(doc)
    namespaces = doc.namespaces
    #if namespaces.index("http://purl.org/rss/1.0/")
    #  collection = parse_rss10(doc)
    if namespaces.index("http://www.w3.org/2005/sparql-results#")
      raise "Sorry, SPARQL not yet supported"
    else
      collection = parse_rdfxml(doc)
    end
    collection.uniq
  end
  
  def self.parse_resource_node(resource_node, collection)
    resource = Resource.new(resource_node.attribute_with_ns('about', "http://www.w3.org/1999/02/22-rdf-syntax-ns#").value)
    unless (resource_node.name == "Description" and resource_node.namespace.href == "http://www.w3.org/1999/02/22-rdf-syntax-ns#") or
      (resource_node.name == "item" and resource_node.namespace.href == "http://purl.org/rss/1.0/")
      resource.assert("[rdf:type]",Resource.new("#{resource_node.namespace.href}#{resource_node.name}"))
    end
    resource_node.children.each do | child |
      next if child.text?
      predicate = "#{child.namespace.href}#{child.name}"
      if object_uri = child.attribute_with_ns("resource", "http://www.w3.org/1999/02/22-rdf-syntax-ns#")
        obj_resource = Resource.new(object_uri.value)
        resource.assert(predicate, obj_resource)
        collection << obj_resource
      elsif all_text?(child)
        opts = {}
        if lang = child.attribute_with_ns("lang", "http://www.w3.org/XML/1998/namespace")
          opts[:language] = lang.value
        end
        if datatype = child.attribute_with_ns("datatype", "http://www.w3.org/1999/02/22-rdf-syntax-ns#")
          opts[:data_type] = datatype.value
        end
        resource.assert(predicate, Literal.new(child.content.strip,opts))
      end
      child.xpath("./*[@rdf:about]").each do | grandchild |
        gc_resource = Resource.new(grandchild.attribute_with_ns('about', "http://www.w3.org/1999/02/22-rdf-syntax-ns#").value)
        resource.assert(predicate, gc_resource)
        collection << gc_resource
        parse_resource_node(grandchild, collection)
      end
    end
    collection << resource        
  end
  
  def self.all_text?(node)
    node.children.each do | child |
      return false unless child.text?
    end
    true
  end
  
  def self.parse_rdfxml(doc)
    collection = []
    doc.root.xpath("./*[@rdf:about]").each do | resource_node |
      parse_resource_node(resource_node, collection)
    end
    collection
  end    
  
  #def self.parse_rss10(doc)
  #  collection = []
  #  doc.root.xpath("./rss:item","rss"=>"http://purl.org/rss/1.0/").each do | resource_node |
  #    parse_resource_node(resource_node, collection)
  #  end
  #  collection
  #end
end

class RDFAParser
  def self.parse(doc)
    xslt = Nokogiri::XSLT(open(File.dirname(__FILE__) + '/../xsl/RDFa2RDFXML.xsl'))
    rdf_doc = xslt.apply_to(doc)  
    XMLParser.parse(Nokogiri.parse(rdf_doc))  
  end
end

class JSONParser
  def self.parse(json)
    collection = []
    json.each_pair do |subject, assertions|
      resource = Resource.new(subject)
      collection << resource
      assertions.each_pair do |predicate, objects|
        objects.each do | object |
          if object['type'] == 'literal'
            opts = {}
            if object['lang']
              opts[:language] = object['lang']
            end
            if object['datatype']
              opts[:data_type] = object['datatype']
            end
            literal = Literal.new(object['value'],opts)
            resource.assert(predicate, literal)
          elsif object['type'] == 'uri'
            o = Resource.new(object['value'])
            resource.assert(predicate, o)
            collection << o
          elsif object['type'] == 'bnode' # For now, we're going to treat a blank node like a URI resource.
            o = Resource.new(object['value'])
            resource.assert(predicate, o)
            collection << o            
          end
        end
      end
    end
    collection.uniq
  end
end

class Parser
  # Choose the best format parser from an admittedly small group of choices.
  def self.parse(rdf)
    begin
      # Check if the format is XML or RDFa
      doc = Nokogiri::XML.parse(rdf, nil, nil, Nokogiri::XML::ParseOptions::PEDANTIC)
      raise "Unable to parse XML/HTML document -- no namespace declared" unless doc.root.namespaces
      if doc.root.namespaces.values.index("http://www.w3.org/1999/xhtml")
        collection = RDFAParser.parse(doc)
      else
        collection = XMLParser.parse(doc)
      end
    rescue Nokogiri::XML::SyntaxError
      begin
        if rdf.respond_to?(:read)
          rdf.rewind
          json = JSON.parse(rdf.read)
        else
          json = JSON.parse(rdf)
        end
        collection = JSONParser.parse(json)
      rescue JSON::ParserError
        if rdf.respond_to?(:read)
          rdf.rewind
        end
        collection = NTriplesParser.parse(rdf)
      end
    end
    collection  
  end
end
end