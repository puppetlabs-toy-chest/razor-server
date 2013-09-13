require 'spec_helper'
require 'tmpdir'

describe Razor::ISO do
  describe "find_bsdtar" do
    it "should raise if the command is not found" do
      File.stub(:executable?).and_return false
      expect { Razor::ISO.find_bsdtar }.
        to raise_error RuntimeError, /the bsdtar unpacker was not found/
    end

    it "should return the path to the executable if it is found" do
      stub_const('ENV', {'PATH' => '/a:/b:/c:/d:/e'})
      File.stub(:executable?) {|path| path == '/c/bsdtar' }
      Razor::ISO.find_bsdtar.should == '/c/bsdtar'
    end

    it "should return the first executable on the path" do
      stub_const('ENV', {'PATH' => '/a:/b:/c:/d:/e'})
      File.stub(:executable?) {|path| ['/c/bsdtar', '/e/bsdtar'].include?(path) }
      Razor::ISO.find_bsdtar.should == '/c/bsdtar'
    end
  end

  describe "unpack" do
    before :each do
      Razor::ISO.find_bsdtar rescue pending "bsdtar is not installed on this machine"
    end

    let :tiny_iso do Pathname(__FILE__).dirname + 'fixtures' + 'iso' + 'tiny.iso' end

    it "should unpack the image with bsdtar" do
      Dir.mktmpdir do |dir|
        Razor::ISO.unpack(tiny_iso, dir)
        File.read(Pathname(dir) + 'content.txt').should == "This is the life!\n"
        File.read(Pathname(dir) + 'file-with-filename-that-is-longer-than-64-characters-which-some-unpackers-get-wrong.txt').should == "7zip for example\n"
      end
    end
  end
end
