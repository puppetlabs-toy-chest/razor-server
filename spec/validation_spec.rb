# -*- encoding: utf-8 -*-
require 'spec_helper'

describe Razor::Validation do
  subject(:schema) { Razor::Validation::HashSchema.new("test") }
  before :each do Razor.config['auth.enabled'] = false end

  context "nested elements" do
    it "object=>object" do
      schema.object('broker', required: true) do
        attr 'name', required: true
      end

      expect { schema.validate!({'broker' => {'nombre' => 'fred'}}, nil) }.
        to raise_error Razor::ValidationFailure, 'broker.name is a required attribute, but it is not present'
    end

    it "object=>object=>object" do
      schema.object('one', required: true) do
        object 'two', required: true do
          object 'three', required: true do
            attr 'four', required: true, type: String
          end
        end
      end

      expect { schema.validate!({'one' => {'two' => {'three' => {'four' => 5}}}}, nil) }.
        to raise_error Razor::ValidationFailure, 'one.two.three.four should be a string, but was actually a number'
    end

    it "array=>object" do
      schema.array('a', required: true) do
        object do
          attr 'b', required: true, type: String
        end
      end

      expect { schema.validate!({'a' => [{'b' => 1}]}, nil) }.
        to raise_error Razor::ValidationFailure, 'a[0].b should be a string, but was actually a number'

      expect { schema.validate!({'a' => [{'b' => '1'}, {'b' => 2}]}, nil) }.
        to raise_error Razor::ValidationFailure, 'a[1].b should be a string, but was actually a number'
    end

    it "array=>object=>array=>object" do
      schema.array('a', required: true) do
        object do
          array 'b', required: true do
            object do
              attr 'c', required: true
            end
          end
        end
      end

      data = {'a' => [{'b' => [{}]}]}
      expect { schema.validate!(data, nil) }.
        to raise_error Razor::ValidationFailure, 'a[0].b[0].c is a required attribute, but it is not present'
    end
  end

  context "to_s" do
    subject :text do schema.to_s end

    context "with authz" do
      before :each do schema.authz '%{name}' end
      it "should include the authz header" do should =~ /^# Access Control$/ end
      it "should include the command name" do should =~ /:test:/ end
      it "should include the pattern"      do should =~ /%{name}/ end
      it "should explain substitution"     do
        should include 'Words surrounded by `%{...}` are substitutions'
      end
    end

    it "should not explain substitution when no substitution is present" do
      schema.authz 'no-substitutions-accepted'
      should_not include 'Words surrounded by `%{...}` are substitutions'
    end

    it "should say authz if currently enabled, if it is" do
      Razor.config['auth.enabled'] = true
      should =~ /on this server security is currently enabled/
    end

    it "should say authz if currently disabled, if it is" do
      Razor.config['auth.enabled'] = false
      should =~ /on this server security is currently disabled/
    end
  end
end
