require_relative '../spec_helper'

describe Razor::View::Siren do
  Siren = Razor::View::Siren

  describe "::entity" do
    context "with only a class specified" do
      it "should have no other keys" do
        Siren.entity("class").keys.should =~ [:class]
      end
    end

    context "with non-nil but empty fields" do
      subject(:entity) { Siren.entity([], {}, [], [], []) }

      it {entity.keys.should =~ [:class, :properties, :entities, :actions, :links]}

      it {entity.each {|k,v| v.should_not be_nil; v.should be_empty} }
    end

    context "with nil entities, actions, and links" do
      subject(:entity) { Siren.entity("",{},[nil], [nil], [nil]) }

      it "should remove the nil ones" do
        entity[:entities].should be_empty
        entity[:actions].should be_empty
        entity[:links].should be_empty
      end
    end
  end

  describe "::action" do
    context "with only a name, title, url, and class specified" do
      subject(:action) { Siren.action("name","title","url","class")}

      it { action.keys.should =~ [:name, :title, :href, :class, :method]}
    end
  end
end
