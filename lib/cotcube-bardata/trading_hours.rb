# frozen_string_literal: true

module Cotcube
  # Missing top level comment
  module Bardata
    def get_range(symbol: nil, set: :full, force_set: false, config: init, debug: false)
      return (0...24 * 7 * 3600) if set.to_s =~ /24x7/

      prepare = lambda do |f|
        CSV.read(f, converters: :numeric)
           .map(&:to_a)
           .tap { |x| x.shift unless x.first?.first?.is_a?(Numeric) }
           .map { |x| (x.first...x.last) }
      end
      sym = symbols(symbol: symbol).first
      raise ArgumentError, 'Cannot continue without valid :symbol' if symbol.nil? || (sym.is_a?(Array) && sym.empty?)

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
