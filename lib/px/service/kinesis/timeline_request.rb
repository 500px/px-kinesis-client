
module Px::Service::Kinesis
  class TimelineRequest < BaseRequest

    def initialize
      self.stream = "activity"

      super
    end
    
    def self.test
      ## do nothing
    end

  end
end
