# This class provides a generic matcher for rules/conditions
#
# It is assumed that rules are expressed as JSON arrays, using Lisp-style
# infix notation. An example of a condition would be
#
#   ["and" ["=" ["facts" "osfamily"] "RedHat"]
#          ["in" ["facts" "macaddress"]
#                "de:ea:db:ee:f0:00" "..MAC.." "..MAC.."]]
#
# The overall syntax for calling a builtin function is
#   [op arg1 arg2 .. argn]
#
# The builtin operators are (see +Functions+)
#   and, or - true if anding/oring arguments is true
#   =, !=   - true if arg1 =/!= arg2
#   in      - true if arg1 is one of arg2 .. argn
#
# FIXME: This needs lots more error checking to become robust
class Razor::Matcher
  class Functions
    ALIAS = { "=" => "eq", "!=" => "neq" }

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

    def fact(*args)
      @values["facts"][args[0]]
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
  end

  # +rule+ must be an Array
  def initialize(rule)
    @rule = rule
  end

  def match?(values)
    fns = Functions.new(values)
    evaluate(@rule, fns) ? true : false
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
end
