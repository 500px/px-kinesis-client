require "spec_helper"

describe Px::Service::Kinesis do
  describe "config" do

    context "when config block is given" do
      subject { Px::Service::Kinesis }
      before :each do
        subject.configure do |config|
          config.region = "some-region-1"
          config.shard_count = 10
        end
      end

      it "sets given region" do
        expect(subject.config.region).to eq("some-region-1")
      end

      it "sets given shard count" do
        expect(subject.config.shard_count).to eq(10)
      end
    end

  end
end
