a = {
  "type"        => "object" ,
  "$schema"     => "http://json-schema.org/draft-04/schema",
  "description" => "JSON Siren validation schema",
  "properties"  => {
    "class"       => { "$ref" => "#/definitions/class" },
    "properties"  => { "type" => "object" },
    "entities"    => {
      "type"        => "array",
      "items"       => {
        "oneOf"       => [
          { "$ref"      => "#/definitions/subEntity" },
          { "$ref"      => "#/definitions/embeddedLink" },
        ]
      }
    },
    "links"     => {
      "type"      => "array",
      "items"     => { "$ref" => "#/definitions/link" },
    },
    "actions"   => { "$ref" => "#/definitions/actions" },
    "title"     => { "type" => "string" },
  },
  "additionalProperties" => false,
  "definitions" => {
    "action"      => {
      "type"        => "object",
      "required"    => %w[href name],
      "properties"  => {
        "class"       => { "$ref" => "#/definitions/class" },
        "href"        => {
          "type"      => "string",
          'pattern' => '^https?://',
        },
        "method"      => {
          "enum"        => %w[GET PUT POST DELETE PATCH]
        },
        "name"        => { "type" => "string" },
        "title"       => { "type" => "string" },
        "fields"      => {
          "type"        => "array",
          "items"       => {
            "type"        => "object",
            "required"    => ["name"],
            "properties"  => {
              "name"        => { "type" => "string" },
              "type"        => {
                "enum"      => %w[hidden text search tel url email,
                             password datetime date month week time
                             datetime-local number range color,
                             checkbox radio file submit image reset button],
              },
              "value"       => {  },
            }
          }
        }
      },
      "additionalProperties" => false,
    },
    "actions" => {
      "type"      => "array",
      "items"     => { "$ref" => "#/definitions/action" },
    },
    "class"       => {
      "type"        => "array",
      "minItems"    => 1,
      "items"       => { "type" => "string" },
    },
    "embeddedLink" => {
      "type" => "object",
      "required"   => ["rel", "href"],
      "properties" => {
        "class" => { "$ref" => "#/definitions/class"},
        "href" => {
          "type" => "string",
          'pattern' => '^https?://',
        },
        "properties" => { "type" => "object" },
        "rel"        => {
          "type"       => "array",
          "items"      => { "type" => "string" },
        },
      },
      "additionalProperties" => false,
    },
    "link"  => {
      "type"       => "object",
      "required"   => [ "rel", "href" ],
      "properties" => {
        "rel"        => {
          "type"       => "array",
          "items"      => { "type" => "string" },
          },
        "href"       => { "type" => "string" },
      },
      "additionalProperties" => false,
    },
    "links" => {
      "type"      => "array",
      "items"     => { "$ref" => "#/definitions/link" },
    },
    "subEntity"   => {
      "type"        => "object",
      "required"    => ["rel"],
      "properties"  => {
        "class"       => { "$ref" => "#/definitions/class" },
        "properties"  => { "type" => "object" },
        "entities"    => {
          "type"        => "array",
          "items"       => {
            "oneOf"       => [
              { "$ref"      => "#/definitions/subEntity" },
              { "$ref"      => "#/definitions/embeddedLink" },
            ]
          }
        },
        "links"     => { "$ref" => "#/definitions/links" },
        "actions"   => { "$ref" => "#/definitions/actions" },
        "title"     => { "type" => "string" },
        "rel"       => { "type" => "array", "items" => { "type" => "string" } }
      },
      "additionalProperties" => false,
    },
  }
}


require 'json'
puts ''
puts a.to_json
puts ''
