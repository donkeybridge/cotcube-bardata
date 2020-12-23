# frozen_string_literal: true

module Cotcube
  module Bardata

    def most_liquid_for(symbol: nil, id: nil, date: last_trade_date, config: init, quiet: false)
      unless symbol.nil?
        symbol_id = symbols.select{|s| s[:symbol] == symbol.to_s.upcase}.first[:id]
        raise ArgumentError, "Could not find match in #{config[:symbols_file]} for given symbol #{symbol}" if symbol_id.nil?
        raise ArgumentError, "Mismatching symbol #{symbol} and given id #{id}" if not id.nil? and symbol_id != id
        id = symbol_id
      end
      raise ArgumentError, "Need :id or :symbol." if id.nil?
      provide_eods(id: id, dates: date, contracts_only: true).first
    end

    def provide_most_liquids_by_eod(config: init, date: last_trade_date, filter: :volume_part, age: 1.hour)
      eods = provide_eods(config: config, dates: date, filter: filter)
      result = [] 
      eods.map do |eod|
        symbol   = eod[0..1]
        contract = eod[2..4] 
        sym      = symbols.select{|s| s[:symbol] == symbol.to_s.upcase}.first
        quarter  = "#{config[:data_path]}/quarters/#{sym[:id]}/#{contract}.csv"
        if File.exist?(quarter)
          puts "#{quarter}: #{ Time.now } - #{File.mtime(quarter)} > #{age} : #{Time.now - File.mtime(quarter) > age}"
          result << eod if Time.now - File.mtime(quarter) > age
        else
          result << eod
        end
      end
      result
    end

    def provide_eods(symbol: nil, 
                     id: nil, 
                     contract: nil, 
                     config: init, 
                     dates: last_trade_date,   # should accept either a date or datelike or date string OR a range of 2 datelike
                     # if omitted returns the eods of last trading date
                     threshold: 0.1,           # set threshold to 0 to disable filtering at all. otherwise only contracts with partial of >= threshold are returned
                     filter: :volume_part,     # filter can be set to volume_part and oi_part. determines, which property is used for filtering.
                     contracts_only: true      # set to false to return the complete row instead of just the contracts matching filter and threshold
                    )
      raise ArgumentError, "Contract '#{contract}' is bogus, should be like 'M21' or 'ESM21'" unless contract.nil? or (contract.is_a? String and [3,5].include? contract.size)
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
      # if no id can be clarified from given arguments, return all matching contracts from all available symbols
      # raise ArgumentError, "Could not guess :id or :symbol from 'contract: #{contract}', please clarify." if id.nil?
      raise ArgumentError, ":filter must be in [:volume_part, :oi_part]" unless [:volume_part, :oi_part].include? filter

      ids = id.nil? ? symbols.map{|x| x[:id]} : [ id ] 
      dates = [ dates ] unless dates.is_a? Array or dates.nil?

      id_path_get  = lambda {|_id| "#{config[:data_path]}/eods/#{_id}" } 

      process_date_for_id = lambda do |d,i| 
        sym        = symbols.select{|s| s[:id] == i}.first
        symbol     = sym[:symbol]
        id_path    = id_path_get.call(i)
        data_file  = "#{id_path}/#{d}.csv"
        raise RuntimeError, "No data found for requested :id (#{id_path} does not exist)" unless Dir.exist?(id_path)
        unless File.exist?(data_file)
          puts "WARNING: No data found for requested id/symbol #{id}/#{symbol} in #{id_path}.".light_yellow unless quiet
          return []
        end
        data = CSV.read(data_file, headers: %i[contract date open high low close volume oi] ).map do |row|
          row = row.to_h
          row.each do |k, _| 
            row[k] = row[k].to_f if [:open, :high, :low, :close].include? k
            row[k] = row[k].to_i if [:volume, :oi].include? k
          end
          row
        end
        all_volume = data.map{|x| x[:volume] }.reduce(:+)
        all_oi     = data.map{|x| x[:oi]     }.reduce(:+)
        data.map{|x| x[:volume_part] = (x[:volume] / all_volume.to_f).round(4); x[:oi_part] = (x[:oi] / all_oi.to_f).round(4) }
        data.select{|x| x[filter] >= threshold}.sort_by{|x| -x[filter]}.tap{|x| x.map!{|y| y[:contract]} if contracts_only}
      end
      if dates
        dates.map do |date| 
          ids.map{|id| process_date_for_id.call(date, id) }
        end.flatten
      else
        raise ArgumentError, "Sorry, support for unlimited dates is not implemented yet. Please send array of dates or single date"
      end
    end

  end
end
