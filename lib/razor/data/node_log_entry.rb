# -*- encoding: utf-8 -*-
module Razor::Data
  class NodeLogEntry < Sequel::Model
    plugin :serialization, :json, :entry
    many_to_one :node
  end
end
