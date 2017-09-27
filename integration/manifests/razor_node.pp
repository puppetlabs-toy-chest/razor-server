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
