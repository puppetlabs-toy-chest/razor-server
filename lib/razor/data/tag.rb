# -*- encoding: utf-8 -*-
class Razor::Data::Tag < Sequel::Model
  plugin :serialization

  serialize_attributes [
    ->(m) { m.serialize },
    ->(m) { Razor::Matcher.unserialize(m) }
  ], :matcher


  many_to_many :policies
  many_to_many :nodes

  def rule
    matcher.rule if matcher
  end

  def rule=(r)
    self.matcher = Razor::Matcher.new(r)
  end

  def match?(node)
    matcher.match?("facts" => node.facts, "metadata" => node.metadata,
                   "state" => { "installed" => node.installed })
  end

  def self.match(node)
    self.all.select { |tag| tag.match?(node) }
  end

  # This is the same hack around auto_validation as in +Node+
  def schema_type_class(k)
    case k
    when :matcher then Razor::Matcher
    else super
    end
  end

  def validate
    super
    unless matcher.nil?
      if matcher.is_a?(Razor::Matcher)
        errors[:matcher] = matcher.errors unless matcher.valid?
      else
        errors.add(:matcher, _("is not a matcher object"))
      end
    end
  end

  def around_save
    # We need to defer publishing eval_nodes until after self has been
    # saved so that for newly created nodes the message includes the actual
    # id
    need_eval_nodes = new? || changed_columns.include?(:matcher)
    super
    publish('eval_nodes') if need_eval_nodes
  end

  def eval_nodes
    Razor::Data::Node.all.each do |node|
      node_tags = node.tags

      begin
        if self.match?(node)
          unless node_tags.include?(self)
            node.add_tag(self)
          end
        else
          if node_tags.include?(self)
            node.remove_tag(self)
          end
        end
      rescue Razor::Matcher::RuleEvaluationError => e
        node.log_append(
          severity: :error,
          error: 'tag_match',
          msg: "Matching tag '#{name}': " + e.message)
        # @todo lutter 2014-05-16: eventually, we need the command that
        # causes eval_nodes to be called here and report the evaluation
        # failure as part of the command, too.  This will require passing
        # the command through a call to Tag#save and involves some
        # gymnastics. Once we move background processing of commands into
        # the commands, this will be much easier to achieve
      end
    end
    self
  end

  # Find an existing tag or create a new one from the Hash in +data+. If a
  # tag with +data["name"] already exists, and +data["rule"]+ is present,
  # it must equal the rule of the existing tag.
  #
  # If no tag with name +data["name"]+ exists yet, +data["rule"]+ must be
  # present, and will be used as the rule of the new tag.
  #
  # Violation of these rules lead to an +ArgumentError+ being thrown.
  def self.find_or_create_with_rule(data)
    name = data['name']
    if tag = find(:name => name)
      data["rule"].nil? or data["rule"] == tag.rule or
        raise ArgumentError, _("Provided rule and existing rule for existing tag '%{name}' must be equal") % {name: name}
      tag
    else
      data["rule"] or
        raise ArgumentError, _("A rule must be provided for new tag '%{name}'") % {name: name}
      create(data)
    end
  end
end
