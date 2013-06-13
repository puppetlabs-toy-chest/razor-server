
# The persistence layer of Razor; these classes are the primary interface
# to the Database. Usually, these would be called 'models', but Razor uses
# the term to mean something else.
module Razor::Data; end

require_relative 'data/active_model'
require_relative 'data/node'
