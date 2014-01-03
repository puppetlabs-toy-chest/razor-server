module Razor::Data
  class Policy < Sequel::Model

    one_to_many  :nodes
    many_to_one  :repo
    many_to_many :tags
    many_to_one  :broker

    def recipe
      Razor::Recipe.find(recipe_name)
    end

    def validate
      super

      # Because we allow recipes in the file system, we do not have a fk
      # constraint on +recipe_name+; this check only helps spot simple
      # typos etc.
      begin
        self.recipe
      rescue Razor::RecipeNotFoundError
        errors.add(:recipe_name,
                   "recipe '#{recipe_name}' does not exist")
      end
    end

    def self.bind(node)
      node_tags = node.tags
      # The policies that could be bound must
      # - be enabled
      # - have at least one tag
      # - the tags must be a subset of the node's tags
      # - allow unlimited nodes (max_count is NULL) or have fewer
      #   than max_count nodes bound to them
      tag_ids = node.tags.map { |t| t.id }.join(",")
      sql = <<SQL
enabled is true
and
exists (select count(*) from policies_tags pt where pt.policy_id = policies.id)
and
(select array(select pt.tag_id from policies_tags pt where pt.policy_id = policies.id)) <@ array[#{tag_ids}]::integer[]
and
(max_count is NULL or (select count(*) from nodes n where n.policy_id = policies.id) < max_count)
SQL
      begin
        match = Policy.where(sql).order(:rule_number).first
        if match
          match.lock!
          # Make sure nobody raced us to binding to the policy
          if match.max_count.nil? or match.nodes.count < match.max_count
            node.bind(match)
            node.log_append(:event => :bind, :policy => match.name)
            node.save_changes
            break
          end
        end
      end while match && node.policy != match
    end
  end
end
