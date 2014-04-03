# -*- encoding: utf-8 -*-
require_relative "../spec_helper"

describe Razor::Data::Policy do

  before(:each) do
    use_task_fixtures
    @node = Fabricate(:node, :hw_hash => { "mac" => ["abc"] },
                      :facts => { "f1" => "a" })
    @tag = Tag.create(:name => "t1", :matcher => Razor::Matcher.new(["=", ["fact", "f1"], "a"]))
    @repo = Fabricate(:repo)
  end

  it "binds to a matching node" do
    pl = Fabricate(:policy, :repo => @repo)
    pl.add_tag(@tag)
    pl.save
    @node.add_tag(@tag)

    Policy.bind(@node)
    @node.policy.should == pl
    @node.log.last["event"].should == "bind"
    @node.log.last["policy"].should == pl.name
  end

  it "does not save a policy if the named task does not exist" do
    pl = Fabricate(:policy, :repo => @repo)
    expect do
      pl.task_name = "no such task"
      pl.save
    end.to raise_error(Sequel::ValidationFailed)
  end

  it "prefers policy task to repo task" do
    repo_with_task = Fabricate(:repo, :task_name => 'some_os')
    pl = Fabricate(:policy, :repo => repo_with_task, :task_name => 'microkernel')
    pl.task.name.should == 'microkernel'
  end

  it "defaults to repo task" do
    repo_with_task = Fabricate(:repo, :task_name => 'some_os')
    pl = Fabricate(:policy, :repo => repo_with_task, :task_name => nil)
    pl.task.name.should == 'some_os'
  end

  describe "max_count" do
    it "binds if there is room" do
      pl = Fabricate(:policy, :repo => @repo, :max_count => 1)
      pl.add_tag(@tag)
      pl.save
      @node.add_tag(@tag)

      Policy.bind(@node)
      @node.policy.should == pl
    end

    it "does not bind if there is no room" do
      pl = Fabricate(:policy, :repo => @repo, :max_count => 0)
      pl.add_tag(@tag)
      pl.save
      Policy.bind(@node)
      @node.policy.should be_nil
    end

    # It would be nice to test that we do not exceed max_count bindings in
    # racy situations, but I don't see a good way to do that without
    # modifying Policy.bind in a way that let's us inject the race reliably
  end

  it "does not bind disabled policy" do
    pl = Fabricate(:policy, :repo => @repo, :enabled => false)
    pl.add_tag(@tag)
    pl.save
    Policy.bind(@node)
    @node.policy.should be_nil
  end

  context "ordering" do
    let :p1 do Fabricate(:policy, :rule_number => 1).save end
    let :p2 do Fabricate(:policy, :rule_number => 2).save end

    def check_move(where, other, list)
      p  = Fabricate(:policy)
      if where
        p.move(where, other)
        p.save
      end

      list = list.map { |x| x == :_ ? p.id : x.id }
      Policy.all.map { |p| p.id }.should == list
    end

    it "moves existing policy to the end" do
      p1.move('after', p2)
      Policy.all.map { |p| p.id }.should == [ p2.id, p1.id ]
    end

    it "creates policies at the end of the list" do
      check_move(nil, nil, [p1, p2, :_])
    end

    describe 'before' do
      it "p1 creates at the head of the table" do
        check_move('before', p1, [:_, p1, p2])
      end

      it "p2 goes between p1 and p2" do
        check_move('before', p2, [p1, :_, p2])
      end

      it "should not change anything if the policy is already before the other" do
        p1.move('before', p2)
        Policy.order(:rule_number).all.should == [p1, p2]
      end

      it "should be stable if moved to first place" do
        p1, p2, p3, p4, p5 = (1..5).map {|n| Fabricate(:policy, :rule_number => n).save }
        p5.move('before', p1).save
        Policy[p5.id].rule_number.should be < Policy[p1.id].rule_number
        before = Policy[p5.id].rule_number
        p5.move('before', p1).save
        Policy[p5.id].rule_number.should be < Policy[p1.id].rule_number
        Policy.all.all? do |p|
          p.id == p5.id or p.rule_number.should be > Policy[p5.id].rule_number
        end
        Policy[p5.id].rule_number.should == before
      end

      it "fails if the policy moves relative to itself" do
        expect { p1.move('before', p1) }.
          to raise_error ArgumentError, /relative to itself/
      end
    end

    describe "after" do
      it "p1 goes between p1 and p2" do
        check_move('after', p1, [p1, :_, p2])
      end

      it "p2 goes to the end of the table" do
        check_move('after', p2, [p1, p2, :_])
      end

      it "should be stable if moved into the middle" do
        p1, p2, p3, p4, p5 = (1..5).map {|n| Fabricate(:policy, :rule_number => n).save }
        p1.move('after', p3).save
        Policy[p3.id].rule_number.should be < Policy[p1.id].rule_number
        before = Policy[p1.id].rule_number
        p1.move('after', p3).save
        Policy[p3.id].rule_number.should be < Policy[p1.id].rule_number
        Policy[p1.id].rule_number.should == before
      end

      it "should be stable if moved to the end" do
        p1, p2, p3, p4, p5 = (1..5).map {|n| Fabricate(:policy, :rule_number => n).save }
        p1.move('after', p5).save
        Policy[p5.id].rule_number.should be < Policy[p1.id].rule_number
        before = Policy[p1.id].rule_number
        p1.move('after', p5).save
        Policy[p5.id].rule_number.should be < Policy[p1.id].rule_number
        Policy[p1.id].rule_number.should == before
      end

      it "fails if the policy moves relative to itself" do
        expect { p1.move('after', p1) }.
          to raise_error ArgumentError, /relative to itself/
      end
    end
  end
end
