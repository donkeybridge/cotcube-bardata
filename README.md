# cotcube-bardata

This gem is a versatile provider of bardata. It relies on a directory structure most probably saved to `/var/cotcube/bardata/`. The following directories and files contain data others might expect to be delivered by a database:

1. `eods`: within *eods/<id or symbol>/<date>.csv*, for each date a list of contracts is located, to be applied with the list of headers `%i[ contract date open high low close volume oi ]`.
2. `daily`: within *daily/<id or symbol>/<contract>.csv*, for each contract all eods are provided. The list of headers is expected as `%i[ contract date open high low close volume oi ]`. Please note that it is not obvious whether `close` contains settlement or actual closing price, depending on the exchange and the broker providing the source data.
3. `quarters`: within *quarters/<id or symbol>/<contract>.csv*, for each contract a list of quarters (15 minute intervals) is provided, depending on the first occurrence of the contract within the topN volume segment. Note the different headers here: `%i[ contract date_alike day open high low close volume ]`.
4. `trading_hours`: within *trading_hours/<symbol or type>_<set>.csv* a list of intervals is provided, with the headers `%i[ interval_start interval_end ]` for each interval described by seconds since Sunday 0:00p.m. (as defaulted by Ruby's *DateTime.new.wday)*.
5. `trade_dates.csv`: A growing list of trade\_dates as provided by the CME.  

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cotcube-bardata'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install cotcube-bardata

## Usage

### Configuration

The gem expects a configfile 'bardata.yml', located in '/etc/cotcube/' on linux platform and '/usr/local/etc/cotcube/' on FreeBSD. The location of the configfile can be overwritten by passing the according parameter to `init`.

### daily.rb

Provides

* `provide_daily(symbol: nil, id: nil, contract:, timezone: Time.find_zone('America/Chicago'), config: init)`
* `continuous(symbol: nil, id: nil, config: init, date: nil)`: Loads all dailies for given *id* and groups by date, hence providing a list of eods. 
* `continuous_ml(symbol: nil, id: nil, base: nil)`: Provides a list of contracts, containing a list of most liquid by volume contracts as `{ date: , ml: }`
* `continuous_actual_ml(symbol: nil, id: nil)`: Same as above, but providing the succeeding trading day (as the signaled 'ML' is yet one day old before it can be used). 
* `continuous_overview(symbol: nil, id: nil, config: init, selector: :volume, human: false, filter: nil)`: Several purposes, but most noticeable providing the range of first and last occurrence within the top N% by volume within eods.

### eods.rb

Provides

* `most_liquid_for(symbol: nil, id: nil, date: last_trade_date, config: init, quiet: false)`
* `provide_most_liquids_by_eod(config: init, date: last_trade_date, filter: :volume_part, age: 1.hour)`
* `provide_eods(**args)`
* `provide_quarters(**args)`

### quarters.rb

Provides `provide_quarters(**args)`.

### provide.rb

Provides `provide(**args)`.

### range\_matrix.rb

Provides `range_matrix`, a simple method processing data based on `Bardata.continuous_actual_ml` to return a statistical overview of daily high-low ranges (not True Ranges). It contains sets for 

* all available data,
* a data subset containing the recent 12 months
* data diminished by `:dim` (top and bottom) based on all available data

and contains  *max*, *avg*, *lower*, *median*, *upper* and *max* (where 'upper' and 'lower' are like the median but at the 25percentile and 75percentile resp.).

As a third dimension (sorry!) all of the above is applied to days, weeks as well as months. 

### trade\_dates.rb

Provides `last_trade_date`, simple fetches the current 5 trade dates from CME and returns the very last.

### trading\_hours.rb

Provides `get_range(symbol: nil, set: :full, force_set: false, config: init, debug: false)`, loading a set of intervals. The sets are defaulting to :full when the requested set is not found--unless :force\_set is enabled. Furthermore, if symbol is not found, the type-based version is returned. Eventually, if neither could be returned, the 24x7 interval is returned.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/donkeybridge/bitangent.


## License

The gem is available as open source under the terms of the [BSD-3-Clause-License](https://opensource.org/licenses/BSD-3-Clause).

