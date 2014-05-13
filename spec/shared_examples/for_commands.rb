# For attributes, two are currently accepted:
# - status: This is the expected resulting status of the command.
# - always_require: This is for any attribute that must be present
#   in the command. The typical use case for this is any attribute
#   which is programmatically validated, i.e. validated outside
#   of the validation framework.
shared_examples "a command" do | attributes = {}|
  status = (attributes[:status] or 'finished')
  command_name = described_class.name

  context "required attributes" do
    always_require = Array(attributes[:always_require])
    require_one_of = described_class.schema.instance_variable_get('@require_one_of').flatten
    required_keys = described_class.schema.instance_variable_get('@attributes').map do |key, value|
      key if value.instance_variable_get('@required')
    end.compact + require_one_of + always_require

    # Verify that the full hash works.
    it "succeeds with all attributes" do
      command command_name, command_hash, :status => status
      last_response.json['error'].should be_nil
      last_response.status.should == 202
    end
    # Strip to just required attributes, see success.
    it "succeeds with minimal attributes" do
      minimum_hash = command_hash.select { |key| required_keys.include? key.to_s }
      command command_name, minimum_hash, :status => status
      last_response.json['error'].should be_nil
      last_response.status.should == 202
    end
    # Remove one attribute at a time, see fail.
    required_keys.each do |exclude_key|
      it "fails when required key #{exclude_key} is omitted" do
        if command_hash.keys.map(&:to_s).include?(exclude_key)
          without_attribute = command_hash.select { |key| key.to_s != exclude_key && required_keys.include?(key.to_s) }
          command command_name, without_attribute, :status => status
          last_response.json['error'].should satisfy,
               "should be required, but was: #{last_response.json['error'] or '[success]'}" do |value|
            required_attribute_string = exclude_key.to_s.gsub('_', '-')
            required = (value == "#{required_attribute_string} is a required attribute, but it is not present")
            require_one_of = (value =~ /requires one out of the.+#{required_attribute_string}.+attributes to be supplied/)
            programmatic = (always_require.map(&:to_s).include?(exclude_key) and not value.nil?)
            required or require_one_of or programmatic
          end
          last_response.status.should == 422
        else
          # Skip test; attribute was not provided in command_hash.
          # This could be due to `require_one_of` or a programmatic requirement.
        end
      end
    end
  end
end
