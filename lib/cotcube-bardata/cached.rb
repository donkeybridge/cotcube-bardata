# frozen_string_literal: true

module Cotcube
  # missing top level documentation
  module Bardata
    # send pre-created days based on quarters
    def provide_cached(contract:, # rubocop:disable Metrics/ParameterLists
                       symbol: nil, id: nil,
                       range: nil,
                       config: init,
                       debug: false,
                       timezone: Time.find_zone('America/Chicago'),
                       filter: :full, # most probably either :full or :rth
                       force_update: false, # force reloading via provide_quarters
                       force_recent: false) #

      unless range.nil? ||
             range.is_a?(Range) &&
             [Date, DateTime, ActiveSupport::TimeWithZone].map do |cl|
               (range.begin.nil? || range.begin.is_a?(cl)) &&
               (range.end.nil? || range.end.is_a?(cl))
             end.reduce(:|)
        raise ArgumentError, 'Range, if given, must be either (Integer..Integer) or (Timelike..Timelike)'
      end

      unless range.nil?
        range_begin = range.begin.nil? ? nil : timezone.parse(range.begin.to_s)
        range_end   = range.end.nil? ? nil : timezone.parse(range.end.to_s)
        range = (range_begin..range_end)
      end

      headers = %i[contract datetime open high low close volume]
      sym      = get_id_set(symbol: symbol, id: id, contract: contract)
      contract = contract[-3..]
      dir      = "#{config[:data_path]}/cached/#{sym[:id]}_#{filter.to_s.downcase}"
      symlink  = "#{config[:data_path]}/cached/#{sym[:symbol]}_#{filter.to_s.downcase}"
      `mkdir -p #{dir}` unless Dir.exist? dir
      `ln -s #{dir} #{symlink}` unless File.exist? symlink
      file = "#{dir}/#{contract}.csv"
      quarters_file = "#{config[:data_path]}/quarters/#{sym[:id]}/#{contract[-3..]}.csv"
      if File.exist?(file) && (not force_update)
        base = CSV.read(file, headers: headers).map do |x|
          x = x.to_h
          x[:datetime] = timezone.parse(x[:datetime])
          %i[open high low close].each { |z| x[z] = x[z].to_f.round(9) }
          x[:volume] = x[:volume].to_i
          x[:type]   = "#{filter.to_s.downcase}_day".to_sym
          x
        end
        if base.last[:high].zero?
          # contract exists but is closed (has the CLOSED marker)
          base.pop
          # rubocop:disable Metrics/BlockNesting
          result = if range.nil?
                     base
                   else
                     base.select do |x|
                       (range.begin.nil? ? true : x[:datetime] >= range.begin) and
                         (range.end.nil? ? true : x[:datetime] <= range.end)
                     end
                   end
          return result
        elsif File.mtime(file) + 1.day > File.mtime(quarters_file)
          puts "CACHE #{File.mtime(file)}\t#{file}" if debug
          puts "QUART #{File.mtime(quarters_file)}\t#{quarters_file}" if debug
          result = if range.nil?
                     base
                   else
                     base.select do |x|
                       (range.begin.nil? ? true : x[:datetime] >= range.begin) and
                         (range.end.nil? ? true : x[:datetime] <= range.end)
                     end
                   end
          # rubocop:enable Metrics/BlockNesting
          return result
        else
          # write a (positive warning, that the cache needs to be updated, as cached value is older
          #   than one day but not closed
          puts "File #{file} exists, but is neither closed nor current. Running update...".colorize(:light_green)
        end
      end
      begin
        data = provide_quarters(contract: contract, id: sym[:id], keep_marker: true)
      rescue StandardError
        puts "Cannot provide quarters for requested contract #{sym[:symbol]}:#{contract},"\
            "returning '[ ]'".colorize(:light_red)
        return []
      end

      # removing marker if existing
      contract_is_marked = data.last[:high].zero?
      data.pop if contract_is_marked
      unless (filter == :full) || (data.size < 3)
        requested_set = trading_hours(symbol: sym[:symbol], filter: filter)
        data = data.select_within(ranges: requested_set, attr: :datetime) { |x| x.to_datetime.to_sssm }
      end

      base = Cotcube::Helpers.reduce(bars: data, to: :days)

      # remove last day of result unless marked
      base.pop unless contract_is_marked || force_recent

      base.map do |x|
        x[:datetime] = x[:datetime].to_date
        x[:type] = "#{filter}_day".to_sym
        x.delete(:day)
      end
      CSV.open(file, 'w') do |csv|
        base.each { |b| csv << b.values_at(*headers) }
        if contract_is_marked
          marker = ["#{sym[:symbol]}#{contract}", base.last[:datetime] + 1.day, 0, 0, 0, 0, 0]
          csv << marker
        end
      end
      if range.nil?
        base
      else
        base.select do |x|
          (range.begin.nil? ? true : x[:date] >= range.begin) and
            (range.end.nil? ? true : x[:date] <= range.end)
        end
      end
    end
  end
end
