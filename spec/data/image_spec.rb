# coding: utf-8
require_relative "../spec_helper"

describe Razor::Data::Image do
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
end
