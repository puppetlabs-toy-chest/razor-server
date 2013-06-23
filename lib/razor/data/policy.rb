module Razor::Data
  class Policy < Sequel::Model

    one_to_many :nodes
    many_to_one :image
    many_to_many :tags

    def installer
      Razor::Installer.find(installer_name)
    end

    def self.bind(node)
      # FIXME: Do this without loading all policies from the DB
      node_tags = node.tags
      # FIXME: Handle max_count
      match = Policy.where(:enabled => true).order(:sort_order).all.find do |p|
        p.tags.size > 0 && p.tags.all? { |t| node_tags.include?(t) }
      end
      if match
        node.bind(match)
        node.save
      end
    end
  end
end
