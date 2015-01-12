#!/bin/sh
cd $(dirname $0)/..
rxgettext -o locales/razor-server.pot --no-wrap --sort-output \
    --package-name 'Razor Server' --package-version "$(git describe)" \
    --copyright-holder="Puppet Labs, LLC." --copyright-year="2015" \
    *.rb $(find lib -name '*.rb')
