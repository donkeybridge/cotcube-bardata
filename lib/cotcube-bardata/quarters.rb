# frozen_string_literal: true

module Cotcube
  # Missing top level documentation
  module Bardata
    # the following method loads the quarterly bars (15-min bars) from the directory tree
    # also note that a former version of this method allowed to provide range or date parameters. this has been moved
    # to #provide itself.
    def provide_quarters(contract:, # rubocop:disable Metrics/ParameterLists
                         symbol: nil, id: nil,
                         timezone: Time.find_zone('America/Chicago'),
                         config: init,
                         keep_marker: false)

      unless contract.is_a?(String) && [3, 5].include?(contract.size)
        raise ArgumentError, "Contract '#{contract}' is bogus, should be like 'M21' or 'ESM21'"
      end

      sym = get_id_set(symbol: symbol, id: id, contract: contract)

      contract = contract[2..4] if contract.to_s.size == 5
      id = sym[:id]
      symbol = sym[:symbol]

      id_path   = "#{config[:data_path]}/quarters/#{id}"
      data_file = "#{id_path}/#{contract}.csv"
      raise "No data found for requested :id (#{id_path} does not exist)" unless Dir.exist?(id_path)

      raise "No data found for requested contract #{symbol}:#{contract} in #{id_path}." unless File.exist?(data_file)

      data = CSV.read(data_file, headers: %i[contract datetime day open high low close volume]).map do |row|
        row = row.to_h
        %i[open high low close].map { |x| row[x] = row[x].to_f }
        %i[volume day].map { |x| row[x] = row[x].to_i }
        row[:datetime] = timezone.parse(row[:datetime])
        row[:dist]     = ((row[:high] - row[:low]) / sym[:ticksize] ).to_i
        row[:type]     = :quarter
        row
      end
      data.pop if data.last[:high].zero? && (not keep_marker)
      data
    end
  end
end
