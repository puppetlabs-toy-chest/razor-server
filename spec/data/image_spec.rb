# coding: utf-8
require_relative "../spec_helper"
require 'tempfile'
require 'tmpdir'
require 'webrick'

describe Razor::Data::Image do
  include TorqueBox::Injectors
  let :queue do fetch('/queues/razor/sequel-instance-messages') end

  context "name" do
    (0..31).map {|n| n.chr(Encoding::UTF_8) }.map(&:to_s).each do |char|
      it "should reject control characters (testing: #{char.inspect})" do
        image = Image.new(:name => "hello #{char} world", :image_url => 'file:///')
        image.should_not be_valid
        expect { image.save }.to raise_error Sequel::ValidationFailed
      end
    end

    it "should reject the `/` character in names" do
      image = Image.new(:name => "hello/goodbye", :image_url => 'file:///')
      image.should_not be_valid
      expect { image.save }.to raise_error Sequel::ValidationFailed
    end

    # A list of Unicode 6.0 whitespace, yay!
    [
      ?\u0009,  # horizontal tab
      ?\u000A,  # newline
      ?\u000B,  # vertical tab
      ?\u000C,  # new page
      ?\u000D,  # carriage return
      ?\u0020,  # space
      ?\u0085,  # NEL, Next line
      ?\u00A0,  # no-break space
      ?\u1680,  # ogham space mark
      ?\u180E,  # mongolian vowel separator
      ?\u2000,  # en quad
      ?\u2001,  # em quad
      ?\u2002,  # en space
      ?\u2003,  # em space
      ?\u2004,  # three-per-em
      ?\u2005,  # four-per-em
      ?\u2006,  # six-per-em
      ?\u2007,  # figure space
      ?\u2008,  # punctuation space
      ?\u2009,  # thin space
      ?\u200A,  # hair space
      ?\u2028,  # line separator
      ?\u2029,  # paragraph separator
      ?\u202F,  # narrow no-break space
      ?\u205F,  # medium mathematical space
      ?\u3000   # ideographic space
    ].each do |ws|
      context "with whitespace (#{format('\u%04x', ws.ord)})" do
        url = 'file:///dev/null'

        context "in Ruby" do
          it "should be rejected at the start" do
            Image.new(:name => "#{ws}name", :image_url => url).
              should_not be_valid
          end

          it "should be rejected at the end" do
            Image.new(:name => "name#{ws}", :image_url => url).
              should_not be_valid
          end

          # Fair warning: what with using a regex for validation, this is a
          # common failure mode, and not in fact redundant to the checks above.
          it "should be rejected at both the start and the end" do
            Image.new(:name => "#{ws}name#{ws}", :image_url => url).
              should_not be_valid
          end

          if ws.ord >= 0x20 then
            it "should accept the whitespace in the middle of a name" do
              Image.new(:name => "hello#{ws}world", :image_url => url).
                should be_valid
            end
          end
        end

        context "in PostgreSQL" do
          it "should be rejected at the start" do
            expect {
              Image.dataset.insert(:name => "#{ws}name", :image_url => url)
            }.to raise_error Sequel::CheckConstraintViolation
          end

          it "should be rejected at the end" do
            expect {
              Image.dataset.insert(:name => "name#{ws}", :image_url => url)
            }.to raise_error Sequel::CheckConstraintViolation
          end

          # Fair warning: what with using a regex for validation, this is a
          # common failure mode, and not in fact redundant to the checks above.
          it "should be rejected at both the start and the end" do
            expect {
              Image.dataset.insert(:name => "#{ws}name#{ws}", :image_url => url)
            }.to raise_error Sequel::CheckConstraintViolation
          end

          if ws.ord >= 0x20 then
            it "should accept the whitespace in the middle of a name" do
              # As long as we don't raise, we win.
              Image.dataset.insert(:name => "hello#{ws}world", :image_url => url)
            end
          end
        end
      end
    end

    # Using 32 characters at a time here is a trade-off: it is much faster
    # than running validation on each character uniquely, which has a fairly
    # high start-up overhead.  On the other hand, with the shuffle it gives
    # reasonable statistical probability that a flaw in the validation will
    # eventually be captured.  Given we report the PRNG seed, we can also
    # reproduce the test...  this does require Ruby 1.9 to function.
    # --daniel 2013-06-24
    prng = Random.new
    context "statistical validation with prng: #{prng.seed}" do
      banned = [
        0x0009,  # horizontal tab
        0x000A,  # newline
        0x000B,  # vertical tab
        0x000C,  # new page
        0x000D,  # carriage return
        0x0020,  # space
        0x002F,  # forward slash
        0x0085,  # NEL, Next line
        0x00A0,  # no-break space
        0x1680,  # ogham space mark
        0x180E,  # mongolian vowel separator
        0x2000,  # en quad
        0x2001,  # em quad
        0x2002,  # en space
        0x2003,  # em space
        0x2004,  # three-per-em
        0x2005,  # four-per-em
        0x2006,  # six-per-em
        0x2007,  # figure space
        0x2008,  # punctuation space
        0x2009,  # thin space
        0x200A,  # hair space
        0x2028,  # line separator
        0x2029,  # paragraph separator
        0x202F,  # narrow no-break space
        0x205F,  # medium mathematical space
        0x3000   # ideographic space
      ]

      (32..0x266b).
        reject{|x| banned.member? x }.
        shuffle(random: prng).
        each_slice(32) do |c|

        string  = c.map{|n| n.chr(Encoding::UTF_8)}.join('')
        display = "\\u{#{c.map{|n| n.to_s(16)}.join(' ')}}"

        # If you came here seeking understanding, the `\u{1 2 3}` form is a
        # nice way of escaping the characters so that your terminal doesn't
        # spend a while loading literally *every* Unicode code point from
        # fallback fonts when you use, eg, the documentation formatter.
        #
        # Internally this is testing on the actual *characters*.
        it "accept all legal characters: string \"#{display}\"" do
          Image.new(:image_url => 'file:///', :name => string).save.should be_valid
        end
      end
    end

    context "aggressive Unicode support" do
      [ # You are not expected to understand this text.
        "ÆtherÜnikérûn", "काkāὕαΜπΜπ", "Pòîê᚛᚛ᚉᚑᚅᛁ", "ᚳ᛫æðþȝaɪkæ", "n⠊⠉⠁ᛖᚴярса",
        "нЯškłoმინა", "სԿրնամجامআ", "মিमीकನನಗका", "चநான்నేనుම", "ටවීکانشيشم",
        "یأناאנאיɜn", "yɜإِنက္ယ္q", "uốcngữ些世ខ្", "ញຂອ້ຍฉันกิ", "मकाཤེལ我能吞我",
        "能私はガラ나는유리ᓂ", "ᕆᔭᕌᖓ",
      ].each do |name|
        url = 'file:///dev/null'

        it "should accept the name #{name.inspect}" do
          image = Image.new(:name => name, :image_url => url)
          image.should be_valid
        end

        it "should round-trip the name #{name.inspect} through the database" do
          image = Image.new(:name => name, :image_url => url).save
          Image.find(:name => name).should == image
        end
      end
    end
  end

  context "image_url" do
    [
      'http://example.com/foobar',
      'http://example/foobar',
      'http://example.com/',
      'http://example.com',
      'https://foo.example.com/image.iso',
      'file:/dev/null',
      'file:///dev/null'
    ].each do |url|
      it "should accept a basic URL: #{url.inspect}" do
        # save to push validation through the database, too.
        Image.new(:name => 'foo', :image_url => url).save.should be_valid
      end
    end

    [
      'ftp://example.com/foo.iso',
      'file://example.com/dev/null',
      'file://localhost/dev/null',
      'http:///vmware.iso',
      'https:///vmware.iso',
      "http://example.com/foo\tbar",
      "http://example.com/foo\nbar",
      "http://example.com/foo\n",
      'http://example.com/foo bar'
    ].each do |url|
      it "Ruby should reject invalid URL: #{url.inspect}" do
        Image.new(:name => 'foo', :image_url => url).should_not be_valid
      end

      it "PostgreSQL should reject invalid URL: #{url.inspect}" do
        expect {
          Image.dataset.insert(:name => 'foo', :image_url => url)
        }.to raise_error Sequel::CheckConstraintViolation
      end
    end
  end

  context "after creation" do
    it "should automatically 'make_the_image_accessible'" do
      image = Image.new(:name => 'foo', :image_url => 'file:///')
      expect {
        image.save
      }.to have_published(
        'class'    => image.class.name,
        # Because we can't look into the future and see what that the PK will
        # be without saving, but we can't save without publishing the message
        # and spoiling the test, we have to check this more liberally...
        'instance' => include(:id => be),
        'message'  => 'make_the_image_accessible'
      ).on(queue)
    end
  end

  context "make_the_image_accessible" do
    context "with file URLs" do
      let :tmpfile do Tempfile.new(['make_the_image_accessible', '.iso']) end
      let :path    do tmpfile.path end
      let :image   do Image.new(:name => 'test', :image_url => "file://#{path}") end

      it "should raise (to trigger a retry) if the image is not readable" do
        File.chmod(00000, path) # yes, *no* permissions, thanks
        expect {
          image.make_the_image_accessible
        }.to raise_error RuntimeError, /unable to read local file/
      end

      it "should publish 'unpack_image' if the image is readable" do
        expect {
          image.make_the_image_accessible
        }.to have_published(
           'class'     => image.class.name,
           'instance'  => image.pk_hash,
           'message'   => 'unpack_image',
           'arguments' => [path]
        ).on(queue)
      end

      it "should work with uppercase file scheme" do
        image.image_url = "FILE://#{path}"

        expect {
          image.make_the_image_accessible
        }.to have_published(
          'class'     => image.class.name,
          'instance'  => image.pk_hash,
          'message'   => 'unpack_image',
          'arguments' => [path]
        ).on(queue)
      end
    end

    context "with HTTP URLs" do
      FileContent = "This is the file content.\n"
      LongFileSize = (Razor::Data::Image::BufferSize * 2.5).ceil

      # around hooks don't allow us to use :all, and we only want to do
      # setup/teardown of this fixture once; since the server is stateless we
      # don't risk much doing so.
      before :all do
        null    = WEBrick::Log.new('/dev/null')
        @server = WEBrick::HTTPServer.new(
          :Port      => 8000,
          :Logger    => null,
          :AccessLog => null,
        )

        @server.mount_proc '/short.iso' do |req, res|
          res.status = 200
          res.body   = FileContent
        end

        @server.mount_proc '/long.iso' do |req, res|
          res.status = 200
          res.body   = ' ' * LongFileSize
        end

        Thread.new { @server.start }
      end

      after :all do
        @server and @server.shutdown
      end

      let :image do
        Image.new(:name => 'test', :image_url => 'http://localhost:8000/')
      end

      context "download_file_to_tempdir" do
        it "should raise (for retry) if the requested URL does not exist" do
          expect {
            image.download_file_to_tempdir(URI.parse('http://localhost:8000/no-such-file'))
          }.to raise_error OpenURI::HTTPError, /404/
        end

        it "should copy short content down on success" do
          url  = URI.parse('http://localhost:8000/short.iso')
          file = image.download_file_to_tempdir(url)
          File.read(file).should == FileContent
        end

        it "should copy long content down on success" do
          url  = URI.parse('http://localhost:8000/long.iso')
          file = image.download_file_to_tempdir(url)
          File.size?(file).should == LongFileSize
        end
      end

      it "should publish 'unpack_image' if the image is readable" do
        image.image_url = 'http://localhost:8000/short.iso'
        image.save              # make sure our primary key is set!

        expect {
          image.make_the_image_accessible
        }.to have_published(
          'class'     => image.class.name,
          'instance'  => image.pk_hash,
          'message'   => 'unpack_image',
          'arguments' => [end_with('/short.iso')]
        ).on(queue)
      end
    end
  end

  context "on destroy" do
    it "should remove the temporary directory, if there is one" do
      tmpdir = Dir.mktmpdir('razor-image-download')

      image = Image.new(:name => 'foo', :image_url => 'file:///')
      image.tmpdir = tmpdir
      image.save
      image.destroy

      File.should_not be_exist tmpdir
    end

    it "should not fail if there is no temporary directory" do
      image = Image.new(:name => 'foo', :image_url => 'file:///')
      image.tmpdir = nil
      image.save
      image.destroy
    end
  end

  context "filesystem_safe_name" do
    '/\\?*:|"<>$\''.each_char do |char|
      it "should escape #{char.inspect}" do
        image = Image.new(:name => "foo#{char}bar", :image_url => 'file:///')
        image.filesystem_safe_name.should_not include char
        image.filesystem_safe_name.should =~ /%0{0,6}#{char.ord.to_s(16)}/i
      end
    end
  end

  context "image_store_root" do
    it "should raise if no image store root is configured" do
      Razor.config.stub(:[]).with('image_store_root').and_return(nil)

      expect {
        Image.new(:name => "foo", :image_url => 'file:///').image_store_root
      }.to raise_error RuntimeError, /image_store_root/
    end

    it "should raise if the path is not absolute" do
      Razor.config.stub(:[]).with('image_store_root').and_return('hoobly-goobly')
      expect {
        Image.new(:name => "foo", :image_url => 'file:///').image_store_root
      }.to raise_error RuntimeError, /image_store_root/
    end

    it "should return a Pathname if the path is valid" do
      path = '/no/such/image-store'
      Razor.config.stub(:[]).with('image_store_root').and_return(path)

      root = Image.new(:name => "foo", :image_url => 'file:///').image_store_root
      root.should be_an_instance_of Pathname
      root.should == Pathname(path)
    end
  end

  context "unpack_image" do
    let :tiny_iso do
      (Pathname(__FILE__).dirname.parent + 'fixtures' + 'iso' + 'tiny.iso').to_s
    end

    let :image do
      Image.new(:name => 'unpack', :image_url => "file://#{tiny_iso}").save
    end

    it "should create the image store root directory if absent" do
      Dir.mktmpdir do |tmpdir|
        root = Pathname(tmpdir) + 'image-store'
        Razor.config['image_store_root'] = root.to_s

        root.should_not exist

        image.unpack_image(tiny_iso)

        root.should exist
      end
    end

    it "should unpack the image into the filesystem_safe_name under root" do
      Dir.mktmpdir do |root|
        root = Pathname(root)
        Razor.config['image_store_root'] = root
        image.unpack_image(tiny_iso)

        (root + image.filesystem_safe_name).should exist
        (root + image.filesystem_safe_name + 'content.txt').should exist
      end
    end

    it "should publish 'release_temporary_image' when unpacking completes" do
      expect {
        Dir.mktmpdir do |root|
          root = Pathname(root)
          Razor.config['image_store_root'] = root
          image.unpack_image(tiny_iso)
        end
      }.to have_published(
        'class'    => image.class.name,
        'instance' => image.pk_hash,
        'message'  => 'release_temporary_image'
      ).on(queue)
    end
  end

  context "release_temporary_image" do
    let :image do
      Image.new(:name => 'unpack', :image_url => 'file:///dev/empty').save
    end

    it "should do nothing, successfully, if tmpdir is nil" do
      image.tmpdir.should be_nil
      image.release_temporary_image
    end

    it "should remove the temporary directory" do
      Dir.mktmpdir do |tmpdir|
        root = Pathname(tmpdir) + 'image-root'
        root.mkpath
        root.should exist

        image.tmpdir = root
        image.save

        image.release_temporary_image

        root.should_not exist
      end
    end

    it "should raise an exception if removing the temporary directory fails" do
      # Testing with a scratch directory means that we can't, eg, discover
      # that someone ran the tests as root and was able to delete the
      # wrong thing.  Much, much better safe than sorry in this case!
      Dir.mktmpdir do |tmpdir|
        tmpdir = Pathname(tmpdir)
        image.tmpdir = tmpdir + 'no-such-directory'
        image.save

        expect {
          image.release_temporary_image
        }.to raise_error Errno::ENOENT, /no-such-directory/
      end
    end
  end
end
