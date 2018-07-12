step "Install PE"
  # TODO `puppet_collection` argument must be supplied because beaker is still
  # looking for PC1 for PE 2018.2.
  # install_pe
  install_pe_on(hosts, options.merge(puppet_collection: 'puppet6'))

