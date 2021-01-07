# frozen_string_literal: true

module Cotcube
  # Missing top level documentation comment
  module Bardata
    # just reads bardata/daily/<id>/<contract>.csv
    def provide_daily(contract:,
                      symbol: nil, id: nil,
                      timezone: Time.find_zone('America/Chicago'),
                      config: init)
      contract = contract.to_s.upcase
      unless contract.is_a?(String) && [3, 5].include?(contract.size)
        raise ArgumentError, "Contract '#{contract}' is bogus, should be like 'M21' or 'ESM21'"
      end

      sym = get_id_set(symbol: symbol, id: id, contract: contract)
      contract = contract[2..4] if contract.to_s.size == 5
      id = sym[:id]
      id_path   = "#{config[:data_path]}/daily/#{id}"
      data_file = "#{id_path}/#{contract}.csv"
      raise "No data found for requested :id (#{id_path} does not exist)" unless Dir.exist?(id_path)

      raise "No data found for requested contract #{symbol}:#{contract} in #{id_path}." unless File.exist?(data_file)

      data = CSV.read(data_file, headers: %i[contract date open high low close volume oi]).map do |row|
        row = row.to_h
        row.each do |k, _|
          row[k] = row[k].to_f if %i[open high low close].include? k
          row[k] = row[k].to_i if %i[volume oi].include? k
        end
        row[:datetime] = timezone.parse(row[:date])
        row[:type]     = :daily
        row
      end
      data.pop if data.last[:high].zero?
      data
    end

    # reads all files in  bardata/daily/<id> and aggregates by date
    # (what is a pre-stage of a continuous based on daily bars)
    def continuous(symbol: nil, id: nil, config: init, date: nil)
      sym = get_id_set(symbol: symbol, id: id)
      id  = sym[:id]
      id_path = "#{config[:data_path]}/daily/#{id}"
      available_contracts = Dir["#{id_path}/*.csv"].map { |x| x.split('/').last.split('.').first }
      available_contracts.sort_by! { |x| x[-7] }.sort_by! { |x| x[-6..-5] }
      data = []
      available_contracts.each do |c|
        provide_daily(id: id, config: config, contract: c).each do |x|
          data << x
        end
      end
      result = []
      data.sort_by { |x| x[:date] }.group_by { |x| x[:date] }.map do |k, v|
        v.map { |x| x.delete(:date) }
        result << {
          date: k,
          volume: v.map { |x| x[:volume] }.reduce(:+),
          oi: v.map { |x| x[:oi] }.reduce(:+)
        }
        result.last[:contracts] = v
      end
      date.nil? ? result : result.select { |x| x[:date] == date }.first
    end

    def continuous_ml(symbol: nil, id: nil, base: nil)
      (base.nil? ? Cotcube::Bardata.continuous(symbol: symbol, id: id) : base).map do |x|
        x[:ml] = x[:contracts].max_by { |z| z[:volume] }[:contract]
        { date: x[:date], ml: x[:ml] }
      end
    end

    # the method above delivers the most_liquid as it is found at the end of the day. D
    # during trading, the work is done with data
    # that is already one day old. This is is fixed here:
    def continuous_actual_ml(symbol: nil, id: nil)
      continuous =    Cotcube::Bardata.continuous    symbol: symbol, id: id
      continuous_ml = Cotcube::Bardata.continuous_ml base: continuous
      continuous_hash = continuous.to_h { |x| [x[:date], x[:contracts]] }
      actual_ml = continuous_ml.pairwise { |a, b| { date: b[:date], ml: a[:ml] } }
      actual_ml.map do |x|
        r = continuous_hash[x[:date]].select { |z| x[:ml] == z[:contract] }.first
        r = continuous_hash[x[:date]].min_by { |z| -z[:volume] } if r.nil?
        r
      end
    end

    # based on .continuous, this methods sorts the prepared dailies continuous for each date
    # on either :volume (default) or :oi
    # with this job done, it can provide the period for which a past contract was the most liquid
    #
    def continuous_overview(symbol: nil, id: nil, # rubocop:disable Metrics/ParameterLists
                            config: init,
                            selector: :volume,
                            human: false,
                            filter: nil)
      raise ArgumentError, 'Selector must be either :volume or :oi' unless selector.is_a?(Symbol) &&
                                                                           %i[volume oi].include?(selector)

      sym = get_id_set(symbol: symbol, id: id)
      id  = sym[:id]
      # noinspection RubyNilAnalysis
      data = continuous(id: id, config: config).map do |x|
        {
          date: x[:date],
          volume: x[:contracts].sort_by { |z| - z[:volume] }[0..4].compact.reject { |z| z[:volume].zero? },
          oi: x[:contracts].sort_by { |z| - z[:oi] }[0..4].compact.reject { |z| z[:oi].zero? }
        }
      end
      data.reject! { |x| x[selector].empty? }
      result = data.group_by { |x| x[selector].first[:contract] }
      if human
        result.each do |k, v|
          next unless filter.nil? || v.first[selector].first[:contract][2..4] =~ (/#{filter}/)

          # rubocop:disable Layout/ClosingParenthesisIndentation
          puts "#{k
             }\t#{v.first[:date]
             }\t#{v.last[:date]
             }\t#{format('%4d', (Date.parse(v.last[:date]) - Date.parse(v.first[:date])))
             }\t#{result[k].map do |x|
                    x[:volume].select do
                      x[:contract] == k
                    end
                  end.size
             }"
          # rubocop:enable Layout/ClosingParenthesisIndentation
        end
      end
      result
    end
  end
end
