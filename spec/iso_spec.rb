require 'spec_helper'
require 'tmpdir'

describe Razor::ISO do
  describe "find_7z" do
    it "should raise if the command is not found" do
      File.stub(:executable?).and_return false
      expect { Razor::ISO.find_7z }.
        to raise_error RuntimeError, /the 7z unpacker was not found/
    end

    it "should return the path to the executable if it is found" do
      stub_const('ENV', {'PATH' => '/a:/b:/c:/d:/e'})
      File.stub(:executable?) {|path| path == '/c/7z' }
      Razor::ISO.find_7z.should == '/c/7z'
    end

    it "should return the first executable on the path" do
      stub_const('ENV', {'PATH' => '/a:/b:/c:/d:/e'})
      File.stub(:executable?) {|path| path == '/c/7z' or path == '/e/7z' }
      Razor::ISO.find_7z.should == '/c/7z'
    end
  end

  describe "unpack" do
    before :each do
      Razor::ISO.find_7z rescue pending "7z is not installed on this machine"
    end

    let :tiny_iso do Pathname(__FILE__).dirname + 'fixtures' + 'iso' + 'tiny.iso' end

    it "should unpack the image with 7z" do
      Dir.mktmpdir do |dir|
        Razor::ISO.unpack(tiny_iso, dir)
        File.read(Pathname(dir) + 'content.txt').should == "This is the life!\n"
      end
    end
  end
end
