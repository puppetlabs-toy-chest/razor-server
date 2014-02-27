# -*- encoding: utf-8 -*-
# Make the translation methods from everywhere
require 'fast_gettext'
Object.send(:include, FastGettext::Translation)

locales = File.absolute_path('../../locales', File.dirname(__FILE__))

# Define our text domain, and set the path into our root.  I would prefer to
# have something smarter, but we really want this up earlier even than our
# config loading happens so that errors there can be translated.
#
# We use the PO files directly, since it works about as efficiently with
# fast_gettext, and avoids all the extra overhead of compilation down to
# machine format, etc.
FastGettext.add_text_domain('razor-server',:path => locales, :type => :po)
FastGettext.default_text_domain = 'razor-server'

# Likewise, be explicit in our default language choice.
FastGettext.default_locale = 'en'
