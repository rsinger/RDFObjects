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
    attr_reader :base_uri
    # Choose the best format parser from an admittedly small group of choices.
    def self.parse(rdf, options={})
      parser = init_parser(rdf, options)
      parser.parse if parser
    end
    
    def self.init_parser(rdf, options={})
      if options[:format]
        parser = case options[:format]
        when 'rdfxml' then XMLParser.new(rdf)
        when 'rdfa' then RDFAParser.new(rdf)
        when 'ntriples' then NTriplesParser.new(rdf)
        when 'json' then JSONParser.new(rdf)
        end        
      else
        # Check to see if it is a URI being passed
        if rdf.is_a?(String)
          begin
            uri = Addressable::URI.parse(rdf)
            if uri.ip_based?
              response =  HTTPClient.fetch(rdf)
              rdf = response[:content]
              options[:base_uri] = response[:uri]
            end
          rescue URI::InvalidURIError
          end
        end
        # Check if the format is XML or RDFa
        doc = XMLTestDocument.new
        p = Nokogiri::XML::SAX::Parser.new(doc)
        if rdf.respond_to?(:read)
          p.parse(rdf.read)
        else
          p.parse(rdf)
        end
        if doc.is_doc?
          if rdf.respond_to?(:read)
            rdf.rewind
          end
          if doc.is_html?

            parser = RDFAParser.new(rdf)
          elsif doc.is_rdf?              
            parser = XMLParser.new(rdf)
          end
        else
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
      if options[:base_uri] && parser
        parser.base_uri = options[:base_uri]
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
    
    def base_uri=(uri)
      if uri.is_a?(URI)
        @base_uri = uri
      else
        @base_uri = Addressable::URI.parse(uri).normalize
      end
    end
    
    def sanitize_uri(uri)
      # Fix some weirdness surrounding escaped ampersands in URIs.
      uri.gsub!(/&#38;/,"&")
      # Return if there's nothing to sanitize with
      return uri unless self.base_uri
      begin
        u = Addressable::URI.parse(uri).normalize
        return uri if u.host
        fq_uri = self.base_uri+u
        fq_uri.to_s
      rescue URI::InvalidURIError
        uri
      end
    end
  end  
  class NTriplesParser < RDFObject::Parser
  
    def parse_ntriple(ntriple)
      if ntriple.respond_to?(:force_encoding)
        ntriple.force_encoding("ASCII-8BIT")
      end      
      scanner = StringScanner.new(ntriple)
      if ntriple[0,1] == "<"
        subject = scanner.scan_until(/> /)
        subject.sub!(/^</,'')
        subject.sub!(/> $/,'')
      else
        subject = scanner.scan_until(/\w /)
        subject.strip!
      end
      predicate = scanner.scan_until(/> /)
      predicate.sub!(/^</,'')
      predicate.sub!(/> $/,'')
      if scanner.match?(/</)
        tmp_object = scanner.scan_until(/>\s?\.\s*\n?$/)
        tmp_object.sub!(/^</,'')
        tmp_object.sub!(/>\s?\.\s*\n?$/,'')
        object = self.sanitize_uri(tmp_object)
        type = "uri"
      elsif scanner.match?(/_:/)
        object = scanner.scan_until(/\w\s?\.\s*\n?$/)
        object.sub!(/\s?\.\s*\n?$/,'')
        type = "bnode"
      else
        language = nil
        data_type = nil
        scanner.getch
        tmp_object = scanner.scan_until(/("\s?\.\s*\n?$)|("@[A-z])|("\^\^)/)
        scanner.pos=(scanner.pos-2)
        tmp_object.sub!(/"..?$/,'')
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
          language = language.to_sym
        elsif scanner.match?(/\^\^/)
          scanner.skip_until(/</)
          data_type = scanner.scan_until(/>/)
          data_type.sub!(/>$/,'')
        end
        object = RDF::Literal.new(tmp_object,{:datatype=>data_type,:language=>language})
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
        when "bnode" then @collection.find_or_create(triple[:object])
        end
        resource.assert(triple[:predicate],object)
      end
      @collection
    end
  end

  class XMLTestDocument < Nokogiri::XML::SAX::Document
    def initialize
      @xml_start = false
      @xml_end = false
      @namespaces = []
    end
    
    def start_element(name, attrs=[])
      @xml_start = name
      attrs.each do | attrib |
        next unless attrib.is_a?(Array)
        if attrib.first =~ /^xmlns(:|\b)/
          @namespaces << attrib.last
        end
      end
    end
    
    def end_element(name)
      if @xml_start
        @xml_end = true if name = @xml_start
      end
    end
    
    def is_doc?
      return true if @xml_start && @xml_end
      return false
    end
    
    def is_rdf?
      return true if @namespaces.index("http://www.w3.org/1999/02/22-rdf-syntax-ns#")
      return false
    end
    
    def is_html?
      return true if @namespaces.index("http://www.w3.org/1999/xhtml")
      return true if @xml_start =~ /html/i
      return false
    end
  end
  
  class XMLParser < RDFObject::Parser
    def initialize(data=nil)
      super(data)
      @uris = []
      @tags = {}
      @parser = Nokogiri::XML::SAX::Parser.new(self)
      @hierarchy = []
      @xml_base = nil
      @default_namespace = nil
    end
    
    def data=(xml)
      if xml.is_a?(String)
        @rdfxml = xml
      elsif xml.respond_to?(:read)
        xml.rewind
        @rdfxml = xml.read
      end
    end
    
    def parse
      @parser.parse(@rdfxml)
      @collection
    end
    
    def method_missing(methName, *args)
      sax_methods = [:xmldecl, :start_document, :end_document, :start_element,
        :end_element, :comment, :warning, :error, :cdata_block]
      unless sax_methods.index(methName)
        raise NoMethodError.new("undefined method '#{methName} for #{self}", 'no_meth')
      end
    end
    
    def attributes_to_hash(attributes, namespaces, name, prefix)
      hash = {}
      attributes.each do | att |
        ns = att.uri || @default_namespace
        unless ns =~ /[#\/]$/
          ns << "/"
        end
        hash["#{ns}#{att.localname}"] = att.value
      end
      hash
    end
    
    def attributes_as_assertions(attributes)
      skip = ["http://www.w3.org/XML/1998/namespace/lang", "http://www.w3.org/XML/1998/namespace/base", 
        "http://www.w3.org/1999/02/22-rdf-syntax-ns#resource", "http://www.w3.org/1999/02/22-rdf-syntax-ns#about",
        "http://www.w3.org/1999/02/22-rdf-syntax-ns#nodeID", "http://www.w3.org/1999/02/22-rdf-syntax-ns#datatype"]
      attributes.each_pair do | uri, value |
        next if skip.index(uri)
        lit = RDF::Literal.new(value, {:datatype=>attributes["http://www.w3.org/1999/02/22-rdf-syntax-ns#datatype"]})
        if attributes["http://www.w3.org/XML/1998/namespace/lang"]
          lit.language = attributes["http://www.w3.org/XML/1998/namespace/lang"].to_sym
        end
        self.current_resource.assert(uri, lit)
      end
    end
    
    def add_layer name, attributes, prefix, uri, ns
      layer = {:name=>"#{uri}#{name}"}
      if attributes['http://www.w3.org/1999/02/22-rdf-syntax-ns#about'] or 
        (attributes['http://www.w3.org/1999/02/22-rdf-syntax-ns#nodeID'] && (@hierarchy.length == 1 || @hierarchy.last[:predicate]))
        id = attributes['http://www.w3.org/1999/02/22-rdf-syntax-ns#about'] || 
          attributes['http://www.w3.org/1999/02/22-rdf-syntax-ns#nodeID']
        id = sanitize_uri(id) if attributes['http://www.w3.org/1999/02/22-rdf-syntax-ns#about']
        layer[:resource] = @collection.find_or_create(id)
        unless "#{uri}#{name}" == "http://www.w3.org/1999/02/22-rdf-syntax-ns#Description"
          layer[:resource].relate("http://www.w3.org/1999/02/22-rdf-syntax-ns#type", @collection.find_or_create("#{uri}#{name}"))
        end 
        if !@hierarchy.empty? && @hierarchy.last[:predicate]
          self.current_resource.relate(self.current_predicate, layer[:resource])
        end
      elsif attributes["http://www.w3.org/1999/02/22-rdf-syntax-ns#resource"] or 
          (attributes['http://www.w3.org/1999/02/22-rdf-syntax-ns#nodeID'] && @hierarchy.length > 1 && @hierarchy.last[:predicate].nil?)
          res = attributes['http://www.w3.org/1999/02/22-rdf-syntax-ns#resource'] || attributes['http://www.w3.org/1999/02/22-rdf-syntax-ns#nodeID']
        self.current_resource.assert("#{uri}#{name}", @collection.find_or_create(sanitize_uri(res)))    
        layer[:predicate] = layer[:name]
      else
        unless layer[:name] == "http://www.w3.org/1999/02/22-rdf-syntax-ns#RDF"
          layer[:predicate] = layer[:name]
        end
      end
      if attributes["http://www.w3.org/1999/02/22-rdf-syntax-ns#datatype"] || attributes["http://www.w3.org/XML/1998/namespace/lang"]
        layer[:datatype] = attributes["http://www.w3.org/1999/02/22-rdf-syntax-ns#datatype"] if attributes["http://www.w3.org/1999/02/22-rdf-syntax-ns#datatype"]
        layer[:language] = attributes["http://www.w3.org/XML/1998/namespace/lang"].to_sym if attributes["http://www.w3.org/XML/1998/namespace/lang"]        
      end    
      layer[:base_uri] = Addressable::URI.parse(attributes["http://www.w3.org/XML/1998/namespace/base"]).normalize if attributes["http://www.w3.org/XML/1998/namespace/base"]  
      @hierarchy << layer
      attributes_as_assertions(attributes)
    end
    
    def remove_layer(name)
      unless @hierarchy.last[:name] == name
        throw ArgumentError, "Hierarchy out of sync."
      end
      layer = @hierarchy.pop
      assert_literal(layer) if layer[:literal] && !layer[:literal].empty?
    end
    
    def assert_literal(layer)
      lit = RDF::Literal.new(layer[:literal], {:datatype=>layer[:datatype], :language=>layer[:language]})  
      self.current_resource.assert(layer[:predicate], lit) if layer[:predicate]     
    end
    
    def current_resource
      @hierarchy.reverse.each do | layer |
        return layer[:resource] if layer[:resource]
      end
    end
    
    def current_predicate
      @hierarchy.reverse.each do | layer |
        return layer[:predicate] if layer[:predicate]
      end      
    end
    
    def current_literal
      unless @hierarchy.empty?
        return @hierarchy.last[:literal] if @hierarchy.last[:literal]
        unless @hierarchy.last[:resource]
          @hierarchy.last[:literal] = ""
          return @hierarchy.last[:literal]
        end
      end
    end
    
    def base_uri
      @hierarchy.reverse.each do | layer |
        return layer[:base_uri] if layer[:base_uri]
      end      
      @base_uri
    end
    
    def start_element_namespace name, attributes = [], prefix = nil, uri = nil, ns = {}
      check_for_default_ns(ns)
      attributes = attributes_to_hash(attributes, ns, name, prefix)
      
      add_layer(name, attributes, prefix, uri, ns)
    end

    def check_for_default_ns(ns)
      return unless self.current_resource.empty?
      ns.each do | n |
        if n.first.nil?
          @default_namespace = n.last
        end
      end
    end
    
    def characters text
      if self.current_literal && !text.strip.empty?
        self.current_literal << text.strip
      end
    end

    def end_element_namespace name, prefix = nil, uri = nil
      remove_layer("#{uri}#{name}")
    end  
  end  
  
  class RDFAParser < Parser
    def data=(xhtml)
      @rdfa = xhtml  
    end    
    
    def parse
      rdfa_parser = RdfaParser::RdfaParser.new()
      html = open(uri)
      ntriples = ""
      rdfa_parser.parse(@rdfa, base_uri).each do | triple |
        ntriples << triple.to_ntriples + "\n"
      end
      RDFObject::Parser.parse(ntriples)
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
                opts[:language] = object['lang'].to_sym
              end
              if object['datatype']
                opts[:datatype] = object['datatype']
              end
              literal = RDF::Literal.new(object['value'],opts)
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