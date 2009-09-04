$KCODE = 'u'
require 'rubygems'
require 'strscan'
require 'iconv'
require 'jcode'
require 'uri'
require 'nokogiri'
require 'json'

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
    raise GeneratorError, "Caught #{e.class}: #{e}"
  end  
end
module RDFObject
class NTriplesParser
  attr_reader :ntriple, :subject, :predicate, :data_type, :language, :literal
  attr_accessor :object
  def initialize(line)
    @ntriple = line
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
      object = scanner.scan_until(/("\s?\.\n?$)|("@[A-z])|("\^\^)/)
      scanner.pos=(scanner.pos-2)
      object.sub!(/"..$/,'')
      uscan = UTF8Parser.new(object)
      object = uscan.parse_string
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
      assertions = resources.split(/\n/)
    elsif resources.is_a?(Array)
      assertions = resources
    elsif resources.respond_to?(:read)
      assertions = resources.readlines
    end
    assertions.each do | assertion |
      triple = self.new(assertion)
      resource = Resource.new(triple.subject)
      resource.assert(triple.predicate, triple.object)
      collection << resource
    end
    collection
  end
end

class XMLParser
  def self.parse(doc)
    unless doc.is_a?(Nokogiri::XML::Document)
      doc = Nokogiri::XML.parse(doc)
    end
    xmlns = {'rdf'=>'http://www.w3.org/1999/02/22-rdf-syntax-ns#'}
    collection = []
    puts doc.to_s
    doc.xpath('/rdf:RDF/rdf:Description', xmlns).each do | resource |
      r = Resource.new(resource['about'])
      resource.children.each do | child |
        next unless child.is_a?(Nokogiri::XML::Element)
        predicate = "#{child.namespace.href}#{child.name}"
        if child.inner_text && !child.inner_text.empty?
          options = {}
          options[:data_type] = child.attribute_with_ns('dataType',xmlns['rdf'])
          options[:language] = child.attribute_with_ns('lang','xml')
          obj = Literal.new(child.inner_text, options)
          r.assert(predicate, obj)
        elsif child['resource']
          r.assert(predicate, Resource.new(child['resource']))
        end
      end
      collection << r
    end
    collection
  end
end

class JSONParser
end

class Parser
  # Choose the best format parser from an admittedly small group of choices.
  def self.parse(rdf)
    begin
      # Check if the format is XML or RDFa
      doc = Nokogiri::XML.parse(rdf, nil, nil, Nokogiri::XML::ParseOptions::PEDANTIC)
      raise "Unable to parse XML/HTML document -- no namespace declared" unless doc.root.namespace
      if doc.root.namespace == "http://www.w3.org/1999/xhtml"
        collection = RDFAParser.parse(doc)
      else
        collection = XMLParser.parse(doc)
      end
    rescue Nokogiri::XML::SyntaxError
      begin
        json = JSON.parse(rdf)
        collection = JSONParser.parse(json)
      rescue JSON::ParserError
        collection = NTriplesParser.parse(rdf)
      end
    end
    collection  
  end
end
end