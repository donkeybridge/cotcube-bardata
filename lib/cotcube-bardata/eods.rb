# frozen_string_literal: true

module Cotcube
  # Missing top level documentation
  module Bardata
    def get_id_from(symbol: nil, id: nil, config: init)
      unless symbol.nil?
        symbol_id = symbols.select { |s| s[:symbol] == symbol.to_s.upcase }.first[:id]
        if symbol_id.nil?
          raise ArgumentError,
                "Could not find match in #{config[:symbols_file]} for given symbol #{symbol}"
        end
        raise ArgumentError, "Mismatching symbol #{symbol} and given id #{id}" if (not id.nil?) && (symbol_id != id)

        id = symbol_id
      end
      raise ArgumentError, 'Need :id or :symbol.' if id.nil?
    end

    def most_liquid_for(symbol: nil, id: nil, date: last_trade_date, config: init)
      id = get_id_from(symbol: symbol, id: id, config: config)
      provide_eods(id: id, dates: date, contracts_only: true).first
    end

    def provide_most_liquids_by_eod(config: init, date: last_trade_date, filter: :volume_part, age: 1.hour)
      eods = provide_eods(config: config, dates: date, filter: filter)
      result = []
      eods.map do |eod|
        symbol   = eod[0..1]
        contract = eod[2..4]
        sym      = symbols.select { |s| s[:symbol] == symbol.to_s.upcase }.first
        quarter  = "#{config[:data_path]}/quarters/#{sym[:id]}/#{contract}.csv"
        if File.exist?(quarter)
          # puts "#{quarter}: #{ Time.now } - #{File.mtime(quarter)} > #{age} : #{Time.now - File.mtime(quarter) > age}"
          result << eod if Time.now - File.mtime(quarter) > age
        else
          result << eod
        end
      end
      result
    end

    def provide_eods(symbol: nil, # rubocop:disable Metrics/ParameterLists
                     id: nil,
                     contract: nil,
                     config: init,
                     # should accept either a date or date_alike or date string OR a range of 2 dates alike
                     # if omitted returns the eods of last trading date
                     dates: last_trade_date,
                     # set threshold to 0 to disable filtering at all.
                     # otherwise only contracts with partial of >= threshold are returned
                     threshold: 0.1,
                     # filter can be set to volume_part and oi_part.
                     # determines, which property is used for filtering.
                     filter: :volume_part,
                     # set to false to return the complete row instead
                     # of just the contracts matching filter and threshold
                     contracts_only: true,
                     quiet: false)
      unless contract.nil? || (contract.is_a?(String) && [
        3, 5
      ].include?(contract.size))
        raise ArgumentError,
              "Contract '#{contract}' is bogus, should be like 'M21' or 'ESM21'"
      end

      symbol = contract[0..1] if contract.to_s.size == 5
      id = get_id_from(symbol: symbol, id: id, config: config)
      # if no id can be clarified from given arguments, return all matching contracts from all available symbols
      # raise ArgumentError, "Could not guess :id or :symbol from 'contract: #{contract}', please clarify." if id.nil?
      raise ArgumentError, ':filter must be in [:volume_part, :oi_part]' unless %i[volume_part oi_part].include? filter

      ids = id.nil? ? symbols.map { |x| x[:id] } : [id]
      dates = [dates] unless dates.is_a?(Array) || dates.nil?

      id_path_get = ->(local_id) { "#{config[:data_path]}/eods/#{local_id}" }

      process_date_for_id = lambda do |d, i|
        sym        = symbols.select { |s| s[:id] == i }.first
        symbol     = sym[:symbol]
        id_path    = id_path_get.call(i)
        data_file  = "#{id_path}/#{d}.csv"
        raise "No data found for requested :id (#{id_path} does not exist)" unless Dir.exist?(id_path)

        unless File.exist?(data_file)
          unless quiet
            puts 'WARNING: No data found for requested id/symbol'\
            " #{id}/#{symbol} in #{id_path} for #{d}.".colorize(:light_yellow)
          end
          return []
        end
        data = CSV.read(data_file, headers: %i[contract date open high low close volume oi]).map do |row|
          row = row.to_h
          row.each do |k, _|
            row[k] = row[k].to_f if %i[open high low close].include? k
            row[k] = row[k].to_i if %i[volume oi].include? k
          end
          row
        end
        all_volume = data.map { |x| x[:volume] }.reduce(:+)
        all_oi     = data.map { |x| x[:oi]     }.reduce(:+)
        data.map do |x|
          x[:volume_part] = (x[:volume] / all_volume.to_f).round(4)
          x[:oi_part]     = (x[:oi] / all_oi.to_f).round(4)
        end
        data.select { |x| x[filter] >= threshold }.sort_by { |x| -x[filter] }.tap do |x|
          if contracts_only
            x.map! do |y|
              y[:contract]
            end
          end
        end
      end
      if dates
        dates.map do |date|
          ids.map { |local_id| process_date_for_id.call(date, local_id) }
        end.flatten
      else
        raise ArgumentError,
              'Sorry, support for unlimited dates is not implemented yet. Please send array of dates or single date'
      end
    end
  end
end
