require 'date'
require 'active_support/all'
require './formatters.rb' 

module Reader
  class Base
  end

  
end

module Writer
  class Base
  end
  
  class As400
  def test
        write(['123456','V','asdasd',Date.parse("2013-04-01"),'1234567890123','titolo lungo','autore',23,'EUR',12.12,10.3,45.2])  
  end

  def write(line)
    out =  ""    
    trace.each_with_index.map do |trace_line,i|
      raise "wrong type in '#{trace_line[:desc]}' expected #{trace_line[:class]} got #{line[i].class.name}" unless line[i].kind_of?(trace_line[:class])
      out += line[i].to_as400(trace_line[:as_400_format])    
    end
    out
  end
  

  def trace 
    As400::trace  
  end
  def self.trace 
      [
        {:from=>1,:to=>6, :desc => "Codice Distributore", :class=>String, :as_400_format=>{:length=>6, :align=>'l', :pad=>' '}},
        {:from=>7,:to=> 7, :desc => " Tipo doc B=Bolla F=Fattura", :class=>String,:as_400_format=>{:length=>1}},
        {:from=>8,:to=> 22, :desc => " Nr. documento", :class=>String,:as_400_format=>{:length=>15, :align=>'l', :pad=>' '}},
        {:from=>23,:to=> 30, :desc => "Data Documento AAAAMMGG", :class=>Date,:as_400_format=>{:length=>8,:format=>'%Y%m%d'}},
        {:from=>31,:to=> 43, :desc => " EAN", :class=>String, :as_400_format=>{:length=>13}},
        {:from=>44,:to=> 253, :desc => " Titolo",:class=>String, :as_400_format=>{:length=>210, :align=>'l', :pad=>' '}},
        {:from=>254,:to=> 288, :desc => " Autore",:class=>String, :as_400_format=>{:length=>35, :align=>'l', :pad=>' '}},
        {:from=>289,:to=> 292, :desc => " Copie",:class=>Integer, :as_400_format=>{:length=>4, :align=>'r', :pad=>'0'}},
        {:from=>293,:to=> 296, :desc => " Valuta", :class=>String,:as_400_format=>{:length=>4, :align=>'l', :pad=>' '}},
        {:from=>297,:to=> 305, :desc => " P.zzo lordo", :class=>Float,:as_400_format=>{:int=>7, :dec=>2}},
        {:from=>306,:to=> 309, :desc => " Sconto", :class=>Float,:as_400_format=>{:int=>2, :dec=>2}},
        {:from=>310,:to=> 318, :desc => " P.zzo netto", :class=>Float, :as_400_format=>{:int=>7, :dec=>2}}
      ]
    end
   def self.verify_trace
    pre = 0    
      trace.inject(true) do |result,field|
      result &= field[:to] - field[:from] + 1 == (field[:as_400_format][:length] || field[:as_400_format][:int] + field[:as_400_format][:dec])
      result &= (pre + 1 ) == field[:from]
      pre = field[:to]
      unless result
        warn field[:desc]
      end
      result

    end
   end
  end


end

warn Writer::As400::verify_trace
w =  Writer::As400.new
warn w.test


