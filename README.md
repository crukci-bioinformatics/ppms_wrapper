# PPMS Wrapper

This plugin provides the following capabilities to a Redmine installation:

1. Validate cost codes and researcher email addresses against the PPMS database.
    1. when an issue is created or saved
    1. when time is logged against an issue
1. Generate monthly billing reports for cross-charging to research groups.
1. Commit billing records reflecting said cross-charging to PPMS on demand.
1. Mark time logs as "charged", after which they cannot be changed.
1. Store (and periodically update) researchers' Raven IDs.
1. Might as well store a list of legal cost codes as well, to save checking
   PPMS on every save.

The plugin stores Raven ids (and corresponding email addresses), as well as a
list of time logs that have been billed, to ensure that they are not changed
after billing, and to ensure that they are not billed more than once.

## Considerations

1. Linking Raven IDs to email addresses: currently we store researcher emails,
   but what happens if the researcher's preferred email address is not the one
   in PPMS?
1. There is only one service the group provides, so we don't need to ask
   which service, when billing.  But is this future-proof?  Might we someday
   have different services available?
1. When (and why) do we refresh the list of known Raven IDs and cost codes?
   Maybe it's easiest to do it on demand: when an issue is saved, or time is
   logged, and we don't have an entry for this cost code or a mapping from
   this email address to a Raven ID, then refresh, and check whether the
   mapping now exists.  If so, great.  Otherwise block the operation and
   complain about the cost code or email address.

## Notes

1. Data come back from PPMS in various formats.  Some API calls return
   CSV-formatted data only; others return either CSV or JSON.  Some return
   slightly odd things:
   1. `getusers` returns the user list HTML-encoded, so for example a single
      quote "'" is encoded as "&#39;".  Other calls do not seem to use this
      encoding.  Also, this call returns a bare list of logins, LF-separated,
      with no header.
