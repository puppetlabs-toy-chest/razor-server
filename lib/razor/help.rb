# -*- encoding: utf-8 -*-
module Razor::Help
  def summary(value = nil)
    if value = Razor::Help.scrub(value)
      value =~ /\n/ and
          raise ArgumentError, "Command summaries should be a single line.\n" +
              "Put the long text into the 'description' instead."
      @summary = value
    end
    # If we don't have a summary yet, generate one from the first line of the
    # description (if possible) and stash it away.
    @summary ||= (description and description.split(/[.\n]/).first)
  end

  def description(value = nil)
    value = Razor::Help.scrub(value)
    value.nil? or @description = value
    @description
  end

  def example(value)
    value = { :api => value } if value.is_a?(String)
    value.is_a?(Hash) or raise ArgumentError, "unexpected datatype '%{class}' for example" % {class: value.class}

    @examples ||= {}
    value.each do |key, value|
      [:cli, :api].include?(key) or raise ArgumentError, "unexpected type '%{type}' for example" % {type: key}
      raise ArgumentError, "Examples already declared for type #{key}" if @examples[key]
      @examples[key] = Razor::Help.scrub(value)
    end
    @examples
  end

  def examples
    @examples
  end

  def returns(value = nil)
    value = Razor::Help.scrub(value)
    value.nil? or @returns = value
    @returns
  end


  # Format the help text into something usable by the client.
  # See the bottom of the file for the actual templates.
  HelpTemplates = Hash.new {|_, name| raise ArgumentError, _("unknown help format #{name}") }
  def help(format = nil)
    if format
      make_templates(HelpTemplates[format])
    else
      # These top-level templates are special cases because they should only be included if their corresponding
      # attribute is present ('summary' to '@summary'). Otherwise, we'll be generating blank ERB templates for
      # help formats that shouldn't be present. E.g. If '@returns' is absent, the 'returns' template should be too.
      templates = HelpTemplates.reject do |template_key, template_erb|
        case template_key
          when 'summary'
            summary.nil?
          when 'description'
            description.nil?
          when 'returns'
            returns.nil?
          when 'examples'
            examples.nil?
          when 'schema'
            schema.help.nil?
          else
            false
        end
      end
      templates.merge(make_templates(templates))
    end
  end

  def make_templates(templates)
    if templates.is_a?(ERB)
      templates.result(binding)
    elsif templates.is_a?(Hash)
      # produce a new hash with the same output keys, but mutated output values
      templates.merge(templates) {|_, arr| make_templates(arr)}
    end
  end

  # A hook to allow us to check that documentation is correct without having
  # to pre-declare it all up front.
  def loading_complete
    super if defined?(super)
    @description or fail "#{self.class} does not have a description"
  end

  def included(where)
    fail "Razor::Help should be extended on a class, not included in one"
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

  HelpTemplates['summary'] = ERB.new(scrub(_('<%= summary %>')), nil, '%')
  HelpTemplates['description'] = ERB.new(scrub(_('<%= description %>')), nil, '%')
  HelpTemplates['returns'] = ERB.new(scrub(_('<%= returns %>')), nil, '%')
  HelpTemplates['schema'] = ERB.new(scrub(_('<%= schema.help %>')), nil, '%')
  HelpTemplates['examples'] = {}
  HelpTemplates['examples']['api'] = ERB.new(scrub(_('<%= examples[:api] %>')), nil, '%')
  HelpTemplates['examples']['cli'] = ERB.new(scrub(_('<%= examples[:cli] %>')), nil, '%')

  HelpTemplates['full'] = ERB.new(scrub(_(<<-ERB)), nil, '%')
% if summary.nil? and description.nil?
Unfortunately, the `<%= name %>` command has not been documented.
% else
% # summary, description, examples[:api]
# SYNOPSIS
<%= summary %>

# DESCRIPTION
<%= description %>
%
% # Add schema documentation so the user understands the methods and structure
% # of the code that they are working with.
<%= schema.help %>
%
% if returns
# RETURNS
<%= returns.gsub(/^/, '  ') %>
% end
%
% if examples && examples[:api]
# EXAMPLES

<%= examples[:api].gsub(/^/, '  ') %>
% end
% end
  ERB
end
