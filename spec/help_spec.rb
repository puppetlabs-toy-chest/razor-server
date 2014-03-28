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

  context "examples" do
    it "should return nil if no examples is set" do
      help.examples.should be_nil
    end

    it "should accept a examples value" do
      expect { help.examples('testing') }.not_to raise_error
    end

    it "should return the new examples value" do
      help.examples('test').should == 'test'
    end

    it "should retain the examples value" do
      help.examples('test')
      help.examples.should == 'test'
    end

    it "should work if the examples contains a newline" do
      expect { help.examples("test\ncontent") }.not_to raise_error
    end

    it "should strip indents" do
      help.examples <<EOT
        This text is indented.
        We should see something strip that off.
EOT
      help.examples.should =~ /^This text/
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
end
