# frozen_string_literal: true

module Cotcube
  module Bardata

    def provide(symbol: nil, id: nil, contract:, config: init, date: Date.today - 1, type: nil, fill: :none)
      case type
      when :eod, :eods
        provide_eods(symbol: symbol, id: id, contract: contract, date: date) 
      when :quarters
        print :quarters
      when :hours
        print :hours
      when :daily, :dailies
        print :dailies
      else
        puts "WARNING: Using provide without :type is for legacy support pointing to .provide_daily".light_yellow
        provide_daily(symbol: symbol, id: id, contract: contract, config: config)
      end
    end
  end

end
