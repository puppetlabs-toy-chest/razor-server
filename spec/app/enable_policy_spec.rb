require_relative '../spec_helper'
require_relative '../../app'

describe "commands to change a policy's 'enabled' flag" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  context "/api/commands/create-policy" do
    before :each do
      use_installer_fixtures
      header 'content-type', 'application/json'
    end

    let(:policy)   { Fabricate(:policy) }

    ["enable", "disable"].each do |verb|
      other_verb = verb == "enable" ? "disable" : "enable"

      it "returns 400 when no name is provided (#{verb})" do
        post "/api/commands/#{verb}-policy", { "noname" => "nothing" }.to_json
        last_response.status.should == 400
      end

      it "returns 404 when no policy with that name exists (#{verb})" do
        post "/api/commands/#{verb}-policy", { "name" => "nothing" }.to_json
        last_response.status.should == 404
      end

      it "#{verb}s a #{other_verb}d policy" do
        policy.enabled = verb == "disable"
        policy.save

        post "/api/commands/#{verb}-policy", { "name" => policy.name }.to_json

        last_response.status.should == 202
        last_response.json?.should be_true
        last_response.json.keys.should =~ %w[result]
        last_response.json["result"].should =~ /#{verb}d$/

        policy.reload
        if verb == "enable"
          policy.enabled.should be_true
        else
          policy.enabled.should be_false
        end
      end
    end
  end
end
