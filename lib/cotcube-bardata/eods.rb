# frozen_string_literal: true

module Cotcube
  # Missing top level documentation
  module Bardata
    def most_liquid_for(symbol: nil, id: nil, date: last_trade_date, config: init)
      id = get_id_set(symbol: symbol, id: id, config: config)[:id]
      provide_eods(id: id, dates: date, contracts_only: true).first
    end

    # the following method seems to be garbage. It is not used anywhere. It seems it's purpose
    # was to retrieve a list of quarters that have not been fetched recently (--> :age)
    def provide_most_liquids_by_eod(symbol: nil, id: nil, # rubocop:disable Metrics/ParameterLists
                                    config: init,
                                    date: last_trade_date,
                                    filter: :volume_part,
                                    age: 1.hour)
      sym  = get_id_set(symbol: symbol, id: id) if symbol || id
      # noinspection RubyScope
      eods = provide_eods(id: sym.nil? ? nil : sym[:id], config: config, dates: date, filter: filter)
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

    # provide a list of all eods for id/symbol or all symbols (default) for an
    #   array of dates (default: [last_trade_date])
    #
    # filter by :threshold*100% share on entire volume(default) or oi
    #
    # return full data or just the contract name (default)
    def provide_eods(symbol: nil, # rubocop:disable Metrics/ParameterLists
                     id: nil,
                     contract: nil,
                     config: init,
                     # should accept either a date or date_alike or date string OR a range of 2 dates alike
                     # if omitted returns the eods of last trading date
                     dates: last_trade_date,
                     # set threshold to 0 to disable filtering at all.
                     # otherwise only contracts with partial of >= threshold are returned
                     threshold: 0.05,
                     # filter can be set to volume_part and oi_part.
                     # determines, which property is used for filtering.
                     filter: :volume_part,
                     # set to false to return the complete row instead
                     # of just the contracts matching filter and threshold
                     contracts_only: true,
                     quiet: false)
      unless contract.nil? || (contract.is_a?(String) && [3, 5].include?(contract.size))
        raise ArgumentError, "Contract '#{contract}' is bogus, should be like 'M21' or 'ESM21'"
      end

      symbol = contract[0..1] if contract.to_s.size == 5
      sym = get_id_set(symbol: symbol, id: id, config: config) if symbol || id
      # if no id can be clarified from given arguments, return all matching contracts from all available symbols
      # raise ArgumentError, "Could not guess :id or :symbol from 'contract: #{contract}', please clarify." if id.nil?
      raise ArgumentError, ':filter must be in [:volume_part, :oi_part]' unless %i[volume_part oi_part].include? filter

      # noinspection RubyScope
      ids = sym.nil? ? symbols.map { |x| x[:id] } : [sym[:id]]
      dates = [dates] unless dates.is_a?(Array) || dates.nil?

      id_path_get = ->(local_id) { "#{config[:data_path]}/eods/#{local_id}" }

      process_date_for_id = lambda do |d, i|
        # l_sym        = symbols.select { |s| s[:id] == i }.first
        # l_symbol     = l_sym[:symbol]
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
