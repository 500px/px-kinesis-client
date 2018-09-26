require "socket"
require "px/service/kinesis/config"

module Px
  module Service
    module Kinesis
      AWS_DEFAULT_REGION = "us-east-1" # http://docs.aws.amazon.com/general/latest/gr/rande.html#ak_region
      DEFAULT_SHARD_COUNT = 1
      DEFAULT_KINESIS_ENDPOINT = "https://kinesis.us-east-1.amazonaws.com"
      KINESIS_STREAM_NAME = "kinesis"
      REDIS_STREAM_NAME = "redis"
    end
  end
end

require "px/service/kinesis/version"
require "px/service/kinesis/base_request"
