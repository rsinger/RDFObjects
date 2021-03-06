class Integer
  attr_accessor :language, :data_type
  def set_data_type(uri)
    @data_type = uri
  end
end
class Float
  attr_accessor :language, :data_type
  def set_data_type(uri)
    @data_type = uri
  end
end
class Date
  attr_accessor :language, :data_type
  def set_data_type(uri)
    @data_type = uri
  end
end
class String
  attr_accessor :language, :data_type
  def set_data_type(uri)
    @data_type = uri
  end
end
class TrueClass
  attr_accessor :language, :data_type
  def set_data_type(uri)
    @data_type = uri
  end
end
class FalseClass
  attr_accessor :language, :data_type
  def set_data_type(uri)
    @data_type = uri
  end
end



class RDFObject::Literal
  def self.new(value, options={})
    obj = case options[:data_type]
    when 'http://www.w3.org/2001/XMLSchema#dateTime' then DateTime.parse(value)
    when 'http://www.w3.org/2001/XMLSchema#date' then Date.parse(value)
    when 'http://www.w3.org/2001/XMLSchema#integer' then value.to_i
    when 'http://www.w3.org/2001/XMLSchema#float' then value.to_f      
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
    if obj.is_a?(Float)
      if obj.to_s == value
      elsif obj.to_s.sub(/\.0*/,'') == value
      else
        raise ArgumentError
      end
    elsif obj.is_a?(DateTime)
      raise ArgumentError if obj.to_s !~ /^#{Regexp.escape(value)}/
    else
      raise ArgumentError if obj.to_s != value      
    end
      
    obj.set_data_type(options[:data_type])
    obj.language = options[:language]
    obj
  end
end