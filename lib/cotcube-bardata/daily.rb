# frozen_string_literal: true

module Cotcube
  # Missing top level documentation comment
  module Bardata
    # just reads bardata/daily/<id>/<contract>.csv
    def provide_daily(contract:, # rubocop:disable Metrics/ParameterLists
                      symbol: nil, id: nil,
                      range: nil,
                      timezone: Time.find_zone('America/Chicago'),
                      config: init)
      contract = contract.to_s.upcase
      unless contract.is_a?(String) && [3, 5].include?(contract.size)
        raise ArgumentError, "Contract '#{contract}' is bogus, should be like 'M21' or 'ESM21'"
      end
      unless range.nil? ||
             (range.is_a?(Range) &&
             [Date, DateTime, ActiveSupport::TimeWithZone].map do |cl|
               (range.begin.nil? || range.begin.is_a?(cl)) &&
               (range.end.nil?   || range.end.is_a?(cl))
             end.reduce(:|))

        raise ArgumentError, 'Range, if given, must be either (Integer..Integer) or (Timelike..Timelike)'
      end

      unless range.nil?
        range_begin = range.begin.nil? ? nil : timezone.parse(range.begin.to_s)
        range_end   = range.end.nil? ? nil : timezone.parse(range.end.to_s)
        range = (range_begin..range_end)
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
      if range.nil?
        data
      else
        data.select do |x|
          (range.begin.nil? ? true : x[:datetime] >= range.begin) and
            (range.end.nil? ? true : x[:datetime] <= range.end)
        end
      end
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
      result.each_key do |key|
        result[key].map! do |x|
          x[:volume].select! { |z| z[:contract] == key }
          x[:oi].select!     { |z| z[:contract] == key }
          x
        end
      end
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

    def continuous_table(symbol: nil, id: nil,
                         selector: :volume,
                         filter: nil,
                         date: Date.today,
                         debuglevel: 1,
                         debug: false)
      if debug.is_a?(Integer)
        debuglevel = debug
        debug = debuglevel > 0 ? true : false
      end
      raise ArgumentError, 'Selector must be either :volume or :oi' unless selector.is_a?(Symbol) &&
                                                                           %i[volume oi].include?(selector)

      sym = get_id_set(symbol: symbol, id: id)
      if %w[R6 BJ GE].include? sym[:symbol]
        puts "Rejecting to process symbol '#{sym[:symbol]}'."
        return
      end
      id  = sym[:id]
      dfm = lambda do |x, y = date.year|
        k = Date.strptime("#{y} #{x.negative? ? x + 366 : x}", '%Y %j')
        k -= 1 while [0, 6].include?(k.wday)
        k.strftime('%a, %Y-%m-%d')
      rescue StandardError
        puts "#{sym[:symbol]}\t#{x}\t#{y}"
      end

      ytoday = date.yday
      data = continuous_overview(id: id, selector: selector, filter: filter, human: false, config: init)
        .reject { |k, _| k[-2..].to_i == date.year % 2000 }
             .group_by { |k, _| k[2] }
      output_sent = []
      early_year=nil
      data.keys.sort.each do |month|
        puts "Processing #{sym[:symbol]}#{month}" if debuglevel > 1
        v0 = data[month]
        ydays = v0.map { |_, v1| Date.parse(v1.last[:date]).yday }
        fdays = v0.map { |_, v1| Date.parse(v1.first[:date]).yday }.sort
        # if the last ml day nears the end of the year, we must fix
        ydays.map! { |x| x > 350 ? x - 366 : x } if ydays.min < 50
        fday  = fdays[fdays.size / 2]
        yavg  = ydays.reduce(:+) / ydays.size
        # a contract is proposed to use after fday - 1, but before ydays.min (green)
        # it is warned to user after fday - 1 but before yavg - 1            (red)
        # it is warned red >= yavg - 1 and <= yavg + 1
        color = if (ytoday >= yavg - 1) && (ytoday <= yavg + 1)
                  :light_red
                elsif (ytoday > ydays.min) && (ytoday < yavg - 1)
                  :light_yellow
                elsif (ytoday >= (fday > yavg ? 0 : fday - 5)) && (ytoday <= ydays.min)
                  :light_green
                else
                  :white
                end
        # rubocop:disable Layout/ClosingParenthesisIndentation
        output = "#{sym[:symbol]
             }#{month
             }\t#{format '%12s', sym[:type]
             }\t#{ytoday
              }/#{fday
             }\t#{format '%5d', ydays.min
             }: #{dfm.call(ydays.min)
             }\t#{format '%5d', yavg
             }: #{dfm.call(yavg)
             }\t#{format '%5d', ydays.max
             }: #{dfm.call(ydays.max)}".colorize(color)
        if debug || (color != :white)
          puts output
          output_sent << "#{sym[:symbol]}#{month}" unless color == :white
        end
        early_year  ||= output
        next unless (debug and debuglevel >= 2)

        v0.each do |contract, v1|
          puts "\t#{contract
               }\t#{v1.first[:date]
               }\t#{Date.parse(v1.last[:date]).strftime('%a')
               }, #{v1.last[:date]
               } (#{Date.parse(v1.last[:date]).yday}"
               # rubocop:enable Layout/ClosingParenthesisIndentation
        end
      end
      case output_sent.size
      when 0
        puts "WARNING: No output was sent for symbol '#{sym[:symbol]}'.".colorize(:light_yellow)
        puts "         Assuming late-year-processing.".light_yellow
        puts early_year.light_green
      when 1
        # all ok
        true
      else
        puts "---- #{output_sent} for #{sym[:symbol]} ---------------"

      end
      output_sent
    end
  end
end
