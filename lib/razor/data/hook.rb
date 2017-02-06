# -*- encoding: utf-8 -*-

# Lifecycle and Events (starred events will be implemented later)
#   * node-booted (C)
#      - every time a node requests /svc/boot
#   * node-registered (C)
#      - first time we get facts for a node (i.e., node.facts were nil before)
#   * node-facts-changed (C)
#      - from /svc/checkin every time facts change
#   * node-bound-to-policy (C)
#      - when a node gets bound to a policy
#   * node-unbound-from-policy (C)
#      - when a node gets unbound from a policy, e.g. via 'reinstall-node' command
#   * node-install-started (*)
#      - when booting into the first step of a task/policy for the first time
#   * node-install-finished (*)
#      - when Node.stage_done is called with name == "finished"
#   * node-broker-finished (*)
#      - we do not know that currently
#   * node-deleted (C)
#      - when 'delete-node' command is run

# Things to worry about
# 1. Events aren't 'done' until all hook scripts for it have finished
#    - can not fire 'next' event until previous one is done
#      -> going from bound-node to install-node; if binding triggers
#         an IP address lookup, we need to wait with install-node until that
#         is done

class Razor::Data::Hook < Sequel::Model
  one_to_many :events

  # If this changes, also update the hooks.md file.
  AVAILABLE_EVENTS = %w(node-booted node-registered node-bound-to-policy
                        node-unbound-from-policy node-deleted node-facts-changed
                        node-install-finished)

  plugin :serialization, :json, :configuration

  serialize_attributes [
                           ->(b){ b.name },               # serialize
                           ->(b){ Razor::HookType.find(name: b) } # deserialize
                       ], :hook_type


  # This is a hack around the fact that the auto_validates plugin does
  # not play nice with the JSON serialization plugin (the serializaton
  # happens in the before_save hook, which runs after validation)
  #
  # To avoid spurious error messages, we tell the validation machinery to
  # expect a Hash
  #
  # FIXME: Figure out a way to address this issue upstream
  def schema_type_class(k)
    if k == :configuration
      Hash
    elsif k == :hook_type
      Razor::HookType
    else
      super
    end
  end

  def _run(hash)
    run(hash['cause'], hash['args'])
  end

  # This runs the hook in-process. If it should be executed asynchronously, use
  # `trigger`. Returns nil if the hook has no handler for the event.
  def run(event, args = {})
    raise ArgumentError.new("cannot run hook with event #{event}") unless AVAILABLE_EVENTS.include?(event)
    if script = find_script(event)
      # FIXME: args may contain Data objects; they need to be serialized
      # special
      # FIXME^2: we do this for Node, but it should be more general
      loop do
        result = execute(event, script, args)
        break result if result != :retry
        # Small sleep to avoid busy-waiting.
        sleep(0.1)
      end
    else
      # Hook contains no script for this event; ignore.
    end
  end

  def handles_event?(event_name)
    !!(find_script(event_name))
  end

  # Trigger all hooks that have a handler for event. The implementation is
  # asynchronous. `run` is synchronous.
  def self.trigger(cause, args = {})
    # Do not disturb original arguments.
    # Serialize the objects here to avoid another database call on objects
    # that may be gone by the time the hook runs.
    self.all do |hook|
      hook.trigger(cause, args)
    end
  end

  # Trigger one hook. This will skip if there is no handler for the event.
  # The implementation is asynchronous; `run` is synchronous.
  def trigger(cause, args = {})
    return unless handles_event?(cause)
    formatted_args = args.dup.merge(serialize_arguments(cause, node: args[:node], policy: args[:policy]))
    # Call the `_run` method so the queue arguments can be converted into a
    # standardized format for the actual `run` method.
    publish '_run', 'cause' => cause, 'args' => formatted_args,
                    'queue' => '/queues/razor/sequel-hooks-messages'
  end

  # Delegator for private method
  def serialize_arguments(cause, args)
    view_hash(cause, args)
  end

  # We have validation that we match our external files on disk, too.
  # While this isn't a complete promise, it does help catch some of the more
  # obvious errors.
  def validate
    super
    if hook_type.is_a?(Razor::HookType)
      # Validate our configuration -- now that we have access to our type to
      # obtain the schema for validation.
      schema = hook_type.configuration_schema

      # Extra keys found in the data we were given are treated as errors,
      # since they are most likely typos, or targeting a hook other than
      # the current hook.
      if configuration.is_a?(Hash) and schema.is_a?(Hash)
        (configuration.keys - schema.keys).each do |additional|
          errors.add(:configuration, _("key '%{additional}' is not defined for this hook type") % {additional: additional})
        end
      else
        errors.add(:configuration, _("must be a Hash"))
      end

      # Required keys that are missing from the supplied configuration.
      schema.each do |key, details|
        next if configuration.has_key? key
        (configuration[key] = details['default']) and next if details['default']
        next unless details['required']
        errors.add(:configuration, _("key '%{key}' is required by this hook type, but was not supplied") % {key: key})
      end
    else
      errors.add(:hook_type, _("'%{name}' is not valid") % {name: hook_type})
    end
  end

  def log(params = {})
    cursor = Razor::Data::Event.order(:timestamp).order(:id).reverse.
        where(hook_id: id).limit(params[:limit], params[:start])
    cursor.map do |log|
      { 'timestamp' => log.timestamp.xmlschema, 'node' => (log.node ? log.node.name : nil),
        'policy' => (log.policy ? log.policy.name : nil)}.update(log.entry).delete_if { |_,v| v.nil? }
    end
  end

  private

  # Check if this hook defines a handler script for event and return its
  # absolute path. Return nil if there is no such script
  def find_script(cause)
    Razor.config.hook_paths.collect do |path|
      Pathname.new(path) + "#{hook_type.name}.hook" + cause
    end.find do |script|
      script.file? and (script.executable? or (!log_append(msg: _("file %{script} is not executable") % {script: script}, severity: 'warn', event: cause) ))
    end
  end

  # This is a helper class for composing the hook's log message. Pieces will be
  # added to this log over time, making this an implementation of the
  # Builder pattern.
  class Appender
    def initialize(entry = {})
      @log = entry
    end
    def update(entry)
      @log.update(entry)
    end
    def add_error(msg, severity = 'error')
      update(error: [get(:error), msg].compact.join(_(' and ')),
              severity: severity)
    end
    def add_action(action)
      update(actions: [get(:actions), action].compact.join(_(' and ')))
    end
    def get(key)
      @log[key]
    end
    def log
      @log.delete_if { |_,v| v.nil? or v.respond_to?('empty?') && v.empty? }
      Razor::Data::Event.log_append(@log)
    end
  end

  # This performs the actual work for running the hook script. The `debug`
  # argument in the `args` hash is stripped away before generating
  # arguments for the hook script.
  def execute(cause, script, args = {})
    debug = args.delete(:debug)
    Razor.database.transaction(savepoint: true) do
      return :retry unless lock!
      appender = Appender.new(hook: self)
      args[:hook] ||= {}
      node_id = args[:node][:id] unless args[:node].nil?
      policy_id = args[:policy][:id] unless args[:policy].nil?
      appender.update(node: node_id, policy: policy_id, event: cause)
      # Refresh these objects if they've changed. The node may be deleted,
      # in which case this should just use the cached data.
      if node = Razor::Data::Node[id: node_id]
        args[:node] = node_hash(node)
      end
      if hook = Razor::Data::Hook[id: self.id]
        args[:hook][:configuration] = hook.configuration
      end
      if policy = Razor::Data::Policy[id: policy_id]
        args[:policy] = policy_hash(policy)
      end

      appender.update(input: args.to_json) if Razor.config['store_hook_input'] or debug
      exit_status, success, output, error = exec_script(script, args.to_json)
      appender.update(exit_status: exit_status,
                      severity: success ? 'info' : 'error')
      # If the output is not valid JSON, put the whole message into the 'msg' in the Event
      begin
        appender.update(output: output) if Razor.config['store_hook_output'] or debug
        json = JSON.parse(output)
        appender.update(msg: json['output'], error: json['error'])
        residual = json.keys - ['hook', 'node', 'output', 'error']
        unless residual == []
          severity = appender.get(:severity) == 'error' ? 'error' : 'warn'
          msg = _('unexpected key in hook\'s output: %{diff}') % {hook: self.name, diff: residual.join(', ')}
          appender.add_error(msg, severity)
        end

        # Update the configuration of this hook.
        if json.has_key?('hook')
          update_hook(json['hook'], appender)
          appender.add_action(_("updating hook configuration: #{json['hook']['configuration']}"))
        end

        # Update node metadata.
        if json.has_key?('node')
          update_node(json['node'], node, appender)
          appender.add_action(_("updating node metadata: #{json['node']['metadata']}"))
        end
      rescue JSON::ParserError
        appender.add_error('invalid JSON returned from hook')
        # Put entire hook output into the 'msg' key as-is.
        appender.update(msg: output)
      rescue TypeError # TypeError catches a nil output.
        # Do nothing; stderr is still entered below.
      end
      if error
        appender.add_error(error)
      end
      save
      appender.log
    end
  end

  def update_hook(hash, appender)
    residual = hash.keys - ['configuration']
    unless residual == []
      severity = appender.get(:error) == 'error' ? 'error' : 'warn'
      msg = _('unexpected key in hook\'s output for hook update: %{diff}') %
          {hook: self.name, diff: residual.join(', ')}
      appender.add_error(msg, severity)
    end
    case (config = hash['configuration'])
    when Hash
      config.each do |operation, hash|
        case operation
          when 'update'
            hash.each do |key, value|
              schema = hook_type.configuration_schema
              if schema.include?(key)
                self.configuration[key] = value
              else
                appender.add_error(_('hook output includes invalid configuration update for key %{key}') % {key: key})
              end
            end
          when 'remove'
            hash.each do |key|
              self.configuration.delete(key)
            end
          else
            appender.add_error(_('undefined operation on hook: %{op}; should be \'update\' or \'remove\'') % {op: operation})
        end
      end
    when NilClass
     # Skip; not included in output.
    else
      severity = appender.get(:severity) == 'error' ? 'error' : 'warn'
      appender.add_error(_('hook output for hook configuration should be an %{object} but was a %{given}') %
                         {object: ruby_type_to_json(Hash), given: ruby_type_to_json(config.class)}, severity)
    end
  end

  def update_node(hash, node, appender)
    residual = hash.keys - ['metadata']
    unless residual == []
      severity = appender.get(:error) == 'error' ? 'error' : 'warn'
      msg = _('unexpected key in hook\'s output for node update: %{diff}') %
          {hook: self.name, diff: residual.join(', ')}
      appender.add_error(msg, severity)
    end
    if (node_changes = hash) && node_changes['metadata'].is_a?(Hash)
      if node
        extra_keys = node_changes['metadata'].keys - ['update', 'remove', 'clear']
        unless extra_keys == []
          msg = _("unexpected node metadata operation(s) %{keys} included") % {keys: extra_keys.join(', ')}
          # Severity remains the same if already 'error'.
          severity = appender.get(:error) == 'error' ? 'error' : 'warn'
          appender.add_error(msg, severity)
        end

        # Extra keys will be ignored in this method.
        node.modify_metadata(node_changes['metadata'])
        node.save
      else
        # Error: Applying metadata change but no node supplied. This shouldn't happen.
        msg = _("hook tried to update node metadata on a hook without a node")
        appender.update(error: [appender.get(:error), msg].compact.join(_(' and ')),
                        severity: 'error')
      end
    end
  end

  def exec_script(script, args)
    begin
      # Run the file from the hook's directory so that relative paths work.
      hook_dir = File.expand_path('..', script)
      stdin, stdout, stderr, wait_thr = Bundler.with_clean_env do
        begin
          old = Dir.pwd
          extra_path = Razor.config['hook_execution_path']
          ENV['PATH'] = "#{extra_path}:#{ENV['PATH']}" if extra_path
          Dir.chdir(hook_dir)
          Open3.popen3(script.to_s)
        ensure
          Dir.chdir(old)
        end
      end
      stdin.write(args) if args
      begin
        stdin.close unless stdin.closed?
      rescue Errno::EPIPE, Errno::EBADF, IOError
        # Do nothing; this means the hook did not read stdin or that stdin
        # closed already.
      end
      wait_thr.join
      # Prefer nil over an empty string.
      output = stdout.readlines.join
      error = stderr.readlines.join
      process = wait_thr.value
      [process.exitstatus, process.success?, output.empty? ? nil : output,
       error.empty? ? nil : error]
    rescue IOError => e
      # Error running the script. Catch the message and continue.
      [1, false, nil, e.message]
    ensure
      stdin.close unless !stdin or stdin.closed?
      stdout.close unless !stdout or stdout.closed?
      stderr.close unless !stderr or stderr.closed?
    end
  end

  # Log a message to the hook's log and save the log. Messages should be
  # hashes, where some of the keys have standard meanings. These keys are
  #
  # +:severity+ - 'info', 'warn' or 'error'
  # +:msg+      - human readable text
  # +:error+    - the kind of error that happened
  # +:action+   - an action the node was told to perform
  # +:event+    - an event on the server, e.g. 'boot'
  #
  # @todo lutter 2013-09-06: narrow down and document what actions and
  # events can be logged, together with the additional information for
  # each
  def log_append(entry)
    Razor::Data::Event.log_append({:hook => self}.merge(entry))
  end

  def view_object_reference(t)
    t && t.respond_to?('name') ? t.name : nil
  end

  def view_hash(cause, args = {})
    hook = self
    node = args[:node]
    policy = args[:policy] || (node && node.policy)
    # NOTE: Any updates to this view should be reflected in the `hooks.md`
    # file as well.
    {
        hook: {
            id: hook.id,
            name: hook.name,
            type: hook.hook_type.name,
            configuration: hook.configuration,
            cause: cause
        },
        node: node_hash(node),
        policy: policy_hash(policy)
    }
  end

  def node_hash(node)
    return nil unless node

    boot_stage = node.policy ? node.task.boot_template(node) : nil

    {
        :id            => node.id,
        :name          => node.name,
        :hw_info       => node.hw_hash,
        :dhcp_mac      => node.dhcp_mac,
        :tags          => node.tags.map { |t| view_object_reference(t) },
        :facts         => node.facts,
        :metadata      => node.metadata,
        :state         => {
            :installed    => node.installed || false,
            :installed_at => ts(node.installed_at),
            :stage        => boot_stage,
        }.delete_if { |_,v| v.nil? },
        :power => {
            :desired_power_state        => node.desired_power_state,
            :last_known_power_state     => node.last_known_power_state,
            :last_power_state_update_at => node.last_power_state_update_at
        }.delete_if { |_,v| v.nil? },
        :hostname      => node.hostname,
        :root_password => node.root_password,
        :ipmi          => { :hostname => node.ipmi_hostname,
                            :username => node.ipmi_username }.delete_if{ |_,v| v.nil? },
        :last_checkin  => ts(node.last_checkin)
    }.delete_if {|_,v| v.nil? or ( v.is_a? Hash and v.empty? ) }
  end

  def policy_hash(policy)
    policy ? { :id => policy.id,
               :name => policy.name,
               :repo => view_object_reference(policy.repo),
               :task => view_object_reference(policy.task),
               :broker => view_object_reference(policy.broker),
               :enabled => policy.enabled,
               :hostname_pattern => policy.hostname_pattern,
               :root_password => policy.root_password,
               :tags => policy.tags.map { |t| view_object_reference(t) },
               :nodes => {:count => policy.nodes.count},
    } : nil
  end

  def ts(date)
    date ? date.xmlschema : nil
  end
end
