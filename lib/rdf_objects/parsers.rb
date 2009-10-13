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
  class Parser
    # Choose the best format parser from an admittedly small group of choices.
    def self.parse(rdf, format=nil)
      parser = init_parser(rdf, format)
      parser.parse 
    end
    
    def self.init_parser(rdf, format=nil)
      if format
        parser = case format
        when 'rdfxml' then XMLParser.new(rdf)
        when 'rdfa' then RDFAParser.new(rdf)
        when 'ntriples' then NTriplesParser.new(rdf)
        when 'json' then JSONParser.new(rdf)
        end        
      else
        begin
          # Check if the format is XML or RDFa
          doc = Nokogiri::XML.parse(rdf, nil, nil, Nokogiri::XML::ParseOptions::PEDANTIC)
          raise "Unable to parse XML/HTML document -- no namespace declared" unless doc.root.namespaces
          if doc.root.namespaces.values.index("http://www.w3.org/1999/xhtml")
            parser = RDFAParser.new(doc)
          else
            parser = XMLParser.new(doc)
          end
        rescue Nokogiri::XML::SyntaxError
          begin
            if rdf.respond_to?(:read)
              rdf.rewind
              json = JSON.parse(rdf.read)
            else
              json = JSON.parse(rdf)
            end
            parser = JSONParser.new(json)
          rescue JSON::ParserError
            if rdf.respond_to?(:read)
              rdf.rewind
            end
            parser = NTriplesParser.new(rdf)
          end
        end
      end
      parser
    end 
         
    attr_reader :collection
    def initialize(data=nil)
      @collection = Collection.new
      self.data=(data) if data
    end
    def collection=(collection)
      raise ArgumentError unless collection.is_a?(RDFObject::Collection)
      @collection = collection
    end
  end  
  class NTriplesParser < RDFObject::Parser
  
    def parse_ntriple(ntriple)
      if ntriple.respond_to?(:force_encoding)
        ntriple.force_encoding("ASCII-8BIT")
      end      
      scanner = StringScanner.new(ntriple)
      subject = scanner.scan_until(/> /)
      subject.sub!(/^</,'')
      subject.sub!(/> $/,'')
      predicate = scanner.scan_until(/> /)
      predicate.sub!(/^</,'')
      predicate.sub!(/> $/,'')
      if scanner.match?(/</)
        tmp_object = scanner.scan_until(/>\s?\.\s*\n?$/)
        tmp_object.sub!(/^</,'')
        tmp_object.sub!(/>\s?\.\s*\n?$/,'')
        object = tmp_object
        type = "uri"
      else
        language = nil
        data_type = nil
        scanner.getch
        tmp_object = scanner.scan_until(/("\s?\.\s*\n?$)|("@[A-z])|("\^\^)/)
        scanner.pos=(scanner.pos-2)
        tmp_object.sub!(/"..$/,'')
        if tmp_object.respond_to?(:force_encoding)
          tmp_object.force_encoding('utf-8').chomp!
        else
          uscan = UTF8Parser.new(tmp_object)
          tmp_object = uscan.parse_string.chomp
        end
        if scanner.match?(/@/)
          scanner.getch
          language = scanner.scan_until(/\s?\.\n?$/)
          language.sub!(/\s?\.\n?$/,'')
        elsif scanner.match?(/\^\^/)
          scanner.skip_until(/</)
          data_type = scanner.scan_until(/>/)
          data_type.sub!(/>$/,'')
        end
        object = Literal.new(tmp_object,{:data_type=>data_type,:language=>language})
        type = "literal"      
      end
      {:subject=>subject, :predicate=>predicate, :object=>object, :type=>type}
    end
    
    def data=(ntriples)
      if ntriples.is_a?(String)
        @ntriples = ntriples.split("\n")
      elsif ntriples.is_a?(Array)
        @ntriples = ntriples
      elsif ntriples.respond_to?(:read)
        @ntriples = ntriples.readlines
      end      
    end
  
    def parse
      @ntriples.each do | assertion |
        next if assertion[0, 1] == "#" # Ignore comments
        triple = parse_ntriple(assertion)
        resource = @collection.find_or_create(triple[:subject])
        object = case triple[:type]
        when "literal" then triple[:object]
        when "uri" then @collection.find_or_create(triple[:object])
        end
        resource.assert(triple[:predicate],object)
      end
      @collection
    end
  end

  class XMLParser < RDFObject::Parser
    #
    # A very unsophisticated RDF/XML Parser -- currently only parses RDF/XML that conforms to 
    # the SimpleRdfXml convention:  http://esw.w3.org/topic/SimpleRdfXml.  This is a pragmatic
    # rather than dogmatic decision.  If it is not working with your RDF/XML let me know and we
    # can probably fix it.
    #
    
    def parse
      if @rdfxml.namespaces.values.index("http://purl.org/rss/1.0/")
        fix_rss10
      end
      if @rdfxml.namespaces.values.index("http://www.w3.org/2005/sparql-results#")
        raise "Sorry, SPARQL not yet supported"
      else
        parse_rdfxml
      end
      @collection
    end
    
    def data=(xml)
      if xml.is_a?(Nokogiri::XML::Document)
        @rdfxml = xml
      else
        @rdfxml = Nokogiri::XML.parse(xml, nil, nil, Nokogiri::XML::ParseOptions::PEDANTIC)
      end
    end
  
    def parse_resource_node(resource_node, collection)
      resource = @collection.find_or_create(resource_node.attribute_with_ns('about', "http://www.w3.org/1999/02/22-rdf-syntax-ns#").value)
      unless (resource_node.name == "Description" and resource_node.namespace.href == "http://www.w3.org/1999/02/22-rdf-syntax-ns#")
        resource.assert("[rdf:type]", @collection.find_or_create("#{resource_node.namespace.href}#{resource_node.name}"))
      end
      resource_node.children.each do | child |
        next if child.text?
        predicate = "#{child.namespace.href}#{child.name}"
        if object_uri = child.attribute_with_ns("resource", "http://www.w3.org/1999/02/22-rdf-syntax-ns#")
          obj_resource = @collection.find_or_create(object_uri.value)
          resource.assert(predicate, obj_resource)
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
          gc_resource = @collection.find_or_create(grandchild.attribute_with_ns('about', "http://www.w3.org/1999/02/22-rdf-syntax-ns#").value)
          resource.assert(predicate, gc_resource)
          parse_resource_node(grandchild, collection)
        end
      end
    end
  
    def all_text?(node)
      node.children.each do | child |
        return false unless child.text?
      end
      true
    end
  
    def parse_rdfxml
      collection = []
      @rdfxml.root.xpath("./*[@rdf:about]").each do | resource_node |
        parse_resource_node(resource_node, collection)
      end
    end    
  
    def fix_rss10
      @rdfxml.root.xpath('./rss:channel/rss:items/rdf:Seq/rdf:li', {"rdf"=>"http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        "rss"=>"http://purl.org/rss/1.0/"}).each do | li |
        if li['resource'] && !li["rdf:resource"]
          li["rdf:resource"] = li["resource"]
        end
      end
    end
  end

  class RDFAParser < XMLParser
    def data=(xhtml)
      if xhtml.is_a?(Nokogiri::XML::Document)
        doc = xhtml
      else
        doc = Nokogiri::HTML.parse(xhtml)
      end
      xslt = Nokogiri::XSLT(open(File.dirname(__FILE__) + '/../xsl/RDFa2RDFXML.xsl'))
      rdfxml = xslt.apply_to(doc)      
      @rdfxml = Nokogiri::XML.parse(rdfxml, nil, nil, Nokogiri::XML::ParseOptions::PEDANTIC)
    end    
  end

  class JSONParser < RDFObject::Parser
    
    def data=(json)
      if json.is_a?(String)
        @json = JSON.parse(json)
      elsif json.is_a?(Hash)
        @json = json
      elsif json.respond_to?(:read)
        @json = JSON.parse(json.read)
      end
    end
    
    def parse
      @json.each_pair do |subject, assertions|
        resource = @collection.find_or_create(subject)
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
              o = @collection.find_or_create(object['value'])
              resource.assert(predicate, o)
            elsif object['type'] == 'bnode' # For now, we're going to treat a blank node like a URI resource.
              o = @collection.find_or_create(object['value'])
              resource.assert(predicate, o)
            end
          end
        end
      end
      @collection
    end
  end


end