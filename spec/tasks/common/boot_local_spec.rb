# -*- encoding: utf-8 -*-
require_relative '../../spec_helper'
require_relative '../../../app'

describe "tasks/common/boot_local" do
  include Rack::Test::Methods
  def app; Razor::App end

  # I am a tiny bit uncomfortable depending on the noop task as a way to say
  # "the boot_local template", but really, that is the defined purpose of the
  # task, so it should be safe, right?
  let :policy do Fabricate(:policy, task_name: 'noop') end

  let :node do
    Fabricate(:node).tap do |node|
      node.facts = {'is_virtual' => 'false', 'virtual' => 'physical'}
      node.bind(policy)
      node.save
    end
  end

  let :mac do node.hw_hash["mac"].first end

  subject :boot_local do
    get "/svc/boot?net0=#{mac}"
    last_response.status.should == 200
    last_response.body
  end

  it "should not use (or mention) sanboot by default" do
    boot_local.should_not =~ /sanboot/
  end

  %w{parallels vmware virtualbox xenhvm xen0 xenu rhev ovirt hyperv}.each do |type|
    it "should use sanboot if the machine is a #{type} virtual machine" do
      node.set(facts: node.facts.merge('is_virtual' => 'true', 'virtual' => type)).save
      boot_local.should =~ /sanboot .* 0x80/
    end
  end

  it "should use sanboot if the `sanboot` metadata field is `true`" do
    node.set(metadata: {'sanboot' => true}).save
    boot_local.should =~ /sanboot .* 0x80/
  end
end
