# frozen_string_literal: true

module Cotcube
  # Missing top level documentation comment
  module Bardata
    # just reads bardata/daily/<id>/<contract>.csv
    def provide_daily(contract:, # rubocop:disable Metrics/ParameterLists
                      symbol: nil, id: nil,
                      range: nil,
                      timezone: Time.find_zone('America/Chicago'),
                      keep_last: false,
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
        row[:dist]     = ((row[:high] - row[:low]) / sym[:ticksize] ).to_i
        row[:type]     = :daily
        row
      end
      data.pop if data.last[:high].zero? and not keep_last
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
    def continuous(symbol: nil, id: nil, config: init, date: nil, measure: nil, force_rewrite: false, selector: nil, debug: false)
      raise ArgumentError, ':measure, if given, must be a Time object (e.g. Time.now)' unless [NilClass, Time].include? measure.class
      measuring = lambda {|c| puts "[continuous] Time measured until '#{c}': #{(Time.now.to_f - measure.to_f).round(2)}sec" unless measure.nil? }

      measuring.call("Starting")
      sym = get_id_set(symbol: symbol, id: id)
      id  = sym[:id]
      symbol = sym[:symbol]
      effective_selector = selector || :volume
      raise ArgumentError, 'selector must be in %i[ nil :volume ;oi].' unless [ nil, :volume, :oi ].include? selector
      id_path = "#{config[:data_path]}/daily/#{id}"
      c_file  = "#{id_path}/continuous.csv"
      puts "Using file #{c_file}" if debug

      # instead of using the provide_daily methods above, for this bulk operation a 'continuous.csv' is created
      # this boosts from 4.5sec to 0.3sec
      rewriting = force_rewrite or not(File.exist?(c_file)) or (Time.now - File.mtime(c_file) > 8.days)
      if rewriting
        puts "In daily+continuous: Rewriting #{c_file} #{force_rewrite ? "forcibly" : "due to fileage"}.".light_yellow
        `rm #{c_file}; find #{id_path} | xargs cat 2>/dev/null | grep -v ',0,' | grep -v ',0$'| sort -t, -k2 | cut -d, -f1-8 | grep ',.*,' | uniq > #{c_file}`
      end
      loading = lambda do
        data = CSV.read(c_file).map do |row|
          r = { contract: row[0],
                date:     row[1],
                open:     row[2],
                high:     row[3],
                low:      row[4],
                close:    row[5],
                volume:   row[6].to_i,
                oi:       row[7].to_i
          }
        end

        measuring.call("Finished retrieving dailies.")
        result = []
        rounding =  8 # sym[:format].split('.').last.to_i rescue 6
        #bollinger_factor = 1
        #long = 250
        #short = 10
        indicators ||= {
           #typical:     Cotcube::Indicators.calc(a: :high, b: :low, c: :close) {|high, low, close| (high + low + close) / 3 },
           typical:     Cotcube::Indicators.calc(a: :close) { |close| close },
           sma250_high: Cotcube::Indicators.sma(key: :high,    length: long),
           sma250_low:  Cotcube::Indicators.sma(key: :low,     length: long),
           sma250_typ:  Cotcube::Indicators.sma(key: :typical, length: long), 
           sma60_typ:   Cotcube::Indicators.sma(key: :typical, length: short),
           tr:          Cotcube::Indicators.true_range,
           atr5:        Cotcube::Indicators.sma(key: :tr,    length: 5),
           dist_abs:    Cotcube::Indicators.calc(a: :sma250_high, b: :sma250_low, c: :high, d: :low) do |sma_high, sma_low, high, low| 
             if high > sma_high
               high - sma_high
             elsif sma_low > low 
               low - sma_low
             else 
               0
             end
           end,
           dist_sma: Cotcube::Indicators.calc(a: :sma250_typ, b: :sma60_typ) do |sma250, sma60|
             sma60 - sma250
           end,
           dist_index:     Cotcube::Indicators.index(key: :dist_abs, length: 60, abs: true),
           dev250_squared: Cotcube::Indicators.calc(a: :sma250_typ, b: :typical) {|sma, x| (sma - x) ** 2 },
           var250:         Cotcube::Indicators.sma(key: :dev250_squared, length: long),
           sig250:         Cotcube::Indicators.calc(a: :var250)                  {|var| Math.sqrt(var)},
           boll250_high:   Cotcube::Indicators.calc(a: :sig250, b: :sma250_typ)  {|sig, typ| (typ + sig * bollinger_factor) rescue nil},
           boll250_low:    Cotcube::Indicators.calc(a: :sig250, b: :sma250_typ)  {|sig, typ| (typ - sig * bollinger_factor) rescue nil},
           dev60_squared:  Cotcube::Indicators.calc(a: :sma60_typ, b: :typical)  {|sma, x| (sma - x) ** 2 },
           var60:          Cotcube::Indicators.sma(key: :dev60_squared, length: short),
           sig60:          Cotcube::Indicators.calc(a: :var60)                   {|var| Math.sqrt(var)},
           boll60_high:    Cotcube::Indicators.calc(a: :sig60, b: :sma60_typ)    {|sig, typ| (typ + sig * bollinger_factor) rescue nil},
           boll60_low:     Cotcube::Indicators.calc(a: :sig60, b: :sma60_typ)    {|sig, typ| (typ - sig * bollinger_factor) rescue nil}

        }



        data.group_by { |x| x[:date] }.map do |k, v|
          v.map { |x| x.delete(:date) }
          avg_bar = { 
            date: k,
            contract: v.max_by{|x| x[:oi] }[:contract],
            open: nil, high: nil, low: nil, close: nil,
            volume:   v.map { |x| x[:volume] }.reduce(:+),
            oi:       v.map { |x| x[:oi] }.reduce(:+),
          }

          %i[ open high low close ].each do |ohlc|
            avg_bar[ohlc] = (v.map{|x| x[ohlc].to_f * x[effective_selector] }.reduce(:+) / avg_bar[effective_selector]).round(rounding)
          end
          p avg_bar if debug
          indicators.each do |k,v|
            print format('%12s:  ', k.to_s) if debug
            avg_bar[k] = v.call(avg_bar).round(rounding)
            puts avg_bar[k] if debug
          end
          %i[tr atr5].each { |ind| 
            avg_bar[ind]     = (avg_bar[ind] / sym[:ticksize]).round.to_i unless avg_bar[ind].nil?
          }
          result << avg_bar
          result.last[:contracts] = v
        end
        result
      end
      constname = "CONTINUOUS_#{symbol}#{selector.nil? ? '' : ('_' + selector.to_s)}".to_sym
      if rewriting or not  Cotcube::Bardata.const_defined?( constname)
        Cotcube::Bardata.const_set constname, loading.call
      end
      measuring.call("Finished processing")
      date.nil? ? Cotcube::Bardata.const_get(constname).map{|z| z.dup } : Cotcube::Bardata.const_get(constname).find { |x| x[:date] == date }
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
                            measure: nil,
                            filter: nil)

      raise ArgumentError, ':measure, if given, must be a Time object (e.g. Time.now)' unless [NilClass, Time].include? measure.class
      measuring = lambda {|c| puts "[continuous_overview] Time measured until '#{c}': #{(Time.now.to_f - measure.to_f).round(2)}sec" unless measure.nil? }

      raise ArgumentError, 'Selector must be either :volume or :oi' unless selector.is_a?(Symbol) &&
        %i[volume oi].include?(selector)

      measuring.call("Starting")
      sym = get_id_set(symbol: symbol, id: id)
      id  = sym[:id]
      # noinspection RubyNilAnalysis
      data = continuous(id: id, config: config, measure: measure).map do |x|
        {
          date: x[:date],
          volume: x[:contracts].sort_by { |z| - z[:volume] }[0..4].compact.reject { |z| z[:volume].zero? },
          oi: x[:contracts].sort_by { |z| - z[:oi] }[0..4].compact.reject { |z| z[:oi].zero? }
        }
      end
      measuring.call("Retrieved continuous for #{sym[:symbol]}")
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
      measuring.call("Finished processing")
      result
    end

    def continuous_table(symbol: nil, id: nil,
                         selector: :volume,
                         filter: nil,
                         date: Date.today,
                         short: true,
                         silent: false,
                         measure: nil,
                         debuglevel: 1,
                         debug: false)
      if debug.is_a?(Integer)
        debuglevel = debug
        debug = debuglevel > 0 ? true : false
      end
      silent = false if debug

      raise ArgumentError, ':measure, if given, must be a Time object (e.g. Time.now)' unless [NilClass, Time].include? measure.class
      measuring = lambda {|c| puts "[continuous_table] Time measured until '#{c}': #{(Time.now.to_f - measure.to_f).round(2)}sec" unless measure.nil? }

      raise ArgumentError, 'Selector must be either :volume or :oi' unless selector.is_a?(Symbol) &&
        %i[volume oi].include?(selector)

      measuring.call("Entering function")
      sym = get_id_set(symbol: symbol, id: id)
      if %w[R6 BJ GE].include? sym[:symbol]
        puts "Rejecting to process symbol '#{sym[:symbol]}'.".light_red
        return []
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
      data = continuous_overview(id: id, selector: selector, filter: filter, human: false, config: init, measure: measure)
        .reject { |k, _| k[-2..].to_i == date.year % 2000 }
        .group_by { |k, _| k[2] }
      measuring.call("Retrieved continous_overview")
      output_sent = []
      early_year=nil
      long_output = []
      data.keys.sort.each do |month|
        current_long = { month: month }
        puts "Processing #{sym[:symbol]}#{month}" if debuglevel > 1
        v0 = data[month]
        ldays = v0.map { |_, v1| Date.parse(v1.last[:date]).yday }
        fdays = v0.map { |_, v1| Date.parse(v1.first[:date]).yday }.sort
        # if the last ml day nears the end of the year, we must fix
        ldays.map! { |x| x > 350 ? x - 366 : x } if ldays.min < 50
        fday  = fdays[fdays.size / 2]
        lavg  = ldays.reduce(:+) / ldays.size
        # a contract is proposed to use after fday - 1, but before ldays.min (green)
        # it is warned to user after fday - 1 but before lavg - 1            (red)
        # it is warned red >= lavg - 1 and <= lavg + 1
        color = if (ytoday >= lavg - 1) && (ytoday <= lavg + 1)
                  :light_red
                elsif (ytoday > ldays.min) && (ytoday < lavg - 1)
                  :light_yellow
                elsif (ytoday >= (fday > lavg ? 0 : fday - 5)) && (ytoday <= ldays.min)
                  :light_green
                else
                  :white
                end
        # rubocop:disable Layout/ClosingParenthesisIndentation
        long_output << {
          month:    month,
          first_ml: fday,
          last_min: ldays.min,
          last_avg: lavg,
          last_max: ldays.max }
        output = "#{sym[:symbol]
             }#{month
             }\t#{format '%12s', sym[:type]
             }\ttoday is #{ytoday
             } -- median of first is #{fday
             }\tlast ranges from #{format '%5d', ldays.min
             }: #{dfm.call(ldays.min)
             }\t#{format '%5d', lavg
             }: #{dfm.call(lavg)
             }\tto #{format '%5d', ldays.max
             }: #{dfm.call(ldays.max)}".colorize(color)
             if debug || (color != :white)
               puts output unless silent
               output_sent << "#{sym[:symbol]}#{month}" unless color == :white
             end
             early_year  ||= output
             next if silent or not (debug and debuglevel >= 2) 

             v0.each do |contract, v1|
               puts "\t#{contract
               }\t#{v1.first[:date]
               } (#{format '%3d', Date.parse(v1.first[:date]).yday
              })\t#{Date.parse(v1.last[:date]).strftime('%a, %Y-%m-%d')
               } (#{Date.parse(v1.last[:date]).yday})" unless silent
               # rubocop:enable Layout/ClosingParenthesisIndentation
             end
        end
      case output_sent.size
      when 0
        unless silent
          puts "WARNING: No output was sent for symbol '#{sym[:symbol]}'.".colorize(:light_yellow) 
          puts "         Assuming late-year-processing.".light_yellow
          puts early_year.light_green
        end
      when 1
        # all ok
        true
      else
        puts "Continuous table show #{output_sent.size} active contracts ( #{output_sent} ) for #{sym[:symbol]} ---------------" unless silent
      end
      measuring.call("Finished processing")
      short ? output_sent : long_output
    end
  end
end
