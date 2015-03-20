require 'spec_helper'

describe Px::Service::Kinesis::BaseRequest do

  before(:each) do 
    Timecop.freeze
    stub_const("Px::Service::Kinesis::BaseRequest::FLUSH_LENGTH", 5)
  end
  subject { Px::Service::Kinesis::BaseRequest.new }
  let (:default_put_rate) { Px::Service::Kinesis::BaseRequest::DEFAULT_PUT_RATE }
  
  describe '#push_records' do
    
    context "when pushing data into buffer" do
      let(:data) { {datakey: "value"} }
      let(:stream) { "activity" }
      before :each do
        subject.push_records(stream, data)
      end

      it "returns incremented buffer count" do
        expect(subject.instance_variable_get(:@buffer).length).to eq(1)
      end

      it "sets last send time" do
        Timecop.travel(15.seconds.from_now)
        Timecop.freeze
        subject.flush_records(stream)
        expect(
          subject.instance_variable_get(:@last_send)
        ).to eq(Time.now)
      end

      context "with throughput limit response" do
        before :each do
          subject.kinesis.stub_responses(
            :put_records,
            {
              failed_record_count: 1,
              records: [
                {
                  error_code: Aws::Kinesis::Errors::ProvisionedThroughputExceededException.code
                }
              ]
            }
          )
          Timecop.travel(15.seconds.from_now)
          Timecop.freeze
          subject.flush_records(stream)
        end

        it "sets last throughput exceeded field" do
          expect(
            subject.instance_variable_get(:@last_throughput_exceeded)
          ).to eq(Time.now)
        end

        it "returns put rate of 2x the default value" do
          expect(subject.send(:put_rate_decay)).to eq( default_put_rate * 2 )
        end

        it "pushes unsent records back on to the buffer" do
          expect(subject.instance_variable_get(:@buffer).length).to eq(1)
        end
      end

      context "no throughput limit" do
      
        it "flushes after default put rate" do
          expect{
            Timecop.travel(10.seconds.from_now) 
            subject.flush_records(stream)
          }.to change{ subject.instance_variable_get(:@buffer).length }.from(1).to(0)
        end

        it "flushes after reaching the flush length" do
          expect {
            8.times do
              subject.push_records(stream, data)
            end
          }.to change{ subject.instance_variable_get(:@buffer).length }.from(1).to(4)
          # started with 1, inserted 8 = 9 total, flushed 5 -> left with 4
        end
      end

      context "with limited throughput" do
        before :each do
          subject.instance_variable_set(:@last_throughput_exceeded, Time.now)
        end

        it "does not flush after flush length" do
          expect {
            Timecop.travel( default_put_rate.seconds.from_now )
            8.times do
              subject.push_records(stream, data)
            end
          }.to change { subject.instance_variable_get(:@buffer).length }.from(1).to(9)
        end

        it "does not flush after default rate" do
          Timecop.travel( default_put_rate.seconds.from_now )
          expect {
            subject.flush_records(stream)
          }.not_to change{ subject.instance_variable_get(:@buffer).length }
        end

        it "flushes after decayed rate" do
          Timecop.travel( subject.send(:put_rate_decay).seconds.from_now )
          expect {
            subject.flush_records(stream)
          }.to change { subject.instance_variable_get(:@buffer).length }.from(1).to(0)
        end

      end

    end

  end

  describe '#put_rate_decay' do

    context "no last limited" do
      it "returns default put rate" do
        expect(subject.send(:put_rate_decay)).to eq( default_put_rate )
      end
    end

    context "when last limited" do

      context "was now" do
        it "returns put rate of 2x the default value" do
          subject.instance_variable_set(:@last_throughput_exceeded, Time.now)
          expect(subject.send(:put_rate_decay)).to eq( default_put_rate * 2 )
        end
      end

      context "5 seconds ago" do
        it "returns put rate of 1.5x the default value" do
          subject.instance_variable_set(:@last_throughput_exceeded, 5.seconds.ago)
          expect(subject.send(:put_rate_decay)).to eq( default_put_rate * 1.5 )
        end
      end

      context "10 seconds ago" do
        it "does not penelise the throughput" do
          subject.instance_variable_set(:@last_throughput_exceeded, 10.seconds.ago)
          expect(subject.send(:put_rate_decay)).to eq( default_put_rate )
        end
      end

      context "15 seconds ago" do
        it "does not penelise the throughput" do
          subject.instance_variable_set(:@last_throughput_exceeded, 15.seconds.ago)
          expect(subject.send(:put_rate_decay)).to eq( default_put_rate )
        end
      end

    end

  end

end
