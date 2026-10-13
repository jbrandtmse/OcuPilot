/// <p>The interoperability codes and sentences (AD-29, AD-39, AD-62, Stories 20.2, 20.5, 20.6 and 20.27): every
/// <code>INTEROP.*</code> code <class>OcuPilot.Port.InteropPort</class> answers with, the four
/// consequence codes the production tools' proposals carry, and the sentence each carries. Each sentence
/// is published once in EXPERIENCE.md's Fixed strings and pinned equal to its
/// <file>ui/src/app/core/strings.ts</file> key by <file>ui/tools/interop.test.mjs</file>. They
/// live beside <class>OcuPilot.Api.Error</class> rather than in it because that class holds the
/// compiler's limit of 1,000 parameters (ERROR #5290).</p>
/// <p>Every refusal is rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409:
/// the vendor would have answered each as a success or a refusal that leaves the production as it was.</p>
Class OcuPilot.Api.InteropError Extends %RegisteredObject
{

/// <p>The route's namespace does not run interoperability productions.</p>
Parameter NAMESPACE = "INTEROP.NAMESPACE";

Parameter REASONNAMESPACE = "This namespace does not run interoperability productions.";

/// <p>Start of a production that is running.</p>
Parameter RUNNING = "INTEROP.PRODUCTION.RUNNING";

Parameter REASONRUNNING = "This production is already running.";

/// <p>Start of a production while another is current in the namespace (running, suspended or
/// troubled).</p>
Parameter OTHER = "INTEROP.PRODUCTION.OTHER";

Parameter REASONOTHER = "Another production is running, suspended or troubled in this namespace, and a namespace runs one production at a time.";

/// <p>Start of a production that did not shut down cleanly.</p>
Parameter TROUBLED = "INTEROP.PRODUCTION.TROUBLED";

Parameter REASONTROUBLED = "This production did not shut down cleanly. Recover it first; once it reads Suspended it can be started.";

/// <p>Stop, restart or update of a production that is not running.</p>
Parameter NOTRUNNING = "INTEROP.PRODUCTION.NOTRUNNING";

Parameter REASONNOTRUNNING = "This production is not running.";

/// <p>Update of a production with nothing pending.</p>
Parameter UPTODATE = "INTEROP.PRODUCTION.UPTODATE";

Parameter REASONUPTODATE = "This production is up to date, so there is nothing to update.";

/// <p>Recover of a production that is not troubled.</p>
Parameter NOTTROUBLED = "INTEROP.PRODUCTION.NOTTROUBLED";

Parameter REASONNOTTROUBLED = "Only a troubled production can be recovered.";

/// <p>The vendor refused a stop, restart or update because the production's work in progress did not
/// finish within the wait; the production is as it was.</p>
Parameter BUSY = "INTEROP.PRODUCTION.BUSY";

Parameter REASONBUSY = "The production's work in progress did not finish within 15 seconds, so it was left as it was.";

/// <p>The production's state is not one of Running, Stopped, Suspended and Troubled.</p>
Parameter STATE = "INTEROP.PRODUCTION.STATE";

Parameter REASONSTATE = "This production's state does not allow that action here.";

/// <p>The consequence codes the stop, restart, update and recover proposals carry. The client maps each
/// to its warning sentence (<file>ui/src/app/core/proposal-view.ts</file>).</p>
Parameter STOP = "INTEROP.STOP";

Parameter REASONSTOP = "Stopping this production waits up to 15 seconds for its work in progress to finish. If it takes longer, nothing is stopped; if a job then takes longer than 15 seconds to stop, the production is left partly stopped.";

Parameter RESTART = "INTEROP.RESTART";

Parameter REASONRESTART = "Restarting this production stops it and starts it again. If its work in progress takes longer than 15 seconds to finish, nothing is stopped; if a job then takes longer than 15 seconds to stop, the production is left partly stopped.";

Parameter UPDATE = "INTEROP.UPDATE";

Parameter REASONUPDATE = "Updating this production restarts only the items whose settings changed, and starts or stops the items enabled or disabled since it started. If an item takes longer than 15 seconds to finish its work, the update is refused and the production keeps running.";

Parameter RECOVER = "INTEROP.RECOVER";

Parameter REASONRECOVER = "Recover is the first response to a troubled production: it returns it to Suspended so it can be started again, marking messages it cannot keep queued as Discarded or Suspended and deleting none. Clean, which deletes queued messages, is a last resort OcuPilot does not offer.";

/// <p>A stop that answered success while messages still queued left the production Suspended rather than
/// Stopped. The stop was applied.</p>
Parameter SUSPENDED = "INTEROP.PRODUCTION.SUSPENDED";

Parameter REASONSUSPENDED = "The production stopped, but messages still queued left it Suspended rather than Stopped. Start it to process them.";

/// <p>A stop or restart whose jobs outlasted the wait after the production quiesced: the vendor answers
/// <code>ErrJobsNotStopped</code> and the production reads Running with only the stuck jobs.</p>
Parameter PARTSTOPPED = "INTEROP.PRODUCTION.PARTSTOPPED";

Parameter REASONPARTSTOPPED = "Some of the production's jobs did not stop within 15 seconds, so it is left partly stopped and still reads Running. Stop it again to finish, or update it to start its jobs again.";

/// <p>An item write on an item that is already enabled.</p>
Parameter ITEMENABLED = "INTEROP.ITEM.ENABLED";

Parameter REASONITEMENABLED = "This item is already enabled.";

/// <p>An item write on an item that is already disabled.</p>
Parameter ITEMDISABLED = "INTEROP.ITEM.DISABLED";

Parameter REASONITEMDISABLED = "This item is already disabled.";

/// <p>An enable or disable of an item whose <code>Enabled</code> a system default setting supplies: the
/// vendor would change the default's row and leave the production alone.</p>
Parameter ITEMDEFAULTSETTING = "INTEROP.ITEM.DEFAULTSETTING";

Parameter REASONITEMDEFAULTSETTING = "A system default setting decides whether this item is enabled, so change it in System Default Settings.";

/// <p>A disable of a business process that runs in the production's shared actor pool.</p>
Parameter ITEMPOOLZERO = "INTEROP.ITEM.POOLZERO";

Parameter REASONITEMPOOLZERO = "This business process runs in the production's shared actor pool, so it cannot be disabled.";

/// <p>An add of a name the production already holds.</p>
Parameter ITEMTAKEN = "INTEROP.ITEM.TAKEN";

Parameter REASONITEMTAKEN = "This production already holds an item of that name.";

/// <p>A write on a name the production holds more than once.</p>
Parameter ITEMAMBIGUOUS = "INTEROP.ITEM.AMBIGUOUS";

Parameter REASONITEMAMBIGUOUS = "This production holds more than one item of that name, so change it in the classic production configuration page.";

/// <p>Violation code (422), on <code>ClassName</code>: not a business service, process or operation class
/// compiled in the namespace.</p>
Parameter ITEMCLASS = "INTEROP.ITEM.CLASS";

Parameter REASONITEMCLASS = "Name a business service, business process or business operation class compiled in this namespace.";

/// <p>Violation code (422), on <code>Name</code>: a name the configuration refuses. The rule is
/// <method>OcuPilot.Port.InteropPort.NameProblem</method>'s.</p>
Parameter ITEMNAME = "INTEROP.ITEM.NAME";

Parameter REASONITEMNAME = "An item name is 1 to 128 characters with no control character and no space at either end. It cannot contain a vertical bar, a semicolon, a comma or an opening bracket, begin with a hyphen or an underscore, end with a hyphen, an exclamation mark or a dollar sign, or be an asterisk.";

/// <p>Violation code (422): a value the item's own property refuses (pool size, category or comment).</p>
Parameter ITEMVALUE = "INTEROP.ITEM.VALUE";

Parameter REASONITEMVALUE = "A production item does not accept this value for that field.";

/// <p>A remove of an item that is enabled.</p>
Parameter ITEMENABLEDREMOVE = "INTEROP.ITEM.ENABLEDREMOVE";

Parameter REASONITEMENABLEDREMOVE = "Disable this item before removing it.";

/// <p>Every item write in a namespace under source control.</p>
Parameter ITEMSOURCECONTROL = "INTEROP.ITEM.SOURCECONTROL";

Parameter REASONITEMSOURCECONTROL = "This namespace uses source control, so change this production's items in the classic production configuration page.";

/// <p>The consequence codes the enable, disable and add proposals, and the remove proposal, carry.</p>
Parameter ITEMPENDING = "INTEROP.ITEM.PENDING";

Parameter REASONITEMPENDING = "The change takes effect when this production next starts or, while it runs, when it is updated on Productions.";

Parameter ITEMREMOVE = "INTEROP.ITEM.REMOVE";

Parameter REASONITEMREMOVE = "Removing this item deletes it and every setting it holds from the production.";

/// <p>A set or reset of a setting whose name the credential pattern matches (Story 20.22): OcuPilot neither shows
/// nor sets such a value.</p>
Parameter SETTINGSECRET = "INTEROP.SETTING.SECRET";

Parameter REASONSETTINGSECRET = "This setting holds a secret, so OcuPilot neither shows nor sets it. Set it in the classic production configuration page, or point the item at a credentials entry.";

/// <p>A set or reset of a setting a system default or a service registry entry decides.</p>
Parameter SETTINGSUPPLIED = "INTEROP.SETTING.SUPPLIED";

Parameter REASONSETTINGSUPPLIED = "A system default setting or a service registry entry decides this setting's value, so change it there.";

/// <p>A set of a value the production already holds.</p>
Parameter SETTINGSAME = "INTEROP.SETTING.SAME";

Parameter REASONSETTINGSAME = "This setting already holds that value.";

/// <p>A reset of a setting that already takes its default.</p>
Parameter SETTINGDEFAULTED = "INTEROP.SETTING.DEFAULTED";

Parameter REASONSETTINGDEFAULTED = "This setting already takes its default value, so there is nothing to reset.";

/// <p>A reset of one of the item's own properties.</p>
Parameter SETTINGCORE = "INTEROP.SETTING.CORE";

Parameter REASONSETTINGCORE = "This is one of the item's own properties, which has no default to return to, so set the value you want instead.";

/// <p>Violation code (422), on <code>Value</code>: a value the declaring class refuses, or one with a space or a
/// control character at either end, which the vendor would store trimmed.</p>
Parameter SETTINGVALUE = "INTEROP.SETTING.VALUE";

Parameter REASONSETTINGVALUE = "The item's class does not accept this value for this setting.";

/// <p>The consequence code a set of a server-path setting carries.</p>
Parameter SETTINGLOCATION = "INTEROP.SETTING.LOCATION";

Parameter REASONSETTINGLOCATION = "<value> is a location on this server that the item reads or writes when it runs. The change takes effect when this production next starts or, while it runs, when it is updated on Productions.";

/// <p>A set or reset of <code>FilePath</code> or <code>SubdirectoryLevels</code> that lets an inbound file adapter
/// descend into the manager directory or the directory OcuPilot serves its files from.</p>
Parameter SETTINGDESCENT = "INTEROP.SETTING.DESCENT";

Parameter REASONSETTINGDESCENT = "This item also reads the directories below its file path, as many levels down as its subdirectory levels, and that would reach the manager directory or the directory OcuPilot serves its files from. Choose another file path or fewer subdirectory levels.";

/// <p>An abort of a queue that holds no waiting message (Story 20.23): the vendor answers success and does nothing.</p>
Parameter QUEUEEMPTY = "INTEROP.QUEUE.EMPTY";

Parameter REASONQUEUEEMPTY = "This queue holds no messages, so there is nothing to abort.";

/// <p>An abort of a queue whose messages are not the ones its read enumerated: nothing is aborted.</p>
Parameter QUEUECHANGED = "INTEROP.QUEUE.CHANGED";

Parameter REASONQUEUECHANGED = "The messages in this queue changed after they were reviewed, so nothing was aborted. Review the queue again.";

/// <p>An action on a job whose process has ended.</p>
Parameter JOBDEAD = "INTEROP.JOB.DEAD";

Parameter REASONJOBDEAD = "This job's process has already ended, so there is nothing to act on. Update the production on Productions to start its jobs again.";

/// <p>An abort or suspend of a job that is not retrying a message: the vendor answers success for any job and leaves the
/// request set.</p>
Parameter JOBNOTRETRYING = "INTEROP.JOB.NOTRETRYING";

Parameter REASONJOBNOTRETRYING = "This job is not retrying a message now, so there is no message to abort or suspend. Its message can be aborted or suspended only while the job waits to retry it.";

/// <p>A stop the vendor could not complete: the job did not stop within the wait, even after it was ended.</p>
Parameter JOBNOTSTOPPED = "INTEROP.JOB.NOTSTOPPED";

Parameter REASONJOBNOTSTOPPED = "The job did not stop within the wait, even after it was ended. Look at Jobs again, and update the production on Productions to start its jobs again.";

/// <p>The consequence codes the queue and job action proposals carry (Story 20.23). The client maps each to its
/// warning sentence (<file>ui/src/app/core/proposal-view.ts</file>).</p>
Parameter MESSAGEABORT = "INTEROP.MESSAGE.ABORT";

Parameter REASONMESSAGEABORT = "Aborting this message takes it off its queue and marks it Aborted, so it is never delivered, and a caller waiting for its reply receives an error instead. It cannot be undone.";

Parameter QUEUEABORT = "INTEROP.QUEUE.ABORT";

Parameter REASONQUEUEABORT = "Aborting all messages takes the messages waiting in this queue now, up to the first 10,000, off it and marks each Aborted, so none is delivered. A message that arrives later stays, and so does one a job is already working on. It cannot be undone.";

Parameter JOBABORT = "INTEROP.JOB.ABORT";

Parameter REASONJOBABORT = "Aborting this job's message marks the message it keeps retrying Aborted when its current retry wait ends, so it is never delivered, and the job moves on to its next message. It cannot be undone.";

Parameter JOBSUSPEND = "INTEROP.JOB.SUSPEND";

Parameter REASONJOBSUSPEND = "Suspending this job's message sets the message it keeps retrying aside as Suspended when its current retry wait ends, and the job moves on to its next message. A suspended message can be resent later.";

Parameter JOBSTOP = "INTEROP.JOB.STOP";

Parameter REASONJOBSTOP = "Stopping this job asks it to finish its current message within 15 seconds, or sooner when the production's update timeout is shorter. A job that does not is ended, and its message goes back on its queue. The item runs a job short until the production is updated on Productions.";

/// <p>An add of a key the lookup table already holds (Story 20.5).</p>
Parameter LOOKUPTAKEN = "INTEROP.LOOKUP.TAKEN";

Parameter REASONLOOKUPTAKEN = "This lookup table already holds an entry with that key.";

/// <p>An add into a table whose name differs only in letter case from one the namespace holds: table names are case
/// sensitive and the classic page treats them as one table.</p>
Parameter LOOKUPTABLECASE = "INTEROP.LOOKUP.TABLECASE";

Parameter REASONLOOKUPTABLECASE = "A lookup table whose name differs from this one only in letter case already exists. Use its spelling, or choose another name.";

/// <p>A set of the value the entry already holds.</p>
Parameter LOOKUPSAME = "INTEROP.LOOKUP.SAME";

Parameter REASONLOOKUPSAME = "This entry already holds that value.";

/// <p>An add or a set of an entry whose key the credential pattern matches: OcuPilot neither shows nor sets such a value.</p>
Parameter LOOKUPSECRET = "INTEROP.LOOKUP.SECRET";

Parameter REASONLOOKUPSECRET = "This key names a credential, so OcuPilot neither shows nor sets its value. Set it in the classic Lookup Tables page.";

/// <p>Every lookup write in a namespace under source control.</p>
Parameter LOOKUPSOURCECONTROL = "INTEROP.LOOKUP.SOURCECONTROL";

Parameter REASONLOOKUPSOURCECONTROL = "This namespace uses source control, so change lookup tables in the classic Lookup Tables page.";

/// <p>A lookup write while the vendor's own table lock is held past the wait.</p>
Parameter LOOKUPLOCKED = "INTEROP.LOOKUP.LOCKED";

Parameter REASONLOOKUPLOCKED = "Someone else is changing this lookup table right now, so nothing was written. Try again in a moment.";

/// <p>Violation codes (422): a table name, an entry key and an entry value the vendor's own limits refuse, and a table name and
/// key too long together for the instance to address (the key's violation). The rules are
/// <method>OcuPilot.Port.InteropPort.LookupViolations</method>'s.</p>
Parameter LOOKUPTABLENAME = "INTEROP.LOOKUP.TABLENAME";

Parameter REASONLOOKUPTABLENAME = "A lookup table name is 1 to 255 characters with no control character, within the length the instance can store.";

Parameter LOOKUPKEY = "INTEROP.LOOKUP.KEY";

Parameter REASONLOOKUPKEY = "An entry key is 1 to 255 characters with no control character, and with its table's name within the length the instance can store.";

Parameter LOOKUPVALUE = "INTEROP.LOOKUP.VALUE";

Parameter REASONLOOKUPVALUE = "An entry value is at most 32,000 characters.";

/// <p>An import file that is not exactly one lookup table with at least one entry and nothing else, or that holds another table than
/// the one named (Story 20.5).</p>
Parameter LOOKUPIMPORTSHAPE = "INTEROP.LOOKUP.IMPORTSHAPE";

Parameter REASONLOOKUPIMPORTSHAPE = "An import file must hold exactly one lookup table with at least one entry and nothing else, in the form the Export action writes.";

/// <p>An import whose file, or whose table, is not what it was reviewed as.</p>
Parameter LOOKUPIMPORTCHANGED = "INTEROP.LOOKUP.IMPORTCHANGED";

Parameter REASONLOOKUPIMPORTCHANGED = "The file or the table changed after the import was reviewed, so nothing was imported. Review the import again.";

/// <p>An export or an import file longer than <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter> characters; the
/// sentence states that number, pinned by <file>ui/tools/interop.test.mjs</file>.</p>
Parameter LOOKUPTOOLARGE = "INTEROP.LOOKUP.TOOLARGE";

Parameter REASONLOOKUPTOOLARGE = "A lookup table file holds at most 3,000,000 characters, and this one holds more.";

/// <p>An export of a table whose name the vendor's export reads as a pattern, a path or a separator, so it cannot name the table's
/// own document (<method>OcuPilot.Port.InteropPort.LookupAddressable</method>).</p>
Parameter LOOKUPEXPORTNAME = "INTEROP.LOOKUP.EXPORTNAME";

Parameter REASONLOOKUPEXPORTNAME = "This lookup table cannot be exported: its name holds a character the export reads as a pattern or a path (* ? / or ;) or begins with an apostrophe.";

/// <p>The consequence code the import proposal carries.</p>
Parameter LOOKUPIMPORT = "INTEROP.LOOKUP.IMPORT";

Parameter REASONLOOKUPIMPORT = "Importing replaces the table's entries with the file's, and entries the file does not hold are removed.";

/// <p>The consequence codes the entry remove and the table delete proposals carry (Story 20.5). The client maps each to its
/// warning sentence (<file>ui/src/app/core/proposal-view.ts</file>).</p>
Parameter LOOKUPREMOVE = "INTEROP.LOOKUP.REMOVE";

Parameter REASONLOOKUPREMOVE = "Removing this entry cannot be undone from OcuPilot. When it is the table's last entry, the table is removed too.";

Parameter LOOKUPDELETE = "INTEROP.LOOKUP.DELETE";

Parameter REASONLOOKUPDELETE = "Deleting this lookup table removes every entry in it. Rules and transformations that read it then get their default value.";

/// <p>The host test's refusals and violations (Story 20.6). The first five refuse a test before a request is built, each 409 on the
/// <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug, and the last three are the 422 violations of a request's fields.
/// <code>INTEROP.PRODUCTION.NOTRUNNING</code> is the production-not-running refusal, reused.</p>
Parameter TESTDISABLED = "INTEROP.TEST.DISABLED";

Parameter REASONTESTDISABLED = "Testing is not enabled for this production. Turn on Testing Enabled in the classic production settings, then update the production.";

Parameter TESTTARGETTYPE = "INTEROP.TEST.TARGETTYPE";

Parameter REASONTESTTARGETTYPE = "Only a business process or a business operation takes a test request.";

Parameter TESTTARGETDISABLED = "INTEROP.TEST.TARGETDISABLED";

Parameter REASONTESTTARGETDISABLED = "This item is disabled, so a test request would wait in its queue with no answer. Enable it first.";

Parameter TESTREQUESTTYPE = "INTEROP.TEST.REQUESTTYPE";

Parameter REASONTESTREQUESTTYPE = "This host does not take that request class. Its Test tab lists the ones it takes.";

Parameter TESTSECRET = "INTEROP.TEST.SECRET";

Parameter REASONTESTSECRET = "This field names a credential, so OcuPilot sends no value for it. Leave it empty, or test in the classic Testing Service page.";

Parameter TESTFIELD = "INTEROP.TEST.FIELD";

Parameter REASONTESTFIELD = "The request class has no such field that a test can set.";

Parameter TESTVALUE = "INTEROP.TEST.VALUE";

Parameter REASONTESTVALUE = "This value does not fit the field, or the field is required.";

Parameter TESTREQUEST = "INTEROP.TEST.REQUEST";

Parameter REASONTESTREQUEST = "The request could not be built from these values.";

/// <p>The consequence code the host test's proposal carries. The client maps it to its published sentence.</p>
Parameter TESTSENDS = "INTEROP.TEST.SENDS";

Parameter REASONTESTSENDS = "A test sends a real message through the running production. The target runs it, and anything it sends on, to another host or outside this instance, is sent too. The test's messages stay in the message store.";

/// <p>The data transformation test's refusals (Story 20.27). The first two refuse a transformation whose source or target class
/// OcuPilot cannot read or show as text, each 409 on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug, before anything is
/// parsed or run. <parameter>TRANSFORMCONTENT</parameter> is the 422 violation of the pasted source message, empty or past
/// <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter>. <code>INTEROP.NAMESPACE</code> is the namespace refusal,
/// reused.</p>
Parameter TRANSFORMSOURCEFORMAT = "INTEROP.TRANSFORM.SOURCEFORMAT";

Parameter REASONTRANSFORMSOURCEFORMAT = "OcuPilot reads a pasted source only as an HL7 or other EDI document's text, or as XML. This transformation's source is neither, so test it in the classic portal.";

Parameter TRANSFORMTARGETFORMAT = "INTEROP.TRANSFORM.TARGETFORMAT";

Parameter REASONTRANSFORMTARGETFORMAT = "OcuPilot shows a target only as an EDI document's text or as XML. This transformation's target is neither, so test it in the classic portal.";

Parameter TRANSFORMCONTENT = "INTEROP.TRANSFORM.CONTENT";

Parameter REASONTRANSFORMCONTENT = "Paste the source message, at most 3,000,000 characters.";

/// <p>The consequence code the data transformation test's proposal carries. The client maps it to its published sentence.</p>
Parameter TRANSFORMRUNS = "INTEROP.TRANSFORM.RUNS";

Parameter REASONTRANSFORMRUNS = "The transformation's code runs on this instance as you, on the input shown. Whatever it writes or sends, it writes or sends.";

/// <p>The refusals the port answers with, as a <class>%List</class>: every code that is not a
/// consequence.</p>
ClassMethod Codes() As %List
{
    Quit $ListBuild(..#NAMESPACE, ..#RUNNING, ..#OTHER, ..#TROUBLED, ..#NOTRUNNING, ..#UPTODATE, ..#NOTTROUBLED, ..#BUSY, ..#STATE, ..#SUSPENDED, ..#PARTSTOPPED) _ ..ItemCodes() _ ..SettingCodes() _ ..RuntimeCodes() _ ..LookupCodes() _ ..TestCodes() _ ..TransformCodes()
}

/// <p>The consequence codes, as a <class>%List</class>.</p>
ClassMethod ConsequenceCodes() As %List
{
    Quit $ListBuild(..#STOP, ..#RESTART, ..#UPDATE, ..#RECOVER, ..#ITEMPENDING, ..#ITEMREMOVE, ..#SETTINGLOCATION, ..#MESSAGEABORT, ..#QUEUEABORT, ..#JOBABORT, ..#JOBSUSPEND, ..#JOBSTOP, ..#LOOKUPREMOVE, ..#LOOKUPDELETE, ..#LOOKUPIMPORT, ..#TESTSENDS, ..#TRANSFORMRUNS)
}

/// <p>The item codes, as a <class>%List</class>: the refusals an item read or write answers with.</p>
ClassMethod ItemCodes() As %List
{
    Quit $ListBuild(..#ITEMENABLED, ..#ITEMDISABLED, ..#ITEMDEFAULTSETTING, ..#ITEMPOOLZERO, ..#ITEMTAKEN, ..#ITEMAMBIGUOUS, ..#ITEMCLASS, ..#ITEMNAME, ..#ITEMVALUE, ..#ITEMENABLEDREMOVE, ..#ITEMSOURCECONTROL)
}

/// <p>The item refusals an item tool's fresh read answers when the action does not fit the item, as a
/// <class>%List</class>; the field violations (<parameter>ITEMCLASS</parameter>, <parameter>ITEMNAME</parameter>
/// and <parameter>ITEMVALUE</parameter>) are an add's body and are not among them.</p>
ClassMethod ItemPreconditionCodes() As %List
{
    Quit $ListBuild(..#ITEMENABLED, ..#ITEMDISABLED, ..#ITEMDEFAULTSETTING, ..#ITEMPOOLZERO, ..#ITEMTAKEN, ..#ITEMAMBIGUOUS, ..#ITEMENABLEDREMOVE, ..#ITEMSOURCECONTROL)
}

/// <p>The setting codes (Story 20.22), as a <class>%List</class>: the refusals an item setting read or write answers
/// with, and the two violations of a set's value.</p>
ClassMethod SettingCodes() As %List
{
    Quit $ListBuild(..#SETTINGSECRET, ..#SETTINGSUPPLIED, ..#SETTINGSAME, ..#SETTINGDEFAULTED, ..#SETTINGCORE, ..#SETTINGVALUE, ..#SETTINGDESCENT)
}

/// <p>The setting refusals a setting tool's fresh read answers when the action does not fit the setting, as a
/// <class>%List</class>; the violations (<parameter>SETTINGVALUE</parameter> and <parameter>SETTINGDESCENT</parameter>)
/// and <parameter>SETTINGSAME</parameter>, which the write alone judges, are not among them.</p>
ClassMethod SettingPreconditionCodes() As %List
{
    Quit $ListBuild(..#SETTINGSECRET, ..#SETTINGSUPPLIED, ..#SETTINGDEFAULTED, ..#SETTINGCORE)
}

/// <p>The queue and job codes (Story 20.23), as a <class>%List</class>: the refusals a queue or job read composed for an
/// action answers with, and the vendor refusal of a stop. The five consequence codes are
/// <method>ConsequenceCodes</method>'s.</p>
ClassMethod RuntimeCodes() As %List
{
    Quit $ListBuild(..#QUEUEEMPTY, ..#QUEUECHANGED, ..#JOBDEAD, ..#JOBNOTRETRYING, ..#JOBNOTSTOPPED)
}

/// <p>The lookup codes (Story 20.5), as a <class>%List</class>: the refusals a lookup read or write answers with, the three
/// violations of an entry's table, key and value and the four refusals of an import file and an export. The three consequence
/// codes are <method>ConsequenceCodes</method>'s.</p>
ClassMethod LookupCodes() As %List
{
    Quit $ListBuild(..#LOOKUPTAKEN, ..#LOOKUPTABLECASE, ..#LOOKUPSAME, ..#LOOKUPSECRET, ..#LOOKUPSOURCECONTROL, ..#LOOKUPLOCKED, ..#LOOKUPTABLENAME, ..#LOOKUPKEY, ..#LOOKUPVALUE, ..#LOOKUPIMPORTSHAPE, ..#LOOKUPIMPORTCHANGED, ..#LOOKUPTOOLARGE, ..#LOOKUPEXPORTNAME)
}

/// <p>The lookup refusals an entry tool's fresh read answers when the action does not fit the entry, as a
/// <class>%List</class>; the violations and <parameter>LOOKUPLOCKED</parameter>, which the write alone judges, and
/// <parameter>LOOKUPSAME</parameter>, which the write and the set's mint judge, are not among them.</p>
ClassMethod LookupPreconditionCodes() As %List
{
    Quit $ListBuild(..#LOOKUPTAKEN, ..#LOOKUPTABLECASE, ..#LOOKUPSECRET, ..#LOOKUPSOURCECONTROL)
}

/// <p>The host test's codes (Story 20.6), as a <class>%List</class>: the five refusals a test is refused with before a request is
/// built and the three violations of its fields. The consequence code is <method>ConsequenceCodes</method>'s.</p>
ClassMethod TestCodes() As %List
{
    Quit $ListBuild(..#TESTDISABLED, ..#TESTTARGETTYPE, ..#TESTTARGETDISABLED, ..#TESTREQUESTTYPE, ..#TESTSECRET, ..#TESTFIELD, ..#TESTVALUE, ..#TESTREQUEST)
}

/// <p>The test refusals the host test tool's fresh read answers when the test does not fit the item, as a <class>%List</class>:
/// the production-not-running refusal and the four that follow it in the read's order, then the credential refusal. The
/// violations (<parameter>TESTFIELD</parameter>, <parameter>TESTVALUE</parameter> and <parameter>TESTREQUEST</parameter>) are the
/// request's and are not among them.</p>
ClassMethod TestPreconditionCodes() As %List
{
    Quit $ListBuild(..#NOTRUNNING, ..#TESTDISABLED, ..#TESTTARGETTYPE, ..#TESTTARGETDISABLED, ..#TESTREQUESTTYPE, ..#TESTSECRET)
}

/// <p>The data transformation test's codes (Story 20.27), as a <class>%List</class>: the two format refusals and the violation of the
/// pasted source message. The consequence code is <method>ConsequenceCodes</method>'s.</p>
ClassMethod TransformCodes() As %List
{
    Quit $ListBuild(..#TRANSFORMSOURCEFORMAT, ..#TRANSFORMTARGETFORMAT, ..#TRANSFORMCONTENT)
}

/// <p>The refusals the data transformation tool's fresh read answers when the transformation cannot be tested, as a
/// <class>%List</class>: the source format, then the target format. The content violation is the pasted message's and is not
/// among them.</p>
ClassMethod TransformPreconditionCodes() As %List
{
    Quit $ListBuild(..#TRANSFORMSOURCEFORMAT, ..#TRANSFORMTARGETFORMAT)
}

/// <p>The codes a production tool's fresh read refuses with when the action's precondition does not
/// hold, as a <class>%List</class>: <class>OcuPilot.Screen.Tool.Write</class>'s
/// <code>PRECONDITIONCODES</code>.</p>
ClassMethod PreconditionCodes() As %List
{
    Quit $ListBuild(..#RUNNING, ..#OTHER, ..#TROUBLED, ..#NOTRUNNING, ..#UPTODATE, ..#NOTTROUBLED, ..#STATE)
}

/// <p>The sentence <var>pCode</var> carries, or <code>""</code> for any code this class does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#NAMESPACE Quit ..#REASONNAMESPACE
    If pCode = ..#RUNNING Quit ..#REASONRUNNING
    If pCode = ..#OTHER Quit ..#REASONOTHER
    If pCode = ..#TROUBLED Quit ..#REASONTROUBLED
    If pCode = ..#NOTRUNNING Quit ..#REASONNOTRUNNING
    If pCode = ..#UPTODATE Quit ..#REASONUPTODATE
    If pCode = ..#NOTTROUBLED Quit ..#REASONNOTTROUBLED
    If pCode = ..#BUSY Quit ..#REASONBUSY
    If pCode = ..#STATE Quit ..#REASONSTATE
    If pCode = ..#STOP Quit ..#REASONSTOP
    If pCode = ..#RESTART Quit ..#REASONRESTART
    If pCode = ..#UPDATE Quit ..#REASONUPDATE
    If pCode = ..#RECOVER Quit ..#REASONRECOVER
    If pCode = ..#SUSPENDED Quit ..#REASONSUSPENDED
    If pCode = ..#PARTSTOPPED Quit ..#REASONPARTSTOPPED
    If pCode = ..#ITEMENABLED Quit ..#REASONITEMENABLED
    If pCode = ..#ITEMDISABLED Quit ..#REASONITEMDISABLED
    If pCode = ..#ITEMDEFAULTSETTING Quit ..#REASONITEMDEFAULTSETTING
    If pCode = ..#ITEMPOOLZERO Quit ..#REASONITEMPOOLZERO
    If pCode = ..#ITEMTAKEN Quit ..#REASONITEMTAKEN
    If pCode = ..#ITEMAMBIGUOUS Quit ..#REASONITEMAMBIGUOUS
    If pCode = ..#ITEMCLASS Quit ..#REASONITEMCLASS
    If pCode = ..#ITEMNAME Quit ..#REASONITEMNAME
    If pCode = ..#ITEMVALUE Quit ..#REASONITEMVALUE
    If pCode = ..#ITEMENABLEDREMOVE Quit ..#REASONITEMENABLEDREMOVE
    If pCode = ..#ITEMSOURCECONTROL Quit ..#REASONITEMSOURCECONTROL
    If pCode = ..#ITEMPENDING Quit ..#REASONITEMPENDING
    If pCode = ..#ITEMREMOVE Quit ..#REASONITEMREMOVE
    If pCode = ..#SETTINGSECRET Quit ..#REASONSETTINGSECRET
    If pCode = ..#SETTINGSUPPLIED Quit ..#REASONSETTINGSUPPLIED
    If pCode = ..#SETTINGSAME Quit ..#REASONSETTINGSAME
    If pCode = ..#SETTINGDEFAULTED Quit ..#REASONSETTINGDEFAULTED
    If pCode = ..#SETTINGCORE Quit ..#REASONSETTINGCORE
    If pCode = ..#SETTINGVALUE Quit ..#REASONSETTINGVALUE
    If pCode = ..#SETTINGLOCATION Quit ..#REASONSETTINGLOCATION
    If pCode = ..#SETTINGDESCENT Quit ..#REASONSETTINGDESCENT
    If pCode = ..#QUEUEEMPTY Quit ..#REASONQUEUEEMPTY
    If pCode = ..#QUEUECHANGED Quit ..#REASONQUEUECHANGED
    If pCode = ..#JOBDEAD Quit ..#REASONJOBDEAD
    If pCode = ..#JOBNOTRETRYING Quit ..#REASONJOBNOTRETRYING
    If pCode = ..#JOBNOTSTOPPED Quit ..#REASONJOBNOTSTOPPED
    If pCode = ..#MESSAGEABORT Quit ..#REASONMESSAGEABORT
    If pCode = ..#QUEUEABORT Quit ..#REASONQUEUEABORT
    If pCode = ..#JOBABORT Quit ..#REASONJOBABORT
    If pCode = ..#JOBSUSPEND Quit ..#REASONJOBSUSPEND
    If pCode = ..#JOBSTOP Quit ..#REASONJOBSTOP
    If pCode = ..#LOOKUPTAKEN Quit ..#REASONLOOKUPTAKEN
    If pCode = ..#LOOKUPTABLECASE Quit ..#REASONLOOKUPTABLECASE
    If pCode = ..#LOOKUPSAME Quit ..#REASONLOOKUPSAME
    If pCode = ..#LOOKUPSECRET Quit ..#REASONLOOKUPSECRET
    If pCode = ..#LOOKUPSOURCECONTROL Quit ..#REASONLOOKUPSOURCECONTROL
    If pCode = ..#LOOKUPLOCKED Quit ..#REASONLOOKUPLOCKED
    If pCode = ..#LOOKUPTABLENAME Quit ..#REASONLOOKUPTABLENAME
    If pCode = ..#LOOKUPKEY Quit ..#REASONLOOKUPKEY
    If pCode = ..#LOOKUPVALUE Quit ..#REASONLOOKUPVALUE
    If pCode = ..#LOOKUPREMOVE Quit ..#REASONLOOKUPREMOVE
    If pCode = ..#LOOKUPDELETE Quit ..#REASONLOOKUPDELETE
    If pCode = ..#LOOKUPIMPORTSHAPE Quit ..#REASONLOOKUPIMPORTSHAPE
    If pCode = ..#LOOKUPIMPORTCHANGED Quit ..#REASONLOOKUPIMPORTCHANGED
    If pCode = ..#LOOKUPTOOLARGE Quit ..#REASONLOOKUPTOOLARGE
    If pCode = ..#LOOKUPEXPORTNAME Quit ..#REASONLOOKUPEXPORTNAME
    If pCode = ..#LOOKUPIMPORT Quit ..#REASONLOOKUPIMPORT
    If pCode = ..#TESTDISABLED Quit ..#REASONTESTDISABLED
    If pCode = ..#TESTTARGETTYPE Quit ..#REASONTESTTARGETTYPE
    If pCode = ..#TESTTARGETDISABLED Quit ..#REASONTESTTARGETDISABLED
    If pCode = ..#TESTREQUESTTYPE Quit ..#REASONTESTREQUESTTYPE
    If pCode = ..#TESTSECRET Quit ..#REASONTESTSECRET
    If pCode = ..#TESTFIELD Quit ..#REASONTESTFIELD
    If pCode = ..#TESTVALUE Quit ..#REASONTESTVALUE
    If pCode = ..#TESTREQUEST Quit ..#REASONTESTREQUEST
    If pCode = ..#TESTSENDS Quit ..#REASONTESTSENDS
    If pCode = ..#TRANSFORMSOURCEFORMAT Quit ..#REASONTRANSFORMSOURCEFORMAT
    If pCode = ..#TRANSFORMTARGETFORMAT Quit ..#REASONTRANSFORMTARGETFORMAT
    If pCode = ..#TRANSFORMCONTENT Quit ..#REASONTRANSFORMCONTENT
    If pCode = ..#TRANSFORMRUNS Quit ..#REASONTRANSFORMRUNS
    Quit ""
}

}
