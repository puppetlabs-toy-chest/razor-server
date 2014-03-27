# -*- encoding: utf-8 -*-

class Razor::Command::SetNodeIPMICredentials < Razor::Command
  authz '%{name}'
  attr  'name', type: String, required: true, references: Razor::Data::Node
  attr  'ipmi-hostname', type: String
  attr  'ipmi-username', type: String, also: 'ipmi-hostname'
  attr  'ipmi-password', type: String, also: 'ipmi-hostname'

  def run(request, data)
    node = Razor::Data::Node[:name => data['name']]

    # Finally, save the changes.  This is using the unrestricted update
    # method because we carefully manually constructed our input above,
    # effectively doing our own input validation manually.  If you ever
    # change that (because, say, we fix the -/_ thing globally, make sure
    # you restrict this to changing the specific attributes only.
    node.update(
      :ipmi_hostname => data['ipmi-hostname'],
      :ipmi_username => data['ipmi-username'],
      :ipmi_password => data['ipmi-password'])

    { :result => _('updated IPMI details') }
  end
end
