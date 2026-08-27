require "rails_helper"

RSpec.describe ApplicationJob do
  include ActiveJob::TestHelper

  class DeadlockOnceJob < ApplicationJob
    class_attribute :call_count, default: 0

    def perform
      self.class.call_count += 1
      raise ActiveRecord::Deadlocked, "simulated deadlock" if self.class.call_count == 1
    end
  end

  class AlwaysFailsJob < ApplicationJob
    def perform
      raise "a genuine bug, not a transient infra hiccup"
    end
  end

  after do
    DeadlockOnceJob.call_count = 0
  end

  it "retries a job that raises a transient error like ActiveRecord::Deadlocked instead of failing permanently" do
    perform_enqueued_jobs(only: DeadlockOnceJob) do
      DeadlockOnceJob.perform_later
    end

    expect(DeadlockOnceJob.call_count).to eq(2)
  end

  it "does not retry (or swallow) an unrelated error" do
    expect {
      AlwaysFailsJob.perform_now
    }.to raise_error(RuntimeError, "a genuine bug, not a transient infra hiccup")
  end
end
