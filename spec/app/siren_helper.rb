require 'json'
require 'uri'


def is_valid_siren?(response)
  response.content_type.should =~ /application\/vnd\.siren\+json/i
  obj = JSON.parse(response.body)
  is_valid_siren_entity?(obj).should == true
end

def optional_string(hash, key)
  hash.include?(key) and hash[key].should be_a String
  hash.delete key
end

def is_valid_siren_action?(action)
  action = action.dup
  action.delete("name").should be_a String
  URI.parse(action.delete("href"))

  action = action.dup

  if action.include? "class"
    is_valid_siren_class?(action["class"]).should == true
    action.delete "class"
  end

  if action.include? "method"
    ["GET","PUT","POST","DELETE","PATCH"].should include(action["method"])
    action.delete "method"
  end

  if action.include? "title"
    action["title"].should be_a String
    action.delete "title"
  end

  if action.include? "type"
    action["type"].should be_a String
    action.delete["type"]
  end

  if action.include? "fields"
    action["fields"].should be_an Array
    action["fields"].each do |field|
      is_valid_siren_field?(field).should == true
    end
    action.delete "fields"
  end

  action.keys.should == []
  true
end

def is_valid_siren_class?(array)
  array.should be_an Array
  array.should_not == []
  array.all? {|x| x.should be_a String}
end

def is_valid_siren_link?(link)
  link.should be_a Hash
  link.keys.should =~ ["href", "rel"]
  URI.parse(self["href"]).should_not be_nil
  link["rel"].should be_an Array
  link["rel"].length.should be 1
  link["rel"].first.should be_a String
  true
end


def is_valid_siren_field?(field)
  field = field.dup

  field.delete("name").should be_a String

  input_types = %w[hidden text search tel url email password
    datetime date month week time datetime-local number range
    color checkbox radio file submit image reset button]

  if field.include? "type"
    input_types.should include field["type"]
    field.delete "type"
  end

  if field.include? "value"
    [String, Numeric, TrueClass, FalseClass, NilClass].any? do |type|
      field["value"].is_a? type
    end.should == true
    field.delete "value"
  end

  field.keys.should == []
  true
end


def is_valid_siren_entity?(entity)
  entity = entity.dup

  entity.should_not == [] # Though not in the spec, this is true for our uses

  if entity.include? "class"
    is_valid_siren_class?(entity["class"]).should == true
    entity.delete "class"
  end

  if entity.include? "properties"
    entity["properties"].should be_a Hash
    entity.delete "properties"
  end

  if entity.include? "entities"
    entity["entities"].should be_an Array
    entity["entities"].each do |sub_ent|
      sub_ent = sub_ent.dup
      p sub_ent unless sub_ent["rel"]
      p sub_ent["rel"] unless sub_ent["rel"].is_a?(Array)
      sub_ent["rel"].should be_an Array
      sub_ent["rel"].should_not == []
      sub_ent.delete "rel"

      sub_ent.delete "href" # for embedded links
      is_valid_siren_entity?(sub_ent).should == true
    end
    entity.delete "entities"
  end

  if entity.include? "links"
    entity["links"].should be_an Array
    entity["links"].each do |link|
      is_valid_siren_link(link).should == true
    end
    entity.delete "links"
  end

  if entity.include? "actions"
    entity["actions"].should be_an Array
    entity["actions"].each do |action|
      is_valid_siren_action?(action).should == true
    end
  end

  true
end
