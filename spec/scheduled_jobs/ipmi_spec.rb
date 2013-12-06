require 'spec_helper'

describe Razor::ScheduledJobs::IPMI do
  include TorqueBox::Injectors
  let :queue do fetch('/queues/razor/sequel-instance-messages') end

  let :ipmi do Razor::ScheduledJobs::IPMI.new end

  it "should do nothing of no nodes match" do
    queue.count.should == 0
    ipmi.run
    queue.count.should == 0
  end

  it "should skip nodes with no IPMI hostname" do
    Fabricate(:node)

    queue.count.should == 0
    ipmi.run
    queue.count.should == 0
  end

  it "should skip nodes that were recently checked" do
    Timecop.freeze do
      Fabricate(:node_with_ipmi, :last_known_power_state => true, :last_power_state_update_at => Time.now - 30)

      queue.count.should == 0
      ipmi.run
      queue.count.should == 0
    end
  end

  it "should check nodes that were not recently checked regardless of power state" do
    on      = Fabricate(:node_with_ipmi, :last_known_power_state => true, :last_power_state_update_at => Time.now - 600)
    off     = Fabricate(:node_with_ipmi, :last_known_power_state => false, :last_power_state_update_at => Time.now - 600)
    unknown = Fabricate(:node_with_ipmi, :last_known_power_state => nil, :last_power_state_update_at => Time.now - 600)

    Timecop.freeze do
      queue.count.should == 0
      ipmi.run
      queue.count.should == 3

      messages = queue.peek_at_all
      messages.each do |m|
        m[:body]['message'].should == 'update_power_state!'
        m[:body]['arguments'].should == []
      end
    end
  end

  it "should work in the face of all possible types of node" do
    Timecop.freeze do
      want = []
      want << Fabricate(:node_with_ipmi, :last_known_power_state => true, :last_power_state_update_at => Time.now - 600).pk_hash
      want << Fabricate(:node_with_ipmi, :last_known_power_state => false, :last_power_state_update_at => Time.now - 600).pk_hash
      want << Fabricate(:node_with_ipmi, :last_known_power_state => nil, :last_power_state_update_at => Time.now - 600).pk_hash

      Fabricate(:node_with_ipmi, :last_known_power_state => true, :last_power_state_update_at => Time.now - 30)
      Fabricate(:node)

      queue.should be_empty
      ipmi.run

      queue.count.should == 3
      sent = queue.peek_at_all.map {|m| m[:body]['instance'] }

      # This should always work reliably, I think.  If not we probably have to
      # sort or something equally nasty.
      sent.should == want
    end
  end
end
