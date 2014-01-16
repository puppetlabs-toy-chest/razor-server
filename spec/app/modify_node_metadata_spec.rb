require_relative '../spec_helper'
require_relative '../../app'

describe "modify node metadata command" do
  include Rack::Test::Methods

  let(:app) { Razor::App }

  before :each do
    header 'content-type', 'application/json'
    authorize 'fred', 'dead'
  end

  def modify_metadata(data)
    post '/api/commands/modify-node-metadata', data.to_json
  end

  it "should require a node" do
    data = { 'update' => { 'k1' => 'v1'} }
    modify_metadata(data)
    last_response.status.should == 400
    JSON.parse(last_response.body)["error"].should =~ /must supply node/
  end

  it "should require an operation" do
    data = { 'node' => 'node1' }
    modify_metadata(data)
    last_response.status.should == 400
    JSON.parse(last_response.body)["error"].should =~ /must supply at least one opperation/
  end

  it "should complain about the use of clear with other ops" do
    data = { 'node' => 'node1', 'update' => { 'k1' => 'v1'}, 'clear' => 'true' }
    modify_metadata(data)
    last_response.status.should == 400
    JSON.parse(last_response.body)["error"].should =~ /clear cannot be used with update or remove/
  end

  it "should complain duplicate keys in update and remove" do
    data = { 
      'node'   => 'node1',
      'update' => { 'k1' => 'v1', 'k2' => 'v2'},
      'remove' => [ 'k2' ]
    }
    modify_metadata(data)
    last_response.status.should == 400
    JSON.parse(last_response.body)["error"].should =~ /cannot update and remove the same key/
  end

  it "should complain if clear is not boolean true or string 'true'" do
    data = { 'node' => 'node1', 'clear' => 'something' }
    modify_metadata(data)
    last_response.status.should == 400
    JSON.parse(last_response.body)["error"].should =~ /clear must be boolean true or string 'true'/
  end

  it "should complain if no_replace is not boolean true or string 'true'" do
    data = { 'node' => 'node1', 'update' => { 'k1' => 'v1'}, 'no_replace' => 'something' }
    modify_metadata(data)
    last_response.status.should == 400
    JSON.parse(last_response.body)["error"].should =~ /no_replace must be boolean true or string 'true'/
  end

  describe "when updating metadata on a node" do

    let(:node) do
      Fabricate(:node)
    end

    it "should create a new metadata item on a node" do
      id = node.id
      data = { 'node' => "node#{id}", 'update' => { 'k1' => 'v1'} } 
      modify_metadata(data)
      last_response.status.should == 202
      node_metadata = Node[:id => id].metadata
      node_metadata['k1'].should == 'v1'
    end

    it "should update the value of an existing tag" do
      id = node.id      
      data = { 'node' => "node#{id}", 'update' => { 'k1' => 'v1'} } 
      modify_metadata(data)
      data = { 'node' => "node#{id}", 'update' => { 'k1' => 'v2'} } 
      modify_metadata(data)
      last_response.status.should == 202
      node_metadata = Node[:id => id].metadata
      node_metadata['k1'].should == 'v2'
    end

    it "should NOT update the value of an existing tag if no_replace is set" do
      id = node.id      
      data = { 'node' => "node#{id}", 'update' => { 'k1' => 'v1'} } 
      modify_metadata(data)
      data = { 'node' => "node#{id}", 'update' => { 'k1' => 'v2', 'k2' => 'v2'}, 'no_replace' => true } 
      modify_metadata(data)
      last_response.status.should == 202
      node_metadata = Node[:id => id].metadata
      node_metadata['k1'].should == 'v1'  #should not have updated.
      node_metadata['k2'].should == 'v2'  #still should have added this.
    end

    it "should add and update multiple items" do
      id = node.id      
      data = { 'node' => "node#{id}", 'update' => { 'k1' => 'v1'} } 
      modify_metadata(data)
      data = { 'node' => "node#{id}", 'update' => { 'k1' => 'v2', 'k2' => 'v2', 'k3' => 'v3' } } 
      modify_metadata(data)
      last_response.status.should == 202
      node_metadata = Node[:id => id].metadata
      node_metadata['k1'].should == 'v2'
      node_metadata['k2'].should == 'v2'
      node_metadata['k3'].should == 'v3'
    end
  end

  describe "when removing metadata from a node" do
    let(:node) do
      node = Fabricate(:node)
      node.modify_metadata( {'update' => { 'k1' => 'v1', 'k2' => 'v2', 'k3' => 'v3'} } )
      node
    end

    it "should remove a single item" do
      id = node.id      
      data = { 'node' => "node#{id}", 'remove' => ['k1'] }
      modify_metadata(data)
      last_response.status.should == 202
      node_metadata = Node[:id => id].metadata
      node_metadata['k1'].should be_nil
    end

    it "should remove multiple pieces of metadata" do
      id = node.id      
      data = { 'node' => "node#{id}", 'remove' => ['k1', 'k2'] }
      modify_metadata(data)
      last_response.status.should == 202
      node_metadata = Node[:id => id].metadata
      node_metadata['k1'].should be_nil
      node_metadata['k2'].should be_nil
    end
  end

  describe "when adding and removing metadata in the same operation" do
    let(:node) do
      node = Fabricate(:node)
      node.modify_metadata( {'update' => { 'k1' => 'v1', 'k2' => 'v2', 'k3' => 'v3'} } )
      node
    end

    it "should processes both the update and remove tasks" do
      id = node.id      
      data = { 
        'node'   => "node#{id}",
        'update' => { 
          'k1' => 'v10',
          'k2' => 'v20',
        },
        'remove' => ['k3']
      }
      modify_metadata(data)
      last_response.status.should == 202
      node_metadata = Node[:id => id].metadata
      node_metadata["k1"].should == 'v10'
      node_metadata["k2"].should == 'v20'
      node_metadata["k3"].should be_nil
    end
  end

  describe "when clearing a nodes metadata" do
    let(:node) do
      node = Fabricate(:node)
      node.modify_metadata( {'update' => { 'k1' => 'v1', 'k2' => 'v2', 'k3' => 'v3'} } )
      node
    end

    it "should remove all metadata when clear is string true" do
      id = node.id      
      data = { 'node' => "node#{id}", 'clear' => 'true' }
      modify_metadata(data)
      last_response.status.should == 202
      node_metadata = Node[:id => id].metadata
      node_metadata.keys.should be_empty
    end

    it "should remove all metadata when clear is boolean true" do
      id = node.id      
      data = { 'node' => "node#{id}", 'clear' => true }
      modify_metadata(data)
      last_response.status.should == 202
      node_metadata = Node[:id => id].metadata
      node_metadata.keys.should be_empty
    end
  end
end
