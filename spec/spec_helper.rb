require 'pry'
require 'timecop'

require 'aws-sdk'
Aws.config[:stub_responses] = true

require 'bundler/setup'
Bundler.setup

require 'px/service/kinesis'
