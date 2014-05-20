# MicroKernel extension at runtime

It is common that users need to amend the facts reported by the
Microkernel; this extension mechanism makes that possible, therefore
allowing user-defined facts to be collected and used in policy matching
together with facts built into Facter. All nodes receive the same MK
extensions and will therefore use the same code to generate facts.

By setting the configuration option `microkernel.extension-zip` in the
server's `config.yaml` to the full path and filename of a zip file, you can
have the Microkernel download and unpack that at runtime before checking in
with the Razor server.

An example of this setting would be:

      microkernel:
        extension-zip: /etc/razor/mk-extension.zip

The microkernel attempts to retrieve and unpack this file just prior to
each checkin. Even microkernels that have been booted for a while will
retrieve the latest extensions as soon as they are made available on the
server -- to be exact, microkernels retrieve this file before each checkin
from the server whenever its timestamp is newer than the one they already
have downloaded, or if they have not downloaded the extension file yet.

The content of the zip file will be placed in a new, non-persistent
directory on the MK image.  No changes to this directory will be saved, and
it will be erased and overwritten with the content of a new extension file
when that becomes available.

When the MK client is executed, these changes are made in the environment:

 * the directory `bin` at the root of the zip is added to `PATH`
 * the directory `lib` is added to `LD_LIBRARY_PATH`
 * the directory `lib/ruby` is added to `RUBYLIB`
 * the directory `facts.d` is used by Facter to load external facts

This allows executables, shared libraries, external facts, and Ruby code to
be added to the MK image at will. It is not possible to change any other
environment variables than the ones listed above through the extension
file.

During unpacking, the executable bit on files will be preserved.  While it is
not possible to create setuid or setgid files this way, the MK client runs as
"root", so has full control over the (in-memory) MK image.

Since the content of the directory that the zip is unpacked to is
unpredictable, you must use relative paths in your applications, or facts, or
otherwise search standard PATH and similar variables to locate content.

If you need to store persistent state, you must select a location outside the
path where the zip file is unpacked on the MK: data stored there can be lost
at any time.  Using `/tmp` is a fine choice, as this will persist as long as
the in-memory MK image is running, and is no less permanent than any
other location.

Facter loads custom facts from `RUBYLIB`, which means that if they are
packaged normally in the Ruby library search path -- remembering that
`lib/ruby` will be added to `RUBYLIB` before checkin -- they will be
available as custom facts. The
[custom facts walkthrough](http://docs.puppetlabs.com/facter/latest/custom_facts.html)
contains more details on this.

As noted above, there is no way to set custom environment variables prior to
checkin, so the static `FACTER_<factname>` environment variables cannot
be used.

The standard command execution mechanisms in Facter will work correctly for
locating binaries shipped in the mk-extension.zip file, without any additional
work on your part.
