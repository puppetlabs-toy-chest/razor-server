#
# Utilities for use by our migrations only; generally, you should strive to
# have each migration be self contained. This file is only for things that
# should be shared across migrations. Be mindful that changing existing
# entries here might require you to redo migrations that have already
# happened - in general, don't modify anything in this file, only add to
# it.

# Regular expression for our idea of a name
#
# No control characters anywhere, spaces except at start or end
# of line.  Welcome to complexity: Ruby treats `\Z` as end of string,
# unless you have a newline, but PostgreSQL doesn't understand `\z`
# at all.
#
# This, with the final look-ahead assertion, works correctly in both
# environments, ensuring consistent validation on both sides of
# the wire.
NAME_RX = %r'\A[^\u0000-\u0020/\u0085\u00a0\u1680\u180e\u2000-\u200a\u2028\u2029\u202f\u205f\u3000](?:[^\u0000-\u001f/]*[^\u0000-\u0020/\u0085\u00a0\u1680\u180e\u2000-\u200a\u2028\u2029\u202f\u205f\u3000])?\Z(?!\n)'i

# Regular expression matching http/https and file URL's
#
# * an absolute URL
# * one of the `http`, `https`, or `file` schemes
#   - does permit the quasi-legal `file:/example/path`
# * that there is at least one character of hostname present for HTTP(S)
# * that there is no hostname present for the file protocol
# * that nothing in the control character range is present in the path
#   - that includes checking no CR or LF characters exist
#
# This does not permit FTP; perhaps we should add that?
URL_RX = %r'\A(?:https?://[^/]+/?|file:(?://)?/)(?:[^/][^\u0000-\u0020]*)?\Z(?!\n)'i
