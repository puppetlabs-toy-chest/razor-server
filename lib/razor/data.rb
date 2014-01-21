# The persistence layer of Razor; these classes are the primary interface
# to the Database. Usually, these would be called 'models', but Razor uses
# the term to mean something else.
module Razor::Data; end

# Configure global model plugins; these require a database connection, so
# much be established now that we have one.
#
# Infer, and extract, database constraints into the Ruby layer.  This makes
# `valid?` and `errors` on model objects work much more nicely -- by reading
# the database constraints and implementing them in Ruby automatically,
# rather than by lifting all validation into the application.
Sequel::Model.plugin :constraint_validations
Sequel::Model.plugin :auto_validations

# Add a `publish` method to all Sequel::Model objects, allowing them to be
# sent messages through the TorqueBox message queue system.
Sequel::Model.plugin Razor::Messaging::Sequel::Plugin

require_relative 'data/task'
require_relative 'data/repo'
require_relative 'data/policy'
require_relative 'data/tag'
require_relative 'data/node_log_entry'
require_relative 'data/node'
require_relative 'data/broker'
