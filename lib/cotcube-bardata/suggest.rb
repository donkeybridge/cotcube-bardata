# frozen_string_literal: true

module Cotcube
  # missing top level documentation
  module Bardata
    # based on day(of year) and symbol, suggest best fitting contract
    def suggest_contract_for symbol:, date: Date.today, warnings: true
      ml = Cotcube::Bardata.continuous_table symbol: symbol, date: date
      if ml.size != 1 
	puts "WARNING: No or no unique most liquid found for #{date}. please give :contract parameter".light_yellow if warnings
	if ml.size > 1
	  puts "\tUsing #{ml.last}. Consider breaking here, if that is not acceptable.".light_yellow if warnings
	  sleep 1
	else
	  puts "\tERROR: No suggestible contract found for #{symbol} and #{date}.".light_red
	  return
	end
      end
      year = date.year % 100
      if ml.last[2] < "K" and date.month > 9
        "#{ml.last}#{year + 1}"
      else
        "#{ml.last}#{year}"
      end
    end
  end
end

