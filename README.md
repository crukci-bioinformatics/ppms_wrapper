## PPMS Wrapper

This plugin provides the following capabilities to a Redmine installation:

1. Validate cost codes and researcher email addresses against the PPMS database.
    1. when an issue is created or saved
    1. when an audit is run
1. Generate monthly billing reports for cross-charging to research groups.
1. Commit billing records reflecting said cross-charging to PPMS on demand.
1. Mark time logs as "charged", after which they cannot be changed.
1. Store (and periodically update) researchers' Raven IDs.
1. Might as well store a list of legal cost codes as well, to save checking
   PPMS on every save.

The plugin stores Raven ids (and corresponding email addresses), as well as a
list of time logs that have been billed, to ensure that they are not changed
after billing, and to ensure that they are not billed more than once.

#### Considerations

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
1. We do not want to hard-code an API key (especially since the code is hosted
   on a public GitHub repository).  But we don't want to have to supply it for
   each operation, either.  Maybe a config file on disk somewhere (outside of
   the HTTP hierarchy)?  Answer: save it as part of the plugin's configuration
   data.
1. How do we prevent saving of an invalid cost code or email address?  I guess
   we allow the issue as a whole to be saved, but reject the saving of the
   custom value, and post a message to the user.  Wrong... see next point.
1. New theory on saving cost codes / researcher emails: For cost codes, the
   field must be blank or a known cost code; nothing else is accepted.  For
   emails, we'll accept unknown emails, but warn about them.  Then refuse to
   bill for them when the time comes.
1. Refreshing the email -- Raven id mapping list currently does not check
   if the email address in PPMS has changed.  Doing so would require separate
   REST calls for each Raven ID (i.e. several hundred calls).  But it's possible
   that they might change.  Maybe the Rake task should check (run manually)
   but the automatic refresh shouldn't.
1. If the researcher email isn't valid, what should we do?  Not bill for the
   time (but warn)?  Use the group leader?  Not allow unknown emails?

#### Notes

1. Data come back from PPMS in various formats.  Some API calls return
   CSV-formatted data only; others return either CSV or JSON.  Some return
   slightly odd things:
   1. `getusers` returns the user list HTML-encoded, so for example a single
      quote "'" is encoded as "&amp;#39;".  Other calls do not seem to use this
      encoding.  Also, this call returns a bare list of logins, LF-separated,
      with no header.  (Similar for `getprojects`.)
   1. `getorders` returns a CSV-formatted string with the first row just the
      word "Orders", and the actual headers on the second row.

1. The API doc does not provide the parameter for "getorderlines".  The correct
   parameter is "orderref".

1. Note that groups are (mostly) named for the last name of the group leader,
   so we can look up group leaders by group name.  Except external groups, which
   may be named anything.  So we'll have to include a field in Redmine for
   "PPMS Group ID" and fill it in if needed.  The exemplar is Rebecca
   Fitzgerald's group, which is named "MRC -  Fitzgerald" instead of just
   "Fitzgerald" (with one space before the dash, and two after, for no
   apparent reason).

1. Do cancelled orders ever go away in PPMS?  How can we make them go away?

#### Rake Tasks

1. `rake redmine:ppms:refresh_raven`: refresh list of email addresses
   with associated Raven IDs.
1. `rake redmine:ppms:refresh_cost_codes`: refresh list of cost codes
   ("projects") with name, code, id.
1. `rake redmine:ppms:audit_group_leaders`: check whether we can look up group
   leader email addresses from the group names.  To do: add "PPMS Group ID"
   custom value to projects, fill in if PPMS group ID is not the last name of
   the group leader.
1. Test format of each data type (group, list of groups, project, list of
   projects, etc).  To do: implement.

#### Unit Tests

The plugin's unit tests can be run with:

`rake redmine:plugins:test:units NAME=ppms`

This requires the Redmine environment around it to run.

#### Remaining Features

1. A billing report showing what has been billed, and when (done).
1. Audits of grant codes associated with research groups (in addition to
   issues) (done).
1. Submit order before writing line to spreadsheet, so sheet can include order
   ID (done).
1. Block changes to time logs after they have been billed (done).
