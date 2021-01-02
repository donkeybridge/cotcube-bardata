# frozen_string_literal: true

module Cotcube
  # missing top level documentation
  module Bardata
    # send pre-created days based on quarters
    def provide_cached(contract:, # rubocop:disable Metrics/ParameterLists
                       symbol: nil, id: nil,
                       config: init,
                       timezone: Time.find_zone('America/Chicago'),
                       filter: :full, # most probably either :full or :rth
                       force_update: false, # force reloading via provide_quarters
                       force_recent: false) #

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
          return base
        elsif File.mtime(file) < File.mtime(quarters_file)
          return base
        else
          puts "File #{file} exists, but is neither closed nor current. Running update.".colorize(:light_green)
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
        requested_set = trading_hours(symbol: sym[:symbol], set: filter)
        data = data.select_within(ranges: requested_set, attr: :datetime) { |x| x.to_datetime.to_sssm }
      end

      base = Cotcube::Helpers.reduce(bars: data, to: :days)

      # remove last day of result if not marked
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
      base
    end
  end
end
