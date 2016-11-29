require "socket"
require "px/service/kinesis/config"

module Px
  module Service
    module Kinesis
      AWS_DEFAULT_REGION = "us-east-1" # http://docs.aws.amazon.com/general/latest/gr/rande.html#ak_region
      DEFAULT_SHARD_COUNT = 1
    end
  end
end

require "px/service/kinesis/version"
require "px/service/kinesis/base_request"
