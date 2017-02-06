# -*- encoding: utf-8 -*-
require_relative '../spec_helper'

describe Razor::Validation::HashAttribute do
  def attr
    Razor::Validation::HashAttribute
  end

  context "initialize" do
    it "should fail if the name is not a string" do
      expect { attr.new(:test, {}) }.
        to raise_error(/attribute name must be a string/)
    end

    ['Boom', 'bing bang', 'bro()'].each do |input|
      it "should fail if the name has illegal characters (#{input.inspect})" do
        expect { attr.new(input, {}) }.
          to raise_error(/attribute name is not valid/)
      end
    end

    [[], "required", :required].each do |input|
      it "should fail if checks are not a hash (#{input.inspect})" do
        expect { attr.new('test', input) }.
          to raise_error(/must be followed by a hash/)
      end
    end

    it "should fail if an unknown check is passed alone" do
      expect { attr.new('test', explode: true) }.
        to raise_error(/does not know how to perform a explode check/)
    end

    it "should fail if an unknown check is passed with valid checks" do
      expect { attr.new('test', required: true, explode: true) }.
        to raise_error(/does not know how to perform a explode check/)
    end
  end

  context "validate!" do
    subject(:attr) { Razor::Validation::HashAttribute.new('attr', {}) }

    it "should fail if the attribute is required but not present" do
      attr.required(true)
      expect { attr.validate!({}, nil) }.
        to raise_error(/attr is a required attribute, but it is not present/)
    end

    it "should return true if the attribute is not required and not present" do
      attr.required(false)
      attr.validate!({}, nil).should be_true
    end

    it "should fail if it excludes another attribute that is present" do
      attr.exclude('fail')
      expect { attr.validate!({'attr' => true, 'fail' => true}, nil) }.
        to raise_error(/if attr is present, fail must not be present/)
    end

    [{}, [], 1, 1.1, true, false, nil].each do |input|
      it "should fail if type is specified (String), and not matched (#{input.inspect})" do
        attr.type(String)
        expect { attr.validate!({'attr' => input}, nil) }.
          to raise_error(/attr should be a string, but was actually a .+/)
      end
    end

    it "should fail if the type is URI, and it has a bad URI passed" do
      attr.type(URI)
      expect { attr.validate!({'attr' => 'http://'}, nil) }.
        to raise_error(/bad URI/)
    end

    it "should fail if value's key is blank" do
      attr.type(Hash)
      expect { attr.validate!({'attr' => {'' => 'abc'}}, nil) }.
          to raise_error(/blank hash key/)
    end

    context "references" do
      let :node do Fabricate(:node) end
      # Necessary because of the magic in lookups.
      let :attr do Razor::Validation::HashAttribute.new('id', {}) end

      before :each do
        attr.references([Razor::Data::Node, :id])
        attr.required(true)
      end

      it "should default to using name as the reference" do
        attr.references(Razor::Data::Node)
        expect { attr.validate!({'id' => node.id}, nil) }.
            to raise_error(/id must be the name of an existing node, but is '#{node.id}'/)
      end

      it "should fail if the referenced instance does not exist" do
        expect { attr.validate!({'id' => node.id + 12}, nil) }.
          to raise_error(/id must be the id of an existing node, but is '#{node.id + 12}'/)
      end

      it "should have a 404 status on the error when the instance does not exist" do
        test_code_ran = false

        begin
          attr.validate!({'id' => node.id + 12}, nil)
        rescue Razor::ValidationFailure => e
          e.status.should == 404
          test_code_ran = true
        end

        # This is to catch the case where we fail to throw, so don't make the
        # assertion at all, and pass because nothing failed and rspec is "pass
        # unless something fails".
        test_code_ran.should be_true
      end

      it "should succeed if the referenced instance does exist" do
        attr.validate!({'id' => node.id}, nil).should be_true
      end

      context "help" do
        subject :text do attr.help end

        it "should use the friendly name of the reference type" do
          should =~ /an existing node\./
        end

        it "should identify which object slot must match" do
          should =~ /must match the id of an existing/
        end
      end
    end

    context "size" do
      context "strings" do
        before :each do
          attr.type(String)
          attr.size(2..4)
        end

        it "should reject an empty string" do
          expect { attr.validate!({'attr' => ''}, nil) }.
            to raise_error Razor::ValidationFailure, 'attr must be between 2 and 4 characters in length, but is 0 characters long'
        end

        it "should reject a short string" do
          expect { attr.validate!({'attr' => '1'}, nil) }.
            to raise_error Razor::ValidationFailure, 'attr must be between 2 and 4 characters in length, but is 1 character long'
        end

        it "should reject a long string" do
          expect { attr.validate!({'attr' => '12345'}, nil) }.
            to raise_error Razor::ValidationFailure, 'attr must be between 2 and 4 characters in length, but is 5 characters long'
        end

        it "should include the start of the range" do
          attr.validate!({'attr' => '12'}, nil).should be_true
        end

        it "should include the end of the range" do
          attr.validate!({'attr' => '1234'}, nil).should be_true
        end

        it "should work in unicode characters, not bytes" do
          expect { attr.validate!({'attr' => "\u{2603}"}, nil) }.to raise_error Razor::ValidationFailure, 'attr must be between 2 and 4 characters in length, but is 1 character long'
          expect { attr.validate!({'attr' => "\u{2603}\u{2603}\u{2603}\u{2603}\u{2603}"}, nil)  }.to raise_error Razor::ValidationFailure, 'attr must be between 2 and 4 characters in length, but is 5 characters long'

          attr.validate!({'attr' => "\u{2603}\u{2603}"}, nil).should be_true
          attr.validate!({'attr' => "\u{2603}\u{2603}\u{2603}\u{2603}"}, nil).should be_true
        end

        context "help" do
          subject :text do attr.help end

          it "should identify the actual size required" do
            should =~ /It must be between 2 and 4 in length./
          end
        end
      end

      context "arrays" do
        before :each do
          attr.type(Array)
          attr.size(2..4)
        end

        it "should reject an empty array" do
          expect { attr.validate!({'attr' => []}, nil) }.
            to raise_error Razor::ValidationFailure, 'attr must have between 2 and 4 entries, but actually contains 0'
        end

        it "should reject a short array" do
          expect { attr.validate!({'attr' => [1]}, nil) }.
            to raise_error Razor::ValidationFailure, 'attr must have between 2 and 4 entries, but actually contains 1'
        end

        it "should reject a long array" do
          expect { attr.validate!({'attr' => %w[1 2 3 4 5]}, nil) }.
            to raise_error Razor::ValidationFailure, 'attr must have between 2 and 4 entries, but actually contains 5'
        end

        context "help" do
          subject :text do attr.help end

          it "should identify the actual size required" do
            should =~ /It must be between 2 and 4 in length./
          end
        end
      end

      context "objects (maps)" do
        before :each do
          attr.type(Hash)
          attr.size(2..4)
        end

        it "should reject an empty object" do
          expect { attr.validate!({'attr' => {}}, nil) }.
            to raise_error Razor::ValidationFailure, 'attr must have between 2 and 4 entries, but actually contains 0'
        end

        it "should reject a short object" do
          expect { attr.validate!({'attr' => {'one' => 1}}, nil) }.
            to raise_error Razor::ValidationFailure, 'attr must have between 2 and 4 entries, but actually contains 1'
        end

        it "should reject a long object" do
          data = {'one' => 1, 'two' => 2, 'three' => 3, 'four' => 4, 'five' => 5}
          expect { attr.validate!({'attr' => data}, nil) }.
            to raise_error Razor::ValidationFailure, 'attr must have between 2 and 4 entries, but actually contains 5'
        end

        context "help" do
          subject :text do attr.help end

          it "should identify the actual size required" do
            should =~ /It must be between 2 and 4 in length./
          end
        end
      end
    end
  end

  context "type" do
    subject(:attr) { Razor::Validation::HashAttribute.new('attr', {}) }

    ["String", true, false, 1, 1.1, :string].each do |input|
      it "should fail unless the type is a class or module (#{input.inspect})" do
        expect { attr.type(input) }.
          to raise_error(/type checks must be passed a class, module, or nil/)
      end
    end

    [[], {}].each do |input|
      it "should fail if given an empty collection (#{input.inspect})" do
        expect { attr.type(input) }.
          to raise_error(/type checks must be passed a class, module, or nil/)
      end
    end

    it "should allow nil" do
      attr.type(nil)[:type].should == NilClass
    end

    context "help" do
      subject :text do attr.help end

      {
        String  => 'string',
        Array   => 'array',
        Hash    => 'object',
        :bool   => 'boolean',
        Integer => 'number'
      }.each do |type, expect|
        it "should correctly report #{type} expectations" do
          attr.type type
          should =~ /It must be of type #{expect}/
        end
      end
    end
  end

  context "exclude" do
    subject(:attr) { Razor::Validation::HashAttribute.new('attr', {}) }

    it "should accept a string" do
      expect { attr.exclude('test') }.not_to raise_error
    end

    it "should accept an array of strings" do
      expect { attr.exclude(%w{test fun bang}) }.not_to raise_error
    end

    [:symbol, {:foo => 1}, 1, true, false, nil].each do |input|
      it "should fail if the argument is not a string or array (#{input.inspect})" do
        expect { attr.exclude(input) }.
          to raise_error(/attribute exclusions must be a string, or an array of strings/)
      end
      it "should fail if the argument is an array, and contains a non-string (#{input.inspect}" do
        expect { attr.exclude(['good', input, 'boom']) }.
          to raise_error(/attribute exclusions must be a string, or an array of strings/)
      end
    end

    context "help" do
      subject :text do attr.help end

      it "should document the exclusions" do
        attr.exclude('test')
        should =~ /If present, test must not be present./
      end
    end
  end

  context "references" do
    subject(:attr) { Razor::Validation::HashAttribute.new('attr', {}) }

    [[], Object, URI, String].each do |input|
      it "should fail if the argument is not a Sequel::Model #{input.inspect}" do
        expect { attr.references(input) }.
          to raise_error(/attribute references must be a class that respond to find/)
      end
    end

    it "should accept a Sequel::Model derived class" do
      expect { attr.references(Razor::Data::Node) }.not_to raise_error
    end

    context "help" do
      subject :text do attr.help end

      it "should document the thing that is referenced" do
        attr.references(Razor::Data::Node)
        should =~ /It must match the name of an existing node./
      end

      it "should document the slot of the referenced object" do
        attr.references([Razor::Data::Node, :example])
        should =~ /It must match the example of an existing node./
      end
    end
  end

  context "size" do
    let(:schema) do
      Razor::Validation::HashSchema.new('test').tap do |schema|
        schema.attr('attr', help: 'foo')
      end
    end

    subject(:attr) { schema.attribute('attr') }

    it "should fail if no type is required" do
      expect do
        attr.size(1..10)
        attr.finalize(schema)
      end.to raise_error "a type, from String, Hash, or Array, must be specified if you want to check the size of the attr attribute"
    end

    [String, Array, Hash].each do |type|
      it "should work with type #{type}" do
        expect do
          attr.type(type)
          attr.size(1..10)
          attr.finalize(schema)
        end.not_to raise_error
      end

      context "help" do
        it "should document the required size" do
          attr.type(type)
          attr.size(1..10)
          attr.finalize(schema)
          attr.help.should =~ /It must be between 1 and 10 in length./
        end
      end
    end

    [Numeric, Float, :bool].each do |type|
      it "should fail with type #{type}" do
        expect do
          attr.type(type)
          attr.size(1..10)
          attr.finalize(schema)
        end.to raise_error "a type, from String, Hash, or Array, must be specified if you want to check the size of the attr attribute"
      end
    end
  end

  context "help with nested schema" do
    it "should include documentation from a nested object" do
      child = Razor::Validation::HashSchema.new('test')
      child.attr 'name', type: String, required: true

      attr.new('test', required: true, schema: child).help.
        should =~ %r~#{Regexp.escape(child.help.gsub(/^/, '   ').rstrip)}~
    end

    it "should include documentation from a nested array" do
      child = Razor::Validation::ArraySchema.new('test')
      child.elements type: String

      attr.new('test', required: true, schema: child).help.
        should =~ %r~#{Regexp.escape(child.help.gsub(/^/, '  ').rstrip)}~
    end
  end

  context "alias" do
    let(:schema) do
      Razor::Validation::HashSchema.new('test').tap do |schema|
        schema.attr('attr', help: 'foo')
      end
    end

    subject(:attr) { schema.attribute('attr') }

    [true, false, 1, 1.1, :string, [1, 2]].each do |input|
      it "should fail unless the alias is a string or array of strings (#{input.inspect})" do
        expect { attr.alias(input) }.
            to raise_error(ArgumentError, /alias must be a string or array of strings \(got .+\)/)
      end
    end

    ['abc', ['abc', 'def']].each do |input|
      it "should work with alias #{input}" do
        expect do
          attr.alias(input)
          attr.finalize(schema)
        end.not_to raise_error
      end
    end
  end

  context "position" do
    let(:schema) do
      Razor::Validation::HashSchema.new('test').tap do |schema|
        schema.attr('attr', help: 'foo')
      end
    end

    subject(:attr) { schema.attribute('attr') }

    [true, false, 'abc', 1.1, -1, :string, [1, 2], {1 => 2}].each do |input|
      it "should fail unless the position is a natural number (#{input.inspect})" do
        expect { attr.position(input) }.
            to raise_error(ArgumentError, /position must be an integer greater than or equal to 0/)
      end
    end

    it "should work with position 0" do
      expect do
        attr.position(0)
        attr.finalize(schema)
      end.not_to raise_error
    end
  end
end
