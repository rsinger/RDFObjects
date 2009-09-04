module RDFObject::Modifiers
  attr_reader :data_type
  attr_accessor :language
  def set_data_type(uri)
    @data_type = uri
  end
end

class RDFObject::Literal
  def self.new(value, options={})
    obj = case options[:data_type]
    when 'http://www.w3.org/2001/XMLSchema#dateTime' then DateTime.parse(value)
    when 'http://www.w3.org/2001/XMLSchema#date' then Date.parse(value)
    when 'http://www.w3.org/2001/XMLSchema#int' then value.to_i
    when 'http://www.w3.org/2001/XMLSchema#string' then value.to_s
    when 'http://www.w3.org/2001/XMLSchema#boolean'
      if value.downcase == 'true' || value == '1'
        true
      else
        false
      end
    else
      value
    end
    obj.extend(RDFObject::Modifiers)
    obj.set_data_type(options[:data_type])
    obj.language = options[:language]
    obj
  end
end