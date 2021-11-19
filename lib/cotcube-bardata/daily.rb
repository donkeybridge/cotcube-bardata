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
                      add_eods: true,
                      indicators: {},
                      config: init)
      contract = contract.to_s.upcase
      rounding = 8
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

      sym = Cotcube::Helpers.get_id_set(symbol: symbol, id: id, contract: contract)
      contract = contract[2..4] if contract.to_s.size == 5
      id = sym[:id]
      id_path   = "#{config[:data_path]}/daily/#{id}"
      data_file = "#{id_path}/#{contract}.csv"
      raise "No data found for requested :id (#{id_path} does not exist)" unless Dir.exist?(id_path)

      raise "No data found for requested contract #{symbol}:#{contract} in #{id_path}." unless File.exist?(data_file)

      data = CSV.read(data_file, headers: %i[contract date open high low close volume oi]).map do |row|
        row = row.to_h
        row.each do |k, _|
          if %i[open high low close].include? k
            row[k] = row[k].to_f
            row[k] = (row[k] * sym[:bcf]).round(8) unless sym[:bcf] == 1.0
          end
          row[k] = row[k].to_i if %i[volume oi].include? k
        end
        row[:datetime] = timezone.parse(row[:date])
        row[:dist]     = ((row[:high] - row[:low]) / sym[:ticksize] ).to_i
        row[:type]     = :daily
        row
      end
      contract_expired = data.last[:high].zero?
      data.pop if contract_expired and not keep_last
      if not contract_expired and add_eods
        today = Date.today
        eods = [ ]
        while today.strftime('%Y-%m-%d') > data.last[:date]
          eods << provide_eods(symbol: sym[:symbol], dates: today, contracts_only: false, quiet: true)
          today -= 1
        end
        eods.flatten!.map!{|x| x.tap {|y| %i[ volume_part oi_part ].map{|z| y.delete(z)} } }
        eods.select!{|x| x[:contract] == "#{sym[:symbol]}#{contract}" } 
        eods.map!{|x| x.tap{|y| 
          if sym[:bcf] != 1.0
            %i[open high low close].map{|k|
               y[k] = (y[k] * sym[:bcf]).round(8)
            }
          end
          y[:datetime] = timezone.parse(y[:date])
          y[:dist]     = ((y[:high] - y[:low]) / sym[:ticksize] ).to_i
          y[:type]     = :eod
        } }
        data += eods.reverse
      end
      data.map do |bar| 
        indicators.each do |k,v|
          tmp = v.call(bar)
          bar[k] = tmp.respond_to?(:round) ? tmp.round(rounding) : tmp
        end
      end unless indicators.empty?
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
    def continuous(symbol: nil, id: nil, config: init, date: nil, measure: nil, force_rewrite: false, selector: nil, debug: false, add_eods: true, indicators: nil)
      raise ArgumentError, ':measure, if given, must be a Time object (e.g. Time.now)' unless [NilClass, Time].include? measure.class
      measuring = lambda {|c| puts "[continuous] Time measured until '#{c}': #{(Time.now.to_f - measure.to_f).round(2)}sec" unless measure.nil? }

      measuring.call("Starting")
      sym = Cotcube::Helpers.get_id_set(symbol: symbol, id: id)
      id  = sym[:id]
      symbol = sym[:symbol]
      ticksize = sym[:ticksize] 
      effective_selector = selector || :volume
      raise ArgumentError, 'selector must be in %i[ nil :volume ;oi].' unless [ nil, :volume, :oi ].include? selector
      id_path = "#{config[:data_path]}/daily/#{id}"
      c_file  = "#{id_path}/continuous.csv"
      puts "Using file #{c_file}" if debug

      # instead of using the provide_daily methods above, for this bulk operation a 'continuous.csv' is created
      # this boosts from 4.5sec to 0.3sec
      rewriting = (force_rewrite or not(File.exist?(c_file)) or (Time.now - File.mtime(c_file) > 8.days))
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
                oi:       row[7].to_i,
                type:     :cont
          }
        end
        if add_eods
          today = Date.today
          eods = [ ]
          while today.strftime('%Y-%m-%d') > data.last[:date]
            eods << provide_eods(symbol: symbol, dates: today, contracts_only: false, quiet: true)
            today -= 1
          end
          eods.flatten!.map!{|x| x.tap {|y| %i[ volume_part oi_part ].map{|z| y.delete(z)} } }
          eods.delete_if { |elem|  elem.flatten.empty? }
          data += eods.reverse
        end

        measuring.call("Finished retrieving dailies.")
        result = []
        rounding =  8 # sym[:format].split('.').last.to_i rescue 6
        indicators ||= {
          typical:     Cotcube::Indicators.calc(a: :high, b: :low, c: :close) {|high, low, close| (high + low + close) / 3 },
          sma250_high: Cotcube::Indicators.sma(key: :high,    length: 250),
          sma250_low:  Cotcube::Indicators.sma(key: :low,     length: 250),
          sma250_typ:  Cotcube::Indicators.sma(key: :typical, length: 250), 
          dist: Cotcube::Indicators.calc(a: :high, b: :low, finalize: :to_i) {|high, low| ((high-low) / ticksize) },
        }



        data.group_by { |x| x[:date] }.map do |k, v|
          v.map { |x| x.delete(:date) }
          avg_bar = { 
            date: k,
            contract: v.max_by{|x| x[:oi] }[:contract],
            open: nil, high: nil, low: nil, close: nil,
            volume:   v.map { |x| x[:volume] }.reduce(:+),
            oi:       v.map { |x| x[:oi] }.reduce(:+),
            type:     :cont_eod
          }

          %i[ open high low close ].each do |ohlc|
            avg_bar[ohlc] = (v.map{|x| x[ohlc].to_f * x[effective_selector] }.reduce(:+) / avg_bar[effective_selector]).round(rounding)
            avg_bar[ohlc] = (avg_bar[ohlc] * sym[:bcf]).round(8) unless sym[:bcf] == 1.0

          end
          p avg_bar if debug
          indicators.each do |k,v|
            print format('%12s:  ', k.to_s) if debug
            tmp = v.call(avg_bar)
            avg_bar[k] = tmp.respond_to?(:round) ? tmp.round(rounding) : tmp
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
        old = $VERBOSE; $VERBOSE = nil
        Cotcube::Bardata.const_set constname, loading.call
        $VERBOSE = old
      end
      measuring.call("Finished processing")
      date.nil? ? Cotcube::Bardata.const_get(constname).map{|z| z.dup } : Cotcube::Bardata.const_get(constname).find { |x| x[:date] == date }
    end

    # the filter series is an indicator based on the Cotcube::Bardata.continuous of the asset price.
    #   current default filter is the ema50
    def filter_series(ema_length: 50, symbol: , print_range: nil)
      ema_high_n = "ema#{ema_length}_high".to_sym
      ema_low_n  = "ema#{ema_length}_low".to_sym
      ema_filter = "ema#{ema_length}_filter".to_sym
      indicators = {
        ema_high_n => Cotcube::Indicators.ema(key: :high,     length: ema_length,  smoothing: 2),
        ema_low_n  => Cotcube::Indicators.ema(key: :low,      length: ema_length,  smoothing: 2),
        :tr        => Cotcube::Indicators.true_range,
        :atr5      => Cotcube::Indicators.ema(key: :tr,       length: 5,           smoothing: 2),
        ema_filter => Cotcube::Indicators.calc(a: :high,      b: :low,             c: :close,
                                               d: ema_high_n, e: ema_low_n,        f: :atr5,
                                               finalize: :to_i)  do |high, low, close, ema_high, ema_low, atr5|

                                                  if    close >  ema_high and (low - ema_high).abs <= atr5 / 5.0; 3 # :bullish_tipped
                                                  elsif   low >  ema_high and (low - ema_high).abs >= atr5 * 3.0; 5 # :bullish_away
                                                  elsif   low >  ema_high and (low - ema_high).abs <= atr5 / 1.5; 2 # :bullish_nearby
                                                  elsif   low >  ema_high;                                        4 # :bullish

                                                  elsif close <  ema_low and (high - ema_low).abs <= atr5 / 5.0; -3 # :bearish_tipped
                                                  elsif  high <  ema_low and (high - ema_low).abs >= atr5 * 3.0; -5 # :bearish_away
                                                  elsif  high <  ema_low and (high - ema_low).abs <= atr5 / 1.5; -2 # :bearish_nearby
                                                  elsif  high <  ema_low;                                        -4 # :bearish

                                                  elsif close >= ema_high and (close - ema_high).abs > atr5 ;     2 # :bullish_closed
                                                  elsif close <= ema_low  and (close - ema_low ).abs > atr5 ;    -2 # :bearish_closed
                                                  elsif close >= ema_high;                                        1 # :bullish_weak
                                                  elsif close <= ema_low;                                        -1 # :bearish_weak
                                                  elsif close >  ema_low and close < ema_high;                    0 # :ambigue
                                                  else
                                                    raise RuntimeError, "Unconsidered Indicator value with #{high}, #{low}, #{close}, #{ema_high}, #{ema_low}, #{atr5}"

                                                  end
                                                end
      }
      filter = Cotcube::Bardata.continuous(symbol: symbol, indicators: indicators).
        map{ |z| z[:datetime] = DateTime.parse(z[:date]); z[:datetime] += z[:datetime].wday == 5 ? 3 : 1; z.slice(:datetime, ema_filter) }.
        group_by{ |z| z[:datetime] }.
        map{ |k,v| [ k, v[0][ema_filter] ] }.
        to_h.
        tap{ |z| z.to_a[print_range].each { |v|
          puts "#{v[0].strftime('%Y-%m-%d')
            } : #{format '%2d', v[1]
            }".colorize(v[1] > 3 ? :light_green : v[1] > 1 ? :green : v[1] < -3 ? :light_red : v[1] < -1 ? :red : :white )
        } if print_range.is_a? Range
      }
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
      sym = Cotcube::Helpers.get_id_set(symbol: symbol, id: id)
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
      sym = Cotcube::Helpers.get_id_set(symbol: symbol, id: id)
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
        .reject { |k, _| k[-2..].to_i >= date.year % 2000 }
        .group_by { |k, _| k[2] }
      measuring.call("Retrieved continous_overview")
      output_sent = []
      early_year=nil
      long_output = []
      data.keys.sort.each do |month|
        puts "Processing #{sym[:symbol]}#{month}" if debuglevel > 1
        v0 = data[month]
        # ldays is the list of 'last days'
        ldays = v0.map { |_, v1| Date.parse(v1.last[:date]).yday }
        # fdays is the list of 'first days'
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
             end
             output_sent << "#{sym[:symbol]}#{month}" unless color == :white
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
