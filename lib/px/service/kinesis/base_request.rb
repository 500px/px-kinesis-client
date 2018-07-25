require "digest"
require 'redis'
require 'msgpack'
require 'aws-sdk'
require 'px-service-legacy-client'
require 'circuit_breaker'

module Px::Service::Kinesis
  class BaseRequest
    include Px::Service::Legacy::Client::CircuitBreaker

    DEFAULT_PUT_RATE = 0.25
    MAX_QUEUE_LENGTH = 1000

    attr_accessor :stream, :credentials
    attr_reader :kinesis, :buffer

    # Circuit breaker configuration
    circuit_handler do |handler|
      handler.logger = nil # Or the configured logger
      handler.failure_threshold = 5
      handler.failure_timeout = 7
      handler.invocation_timeout = 10
      handler.excluded_exceptions = [Px::Service::ServiceRequestError]
    end

    def initialize
      @kinesis = Aws::Kinesis::Client.new(credentials: (@credentials || Px::Service::Kinesis.config.credentials), region: Px::Service::Kinesis.config.region)
      @redis = Px::Service::Kinesis.config.redis
      @dev_queue_key = Px::Service::Kinesis.config.dev_queue_key
      # TODO: by default partition key can be combination
      # of hostname and other factors to ensure even
      # distribution over shards.
      #
      # Current design is per machine per shard per partition key
      @last_send = Time.now
      @last_throughput_exceeded = nil

      @buffer = []
      @semaphore = Mutex.new
    end

    ##
    # Check if buffer should be flushed and sent to kinesis
    def flush_records
      # clear out nil value in buffer
      # TODO: fix and figure out why this is happening
      #
      @buffer = @buffer.compact
      if @buffer.present? && can_flush?
        if Px::Service::Kinesis.config.dev_mode && @redis && @dev_queue_key
          # push directly to redis queue if in dev
          @buffer.each do |a|
            @redis.zadd(@dev_queue_key, Time.now.to_f, a[:data])
            @redis.zremrangebyrank(@dev_queue_key, 0, -MAX_QUEUE_LENGTH - 1)
          end
          @buffer = []
        else
          response = @kinesis.put_records(stream_name: @stream, records: @buffer)

          # iterate over response and
          # back append everything that didn't send
          #
          # TODO: detect which shard is being limited
          # - decay that shard's partition_key
          # - split shards when we really need to

          tmp_buffer = []
          if response[:failed_record_count] > 0
            response[:records].each_with_index do |r, index|
              next unless r.error_code

              if r.error_code == Aws::Kinesis::Errors::ProvisionedThroughputExceededException.code
                # set last throughput limited value
                @last_throughput_exceeded = Time.now
              end
              tmp_buffer << @buffer[index]
            end
          end

          @buffer = tmp_buffer
        end
        @last_send = Time.now
      end
    end
    circuit_method :flush_records

    ##
    # Takes a blob of data to send to Kinesis.
    # The data will be msgpacked and queued for send.
    #
    # Returns the number of unsent messages
    def queue_record(data)
      @semaphore.synchronize do
        data_blob = data.to_msgpack
        partition_key = data[:partition_key] || Px::Service::Kinesis.partition_key(data_blob)

        @buffer << { data: data_blob, partition_key: partition_key }

        # Check if we should flush the buffer.
        flush_records

        @buffer.size
      end
    end

    # push a single record to kinesis, bypass the buffer
    #
    # Please don't use unless necessary.
    # Mainly used to bypass buffering when testing
    def put_record(data)
      return unless data

      data_blob = data.to_msgpack
      @kinesis.put_record(stream_name: @stream,
                          data: data_blob,
                          partition_key: Px::Service::Kinesis.partition_key(data_blob))
    end
    circuit_method :put_record

    ##
    # Returns true if the buffered messages can be flushed
    def can_flush?
      (Time.now - @last_send).to_f > put_rate_decay || @buffer.size >= Px::Service::Kinesis.config.max_buffer_length
    end

    private

    # tune this function for handling throughput exceptions
    #  decay linearly based on when last throughput failure happend
    def put_rate_decay
      return DEFAULT_PUT_RATE unless @last_throughput_exceeded && (Time.now - @last_throughput_exceeded) < 10
      DEFAULT_PUT_RATE * (2 - ((Time.now - @last_throughput_exceeded) / 10))
    end
  end
end
