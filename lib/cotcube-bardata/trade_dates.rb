# frozen_string_literal: true

module Cotcube
  module Bardata

    # fetching official tradedates from CME
    def last_trade_date
      uri = "https://www.cmegroup.com/CmeWS/mvc/Volume/TradeDates?exchange=CME"
      res = nil
      res = HTTParty.get(uri).parsed_response
      res.map{|x| a = x["tradeDate"].chars.each_slice(2).map(&:join); "#{a[0]}#{a[1]}-#{a[2]}-#{a[3]}"}.first
    end

  end
end
