# frozen_string_literal: true

module Cotcube
  module Bardata

    # just reads bardata/daily/<id>/<contract>.csv
    def provide_daily(symbol: nil, id: nil, contract:, config: init)
      contract = contract.to_s.upcase
      raise ArgumentError, "Contract '#{contract}' is bogus, should be like 'M21' or 'ESM21'" unless contract.is_a? String and [3,5].include? contract.size
      if contract.to_s.size == 5
        symbol   = contract[0..1]
        contract = contract[2..4] 
      end
      unless symbol.nil?
        symbol_id = symbols.select{|s| s[:symbol] == symbol.to_s.upcase}.first[:id]
        raise ArgumentError, "Could not find match in #{config[:symbols_file]} for given symbol #{symbol}" if symbol_id.nil?
        raise ArgumentError, "Mismatching symbol #{symbol} and given id #{id}" if not id.nil? and symbol_id != id
        id = symbol_id
      end
      raise ArgumentError, "Could not guess :id or :symbol from 'contract: #{contract}', please clarify." if id.nil?
      id_path   = "#{config[:data_path]}/daily/#{id}"
      data_file = "#{id_path}/#{contract}.csv"
      raise RuntimeError, "No data found for requested :id (#{id_path} does not exist)" unless Dir.exist?(id_path)
      raise RuntimeError, "No data found for requested contract #{symbol}:#{contract} in #{id_path}." unless File.exist?(data_file)
      data = CSV.read(data_file, headers: %i[contract date open high low close volume oi] ).map do |row|
        row = row.to_h
        row.each do |k, _| 
          row[k] = row[k].to_f if [:open, :high, :low, :close].include? k
          row[k] = row[k].to_i if [:volume, :oi].include? k
        end
        row
      end
      data
    end
   
    # reads all files in  bardata/daily/<id> and aggregates by date (what is a pre-stage of a continuous based on daily bars)
    def continuous(symbol: nil, id: nil, config: init, date: nil)
      unless symbol.nil?
        symbol_id = symbols.select{|s| s[:symbol] == symbol.to_s.upcase}.first[:id]
        raise ArgumentError, "Could not find match in #{config[:symbols_file]} for given symbol #{symbol}" if symbol_id.nil?
        raise ArgumentError, "Mismatching symbol #{symbol} and given id #{id}" if not id.nil? and symbol_id != id
        id = symbol_id
      end
      raise ArgumentError, "Could not guess :id or :symbol, please clarify." if id.nil?
      id_path    = "#{config[:data_path]}/daily/#{id}"
      available_contracts = Dir[id_path + '/*.csv'].map{|x| x.split('/').last.split('.').first}.sort_by{|x| x[-7]}.sort_by{|x| x[-6..-5]}
      data = [] 
      available_contracts.each do |c| 
        provide_daily(id: id, config: config, contract: c).each do |x| 
          data << x
        end
      end
      result = [] 
      data.sort_by{|x| x[:date]}.group_by{|x| x[:date]}.map{|k,v| 
        v.map{|x| x.delete(:date)}
        result << {
          date: k,
          volume: v.map{|x| x[:volume]}.reduce(:+),
          oi:     v.map{|x| x[:oi    ]}.reduce(:+)
        }
        result.last[:contracts] = v
      } 
      date.nil? ? result : result.select{|x| x[:date] == date}.first
    end

    # based on .continuous, this methods sorts the prepared dailies continuous for each date on either :volume (default) or :oi
    # with this job done, it can provide the period for which a past contract was the most liquid
    #
    def continuous_overview(symbol: nil, id: nil, config: init, selector: :volume, human: false, filter: nil)
      raise ArgumentError, "Selector must be either :volume or :oi" unless selector.is_a? Symbol and [:volume, :oi].include? selector
      
      unless symbol.nil?
        symbol_id = symbols.select{|s| s[:symbol] == symbol.to_s.upcase}.first[:id]
        raise ArgumentError, "Could not find match in #{config[:symbols_file]} for given symbol #{symbol}" if symbol_id.nil?
        raise ArgumentError, "Mismatching symbol #{symbol} and given id #{id}" if not id.nil? and symbol_id != id
        id = symbol_id
      end
      raise ArgumentError, "Could not guess :id or :symbol, please clarify." if id.nil?
      data = continuous(id: id, config: config).map{|x| 
        {
          date:   x[:date],
          volume: x[:contracts].sort_by{|x| - x[:volume]}[0..4].compact.select{|x| not x[:volume].zero?},
          oi:     x[:contracts].sort_by{|x| - x[:oi]}[0..4].compact.select{|x| not x[:oi].zero?}
        }
      }.select{|x| not x[selector].empty? }
      result = data.group_by{|x| x[selector].first[:contract]}
      if human
        result.each {|k,v| puts "#{k}\t#{v.first[:date]}\t#{v.last[:date]}" if filter.nil? or v.first[selector].first[:contract][2..4]=~ /#{filter}/ }
      end
      result
    end
  end
end
