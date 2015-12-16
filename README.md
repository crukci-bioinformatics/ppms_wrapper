# PPMS Wrapper

This plugin provides the following capabilities to a Redmine installation:

1. Validate cost codes and researcher email addresses against the PPMS database.
    1. when an issue is created or saved
    1. when time is logged against an issue
1. Generate monthly billing reports for cross-charging to research groups.
1. Commit billing records reflecting said cross-charging to PPMS on demand.
1. Mark time logs as "charged", after which they cannot be changed.
1. Store (and periodically update) researchers' Raven IDs.

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
