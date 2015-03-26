require 'spec_helper'

describe Px::Service::Kinesis::BaseRequest do

  subject { Px::Service::Kinesis::BaseRequest.new.tap { |s| s.stream = "test" } }
  let (:default_put_rate) { Px::Service::Kinesis::BaseRequest::DEFAULT_PUT_RATE }
  let (:data) { {datakey: "value"} }

  before :each  do
    Timecop.freeze
    stub_const("Px::Service::Kinesis::BaseRequest::FLUSH_LENGTH", 5)
  end

  describe '#queue_record' do
    it "returns incremented buffer count" do
      subject.queue_record(data)

      expect(subject.buffer.size).to eq(1)
    end

    context "when enough time has elapsed" do
      before :each do
        subject

        Timecop.travel(15.seconds.from_now)
        Timecop.freeze
      end

      it "sets the last send time" do
        subject.queue_record(data)

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

          subject.queue_record(data)
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
          expect(subject.buffer.size).to eq(1)
        end
      end
    end

    context "with no throughput limit" do
      context "when enough time as elapsed" do
        before :each do
          subject

          Timecop.travel(10.seconds.from_now)
        end

        it "flushes" do
          expect {
            subject.queue_record(data)
          }.not_to change{ subject.buffer.size }
        end
      end

      context "when the buffer flush size is reached" do
        it "flushes" do
          expect {
            8.times do
              subject.queue_record(data)
            end
          }.to change{ subject.buffer.size }.from(0).to(3)
          # started with 0, inserted 8, flushed 5 -> left with 3
        end
      end
    end

    context "with limited throughput" do
      before :each do
        subject.instance_variable_set(:@last_throughput_exceeded, Time.now)
      end

      context "when buffer is full" do
        before :each do
          Timecop.travel( default_put_rate.seconds.from_now )
        end

        it "does not flush" do
          expect {
            8.times do
              subject.queue_record(data)
            end
          }.to change { subject.buffer.size }.from(0).to(8)
        end
      end

      context "when flush time has elapsed" do
        before :each do
          Timecop.travel( default_put_rate.seconds.from_now )
        end

        it "does not flush" do
          expect {
            subject.queue_record(data)
          }.to change{ subject.buffer.size }.from(0).to(1)
        end
      end

      context "when the decay time has elapsed" do
        before :each do
          Timecop.travel( subject.send(:put_rate_decay).seconds.from_now )
        end

        it "flushes after decayed rate" do
          expect {
            subject.queue_record(data)
          }.not_to change { subject.buffer.size }
        end
      end
    end
  end

  describe '#put_record' do
    context "when tripping circuit breaker" do
      before :each do
        subject.kinesis.stub_responses(
          :put_record,
          Seahorse::Client::NetworkingError.new(Exception.new("test error"))
        )
      end

      it "expects request to error" do
        expect{
          subject.put_record(data)
        }.to raise_error(Px::Service::ServiceError)
      end

      it "increments failure count 5 times" do
        expect {
          5.times do
            subject.put_record(data) rescue nil
          end
        }.to change{subject.circuit_state.failure_count}.from(0).to(5)
      end

      it "trips circuit breaker after threshold" do
        expect {
          6.times do
            subject.put_record(data) rescue nil
          end
        }.to change{subject.circuit_state.aasm.current_state}.from(:closed).to(:open)
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
