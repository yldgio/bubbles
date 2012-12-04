require 'date'
require 'active_support/all'
require './formatters.rb' 
require 'pathname'
require 'parsifal'


module Reader
  class Base
    attr_accessor :lines

    def process(file)
      @lines = parser.parse(file).to_a
    end

    def documents
      return @documents unless @documents.blank?
      docs = @lines.group_by{|l| l[:document_number]}
      @documents = []
      docs.each do |number,lines|
        doc = {}
        doc[:header] =lines.first.slice(*header_fields).merge(added_header_fields)
        doc[:lines] = lines.map{|l| l.delete_if{|k,v| header_fields.include?(k) || unused_line_fields.include?(k) }}.map{|l| validate_and_fill(l)}
        @documents << doc
      end
      @documents
    end
    def validate_and_fill(l)
      l.merge(added_line_fields)
    end

  end
  class Messaggerie < Base
    def added_line_fields
      {:currency=>'EUR',:author=>"",:title=>""}
    end

    def validate_and_fill(l)
      l[:item_net_amount]  = l[:item_net_amount].blank? ? (l[:line_total_discounted_net_amount] / l[:quantity]).round(2)  : l[:item_net_amount]
      #TODO: verify discount logic
      l[:item_percentage_discount]  = l[:item_percentage_discount].blank? ? (l[:discount_1] + l[:discount_2] + l[:discount_2] + l[:discount_2] ).round(2)  : l[:item_percentage_discount]
      super
    end

    field :item_percentage_discount, :at => [108, 4], :as=>:float, :translate => lambda{|d| Integer(d)/100.0 }
    field :item_net_amount, :at => [116, 9], :as=>:float, :translate => lambda{|d| Integer(d)/100.0 }

  end

  class PDE < Base
    def self.test_document
      {:header=> {:document_number=>35638, :document_date=>Date.parse("Mon, 03 Dec 2012"), :deposit=>13, :client_code=>210245, :as_400_code=>"PDEcod", :processed_at=>Time.now, :document_type=>"B"},
       :lines=>[
                 {:ean=>"9788885385122", :title=>"MEDITAZIONI ZODIACAL", :quantity=>1, :item_cover_price=>13.0, :item_percentage_discount=>45.0, :item_vat=>0, :item_net_amount=>7.15},
                 {:ean=>"9788889891261", :title=>"NEURONARRATOLOGIA", :quantity=>1, :item_cover_price=>21.0, :item_percentage_discount=>32.0, :item_vat=>0, :item_net_amount=>14.28},
                 {:ean=>"9788895688510", :title=>"QUESITI E SOLUZIONI", :quantity=>1, :item_cover_price=>11.5, :item_percentage_discount=>0.0, :item_vat=>0, :item_net_amount=>11.5},
                 {:ean=>"9788827200834", :title=>"TAO YOGA AMORE", :quantity=>1, :item_cover_price=>15.95, :item_percentage_discount=>3.0, :item_vat=>0, :item_net_amount=>15.47},
                 {:ean=>"9788804621867", :title=>"INVECCHIERO MA CON C", :quantity=>1, :item_cover_price=>18.0, :item_percentage_discount=>0.0, :item_vat=>0, :item_net_amount=>18.0},
                 {:ean=>"9788817057318", :title=>"MUOIO DALLA VOGLIA D", :quantity=>1, :item_cover_price=>13.0, :item_percentage_discount=>0.0, :item_vat=>0, :item_net_amount=>13.0}
              ]
      }
    end

    def validate_and_fill(l)
      l[:item_net_amount]  = l[:item_net_amount].blank? ?   (l[:item_cover_price]*(1-l[:item_percentage_discount]/100.0)).round(2) : l[:item_net_amount]
      l[:item_cover_price] = l[:item_cover_price].blank? ?  (l[:item_net_amount] /(1-l[:item_percentage_discount]/100.0)).round(2)  : l[:item_cover_price]
      super
    end

    def header_fields
      [:document_number,:document_date,:deposit,:client_code]
    end

    def added_header_fields
      {:as_400_code=>as_400_code,:processed_at=>Time::now(),:document_type=>'B'}
    end

    def unused_line_fields
      [:line_number, :publisher, :payment_characteristics,:free_quantity]
    end

    def added_line_fields
	    {:currency=>'EUR',:author=>""}
    end

    def parser
      @p ||= DocumentParser::PDE.new() 
    end

    def as_400_code
      '123456'
    end


  end


end



module DocumentParser
  class Base < Parsifal::Parser::Fixed
    include Parsifal::Parser::Translate
    include Parsifal::Parser::Force
    self.encoding = 'utf-8'

  end
  class Messaggerie < Base
    field :document_type, :at=>[1,2],:translate => lambda{|s| s == 'FT' ? 'F' : '' } #Tipo documento	1	2	A	FT ;NC
    field :invoice_date, :at => [3, 8], :translate => lambda{|d| Date.parse(d,'%Y%m%d')}  #Data fattura	3	8	A
    field :invoice_number, :at => [11, 8],  :translate => lambda{|i| Float(i).to_i} #Numero fattura	11	8	N	 	Riempimento a sx zeri non significativi.
    field :document_date, :at => [19, 8], :translate => lambda{|d| Date.parse(d,'%Y%m%d')}  #Data DDT	19	8	A	 	AAAAMMGG
    field :document_number, :at => [27, 8], :translate => lambda{|i| Float(i).to_i.to_s} #Numero DDT	27	8	N	 	Riempimento a sx zeri non significativi
    field :ref_order_number, :at => [35, 8] #Numero riferimento ordine CLI.	35	8	A
    field :ref_order_date, :at => [27, 8], :translate => lambda{|d| Date.parse(d,'%Y%m%d')}  #Data riferimento ordine CLI.	43	8	A		AAAAMMGG
    field :client_code, :at => [51, 3], :translate => lambda{|i| Float(i).to_i}  #Codice negozio	51	3	N	 	Riempimento a sx zeri non significativi
    field :vat_no, :at => [54, 16] #Codice fiscale o Partita IVA	54	16	A	 	Partita Iva negozio

    field :isbn, :at => [70, 10]  #Codice ISBN	70	10	A

    field :quantity, :at => [80, 5], :translate => lambda{|i| Float(i).to_i} #Copie fatturate	80	5	N	 	Riempimento a sx zeri non significativi
    field :free_quantity, :at => [85, 4], :translate => lambda{|i| Float(i).to_i} #Copie gratuite	85	4	N	 	Riempimento a sx zeri non significativi

    field :item_cover_price, :at => [89, 7], :as=>:float, :translate => lambda{|d| Float(d).to_i/100.0 } #Prezzo lordo unitario	89	7	N(5+2)	 	Riempimento a sx zeri non significativi
    field :discount_1, :at => [96, 4], :translate => lambda{|i| Float(i).to_i/100.0 } #Sconto 1	96	4	N(2+2)	 	Riempimento a sx zeri non significativi
    field :discount_2, :at => [100, 4], :translate => lambda{|i| Float(i).to_i/100.0 }#Sconto 2	100	4	N(2+2)	 	Riempimento a sx zeri non significativi
    field :discount_3, :at => [104, 4], :translate => lambda{|i| Float(i).to_i/100.0 }#Sconto 3	104	4	N(2+2)	 	Riempimento a sx zeri non significativi
    field :discount_4, :at => [108, 4], :translate => lambda{|i| Float(i).to_i/100.0 }#Sconto 4	108	4	N(2+2)	 	Riempimento a sx zeri non significativi

    field :item_vat_code, :at => [112, 2]  #Codice I.V.A	112	2	A	 	Tabella IVA standard MELI
    field :item_vat, :at => [114, 4], :translate => lambda{|i| Float(i).to_i/100.0} #Aliquota I.V.A.	114	4	N(2+2)	 	Riempimento a sx zeri non significativi
    field :item_vat_riaccredito, :at => [118, 5], :translate => lambda{|i| Float(i).to_i/100.0} #Percentuale riaccredito IVA	118	5	N(3+2)	 	Quota % IVA carico Editore

    field :item_total_cover_price, :at => [123, 12], :as=>:float, :translate => lambda{|d| Float(d).to_i/100.0 } #Prezzo lordo riga	123	12	N(10+2)	 	Prodotto lordo per numero Copie




    field :line_total_discounted_amount, :at => [135, 12], :as=>:float, :translate => lambda{|d| Float(d).to_i/100.0 } #Prezzo Netto Sconti riga	135	12	N(10+2)	 	Prezzo lordoriga al netto degli sconti a al lordo dell'IVA.
    field :line_total_discounted_net_amount, :at => [147, 12], :as=>:float, :translate => lambda{|d| Float(d).to_i/100.0 } #Prezzo netto Sconti/iva Riga	147	12	N(10+2)	 	Prezzo lordo netto sconti IVA

    field :line_total_discount_amount, :at => [159, 12], :as=>:float, :translate => lambda{|d| Float(d).to_i/100.0 }#Importo Sconti Riga	159	12	N(10+2)	 	Totali sconti applicati
    field :line_total_vat_amount, :at => [171, 12], :as=>:float, :translate => lambda{|d| Float(d).to_i/100.0 } #Importo IVA riga	171	12	N(10+2)	 	Totale IVA sulla riga.
    field :return_reason, :at => [183, 1]#Motivo resa	183	1	A	 	A=aut;D=Rese Dep;G=gua;R=Res;S=Er
    field :campaign_ref, :at => [184, 30]#Riferimento campagna	184	30	A
    field :handling_fee, :at => [214,7], :as=>:float, :translate => lambda{|d| Float(d).to_i/100.0 } #Addebito Spese Imballo	214	7	N(5+2)	 	Riempimento a sx zeri non significativi
    field :delivery_charge, :at => [221, 10], :as=>:float, :translate => lambda{|d| Float(d).to_i/100.0 } #Addebito delivery charge	221	10	N(8+2)	 	Riempimento a sx zeri non significativi
    field :bar_code, :at => [231, 13] #Barcode	231	13	A	 	Riempimento a xs zeri
    field :ean, :at => [244, 13] #Codice ISBN new	244	13	A


  end
  class Rizzoli < Base
    field :document_type, :at=>[1,2],:translate => lambda{|s| s == 'FT' ? 'F' : '' }#TIPO DOCUMENTO	1	2	A	S	FT=Fattura, NC=Nota Credito

    field :deposit, :at => [1, 2], :translate => lambda{|i| Float(i).to_i}
    field :client_code, :at => [4, 7], :translate => lambda{|i| Float(i).to_i}
    field :document_date, :at => [12, 8], :translate => lambda{|d| Date.parse(d,'%Y%m%d')}
    field :document_number, :at => [21, 7], :translate => lambda{|i| Float(i).to_i.to_s}
    field :line_number, :at => [29, 5], :translate => lambda{|i| Float(i).to_i} #lost
    field :publisher, :at => [35, 5] #lost
    field :ean, :at => [51, 13]
    field :title, :at => [65, 20], :translate => lambda{|i| i.rstrip}
    field :quantity, :at => [86, 5], :translate => lambda{|i| Float(i).to_i}
    field :free_quantity, :at => [92, 5], :translate => lambda{|i| Float(i).to_i}
    field :item_cover_price, :at => [98, 9], :as=>:float, :translate => lambda{|d| Integer(d)/100.0 }
    field :item_percentage_discount, :at => [108, 4], :as=>:float, :translate => lambda{|d| Integer(d)/100.0 }
    field :item_vat, :at => [113, 2], :translate => lambda{|i| Float(i).to_i}
    field :item_net_amount, :at => [116, 9], :as=>:float, :translate => lambda{|d| Integer(d)/100.0 || 0.0 }
    # 2 decimali. Il valore si riferisce al totale riga netto defiscalizzato
    field :payment_characteristics, :at => [126, 80], :as=>:string

    #NOME CAMPO	P.I.	Lung.	TIPO	OBBLIGATORIO	NOTE

    #DATA FATTURA	3	8	A	S	AAAAMMGG
    #NUMERO FATTURA	11	10	N	S	Riempimento a sx zeri non significativi
    #DATA DDT 	21	8	A	S	AAAAMMGG
    #NUMERO DDT	29	10	N	S	Riempimento a sx zeri non significativi
    #NUMERO RIFERIMENTO ORDINE CLI.	39	9	A	N
    #DATA RIFERIMENTO ORDINE CLI.	48	8	A	N	AAAAMMGG
    #CODICE NEGOZIO	56	3	N	S	Riempimento a sx zeri non significativi
    #CODICE FISCALE O PARTITA IVA 	59	16	A	N	Partita Iva negozio
    #CODICE ISBN 	75	10	A	N
    #COPIE FATTURATE	85	5	N	S	Riempimento a sx zeri non significativi
    #COPIE GRATUITE	90	4	N	S	Riempimento a sx zeri non significativi
    #PREZZO LORDO UNITARIO	94	7	N(5+2)	S	Riempimento a sx zeri non significativi
    #SCONTO  1	101	4	N (2+2)	S	Riempimento a sx zeri non significativi
    #SCONTO  2	105	4	N (2+2)	N	Riempimento a sx zeri non significativi
    #SCONTO  3	109	4	N (2+2)	N	Riempimento a sx zeri non significativi
    #SCONTO  4	113	4	N (2+2)	N	Riempimento a sx zeri non significativi
    #CODICE I.V.A.	117	2	A	S	04 = aliquota 4%, 10 = aliquota 10%, 20 = aliquota 20%, 92 = esente art.74, 80 = Non soggetto Art.26 DPR 633/72
    #ALIQUOTA I.V.A.	119	4	N (2+2)	S	Riempimento a sx zeri non significativi
    #PERCENTUALE RIACCREDITO IVA	123	5	N (3+2)	S	Si tratta della quota % dell'IVA a carico dell'editore (es. 100,00 --> interamente a carico dell'editore). Riempimento a sx zeri non significativi
    #PREZZO LORDO RIGA	128	12	N (10+2)	S	Si tratta del prodotto del lordo unitario per il numero di copie fatturate.Riempimento a sx zeri non significativi
    #PREZZO NETTO SCONTI RIGA	140	12	N (10+2)	S	Si tratta del prezzo lordo riga al netto degli sconti e al lordo dell'IVA. Riempimento a sx zeri non significativi
    #PREZZO NETTO SCONTI/IVA RIGA	152	12	N (10+2)	S	Si tratta del prezzo lordo riga al netto degli sconti e dell'IVA. Riempimento a sx zeri non significativi
    #IMPORTO SCONTI RIGA	164	12	N (10+2)	S	Si tratta del totale degli sconti applicati. Riempimento a sx zeri non significativi
    #IMPORTO IVA RIGA	176	12	N (10+2)	S	Si tratta del totale dell'IVA sulla riga. Riempimento a sx zeri non significativi
    #MOTIVO RESA	188	1	A	N	A=Autorizzata, D=Rese da Depositi, G=Guasti, R=Respinto, S=Errato invio
    #RIFERIMENTO CAMPAGNA	189	30	A	N
    #ADDEBITO SPESE IMBALLO *	219	7	N(5+2)	S	Riempimento a sx zeri non significativi
    #ADDEBITO DELIVERY CHARGE	226	10	N(8+2)	S	Riempimento a sx zeri non significativi
    #BARCODE	236	13	A	S	Riempimento a sx zeri
    #CODICE ISBN NEW 	249	13	A	S
    #IMPORTO TOTALE IVA FATTURA**	262	12	N (10+2)	S
    #IMPORTO TOTALE SCONTO FATTURA**	274	12	N (10+2)	S
    #IMPORTO TOTALE LORDO FATTURA**	286	12	N (10+2)	S
    #IMPORTO TOTALE NETTO SCONTI FATTURA**	298	12	N (10+2)	S
    #IMPORTO TOTALE NETTO SCONTI/IVA FATTURA**	310	12	N (10+2)	S
    #CONDIZIONE DI PAGAMENTO FATTURA**	322	4	A	S
    #DATA SCADENZA**	326	8	A	N	Data scadenza fattura  AAAAMMGG
    #DESCRIZIONE PAGAMENTO	334	50	A	S
    #DISTINTA BASE	384	1	A	N	Valorizzato a "X" se ISBN è un cofanetto
    #NOTE	385	40	A		NOTE
    #CODICE FORNITORE	425	10	A	S
    #DESCRIZIONE PRODOTTO	435	80	A	N
    #PROGRESSIVO RIGA	515	7	A	S
    #FINE FILE	522	1	A	S	Valore fisso "."
    #Lunghezza record		522
    #
    #
    #* ADDEBITO SPESE IMBALLO:	Volendo, è possibile trattare tali valori come articoli di vendita totalizzati per fattura. Nel caso si decida di percorrere questa strada,
    #	alternativa al calcolo delle spese di imballo per singolo barcode, occorre utilizzare i seguenti barcode fissi:
    #	- SPIMP92: valore addebito spese imballo soggette a IVA esente/fuori campo
    #	- SPIMP04: valore addebito spese imballo soggette ad aliquota IVA 4 %
    #	- SPIMP10: valore addebito spese imballo soggette ad aliquota IVA 10 %
    #	- SPIMP20: valore addebito spese imballo soggette ad aliquota IVA 20 %
    #	Le spese di cui sopra devono essere indicate per fattura (non per DDT)
    #
    #I campi con **, essendo totali di fattura, saranno ripetuti sulle righe appartenenti alla fattura.

  end
  class PDE < Base
    self.header_size = 1
    field :deposit, :at => [1, 2], :translate => lambda{|i| Float(i).to_i}
    field :client_code, :at => [4, 7], :translate => lambda{|i| Float(i).to_i}
    field :document_date, :at => [12, 8], :translate => lambda{|d| Date.parse(d,'%Y%m%d')}
    field :document_number, :at => [21, 7], :translate => lambda{|i| Float(i).to_i.to_s}
    field :line_number, :at => [29, 5], :translate => lambda{|i| Float(i).to_i} #lost
    field :publisher, :at => [35, 5] #lost
    field :ean, :at => [51, 13]
    field :title, :at => [65, 20], :translate => lambda{|i| i.rstrip}
    field :quantity, :at => [86, 5], :translate => lambda{|i| Float(i).to_i}
    field :free_quantity, :at => [92, 5], :translate => lambda{|i| Float(i).to_i}
    field :item_cover_price, :at => [98, 9], :as=>:float, :translate => lambda{|d| Integer(d)/100.0 }
    field :item_percentage_discount, :at => [108, 4], :as=>:float, :translate => lambda{|d| Integer(d)/100.0 }
    field :item_vat, :at => [113, 2], :translate => lambda{|i| Float(i).to_i}
    field :item_net_amount, :at => [116, 9], :as=>:float, :translate => lambda{|d| Integer(d)/100.0 || 0.0 }
    # 2 decimali. Il valore si riferisce al totale riga netto defiscalizzato
    field :payment_characteristics, :at => [126, 80], :as=>:string
  end

end

module Writer
  class Base

    def write(document)
      fname = File.join('./output',filename_from(document))
      File.open(fname,"w+") do |f|
         f.write(compile(document))
      end
    end



    def compile(document)
      out =  ""
      out += write_line(document[:header],header_trace)
      document[:lines].each do |line|
        out += write_line(line,item_trace)
      end
      out
    end

    protected
    def filename_from(document)
      h = document[:header]
      "DDT_#{h[:as_400_code]}_#{h[:document_number]}_#{Time.now.strftime('%Y%m%d%H%M')}.txt"
    end

    def write_line(line,trace)
      out = ""
      trace.each.map do |field|
        raise "wrong type in '#{field[:desc]}' expected #{field[:class]} got #{line[field[:name]].class.name}" unless line[field[:name]].kind_of?(field[:class])
        out += line[field[:name]].to_as400(field[:as_400_format])
      end
      out + "\n"
    end

  end
  class As400 < Base




    def header_trace
        [
            {:name=> :as_400_code,:from=>1,:to=>6, :desc => "Codice Distributore", :class=>String, :as_400_format=>{:length=>6, :align=>'l', :pad=>' '}},
            {:name=> :document_type,:from=>7,:to=> 7, :desc => " Tipo doc B=Bolla F=Fattura", :class=>String,:as_400_format=>{:length=>1}},
            {:name=> :document_number,:from=>8,:to=> 22, :desc => " Nr. documento", :class=>String,:as_400_format=>{:length=>15, :align=>'l', :pad=>' '}},
            {:name=> :document_date,:from=>23,:to=> 30, :desc => "Data Documento AAAAMMGG", :class=>Date,:as_400_format=>{:length=>8,:format=>'%Y%m%d'}}
        ]
    end

    def item_trace
        [
          {:name=> :ean , :from=>1,:to=> 13, :desc => " EAN", :class=>String, :as_400_format=>{:length=>13}},
          {:name=> :title, :from=>14,:to=> 223, :desc => " Titolo",:class=>String, :as_400_format=>{:length=>210, :align=>'l', :pad=>' '}},
          {:name=> :author, :from=>224,:to=> 258, :desc => " Autore",:class=>String, :as_400_format=>{:length=>35, :align=>'l', :pad=>' '}},
          {:name=> :quantity, :from=>259,:to=> 262, :desc => " Copie",:class=>Integer, :as_400_format=>{:length=>4, :align=>'r', :pad=>'0'}},
          {:name=> :currency, :from=>263,:to=> 265, :desc => " Valuta ISO code ", :class=>String,:as_400_format=>{:length=>3, :align=>'l', :pad=>' '}},
          {:name=> :item_cover_price, :from=>266,:to=> 274, :desc => " P.zzo al lordo dello sconto senza iva (di copertina)", :class=>Float,:as_400_format=>{:int=>7, :dec=>2}},
          {:name=> :item_percentage_discount, :from=>275,:to=> 278, :desc => " Sconto ", :class=>Float,:as_400_format=>{:int=>2, :dec=>2}},
          {:name=> :item_net_amount, :from=>279,:to=> 287, :desc => " P.zzo al netto dello sconto senza iva", :class=>Float, :as_400_format=>{:int=>7, :dec=>2}},
          {:name=> :item_vat, :from=>288,:to=> 289, :desc => " percentuale IVA 0 per libri ", :class=>Integer, :as_400_format=>{:length=>2, :align=>'r', :pad=>'0'}}
        ]
    end

    def self.verify(trace)
      pre = 0
      trace.inject(true) do |result,field|
      result &= field[:to] - field[:from] + 1 == (field[:as_400_format][:length] || field[:as_400_format][:int] + field[:as_400_format][:dec])
      result &= (pre + 1 ) == field[:from]

      unless result
        warn field[:desc]  + " pre: #{ (pre + 1 ) } =? #{ field[:from]}, or #{field[:to] - field[:from] + 1} =? #{ (field[:as_400_format][:length] || field[:as_400_format][:int] + field[:as_400_format][:dec])}"
      end
      pre = field[:to]
      result

      end
     end
  end
end


#warn Writer::As400::verify(Writer::As400::header_trace)
#warn Writer::As400::verify(Writer::As400::item_trace)


r = Reader::PDE.new()
r.process(File.join('./input','PDE.txt'))
writer = Writer::As400.new()
warn "\n\n"
r.documents.each do |d|
  writer.write(d)
end



#r.lines.each do |l|
#  warn l.inspect  
#end



#w =  Writer::As400.new
#warn w.test


