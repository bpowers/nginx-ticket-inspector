TLS session ticket experiments
==============================

This repo sets up nginx to generate session tickets, so that we can
explore what is in the session ticket!

I'm looking to figure out if the server hostname (either directly, or
as the CN in the server certificate) (a) ends up in the ticket at all,
and if either the server or client uses that hostname to decide to
cancel a resumption.
