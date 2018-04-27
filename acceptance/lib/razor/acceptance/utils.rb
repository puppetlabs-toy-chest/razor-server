# -*- encoding: utf-8 -*-
require 'tmpdir'
require 'shellwords'

require 'net/ssh'

# This exists to fix a bug in Net::SSH that precludes
# the sending of unicode characters over the wire. There
# is an issue to fix this in Beaker, but meanwhile, this
# fix will do.
class Net::SSH::Buffer
  def write(*data)
    data.each { |datum|
      @content << datum.dup.force_encoding('BINARY')
    }
    self
  end
end

# Collection of general helpers that get used in our tests.

def reset_database(where = agents, clear_queue = true)
  step 'Reset the razor database to a blank slate'
  on where, 'env TORQUEBOX_FALLBACK_LOGFILE=/dev/null ' +
    '/opt/puppetlabs/bin/razor-admin -e production reset-database'
  on where, 'curl -kfX POST https://localhost:8151/api/commands/dequeue-message-queues' if clear_queue
end

def razor(where, what, args = nil, options = {}, &block)
  case args
  when String then json = args
  when Hash   then json = args.to_json
  end

  # translate this to something nicer
  options[:exit] and options[:acceptable_exit_codes] = Array(options.delete(:exit))

  # This may never be used, but is cheap to generate.
  file = '/tmp/' + Dir::Tmpname.make_tmpname(['razor-json-input-', '.json'], nil)

  if json
    teardown { on where, "rm -f #{file}" }

    step "Create the JSON file containing the #{what} command on agents"
    create_remote_file where, file, json
  end

  Array(where).each do |node|
    step "Run #{what} on #{node}"
    cmd = "razor #{what} " +
      (json ? "--json #{file}" : Array(args).shelljoin)

    output = on(node, cmd, options).output

    block and case block.arity
              when 0 then yield
              when 1 then yield node
              when 2 then yield node, output
              else raise "unknown arity #{block.arity} for razor helper!"
              end
  end
end

# This method will create a policy in addition to the dependencies needed for that:
# - Repo (creation can be bypassed by using :repo_name)
# - Broker (creation can be bypassed by using :broker_name)
#
# [Optional]: This can also create and/or associate a tag.
# => Tag creation: :create_tag = true
# => Name/reference: :tag_name
#
# :task_name, :broker_type, and :policy_max_count can also be specified to alter the behavior.
#
# A block provided to this method will be executed inside the create-policy call, with
# `agent` and `output` as optional parameters to the block.
def create_policy(agents, args = {}, positional = false, &block)
  def has_key_or_default(args, key, default)
    args.has_key?(key) ? args[key] : default
  end
  policy_name = has_key_or_default(args, :policy_name, 'puppet-test-policy')
  # Use :tag_name for reference, :create_tag for creation
  tag_name = has_key_or_default(args, :tag_name, (args[:create_tag] && 'small'))
  repo_name = has_key_or_default(args, :repo_name, "centos-6.4")
  broker_name = has_key_or_default(args, :broker_name, 'noop')
  broker_type = has_key_or_default(args, :broker_type,'noop')
  task_name = has_key_or_default(args, :task_name, "centos")
  max_count = has_key_or_default(args, :policy_max_count, 20)

  unless args[:just_policy]
    razor agents, 'create-tag', {
        "name" => tag_name,
        "rule" => ["=", ["fact", "processorcount"], "2"]
    } if args[:create_tag]
    razor agents, 'create-repo', {
        "name" => repo_name,
        "url"  => 'http://provisioning.example.com/centos-6.4/x86_64/os/',
        "task" => task_name
    } unless args.has_key?(:repo_name)
    razor agents, 'create-broker', {
        "name"        => broker_name,
        "broker-type" => broker_type
    } unless args.has_key?(:broker_name)
  end

  json = {
      'name'          => policy_name,
      'repo'          => repo_name,
      'task'          => task_name,
      'broker'        => broker_name,
      'enabled'       => true,
      'hostname'      => "host${id}.example.com",
      'root-password' => "secret",
      'max-count'     => max_count,
      'tags'          => tag_name.nil? ? [] : [tag_name]
  }
  # Workaround; max-count cannot be nil
  json.delete('max-count') if max_count.nil?


  if positional
      razor agents, "create-policy #{policy_name} --repo #{repo_name} --task #{task_name} --broker #{broker_name} --hostname host${id}.example.com --root-password secret --max-count #{max_count} --tags #{tag_name.nil? ? [] : [tag_name]}" do |agent, output|
        step "Verify that the policy is defined on #{agent}"
        text = on(agent, "razor -u https://#{agent}:8151/api policies '#{policy_name}'").output
        assert_match /#{Regexp.escape(policy_name)}/, text
        block and case block.arity
                    when 0 then yield
                    when 1 then yield agent
                    when 2 then yield agent, output
                    else raise "unexpected arity #{block.arity} for create_policy!"
                  end
      end
  else
    {policy: {:name => policy_name, :max_count => max_count}, repo_name: repo_name,
     broker: {:broker_name => broker_name, :broker_type => broker_type},
     tag_name: tag_name, task_name: task_name}.tap do |return_hash|
      razor agents, 'create-policy', json do |agent, output|
        step "Verify that the policy is defined on #{agent}"
        text = on(agent, "razor -u https://#{agent}:8151/api policies '#{policy_name}'").output
        assert_match /#{Regexp.escape(policy_name)}/, text
        block and case block.arity
                    when 0 then yield
                    when 1 then yield agent
                    when 2 then yield agent, output
                    when 3 then yield agent, output, return_hash
                    else raise "unexpected arity #{block.arity} for create_policy!"
                  end
      end
    end
  end

end

# This excludes, by default:
# "\" => illegal character in URLs. (Encoded as %5C)
# "'" => used as string-surrounding character on command line
def unicode_string(length = 50, exclude = "")
  # Why are these characters excluded? Well...
  # - "\", "[", and "]" cause problems with the combination of URI.parse and
  #   URI.escape. We can avoid them for these tests, but this may require
  #   more server-side monkey-patching for proper support. As a test, try:
  #   `URI.parse(URI.escape("http://abc.com/\\["))`
  # - "'" causes problems with CLI, since we surround strings with
  #   that character.
  # - "?" and "/" are not currently properly encoded in URLs.
  #   Pending a RAZOR-334 fix, this can be removed.
  exclude = (exclude + "\\?/'[]").split(//).map(&:ord)
  min = 32
  (1..length).map do |index|
    max = 45295
    # Prioritize potentially problematic characters for long strings.
    max = 70 if length > 150 && index < 50
    ord = rand(max - min + 1) + min
    redo if exclude.include?(ord)
    chr = ord.chr('UTF-8')
    redo if is_illegal(chr, index, length)
    chr
  end.join.tap do |string|
    step "Using unicode string of #{string}"
  end
end

def is_illegal(char, position, length)
  if position == 1 or position == length
    # This comes from util.rb, used in the database.
    return true if
        char =~ %r'[\u0000-\u0020/\u0085\u00a0\u1680\u180e\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]'i
    # No dash at the start to prevent '--', which is interpreted as a new param
    position == 1 and char =~ /-/
  else
    # Middle characters here
    char =~ %r'[\u0000-\u001f/]'i
  end
end

def long_unicode_string(exclude = "")
  unicode_string(250, exclude)
end

def ascii_data
  @ascii_data ||= [('a'..'z'), ('A'..'Z'), ('0'..'9'), %w(- _)].map(&:to_a).flatten
end
def long_string(length = 250)
  name = (1..length).map { ascii_data[rand(ascii_data.length)] }.join
  # Shouldn't start with "--" to avoid ambiguity with CLI arguments.
  name = long_string(length) if name =~ /^--/
  name
end
