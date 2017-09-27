step "Install PE Razor Server"
  razor_hosts = get_razor_hosts
  razor_hosts.each do |host|
    on host, 'service pe-razor-server stop'
    install_pe_razor_server host
    on host, 'service pe-razor-server start >&/dev/null'
    unless retry_on(host, 'curl -kf https://localhost:8151/api',
                    :max_retries => 30, :retry_interval => 5)
      raise RuntimeError, "server #{host} did not start back up"
    end
  end
