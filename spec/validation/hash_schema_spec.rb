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

    it "should fail if the 'position' attributes do not start at 0" do
      schema.attr('good', help: 'foo', position: 1)
      expect { schema.finalize }.
          to raise_error(/positional argument indices should begin at 0 \(found 1\)/)
    end

    it "should fail if the 'position' attributes are not sequential" do
      schema.attr('good', help: 'foo', position: 0)
      schema.attr('ok', help: 'foo', position: 1)
      schema.attr('bad', help: 'foo', position: 3)
      expect { schema.finalize }.
          to raise_error(/positional argument indices should be sequential \(3 is present but 2 is absent\)/)
    end

    it "should fail if the 'position' attributes are not unique" do
      schema.attr('good', help: 'foo', position: 0)
      schema.attr('allowed', help: 'foo', position: 1)
      schema.attr('bad', help: 'foo', position: 1)
      expect { schema.finalize }.
          to raise_error(/positional argument indices should be unique/)
    end

    it "should succeed with several position attributes" do
      schema.attr('good', help: 'foo', position: 0)
      schema.attr('better', help: 'foo', position: 1)
      schema.attr('best', help: 'foo', position: 2)
      schema.finalize
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


  context "help" do
    subject :text do schema.help end

    context "with authz" do
      before :each do schema.authz '%{name}' end
      it "should include the authz header" do should =~ /^# Access Control$/ end
      it "should include the command name" do should =~ /:test:/ end
      it "should include the pattern"      do should =~ /%{name}/ end
      it "should explain substitution"     do
        should include 'Words surrounded by `%{...}` are substitutions'
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

    it "should not document attributes if there are none" do
      should_not =~ /# Attributes/
    end

    it "should document a single attribute" do
      schema.attr 'one', type: String, size: 1..Float::INFINITY
      should =~ /^# Attributes/
      should =~ / \* one/
      should =~ /#{Regexp.escape(schema.attribute('one').help)}/
    end

    it "should document multiple attributes" do
      schema.attr 'one', type: String, size: 1..Float::INFINITY
      schema.attr 'two', type: Array,  required: true
      should =~ /^# Attributes/
      should =~ / \* one/
      should =~ / \* two/
      should =~ /#{Regexp.escape(schema.attribute('one').help)}/
      should =~ /#{Regexp.escape(schema.attribute('two').help)}/
    end
  end

  context "validate!" do
    [[], 1, 1.1, ""].each do |input|
      it "should fail if the data is an #{input.class}" do
        expect { schema.validate!(input, nil) }.
          to raise_error(/the command should be an object, but got/)
      end
    end

    context "authz validation" do
      before :each do
        # Set up our schema, ready to test what we need.
        schema.attr('before', required: true, help: 'foo')
        schema.attr('after',  required: true, help: 'foo')
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
          expect { schema.validate!({'after' => true}, nil) }.
            to raise_error(/before is a required attribute, but it is not present/)
        end
      end

      it "should fail an invalid login before checking non-authz-dep attributes" do
        with_auth('jane', 'jungle') do
          expect { schema.validate!({'before' => true}, nil) }.
            to raise_error(org.apache.shiro.authz.UnauthenticatedException)
        end
      end

      it "should fail non-authz-dep attributes if the login works" do
        with_auth('fred', 'dead') do
          expect { schema.validate!({'before' => true}, nil) }.
            to raise_error(/after is a required attribute, but it is not present/)
        end
      end
    end

    context "require_one_of" do
      before :each do
        Razor.config['auth.enabled'] = false
        schema.authz 'none'

        schema.require_one_of('a', 'b', 'c')
        schema.attr('a', help: 'foo')
        schema.attr('b', help: 'foo')
        schema.attr('c', help: 'foo')
        schema.finalize
      end

      it "should fail if none of the attributes are supplied" do
        expect { schema.validate!({}, nil) }.
          to raise_error(/the command requires one out of the a, b, c attributes to be supplied/)
      end

      it "should fail if two of the attributes are supplied" do
        expect { schema.validate!({'a' => 1, 'b' => 2}, nil) }.
          to raise_error(/the command requires at most one of a, b to be supplied/)
        expect { schema.validate!({'a' => 1, 'c' => 3}, nil) }.
          to raise_error(/the command requires at most one of a, c to be supplied/)
        expect { schema.validate!({'b' => 2, 'c' => 3}, nil) }.
          to raise_error(/the command requires at most one of b, c to be supplied/)
      end

      it "should fail if all three of the attributes are supplied" do
        expect { schema.validate!({'a' => 1, 'b' => 2, 'c' => 3}, nil) }.
          to raise_error(/the command requires at most one of a, b, c to be supplied/)
      end
    end

    context "extra attributes" do
      before :each do
        Razor.config['auth.enabled'] = false
        schema.authz 'none'
      end

      it "should fail if one extra attribute is present" do
        expect { schema.validate!({'a' => 1}, nil) }.
          to raise_error(/extra attribute a was present in the command, but is not allowed/)
      end

      it "should fail if two extra attributes are present" do
        expect { schema.validate!({'a' => 1, 'b' => 2}, nil) }.
          to raise_error(/extra attributes a, b were present in the command, but are not allowed/)
      end

      it "should fail if three extra attributes are present" do
        expect { schema.validate!({'a' => 1, 'b' => 2, 'c' => 3}, nil) }.
          to raise_error(/extra attributes a, b, c were present in the command, but are not allowed/)
      end
    end

    context "aliases" do
      before :each do
        Razor.config['auth.enabled'] = false
        schema.authz 'none'
      end
      it "should apply an alias" do
        schema.attr('a', alias: 'b', required: true, help: 'foo')
        schema.finalize
        schema.validate!({'b' => 2}, nil)
      end
      it "should ignore alias if not matched" do
        schema.attr('a', alias: 'b', required: true, help: 'foo')
        schema.finalize
        schema.validate!({'a' => 2}, nil)
      end
      it "should throw an error if both are supplied" do
        schema.attr('a', alias: 'b', required: true, help: 'foo')
        schema.finalize
        expect { schema.validate!({'a' => 1, 'b' => 2}, nil) }.
          to raise_error(/cannot supply both a and b/)
      end
      it "should automatically apply aliases for underscores" do
        schema.attr('a_b_c', required: true, help: 'foo')
        schema.finalize
        schema.validate!({'a-b-c' => 2}, nil)
      end
    end
  end
end
