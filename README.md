# Bitangent

This gem provides a class (and will maybe later provide a commandline tool) to process 
time series data into bitangents.

The underlying algorithm starts with the entire range of data and shears it (starting at 
90 or -90 degrees) along the x axis until a bitangent is found parallel to the x axis 
(i.e. __y == 0__ resp. __y == y.last__), resulting in an angle and a group of at least 
2 measurements. Please note here: 
- Measurements can be clustered to 1 finding in case there is no significant distance to 
  the bitangent in regard to the :fuzziness, which is at least 1 'tick'.
- Ocassionally a bitangent becomes an N-tangent, when multiple findings or clusters are 
  in one line resp. the fuzzied ranged on the sheared graph.
- Shearing is limited by reaching 0 degrees, so everything below the horizont (or above resp.)
  is discarded. 

After identifiying the angle of Z degress delivering N findings( actually N - 1, as the 
last finding always is the last member of the series), the entire time series then is split  
into N subranges, where each subrange is processed again until it reaches minimum size
(which defaults to 3 items).

Except for the very first range the challenge is to trim away the beginning of each sub
range.

The result of such a search is a tree, where it might be considerable to walk and change
this tree by adding elements to the time series instead of recalculating it completely. 

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bitangent'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install bitangent

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/bitangent.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
