module Px
  module Service
    module Kinesis
      class << self
        DefaultConfig = Struct.new(:region, :credentials, :shard_count, :redis, :dev_mode, :dev_queue_key, :logger, :max_buffer_length) do
          def initialize
            self.region = AWS_DEFAULT_REGION
            self.shard_count = DEFAULT_SHARD_COUNT
            self.credentials = Aws::SharedCredentials.new
            self.dev_mode = false
            self.dev_queue_key = nil
            self.redis = nil

            # Maximum length of buffer before flushing.
            self.max_buffer_length = 200
          end
        end

        def configure
          @config ||= DefaultConfig.new
          yield(@config) if block_given?
          @config
        end

        def config
          @config || configure
        end

        def partition_key(data_blob)
          Digest::MD5.hexdigest(data_blob)
        end
      end
    end
  end
end
