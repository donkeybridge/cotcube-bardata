# frozen_string_literal: true

module Cotcube
  # missing top level documentation
  module Bardata
    # fetching official trade dates from CME
    # it returns the current trade date or, if today isn't a trading day, the last trade date.
    def last_trade_date(force_update: false)
      const_LTD = :LAST_TRADE_DATE
      const_LTDU = :LAST_TRADE_DATE_UPDATE
      if force_update or not Object.const_defined?(const_LTD) or Object.const_get(const_LTD).nil? or Time.now - Object.const_get(const_LTDU) > 2.hours
        result = nil
        uri = 'https://www.cmegroup.com/CmeWS/mvc/Volume/TradeDates?exchange=CME'
        headers = { "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9",
                  "Accept-Encoding" => "gzip, deflate, br",
                  "Accept-Language" => "en-US,en;q=0.9",
                  "Cache-Control" => "max-age=0",
                  "Connection" => "keep-alive",
                 # Cookie: ak_bmsc=602078F6DE40954BAA8C7E7D3815102CACE82AAFD237000084B5A460F4FBCA68~pluz010T49Xag3sXquUZtVJmFX701dzEgt5v6Ht1EZSLKE4HL+bgg1L9ePnL5I0mm7QWXe1qaLhUbX1IPrL/f20trRMMRlkC3UWXk27DY/EBCP4mRno8QQygLCwgs2B2AQHJyb63WwRihCko8UYUiIhb89ArPZM5OPraoKy3JU9oE9e+iERdARNZHLHqRiB1GnmbKUvQqos3sXaEe3GpoiTszzk8sHZs4ZKuoO/rvFHko=",
                  "Host" => "www.cmegroup.com",
                  "sec-ch-ua" => %q[" Not A;Brand";v="99", "Chromium";v="90", "Google Chrome";v="90"],
                  "sec-ch-ua-mobile" => "?0",
                  "Sec-Fetch-Dest" => "document",
                  "Sec-Fetch-Mode" => "navigate",
                  "Sec-Fetch-Site" => "none",
                  "Sec-Fetch-User" => "?1",
                  "Upgrade-Insecure-Requests" => "1",
                  "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.212 Safari/537.36" }
        begin
#          HTTParty.get(uri, headers: { "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/81.0"})
           result = HTTParty.get(uri, headers: headers)
                  .parsed_response
                  .map do |x|
                    a = x['tradeDate'].chars.each_slice(2).map(&:join)
                    "#{a[0]}#{a[1]}-#{a[2]}-#{a[3]}"
                  end
                  .first
        rescue StandardError
          result = nil
        end
        oldverbose = $VERBOSE; $VERBOSE = nil
        Object.const_set(const_LTD, result)
        Object.const_set(const_LTDU, Time.now) unless result.nil?
        $VERBOSE = oldverbose
      end
      Object.const_get(const_LTD)
    end

    def holidays(config: init)
      CSV.read("#{config[:data_path]}/holidays.csv").map{|x| DateTime.parse(x[0])}
    end

  end
end
