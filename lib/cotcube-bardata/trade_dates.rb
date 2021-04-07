# frozen_string_literal: true

module Cotcube
  # missing top level documentation
  module Bardata
    # fetching official trade dates from CME
    # it returns the current trade date or, if today isn't a trading day, the last trade date.
    def last_trade_date
      uri = 'https://www.cmegroup.com/CmeWS/mvc/Volume/TradeDates?exchange=CME'
      begin
        HTTParty.get(uri, headers: { "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/81.0"})
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

    def holidays(config: init)
      CSV.read("#{config[:data_path]}/holidays.csv").map{|x| DateTime.parse(x[0])}
    end

  end
end
