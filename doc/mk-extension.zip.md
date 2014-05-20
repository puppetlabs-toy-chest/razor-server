# MicroKernel extension at runtime

By setting the configuration option `microkernel.extension-zip` to the full
path and filename of a zip file, you can have the Microkernel download and
unpack that at runtime before checking in with the Razor server.

An example of this setting would be:

      microkernel:
        extension-zip: /etc/razor/mk-extension.zip

Before the microkernel checks in to the Razor server, this is unpacked.

The content of the zip file will be placed in a new, non-persistent directory
on the MK image.  No changes to this directory will be saved -- it can be
replaced with a newly unpacked version at any time.

When the MK client is executed, these changes will be made in the environment:

 * the directory `bin` at the root of the zip will added to `PATH`
 * the directory `lib` will be added to `LD_LIBRARY_PATH`
 * the directory `lib/ruby` will be added to `RUBYLIB`

This allows executables, shared libraries, and Ruby code to be added to the MK
image at will, as part of the zip file.

Other than those environment variables being changed prior to checkin, it is
not possible to set environment variables through the content of this
zip file.

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

A common use for this extension is adding a custom fact to the MK, which will
be gathered and returned to the Razor server, and available for
policy matching.

These are absolutely standard Facter custom facts, so the
[standard custom fact walkthrough for Facter][facts] documents writing them.

[facts]: http://docs.puppetlabs.com/facter/latest/custom_facts.html

As normal, Facter will load custom facts from `RUBYLIB`, which means that if
they are packaged normally in the Ruby library search path -- remembering that
`lib/ruby` will be added to `RUBYLIB` before checkin -- they will be available
as custom facts.

As noted above, there is no way to set custom environment variables prior to
checkin, so the static `FACTER_<factname>` environment variables cannot
be used.

At the moment custom external facts are also not supported as there is no
public mechanism for these to be set without modification of facter.
This unfortunately means you will be restricted to writing Ruby based facts,
at least for now, although they can easily wrap external executables in
any language.

The standard command execution mechanisms in Facter will work correctly for
locating binaries shipped in the mk-extension.zip file, without any additional
work on your part.
