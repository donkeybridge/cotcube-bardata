# frozen_string_literal: true

module Cotcube
  module Bardata

    def provide_quarters(
      symbol: nil, id: nil, 
      contract:, 
      as: :quarters, 
      range: nil, date: nil, 
      timezone: Time.find_zone('America/Chicago'),
      config: init,
      quiet: false
    )
      date = timezone.parse(date) if date.is_a? String
      raise ArgumentError, ":range and :date are mutually exclusive" if range and date
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
      raise ArgumentError, ":as can only be in [:quarters, :hours, :days]" unless %i[quarters hours days].include?(as)
      raise ArgumentError, "Could not guess :id or :symbol from 'contract: #{contract}', please clarify." if id.nil?
      id_path   = "#{config[:data_path]}/quarters/#{id}"
      data_file = "#{id_path}/#{contract}.csv"
      raise RuntimeError, "No data found for requested :id (#{id_path} does not exist)" unless Dir.exist?(id_path)
      raise RuntimeError, "No data found for requested contract #{symbol}:#{contract} in #{id_path}." unless File.exist?(data_file)
      data      = CSV.read(data_file, headers: %i[contract datetime day open high low close volume]).map do |row|
        row = row.to_h
        %i[open high low close].map{|x| row[x] = row[x].to_f}
        %i[volume day].map{|x|         row[x] = row[x].to_i}
        row[:datetime] = timezone.parse(row[:datetime])
        row
      end
      select_specific_date = lambda do |specific_date|
        data.select{|d| d[:day] == specific_date.day and specific_date.year == d[:datetime].year and (
          if specific_date.day > 1
            specific_date.month == d[:datetime].month
          else
            ((specific_date.month == d[:datetime].month     and d[:datetime].day == 1) or
             (specific_date.month == d[:datetime].month + 1 and d[:datetime].day  > 25) )
          end
        )}
      end
      if range
        starting = range.begin
        starting = timezone.parse(starting) if starting.is_a? String
        ending   = range.end
        ending   = timezone.parse(  ending) if ending.is_a? String
        if starting.hour == 0 and starting.min == 0 and ending.hour == 0 and ending.min == 0
          puts "WARNING: When sending midnight, full trading day is assumed (starting 5 pm yesterday, ending 4 pm today)".light_yellow unless quiet
          result = select_specific_date.call(starting)
          result += data.select{|d| d[:datetime] > starting and d[:datetime] < ending.to_date }
          result += select_specific_date.call(ending)
          result.uniq!
        else
          result = data.select{|x| x[:datetime] >= starting and x[:datetime] < ending }
        end
      elsif date
        result = select_specific_date.call(date)
      else 
        result = data
      end
      return case as
      when :hours
        Cotcube::Helpers.reduce(bars: result, to: 1.hour){|c,b| c[:day] == b[:day] and c[:datetime].hour == b[:datetime].hour }
      when :days
        Cotcube::Helpers.reduce(bars: result, to: 1.day ){|c,b| c[:day] == b[:day] }
      else
        result
      end
    end
  end
end
