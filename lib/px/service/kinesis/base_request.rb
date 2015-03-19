require 'msgpack'
require 'aws-sdk'
require 'yajl'
require 'px-service-client'
require 'circuit_breaker'

module Px::Service::Kinesis
  class BaseRequest
    include Px::Service::Client::CircuitBreaker
    include Px::Service::Client::Caching

    DEFAULT_PUT_RATE = 0.25
    FLUSH_LENGTH = 200

    attr_accessor = :kinesis

    # Circuit breaker configuration
    circuit_handler do |handler|
      handler.logger =  defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
      handler.failure_threshold = 5
      handler.failure_timeout = 7
      handler.invocation_timeout = 10
      handler.excluded_exceptions = [Px::Service::ServiceRequestError]
    end

    def initialize
      # cheating, do config
      @kinesis = Aws::Kinesis::Client.new(region: Px::Service::Kinesis.config.region)
      # TODO: by default partition key can be combination
      # of hostname and other factors to ensure even
      # distribution over shards.
      #
      # Current design is per machine per shard per partition key
      #
      # If roshi does not care out-of-order insertion. We don't have
      # to worry about out-of-order sequence numbers going to different
      # shards. the consumer can take care of that

      @last_send = Time.now
      @last_throughput_exceeded = -1

      @jencoder = Yajl::Encoder.new
      @buffer = Array.new

      # TODO: remove this when done testing or abstract it out
      #  this is so we don't use the buffer when developing
      @test = true
    end

    ##
    # Takes a blob of data to send to Kinesis
    # The data will be json encoded and msgpacked
    #
    def push_records(stream, data)

      data_blob = @jencoder.encode(data).to_msgpack

      # TODO: ensure partition key is distributed over shards
      @buffer << {data: data_blob, partition_key: Px::Service::Kinesis.config.partition_key}

      # check if we should flush the buffer
      if (put_rate_decay == DEFAULT_PUT_RATE && @buffer.length > FLUSH_LENGTH) || (Time.now - @last_send > put_rate_decay) || @test
        response = @kinesis.put_records(:stream_name => stream, :records => @buffer)

        # iterate over response and
        # back append everything that didn't send
        #
        # TODO: detect which shard is being limited
        # - decay that shard's partition_key
        # - split shards when we really need to

        tmp_buffer = []
        if response[:failed_record_count] > 0
          response[:records].each do |index, r|
            if r[:error_code] == Aws::Kinesis::Errors::ProvisionedThroughputExceededException
              # set last throughput limited value
              @last_throughput_exceeded = Time.now
            end
            tmp_buffer << @buffer[index]
          end
        end

        @buffer = tmp_buffer
        @last_send = Time.now
      end

      return @buffer.length
    end

    # push a single record to kinesis, bypass the buffer
    def put_record(stream, data)
      return unless data

      data_blob = @jencoder.encode(data).to_msgpack
      r = @kinesis.put_record(:stream_name => stream,
                                :data => data_blob,
                                :partion_key => Px::Service::Kinesis.config.partition_key)
    end

    private

    # tune this function for handling throughput exceptions
    #  decay linearly based on when last throughput failure happend
    def put_rate_decay
      return DEFAULT_PUT_RATE unless @last_throughput_exceeded != -1

      DEFAULT_PUT_RATE * (1 + (10 / (Time.now - @last_throughput_exceeded)))
    end

  end
end
