/// <p>System Explorer's write codes and sentences (AD-39, Story 19.2): every <code>EXPLORER.*</code>
/// code the source code API port answers a write with, the sentence each carries, and the port-owned
/// reason a delete's refused document carries in its per-document result. Each sentence is published
/// once in EXPERIENCE.md's Fixed strings and pinned equal to its <file>ui/src/app/core/strings.ts</file>
/// key by <file>ui/tools/self-protection.test.mjs</file>. They live beside
/// <class>OcuPilot.Api.Error</class> rather than in it because that class holds the compiler's limit
/// of 1,000 parameters (ERROR #5290).</p>
Class OcuPilot.Api.AtelierError Extends %RegisteredObject
{

/// <p>Envelope code: a document the write names is absent at the fresh read, so nothing was sent.
/// Rendered on the <parameter>OcuPilot.Api.Error.NOTFOUND</parameter> slug with 404, its
/// <code>detail.documents</code> naming each absent document.</p>
Parameter DOCUMENTABSENT = "EXPLORER.DOCUMENT.ABSENT";

/// <p>The sentence <parameter>DOCUMENTABSENT</parameter> carries.</p>
Parameter REASONDOCUMENTABSENT = "This namespace no longer holds a document this change names.";

/// <p>Envelope code: an import's file holds no document the instance can read (Story 19.13).</p>
Parameter IMPORTUNREADABLE = "EXPLORER.IMPORT.UNREADABLE";

/// <p>The sentence <parameter>IMPORTUNREADABLE</parameter> carries.</p>
Parameter REASONIMPORTUNREADABLE = "The file holds no document this instance can read.";

/// <p>Envelope code: an import's file, or a document it would replace, differs at the write from the
/// documents its import was reviewed with (Story 19.13).</p>
Parameter IMPORTCHANGED = "EXPLORER.IMPORT.CHANGED";

/// <p>The sentence <parameter>IMPORTCHANGED</parameter> carries.</p>
Parameter REASONIMPORTCHANGED = "The file, or a document it would replace, has changed since this import was proposed.";

/// <p>Envelope code: an export's file name names a directory that does not exist under its allowed
/// directory (Story 19.13). Rendered as a 400 violation on <code>path</code>.</p>
Parameter EXPORTDIRECTORY = "EXPLORER.EXPORT.DIRECTORY";

/// <p>The sentence <parameter>EXPORTDIRECTORY</parameter> carries.</p>
Parameter REASONEXPORTDIRECTORY = "There is no such directory under that allowed directory.";

/// <p>Envelope code: a file sent or named for import is longer than an import reads (Story 19.13).</p>
Parameter IMPORTTOOLARGE = "EXPLORER.IMPORT.TOOLARGE";

/// <p>The sentence <parameter>IMPORTTOOLARGE</parameter> carries.</p>
Parameter REASONIMPORTTOOLARGE = "The file is longer than 3,000,000 characters, the most one import reads.";

/// <p>Envelope code: the document a save names changed on the instance after the editor read it, so
/// the text was not saved (Story 19.3). Rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter>
/// slug with 409, and never logged: it is an answer, not a fault.</p>
Parameter DOCUMENTCONFLICT = "EXPLORER.DOCUMENT.CONFLICT";

/// <p>The sentence <parameter>DOCUMENTCONFLICT</parameter> carries.</p>
Parameter REASONDOCUMENTCONFLICT = "Someone else changed this document after you opened it, so it was not saved. Copy your changes, then reopen the document to see the current text.";

/// <p>Envelope code: another process holds the document a save or an import names (#5864), so
/// nothing was written (Story 19.3). Rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter>
/// slug with 409, and never logged as a fault; the vendor's message, which names a user and a process,
/// is logged at information severity and never sent (AD-61 rule 6).</p>
Parameter DOCUMENTLOCKED = "EXPLORER.DOCUMENT.LOCKED";

/// <p>The sentence <parameter>DOCUMENTLOCKED</parameter> carries, the one
/// <parameter>DELETELOCKED</parameter> carries.</p>
Parameter REASONDOCUMENTLOCKED = "Another process is editing this document.";

/// <p>Envelope code: the namespace's source-control class has not released the document a save names for
/// editing (#5845, #5865 or #6151, its edit check), so nothing was written (Story 20.10). Rendered on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409, and never logged as a fault; the
/// vendor's message, which can name the user who holds the document, is logged at information severity and
/// never sent (AD-61 rule 6).</p>
Parameter DOCUMENTSOURCECONTROL = "EXPLORER.DOCUMENT.SOURCECONTROL";

/// <p>The sentence <parameter>DOCUMENTSOURCECONTROL</parameter> carries.</p>
Parameter REASONDOCUMENTSOURCECONTROL = "Source control has not released this document for editing, so nothing was saved. Check it out first.";

/// <p>Envelope code: the first line of a save's text does not name the document saved, by name and
/// kind, so nothing was sent (Story 19.3). Rendered on the
/// <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug with 422.</p>
Parameter SAVEHEADER = "EXPLORER.SAVE.HEADER";

/// <p>The sentence <parameter>SAVEHEADER</parameter> carries.</p>
Parameter REASONSAVEHEADER = "The first line no longer names this document, so the text was not saved.";

/// <p>Envelope code: a save's text is longer than one save sends, so nothing was sent (Story 19.3).
/// Rendered on the <parameter>OcuPilot.Api.Error.BADREQUEST</parameter> slug with 400.</p>
Parameter SAVETOOLARGE = "EXPLORER.SAVE.TOOLARGE";

/// <p>The sentence <parameter>SAVETOOLARGE</parameter> carries.</p>
Parameter REASONSAVETOOLARGE = "The text is longer than 3,000,000 characters, the most one save sends.";

/// <p>Envelope code: the instance refused a save's text with an error of its own, a source-control
/// hook's own refusal or text it cannot store among them, and kept the document as it was (Story 19.3). Rendered
/// on the <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug with 422; the vendor's text
/// is logged and never sent.</p>
Parameter SAVEREFUSED = "EXPLORER.SAVE.REFUSED";

/// <p>The sentence <parameter>SAVEREFUSED</parameter> carries.</p>
Parameter REASONSAVEREFUSED = "The instance refused this text, so nothing was saved.";

/// <p>Envelope code: the namespace's source-control class reported an error for a person's answer to its question after
/// a create or a delete (Story 21.38). Rendered on the <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug
/// with 422; the class's text is logged at information severity and never sent.</p>
Parameter SOURCECONTROLANSWER = "EXPLORER.SOURCECONTROL.ANSWER";

/// <p>The sentence <parameter>SOURCECONTROLANSWER</parameter> carries.</p>
Parameter REASONSOURCECONTROLANSWER = "The source-control class reported an error for this answer, so its step may not have finished.";

/// <p>A deleted document's per-document reason when the vendor refused it for want of a privilege
/// (#5838, #5883, #302) or a <code>&lt;PROTECT&gt;</code>.</p>
Parameter DELETEACCESS = "This account cannot change the database that holds this document.";

/// <p>A deleted document's per-document reason when another process holds it (#5864).</p>
Parameter DELETELOCKED = "Another process is editing this document.";

/// <p>A deleted document's per-document reason when the vendor no longer found it.</p>
Parameter DELETEABSENT = "This namespace no longer holds this document.";

/// <p>A deleted document's per-document reason for any other refusal.</p>
Parameter DELETEFAILED = "The source code API could not delete this document.";

/// <p>Envelope code: a SQL console request's statement, values or Max rows are outside their bounds,
/// so nothing was prepared (Story 19.6). Rendered on the
/// <parameter>OcuPilot.Api.Error.BADREQUEST</parameter> slug with 400.</p>
Parameter SQLINPUT = "EXPLORER.SQL.INPUT";

/// <p>The sentence <parameter>SQLINPUT</parameter> carries.</p>
Parameter REASONSQLINPUT = "Send one statement of up to 100,000 characters, at most 100 values of up to 32,767 characters each, and Max rows from 1 to 1,000.";

/// <p>Envelope codes for the statements the SQL console refuses by kind after preparing them (Story
/// 19.6), each rendered on the <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug with
/// 422: a statement that controls a server process, one that administers accounts, roles,
/// privileges or databases, and one that names a server file or another server.</p>
Parameter SQLSESSION = "EXPLORER.SQL.SESSION";

Parameter REASONSQLSESSION = "This statement controls a server process (a transaction, lock, option, cursor, namespace or running query) and is not run here.";

Parameter SQLADMINISTRATION = "EXPLORER.SQL.ADMINISTRATION";

Parameter REASONSQLADMINISTRATION = "Users, roles, privileges and databases are changed on Permissions and OS management, where OcuPilot checks each change; this statement is not run here.";

Parameter SQLSERVERFILES = "EXPLORER.SQL.SERVERFILES";

Parameter REASONSQLSERVERFILES = "This statement reads a server file or another server, which OcuPilot does not let a caller name.";

/// <p>Envelope code: a statement that sets a password, refused before it is prepared because the
/// instance keeps a prepared statement's text (Story 19.6). Rendered on the
/// <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug with 422.</p>
Parameter SQLPASSWORD = "EXPLORER.SQL.PASSWORD";

Parameter REASONSQLPASSWORD = "A statement that sets a password is not prepared here, because the instance keeps a prepared statement's text; set passwords on the Users list in Permissions.";

/// <p>Envelope code: a statement that only reads, sent to the console's confirmed run, which runs only
/// a statement that changes something (Story 19.6). Rendered on the
/// <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug with 422.</p>
Parameter SQLREADS = "EXPLORER.SQL.READS";

Parameter REASONSQLREADS = "This statement only reads, so it runs without confirming.";

/// <p>Envelope code: a confirmed run whose values do not number the statement's value positions
/// (Story 19.6). Rendered on the <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug with
/// 422.</p>
Parameter SQLPARAMETERS = "EXPLORER.SQL.PARAMETERS";

Parameter REASONSQLPARAMETERS = "Give one value for each ? in the statement.";

/// <p>Envelope code: a query or a DML statement the instance's statement index holds no row for once
/// it is prepared, so the tables it uses cannot be checked before it runs and it is not run. Rendered
/// on the <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug with 422.</p>
Parameter SQLUNRECORDED = "EXPLORER.SQL.UNRECORDED";

Parameter REASONSQLUNRECORDED = "The instance keeps no record of the tables this statement uses before it runs, so OcuPilot cannot check what it reads or changes and does not run it here; writing SELECT %NORUNTIME may let a query be checked.";

/// <p>Envelope codes for the agent's two SQL tools (Story 19.11), each rendered on the
/// <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug with 422: a statement that changes
/// something sent to the read tool, a statement that carries code sent to the run tool, and a
/// statement the instance did not prepare sent to the run tool, which the mint refuses before any
/// proposal exists.</p>
Parameter SQLCHANGES = "EXPLORER.SQL.CHANGES";

Parameter REASONSQLCHANGES = "This statement changes something, so it is proposed and runs only once a person confirms it.";

Parameter SQLAGENTCODE = "EXPLORER.SQL.AGENTCODE";

Parameter REASONSQLAGENTCODE = "A statement that creates a function, method, procedure, query, trigger or aggregate, or a COMPUTECODE field, carries code, which a person writes and runs on SQL query.";

Parameter SQLNOTPREPARED = "EXPLORER.SQL.NOTPREPARED";

Parameter REASONSQLNOTPREPARED = "The instance did not prepare this statement, so it is not proposed; its SQLCODE says why.";

/// <p>Envelope code: a statement of any kind but a query sent to the console's background run, which
/// runs only a query (Story 19.15). Rendered on the <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter>
/// slug with 422.</p>
Parameter SQLBACKGROUNDQUERYONLY = "EXPLORER.SQL.BACKGROUND.QUERYONLY";

Parameter REASONSQLBACKGROUNDQUERYONLY = "Only a query runs in the background; use Run for a statement that changes something.";

/// <p>Envelope code: a background run started while one the caller started still runs (Story 19.15). Rendered on
/// the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409, its
/// <code>detail.runId</code> naming the running run.</p>
Parameter SQLBACKGROUNDBUSY = "EXPLORER.SQL.BACKGROUND.BUSY";

Parameter REASONSQLBACKGROUNDBUSY = "A query you started is already running in the background; cancel it or wait for it to end.";

/// <p>Envelope code: a background run started while the instance runs as many as it allows (Story
/// 19.15). Rendered on the <parameter>OcuPilot.Api.Error.UNAVAILABLE</parameter> slug with 503.</p>
Parameter SQLBACKGROUNDFULL = "EXPLORER.SQL.BACKGROUND.FULL";

Parameter REASONSQLBACKGROUNDFULL = "As many background queries as this instance allows are running; try again when one ends.";

/// <p>Envelope code: no background run of the caller's has this id -- another user's, an unknown or a
/// swept run alike (Story 19.15). Rendered on the <parameter>OcuPilot.Api.Error.NOTFOUND</parameter>
/// slug with 404.</p>
Parameter SQLBACKGROUNDNOTFOUND = "EXPLORER.SQL.BACKGROUND.NOTFOUND";

Parameter REASONSQLBACKGROUNDNOTFOUND = "No background run of yours has this id; an ended run is kept for 15 minutes.";

/// <p>Envelope code: a background run that ended without an answer -- its job was not accepted, or
/// stopped before it answered (Story 19.15). Rendered on the
/// <parameter>OcuPilot.Api.Error.UNAVAILABLE</parameter> slug with 503, and carried as a failed run's
/// <code>refusal</code>.</p>
Parameter SQLBACKGROUNDLOST = "EXPLORER.SQL.BACKGROUND.LOST";

Parameter REASONSQLBACKGROUNDLOST = "The background run ended without an answer; run it again.";

/// <p>Envelope code: a data browser request outside its shape (Story 19.7): an unknown key, a bad
/// name, a filter or sort on a column the table does not list or of a stream or binary column, a
/// direction, an offset or a page size out of range. Rendered on the
/// <parameter>OcuPilot.Api.Error.BADREQUEST</parameter> slug with 400.</p>
Parameter DATAINPUT = "EXPLORER.DATA.INPUT";

Parameter REASONDATAINPUT = "Name a table or view as the tree shows it; filters of up to 1,000 characters on its listed columns that are not streams or binary; a sort on one such column, ascending or descending; an offset from 0; and a page size of 50, 100, 250 or 500.";

/// <p>Envelope code: no table or view the caller's catalog shows has the requested name (Story 19.7).
/// Rendered on the <parameter>OcuPilot.Api.Error.NOTFOUND</parameter> slug with 404, unlogged.</p>
Parameter DATANOTFOUND = "EXPLORER.DATA.NOTFOUND";

Parameter REASONDATANOTFOUND = "This namespace holds no table or view by that name that this account can see.";

/// <p>Envelope code: a data browser save whose changes break the table's column rules (Story 19.8): a
/// key member missing or extra, a key, identity, generated, stream, binary or unlisted column among
/// the values, or the values read naming other columns than the values set. Rendered on the
/// <parameter>OcuPilot.Api.Error.BADREQUEST</parameter> slug with 400.</p>
Parameter DATACHANGES = "EXPLORER.DATA.CHANGES";

Parameter REASONDATACHANGES = "Name each row's key, and change only listed columns that are not keys, identities, computed, streams or binary.";

/// <p>Envelope code: a data browser save to a view, or to a table without a key the caller can list
/// (Story 19.8), refused before any statement. Rendered on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409.</p>
Parameter DATAREADONLY = "EXPLORER.DATA.READONLY";

Parameter REASONDATAREADONLY = "This is a view, or a table without a key this account can see, so its rows are not changed here.";

/// <p>Envelope code: a Code metrics or Document hashes spec has a part that is a bare <code>*</code>, which
/// names the whole namespace, so no body ran (Story 24.1). Rendered on the
/// <parameter>OcuPilot.Api.Error.BADREQUEST</parameter> slug with 400, and never logged.</p>
Parameter SPECWIDE = "EXPLORER.SPEC.WIDE";

Parameter REASONSPECWIDE = "Name a package or a pattern, such as MyApp.*.cls; * on its own covers the whole namespace.";

/// <p>Envelope code: a Code metrics or Document hashes spec matches more documents than one read covers, so
/// no body ran (Story 24.1). Rendered on the <parameter>OcuPilot.Api.Error.BADREQUEST</parameter> slug with
/// 400, <code>detail.count</code> the documents it matches and <code>detail.max</code> the most one read
/// covers, and never logged.</p>
Parameter SPECTOOMANY = "EXPLORER.SPEC.TOOMANY";

Parameter REASONSPECTOOMANY = "That pattern matches more than 1,000 documents, the most one read covers. Narrow it to a package.";

/// <p>Envelope code: a person's unit-test run is asked while its governance key, <code>explorer.unittests.run</code>, is
/// off, which is how it ships (Story 24.5, AD-10, AD-22). Rendered on the <parameter>OcuPilot.Api.Error.FORBIDDEN</parameter>
/// slug with 403, before the hold and the fresh read, and never logged.</p>
Parameter UNITTESTOFF = "EXPLORER.UNITTEST.OFF";

Parameter REASONUNITTESTOFF = "Running unit tests is switched off on this instance. An administrator can switch it on in Governance policy.";

/// <p>Envelope code: no compiled test class matches the target the run names (Story 24.5). Rendered on the
/// <parameter>OcuPilot.Api.Error.NOTFOUND</parameter> slug with 404, and never logged.</p>
Parameter UNITTESTNOTFOUND = "EXPLORER.UNITTEST.NOTFOUND";

Parameter REASONUNITTESTNOTFOUND = "No compiled test class matches in this namespace.";

/// <p>Envelope code: a package holds more test classes than one run takes, so no body ran (Story 24.5). Rendered on the
/// <parameter>OcuPilot.Api.Error.BADREQUEST</parameter> slug with 400, <code>detail.count</code> the classes it holds and
/// <code>detail.max</code> the most one run takes, and never logged.</p>
Parameter UNITTESTTOOMANY = "EXPLORER.UNITTEST.TOOMANY";

Parameter REASONUNITTESTTOOMANY = "This package holds more test classes than one run takes.";

/// <p>Envelope code: the tests include a production test, which stops the running production (Story 24.5). Rendered on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409, and never logged.</p>
Parameter UNITTESTPRODUCTION = "EXPLORER.UNITTEST.PRODUCTION";

Parameter REASONUNITTESTPRODUCTION = "These tests include a production test, which stops the running production. OcuPilot does not run production tests.";

/// <p>Envelope code: another unit-test run holds the run lock (Story 24.5). Rendered on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409, and never logged.</p>
Parameter UNITTESTBUSY = "EXPLORER.UNITTEST.BUSY";

Parameter REASONUNITTESTBUSY = "Another unit-test run is in progress. Try again when it ends.";

/// <p>Envelope code: the target's first segment is OcuPilot's own (Story 24.5). Rendered on the
/// <parameter>OcuPilot.Api.Error.BADREQUEST</parameter> slug with 400, and never logged.</p>
Parameter UNITTESTOWNCODE = "EXPLORER.UNITTEST.OWNCODE";

Parameter REASONUNITTESTOWNCODE = "OcuPilot does not run its own tests.";

/// <p>Envelope code: the run left no new result in the namespace's record (Story 24.5). Rendered on the
/// <parameter>OcuPilot.Api.Error.SERVERERROR</parameter> slug with 500, and logged.</p>
Parameter UNITTESTNORESULT = "EXPLORER.UNITTEST.NORESULT";

Parameter REASONUNITTESTNORESULT = "The run recorded no results.";

/// <p>Envelope code: a person's command run is asked while its governance key, <code>explorer.command.run</code>, is off, which
/// is how it ships (Story 24.6, AD-10, AD-22). Rendered on the <parameter>OcuPilot.Api.Error.FORBIDDEN</parameter> slug with
/// 403, before the hold and the fresh read, and never logged.</p>
Parameter COMMANDOFF = "EXPLORER.COMMAND.OFF";

Parameter REASONCOMMANDOFF = "Running commands is switched off on this instance. An administrator can switch it on in Governance policy.";

/// <p>Envelope code: a person's class method call is asked while its governance key, <code>explorer.classmethod.run</code>,
/// is off, which is how it ships (Story 24.6). Rendered like <parameter>COMMANDOFF</parameter>.</p>
Parameter CLASSMETHODOFF = "EXPLORER.CLASSMETHOD.OFF";

Parameter REASONCLASSMETHODOFF = "Calling class methods is switched off on this instance. An administrator can switch it on in Governance policy.";

/// <p>Envelope code: the command names OcuPilot in any letter case (Story 24.6). Rendered on the
/// <parameter>OcuPilot.Api.Error.BADREQUEST</parameter> slug with 400, and never logged.</p>
Parameter COMMANDOWNCODE = "EXPLORER.COMMAND.OWNCODE";

Parameter REASONCOMMANDOWNCODE = "OcuPilot does not run a command that names OcuPilot.";

/// <p>Envelope code: the class's first segment is OcuPilot's own (Story 24.6). Rendered like
/// <parameter>COMMANDOWNCODE</parameter>.</p>
Parameter CLASSMETHODOWNCODE = "EXPLORER.CLASSMETHOD.OWNCODE";

Parameter REASONCLASSMETHODOWNCODE = "OcuPilot does not call its own class methods.";

/// <p>Envelope code: the namespace holds no compiled, public class method of that name (Story 24.6). Rendered on the
/// <parameter>OcuPilot.Api.Error.NOTFOUND</parameter> slug with 404, and never logged.</p>
Parameter CLASSMETHODNOTFOUND = "EXPLORER.CLASSMETHOD.NOTFOUND";

Parameter REASONCLASSMETHODNOTFOUND = "No compiled class method of that name is in this namespace.";

/// <p>Envelope code: the instance answered an error status for a statement write -- a freeze, an unfreeze, a clear or a clean (Story 21.6). Rendered on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409, the instance's message in <code>detail</code> alone and never logged
/// (AD-39).</p>
Parameter STATEMENTVENDOR = "SQL.STATEMENT.VENDOR";

Parameter REASONSTATEMENTVENDOR = "The instance did not apply this change to the statement.";

/// <p>Envelope codes: a statement write's precondition does not hold at the fresh read (Story 21.6). Each is the sentence a refused mint or screen
/// action states.</p>
Parameter STATEMENTALREADYFROZEN = "SQL.STATEMENT.ALREADYFROZEN";

Parameter REASONSTATEMENTALREADYFROZEN = "This statement's plan is already frozen.";

/// <p>A plan in the <code>Unfrozen/Parallel</code> state, for which the classic statement dialog disables its Freeze Plan button.</p>
Parameter STATEMENTPARALLEL = "SQL.STATEMENT.PARALLEL";

Parameter REASONSTATEMENTPARALLEL = "This statement's plan uses parallel processing and cannot be frozen.";

Parameter STATEMENTNOTFROZEN = "SQL.STATEMENT.NOTFROZEN";

Parameter REASONSTATEMENTNOTFROZEN = "This statement's plan is not frozen.";

Parameter STATEMENTNOERROR = "SQL.STATEMENT.NOERROR";

Parameter REASONSTATEMENTNOERROR = "This statement has no plan error.";

Parameter STATEMENTNOSTALE = "SQL.STATEMENT.NOSTALE";

Parameter REASONSTATEMENTNOSTALE = "This namespace's statement index holds no stale statements.";

/// <p>The sentences the 404 <code>PORT.NOTFOUND</code> of an absent statement hash and of an absent cached-query class state (Story 21.6).</p>
Parameter REASONSTATEMENTNOTFOUND = "This namespace holds no SQL statement with that hash.";

Parameter REASONCACHEDQUERYNOTFOUND = "This namespace holds no cached query by that name.";

/// <p>The consequence codes the proposal card and the dialog of each statement write and of the cached-query purges carry (Story 21.6).</p>
Parameter STATEMENTFREEZE = "SQL.STATEMENT.FREEZE";

Parameter REASONSTATEMENTFREEZE = "This statement keeps its current plan until it is unfrozen, even when its indices or table statistics change.";

Parameter STATEMENTUNFREEZE = "SQL.STATEMENT.UNFREEZE";

Parameter REASONSTATEMENTUNFREEZE = "This statement takes the plan the optimizer chooses the next time it is prepared.";

Parameter STATEMENTCLEARSTATISTICS = "SQL.STATEMENT.CLEARSTATISTICS";

Parameter REASONSTATEMENTCLEARSTATISTICS = "This statement's run statistics are removed, and counting starts again at its next run.";

Parameter STATEMENTCLEARERROR = "SQL.STATEMENT.CLEARERROR";

Parameter REASONSTATEMENTCLEARERROR = "The plan error is removed from the statement index. The plan itself is unchanged.";

Parameter STATEMENTCLEAN = "SQL.STATEMENT.CLEAN";

Parameter REASONSTATEMENTCLEAN = "Removes every statement in this namespace's index that no class or routine still holds. A statement whose plan is frozen stays.";

Parameter CACHEDQUERYPURGE = "SQL.CACHEDQUERY.PURGE";

Parameter REASONCACHEDQUERYPURGE = "The purged queries are prepared again the next time each one runs.";

/// <p>Envelope code: the instance answered an error status for a table write -- an index rebuild (Story 21.25). Rendered on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409, the instance's message in <code>detail</code> alone and never logged
/// (AD-39).</p>
Parameter TABLEVENDOR = "SQL.TABLE.VENDOR";

Parameter REASONTABLEVENDOR = "The instance did not apply this change to the table.";

/// <p>A rebuild of the table's data map, which holds the rows and has no index to rebuild (Story 21.25).</p>
Parameter TABLEDATAMAP = "SQL.TABLE.DATAMAP";

Parameter REASONTABLEDATAMAP = "This is the table's data map, which has no index to rebuild.";

/// <p>The consequence codes the proposal card and the dialog of each table write carry (Story 21.25).</p>
Parameter TABLEREBUILD = "SQL.TABLE.REBUILD";

Parameter REASONTABLEREBUILD = "This index is emptied and built again from the table's rows. The table is locked against changes while it runs. Changes to the table wait meanwhile, and fail if the rebuild outlasts their lock timeout.";

Parameter TABLEREBUILDALL = "SQL.TABLE.REBUILDALL";

Parameter REASONTABLEREBUILDALL = "Every index of this table is emptied and built again from its rows. The table is locked against changes while it runs. Changes to the table wait meanwhile, and fail if the rebuild outlasts their lock timeout.";

/// <p>The removal of fixed statistics from a table that has none (Story 21.25).</p>
Parameter TABLENOFIXEDSTATS = "SQL.TABLE.NOFIXEDSTATS";

Parameter REASONTABLENOFIXEDSTATS = "This table has no fixed statistics.";

/// <p>The consequence codes of the statistics writes: the collection of a table's statistics, the removal of its fixed statistics and the collection
/// of every table's in a schema (Story 21.25).</p>
Parameter TABLETUNE = "SQL.TABLE.TUNE";

Parameter REASONTABLETUNE = "The table's extent size and each field's selectivity are measured from its current rows. Some cached queries may be purged, including ones on other tables, so their plans may change.";

Parameter TABLECLEARSTATISTICS = "SQL.TABLE.CLEARSTATISTICS";

Parameter REASONTABLECLEARSTATISTICS = "The fixed statistics saved for this table are removed. The optimizer uses collected statistics, or none.";

Parameter TABLETUNESCHEMA = "SQL.TABLE.TUNESCHEMA";

Parameter REASONTABLETUNESCHEMA = "Every table in this schema is measured as Collect statistics measures one.";

/// <p>The consequence codes of the three fixed-statistics setters, which share one sentence (Story 21.31).</p>
Parameter TABLESETEXTENTSIZE = "SQL.TABLE.SETEXTENTSIZE";

Parameter TABLESETSELECTIVITY = "SQL.TABLE.SETSELECTIVITY";

Parameter TABLESETMAPSIZE = "SQL.TABLE.SETMAPSIZE";

Parameter REASONTABLESET = "The optimizer uses this value in place of the collected one until the table's fixed statistics are cleared. If the table's statistics were collected, they are first saved as its fixed statistics.";

/// <p>The shape refusals of the setters' values, each 400 <code>BAD_REQUEST</code> before any vendor call, from either caller (Story 21.31): an extent
/// size, a selectivity (and an outlier selectivity), a whole number 0 or more (a map's size and a field's average size), and an outlier value.</p>
Parameter TABLEEXTENTSIZE = "SQL.TABLE.EXTENTSIZE";

Parameter REASONTABLEEXTENTSIZE = "Enter a whole number from 0 to 1,000,000,000,000.";

Parameter TABLESELECTIVITY = "SQL.TABLE.SELECTIVITY";

Parameter REASONTABLESELECTIVITY = "Enter 1, or a percentage over 0% and up to 99.999%.";

Parameter TABLEWHOLENUMBER = "SQL.TABLE.WHOLENUMBER";

Parameter REASONTABLEWHOLENUMBER = "Enter a whole number, 0 or more.";

Parameter TABLEOUTLIERVALUE = "SQL.TABLE.OUTLIERVALUE";

Parameter REASONTABLEOUTLIERVALUE = "Enter at most 128 characters.";

/// <p>The sentence <var>pCode</var>, one of the <code>SQL.STATEMENT.*</code>, <code>SQL.CACHEDQUERY.*</code> and <code>SQL.TABLE.*</code> codes above,
/// carries, or <code>""</code> for any other code (Stories 21.6, 21.25 and 21.31).</p>
ClassMethod SqlReasonFor(pCode As %String) As %String
{
    If (pCode = ..#TABLESETEXTENTSIZE) || (pCode = ..#TABLESETSELECTIVITY) || (pCode = ..#TABLESETMAPSIZE) Quit ..#REASONTABLESET
    If pCode = ..#TABLEEXTENTSIZE Quit ..#REASONTABLEEXTENTSIZE
    If pCode = ..#TABLESELECTIVITY Quit ..#REASONTABLESELECTIVITY
    If pCode = ..#TABLEWHOLENUMBER Quit ..#REASONTABLEWHOLENUMBER
    If pCode = ..#TABLEOUTLIERVALUE Quit ..#REASONTABLEOUTLIERVALUE
    If pCode = ..#TABLEVENDOR Quit ..#REASONTABLEVENDOR
    If pCode = ..#TABLEDATAMAP Quit ..#REASONTABLEDATAMAP
    If pCode = ..#TABLEREBUILD Quit ..#REASONTABLEREBUILD
    If pCode = ..#TABLEREBUILDALL Quit ..#REASONTABLEREBUILDALL
    If pCode = ..#TABLENOFIXEDSTATS Quit ..#REASONTABLENOFIXEDSTATS
    If pCode = ..#TABLETUNE Quit ..#REASONTABLETUNE
    If pCode = ..#TABLECLEARSTATISTICS Quit ..#REASONTABLECLEARSTATISTICS
    If pCode = ..#TABLETUNESCHEMA Quit ..#REASONTABLETUNESCHEMA
    If pCode = ..#STATEMENTVENDOR Quit ..#REASONSTATEMENTVENDOR
    If pCode = ..#STATEMENTALREADYFROZEN Quit ..#REASONSTATEMENTALREADYFROZEN
    If pCode = ..#STATEMENTPARALLEL Quit ..#REASONSTATEMENTPARALLEL
    If pCode = ..#STATEMENTNOTFROZEN Quit ..#REASONSTATEMENTNOTFROZEN
    If pCode = ..#STATEMENTNOERROR Quit ..#REASONSTATEMENTNOERROR
    If pCode = ..#STATEMENTNOSTALE Quit ..#REASONSTATEMENTNOSTALE
    If pCode = ..#STATEMENTFREEZE Quit ..#REASONSTATEMENTFREEZE
    If pCode = ..#STATEMENTUNFREEZE Quit ..#REASONSTATEMENTUNFREEZE
    If pCode = ..#STATEMENTCLEARSTATISTICS Quit ..#REASONSTATEMENTCLEARSTATISTICS
    If pCode = ..#STATEMENTCLEARERROR Quit ..#REASONSTATEMENTCLEARERROR
    If pCode = ..#STATEMENTCLEAN Quit ..#REASONSTATEMENTCLEAN
    If pCode = ..#CACHEDQUERYPURGE Quit ..#REASONCACHEDQUERYPURGE
    Quit ""
}

/// <p>The sentence <var>pCode</var>, one of the seven <code>EXPLORER.UNITTEST.*</code> codes above or one of the five
/// <code>EXPLORER.COMMAND.*</code> and <code>EXPLORER.CLASSMETHOD.*</code> codes, carries, or <code>""</code> for any other
/// code (Stories 24.5 and 24.6).</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#UNITTESTOFF Quit ..#REASONUNITTESTOFF
    If pCode = ..#UNITTESTNOTFOUND Quit ..#REASONUNITTESTNOTFOUND
    If pCode = ..#UNITTESTTOOMANY Quit ..#REASONUNITTESTTOOMANY
    If pCode = ..#UNITTESTPRODUCTION Quit ..#REASONUNITTESTPRODUCTION
    If pCode = ..#UNITTESTBUSY Quit ..#REASONUNITTESTBUSY
    If pCode = ..#UNITTESTOWNCODE Quit ..#REASONUNITTESTOWNCODE
    If pCode = ..#UNITTESTNORESULT Quit ..#REASONUNITTESTNORESULT
    If pCode = ..#COMMANDOFF Quit ..#REASONCOMMANDOFF
    If pCode = ..#CLASSMETHODOFF Quit ..#REASONCLASSMETHODOFF
    If pCode = ..#COMMANDOWNCODE Quit ..#REASONCOMMANDOWNCODE
    If pCode = ..#CLASSMETHODOWNCODE Quit ..#REASONCLASSMETHODOWNCODE
    If pCode = ..#CLASSMETHODNOTFOUND Quit ..#REASONCLASSMETHODNOTFOUND
    Quit ""
}

}
