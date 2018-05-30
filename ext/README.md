# Razor Server Configuration

The files in this directory are used to set up the Razor Server service and
environment on various platforms. The [razor-vanagon](https://github.com/puppetlabs/razor-vanagon) repo lays down these
files when creating packages and makes any necessary changes required by the
package type (FOSS or PE).

### razor-server.init
This file is used to set up the razor-server service on platforms with System V
(SysV) init systems.
* el-6
* ubuntu-14.04 (trusty)

### razor-server.service
This file is used to set up the razor-server service on platforms with systemd
init systems.
* el-7
* ubuntu-16.04 (xenial)
* debian-8 (jessie)

### razor-server.sysconfig
This file contains environment variables that are used by the razor-server
service on both SysV and systemd.

### razor-server.env
This file contains environment variables used only by systemd.

### razor-server-tmpfiles.conf
This file uses "the systemd tmpfiles.d mechanism to ensure that the
/run/razor-server directory is created on boot with the proper ownership as /run
is now using tmpfs" (from the commit message adding this file).
