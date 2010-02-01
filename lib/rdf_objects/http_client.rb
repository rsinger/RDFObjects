require 'net/http'
require 'uri'
require 'cgi'
module RDFObject
  class HTTPClient
    @@proxies = {}
    def self.fetch(uri)
      @@proxies.each do | key, proxy |
        if uri.match(key)
          uri = proxy.proxy_uri(uri, ['json', 'ntriples','rdf'])
        end
      end
      u = URI.parse(uri)
      request = Net::HTTP::Get.new(u.request_uri)
      request['accept'] = nil
      request['accept'] = ['application/rdf+xml']
      response = Net::HTTP.start(u.host, u.port) do | http |
        http.request(request)
      end
      if response.code == "200"
        return {:uri=>u.to_s, :content=>response.body}
      elsif response.code =~ /^30[0-9]$/
        new_uri = URI.parse(response.header['location'])
        unless new_uri.host
          new_uri = u+new_uri
        end
        return fetch(new_uri.to_s)
      else
        raise response.message
      end
    end
  
    def self.register_proxy(uri,proxy)
      @@proxies[uri] = proxy
    end
  end


  class TalisPlatformProxy
    attr_reader :store
    @@formats = ['rdf','ntriples','turtle','json']
    def initialize(store_name)
      @store = store_name
    end
  
    def proxy_uri(uri, format=['rdf'])
      idx = 0
      best_format = nil
      while !best_format
        @@formats.each do | fmt |
          if format[idx] == fmt
            best_format = fmt
            break
          end
        end
        idx += 1
      end
      raise "No compatible response format!" if !best_format
      "http://api.talis.com/stores/#{@store}/meta?about=#{CGI.escape(uri)}&output=#{best_format}"
    end
  end
end