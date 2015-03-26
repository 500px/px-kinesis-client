# Px::Service::Kinesis

A simple Ruby Gem wrapper for Amazon Kinesis.

Built-in features:

* circuit breaker pattern on networking errors
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

    $ gem install px-kinesis-client

## Usage and Features

Extend *Px::Service::Kinesis:BaseRequest* for more fine tuning and specific
needs. The extended class can be as simple as something below:

	module SimpleKinesisClient
	
	  class Client < Px::Service::Kinesis::BaseRequest
	
	    include Singleton
	
	    def initialize
	      self.stream = "simple_stream"
	
	      super
	    end
	    
	  end
	end

### Basic Configuration

Default configurations are set in *Px::Service::Kinesis*, they can be changed by
passing block to *Px::Service::Kinesis.configure*

### #queue_records

Call this function to queue up data blobs for dispatching. All data are msgpacked, so your Kinesis data processor should be able to decode msgpacked data.


### # flush_records

Call this function to check and send data to Kinesis. If conditions pass, buffered data is consumed and flushed to Kinesis.


For documentation on CircuitBreaker usage, refer to [Px-Service-Client](https://github.com/500px/px-service-client) docs.

## Contributing

1. Fork it ( https://github.com/[my-github-username]/px-kinesis-client/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
