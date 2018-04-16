# -*- encoding: utf-8 -*-

module Razor
  module Spec
    module CollectionSchemas
      # Schema for a response returned via. the /api/collections/<coll_type>
      # endpoint. 
      def collection_schema(item_schema = object_ref_item_schema)
        {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'title'    => "Object Reference Collection JSON Schema",
          'type'     => 'object',
          'additionalProperties' => false,
          'properties' => {
            "spec" => {
              'type'    => 'string',
              'pattern' => '^https?://'
            },
            "items" => {
              'type'    => 'array',
              'items'    => item_schema
            },
            'total' => {
                'type'     => 'number'
            }
          }
        }.freeze
      end
    
      def validate_schema!(schema, json)
        # Why does the validate method insist it should be able to modify
        # my schema?  That would be, y'know, bad.
        JSON::Validator.validate!(schema.dup, json, :validate_schema => true)
      end

      # Unfortunately, it's a bit painful to get RSpec to include a module's
      # contants in example groups, so we encapsulate our item schemas in
      # methods instead.

      # JSON schema for collections where we only send back object references;
      # these are the same no matter what the underlying collection elements
      # look like
      def object_ref_item_schema
       {
          'type'     => 'object',
          'additionalProperties' => false,
          'properties' => {
            "spec" => {
              'type'    => 'string',
              'pattern' => '^https?://'
            },
            "id" => {
              'type'    => 'string',
              'pattern' => '^https?://'
            },
            "name" => {
              'type'    => 'string',
              'pattern' => '^[^\n]+$'
            }
          }
        }
      end
    
      # Schemas for each of the Razor::Data items. 
      def policy_item_schema 
        {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'title'    => "Broker Collection JSON Schema",
          'type'     => 'object',
          'required' => %w[spec id name configuration enabled max_count node_metadata repo task broker],
          'properties' => {
            'spec' => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'id'       => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'name'     => {
              'type'     => 'string',
              'pattern'  => '^[a-zA-Z0-9 ]+$'
            },
            'configuration' => {
              'type'    => 'object',
              'properties' => {
                 'hostname_pattern' => {
                   'type' => 'string',
                 },
                 'root_password' => {
                   'type' => 'string',
                 }
               },
              'additionalProperties' => false,
            },
            'enabled' => {
              'type' => 'boolean',
            },
            'max_count' => {
              'type' => 'integer',
            },
            'node_metadata' => {
              'type' => 'object',
            },
            'repo' => object_ref_item_schema,
            'task' => object_ref_item_schema,
            'broker' => object_ref_item_schema,
            'nodes' => {
              'type' => 'object',
            },
            'tags' => {
              'type' => 'array',
              'items' => object_ref_item_schema,
            },
          },
          'additionalProperties' => false,
        }.freeze
      end
    
      def tag_item_schema
        {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'title'    => "Task Item JSON Schema",
          'type'     => 'object',
          'required' => %w[spec id name rule nodes policies],
          'properties' => {
            'spec' => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'id'       => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'name'     => {
              'type'     => 'string',
            },
            'rule' => {
              'type'     => 'array',
            },
            'nodes' => {
              'type'     => 'object',
            },
            'policies' => {
              'type'     => 'object',
            },
          },
          'additionalProperties' => false,
        }.freeze
      end
    
      def repo_item_schema
        {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'title'    => "Task Item JSON Schema",
          'type'     => 'object',
          'required' => %w[spec id name iso_url task],
          'properties' => {
            'spec' => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'id'       => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'name'     => {
              'type'     => 'string',
            },
            'iso_url' => {
              'type'     => 'string',
            },
            'url' => {
              'type'     => [ 'string', 'null' ]
            },
            'task' => {
              'type'    => 'object',
            },
          },
          'additionalProperties' => false,
        }.freeze
      end

      # @todo lutter 2013-10-08: I would like to pull the schema for the base
      # property out into a ObjectReferenceSchema and make the base property
      # a $ref to that. My attempts at doing that have failed so far, because
      # json-schema fails when we validate against the resulting
      # task_item_schema, complaining that the schema for base is not
      # valid
      #
      # Note that to use a separate ObjectReferenceSchema, we have to
      # register it first with the Validator:
      #   url = "http://api.puppetlabs.com/razor/v1/reference"
      #   ObjectReferenceSchema['id'] = url
      #   sch = JSON::Schema::new(ObjectReferenceSchema, url)
      #   JSON::Validator.add_schema(sch)
      def task_item_schema 
        {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'title'    => "Task Item JSON Schema",
          'type'     => 'object',
          'required' => %w[spec id name os],
          'properties' => {
            'spec' => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'id'       => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'name'     => {
              'type'     => 'string',
              'pattern'  => '^[a-zA-Z0-9_/]+$'
            },
            'base'     => {
              'title'    => "Object Reference Schema",
              'type'     => 'object',
              'required' => %w[spec id name],
              'properties' => {
                'spec' => {
                  'type'     => 'string',
                  'pattern'  => '^https?://'
                },
                'id'       => {
                  'type'     => 'string',
                  'pattern'  => '^https?://'
                },
                'name'     => {
                  'type'     => 'string',
                  'pattern'  => '^[a-zA-Z0-9_/]+$'
                }
              },
              'additionalProperties' => false
            },
            'description' => {
              'type'     => 'string'
            },
            'os' => {
              'type'    => 'object',
              'properties' => {
                'name' => {
                  'type' => 'string'
                },
                'version' => {
                  'type' => 'string'
                }
              }
            },
            'boot_seq' => {
              'type' => 'object',
              'required' => %w[default],
              'patternProperties' => {
                "^([0-9]+|default)$" => {}
              },
              'additionalProperties' => false,
            }
          },
          'additionalProperties' => false,
        }.freeze
      end
    
      def broker_item_schema
        {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'title'    => "Broker Collection JSON Schema",
          'type'     => 'object',
          'required' => %w[spec id name configuration broker_type],
          'properties' => {
            'spec' => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'id'       => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'name'     => {
              'type'     => 'string',
              'pattern'  => '^[a-zA-Z0-9 ]+$'
            },
            'broker_type' => {
              'type'     => 'string',
              'pattern'  => '^[a-zA-Z0-9 ]+$'
            },
            'configuration' => {
              'type'    => 'object',
              'additionalProperties' => {
                'oneOf'     => [
                  {
                    'type'      => 'string',
                    'minLength' => 1
                  },
                  {
                    'type'      => 'number',
                  }
                ]
              }
            },
            'policies'     => {
              'type'    => 'object',
              'required' => %w[id count name],
              'properties' => {
                'id'   => {
                  'type'     => 'string',
                  'pattern'  => '^https?://'
                },
                'count'     => {
                  'type'     => 'integer'
                },
                'name'     => {
                  'type'     => 'string',
                  'pattern'  => '^[a-zA-Z0-9 ]+$'
                }
              }
            }
          },
          'additionalProperties' => false,
        }.freeze
      end
    
      def node_item_schema
        {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'title'    => "Node Collection JSON Schema",
          'type'     => 'object',
          'required' => %w[spec id name],
          'properties' => {
            'spec' => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'id'       => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'name'     => {
              'type'     => 'string',
              'pattern'  => '^node[0-9]+$'
            },
            'hw_info'    => {
              'type'     => 'object'
            },
            'dhcp_mac' => {
              'type'     => 'string',
              'pattern'  => '^[0-9a-fA-F]+$'
            },
            'log'   => {
              'type'       => 'object',
              'required'   => %w[id name],
              'properties' => {
                'id'       => {
                  'type'     => 'string',
                  'pattern'  => '^https?://'
                },
                'name'     => {
                  'type'      => 'string',
                  'minLength' => 1
                },
              },
            },
            'tags'     => {
              'type'       => 'array',
              'items'      => {
                'type'       => 'object',
                'required'   => %w[id name spec],
                'properties'  => {
                  'id'       => {
                    'type'     => 'string',
                    'pattern'  => '^https?://'
                  },
                  'name'     => {
                    'type'      => 'string',
                    'minLength' => 1
                  },
                  'spec' => {
                    'type'     => 'string',
                    'pattern'  => '^https?://'
                  },
                },
              },
            },
            'policy'   => {
              'type'       => 'object',
              'required'   => %w[spec id name],
              'properties' => {
                'spec' => {
                  'type'     => 'string',
                  'pattern'  => '^https?://'
                },
                'id'       => {
                  'type'     => 'string',
                  'pattern'  => '^https?://'
                },
                'name'     => {
                  'type'      => 'string',
                  'minLength' => 1
                },
              },
              'additionalProperties' => false,
            },
            'facts' => {
              'type'          => 'object',
              'minProperties' => 1,
              'additionalProperties' => {
                'type'      => 'string',
                'minLength' => 0
              }
            },
            'metadata' => {
              'type'          => 'object',
              'minProperties' => 0,
              'additionalProperties' => {
                'type'      => 'string',
                'minLength' => 0
              }
            },
            'state' => {
              'type'          => 'object',
              'minProperties' => 0,
              'properties'    => {
                'installed' => {
                  'type'     => ['string', 'boolean'],
                }
              },
              'additionalProperties' => {
                'type'      => 'string',
                'minLength' => 0
              }
            },
            'hostname' => {
              'type'     => 'string',
            },
            'root_password' => {
              'type'     => 'string',
            },
            'power' => {
              'type'       => 'object',
              'properties' => {
                'desired_power_state' => {
                  'type'     => ['string', 'null'],
                  'pattern'  => 'on|off'
                },
                'last_known_power_state' => {
                  'type'     => ['string', 'null'],
                  'pattern'  => 'on|off'
                },
                'last_power_state_update_at' => {
                  'type'     => ['string', 'null'],
                  # 'pattern' => '' ...date field.
                }
              },
              'additionalProperties' => false,
            },
            'ipmi' => {
                'hostname' => nil,
                'username' => nil
            }
          },
          'additionalProperties' => false,
        }.freeze
      end
    
      def command_item_schema
        {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'title'    => "Command item JSON Schema",
          'type'     => 'object',
          'required' => %w[spec id name command],
          'properties' => {
            'spec' => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'id'       => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'name'     => {
              'type'     => 'string',
              'pattern'  => '^[0-9]+$'
            },
            'command'    => {
              'type'     => 'string',
              'pattern'  => '^[a-z-]+$'
            },
            'params'     => {
              'type'     => 'object',
            },
            'errors'     => {
              'type'     => 'array',
              'items'    =>  {
                'type'     => 'object',
                'required' => %w[exception message attempted_at],
                'properties' => {
                  'exception' => {
                     'type'   => 'string'
                  },
                  'message'   => {
                    'type'    => 'string'
                  },
                  'attempted_at' => {
                    'type' => 'string'
                  }
                },
                'additionalProperties' => false
              }
            },
            'status' => {
              'type'     => 'string',
              'pattern'  => '^(pending|running|finished|failed)$'
            },
            'submitted_at' => {
              'type'       => 'string',
            },
            'finished_at'  => {
              'type'       => 'string'
            }
          },
          'additionalProperties' => false,
        }.freeze
      end
    
      def hook_item_schema
        {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'title'    => "Hook Collection JSON Schema",
          'type'     => 'object',
          'required' => %w[spec id name hook_type],
          'properties' => {
            'spec' => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'id'       => {
              'type'     => 'string',
              'pattern'  => '^https?://'
            },
            'name'     => {
              'type'     => 'string',
              'pattern'  => '^[^\n]+$'
            },
            'hook_type' => {
              'type'     => 'string',
              'pattern'  => '^[a-zA-Z0-9 ]+$'
            },
            'configuration' => {
              'type'    => 'object',
              'additionalProperties' => {
                'oneOf'     => [
                  {
                    'type'      => 'string',
                    'minLength' => 1
                  },
                  {
                    'type'      => 'number',
                  }
                ]
              }
            },
            'log'   => {
              'type'       => 'object',
              'required'   => %w[id name],
              'properties' => {
                'id'       => {
                  'type'     => 'string',
                  'pattern'  => '^https?://'
                },
                'name'     => {
                  'type'      => 'string',
                  'minLength' => 1
                },
              },
            },
          },
          'additionalProperties' => false,
        }.freeze
      end
    
      def event_item_schema
        {
          '$schema'  => 'http://json-schema.org/draft-04/schema#',
          'title'    => "Event Collection JSON Schema",
          'type'     => 'object',
          'required' => %w[spec id name severity entry],
          'properties' => {
              'spec' => {
                  'type'     => 'string',
                  'pattern'  => '^https?://'
              },
              'id'       => {
                  'type'     => 'string',
                  'pattern'  => '^https?://'
              },
              'name'     => {
                  'type'     => 'number',
                  'pattern'  => '^[^\n]+$'
              },
              'node' => {
                  'type'     => 'object'
              },
              'policy' => {
                  'type'     => 'object'
              },
              'timestamp' => {
                  'type'     => 'string'
                  # 'pattern' => '' ...date field.
              },
              'entry' => {
                  'type'     => 'object'
              },
              'severity' => {
                  'type'     => 'string',
                  'pattern'   => 'error|warning|info',
              }
          },
          'additionalProperties' => false,
        }.freeze
      end
    end
  end
end
