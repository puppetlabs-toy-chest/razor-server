class Razor::FakeQueue < Array
  def publish(body, options = {})
    options = options.merge(
      :encoding   => :marshal,
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

    raw = shift
    case raw[:options][:encoding]
    when :marshal then Marshal.load(raw[:body])
    when :edn     then EDN.read(raw[:body])
    else raise "#{raw[:options][:encoding]} encoding not implemented yet"
    end
  end

  # Internal helper for testing purposes: peek at the first message with both
  # raw and decoded versions of the body present.
  def peek
    return nil if empty?
    raw = self[0]

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
