# -*- encoding: utf-8 -*-
module Razor::Help
  def summary(value = nil)
    if value = Razor::Help.scrub(value)
      value =~ /\n/ and
        raise ArgumentError, "Command summaries should be a single line.\n" +
                             "Put the long text into the 'description' instead."
      @summary = value
    end
    @summary
  end

  def description(value = nil)
    value = Razor::Help.scrub(value)
    value.nil? or @description = value
    @description
  end

  def example(value = nil)
    value = Razor::Help.scrub(value)
    value.nil? or @example = value
    @example
  end

  # A hook to allow us to check that documentation is correct without having
  # to pre-declare it all up front.
  def loading_complete
    super if defined?(super)
  end

  # Strip indentation and trailing whitespace from embedded doc fragments.
  #
  # Multi-line doc fragments are sometimes indented in order to preserve the
  # formatting of the code they're embedded in. Since indents are syntactic
  # elements in Markdown, we need to make sure we remove any indent that was
  # added solely to preserve surrounding code formatting, but LEAVE any
  # indent that delineates a Markdown element (code blocks, multi-line
  # bulleted list items). We can do this by removing the *least common
  # indent* from each line.
  #
  # Least common indent is defined as follows:
  #
  # * Find the smallest amount of leading space on any line...
  # * ...excluding the first line (which may have zero indent without affecting
  #   the common indent)...
  # * ...and excluding lines that consist solely of whitespace.
  # * The least common indent may be a zero-length string, if the fragment is
  #   not indented to match code.
  # * If there are hard tabs for some dumb reason, we assume they're at least
  #   consistent within this doc fragment.
  def self.scrub(string)
    return if string.nil?
    # ...now, make that a string!
    text = string.to_s
    # One-liners are easy!
    return text.strip if text.strip !~ /\n/
    # Otherwise, figure out the indent.
    excluding_first_line = text.partition("\n").last
    indent = excluding_first_line.scan(/^[ \t]*(?=\S)/).min || '' # prevent nil
    # Clean hanging indent, if any
    if indent.length > 0
      text = text.gsub(/^#{indent}/, '')
    end
    # Clean trailing space
    text.lines.map{|line|line.rstrip}.join("\n").rstrip
  end

  def included(where)
    fail "Razor::Help should be extended on a class, not included in one"
  end
end
