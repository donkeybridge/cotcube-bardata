# frozen_string_literal: true

module Cotcube
  # Missing top level documentation comment
  module Bardata
    # small helper to select a specific full trading day from quarters (or reduced)
    #   this special handling is needed, as full trading days start '5pm CT yesterday'
    def select_specific_date(date:, base:)
      base.select do |d|
        d[:day] == date.day and date.year == d[:datetime].year and (
        if date.day > 1
          date.month == d[:datetime].month
        else
          ((date.month == d[:datetime].month     and d[:datetime].day == 1) or
           (date.month == d[:datetime].month + 1 and d[:datetime].day > 25))
        end
      )
      end
    end

    # diminishes a given base of bars to fit into a given range (DO NOT CONFUSE with trading_hours)
    # note that the last bar is simply required to _start_ within the given range, not to end withing
    def extended_select_for_range(base:,
                                  range: ('1900-01-01'...'2100-01-01'),
                                  timezone: Time.find_zone('America/Chicago'),
                                  quiet: false)

      starting = range.begin
      starting = timezone.parse(starting) if starting.is_a? String
      ending   = range.end
      ending   = timezone.parse(ending) if ending.is_a? String
      puts "#{starting}\t#{ending}" unless quiet
      if starting.hour.zero? && starting.min.zero? && ending.hour.zero? && ending.min.zero?
        unless quiet
          puts 'WARNING: When sending midnight, full trading day'\
            ' is assumed (starting 5 pm CT yesterday, ending 4 pm CT today)'.colorize(:light_yellow)
        end
        result = select_specific_date(date: starting, base: base)
        result += base.select { |d| d[:datetime] >= starting and d[:datetime] < ending.to_date }
        result += select_specific_date(date: ending, base: base)
        result.uniq!
      else
        result = base.select { |x| x[:datetime] >= starting and x[:datetime] <= ending }
      end
      result
    end

    def get_id_set(symbol: nil, id: nil, contract: nil, config: init)
      contract = contract.to_s.upcase if contract.is_a? Symbol
      id       =       id.to_s.upcase if       id.is_a? Symbol
      symbol   =   symbol.to_s.upcase if   symbol.is_a? Symbol

      if contract.is_a?(String) && (contract.length == 5)
        c_symbol = contract[0..1]
        if (not symbol.nil?) && (symbol != c_symbol)
          raise ArgumentError,
                "Mismatch between given symbol #{symbol} and contract #{contract}"
        end

        symbol = c_symbol
      end

      unless symbol.nil?
        sym = symbols.select { |s| s[:symbol] == symbol.to_s.upcase }.first
        if sym.nil? || sym[:id].nil?
          raise ArgumentError,
                "Could not find match in #{config[:symbols_file]} for given symbol #{symbol}"
        end
        raise ArgumentError, "Mismatching symbol #{symbol} and given id #{id}" if (not id.nil?) && (sym[:id] != id)

        return sym
      end
      unless id.nil?
        sym = symbols.select { |s| s[:id] == id.to_s }.first
        if sym.nil? || sym[:id].nil?
          raise ArgumentError,
                "Could not find match in #{config[:symbols_file]} for given id #{id}"
        end
        return sym
      end
      raise ArgumentError, 'Need :id, :symbol or valid :contract '
    end

    def compare(contract:, format: '%5.2f')
      format = "%#{format}" unless format[0] == '%'
      daily = provide(contract: contract, interval: :daily)
      full  = provide(contract: contract, interval: :days, filter: :full)
      rth   = provide(contract: contract, interval: :days, filter: :rth)
      rth_dates = rth.map { |x| x[:datetime] }
      daily.select! { |x| rth_dates.include? x[:datetime].to_datetime }
      full.select! {  |x| rth_dates.include? x[:datetime].to_datetime }

      printer = lambda { |z|
           # rubocop:disable Layout/ClosingParenthesisIndentation
           "#{z[:datetime].strftime('%m-%d') # rubocop:disable Layout/IndentationWidth
         }\t#{format format, z[:open]
         }\t#{format format, z[:high]
         }\t#{format format, z[:low]
         }\t#{format format, z[:close]
         }\t#{format '%7d', z[:volume]}"
        # rubocop:enable Layout/ClosingParenthesisIndentation
      }
      daily.each_with_index do |_x, i|
        puts "DAILY #{printer.call daily[i]}"
        puts "FULL  #{printer.call full[i]}"
        puts "RTH   #{printer.call rth[i]}"
        puts ' '
      end
    end
  end
end
