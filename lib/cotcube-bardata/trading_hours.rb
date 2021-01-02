# frozen_string_literal: true

module Cotcube
  # Missing top level comment
  module Bardata
    # returns an Array of ranges containing a week of trading hours, specified by seconds since monday morning
    #    (as sunday is wday:0)
    # according files are located in config[:data_path]/trading_hours and picked either
    # by the symbol itself or by the assigned type
    # commonly there are two sets for each symbol: :full and :rth, exceptions are e.g. meats
    def trading_hours(symbol: nil, id: nil,         # rubocop:disable Metrics/ParameterLists
                      set: :full, force_set: false,
                      config: init, debug: false)
      return (0...24 * 7 * 3600) if set.to_s =~ /24x7/

      prepare = lambda do |f|
        CSV.read(f, converters: :numeric)
           .map(&:to_a)
           .tap { |x| x.shift unless x.first.first.is_a?(Numeric) }
           .map { |x| (x.first...x.last) }
      end

      sym = get_id_set(symbol: symbol, id: id)

      file = "#{config[:data_path]}/trading_hours/#{sym[:symbol]}_#{set}.csv"
      puts "Trying to use #{file} for #{symbol} + #{set}" if debug
      return prepare.call(file) if File.exist? file

      file = "#{config[:data_path]}/trading_hours/#{sym[:symbol]}_full.csv"
      puts "Failed. Trying to use #{file} now" if debug
      return prepare.call(file) if File.exist?(file) && (not force_set)

      file = "#{config[:data_path]}/trading_hours/#{sym[:type]}_#{set}.csv"
      puts "Failed. Trying to use #{file} now." if debug
      return prepare.call(file) if File.exist? file

      file = "#{config[:data_path]}/trading_hours/#{sym[:type]}_full.csv"
      puts "Failed. Trying to use #{file} now." if debug
      return prepare.call(file) if File.exist?(file) && (not force_set)

      puts "Finally failed to find range set for #{symbol} + #{set}, returning 24x7"..colorize(:light_yellow)
      (0...24 * 7 * 3600)
    end
  end
end
