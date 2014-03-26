# -*- encoding: utf-8 -*-
require_relative '../spec_helper'

describe Razor::Validation::HashSchema do
  subject(:schema) { Razor::Validation::HashSchema.new("test") }

  context "finalize" do
    it "should fail if an authz dependency is not defined as an attribute" do
      schema.authz('%{fail}')
      expect { schema.finalize }.to raise_error(/authz pattern references fail/)
    end

    it "should fail if require_one_of specifies an attribute that does not exist" do
      schema.require_one_of('a')
      expect { schema.finalize }.to raise_error(/require_one_of a references a/)
    end

    it "should fail if there are multiple require_one_of's but only one is wrong" do
      schema.require_one_of('good', 'fast')
      schema.require_one_of('fast', 'cheap')
      schema.require_one_of('good', 'cheap')
      schema.require_one_of('good', 'fast', 'cheep') # note type in 'cheep'
      schema.attr('good', {})
      schema.attr('fast', {})
      schema.attr('cheap', {})
      expect { schema.finalize }.to raise_error(/require_one_of cheep, fast, good references cheep/)
    end

    it "should fail if an unknown attribute is excluded" do
      schema.attr('good', exclude: 'bad')
      expect { schema.finalize }.
        to raise_error(/excluded attribute bad by good is not defined in the schema/)
    end

    it "should fail if an unknown attribute is 'also' required" do
      schema.attr('good', also: 'bad')
      expect { schema.finalize }.
        to raise_error(/additionally required attribute bad by good is not defined in the schema/)
    end
  end

  context "authz" do
    it "should fail if not given a string" do
      expect { schema.authz(['big-fail']) }.
        to raise_error(/the authz pattern must be a string/)
    end

    it "should fail if an invalid substitution is given" do
      expect { schema.authz('%{big-fail}') }.
        to raise_error(/authz pattern substitution "%{big-fail}" is invalid/)
    end

    it "should fail if an empty string is given" do
      expect { schema.authz('') }.
        to raise_error(/the authz pattern must not be empty/)
    end

    it "should fail if whitespace is included" do
      expect { schema.authz('big bad wolf') }.
        to raise_error(/the authz pattern must contain only a-z/)
    end
  end

  context "require_one_of" do
    it "should fail if given a non-string" do
      expect { schema.require_one_of(:fail) }.
        to raise_error(/required_one_of must be given a set of string attribute names/)
    end

    it "should fail if given a non-string among strings" do
      expect { schema.require_one_of('good', :fail, 'bad') }.
        to raise_error(/required_one_of must be given a set of string attribute names/)
    end

    it "should fail if given duplicate attribute names" do
      expect { schema.require_one_of('good', 'bad', 'cheap', 'fast', 'cheap', 'bad') }.
        to raise_error(/required_one_of good, bad, cheap, fast, cheap, bad includes duplicate elements cheap, bad/)
    end
  end

  context "validate!" do
    [[], 1, 1.1, ""].each do |input|
      it "should fail if the data is an #{input.class}" do
        expect { schema.validate!(input) }.
          to raise_error(/expected object but got/)
      end
    end

    context "authz validation" do
      before :each do
        # Set up our schema, ready to test what we need.
        schema.attr('before', required: true)
        schema.attr('after',  required: true)
        schema.authz('%{before}')
        schema.finalize
      end

      def with_auth(user, pass)
        begin
          context = org.apache.shiro.subject.support.DefaultSubjectContext.new
          subject = Razor.security_manager.create_subject(context)
          token   = org.apache.shiro.authc.UsernamePasswordToken.new(user, pass)
          subject.login(token) rescue nil
          state   = org.apache.shiro.subject.support.SubjectThreadState.new(subject)
          state.bind
          yield
        ensure
          state.restore
        end
      end

      it "should fail an invalid authz dependency before authz checking" do
        with_auth('jane', 'jungle') do
          expect { schema.validate!('after' => true) }.
            to raise_error(/required attribute before is missing/)
        end
      end

      it "should fail an invalid login before checking non-authz-dep attributes" do
        with_auth('jane', 'jungle') do
          expect { schema.validate!('before' => true) }.
            to raise_error(org.apache.shiro.authz.UnauthenticatedException)
        end
      end

      it "should fail non-authz-dep attributes if the login works" do
        with_auth('fred', 'dead') do
          expect { schema.validate!('before' => true) }.
            to raise_error(/required attribute after is missing/)
        end
      end
    end

    context "require_one_of" do
      before :each do
        Razor.config['auth.enabled'] = false

        schema.require_one_of('a', 'b', 'c')
        schema.attr('a', {})
        schema.attr('b', {})
        schema.attr('c', {})
        schema.finalize
      end

      it "should fail if none of the attributes are supplied" do
        expect { schema.validate!({}) }.
          to raise_error(/one of a, b, c must be supplied/)
      end

      it "should fail if two of the attributes are supplied" do
        expect { schema.validate!({'a' => 1, 'b' => 2}) }.
          to raise_error(/only one of a, b must be supplied/)
        expect { schema.validate!({'a' => 1, 'c' => 3}) }.
          to raise_error(/only one of a, c must be supplied/)
        expect { schema.validate!({'b' => 2, 'c' => 3}) }.
          to raise_error(/only one of b, c must be supplied/)
      end

      it "should fail if all three of the attributes are supplied" do
        expect { schema.validate!({'a' => 1, 'b' => 2, 'c' => 3}) }.
          to raise_error(/only one of a, b, c must be supplied/)
      end
    end

    context "extra attributes" do
      before :each do
        Razor.config['auth.enabled'] = false
      end

      it "should fail if one extra attribute is present" do
        expect { schema.validate!({'a' => 1}) }.
          to raise_error(/extra attribute a was present, but is not allowed/)
      end

      it "should fail if two extra attributes are present" do
        expect { schema.validate!({'a' => 1, 'b' => 2}) }.
          to raise_error(/extra attributes a, b were present, but are not allowed/)
      end

      it "should fail if three extra attributes are present" do
        expect { schema.validate!({'a' => 1, 'b' => 2, 'c' => 3}) }.
          to raise_error(/extra attributes a, b, c were present, but are not allowed/)
      end
    end
  end
end
