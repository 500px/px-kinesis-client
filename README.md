# Px::Service::Kinesis

A simple Ruby Gem wrapper for Amazon Kinesis.

Built-in features:

* circuit breaker pattern on NetworkError
* linear backoff on throughput error
* timed/length buffering and bulk sending

TODO:

* robust partition distribution
* decay a specific shard based on throughput
* resharding when needed

## Installation

Add this line to your application's Gemfile:

    gem 'px-kinesis-client'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install px-timeline-service-client

## Usage

Follow the documentation wiki here:

* [Development Setup HOWTO](https://github.com/500px/500px/wiki/HOWTO:-Timeline-Service)

## Contributing

1. Fork it ( https://github.com/[my-github-username]/px-kinesis-client/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
