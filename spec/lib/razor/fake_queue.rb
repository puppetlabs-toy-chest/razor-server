# -*- encoding: utf-8 -*-
# Use:
#
#     expect {
#       ...
#     }.to have_published(message_match).on(queue)
#
RSpec::Matchers.define :have_published do |expected|
  raise "expected was not a Hash" unless Hash === expected

  # I use this half the time, because I can't remember which name I used.
  # Why bother learning when I can alias it. ;)
  chain :on do |queue|
    @queue = queue
  end

  chain :to do |queue|
    @queue = queue
  end

  match do |code_to_run|
    raise "queue was not set with `on`" unless @queue
    before = @queue.count - 1   # only newly published messages count
    code_to_run.call            # don't care if you throw past me
    after = @queue.peek_at_all.slice(before .. -1) || []
    after.map{|msg| msg[:body]}.any? do |msg|
      expected.all? do |k, v|
        # The comparison on the right allows us to use rspec matchers, as well
        # as Class instances, regexp vs string, etc, smart matching.
        # Especially the ability to use an rspec matcher is ideal.
        msg.has_key?(k) and v === msg[k]
      end
    end
  end

  description do
    "published #{expected.inspect}"
  end

  failure_message_for_should do |actual|
    "expected the message would have published #{expected.inspect}"
  end

  failure_message_for_should_not do |actual|
    "expected the message would not have published #{expected.inspect}"
  end
end

class Razor::FakeQueue < Array
  def publish(body, options = {})
    options = options.merge(
      :encoding   => :edn,      # matches our policies, if not upstream
      :priority   => :normal,
      :ttl        => 0,
      :tx         => true,
      :persistent => true
    )

    raise 'only edn or marshal encoding is supported' unless [:edn, :marshal].include? options[:encoding]
    raise ArgumentError if options[:scheduled] and not options[:scheduled].is_a? Time

    body = case options[:encoding]
           when :marshal then Marshal.dump(body)
           when :edn     then body.to_edn
           else raise "unsupported encoding #{options[:encoding]}"
           end

    push({:body => body, :options => options})
    self
  end

  def receive(options = {})
    options = options.merge(
      :decode          => true,
      :timeout         => 0,
      :startup_timeout => 30000,
      :subscriber_name => 'subscriber-1'
    )

    raise "only 'decoded' receive has been implemented" unless options[:decode]
    raise "timeout has not been implemented" unless options[:timeout] == 0
    raise 'selector has not been implemented' unless options[:selector].nil?

    _decode_message(shift)[:body]
  end

  # Internal helper for testing purposes: peek at the first message with both
  # raw and decoded versions of the body present.
  def peek
    return nil if empty?
    _decode_message(self.first)
  end

  def peek_at_all
    map {|msg| _decode_message(msg) }
  end

  def _decode_message(raw)
    decoded = case raw[:options][:encoding]
              when :marshal then Marshal.load(raw[:body])
              when :edn     then EDN.read(raw[:body])
              else raise "#{raw[:options][:encoding]} encoding not implemented yet"
              end
    {:options => raw[:options], :body => decoded, :raw => raw[:body]}
  end

  def remove_messages(filter = nil)
    raise "filter is not yet implemented" if filter
    clear
    self
  end

  def count_messages
    length
  end
end
