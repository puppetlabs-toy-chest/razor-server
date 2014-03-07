# -*- encoding: utf-8 -*-
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
      super + _(" while evaluating rule: %{rule}") % {rule: @rule}
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
        raise RuleEvaluationError.new(_("Tag '%{name}' does not exist") % {name: args[0]})
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

      raise RuleEvaluationError.new _("can't convert %{raw} to number") % {raw: value.inspect}
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
        raise RuleEvaluationError.new _("Couldn't find %{name} '%{raw}' and no default supplied") % {name: name, raw: args[0]}
      end
    end
  end

  def self.unserialize(rule_json)
    rule_hash = JSON.parse(rule_json)

    unless rule_hash.keys.sort == ["rule"]
      raise _("Invalid matcher; couldn't unserialize %{rule_hash}") % {raw: rule_hash}
    end

    self.new(rule_hash["rule"])
  end

  def serialize
    { "rule" => @rule }.to_json
  end

  attr_reader :rule
  # +rule+ must be an Array
  def initialize(rule)
    raise TypeError.new(_("rule is not an array")) unless rule.is_a? Array
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

  def validate(rule, required_returns, caller_name = nil, caller_position = nil)
    errors.clear

    # This error is fatal; all further validation assumes rule is an array
    return errors << _("must be an array") unless rule.is_a?(Array)

    return errors << _("must have at least one argument") unless rule.size >= 2

    # This error is also fatal; if a type isn't accepted here, it certainly
    # won't be later.
    return unless rule.flatten.all? do |arg|
      if Mixed.any? {|type| arg.class <= type }
        true
      else
        errors << _("cannot process objects of type %{class}") % {class: arg.class}
        false
      end
    end

    name = rule[0]
    attrs = Functions::ATTRS[Functions::ALIAS[name] || name]
    unless attrs
      # This error is fatal since unknown operators have unknown requirements
      errors << _("uses unrecognized operator '%{name}'; recognized operators are %{operators}") %
        {name: name, operators: Functions::ATTRS.keys+Functions::ALIAS.keys}
      return false
    end

    # Ensure all returned types are in required_returns, or that they
    # are subclasses of classes in required_returns
    # E.g. Select returns that are not subclasses of any required returns
    outliers = attrs[:returns].select { |ret| required_returns.none? { |allowed| ret <= allowed } }
    unless outliers.empty?
      if caller_name.nil? then
        errors << _("could return incompatible datatype(s) from function '%{name}' (%{outliers}). Rule expects (%{required_returns})") %
            {name: name, outliers: outliers, required_returns: required_returns}
      else
        errors << _("could return incompatible datatype(s) from function '%{name}' (%{outliers}) for argument %{position}. Function '%{caller_name}' expects (%{required_returns})") %
            {name: name, outliers: outliers, position: caller_position, required_returns: required_returns, caller_name: caller_name}
      end
    end

    rule.drop(1).each_with_index do |arg, pos|
      expected_types = attrs[:expects][pos] || attrs[:expects].last
      if arg.is_a? Array
        validate(arg, expected_types, name, pos)
      else
        # Ensure all concrete objects are of expected types
        unless expected_types.any? {|type| arg.class <= type }
          errors << _("attempts to pass %{arg} of type %{type} to "+
                    "'%{name}' for argument %{position}, but only "+
                    "%{expected} are accepted") %
            {arg: arg.inspect, type: arg.class, name: name, position: pos, expected: expected_types}
        end
      end
    end
  end
end
