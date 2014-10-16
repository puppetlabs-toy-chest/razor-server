#!/usr/bin/env ruby
require 'json'

node = ARGV.shift

begin
  node = JSON.load(node)
rescue
  raise RuntimeError, "Could not load node from JSON"
end

output = {
  'update' => {
    'id' => node['id']
  }
}

puts output.to_json
exit 0
