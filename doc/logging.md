# Logging

Razor uses TorqueBox's logging subsystem exclusively for logging. Please
read the
[TorqueBox documentation](http://torquebox.org/builds/html-docs/jboss.html#jboss-logging)
on logging for details about how to configure that.

## Log categories

Razor logs to a few different categories, which can be used to separate the
wheat from the chaff in looking through logfiles:

* `razor.web.log` server access log in common log format
* `razor.web.api` additional messages from the API frontend, including
  details about errors
* `razor.messaging.sequel` messages about the internal messaging used, for
  example, when importing ISO's
* `razor` everything else
