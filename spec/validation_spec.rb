# -*- encoding: utf-8 -*-
require 'spec_helper'

describe Razor::Validation do
  subject :schema do
    Razor.config['auth.enabled'] = false
    Razor::Validation::HashSchema.new("test").tap do |schema|
      schema.authz 'none'
    end
  end

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

    context "to_s" do
      it "should only talk about authz only in the top level object" do
        schema.object 'node' do
          attr 'name', type: String
        end

        # This line should show up in *all* access control documentation;
        # hopefully it should count 0 if we change that text and fail to
        # change this, so that the developer responsible knows they have to do
        # something here, and changes this text to match the new authz text.
        schema.to_s.lines.grep(/This command's access control pattern/).count.should == 1
      end
    end
  end
end
