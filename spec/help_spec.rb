# -*- encoding: utf-8 -*-
require 'spec_helper'

describe Razor::Help do
  subject('help') do
    help = Class.new
    help.send('extend', Razor::Help)
    help
  end

  context "summary" do
    it "should return nil if no summary is set" do
      help.summary.should be_nil
    end

    it "should accept a summary value" do
      expect { help.summary('testing') }.not_to raise_error
    end

    it "should return the new summary value" do
      help.summary('test').should == 'test'
    end

    it "should retain the summary value" do
      help.summary('test')
      help.summary.should == 'test'
    end

    it "should fail if the summary contains a newline" do
      expect { help.summary("test\ncontent") }.
        to raise_error(/Command summaries should be a single line/)
    end
  end

  context "description" do
    it "should return nil if no description is set" do
      help.description.should be_nil
    end

    it "should accept a description value" do
      expect { help.description('testing') }.not_to raise_error
    end

    it "should return the new description value" do
      help.description('test').should == 'test'
    end

    it "should retain the description value" do
      help.description('test')
      help.description.should == 'test'
    end

    it "should work if the description contains a newline" do
      expect { help.description("test\ncontent") }.not_to raise_error
    end

    it "should strip indents" do
      help.description <<EOT
        This text is indented.
        We should see something strip that off.
EOT
      help.description.should =~ /^This text/
    end
  end

  context "example" do
    it "should return nil if no example is set" do
      help.example.should be_nil
    end

    it "should accept a example value" do
      expect { help.example('testing') }.not_to raise_error
    end

    it "should return the new example value" do
      help.example('test').should == 'test'
    end

    it "should retain the example value" do
      help.example('test')
      help.example.should == 'test'
    end

    it "should work if the example contains a newline" do
      expect { help.example("test\ncontent") }.not_to raise_error
    end

    it "should strip indents" do
      help.example <<EOT
        This text is indented.
        We should see something strip that off.
EOT
      help.example.should =~ /^This text/
    end
  end

  context "scrub" do
    extend Forwardable
    def_delegators 'described_class', 'scrub'

    it "should return nil if nil is passed in" do
      scrub(nil).should be_nil
    end

    it "should return a oneliner with whitespace stripped" do
      scrub("foo").should == "foo"
      scrub(" foo").should == "foo"
      scrub("foo ").should == "foo"
      scrub(" foo ").should == "foo"
    end

    it "should strip trailing whitespace from all lines" do
      scrub("foo \nbar ").should == "foo\nbar"
    end

    it "should strip a trailing newline" do
      scrub("foo\n").should == "foo"
      scrub("foo\nbar\n").should == "foo\nbar"
    end

    it "should remove leading whitespace from a multi-line string" do
      text = <<-EOT
  This has some indentation
  It is consistent depth
      EOT

      scrub(text).should == <<-EOT.chomp
This has some indentation
It is consistent depth
      EOT
    end

    it "should preserve internal indentation" do
      text = <<-EOT
  This is some indented text
    With internal indentation
  Back to baseline
      EOT

      scrub(text).should == <<-EOT.chomp
This is some indented text
  With internal indentation
Back to baseline
      EOT
    end

    it "should ignore the first line when calculating indentation" do
      text = "This is not indented
              but the rest of the text is
              and should be stripped"

      scrub(text).should == <<-EOT.chomp
This is not indented
but the rest of the text is
and should be stripped
      EOT
    end

    it "should preserve internal indents when ignoring the first line" do
      text = "This is not indented
              but the rest of the text is
                and it contains internal indentation
                  and should be stripped,
                    but our indentation should be preserved"

      scrub(text).should == <<-EOT.chomp
This is not indented
but the rest of the text is
  and it contains internal indentation
    and should be stripped,
      but our indentation should be preserved
      EOT
    end
  end

  context "formatting help text" do
    let :cmd do
      Class.new(Razor::Command)
    end

    before :each do
      stub_const('Razor::Command::TestHelpRendering', cmd)
    end

    it "should fail with an unknown help format" do
      expect { cmd.help('awesome') }.
        to raise_error ArgumentError, /unknown help format awesome/
    end

    context "full help" do
      subject(:text) { cmd.help('full') }

      it "should return a sensible message with no help text" do
        text.should =~
          /Unfortunately, the `test-help-rendering` command has not been documented/
      end

      context "with a description" do
        before :each do
          cmd.description <<EOT
This is a description of the command.
It has a pile of text, and a couple of paragraphs.

Yup, this is totally a second "paragraph".
EOT
        end

        it { should =~ /# SYNOPSIS/ }
        it { should =~ /# DESCRIPTION/ }
        it { should_not =~ /# EXAMPLES/ }
        it { should_not =~ /# RETURNS/ }

        it { should =~ /This is a description of the command/ }
        it { should =~ /Yup, this is totally a second "paragraph"/ }

        context "synopsis generation" do
          it "should duplicate the first part of description as the synopsis" do
            text.should =~ /SYNOPSIS.*This is a description of the command$.*DESCRIPTION/m
          end

          it "should handle an embedded period nicely" do
            cmd.description <<EOT
Add a tag to a policy.  You can specify an existing tag by name, or you can
blah blah blah blah blah blah blah blah blah blah blah blah blah blah blah
EOT
            cmd.summary.should == 'Add a tag to a policy'
          end
        end

        it "should override the summary if explicitly supplied" do
          cmd.summary "hello, world"
          text.should =~ /SYNOPSIS.*hello, world$.*DESCRIPTION/m
          text.should =~ /This is a description of the command/
        end
      end
    end
  end
end
