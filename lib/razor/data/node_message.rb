module Razor::Data
  class NodeMessage < Sequel::Model
    plugin :serialization, :json, :message
    many_to_one :node
  end
end
