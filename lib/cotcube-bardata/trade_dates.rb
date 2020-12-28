# frozen_string_literal: true

module Cotcube
  # missing top level documentation
  module Bardata
    # fetching official trade dates from CME
    def last_trade_date
      uri = 'https://www.cmegroup.com/CmeWS/mvc/Volume/TradeDates?exchange=CME'
      begin
        HTTParty.get(uri)
                .parsed_response
                .map do |x|
                  a = x['tradeDate'].chars.each_slice(2).map(&:join)
                  "#{a[0]}#{a[1]}-#{a[2]}-#{a[3]}"
                end
                .first
      rescue StandardError
        nil
      end
    end
  end
end
