require 'json'

# This class provides a generic matcher for rules/conditions
#
# It is assumed that rules are expressed as JSON arrays, using Lisp-style
# infix notation. An example of a condition would be
#
#   ["and" ["=" ["fact" "osfamily"] "RedHat"]
#          ["in" ["fact" "macaddress"]
#                "de:ea:db:ee:f0:00" "..MAC.." "..MAC.."]]
#
# The overall syntax for calling a builtin function is
#   [op arg1 arg2 .. argn]
#
# The builtin operators are (see +Functions+)
#   and, or - true if anding/oring arguments is true
#   =, !=   - true if arg1 =/!= arg2
#   in      - true if arg1 is one of arg2 .. argn
#   fact    - retrieves the fact named arg1 from the node if it exists
#             If not, an error is raised unless a second argument is given, in
#             which case it is returned as the default.
#   num     - converts arg1 to a numeric value if possible; raises if not
#   <, <=   - true if arg1 </<= arg2
#   >, >=   - true if arg1 >/>= arg2
#
# FIXME: This needs lots more error checking to become robust
class Razor::Matcher

  Boolean = [TrueClass, FalseClass]
  Mixed = [String, *Boolean, Numeric, NilClass]
  Number = [Numeric]

  class RuleEvaluationError < ArgumentError
    def rule=(rule)
      @rule = rule
    end

    def to_s
      super + " while evaluating rule: #{@rule}"
    end
  end

  class Functions
    ALIAS = {
      "=" => "eq",
      "!=" => "neq",
      ">" => "gt",
      ">=" => "gte",
      "<" => "lt",
      "<=" => "lte",
      }.freeze

    ATTRS = {
        "and"      => {:expects => [Boolean],         :returns => Boolean },
        "or"       => {:expects => [Boolean],         :returns => Boolean },
        "not"      => {:expects => [Boolean],         :returns => Boolean },
        "fact"     => {:expects => [[String], Mixed], :returns => Mixed   },
        "metadata" => {:expects => [[String], Mixed], :returns => Mixed   },
        "tag"      => {:expects => [[String]],        :returns => Mixed   },
        "state"    => {:expects => [[String], [String]], :returns => Mixed   },
        "eq"       => {:expects => [Mixed],           :returns => Boolean },
        "neq"      => {:expects => [Mixed],           :returns => Boolean },
        "in"       => {:expects => [Mixed],           :returns => Boolean },
        "num"      => {:expects => [Mixed],           :returns => Number  },
        "gte"      => {:expects => [[Numeric]],       :returns => Boolean },
        "gt"       => {:expects => [[Numeric]],       :returns => Boolean },
        "lte"      => {:expects => [[Numeric]],       :returns => Boolean },
        "lt"       => {:expects => [[Numeric]],       :returns => Boolean },
      }.freeze

    # FIXME: This is pretty hackish since Ruby semantics will shine through
    # pretty hard (e.g., truthiness, equality, type conversion from JSON)
    def initialize(values)
      @values = values
    end

    def and(*args)
      args.all? { |a| a }
    end

    def or(*args)
      args.any? { |a| a }
    end

    def not(*args)
      not args[0]
    end

    # Returns the fact named #{args[0]}
    #
    # If no fact with the specified name exists, args[1] is returned if given.
    # If no fact exists and args[1] is not given, an ArgumentError is raised.
    def fact(*args)
      value_lookup("facts", args)
    end

    def metadata(*args)
      value_lookup("metadata", args)
    end

    def tag(*args)
      unless t = Razor::Data::Tag[:name => args[0]]
        raise RuleEvaluationError.new "Tag '#{args[0]}' does not exist"
      end
      # This is a bit ugly: we really just want to call t.match? but that
      # takes a node, and we only have the values Hash here. So we peek a
      # little too deeply into the tag.
      t.matcher.match?(@values)
    end

    def state(*args)
      value_lookup("state", args)
    end

    def eq(*args)
      args[0] == args[1]
    end

    def neq(*args)
      args[0] != args[1]
    end

    def in(*args)
      needle = args.shift
      args.include?(needle)
    end

    def num(*args)
      value = args[0]
      begin
        return value if value.is_a?(Numeric)
        if value.is_a? String
          # Make sure binary and octal integers get passed to Integer since
          # Float can't handle them
          return Integer(value) if value =~ /\A-?(0b[10]+  |  0[0-7]+)\Z/ix
          return Float(value)
        end
      rescue ArgumentError => e
        # Ignore this here, since a RuleEvaluationError will be raised later
      end

      raise RuleEvaluationError.new "can't convert #{value.inspect} to number"
    end

    def gte(*args)
      args[0] >= args[1]
    end

    def gt(*args)
      args[0] > args[1]
    end

    def lte(*args)
      args[0] <= args[1]
    end

    def lt(*args)
      args[0] < args[1]
    end

    private
    def value_lookup(map_name, args)
      map = @values[map_name]
      case
      when map.include?(args[0]) then map[args[0]]
      when args.length > 1 then args[1]
      else
        name = map_name == "facts" ? "fact" : map_name
        raise RuleEvaluationError.new "Couldn't find #{name} '#{args[0]}' and no default supplied"
      end
    end
  end

  def self.unserialize(rule_json)
    rule_hash = JSON.parse(rule_json)

    unless rule_hash.keys.sort == ["rule"]
      raise "Invalid matcher; couldn't unserialize #{rule_hash}"
    end

    self.new(rule_hash["rule"])
  end

  def serialize
    { "rule" => @rule }.to_json
  end

  attr_reader :rule
  # +rule+ must be an Array
  def initialize(rule)
    raise TypeError.new("rule is not an array") unless rule.is_a? Array
    @rule = rule.freeze
  end

  def match?(values)
    fns = Functions.new(values)
    evaluate(@rule, fns) ? true : false
  rescue RuleEvaluationError => e
    e.rule = @rule
    raise
  end

  def valid?
    # Matchers should return boolean expressions
    validate(@rule, Boolean)
    errors.empty?
  end

  def errors
    @errors ||=[]
  end

  private
  def evaluate(rule, fns)
    r = rule.map do |arg|
      if arg.is_a?(Array)
        evaluate(arg, fns)
      else
        arg
      end
    end
    r[0] = Functions::ALIAS[r[0]] || r[0]
    fns.send(*r)
  end

  def validate(rule, required_returns)
    errors.clear

    # This error is fatal; all further validation assumes rule is an array
    return errors << "must be an array" unless rule.is_a?(Array)

    return errors << "must have at least one argument" unless rule.size >= 2

    # This error is also fatal; if a type isn't accepted here, it certainly
    # won't be later.
    return unless rule.flatten.all? do |arg|
      if Mixed.any? {|type| arg.class <= type }
        true
      else
        errors << "cannot process objects of type #{arg.class}" and false
      end
    end

    attrs = Functions::ATTRS[Functions::ALIAS[rule[0]] || rule[0]]
    unless attrs
      # This error is fatal since unknown operators have unknown requirements
      errors << "uses unrecognized operator '#{rule[0]}'; recognized " +
                "operators are #{Functions::ATTRS.keys+Functions::ALIAS.keys}"
      return false
    end

    # Ensure all returned types are in required_returns, or that they
    # are subclasses of classes in required_returns
    attrs[:returns].each do |return_type|
      unless required_returns.any? {|allowed_type| return_type <= allowed_type}
        errors << "attempts to return values of type #{return_type} from " +
                  "#{rule[0]}, but only #{required_returns} are allowed"
      end
    end

    rule.drop(1).each_with_index do |arg, pos|
      expected_types = attrs[:expects][pos] || attrs[:expects].last
      if arg.is_a? Array
        validate(arg, expected_types)
      else
        # Ensure all concrete objects are of expected types
        unless expected_types.any? {|type| arg.class <= type }
          errors << "attempts to pass #{arg.inspect} of type #{arg.class} to "+
                    "'#{rule[0]}' for argument #{pos}, but only "+
                    "#{expected_types} are accepted"
        end
      end
    end
  end
end
