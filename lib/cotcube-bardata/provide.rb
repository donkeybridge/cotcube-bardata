# frozen_string_literal: true

module Cotcube
  module Bardata

    def provide(contract:,
                # Can be like ("2020-12-01 12:00"..."2020-12-14 11:00")
                range: nil,              
                symbol: nil, id: nil,
                config: init,
                # supported types are :quarters, :hours, :days, :rth, :dailies, :weeks, :months
                type: :days,             
                # supported fills are :raw, :_24x7_, :full and :rth (and custom named, if provided as file)
                set: :full,        
                # TODO: for future compatibility and suggestion: planning to include a function to update
                #       with live data from broker
                force_recent: false)

      sym = get_id_set(symbol: symbol, id: id, contract: contract, config: config)

      case type
      when :quarters, :hours, :quarter, :hour
        base = provide_quarters(contract: contract, symbol: symbol, id: id, config: config)
        base = extended_select_for_range(range: range, base: base) if range
        requested_set = trading_hours(symbol: sym[:symbol], set: set)

        base = base.select_within(ranges: requested_set, attr: :datetime) {|x| x.to_datetime.to_sssm }
        return base if [:quarters, :quarter].include? type

        base = Cotcube::Helpers.reduce(bars: base, to: :hours){|c,b|  
          c[:day] == b[:day] and c[:datetime].hour == b[:datetime].hour 
        }

      when :days, :weeks, :months
        base = provide_cached contract: contract, symbol: symbol, id: id, config: config, set: set, force_recent: force_recent
        base = extended_select_for_range(range: range, base: base) if range
        return base if [:day, :days].include? type
        # TODO: Missing implemetation to reduce cached days to weeks or months
        raise "Missing implementation to reduce cached days to weeks or months"
      when :dailies, :daily
        base = provide_daily contract: contract, symbol: symbol, id: id, config: config
        base = extended_select_for_range(range: range, base: base) if range
        return base 
      else
        raise ArgumentError, "Unsupported or unknown type '#{type}' in Bardata.provide"
      end
    end
  end
end
