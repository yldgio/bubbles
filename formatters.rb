module AS400
  module Formatters
    module Time
      def to_as400(options={})
        options.reverse_merge!(:case=>:default)
        format = options.delete(:format) || '%Y%m%d'
        formatted = if format
          self.strftime(format)
        else
          self.to_s(:as400)
        end
        formatted.to_as400(options)
      end
    end

    module String
      def iso_88591_normalized(options = {})
        return ''.mb_chars if self.nil?
        s_case = options[:case] || :default
        _formatted = case s_case
          when :upcase, :downcase
            self.mb_chars.try(s_case) || self.mb_chars
          else
            self.mb_chars
        end
        _formatted.normalize(:kc).unpack('U*').reject{|e| e > 255 }.pack('U*').mb_chars
      end
      def accents_rejecting_normalized
        return ''.mb_chars if self.nil?
        self.mb_chars.normalize(:kd).gsub(/[^\x00-\x7F]/n, '')
      end
      
      def iso_88591_incompatible?(val)
        return true if val.blank?
        val.unpack('U*').any?{|cr| cr > 255}
      end
         
      def to_as400(options={})
        options.reverse_merge!(:case=>:upcase)
        out = iso_88591_normalized(options)
        out.gsub!(/[\n\r]/u, '')
        return sprintf(options[:format], out) if options[:format]
        options.reverse_merge!({:length=>out.length, :align=>'l', :pad=>' '})
        len = options[:length]
        out = out.slice(0, len)
        return (options[:align] == 'l') ? out.ljust(len, options[:pad]) : out.rjust(len, options[:pad])
      end
    end
    module Numeric
      def to_as400(options ={})
        out = self.nil? ? '' : self.to_s
        options.reverse_merge!({:length=>out.length, :align=>'r', :pad=>'0', :case=>:default})
        return out.to_as400(options)
      end
    end
    module Float
      def to_as400(options={})
        out = self.nil? ? '' : self.to_s
        out = out.split('.')
        int = out[0] || 0
        dec = out[1] || 0
        len = options[:int] || int.length
        options.merge!({:length=>len, :align=>'r', :pad=>'0'})
        out = int.to_as400(options)
        len = options[:dec] || dec.length
        options.merge!({:length=>len, :align=>'l', :pad=>'0'})
        return out + dec.to_as400(options)
      end
    end
  end
end
class Time
  include AS400::Formatters::Time
end
class DateTime
  include AS400::Formatters::Time
end
class Date
  include AS400::Formatters::Time
end

class String
  include AS400::Formatters::String
end
class Numeric
  include AS400::Formatters::Numeric
end
class Float
  include AS400::Formatters::Float
end
class NilClass
  include AS400::Formatters::String
end
