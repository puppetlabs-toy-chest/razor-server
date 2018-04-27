file { '/root/.ssh':
  ensure  => directory,
  owner   => 'root',
  group   => 'root',
  mode    => '0700'
}
->
file { '/root/.ssh/authorized_keys':
  ensure  => file,
  owner   => 'root',
  group   => 'root',
  mode    => '0600',
  source  => 'puppet:///modules/auth_keys/authorized_keys'
}
file {'/etc/ssh':
  ensure  => directory,
  owner   => 'root',
  group   => 'root',
  mode    => '0755'
}
->
file { '/etc/ssh/sshd_config':
  ensure  => file,
  owner   => 'root',
  group   => 'root',
  mode    => '0644',
  source  => 'puppet:///modules/ssh/sshd_config',
  notify  => Service['ssh']
}
~>
service { 'ssh':
  ensure  => 'running',
  enable  => 'true'
}
