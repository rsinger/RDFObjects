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
            parser = XMLParser.new(rdf)
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
    def initialize(data=nil)
      super(data)
      @uris = []
      @tags = {}
      @parser = Nokogiri::XML::SAX::Parser.new(self)
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
    
    def attributes_to_hash(attributes)
      hash = {}
      attributes.each do | att |
        hash[att.localname] = att.value
      end
      hash
    end
    
    def add_layer(element_uri, resource_uri)
      if @uris.length > 0 && @current_predicate
        @collection[@uris.last].relate(@current_predicate, @collection.find_or_create(resource_uri))
        @current_predicate = nil
      end
      @uris << resource_uri
      @tags[resource_uri] = element_uri              
    end
    
    def remove_layer(element_uri)
      uris = []
      @tags.each do |uri, el|
        uris << uri if el == element_uri
      end
      uris.each do | uri |  
        if @uris.last == uri
          @uris.pop
          @tags.delete(uri)
          break
        end
      end
      @current_resource = @collection[@uris.last]
    end
    
    def start_element_namespace name, attributes = [], prefix = nil, uri = nil, ns = {}
       attributes = attributes_to_hash(attributes)
       if attributes["about"]
         @current_resource = @collection.find_or_create(attributes['about'])
         add_layer("#{uri}#{name}", @current_resource.uri)
         unless "#{uri}#{name}" == "http://www.w3.org/1999/02/22-rdf-syntax-ns#Description"
           @current_resource.relate("http://www.w3.org/1999/02/22-rdf-syntax-ns#type", @collection.find_or_create("#{uri}#{name}"))
         end
       elsif attributes["resource"]
         resource = @collection.find_or_create(attributes['resource'])
         @current_resource.assert("#{uri}#{name}", resource)
       else
         @current_predicate = "#{uri}#{name}"
       end
       if attributes["datatype"] || attributes["lang"]
         @literal = {}
         @literal[:datatype] = attributes["datatype"] if attributes["datatype"]
         @literal[:language] = attributes["lang"] if attributes["lang"]
         @literal[:value] = ""
       end
     end


    def characters text
      if @current_predicate && !text.strip.empty?
        @literal ||={:value=>""}
        @literal[:value] << text.strip
      end
    end

    def end_element_namespace name, prefix = nil, uri = nil
      if @literal
        lit = RDFObject::Literal.new(@literal[:value], {:data_type=>@literal[:datatype], :language=>@literal[:language]})  
        #puts "#{@current_resource.inspect} :: #{@current_predicate} == #{lit}"      
        @current_resource.assert(@current_predicate, lit) if @current_predicate
        @literal = nil
        @current_predicate = nil
      else
        remove_layer("#{uri}#{name}")      
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
      @rdfxml = xslt.apply_to(doc)      
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