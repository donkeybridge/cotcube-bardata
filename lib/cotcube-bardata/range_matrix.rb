# frozen_string_literal: true

module Cotcube
  # Missing top level documentation
  module Bardata
    def range_matrix(symbol:, print: false, dim: 0.05)
      # rubocop:disable Style/MultilineBlockChain
      sym = Cotcube::Bardata.symbols(symbol: symbol).first
      source = {}
      target = {}
      source[:days]   = Cotcube::Bardata.continuous_actual_ml symbol: symbol
      source[:weeks]  = Cotcube::Helpers.reduce bars: source[:days], to: :weeks
      source[:months] = Cotcube::Helpers.reduce bars: source[:days], to: :months

      %i[days weeks months].each do |period|
        source[period].map! do |x|
          x[:range] = ((x[:high] - x[:low]) / sym[:ticksize]).round
          x
        end
        target[period] = {}
        target[period][:all_size]   =  source[period].size
        target[period][:all_avg]    = (source[period].map { |x| x[:range] }.reduce(:+) / source[period].size).round
        target[period][:all_lower]  =  source[period].sort_by do |x|
                                         x[:range]
                                       end.map { |x| x[:range] }[ (source[period].size * 1 / 4).round ]
        target[period][:all_median] =  source[period].sort_by do |x|
                                         x[:range]
                                       end.map { |x| x[:range] }[ (source[period].size * 2 / 4).round ]
        target[period][:all_upper]  =  source[period].sort_by do |x|
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
        target[period][:dim_median] =  custom.sort_by do |x|
                                         x[:range]
                                       end.map { |x| x[:range] }[ (custom.size * 2 / 4).round ]
        target[period][:dim_upper]  =  custom.sort_by do |x|
                                         x[:range]
                                       end.map { |x| x[:range] }[ (custom.size * 3 / 4).round ]
        target[period][:dim_max]    =  custom.map { |x| x[:range] }.max
        target[period][:dim_records] = custom.sort_by do |x|
                                         -x[:range]
                                       end.map { |x| { contract: x[:contract], range: x[:range] } }.take(5)

        range = case period
                when :months
                  -13..-2
                when :weeks
                  -53..-2
                when :days
                  -200..-1
                else
                  raise ArgumentError, "Unsupported period: '#{period}'"
                end
        custom = source[period][range]
        target[period][:rec_size]   =  custom.size
        target[period][:rec_avg]    = (custom.map { |x| x[:range] }.reduce(:+) / custom.size).round
        target[period][:rec_lower]  =  custom.sort_by do |x|
                                         x[:range]
                                       end.map { |x| x[:range] }[ (custom.size * 1 / 4).round ]
        target[period][:rec_median] =  custom.sort_by do |x|
                                         x[:range]
                                       end.map { |x| x[:range] }[ (custom.size * 2 / 4).round ]
        target[period][:rec_upper]  =  custom.sort_by do |x|
                                         x[:range]
                                       end.map { |x| x[:range] }[ (custom.size * 3 / 4).round ]
        target[period][:rec_max]    =  custom.map { |x| x[:range] }.max
        target[period][:rec_records] = custom.sort_by do |x|
                                         -x[:range]
                                       end.map { |x| { contract: x[:contract], range: x[:range] } }.take(5)
      end

      if print
        %w[size avg lower median upper max].each do |a|
          print "#{'%10s' % a} | " # rubocop:disable Style/FormatString
          %i[days weeks months].each do |b|
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
