module Px
  module Service
    module Kinesis
      class << self
        DefaultConfig = Struct.new(:region, :shard_count, :partition_key, :logger) do
          def initialize
            self.region = AWS_DEFAULT_REGION
            self.shard_count = DEFAULT_SHARD_COUNT
            self.partition_key = BASE_PARTITION_KEY
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
      end
    end
  end
end
