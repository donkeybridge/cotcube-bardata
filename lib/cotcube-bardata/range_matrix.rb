# frozen_string_literal: true

module Cotcube
  # Missing top level documentation
  module Bardata
    # this is an analysis tool to investigate actual ranges of an underlying symbol
    # it is in particular no true range or average true range, as a 'true range' can only be applied to
    #
    # The result printed / returned is a table, containing a matrix of rows:
    #   1. size: the amount of values evaluated
    #   2. avg:
    #   3. lower: like median, but not at 1/2 but 1/4
    #   4. median:
    #   5. upper: like median, but not at 1/2 but 3/4
    #   6. max:
    # and columns:
    #   1.a) all days os the series
    #   1.b) all days of the series, diminished by 2* :dim*100% extreme values (i.e. at both ends)
    #   1.c) the last 200 days
    #   2.a-c) same with days reduced to weeks (c: 52 weeks)
    #   3.a-c) same with days reduced to months (c: 12 months)
    #
    # NOTE: there is now a new method Cotcube::Helpers.simple_series_stats, that should be used in favor.
    def range_matrix(symbol: nil, id: nil, base: nil, print: false, dim: 0.05, days_only: false, last_n: 60, &block)
      # rubocop:disable Style/MultilineBlockChain
      symbol ||= base.last[:contract][0..1] if id.nil?
      sym = get_id_set(symbol: symbol, id: id)
      source = {}
      target = {}
      if base.nil?
        ml = (Cotcube::Bardata.continuous_actual_ml symbol: symbol)&.last[:contract]
        source[:days]   = Cotcube::Bardata.provide contract: ml
      else
        source[:days]   = base
      end
      source[:weeks]  = Cotcube::Helpers.reduce bars: source[:days], to: :weeks
      source[:months] = Cotcube::Helpers.reduce bars: source[:days], to: :months

      %i[days weeks months].each do |period|
        next if days_only and %i[weeks months].include? period
        source[period].map! do |x|
          x[:range] = block_given? ? yield(x) : (((x[:high] - x[:low]) / sym[:ticksize]).round)
          x
        end
        target[period] = {}
        target[period][:all_size]   =  source[period].size
        target[period][:all_avg]    = (source[period].map { |x| x[:range] }.reduce(:+) / source[period].size).round
        target[period][:all_lower]  =  source[period].sort_by do |x|
          x[:range]
        end.map { |x| x[:range] }[ (source[period].size * 1 / 4).round ]

        target[period][:all_median] = source[period].sort_by do |x|
          x[:range]
        end.map { |x| x[:range] }[ (source[period].size * 2 / 4).round ]

        target[period][:all_upper] = source[period].sort_by do |x|
          x[:range]
        end.map { |x| x[:range] }[ (source[period].size * 3 / 4).round ]

        target[period][:all_max] = source[period].map { |x| x[:range] }.max
        target[period][:all_records] = source[period].sort_by do |x|
          -x[:range]
        end.map { |x| { contract: x[:contract], range: x[:range] } }.take(5)

        tenth = (source[period].size * dim).round
        custom = source[period].sort_by { |x| x[:range] }[tenth..source[period].size - tenth]

        target[period][:dim_size]   =  custom.size
        target[period][:dim_avg]    = (custom.map { |x| x[:range] }.reduce(:+) / custom.size).round
        target[period][:dim_lower]  =  custom.sort_by do |x|
          x[:range]
        end.map { |x| x[:range] }[ (custom.size * 1 / 4).round ]

        target[period][:dim_median] = custom.sort_by do |x|
          x[:range]
        end.map { |x| x[:range] }[ (custom.size * 2 / 4).round ]

        target[period][:dim_upper] = custom.sort_by do |x|
          x[:range]
        end.map { |x| x[:range] }[ (custom.size * 3 / 4).round ]

        target[period][:dim_max] = custom.map { |x| x[:range] }.max
        target[period][:dim_records] = custom.sort_by do |x|
          -x[:range]
        end.map { |x| { contract: x[:contract], range: x[:range] } }.take(5)

        range = case period
                when :months
                  -(last_n/15)..-2
                when :weeks
                  -(last_n/4)..-2
                when :days
                  -last_n..-1
                else
                  raise ArgumentError, "Unsupported period: '#{period}'"
                end
        if range.begin.abs > source[period].size
          puts "WARNING: requested last_n = #{last_n} exceeds actual size (#{source[period].size}), adjusting...".light_yellow
          range = (-source[period].size..range.end)
        end
        custom = source[period][range]
        target[period][:rec_size]   =  custom.size
        target[period][:rec_avg]    = (custom.map { |x| x[:range] }.reduce(:+) / custom.size).round
        target[period][:rec_lower]  =  custom.sort_by do |x|
          x[:range]
        end.map { |x| x[:range] }[ (custom.size * 1 / 4).round ]
        target[period][:rec_median] = custom.sort_by do |x|
          x[:range]
        end.map { |x| x[:range] }[ (custom.size * 2 / 4).round ]
        target[period][:rec_upper] = custom.sort_by do |x|
          x[:range]
        end.map { |x| x[:range] }[ (custom.size * 3 / 4).round ]
        target[period][:rec_max] = custom.map { |x| x[:range] }.max
        target[period][:rec_records] = custom.sort_by do |x|
          -x[:range]
        end.map { |x| { contract: x[:contract], range: x[:range] } }.take(5)
      end

      if print
        %w[size avg lower median upper max].each do |a|
          print "#{'%10s' % a} | " # rubocop:disable Style/FormatString
          %i[days weeks months].each do |b|
            next if days_only and %i[weeks months].include? b
            %w[all dim rec].each do |c|
              print ('%8d' % target[b]["#{c}_#{a}".to_sym]).to_s # rubocop:disable Style/FormatString
            end
            print ' | '
          end
          puts ''
        end
      end

      target
      # rubocop:enable Style/MultilineBlockChain
    end
  end
end
