# coding: utf-8
require_relative "../spec_helper"
require 'tempfile'
require 'tmpdir'
require 'webrick'

describe Razor::Data::Repo do
  include TorqueBox::Injectors
  let :queue do fetch('/queues/razor/sequel-instance-messages') end

  context "name" do
    (0..31).map {|n| n.chr(Encoding::UTF_8) }.map(&:to_s).each do |char|
      it "should reject control characters (testing: #{char.inspect})" do
        repo = Repo.new(:name => "hello #{char} world", :iso_url => 'file:///')
        repo.should_not be_valid
        expect { repo.save }.to raise_error Sequel::ValidationFailed
      end
    end

    it "should reject the `/` character in names" do
      repo = Repo.new(:name => "hello/goodbye", :iso_url => 'file:///')
      repo.should_not be_valid
      expect { repo.save }.to raise_error Sequel::ValidationFailed
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
            Repo.new(:name => "#{ws}name", :iso_url => url).
              should_not be_valid
          end

          it "should be rejected at the end" do
            Repo.new(:name => "name#{ws}", :iso_url => url).
              should_not be_valid
          end

          # Fair warning: what with using a regex for validation, this is a
          # common failure mode, and not in fact redundant to the checks above.
          it "should be rejected at both the start and the end" do
            Repo.new(:name => "#{ws}name#{ws}", :iso_url => url).
              should_not be_valid
          end

          if ws.ord >= 0x20 then
            it "should accept the whitespace in the middle of a name" do
              Repo.new(:name => "hello#{ws}world", :iso_url => url).
                should be_valid
            end
          end
        end

        context "in PostgreSQL" do
          it "should be rejected at the start" do
            expect {
              Repo.dataset.insert(:name => "#{ws}name", :iso_url => url)
            }.to raise_error Sequel::CheckConstraintViolation
          end

          it "should be rejected at the end" do
            expect {
              Repo.dataset.insert(:name => "name#{ws}", :iso_url => url)
            }.to raise_error Sequel::CheckConstraintViolation
          end

          # Fair warning: what with using a regex for validation, this is a
          # common failure mode, and not in fact redundant to the checks above.
          it "should be rejected at both the start and the end" do
            expect {
              Repo.dataset.insert(:name => "#{ws}name#{ws}", :iso_url => url)
            }.to raise_error Sequel::CheckConstraintViolation
          end

          if ws.ord >= 0x20 then
            it "should accept the whitespace in the middle of a name" do
              # As long as we don't raise, we win.
              Repo.dataset.insert(:name => "hello#{ws}world", :iso_url => url)
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
          Repo.new(:iso_url => 'file:///', :name => string).save.should be_valid
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
          repo = Repo.new(:name => name, :iso_url => url)
          repo.should be_valid
        end

        it "should round-trip the name #{name.inspect} through the database" do
          repo = Repo.new(:name => name, :iso_url => url).save
          Repo.find(:name => name).should == repo
        end
      end
    end
  end


  [:url, :iso_url].each do |url_name|
    context url_name.to_s do
      [
       'http://example.com/foobar',
       'http://example/foobar',
       'http://example.com/',
       'http://example.com',
       'https://foo.example.com/repo.iso',
       'file:/dev/null',
       'file:///dev/null'
      ].each do |url|
        it "should accept a basic URL #{url.inspect}" do
          # save to push validation through the database, too.
          Repo.new(:name => 'foo', url_name => url).save.should be_valid
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
        it "Ruby should reject invalid URL #{url.inspect}" do
          Repo.new(:name => 'foo', :iso_url => url).should_not be_valid
        end

        it "PostgreSQL should reject invalid URL #{url.inspect}" do
          expect {
            Repo.dataset.insert(:name => 'foo', :iso_url => url)
          }.to raise_error Sequel::CheckConstraintViolation
        end
      end
    end
  end

  context "url and iso_url" do
    it "should reject setting both" do
      Repo.new(:name => 'foo', :url => 'http://example.org/',
               :iso_url => 'http://example.com').should_not be_valid
    end

    it "should require setting one of them" do
      Repo.new(:name => 'foo').should_not be_valid
    end
  end

  context "after creation" do
    it "should automatically 'make_the_repo_accessible'" do
      repo = Repo.new(:name => 'foo', :iso_url => 'file:///')
      expect {
        repo.save
      }.to have_published(
        'class'    => repo.class.name,
        # Because we can't look into the future and see what that the PK will
        # be without saving, but we can't save without publishing the message
        # and spoiling the test, we have to check this more liberally...
        'instance' => include(:id => be),
        'message'  => 'make_the_repo_accessible'
      ).on(queue)
    end
  end

  context "make_the_repo_accessible" do
    context "with file URLs" do
      let :tmpfile do Tempfile.new(['make_the_repo_accessible', '.iso']) end
      let :path    do tmpfile.path end
      let :repo   do Repo.new(:name => 'test', :iso_url => "file://#{path}") end

      it "should raise (to trigger a retry) if the repo is not readable" do
        File.chmod(00000, path) # yes, *no* permissions, thanks
        expect {
          repo.make_the_repo_accessible
        }.to raise_error RuntimeError, /unable to read local file/
      end

      it "should publish 'unpack_repo' if the repo is readable" do
        expect {
          repo.make_the_repo_accessible
        }.to have_published(
           'class'     => repo.class.name,
           'instance'  => repo.pk_hash,
           'message'   => 'unpack_repo',
           'arguments' => [path]
        ).on(queue)
      end

      it "should work with uppercase file scheme" do
        repo.iso_url = "FILE://#{path}"

        expect {
          repo.make_the_repo_accessible
        }.to have_published(
          'class'     => repo.class.name,
          'instance'  => repo.pk_hash,
          'message'   => 'unpack_repo',
          'arguments' => [path]
        ).on(queue)
      end
    end

    context "with HTTP URLs" do
      FileContent = "This is the file content.\n"
      LongFileSize = (Razor::Data::Repo::BufferSize * 2.5).ceil

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

      let :repo do
        Repo.new(:name => 'test', :iso_url => 'http://localhost:8000/')
      end

      context "download_file_to_tempdir" do
        it "should raise (for retry) if the requested URL does not exist" do
          expect {
            repo.download_file_to_tempdir(URI.parse('http://localhost:8000/no-such-file'))
          }.to raise_error OpenURI::HTTPError, /404/
        end

        it "should copy short content down on success" do
          url  = URI.parse('http://localhost:8000/short.iso')
          file = repo.download_file_to_tempdir(url)
          File.read(file).should == FileContent
        end

        it "should copy long content down on success" do
          url  = URI.parse('http://localhost:8000/long.iso')
          file = repo.download_file_to_tempdir(url)
          File.size?(file).should == LongFileSize
        end
      end

      it "should publish 'unpack_repo' if the repo is readable" do
        repo.iso_url = 'http://localhost:8000/short.iso'
        repo.save              # make sure our primary key is set!

        expect {
          repo.make_the_repo_accessible
        }.to have_published(
          'class'     => repo.class.name,
          'instance'  => repo.pk_hash,
          'message'   => 'unpack_repo',
          'arguments' => [end_with('/short.iso')]
        ).on(queue)
      end
    end
  end

  context "on destroy" do
    it "should remove the temporary directory, if there is one" do
      tmpdir = Dir.mktmpdir('razor-repo-download')

      repo = Repo.new(:name => 'foo', :iso_url => 'file:///')
      repo.tmpdir = tmpdir
      repo.save
      repo.destroy

      File.should_not be_exist tmpdir
    end

    it "should not fail if there is no temporary directory" do
      repo = Repo.new(:name => 'foo', :iso_url => 'file:///')
      repo.tmpdir = nil
      repo.save
      repo.destroy
    end
  end

  context "filesystem_safe_name" do
    '/\\?*:|"<>$\''.each_char do |char|
      it "should escape #{char.inspect}" do
        repo = Repo.new(:name => "foo#{char}bar", :iso_url => 'file:///')
        repo.filesystem_safe_name.should_not include char
        repo.filesystem_safe_name.should =~ /%0{0,6}#{char.ord.to_s(16)}/i
      end
    end
  end

  context "repo_store_root" do
    it "should return a Pathname if the path is valid" do
      path = '/no/such/repo-store'
      Razor.config.stub(:[]).with('repo_store_root').and_return(path)

      root = Repo.new(:name => "foo", :iso_url => 'file:///').repo_store_root
      root.should be_an_instance_of Pathname
      root.should == Pathname(path)
    end
  end

  context "unpack_repo" do
    let :tiny_iso do
      (Pathname(__FILE__).dirname.parent + 'fixtures' + 'iso' + 'tiny.iso').to_s
    end

    let :repo do
      Repo.new(:name => 'unpack', :iso_url => "file://#{tiny_iso}").save
    end

    it "should create the repo store root directory if absent" do
      Dir.mktmpdir do |tmpdir|
        root = Pathname(tmpdir) + 'repo-store'
        Razor.config['repo_store_root'] = root.to_s

        root.should_not exist

        repo.unpack_repo(tiny_iso)

        root.should exist
      end
    end

    it "should unpack the repo into the filesystem_safe_name under root" do
      pending("libarchive ISO support on OSX", :if => ::FFI::Platform.mac?) do
        Dir.mktmpdir do |root|
          root = Pathname(root)
          Razor.config['repo_store_root'] = root
          repo.unpack_repo(tiny_iso)

          (root + repo.filesystem_safe_name).should exist
          (root + repo.filesystem_safe_name + 'content.txt').should exist
          (root + repo.filesystem_safe_name + 'file-with-filename-that-is-longer-than-64-characters-which-some-unpackers-get-wrong.txt').should exist
        end
      end
    end

    it "should publish 'release_temporary_repo' when unpacking completes" do
      expect {
        Dir.mktmpdir do |root|
          root = Pathname(root)
          Razor.config['repo_store_root'] = root
          repo.unpack_repo(tiny_iso)
        end
      }.to have_published(
        'class'    => repo.class.name,
        'instance' => repo.pk_hash,
        'message'  => 'release_temporary_repo'
      ).on(queue)
    end
  end

  context "release_temporary_repo" do
    let :repo do
      Repo.new(:name => 'unpack', :iso_url => 'file:///dev/empty').save
    end

    it "should do nothing, successfully, if tmpdir is nil" do
      repo.tmpdir.should be_nil
      repo.release_temporary_repo
    end

    it "should remove the temporary directory" do
      Dir.mktmpdir do |tmpdir|
        root = Pathname(tmpdir) + 'repo-root'
        root.mkpath
        root.should exist

        repo.tmpdir = root
        repo.save

        repo.release_temporary_repo

        root.should_not exist
      end
    end

    it "should raise an exception if removing the temporary directory fails" do
      # Testing with a scratch directory means that we can't, eg, discover
      # that someone ran the tests as root and was able to delete the
      # wrong thing.  Much, much better safe than sorry in this case!
      Dir.mktmpdir do |tmpdir|
        tmpdir = Pathname(tmpdir)
        repo.tmpdir = tmpdir + 'no-such-directory'
        repo.save

        expect {
          repo.release_temporary_repo
        }.to raise_error Errno::ENOENT, /no-such-directory/
      end
    end
  end
end
