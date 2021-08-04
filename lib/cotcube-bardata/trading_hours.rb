# frozen_string_literal: true

module Cotcube
  # Missing top level comment
  module Bardata
    # returns an Array of ranges containing a week of trading hours, specified by seconds since monday morning
    #    (as sunday is wday:0)
    # according files are located in config[:data_path]/trading_hours and picked either
    # by the symbol itself or by the assigned type
    # commonly there are two filter for each symbol: :full and :rth, exceptions are e.g. meats
    def trading_hours(symbol: nil, id: nil, # rubocop:disable Metrics/ParameterLists
                      filter: ,
                      force_filter: false,  # with force_filter one would avoid falling back
                                            # to the contract_type based range set
                      headers_only: false,  # return only headers instead of ranges
                      config: init, debug: false)
      return (0...24 * 7 * 3600) if filter.to_s =~ /24x7/

      prepare = lambda do |f|
        if headers_only
          CSV.read(f)
            .first
        else
          CSV.read(f, converters: :numeric)
             .map(&:to_a)
             .tap { |x| x.shift unless x.first.first.is_a?(Numeric) }
             .map { |x| (x.first...x.last) }
        end
      end

      sym = get_id_set(symbol: symbol, id: id)

      file = "#{config[:data_path]}/trading_hours/#{sym[:symbol]}_#{filter}.csv"
      puts "Trying to use #{file} for #{symbol} + #{filter}" if debug
      return prepare.call(file) if File.exist? file

      file = "#{config[:data_path]}/trading_hours/#{sym[:symbol]}_full.csv"
      puts "Failed. Trying to use #{file} now" if debug
      return prepare.call(file) if File.exist?(file) && (not force_filter)

      file = "#{config[:data_path]}/trading_hours/#{sym[:type]}_#{filter}.csv"
      puts "Failed. Trying to use #{file} now." if debug
      return prepare.call(file) if File.exist? file

      file = "#{config[:data_path]}/trading_hours/#{sym[:type]}_full.csv"
      puts "Failed. Trying to use #{file} now." if debug
      return prepare.call(file) if File.exist?(file) && (not force_filter)

      puts "Finally failed to find range filter for #{symbol} + #{filter}, returning 24x7".colorize(:light_yellow)
      (0...24 * 7 * 3600)
    end
  end
end
