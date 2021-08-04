# frozen_string_literal: true

module Cotcube
  # Missing top level documentation comment
  module Bardata
    def provide(contract:, # rubocop:disable Metrics/ParameterLists
                # Can be like ("2020-12-01 12:00"..."2020-12-14 11:00")
                range: nil,
                symbol: nil, id: nil,
                config: init,
                # supported types are :quarters, :hours, :days, :rth, :dailies, :weeks, :months
                interval: :days,
                # supported filters are :full and :rth (and custom named, if provided as file)
                filter: :full,
                # TODO: for future compatibility and suggestion: planning to include a function to update
                #       with live data from broker
                force_update: false,
                force_recent: false)

      sym = get_id_set(symbol: symbol, id: id, contract: contract, config: config)

      case interval
      when :quarters, :hours, :quarter, :hour
        base = provide_quarters(contract: contract, symbol: symbol, id: id, config: config)
        base = extended_select_for_range(range: range, base: base) if range
        requested_set = trading_hours(symbol: sym[:symbol], filter: filter)

        base = base.select_within(ranges: requested_set, attr: :datetime) { |x| x.to_datetime.to_sssm }
        return base if %i[quarters quarter].include? interval

        Cotcube::Helpers.reduce(bars: base, to: :hours) do |c, b|
          c[:day] == b[:day] and c[:datetime].hour == b[:datetime].hour
        end

      when :days, :weeks, :months
        base = provide_cached contract: contract, symbol: symbol, id: id, config: config, filter: filter,
                              range: range, force_recent: force_recent, force_update: force_update
        return base if %i[day days].include? interval

        # TODO: Missing implementation to reduce cached days to weeks or months
        raise 'Missing implementation to reduce cached days to weeks or months'
      when :dailies, :daily
        provide_daily contract: contract, symbol: symbol, id: id, config: config, range: range
      when :synth, :synthetic, :synthetic_days
        days = provide_cached contract: contract, symbol: symbol, id: id, config: config, filter: filter,
                              range: range, force_recent: force_recent, force_update: force_update
        dailies = provide_daily contract: contract, symbol: symbol, id: id, config: config, range: range
        if ((days.last[:datetime] > dailies.last[:datetime]) rescue false)
          dailies[..-2] + days.select { |d| d[:datetime] > dailies[-2][:datetime] }
        else
          dailies
        end
      else
        raise ArgumentError, "Unsupported or unknown interval '#{interval}' in Bardata.provide"
      end
    end

    def determine_significant_volume(base: , contract: )
      set  = Cotcube::Bardata.trading_hours(symbol: contract[0..1], filter: :rth)
      prod = base - base.select_within(ranges: set ,attr: :datetime) {|x| x.to_datetime.to_sssm }
      prod.group_by{|x| x[:volume] / 500 }
    end
  end
end
