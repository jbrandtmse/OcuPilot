/// <p>The port to the instance's interoperability runtime (AD-62, AD-29, AD-52, Stories 20.2, 20.3, 20.5, 20.6, 20.23, 20.26, 20.27, 20.31, 20.40, 20.41 and 24.3): <b>the
/// only product class that starts, stops, restarts, updates or recovers a production, enables, disables,
/// adds, copies, changes the class of or removes one of its items, aborts a queued message, a queue's messages or a job's retried message,
/// suspends that message or stops a job, adds, changes or removes a lookup table's entry, deletes, imports or exports a lookup
/// table, adds, changes or removes a business partner, sets the production that starts with the instance or a production's shutdown group, sends a test request to an item, runs a data transformation on a pasted message, or resends messages with or without an
/// edited body</b>, and the only one that reads the interoperability configuration for
/// a declared read (source kind <code>interop</code>); Story 20.4 adds the nine runtime reads (<parameter>ENDPOINTS</parameter>
/// from <code>Monitor</code> on), which write nothing. It calls the documented classes the classic pages call --
/// <code>Ens.Director</code>, <code>Ens.Queue</code>, <code>Ens.Job</code>, <code>Ens.Config.Production:ProductionStatus</code> and
/// <code>%Dictionary.ClassDefinition:SubclassOf</code> -- in the caller's process, as the signed-in
/// user. Nothing here issues an HTTP request, calls a <code>%Api.InteropEditors</code> class, calls
/// <code>Ens.Director.CleanProduction</code>, <code>Ens.Queue.AbortQueue</code> or <code>Ens.Job.Enumerate</code>, or writes a
/// vendor global.</p>
/// <p>The vendor's reads check no privilege (a principal holding only <code>%DB_USER:R</code> read the
/// status, the production list and the rule list, measured), so <method>Invoke</method>'s gate is the
/// whole gate for a read. <b>The order of every call is fixed</b>, and nothing reaches the vendor before
/// all of it has passed:</p>
/// <ol>
/// <li>The endpoint and type are one this port serves, else 501 <code>PORT.NOTIMPLEMENTED</code>.</li>
/// <li>The endpoint's pairs (<parameter>PRODUCTIONPAIRS</parameter> or <parameter>CODEPAIRS</parameter>)
/// and, for a write, <parameter>WRITEPAIRS</parameter> or the queue or job action's own pair
/// (<parameter>QUEUEWRITEPAIR</parameter>, <parameter>JOBWRITEPAIR</parameter>, <parameter>SUSPENDPAIR</parameter>),
/// through <method>OcuPilot.Screen.Gate.EvaluateRequired</method>; a refusal is 403 naming the failed pair.</li>
/// <li>The namespace: the query's <parameter>NAMESPACEKEY</parameter>, or the request's scope
/// (<method>OcuPilot.Kernel.Scope.Current</method>), its shape checked; a namespace that does not report
/// interoperability is 409 <parameter>OcuPilot.Api.InteropError.NAMESPACE</parameter>, refused before any
/// switch.</li>
/// <li>READ, or for a write WRITE, on the resource guarding the namespace's globals database, and for an
/// item write WRITE on the one guarding its routines database too; an unresolved resource is 400
/// <code>PORT.VALIDATION</code>.</li>
/// <li>For a write, the target's state, read first and judged by <method>Refusal</method>, <method>ItemRefusalToken</method>
/// or <method>RuntimeRefusal</method>: whatever the vendor would answer as a silent success is refused by its own code,
/// and nothing is called.</li>
/// <li>The vendor call, in the target namespace, switched by explicit save and restore (AD-16): the
/// restore is the first line of every <code>Catch</code>, and no <code>OcuPilot.*</code> class is called
/// while switched.</li>
/// </ol>
/// <p>The vendor performs start, stop, restart and update as its own service account after checking the
/// caller's run resource, as from the classic page (AD-8, AD-62): this port adds no elevation, and the
/// caller's <code>$USERNAME</code> and <code>$ROLES</code> read the same afterwards (measured). A write
/// finishes inside its own request (AD-7): start returns once its jobs are launched, and stop, restart
/// and update pass the production's own timeout capped at <parameter>STOPSECONDS</parameter>. A
/// production that does not quiesce in that time is refused by the vendor and left as it was. A job stop passes the same
/// capped timeout and forces.</p>
/// <p><b>The queue and job actions record OcuPilot's own audit row</b> (<method>AuditRuntime</method>, AD-15), because the
/// vendor records none for them.</p>
/// <p><b>Every refusal is a written reason</b> (AD-39): the vendor's text goes to
/// <method>LogFault</method> and nowhere else, and a read answered 404 is not logged (AD-2).</p>
/// <p><b>The lookup writes</b> (Story 20.5) take the vendor's own table lock (<method>LockTable</method>) as the classic page's save
/// takes it, refuse by name what the vendor would answer as a silent success, and record OcuPilot's own audit row
/// (<method>AuditRuntime</method>), because the vendor records none. The vendor's lookup and partner calls check no privilege
/// either (measured), so the gate is the whole gate.</p>
/// <p><b>The business partner writes</b> (Story 20.26, the <code>BusinessPartners</code> endpoint's <code>ADDPARTNER</code>,
/// <code>SETPARTNER</code> and <code>REMOVEPARTNER</code>, each over the port-composed <code>PARTNER</code> read) save and delete an
/// <code>Ens.Config.BusinessPartner</code> through the vendor class's own <code>%Save</code> and <code>%DeleteId</code>, which check
/// no privilege and audit nothing (measured), so the gate is the whole gate and the port records OcuPilot's own row
/// (<method>AuditRuntime</method>). A rename cannot be expressed: the name is the target, and an update's body carries the fields it
/// changes. Before any vendor call the port refuses a namespace under source control, an add of a name the namespace holds
/// in any letter case, a remove of a partner that any item of any production of the namespace names in its Host
/// <code>BusinessPartner</code> setting, and a field past the vendor's own length (<method>PartnerViolations</method>).</p>
/// <p><b>The startup settings</b> (Story 24.3, the Productions endpoint's <code>STARTUP</code> read and its <code>AUTOSTART</code> and
/// <code>SHUTDOWNGROUP</code> writes) set which production the namespace starts with the instance, at which startup priority, and the
/// shutdown group a production stops in, through <code>Ens.Director</code>'s <code>SetAutoStart</code> and its <code>[Internal]</code>
/// <code>SetProductionShutdownGroup</code>, as the classic Auto-Start Production and Production Shutdown Group pages call them. The
/// vendor records no audit row for either (measured), so the port records OcuPilot's own (<method>AuditRuntime</method>). Beyond the
/// gate it refuses before any vendor call: a value outside its shape (422), a value the production already holds, a priority for a
/// production that does not start with the instance, a priority or group change when the caller cannot read every interoperability
/// namespace's settings (<method>AllNamespacesReadable</method>, as the classic pages ask), and a namespace whose database is mounted
/// read-only (<method>DefaultReadOnly</method>). It never sets a vendor global itself.</p>
/// <p><b>The host test</b> (Story 20.6, the <code>ItemTest</code> endpoint) lists the request classes an item takes (the host class's
/// own <code>GetMessageList</code>, as the classic dialog reads it, then their subclasses from the class dictionary) and their
/// settable fields from the class dictionary, and sends one test request through <code>EnsLib.Testing.Service</code> as the
/// classic Testing Service dialog does, asynchronously. It refuses by name, before any vendor call, whatever the vendor would
/// answer as a silent success or write to the device about: the production not running, testing not enabled, a target that is
/// not an enabled process or operation, a request class the target does not take, and a value for a credential-named field.
/// Every vendor call that can write to the device runs inside the output capture, so the answer stays JSON, and what a test
/// answered reaches the screen and the proposal card only (AD-39's seventh exception). The vendor audits no test, so the port
/// records OcuPilot's own row (<method>AuditRuntime</method>).</p>
/// <p><b>The data transformation test</b> (Story 20.27, the <code>Transforms</code> endpoint's <code>TRANSFORM</code> and
/// <code>TRANSFORMTEST</code>) runs a listed <code>Ens.DataTransform</code> subclass once, in this process, on a pasted message. The
/// source and target classes are judged before any vendor call (<method>FormatKindHere</method>): a virtual document or an XML
/// class is admitted, a Record Map class and anything else is refused. The message is parsed with a virtual document's
/// <code>ImportFromString</code> or the XML reader, never the vendor's hidden serialized reader, and pasted XML is read only from its
/// first <code>&lt;</code> and with no document type, so no pasted text names a file the parser opens (AD-21); the vendor calls run
/// inside the output capture; the target is shown as text; and a source or target that gained an <code>%Id()</code> is deleted in the
/// same request. The output, error and console lines reach the screen and the proposal card only (AD-39's seventh exception).</p>
/// <p><b>The message reads</b> (Story 20.9, the <code>Messages</code>, <code>MessageHeader</code> and <code>MessageContents</code>
/// endpoints) search <code>Ens.MessageHeader</code> by time window and header criteria, read one header's twenty-three properties,
/// and show one message body as text. They read with <code>%ExecDirectNoPriv</code> after the gate, bind every value, and write
/// nothing but the vendor's own view audit row for a body that opened (<method>ReadMessageContents</method>).</p>
/// <p><b>The session trace</b> (Story 20.30, the <code>MessageTrace</code> endpoint) reads the whole session of one message header,
/// in <code>ID</code> order, capped, as <method>MessageRow</method> builds each header plus its <code>Step</code>
/// (<method>ListMessageTrace</method>). It reads no event, rule or I/O log entry and does not follow <code>SuperSession</code>.</p>
/// <p><b>The session reads</b> (Story 24.4, the <code>Sessions</code>, <code>SessionSummary</code> and <code>SessionMessages</code> endpoints) serve the
/// agent's session and message tools and no screen, under the message viewer's pairs. A windowed read is at most
/// <parameter>SESSIONHOURSMAX</parameter> hours, turned into ID bounds as <method>ListMessages</method> turns its window; a keyed read leads on
/// <code>SessionId</code> or on <code>Ens.SuperSessionIndex.SuperSession</code> and takes no window. Each reads with
/// <code>%ExecDirectNoPriv</code> after the gate, binds every value and writes nothing (<method>ListSessions</method>,
/// <method>ReadSessionSummary</method>, <method>ListSessionMessages</method>).</p>
/// <p><b>The resend writes</b> (Story 20.31, the <code>Messages</code> endpoint's <code>RESENDMESSAGES</code> and
/// <code>EDITRESEND</code>, each over its port-composed read, <code>RESEND</code> and <code>EDIT</code>) call
/// <code>Ens.MessageHeader.ResendDuplicatedMessage</code> in process, which checks no privilege and audits each new header itself, so
/// the gate is the whole gate and OcuPilot records no row of its own. Before any vendor call the port refuses a namespace whose
/// production is not running and judges each message (<method>MessageVerdict</method>); it resends exactly the messages whose verdict
/// is <code>resend</code>, at most <parameter>RESENDMAX</parameter> in one action, in ascending id order, and goes on past a vendor
/// refusal of one. An edit resends the original header with a saved clone of its body that carries the changed fields
/// (<method>EditCloneHere</method>); the original body is never changed.</p>
/// <p><b>The change of class</b> (Story 20.41, the <code>Items</code> endpoint's <code>CHANGECLASS</code>) is an item write over the
/// <code>ITEM</code> read composed from the chosen class (<parameter>NEWCLASSKEY</parameter>), which answers the settings the change
/// removes (<method>DroppedSettings</method>, the rule of the classic <code>HostChangeClass</code>) and a digest over them. The write
/// judges the class and the settings again under the production's lock and refuses a reviewed digest that moved
/// (<code>INTEROP.ITEM.REVIEWCHANGED</code>) before anything is written. The <code>ItemClasses</code> endpoint lists the classes an
/// item can change to (<method>CandidateClasses</method>).</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>LogFault</method>,
/// <method>StopSeconds</method>, <method>RoutineResource</method>, <method>SourceControlled</method>,
/// <method>VendorAbortItem</method>, <method>VendorJob</method>, <method>LockTable</method>, <method>VendorSendTest</method>,
/// <method>TestWait</method>, <method>AllNamespacesReadable</method>, <method>DefaultReadOnly</method>,
/// <method>VendorSetAutoStart</method>, <method>VendorSetShutdownGroup</method>, <method>VendorLogPurge</method> and <method>LogHere</method>, and the parameters <parameter>ABORTMAX</parameter>, <parameter>RULELOGMAX</parameter> and <parameter>PROCESSLOGMAX</parameter>. Production overrides none.</p>
Class OcuPilot.Port.InteropPort Extends %RegisteredObject
{

/// <p>The class the pair sets are evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The endpoints this port serves, comma-separated: the namespace's productions, business
/// processes, data transformations and business rules, and a production's items.
/// <file>ui/tools/screen-mirror.mjs</file> reads this list.</p>
Parameter ENDPOINTS = "Productions,Processes,Transforms,Rules,Items,Settings,Monitor,ItemStatus,Queues,QueueItems,ItemQueue,ItemLog,ItemMessages,Jobs,ItemJobs,LookupTables,LookupEntries,BusinessPartners,ItemTest,Messages,MessageHeader,MessageContents,MessageTrace,ItemClasses,Sessions,SessionSummary,SessionMessages,DefaultSettings,DefaultSettingsDiff,Credentials,Schedules,PurgeSettings,Purge,SuspendedMessages,ArchiveSettings,Archive,ArchiveErrors,ManagedAlerts,ManagedAlertActions,RuleLog,ProcessLog";

Parameter ENDPOINTPRODUCTIONS = "Productions";

Parameter ENDPOINTPROCESSES = "Processes";

Parameter ENDPOINTTRANSFORMS = "Transforms";

Parameter ENDPOINTRULES = "Rules";

/// <p>A production's items: <code>LIST</code> for the production the <parameter>PRODUCTIONKEY</parameter>
/// names, <code>ITEM</code> for one item and the four item writes (Story 20.3).</p>
Parameter ENDPOINTITEMS = "Items";

/// <p>An item's settings (Story 20.22): <code>LIST</code> for the item the <parameter>ITEMKEY</parameter> names,
/// <code>SETTING</code> for one setting and the two setting writes <code>SET</code> and <code>RESET</code>. A
/// setting is one of the item's own properties (<parameter>TARGETCORE</parameter>) or one the item's class
/// (<parameter>TARGETHOST</parameter>) or its adapter (<parameter>TARGETADAPTER</parameter>) declares.</p>
Parameter ENDPOINTSETTINGS = "Settings";

/// <p>The production monitor (Story 20.4): the hosts the namespace's running production configures, with the status the
/// vendor's host monitor keeps. <code>LIST</code> only, like every endpoint from here to <parameter>ENDPOINTITEMJOBS</parameter>;
/// none writes, and none calls a queue or job action.</p>
Parameter ENDPOINTMONITOR = "Monitor";

/// <p>One item's status (Story 20.4): its configuration facts and its host's monitor row. An item endpoint takes the
/// item under <parameter>ITEMKEY</parameter>.</p>
Parameter ENDPOINTITEMSTATUS = "ItemStatus";

/// <p>The namespace's queues and the entries of one of them, named under <parameter>QUEUEKEY</parameter>.</p>
Parameter ENDPOINTQUEUES = "Queues";

Parameter ENDPOINTQUEUEITEMS = "QueueItems";

/// <p>An item's queue, its event log rows and its message headers.</p>
Parameter ENDPOINTITEMQUEUE = "ItemQueue";

Parameter ENDPOINTITEMLOG = "ItemLog";

Parameter ENDPOINTITEMMESSAGES = "ItemMessages";

/// <p>The running production's jobs, and one item's.</p>
Parameter ENDPOINTJOBS = "Jobs";

Parameter ENDPOINTITEMJOBS = "ItemJobs";

/// <p>The namespace's lookup tables (Story 20.5): <code>LIST</code>, one table (<code>LOOKUPTABLE</code>) and the table
/// delete. A table is created by adding its first entry, and removing its last entry removes it.</p>
Parameter ENDPOINTLOOKUPTABLES = "LookupTables";

/// <p>The entries of the table <parameter>TABLEKEY</parameter> names (Story 20.5): <code>LIST</code>, one entry
/// (<code>LOOKUPENTRY</code>) and the three entry writes.</p>
Parameter ENDPOINTLOOKUPENTRIES = "LookupEntries";

/// <p>The namespace's business partners (Story 20.5): <code>LIST</code> only.</p>
Parameter ENDPOINTBUSINESSPARTNERS = "BusinessPartners";

/// <p>The namespace's system default settings (Story 24.15): <code>LIST</code>, one setting (<code>DEFAULTSETTING</code>) and the three
/// writes, over <code>Ens.Config.DefaultSettings</code>.</p>
Parameter ENDPOINTDEFAULTSETTINGS = "DefaultSettings";

/// <p>The system default settings that differ between the route's namespace and the one the <parameter>DIFFTARGETKEY</parameter>
/// criterion names (Story 24.15): <code>LIST</code> only, read in each namespace through the same read as
/// <parameter>ENDPOINTDEFAULTSETTINGS</parameter>' list.</p>
Parameter ENDPOINTDEFAULTSETTINGSDIFF = "DefaultSettingsDiff";

/// <p>The namespace's credentials (Story 24.15): <code>LIST</code>, one credential (<code>CREDENTIAL</code>) and the four writes, over
/// <code>Ens.Config.Credentials</code>. The password is never read: a row says only whether one is stored.</p>
Parameter ENDPOINTCREDENTIALS = "Credentials";

/// <p>The namespace's schedule specs (Story 24.15): <code>LIST</code>, one schedule spec (<code>SCHEDULE</code>) and the three writes, over
/// <code>Ens.Util.Schedule</code>. A spec is shown as text and never run.</p>
Parameter ENDPOINTSCHEDULES = "Schedules";

/// <p>An item's host test (Story 20.6): <code>LIST</code> for the item <parameter>ITEMKEY</parameter> names (one row for each
/// settable field of each request class it takes), <code>TESTTARGET</code> (the composed fresh read of the test about to be
/// sent) and the write <code>SENDTEST</code>.</p>
Parameter ENDPOINTITEMTEST = "ItemTest";

/// <p>The classes an item can change to (Story 20.41): <code>LIST</code> for the item <parameter>ITEMKEY</parameter> names, one row
/// for each compiled, non-abstract class of the item's kind (<method>CandidateClasses</method>). It takes the Productions
/// endpoint's pairs and the item write's, the classic Change Class dialog's resource.</p>
Parameter ENDPOINTITEMCLASSES = "ItemClasses";

/// <p>The namespace's message headers (Story 20.9): <code>LIST</code> searches them by time window, status, type, source, target,
/// body class, session and error flag, newest first. It is the one endpoint whose <code>LIST</code> takes search criteria of its
/// own, beside a parented list's route id (<parameter>SEARCHENDPOINTS</parameter>).</p>
Parameter ENDPOINTMESSAGES = "Messages";

/// <p>One message header's twenty-three properties (Story 20.9), as <code>{Message, Position, Name, Value}</code> rows, for the
/// header <parameter>MESSAGEKEY</parameter> names.</p>
Parameter ENDPOINTMESSAGEHEADER = "MessageHeader";

/// <p>One message's body as text lines (Story 20.9), <code>{Message, Line, Text}</code>, for the header
/// <parameter>MESSAGEKEY</parameter> names.</p>
Parameter ENDPOINTMESSAGECONTENTS = "MessageContents";

/// <p>One message's whole session (Story 20.30): the headers that share the session of the header <parameter>MESSAGEKEY</parameter>
/// names, in <code>ID</code> order, as the search's rows with <code>Message</code> and <code>Step</code> added.</p>
Parameter ENDPOINTMESSAGETRACE = "MessageTrace";

/// <p>The sessions a search finds (Story 24.4): one row per session, <code>LIST</code> only. The criteria are <code>kind</code> (what the
/// search leads on, one of <parameter>SESSIONKINDS</parameter>) and the criteria that kind takes (<method>ListSessions</method>).</p>
Parameter ENDPOINTSESSIONS = "Sessions";

/// <p>One session's summary row (Story 24.4), for the session the <code>session</code> criterion names.</p>
Parameter ENDPOINTSESSIONSUMMARY = "SessionSummary";

/// <p>One session's headers in <code>ID</code> order (Story 24.4), as <method>MessageRow</method> builds them with <code>Step</code> added.</p>
Parameter ENDPOINTSESSIONMESSAGES = "SessionMessages";

/// <p>The endpoints whose <code>LIST</code> declares search criteria of its own (Story 20.9). A declared read names criteria on
/// the interoperability port only as its parent's route id, except on these; <file>ui/tools/screen-mirror.mjs</file> reads this
/// list as it reads <parameter>ENDPOINTS</parameter>.</p>
Parameter SEARCHENDPOINTS = "Messages,DefaultSettingsDiff,ManagedAlerts,RuleLog,ProcessLog";

/// <p>The query key naming the message header a header or contents read is about: its one criterion, the header's id kept exactly
/// (AD-13).</p>
Parameter MESSAGEKEY = "message";

/// <p>The pairs the Productions endpoint requires: the classic Interoperability menu's
/// <code>%Ens_Portal:USE</code> and <code>EnsPortal.Productions</code>'s own resource (AD-8,
/// AD-29).</p>
Parameter PRODUCTIONPAIRS = "%Ens_Portal:USE,%Ens_ProductionConfig:READ";

/// <p>The pairs the three code lists require. The classic pages' resource is an OR list a pair set
/// cannot express; <code>%Ens_Code:READ</code> is held by every shipped role that reaches them
/// (AD-62's named limit).</p>
Parameter CODEPAIRS = "%Ens_Portal:USE,%Ens_Code:READ";

/// <p>The pairs the Monitor endpoint requires: the classic <code>EnsPortal.ProductionMonitor</code>'s resource
/// (Story 20.4).</p>
Parameter MONITORPAIRS = "%Ens_Portal:USE,%Ens_Dashboard:USE";

/// <p>The pairs the Queues and QueueItems endpoints require: <code>EnsPortal.Queues</code>' resource.</p>
Parameter QUEUEPAIRS = "%Ens_Portal:USE,%Ens_Queues:READ";

/// <p>The pairs the Jobs endpoint requires: <code>EnsPortal.Jobs</code>' resource.</p>
Parameter JOBPAIRS = "%Ens_Portal:USE,%Ens_Jobs:READ";

/// <p>The pairs the two lookup endpoints require: the classic Interoperability menu's <code>%Ens_Portal:USE</code> and
/// <code>EnsPortal.LookupSettings</code>' own resource (Story 20.5). The vendor's lookup calls check no privilege
/// (measured), so these are the whole gate for a read.</p>
Parameter LOOKUPPAIRS = "%Ens_Portal:USE,%Ens_LookupTables:READ";

/// <p>The pair a lookup write adds: the classic page's <code>EDITRESOURCE</code>.</p>
Parameter LOOKUPWRITEPAIR = "%Ens_LookupTables:WRITE";

/// <p>The pair a business partner write adds (Story 20.26): the resource the classic page reads with and every other
/// interoperability configuration write holds at WRITE. The classic page declares no edit resource, so it admits a holder of READ.</p>
Parameter PARTNERWRITEPAIR = "%Ens_ProductionConfig:WRITE";

/// <p>The pairs the DefaultSettings and DefaultSettingsDiff endpoints require (Story 24.15): the classic Interoperability menu's
/// <code>%Ens_Portal:USE</code> and <code>EnsPortal.DefaultSettings</code>' own resource. The vendor's calls check no privilege of their
/// own beyond the database (measured), so these are the whole gate for a read.</p>
Parameter DEFAULTSETTINGPAIRS = "%Ens_Portal:USE,%Ens_SystemDefaultConfig:READ";

/// <p>The pair a default setting write adds: the classic page's own edit resource.</p>
Parameter DEFAULTSETTINGWRITEPAIR = "%Ens_SystemDefaultConfig:WRITE";

/// <p>The resource whose holder, without the <code>%All</code> role, writes only the settings the classic page's
/// <code>canEditSettingName</code> admits (<method>DefaultSettingRestricted</method>), and the prefix of the resource each setting adds.</p>
Parameter DEFAULTSETTINGRESTRICTEDPAIR = "%Ens_RestrictedUI_SystemDefaultSettings:USE";

Parameter DEFAULTSETTINGRESOURCEPREFIX = "%Ens_SystemDefaultSettings_";

/// <p>The setting whose write also needs <parameter>ITEMRUNPAIR</parameter>, as the classic page asks.</p>
Parameter DEFAULTSETTINGENABLED = "Enabled";

/// <p>The pairs the Credentials endpoint requires (Story 24.15): the classic Interoperability menu's <code>%Ens_Portal:USE</code> and
/// <code>EnsPortal.Credentials</code>' own resource. The vendor's reads check no privilege of their own beyond the database (measured).</p>
Parameter CREDENTIALPAIRS = "%Ens_Portal:USE,%Ens_Credentials:READ";

/// <p>The pair a credential write adds: the classic page's own edit resource, which the vendor's password calls check themselves.</p>
Parameter CREDENTIALWRITEPAIR = "%Ens_Credentials:WRITE";

/// <p>The pairs the Schedules endpoint requires (Story 24.15): the classic Interoperability menu's <code>%Ens_Portal:USE</code> and
/// <code>EnsPortal.ScheduleEditor</code>'s own resource. The vendor's reads check no privilege of their own beyond the database
/// (measured).</p>
Parameter SCHEDULEPAIRS = "%Ens_Portal:USE,%Ens_ProductionConfig:READ";

/// <p>The pair a schedule spec write adds, the remove included: the classic page's own edit resource. The vendor's <code>%Save</code> and
/// <code>%DeleteId</code> need WRITE on the namespace's globals database and no other pair (measured).</p>
Parameter SCHEDULEWRITEPAIR = "%Ens_ProductionConfig:WRITE";

/// <p>The pairs the ItemTest endpoint requires: the classic Interoperability menu's <code>%Ens_Portal:USE</code> and
/// <code>EnsPortal.TestingService</code>'s own resource (Story 20.6). The vendor's <code>SendTestRequest</code> checks no
/// privilege (measured), so these, and WRITE on the namespace's globals database for a send, are the whole gate.</p>
Parameter TESTPAIRS = "%Ens_Portal:USE,%Ens_TestingService:USE";

/// <p>The endpoint and type pairs that send no body and take their arguments through the query (AD-51 as amended by Story 12.3): the
/// lookup table export and import (Story 20.5), whose files and reviewed counts the port reads from its query, and the host test's
/// send (Story 20.6), whose request class and field values it reads from its query, and the data transformation test (Story 20.27),
/// whose pasted message it reads from its query, and the edit-and-resend (Story 20.31), whose edited body it builds from the fields its
/// query carries, and the edit-and-resubmit of a suspended message (Story 24.16), which builds its edited body the same way.</p>
Parameter COMPOSEDTYPES = "LookupTables/EXPORT,LookupTables/IMPORT,ItemTest/SENDTEST,Transforms/TRANSFORMTEST,Messages/EDITRESEND,SuspendedMessages/EDITRESUBMIT";

/// <p>The pair each item tab adds to the Productions endpoint's pairs (the classic configuration page's
/// <code>initSecurity</code>): the queue, the event log, the message headers and the jobs.</p>
Parameter ITEMQUEUEPAIR = "%Ens_Queues:READ";

Parameter ITEMLOGPAIR = "%Ens_EventLog:USE";

Parameter ITEMMESSAGEPAIR = "%Ens_MessageHeader:USE";

Parameter ITEMJOBPAIR = "%Ens_Jobs:READ";

/// <p>The pairs the Messages and MessageHeader endpoints require: the classic Interoperability menu's <code>%Ens_Portal:USE</code>
/// and <code>EnsPortal.MessageViewer</code>'s own resource, <code>%Ens_MessageHeader:USE</code> (Story 20.9).</p>
Parameter MESSAGEPAIRS = "%Ens_Portal:USE,%Ens_MessageHeader:USE";

/// <p>The pair the MessageContents endpoint adds: the classic Contents pane's resource, which <code>EnsPortal.MessageContents</code>
/// checks in its own code (Story 20.9).</p>
Parameter MESSAGECONTENTPAIR = "%Ens_MessageContent:USE";

/// <p>The pair the MessageTrace endpoint adds: <code>EnsPortal.VisualTrace</code>'s <code>RESOURCE</code> (Story 20.30).</p>
Parameter MESSAGETRACEPAIR = "%Ens_MessageTrace:USE";

/// <p>The pair a write adds: the vendor's own run resource, the classic
/// <code>EnsPortal.ProductionConfig</code> check (measured: start, stop and restart answer #940
/// without it).</p>
Parameter WRITEPAIRS = "%Ens_ProductionRun:USE";

/// <p>The pair an item write adds to the Productions endpoint's pairs: the classic
/// <code>EnsPortal.ProductionConfig</code> editor's resource at WRITE. The vendor's item writes check no
/// privilege of their own (measured), so the declared pairs are the whole gate. An item write does not
/// need <code>%Ens_ProductionRun:USE</code>.</p>
Parameter ITEMWRITEPAIRS = "%Ens_ProductionConfig:WRITE";

/// <p>The pair an item runtime write (stop, start, restart) adds to the Items endpoint's pairs: the classic
/// <code>EnsPortal.ProductionConfig</code> page's own check for a temporary stop or start. The vendor's
/// <code>TempStopConfigItem</code> checks no privilege (measured), so the declared pairs are the whole gate. The
/// write needs neither <code>%Ens_ProductionRun:USE</code> nor <code>%Ens_ProductionConfig:WRITE</code>.</p>
Parameter ITEMRUNPAIR = "%Ens_ConfigItemRun:USE";

/// <p>The pair a queue abort (one message or all) adds to the Queues and QueueItems endpoints' pairs: the vendor's own
/// check in <code>Ens.Queue.AbortItem</code> (Story 20.23).</p>
Parameter QUEUEWRITEPAIR = "%Ens_Queues:WRITE";

/// <p>The pair a job's abort or stop adds to the Jobs endpoint's pairs: the vendor's own check in
/// <code>Ens.Job.AbortOperation</code> and <code>Ens.Job.Stop</code>.</p>
Parameter JOBWRITEPAIR = "%Ens_Jobs:WRITE";

/// <p>The pair a job's suspend adds to the Jobs endpoint's pairs: the vendor's own check in
/// <code>Ens.Job.SuspendOperation</code>.</p>
Parameter SUSPENDPAIR = "%Ens_MessageSuspend:USE";

/// <p>The permission a read requires on the namespace's globals database.</p>
Parameter READPERMISSION = "READ";

/// <p>The permission a write requires on it (recover raises <code>&lt;PROTECT&gt;</code> on
/// <code>^Ens.Suspended</code> without it, measured), and an item write on the namespace's routines
/// database as well (<code>&lt;PROTECT&gt;</code> on <code>^Ens.Config.ItemD</code> and
/// <code>^oddDEF</code> without it, measured).</p>
Parameter WRITEPERMISSION = "WRITE";

/// <p>The longest a stop, restart or update waits for the production's work in progress, in seconds;
/// <method>StopSeconds</method> caps the production's own timeout at it. The sentences that state it
/// (<class>OcuPilot.Api.InteropError</class>) hold the same number, pinned by
/// <file>ui/tools/interop.test.mjs</file>.</p>
Parameter STOPSECONDS = 15;

/// <p>The request types. <code>LIST</code> answers rows on every endpoint; the rest are the
/// Productions endpoint's.</p>
Parameter TYPELIST = "LIST";

/// <p>One production's state: <code>{Name, Namespace, State, Current, NeedsUpdate}</code>, the tools'
/// fresh read. With <parameter>ACTIONKEY</parameter> in the query it refuses what that action would be
/// refused (<method>Refusal</method>).</p>
Parameter TYPESTATE = "STATE";

Parameter TYPESTART = "START";

Parameter TYPESTOP = "STOP";

Parameter TYPERESTART = "RESTART";

Parameter TYPEUPDATE = "UPDATE";

Parameter TYPERECOVER = "RECOVER";

/// <p>One item: <code>{Production, Name, ClassName, Type, Enabled, EnabledSource, PoolSize, Category,
/// Comment, Namespace, Count}</code>, the item tools' fresh read. The id is the composite
/// <code>[Production, Name]</code>. With <parameter>ACTIONKEY</parameter> in the query it refuses what that
/// action would be refused (<method>ItemRefusal</method>).</p>
Parameter TYPEITEM = "ITEM";

Parameter TYPEENABLE = "ENABLE";

Parameter TYPEDISABLE = "DISABLE";

Parameter TYPEADD = "ADD";

Parameter TYPEREMOVE = "REMOVE";

/// <p>An item copy (Story 20.40): a create over the new name's absence, whose payload names the source item
/// (<code>CopyFrom</code>) in the same production. It extends the add's path: the new item is the source's clone, stored
/// disabled.</p>
Parameter TYPECOPY = "COPY";

/// <p>An item change of class (Story 20.41): an action-style write over the port-composed <code>ITEM</code> read, whose composed read
/// names the chosen class under <parameter>NEWCLASSKEY</parameter> and answers the settings the change would drop.</p>
Parameter TYPECHANGECLASS = "CHANGECLASS";

/// <p>One item's runtime (Story 20.25): <code>{Production, Name, ClassName, Enabled, EnabledSource, Count, State, Current,
/// TemporarilyStopped, OwnJobs, Jobs, NeedsUpdate, Namespace}</code>, the fresh read of the item runtime tools. The id is the
/// composite <code>[Production, Name]</code>. With <parameter>ACTIONKEY</parameter> in the query it refuses what that action
/// would be refused (<method>ItemRunRefusal</method>). The three writes below are not named <code>STOP</code>, <code>START</code>
/// or <code>RESTART</code>, which add the production run resource (<method>IsWrite</method>).</p>
Parameter TYPEITEMRUN = "ITEMRUN";

/// <p>Stop one item's jobs until it is started again or its production next restarts.</p>
Parameter TYPESTOPITEM = "STOPITEM";

/// <p>Start the jobs of an item stopped with <parameter>TYPESTOPITEM</parameter>.</p>
Parameter TYPESTARTITEM = "STARTITEM";

/// <p>Stop one item's jobs and start them again.</p>
Parameter TYPERESTARTITEM = "RESTARTITEM";

/// <p>One setting: <code>{Production, Item, Target, Name, Value, Source, Default, DefaultSource, Type, Category,
/// Location, Secret, Namespace, Count}</code>, the setting tools' fresh read. The id is the composite
/// <code>[Production, Item, Target, Name]</code>. With <parameter>ACTIONKEY</parameter> in the query it refuses
/// what that action would be refused (<method>SettingRefusalToken</method>).</p>
Parameter TYPESETTING = "SETTING";

/// <p>Store a value for a setting. The body names it in <code>Value</code>.</p>
Parameter TYPESET = "SET";

/// <p>Remove the production's own value of a Host or Adapter setting, so its default applies again.</p>
Parameter TYPERESET = "RESET";

/// <p>One queue (Story 20.23): <code>{Name, Count, Active, Created, Entries, Digest, Namespace}</code>, the queue abort's
/// fresh read. <code>Entries</code> is how many entries the read enumerated, at most <parameter>ABORTMAX</parameter>, and
/// <code>Digest</code> stands for them (<method>QueueDigest</method>). The id is the queue's name. With
/// <parameter>ACTIONKEY</parameter> in the query it refuses what that action would be refused
/// (<method>RuntimeRefusal</method>).</p>
Parameter TYPEQUEUE = "QUEUE";

/// <p>One queue entry (Story 20.23): <code>{Queue, Priority, Index, MessageId, Source, Target, BodyClass, TimeCreated,
/// Status, Namespace}</code>, found through the message header's own <code>TargetQueueName</code>, so a message to a business
/// process of pool size 0 is found in <parameter>ACTORQUEUE</parameter>. The id is the header's id.</p>
Parameter TYPEENTRY = "ENTRY";

/// <p>One job of the running production (Story 20.23): <method>JobRow</method>'s fields with <code>Production</code>, <code>Item</code> and
/// <code>Namespace</code>. The id is the job's process id. With <parameter>ACTIONKEY</parameter> in the query it refuses what that
/// action would be refused (<method>RuntimeRefusal</method>).</p>
Parameter TYPEJOB = "JOB";

/// <p>Abort the entries of a queue its read enumerated, one <code>Ens.Queue.AbortItem</code> each. <code>Ens.Queue.AbortQueue</code> is
/// never called: it also aborts what arrived after the review.</p>
Parameter TYPEABORTQUEUE = "ABORTQUEUE";

/// <p>Abort one waiting message.</p>
Parameter TYPEABORTMESSAGE = "ABORTMESSAGE";

/// <p>Abort the message a job is retrying, when its current retry wait ends.</p>
Parameter TYPEABORTJOB = "ABORTJOB";

/// <p>Suspend the message a job is retrying, when its current retry wait ends.</p>
Parameter TYPESUSPENDJOB = "SUSPENDJOB";

/// <p>Stop one job of the running production, forcing it if it does not stop within the wait.</p>
Parameter TYPESTOPJOB = "STOPJOB";

/// <p>One lookup table (Story 20.5): <code>{Name, Entries, Modified, Namespace}</code>, the table delete's fresh read. The id
/// is the table's name. With <parameter>ACTIONKEY</parameter> in the query it refuses what that action would be refused
/// (<method>ReadLookupTable</method>).</p>
Parameter TYPELOOKUPTABLE = "LOOKUPTABLE";

/// <p>One lookup entry (Story 20.5): <code>{Table, Key, Value, Secret, Namespace}</code>, the entry tools' fresh read. The id is
/// the composite <code>[Table, Key]</code>. It carries no count, so another entry's change never moves a fingerprint.</p>
Parameter TYPELOOKUPENTRY = "LOOKUPENTRY";

/// <p>Add an entry, creating its table when it is absent. The body names the value in <code>Value</code>.</p>
Parameter TYPEADDENTRY = "ADDENTRY";

/// <p>Store a new value for an entry the table holds.</p>
Parameter TYPESETENTRY = "SETENTRY";

/// <p>Remove an entry; removing a table's last entry removes the table (measured).</p>
Parameter TYPEREMOVEENTRY = "REMOVEENTRY";

/// <p>Remove a table and every entry in it.</p>
Parameter TYPEDELETETABLE = "DELETETABLE";

/// <p>One business partner (Story 20.26): <code>{Name, Description, ...the twelve contact fields, NamedBy, Namespace}</code>, the
/// partner tools' fresh read. The id is the partner's name. With <parameter>ACTIONKEY</parameter> in the query it refuses what that
/// action would be refused (<method>ReadPartner</method>).</p>
Parameter TYPEPARTNER = "PARTNER";

/// <p>Add a partner, with its description and both contacts. The body names the thirteen fields; the name is the id.</p>
Parameter TYPEADDPARTNER = "ADDPARTNER";

/// <p>Store new values for the fields of a partner the namespace holds. The name cannot change.</p>
Parameter TYPESETPARTNER = "SETPARTNER";

/// <p>Remove a partner, with its description and both contacts.</p>
Parameter TYPEREMOVEPARTNER = "REMOVEPARTNER";

/// <p>One system default setting (Story 24.15): <code>{Production, Item, HostClass, Setting, Value, Description, Deployable, Secret,
/// Namespace}</code>, the default setting tools' fresh read. The id is the composite <code>[Production, Item, HostClass, Setting]</code>,
/// each part kept exactly. With <parameter>ACTIONKEY</parameter> in the query it refuses what that action would be refused
/// (<method>ReadDefaultSetting</method>).</p>
Parameter TYPEDEFAULTSETTING = "DEFAULTSETTING";

/// <p>Add a default setting. The body names <code>Value</code>, <code>Description</code> and <code>Deployable</code>; the key is the id.</p>
Parameter TYPEADDDEFAULT = "ADDDEFAULT";

/// <p>Store new values for the fields of a default setting the namespace holds. The key cannot change.</p>
Parameter TYPESETDEFAULT = "SETDEFAULT";

/// <p>Remove a default setting.</p>
Parameter TYPEREMOVEDEFAULT = "REMOVEDEFAULT";

/// <p>One credential (Story 24.15): <code>{Name, Username, BusinessPartner, Password, Namespace}</code>, the credential tools' fresh read;
/// <code>Password</code> is <code>stored</code> or <code>not stored</code>. The id is the credential's name, kept exactly. With
/// <parameter>ACTIONKEY</parameter> in the query it refuses what that action would be refused (<method>ReadCredential</method>).</p>
Parameter TYPECREDENTIAL = "CREDENTIAL";

/// <p>Add a credential. The body names <code>Username</code>, <code>BusinessPartner</code> and, optionally, <code>Password</code>; the name is the id.</p>
Parameter TYPEADDCREDENTIAL = "ADDCREDENTIAL";

/// <p>Store a new user name or business partner for a credential the namespace holds. The name cannot change.</p>
Parameter TYPESETCREDENTIAL = "SETCREDENTIAL";

/// <p>Store a new password for a credential the namespace holds. The body is the password alone.</p>
Parameter TYPEPASSWORDCREDENTIAL = "PASSWORDCREDENTIAL";

/// <p>Remove a credential, and its password with it.</p>
Parameter TYPEREMOVECREDENTIAL = "REMOVECREDENTIAL";

/// <p>One schedule spec (Story 24.15): <code>{Name, Description, ScheduleSpec, Deployable, Namespace}</code>, the schedule tools' fresh read. The
/// id is the schedule spec's name, kept exactly. With <parameter>ACTIONKEY</parameter> in the query it refuses what that action would be refused
/// (<method>ReadSchedule</method>).</p>
Parameter TYPESCHEDULE = "SCHEDULE";

/// <p>Add a schedule spec. The body names <code>ScheduleSpec</code> and, optionally, <code>Description</code> and <code>Deployable</code>; the name
/// is the id.</p>
Parameter TYPEADDSCHEDULE = "ADDSCHEDULE";

/// <p>Store a new spec, description or deployable flag for a schedule spec the namespace holds. The name cannot change.</p>
Parameter TYPESETSCHEDULE = "SETSCHEDULE";

/// <p>Remove a schedule spec.</p>
Parameter TYPEREMOVESCHEDULE = "REMOVESCHEDULE";

/// <p>The query key naming the table an entries list reads: its one criterion.</p>
Parameter TABLEKEY = "table";

/// <p>One lookup table read for an import (Story 20.5): <code>{Table, FileEntries, Digest, Present, Entries, Modified, Namespace,
/// root, path, fileName}</code>, composed from the values the query carries -- the file's text, from a server file
/// (<parameter>ROOTKEY</parameter> and <parameter>PATHKEY</parameter>) or a local one (<parameter>FILENAMEKEY</parameter> and
/// <parameter>CONTENTKEY</parameter>) -- and the table the file names, as it stands (<code>Present</code>, <code>Entries</code> and
/// <code>Modified</code>). The id is the table the file must hold, or <parameter>IMPORTID</parameter> for the table the file names.</p>
Parameter TYPEIMPORTTABLE = "IMPORTTABLE";

/// <p>Replace, or create, the one table a file holds with the file's entries; keys the file lacks are removed. The write names the
/// reviewed <parameter>DIGESTKEY</parameter>, <parameter>ENTRIESKEY</parameter> and <parameter>MODIFIEDKEY</parameter>.</p>
Parameter TYPEIMPORT = "IMPORT";

/// <p>Export a table's <code>.LUT</code> document, to a server file named by <parameter>ROOTKEY</parameter> and
/// <parameter>PATHKEY</parameter> or, with neither, as lines for the browser.</p>
Parameter TYPEEXPORT = "EXPORT";

/// <p>One item's test, composed (Story 20.6): <code>{Namespace, Production, Name, Type, Enabled, State, Testing, RequestClass, Kind,
/// Fields, RequestValid}</code>, the host test tool's fresh read. <code>Testing</code> is whether the running production has
/// registered the testing service, <code>Kind</code> is <code>object</code> or <code>document</code> for a request class the
/// item takes, and <code>Fields</code> is the supplied values as canonical JSON text. The id is the item's composite
/// <code>[Production, Name]</code>. With <parameter>ACTIONKEY</parameter> in the query it refuses what the send would be refused
/// (<method>ReadTestTarget</method>).</p>
Parameter TYPETESTTARGET = "TESTTARGET";

/// <p>Send one test request to the item, asynchronously, and answer what it answered within <method>TestWait</method> seconds.</p>
Parameter TYPESENDTEST = "SENDTEST";

/// <p>One data transformation, composed (Story 20.27): <code>{Namespace, Name, SourceClass, SourceDocType, SourceKind, TargetClass,
/// TargetDocType, TargetKind, Create, content}</code>, the transformation test tool's fresh read. A kind is <code>document</code>,
/// <code>xml</code>, <code>recordmap</code> or <code>other</code>, and <code>content</code> is the pasted message the query carries. The
/// id is the transformation's document name (<code>&lt;class&gt;.cls</code>). With <parameter>ACTIONKEY</parameter> in the query it
/// refuses what the test would be refused (<method>ReadTransform</method>).</p>
Parameter TYPETRANSFORM = "TRANSFORM";

/// <p>Run the transformation once on the pasted message and answer the target as text.</p>
Parameter TYPETRANSFORMTEST = "TRANSFORMTEST";

/// <p>The pair the transformation read and test add to the Transforms endpoint's pairs: the classic Test Transform dialog's resource
/// (Story 20.27). The vendor's <code>Transform</code> checks no privilege, so this, the endpoint's pairs and WRITE on the
/// namespace's globals database are the whole gate.</p>
Parameter DTLTESTPAIR = "%Ens_DTLTest:USE";

/// <p>The pair a resend adds to the Messages endpoint's pairs, and the pair an edit-and-resend adds after it: the classic
/// <code>EnsPortal.MessageResend</code> and <code>EnsPortal.MessageResendEdit</code> resources (Story 20.31). The vendor's
/// <code>ResendDuplicatedMessage</code> checks no privilege, so these, the endpoint's pairs and WRITE on the namespace's globals
/// database are the whole gate.</p>
Parameter RESENDPAIR = "%Ens_MessageResend:USE";

Parameter EDITRESENDPAIR = "%Ens_MessageEditResend:USE";

/// <p>The Messages endpoint's four resend types (Story 20.31): <code>RESEND</code> and <code>EDIT</code> are the composed fresh
/// reads, <code>RESENDMESSAGES</code> and <code>EDITRESEND</code> the writes.</p>
/// <p><code>RESEND</code> answers <code>{Namespace, Production, Messages: [{ID, Type, Source, Target, Verdict}], Verdicts, Eligible,
/// Reviewed, Digest}</code> for the canonical set the id names. <code>EDIT</code> answers <code>{Namespace, Production, Message,
/// Type, Source, Target, BodyClass, Kind, Verdict, Form, Fields, Changed, Before, After, Original, Reviewed, Digest}</code> for one
/// message and the fields <parameter>FIELDSKEY</parameter> supplies. <code>RESENDMESSAGES</code> answers <code>{Namespace, Resent,
/// Failed, Messages: [{ID, NewId}|{ID, Error}]}</code> and <code>EDITRESEND</code> <code>{Namespace, Message, NewId, BodyClass,
/// BodyId}</code>.</p>
Parameter TYPERESEND = "RESEND";

Parameter TYPERESENDMESSAGES = "RESENDMESSAGES";

Parameter TYPEEDIT = "EDIT";

Parameter TYPEEDITRESEND = "EDITRESEND";

/// <p>The most messages one resend names, and so the most it sends (Story 20.31). A set over it is refused whole, never cut. The
/// sentence that states it is <file>ui/src/app/core/strings.ts</file>'s, and the descriptor's <code>multiSelect.max</code> equals it.</p>
Parameter RESENDMAX = 100;

/// <p>The message export (Story 24.16 Batch 3), on the Messages endpoint: <code>EXPORT</code> is the composed fresh read (the review, one verdict for each id, and
/// the two lists), <code>EXPORTMESSAGES</code> the write and <code>EXPORTCHOICES</code> the lists alone. The export writes no database, so its pairs carry READ on the
/// globals database and the classic export dialog's resource and the Contents pane's, which the export is never a way round.</p>
/// <p><code>EXPORT</code> answers what <code>RESEND</code> does, with <code>Production</code> <code>""</code>, and <code>{Separator, Charset, Separators: [], Charsets: []}</code>.
/// <code>EXPORTMESSAGES</code> answers <code>{Namespace, Exported, Failed, Messages: [{ID}|{ID, Error}], File}</code>, <code>File</code> the bytes of the export base64-encoded
/// and empty when nothing was exported. <code>EXPORTCHOICES</code> answers <code>{Separators: [], Charsets: [], DefaultSeparator, DefaultCharset}</code>.</p>
Parameter EXPORTPAIR = "%Ens_MessageExport:USE";

Parameter TYPEEXPORTMESSAGES = "EXPORTMESSAGES";

Parameter TYPEEXPORTCHOICES = "EXPORTCHOICES";

/// <p>The query keys carrying the separator and the character set an export is made with.</p>
Parameter SEPARATORKEY = "separator";

Parameter CHARSETKEY = "charset";

/// <p>The classic export dialog's message separators, in its order, and the default of each choice. The character sets are the instance's own
/// (<method>ExportCharsets</method>).</p>
Parameter EXPORTSEPARATORS = "CRLF,CR,LF,MLLP,Tab,None";

Parameter DEFAULTSEPARATOR = "CRLF";

Parameter DEFAULTCHARSET = "UTF8";

/// <p>The most bytes an export's file holds; the most messages it names is <parameter>RESENDMAX</parameter>. The bytes travel base64-encoded in one JSON string of at most
/// <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter> characters, so the file holds at most three quarters of that, 2,250,000 bytes (a test holds the
/// two equal); an export over it is refused whole, never cut.</p>
Parameter EXPORTMAXBYTES = 2250000;

/// <p>The most characters an export converts to its character set in one piece: at nine bytes a character, the widest any listed character set writes, a piece stays under
/// the longest string the instance holds.</p>
Parameter EXPORTCHUNK = 300000;

/// <p>The text an edited HL7 message's <code>Source</code> ends with, followed by the original body's id, as the classic Edit and
/// Resend page writes it, and the lower-case prefix of the body class names OcuPilot never edits.</p>
Parameter EDITEDCOPY = "; Edited copy of ";

Parameter OWNCLASSPREFIX = "ocupilot";

/// <p>The longest vendor error text a message that was not resent carries.</p>
Parameter ERRORTEXTMAX = 1000;

/// <p>The classes the test judges a transformation's source and target by (<method>FormatKindHere</method>): the Record Map records and
/// batches it refuses, EDI XML, segmented documents and the XML adaptor.</p>
Parameter RECORDMAPBASES = "EnsLib.RecordMap.Base,EnsLib.RecordMap.Batch,EnsLib.RecordMap.ComplexBase,EnsLib.RecordMap.ComplexParent";

Parameter XMLDOCUMENT = "EnsLib.EDI.XML.Document";

Parameter SEGMENTEDDOCUMENT = "EnsLib.EDI.Segmented";

Parameter XMLADAPTOR = "%XML.Adaptor";

/// <p>The class a transformation is listed under and the one listing excludes (<method>ListClasses</method>), and the extension its
/// document name ends with.</p>
Parameter TRANSFORMBASE = "Ens.DataTransform";

Parameter TRANSFORMDTL = "Ens.DataTransformDTL";

Parameter CLASSEXTENSION = ".cls";

/// <p>The query keys carrying the request class a test is sent as and its field values, as JSON object text.</p>
Parameter REQUESTCLASSKEY = "requestClass";

Parameter FIELDSKEY = "fields";

/// <p>The most seconds a test waits for the target's answer before it answers <code>waiting</code>, and the pause between two reads
/// of the test's answer node (Story 20.6). The cap is AD-62 item 6's.</p>
Parameter TESTWAIT = 15;

Parameter TESTPOLL = 0.25;

/// <p>The most properties examined at each level of a request class, and the most fields one class lists: the classic form's own
/// bound (<code>%CSP.Util.AutoFormGenerator.MAXPROPERTIES</code>).</p>
Parameter TESTFIELDMAX = 100;

/// <p>The most fields a test request names, so a request cannot outgrow the class it is for.</p>
Parameter TESTINPUTMAX = 200;

/// <p>The most characters one response field shows, and the most all the lines of a result hold.</p>
Parameter TESTVALUEMAX = 1000;

Parameter TESTOUTPUTMAX = 1000000;

/// <p>The text a cut value or a cut result ends with.</p>
Parameter TESTCUT = " ... [cut]";

/// <p>The testing service, the class a request class must descend from to be a virtual document, and the one member a document
/// request is made of.</p>
Parameter TESTSERVICE = "EnsLib.Testing.Service";

Parameter DOCUMENTBASE = "EnsLib.EDI.Document";

Parameter DOCUMENTFIELD = "content";

/// <p>What every test refusal code begins with (<class>OcuPilot.Api.InteropError</class>).</p>
Parameter TESTCODEPREFIX = "INTEROP.TEST.";

/// <p>The entity type and verb the audit row of a test names (<method>AuditRuntime</method>, Story 20.6).</p>
Parameter ENTITYITEM = "production-item";

/// <p>The entity type the audit row of a data transformation test names (Story 20.27).</p>
Parameter ENTITYCLASS = "class";

Parameter VERBTEST = "test";

/// <p>The vendor's status codes the test maps to its own words.</p>
Parameter CODENOTREGISTERED = "<Ens>ErrBusinessDispatchNameNotRegistered";

Parameter CODEPRODUCTIONNOTRUNNING = "<Ens>ErrProductionNotRunning";

Parameter CODEPRODUCTIONQUIESCENT = "<Ens>ErrProductionQuiescent";

/// <p>The query keys carrying a server file (an allowed directory and a relative name under it, AD-21's sixth case) and a local
/// file (its name, which names no directory, and its text).</p>
Parameter ROOTKEY = "root";

Parameter PATHKEY = "path";

Parameter FILENAMEKEY = "fileName";

Parameter CONTENTKEY = "content";

/// <p>The query keys carrying the reviewed entry count and stamp an import's write compares (<parameter>DIGESTKEY</parameter>
/// carries the reviewed digest).</p>
Parameter ENTRIESKEY = "entries";

Parameter MODIFIEDKEY = "modified";

/// <p>The id an import takes for the table its file names.</p>
Parameter IMPORTID = "import";

/// <p>Whether an export replaces a file already at its name: declared by the export itself, never a caller value (AD-21).</p>
Parameter EXPORTOVERWRITES As BOOLEAN = 1;

/// <p>The extension of a lookup table's document.</p>
Parameter LUTEXTENSION = ".LUT";

/// <p>The most characters the vendor stores for a table name, an entry key and an entry value (measured: a 256-character key
/// and a 32,001-character value are refused #7201). A table and a key each within its bound can still be too long together
/// (<method>LookupFits</method>).</p>
Parameter TABLEMAX = 255;

Parameter KEYMAX = 255;

Parameter VALUEMAX = 32000;

/// <p>How long a lookup write waits for the vendor's own table lock, in seconds: the classic page's save waits as long.</p>
Parameter LOCKSECONDS = 3;

/// <p>What every lookup refusal code begins with (<class>OcuPilot.Api.InteropError</class>).</p>
Parameter LOOKUPCODEPREFIX = "INTEROP.LOOKUP.";

/// <p>The characters <code>$System.OBJ</code> reads in a document name as a pattern (<code>*</code>, <code>?</code>), a path
/// (<code>/</code>, <code>\</code>) or a separator (<code>;</code>), so the export of a table whose name holds one cannot name its
/// own <code>.LUT</code> document (<method>LookupAddressable</method>).</p>
Parameter UNADDRESSABLE = "*?/\;";

/// <p>What every business partner refusal code begins with (<class>OcuPilot.Api.InteropError</class>).</p>
Parameter PARTNERCODEPREFIX = "INTEROP.PARTNER.";

/// <p>The partner fields in the order a row carries them (Story 20.26): the name, the description, then the primary and the
/// alternative contact's name, title, email, phone, mobile and notes. <parameter>PARTNERSETFIELDS</parameter> is the thirteen a
/// write may set.</p>
Parameter PARTNERFIELDS = "Name,Description,PrimaryContact,PrimaryTitle,PrimaryEmail,PrimaryPhone,PrimaryMobile,PrimaryNotes,AlternativeContact,AlternativeTitle,AlternativeEmail,AlternativePhone,AlternativeMobile,AlternativeNotes";

Parameter PARTNERSETFIELDS = "Description,PrimaryContact,PrimaryTitle,PrimaryEmail,PrimaryPhone,PrimaryMobile,PrimaryNotes,AlternativeContact,AlternativeTitle,AlternativeEmail,AlternativePhone,AlternativeMobile,AlternativeNotes";

/// <p>The most characters the vendor stores for a partner's name and for the name, title and email of a contact (measured: one more
/// is refused #7201 and nothing is stored). A description, a contact's phone and mobile number and a contact's notes keep fewer or
/// more (<method>PartnerLimit</method>).</p>
Parameter PARTNERNAMEMAX = 255;

/// <p>The entity type the audit row of a partner write names.</p>
Parameter ENTITYPARTNER = "business-partner";

/// <p>What every system default setting refusal code begins with (<class>OcuPilot.Api.InteropError</class>).</p>
Parameter DEFAULTSETTINGCODEPREFIX = "INTEROP.DEFAULTSETTING.";

/// <p>The default setting fields in the order a row carries them (Story 24.15); <parameter>DEFAULTSETTINGSETFIELDS</parameter> is the
/// three a write may set.</p>
Parameter DEFAULTSETTINGFIELDS = "Production,Item,HostClass,Setting,Value,Description,Deployable";

Parameter DEFAULTSETTINGSETFIELDS = "Value,Description,Deployable";

/// <p>The most characters the vendor stores for each part of a default setting's key (measured: <code>MAXLEN</code> 255), and for a
/// value and a description (2,000).</p>
Parameter DEFAULTSETTINGKEYMAX = 255;

Parameter DEFAULTSETTINGTEXTMAX = 2000;

/// <p>The most default settings one namespace may hold for a comparison to cover it: past it
/// <code>INTEROP.DEFAULTSETTING.TOOMANY</code> names the namespace.</p>
Parameter DEFAULTSETTINGSIDEMAX = 5000;

/// <p>The query key naming the other namespace a comparison reads: its one criterion.</p>
Parameter DIFFTARGETKEY = "target";

/// <p>The words a comparison row's <code>Change</code> takes.</p>
Parameter DIFFONLYHERE = "only here";

Parameter DIFFONLYTHERE = "only there";

Parameter DIFFDIFFERS = "differs";

/// <p>What every credential refusal code begins with (<class>OcuPilot.Api.InteropError</class>).</p>
Parameter CREDENTIALCODEPREFIX = "INTEROP.CREDENTIAL.";

/// <p>The fields a credential row carries, in order, and the two an edit may set (Story 24.15).</p>
Parameter CREDENTIALFIELDS = "Name,Username,BusinessPartner,Password";

Parameter CREDENTIALSETFIELDS = "Username,BusinessPartner";

/// <p>The most characters the vendor stores for a credential's name (measured: the default string length, 50).</p>
Parameter CREDENTIALNAMEMAX = 50;

/// <p>The most characters the vendor stores for a user name.</p>
Parameter CREDENTIALUSERMAX = 3640873;

/// <p>The words a row's <code>Password</code> takes.</p>
Parameter CREDENTIALSTORED = "stored";

Parameter CREDENTIALNOTSTORED = "not stored";

/// <p>The entity type the audit row of a credential write names.</p>
Parameter ENTITYCREDENTIAL = "interop-credential";

/// <p>What every schedule spec refusal code begins with (<class>OcuPilot.Api.InteropError</class>).</p>
Parameter SCHEDULECODEPREFIX = "INTEROP.SCHEDULE.";

/// <p>The fields a schedule spec row carries, in order (Story 24.15).</p>
Parameter SCHEDULEFIELDS = "Name,Description,ScheduleSpec,Deployable";

/// <p>The most characters the vendor stores for a schedule spec's name (measured: the default string length, 50) and for its description
/// (measured: 256).</p>
Parameter SCHEDULENAMEMAX = 50;

Parameter SCHEDULEDESCRIPTIONMAX = 256;

/// <p>The entity type the audit row of a schedule spec write names.</p>
Parameter ENTITYSCHEDULE = "interop-schedule";

/// <p>The vendor's judge of a schedule spec, which the port calls (Story 24.15): <code>Ens.ScheduleHandler:ValidateScheduleSpec</code>, a class
/// method marked <code>Internal</code> with the formal spec and return type below, which a test reads from the instance. <code>ParseScheduleSpec</code>
/// is never called, because it logs a bad spec and answers OK.</p>
Parameter SCHEDULEVALIDATOR = "ValidateScheduleSpec";

Parameter SCHEDULEVALIDATORFORMAL = "&pScheduleSpec,&pScheduleErrors,*pLength";

Parameter SCHEDULEVALIDATORRETURN = "%Library.Status";

/// <p>The entity types and verbs the audit row of a lookup write names (<method>AuditRuntime</method>, Story 20.5).</p>
Parameter ENTITYLOOKUPTABLE = "lookup-table";

Parameter ENTITYLOOKUPENTRY = "lookup-entry";

Parameter VERBADD = "add";

Parameter VERBSET = "set";

Parameter VERBREMOVE = "remove";

Parameter VERBDELETE = "delete";

Parameter VERBIMPORT = "import";

Parameter VERBEXPORT = "export";

/// <p>The Productions endpoint's startup types (Story 24.3): <code>STARTUP</code>, one production's startup settings
/// <code>{Name, Namespace, AutoStart, StartupPriority, ShutdownGroup, AutoStartOther}</code> (<code>AutoStart</code> is <code>1</code>
/// or <code>0</code>; <code>AutoStartOther</code> names the namespace's other auto-start production or is empty), and the two writes
/// over it. With <parameter>ACTIONKEY</parameter> and the values the write would carry in the query, the read refuses what the write
/// would be refused (<method>StartupRefusal</method>).</p>
Parameter TYPESTARTUP = "STARTUP";

Parameter TYPEAUTOSTART = "AUTOSTART";

Parameter TYPESHUTDOWNGROUP = "SHUTDOWNGROUP";

/// <p>The pair an auto-start write adds: the classic Auto-Start Production page's <code>EDITRESOURCE</code>.</p>
Parameter AUTOSTARTPAIR = "%Ens_ProductionConfig:WRITE";

/// <p>The pair a shutdown-group write adds: the classic Production Shutdown Group page's <code>EDITRESOURCE</code>.</p>
Parameter GROUPPAIR = "%Admin_Manage:USE";

/// <p>The query keys carrying the values a <code>STARTUP</code> read is composed from.</p>
Parameter AUTOSTARTKEY = "autoStart";

Parameter PRIORITYKEY = "priority";

Parameter GROUPKEY = "group";

/// <p>The shape of a startup priority and a shutdown group: an optional minus sign and one to nine digits.</p>
Parameter STARTUPNUMBER = "^-?[0-9]{1,9}$";

/// <p>The class an HL7 v2 message body is told apart by (Story 24.3).</p>
Parameter HL7MESSAGE = "EnsLib.HL7.Message";

/// <p>The entity type and the tool names the audit row of a startup write names.</p>
Parameter ENTITYPRODUCTION = "production";

Parameter TOOLAUTOSTART = "interop.productions.autostart";

Parameter TOOLSHUTDOWNGROUP = "interop.productions.shutdowngroup";

/// <p>The query key naming the item a <code>Settings</code> list reads: its one criterion. Its value is the item's
/// composite id <code>[Production, Name]</code> or the vendor's config name <code>Production||Name</code>.</p>
Parameter ITEMKEY = "item";

/// <p>The query key naming the queue a <code>QueueItems</code> list reads: its one criterion (Story 20.4).</p>
Parameter QUEUEKEY = "queue";

/// <p>The query key carrying the digest a queue abort was reviewed with (Story 20.23): the write refuses a queue whose
/// entries no longer give it.</p>
Parameter DIGESTKEY = "digest";

/// <p>The query key naming the class an item change of class (<parameter>TYPECHANGECLASS</parameter>) is composed for.</p>
Parameter NEWCLASSKEY = "newClass";

/// <p>The queue a business process of pool size 0 shares with every other such process; its entries are told apart by
/// the header's target.</p>
Parameter ACTORQUEUE = "Ens.Actor";

/// <p>The entity types and verbs the audit row of a queue or job write names (<method>AuditRuntime</method>, Story 20.23).</p>
Parameter ENTITYQUEUE = "interop-queue";

Parameter ENTITYMESSAGE = "interop-message";

Parameter ENTITYJOB = "interop-job";

Parameter VERBABORT = "abort";

Parameter VERBABORTALL = "abortall";

Parameter VERBSUSPEND = "suspend";

Parameter VERBSTOP = "stop";

/// <p>The state words a runtime read answers rows in: the namespace's current production, running or troubled
/// (<method>ReadState</method>'s words).</p>
Parameter LIVEWORDS = "Running,Troubled";

/// <p>The most entries one queue read examines. A queue shared by many hosts (<parameter>ACTORQUEUE</parameter>) is
/// walked entry by entry and each header opened; past this many the read stops, so an item whose entries lie further
/// down the queue shows only those it reached.</p>
Parameter QUEUESCANMAX = 10000;

/// <p>The most entries a queue read enumerates for <code>Entries</code> and <code>Digest</code>, and so the most a queue abort
/// aborts (Story 20.23). The sentence that states it (<class>OcuPilot.Api.InteropError</class>) holds the same number, pinned by
/// <file>ui/tools/interop.test.mjs</file>.</p>
Parameter ABORTMAX = 10000;

/// <p>What a setting refusal code begins with (<class>OcuPilot.Api.InteropError</class>).</p>
Parameter SETTINGCODEPREFIX = "INTEROP.SETTING.";

/// <p>The three groups a setting belongs to.</p>
Parameter TARGETCORE = "Core";

Parameter TARGETHOST = "Host";

Parameter TARGETADAPTER = "Adapter";

/// <p>The pair of adapter settings that makes an inbound file adapter read below its directory: the levels it
/// descends, and the directory it starts from.</p>
Parameter DESCENTSETTING = "SubdirectoryLevels";

Parameter DESCENTPATH = "FilePath";

/// <p>The editor-context components that mark a server path: a directory, or a file.</p>
Parameter LOCATIONDIRECTORY = "directorySelector";

Parameter LOCATIONFILE = "fileSelector";

/// <p>The query key naming the production an <code>Items</code> list reads: its one criterion.</p>
Parameter PRODUCTIONKEY = "production";

/// <p>What every item refusal code begins with (<class>OcuPilot.Api.InteropError</class>).</p>
Parameter ITEMCODEPREFIX = "INTEROP.ITEM.";

/// <p>The query key naming the namespace a call runs in.</p>
Parameter NAMESPACEKEY = "namespace";

/// <p>The query key naming the production a typed call is about.</p>
Parameter IDKEY = "id";

/// <p>The query key naming the action a <parameter>TYPESTATE</parameter> read is composed for, one of the
/// write types: the read then refuses what that action would be refused.</p>
Parameter ACTIONKEY = "action";

/// <p>The query key bounding a list's rows.</p>
Parameter MAXROWSKEY = "maxRows";

/// <p>The vendor's status codes this port answers in its own words.</p>
Parameter CODENOTQUIESCENT = "<Ens>ErrProductionNotQuiescent";

Parameter CODEJOBNOTSTOPPED = "<Ens>ErrJobNotStopped";

Parameter CODEJOBSNOTSTOPPED = "<Ens>ErrJobsNotStopped";

Parameter CODEALREADYRUNNING = "<Ens>ErrProductionAlreadyRunning";

Parameter CODENOTSHUTDOWNCLEANLY = "<Ens>ErrProductionNotShutdownCleanly";

Parameter CODESUSPENDEDMISMATCH = "<Ens>ErrProductionSuspendedMismatch";

Parameter CODERUNTIMELOCK = "<Ens>ErrCanNotAcquireRuntimeLock";

/// <p>The vendor's job-level locks (Story 20.23): the request lock an abort, suspend or stop takes on a job, and the status lock
/// a forced stop takes.</p>
Parameter CODEJOBLOCK = "<Ens>ErrCanNotAcquireJobLock";

Parameter CODEJOBSTATUSLOCKED = "<Ens>ErrJobStatusLocked";

/// <p>#940: the vendor's own privilege refusal.</p>
Parameter CODEPRIVILEGE = 940;

/// <p>The state words a write acts on. Any other word, <code>Unknown</code> and a mirror backup's
/// among them, refuses every action.</p>
Parameter ACTIONABLEWORDS = "Running,Stopped,Suspended,Troubled";

/// <p>The subsystem every log line of this port is written under.</p>
Parameter LOGSUBSYSTEM = "interopport";

/// <p>The reasons this port's own refusals carry.</p>
Parameter REASONNOTIMPLEMENTED = "This instance does not implement that operation.";

Parameter REASONNAMESPACESHAPE = "Name the namespace the call runs in.";

Parameter REASONNAMESPACEUNKNOWN = "This instance cannot name the database that namespace keeps its interoperability configuration in.";

Parameter REASONMAXROWS = "maxRows must be a whole number above zero.";

Parameter REASONIDREQUIRED = "Name the production.";

Parameter REASONLOCK = "The production's state could not be read just now. Try again.";

Parameter REASONROUTINESUNKNOWN = "This instance cannot name the database that namespace keeps its routines in.";

Parameter REASONITEMIDREQUIRED = "Name the production and the item.";

Parameter REASONQUEUEREQUIRED = "Name the queue.";

Parameter REASONMESSAGEREQUIRED = "Name the message.";

Parameter REASONJOBREQUIRED = "Name the job.";

Parameter REASONITEMBODY = "An item write names its fields in an object.";

Parameter REASONSETTINGID = "Name the production, the item, the group (Core, Host or Adapter) and the setting.";

Parameter REASONTABLEREQUIRED = "Name the lookup table.";

Parameter REASONENTRYID = "Name the lookup table and the entry's key.";

Parameter REASONENTRYBODY = "An entry write names its value in an object.";

Parameter REASONIMPORTSOURCE = "Name one file: a server file by its allowed directory and name, or a local file by its name and text.";

Parameter REASONIMPORTFILENAME = "A local file's name is 1 to 255 characters and holds no slash, no backslash and no control character.";

Parameter REASONTESTFIELDS = "Name the request's fields as a JSON object of text values, at most 200 of them.";

Parameter REASONTRANSFORMID = "Name the data transformation.";

/// <p>The class the pair sets are evaluated through. Overridable so a fixture can drive a denial in
/// process; production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>The longest a stop, restart or update waits, in seconds. Overridable so a test can shorten the
/// wait and observe a busy production refused; production never overrides it.</p>
ClassMethod StopSeconds() As %Integer
{
    Quit ..#STOPSECONDS
}

/// <p>The endpoint list as a <class>%List</class>.</p>
ClassMethod Endpoints() As %List
{
    Quit $ListFromString(..#ENDPOINTS)
}

/// <p>Whether <var>pType</var> is one of the writes this port carries.</p>
ClassMethod IsWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPESTART) || (pType = ..#TYPESTOP) || (pType = ..#TYPERESTART) || (pType = ..#TYPEUPDATE) || (pType = ..#TYPERECOVER)
}

/// <p>Whether <var>pType</var> is one of the item writes this port carries (Stories 20.3, 20.40 and 20.41).</p>
ClassMethod IsItemWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEENABLE) || (pType = ..#TYPEDISABLE) || (pType = ..#TYPEADD) || (pType = ..#TYPECOPY) || (pType = ..#TYPEREMOVE) || (pType = ..#TYPECHANGECLASS)
}

/// <p>Whether <var>pType</var> is one of the item runtime writes this port carries (Story 20.25): an action-style write
/// over the port-composed <code>ITEMRUN</code> read, needing the run pair and WRITE on the namespace's globals database and
/// no routines database. It is not an item write: the stored production configuration and the production class are not
/// changed.</p>
ClassMethod IsItemRunWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPESTOPITEM) || (pType = ..#TYPESTARTITEM) || (pType = ..#TYPERESTARTITEM)
}

/// <p>Whether <var>pType</var> is one of the setting writes this port carries (Story 20.22). A setting write is an
/// item write for the pairs and the databases it needs: it stores the item and the production class.</p>
ClassMethod IsSettingWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPESET) || (pType = ..#TYPERESET)
}

/// <p>Whether <var>pType</var> is one of the queue and job writes this port carries (Story 20.23): action-style writes
/// over a port-composed read of the target, each needing WRITE on the namespace's globals database and no routines
/// database.</p>
ClassMethod IsRuntimeWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEABORTQUEUE) || (pType = ..#TYPEABORTMESSAGE) || (pType = ..#TYPEABORTJOB) || (pType = ..#TYPESUSPENDJOB) || (pType = ..#TYPESTOPJOB)
}

/// <p>Whether <var>pType</var> is the host test's send (Story 20.6) or the data transformation test (Story 20.27): an action-style
/// write over a port-composed read, needing WRITE on the namespace's globals database and no routines database.</p>
ClassMethod IsTestWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPESENDTEST) || (pType = ..#TYPETRANSFORMTEST)
}

/// <p>Whether <var>pType</var> is one of the Messages endpoint's resend writes (Story 20.31): an action-style write over a
/// port-composed read of the messages, needing WRITE on the namespace's globals database and no routines database.</p>
ClassMethod IsMessageWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPERESENDMESSAGES) || (pType = ..#TYPEEDITRESEND)
}

/// <p>Whether <var>pType</var> is one of the Messages endpoint's types: the four resend types, the two reads and the two writes, and the three export types.</p>
ClassMethod IsMessageType(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPERESEND) || (pType = ..#TYPEEDIT) || ..IsMessageWrite(pType) || ..IsMessageExportType(pType)
}

/// <p>Whether <var>pType</var> is one of the business partner writes this port carries (Story 20.26): an action-style or merge
/// write over the <code>PARTNER</code> read, needing WRITE on the namespace's globals database and no routines database.</p>
ClassMethod IsPartnerWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEADDPARTNER) || (pType = ..#TYPESETPARTNER) || (pType = ..#TYPEREMOVEPARTNER)
}

/// <p>Whether <var>pType</var> is one of the system default setting writes this port carries (Story 24.15): a create, a merge or a
/// delete over the <code>DEFAULTSETTING</code> read, needing WRITE on the namespace's globals database and no routines database.</p>
ClassMethod IsDefaultSettingWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEADDDEFAULT) || (pType = ..#TYPESETDEFAULT) || (pType = ..#TYPEREMOVEDEFAULT)
}

/// <p>Whether <var>pType</var> is one of the credential writes this port carries (Story 24.15): a create, a merge, a password set or a
/// delete over the <code>CREDENTIAL</code> read, needing WRITE on the namespace's globals database and no routines database.</p>
ClassMethod IsCredentialWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEADDCREDENTIAL) || (pType = ..#TYPESETCREDENTIAL) || (pType = ..#TYPEPASSWORDCREDENTIAL) || (pType = ..#TYPEREMOVECREDENTIAL)
}

/// <p>Whether <var>pType</var> is one of the schedule spec writes this port carries (Story 24.15): a create, a merge or a delete over the
/// <code>SCHEDULE</code> read, needing WRITE on the namespace's globals database and no routines database.</p>
ClassMethod IsScheduleWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEADDSCHEDULE) || (pType = ..#TYPESETSCHEDULE) || (pType = ..#TYPEREMOVESCHEDULE)
}

/// <p>Whether <var>pType</var> is one of the Productions endpoint's two startup writes (Story 24.3): a merge over the
/// <code>STARTUP</code> read, needing WRITE on the namespace's globals database and no routines database.</p>
ClassMethod IsStartupWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEAUTOSTART) || (pType = ..#TYPESHUTDOWNGROUP)
}

/// <p>Whether <var>pType</var> is any write this port carries, whichever family declares it.</p>
ClassMethod IsAnyWrite(pType As %String) As %Boolean
{
    Quit ..IsStartupWrite(pType) || ..IsWrite(pType) || ..IsItemWrite(pType) || ..IsItemRunWrite(pType) || ..IsSettingWrite(pType) || ..IsRuntimeWrite(pType) || ..IsLookupWrite(pType) || ..IsPartnerWrite(pType) || ..IsDefaultSettingWrite(pType) || ..IsCredentialWrite(pType) || ..IsScheduleWrite(pType) || ..IsPurgeWrite(pType) || ..IsArchiveWrite(pType) || (pType = ..#TYPEARCHIVESETTINGSET) || ..IsSuspendedWrite(pType) || ..IsTestWrite(pType) || ..IsMessageWrite(pType) || ..IsAlertWrite(pType) || ..IsLogPurgeWrite(pType)
}

/// <p>The runtime reads, as a <class>%List</class>: Story 20.4's nine, Story 20.9's three message reads, Story 20.30's session trace and Story 24.4's three session reads. Each serves
/// <code>LIST</code>; Queues, QueueItems and Jobs also serve the typed reads and writes of Story 20.23
/// (<method>Serves</method>).</p>
ClassMethod RuntimeEndpoints() As %List
{
    Quit $ListBuild(..#ENDPOINTMONITOR, ..#ENDPOINTITEMSTATUS, ..#ENDPOINTQUEUES, ..#ENDPOINTQUEUEITEMS, ..#ENDPOINTITEMQUEUE, ..#ENDPOINTITEMLOG, ..#ENDPOINTITEMMESSAGES, ..#ENDPOINTJOBS, ..#ENDPOINTITEMJOBS, ..#ENDPOINTMESSAGES, ..#ENDPOINTMESSAGEHEADER, ..#ENDPOINTMESSAGECONTENTS, ..#ENDPOINTMESSAGETRACE, ..#ENDPOINTSESSIONS, ..#ENDPOINTSESSIONSUMMARY, ..#ENDPOINTSESSIONMESSAGES)
}

/// <p>The runtime reads that are about one item, named under <parameter>ITEMKEY</parameter>.</p>
ClassMethod ItemEndpoints() As %List
{
    Quit $ListBuild(..#ENDPOINTITEMSTATUS, ..#ENDPOINTITEMQUEUE, ..#ENDPOINTITEMLOG, ..#ENDPOINTITEMMESSAGES, ..#ENDPOINTITEMJOBS)
}

/// <p>The pairs <var>pEndpoint</var> requires for <var>pType</var>, as the <code>%List</code> of
/// two-element <code>%List</code>s the gate evaluates: the endpoint's own pairs, then
/// <parameter>WRITEPAIRS</parameter> for a production write, <parameter>ITEMWRITEPAIRS</parameter> for an
/// item write, or the queue or job write's own pair (<parameter>QUEUEWRITEPAIR</parameter>,
/// <parameter>JOBWRITEPAIR</parameter>, <parameter>SUSPENDPAIR</parameter>); <code>""</code> for an endpoint this port does
/// not serve. The Items and Settings endpoints take the
/// Productions endpoint's pairs, and so does ItemStatus. The other runtime reads take the pairs of the classic page
/// they replace (Story 20.4): Monitor, Queues and QueueItems, Jobs; and each item tab the Productions pairs plus its
/// own (queue, event log, message headers, jobs). The Messages and MessageHeader endpoints, and the three session endpoints of Story 24.4, take the classic message viewer's
/// pair (<parameter>MESSAGEPAIRS</parameter>), and MessageContents adds the Contents pane's (Story 20.9) and MessageTrace the Visual Trace's
/// (Story 20.30).</p>
ClassMethod Pairs(pEndpoint As %String, pType As %String = "") As %List
{
    If (pEndpoint = ..#ENDPOINTPRODUCTIONS) || (pEndpoint = ..#ENDPOINTITEMS) || (pEndpoint = ..#ENDPOINTSETTINGS) || (pEndpoint = ..#ENDPOINTITEMSTATUS) || (pEndpoint = ..#ENDPOINTBUSINESSPARTNERS) {
        Set tSpec = ..#PRODUCTIONPAIRS
    } ElseIf (pEndpoint = ..#ENDPOINTLOOKUPTABLES) || (pEndpoint = ..#ENDPOINTLOOKUPENTRIES) {
        Set tSpec = ..#LOOKUPPAIRS
    } ElseIf (pEndpoint = ..#ENDPOINTDEFAULTSETTINGS) || (pEndpoint = ..#ENDPOINTDEFAULTSETTINGSDIFF) {
        Set tSpec = ..#DEFAULTSETTINGPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTCREDENTIALS {
        Set tSpec = ..#CREDENTIALPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTSCHEDULES {
        Set tSpec = ..#SCHEDULEPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTPURGESETTINGS {
        Set tSpec = ..#PURGESETTINGPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTPURGE {
        Set tSpec = ..#PURGEPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTSUSPENDEDMESSAGES {
        Set tSpec = ..#MESSAGEPAIRS
    } ElseIf (pEndpoint = ..#ENDPOINTARCHIVESETTINGS) || (pEndpoint = ..#ENDPOINTARCHIVE) || (pEndpoint = ..#ENDPOINTARCHIVEERRORS) {
        Set tSpec = ..#ARCHIVEPAIRS
    } ElseIf (pEndpoint = ..#ENDPOINTMANAGEDALERTS) || (pEndpoint = ..#ENDPOINTMANAGEDALERTACTIONS) {
        Set tSpec = ..#ALERTPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTRULELOG {
        Set tSpec = ..#RULELOGPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTPROCESSLOG {
        Set tSpec = ..#PROCESSLOGPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTITEMTEST {
        Set tSpec = ..#TESTPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTITEMCLASSES {
        Set tSpec = ..#PRODUCTIONPAIRS _ "," _ ..#ITEMWRITEPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTMONITOR {
        Set tSpec = ..#MONITORPAIRS
    } ElseIf (pEndpoint = ..#ENDPOINTQUEUES) || (pEndpoint = ..#ENDPOINTQUEUEITEMS) {
        Set tSpec = ..#QUEUEPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTJOBS {
        Set tSpec = ..#JOBPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTITEMQUEUE {
        Set tSpec = ..#PRODUCTIONPAIRS _ "," _ ..#ITEMQUEUEPAIR
    } ElseIf pEndpoint = ..#ENDPOINTITEMLOG {
        Set tSpec = ..#PRODUCTIONPAIRS _ "," _ ..#ITEMLOGPAIR
    } ElseIf pEndpoint = ..#ENDPOINTITEMMESSAGES {
        Set tSpec = ..#PRODUCTIONPAIRS _ "," _ ..#ITEMMESSAGEPAIR
    } ElseIf (pEndpoint = ..#ENDPOINTMESSAGES) || (pEndpoint = ..#ENDPOINTMESSAGEHEADER) || (pEndpoint = ..#ENDPOINTSESSIONS) || (pEndpoint = ..#ENDPOINTSESSIONSUMMARY) || (pEndpoint = ..#ENDPOINTSESSIONMESSAGES) {
        Set tSpec = ..#MESSAGEPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTMESSAGECONTENTS {
        Set tSpec = ..#MESSAGEPAIRS _ "," _ ..#MESSAGECONTENTPAIR
    } ElseIf pEndpoint = ..#ENDPOINTMESSAGETRACE {
        Set tSpec = ..#MESSAGEPAIRS _ "," _ ..#MESSAGETRACEPAIR
    } ElseIf pEndpoint = ..#ENDPOINTITEMJOBS {
        Set tSpec = ..#PRODUCTIONPAIRS _ "," _ ..#ITEMJOBPAIR
    } ElseIf $ListFind(..Endpoints(), pEndpoint) {
        Set tSpec = ..#CODEPAIRS
    } Else {
        Quit ""
    }
    If ..IsWrite(pType) Set tSpec = tSpec _ "," _ ..#WRITEPAIRS
    If ..IsItemWrite(pType) || ..IsSettingWrite(pType) Set tSpec = tSpec _ "," _ ..#ITEMWRITEPAIRS
    If ..IsItemRunWrite(pType) Set tSpec = tSpec _ "," _ ..#ITEMRUNPAIR
    If (pType = ..#TYPEABORTQUEUE) || (pType = ..#TYPEABORTMESSAGE) Set tSpec = tSpec _ "," _ ..#QUEUEWRITEPAIR
    If (pType = ..#TYPEABORTJOB) || (pType = ..#TYPESTOPJOB) Set tSpec = tSpec _ "," _ ..#JOBWRITEPAIR
    If pType = ..#TYPESUSPENDJOB Set tSpec = tSpec _ "," _ ..#SUSPENDPAIR
    If ..IsLookupWrite(pType) Set tSpec = tSpec _ "," _ ..#LOOKUPWRITEPAIR
    If ..IsPartnerWrite(pType) Set tSpec = tSpec _ "," _ ..#PARTNERWRITEPAIR
    If ..IsDefaultSettingWrite(pType) Set tSpec = tSpec _ "," _ ..#DEFAULTSETTINGWRITEPAIR
    If ..IsCredentialWrite(pType) Set tSpec = tSpec _ "," _ ..#CREDENTIALWRITEPAIR
    If ..IsScheduleWrite(pType) Set tSpec = tSpec _ "," _ ..#SCHEDULEWRITEPAIR
    If ((pEndpoint = ..#ENDPOINTARCHIVESETTINGS) && (pType = ..#TYPEARCHIVESETTINGSET)) || ((pEndpoint = ..#ENDPOINTARCHIVE) && ..IsArchiveWrite(pType)) Set tSpec = tSpec _ "," _ ..#ARCHIVEWRITEPAIR
    If (pEndpoint = ..#ENDPOINTMANAGEDALERTS) && (..IsAlertWrite(pType) || (pType = ..#TYPEALERTOWNERS)) Set tSpec = tSpec _ "," _ ..#ALERTWRITEPAIR
    If ((pEndpoint = ..#ENDPOINTRULELOG) || (pEndpoint = ..#ENDPOINTPROCESSLOG)) && ..IsLogPurgeWrite(pType) Set tSpec = tSpec _ "," _ ..#LOGPURGEPAIR
    If pType = ..#TYPEAUTOSTART Set tSpec = tSpec _ "," _ ..#AUTOSTARTPAIR
    If pType = ..#TYPESHUTDOWNGROUP Set tSpec = tSpec _ "," _ ..#GROUPPAIR
    If (pEndpoint = ..#ENDPOINTTRANSFORMS) && ((pType = ..#TYPETRANSFORM) || (pType = ..#TYPETRANSFORMTEST)) Set tSpec = tSpec _ "," _ ..#DTLTESTPAIR
    If (pEndpoint = ..#ENDPOINTMESSAGES) && ((pType = ..#TYPERESEND) || (pType = ..#TYPERESENDMESSAGES)) Set tSpec = tSpec _ "," _ ..#RESENDPAIR
    If (pEndpoint = ..#ENDPOINTMESSAGES) && ((pType = ..#TYPEEDIT) || (pType = ..#TYPEEDITRESEND)) Set tSpec = tSpec _ "," _ ..#MESSAGECONTENTPAIR _ "," _ ..#RESENDPAIR _ "," _ ..#EDITRESENDPAIR
    If (pEndpoint = ..#ENDPOINTMESSAGES) && ..IsMessageExportType(pType) Set tSpec = tSpec _ "," _ ..#EXPORTPAIR _ "," _ ..#MESSAGECONTENTPAIR
    If pEndpoint = ..#ENDPOINTSUSPENDEDMESSAGES {
        Set tKind = ..SuspendedKind(pType)
        If tKind = "resubmit" Set tSpec = tSpec _ "," _ ..#RESENDPAIR
        If tKind = "edit" Set tSpec = tSpec _ "," _ ..#MESSAGECONTENTPAIR _ "," _ ..#RESENDPAIR _ "," _ ..#EDITRESENDPAIR
        If (tKind = "discard") || (tKind = "delete") Set tSpec = tSpec _ "," _ ..#DISCARDPAIR
    }
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(tSpec)
}

/// <p>Whether endpoint <var>pEndpoint</var> serves request type <var>pType</var>: <code>LIST</code> on every endpoint; and,
/// beyond it, Productions the production reads and writes, Items and Settings theirs, and Queues (<code>QUEUE</code>,
/// <code>ABORTQUEUE</code>), QueueItems (<code>ENTRY</code>, <code>ABORTMESSAGE</code>), Jobs (<code>JOB</code>,
/// <code>ABORTJOB</code>, <code>SUSPENDJOB</code>, <code>STOPJOB</code>) and Transforms (<code>TRANSFORM</code>,
/// <code>TRANSFORMTEST</code>), Messages the four resend types of Story 20.31 and BusinessPartners the read and three writes of
/// Story 20.26.</p>
ClassMethod Serves(pEndpoint As %String, pType As %String) As %Boolean
{
    If '$ListFind(..Endpoints(), pEndpoint) Quit 0
    If pType = ..#TYPELIST Quit 1
    If pEndpoint = ..#ENDPOINTITEMS Quit (pType = ..#TYPEITEM) || ..IsItemWrite(pType) || (pType = ..#TYPEITEMRUN) || ..IsItemRunWrite(pType)
    If pEndpoint = ..#ENDPOINTSETTINGS Quit (pType = ..#TYPESETTING) || ..IsSettingWrite(pType)
    If pEndpoint = ..#ENDPOINTQUEUES Quit (pType = ..#TYPEQUEUE) || (pType = ..#TYPEABORTQUEUE)
    If pEndpoint = ..#ENDPOINTQUEUEITEMS Quit (pType = ..#TYPEENTRY) || (pType = ..#TYPEABORTMESSAGE)
    If pEndpoint = ..#ENDPOINTJOBS Quit (pType = ..#TYPEJOB) || (pType = ..#TYPEABORTJOB) || (pType = ..#TYPESUSPENDJOB) || (pType = ..#TYPESTOPJOB)
    If pEndpoint = ..#ENDPOINTLOOKUPTABLES Quit (pType = ..#TYPELOOKUPTABLE) || (pType = ..#TYPEDELETETABLE) || (pType = ..#TYPEIMPORTTABLE) || (pType = ..#TYPEIMPORT) || (pType = ..#TYPEEXPORT)
    If pEndpoint = ..#ENDPOINTLOOKUPENTRIES Quit (pType = ..#TYPELOOKUPENTRY) || (pType = ..#TYPEADDENTRY) || (pType = ..#TYPESETENTRY) || (pType = ..#TYPEREMOVEENTRY)
    If pEndpoint = ..#ENDPOINTBUSINESSPARTNERS Quit (pType = ..#TYPEPARTNER) || ..IsPartnerWrite(pType)
    If pEndpoint = ..#ENDPOINTDEFAULTSETTINGS Quit (pType = ..#TYPEDEFAULTSETTING) || ..IsDefaultSettingWrite(pType)
    If pEndpoint = ..#ENDPOINTDEFAULTSETTINGSDIFF Quit 0
    If pEndpoint = ..#ENDPOINTCREDENTIALS Quit (pType = ..#TYPECREDENTIAL) || ..IsCredentialWrite(pType)
    If pEndpoint = ..#ENDPOINTSCHEDULES Quit (pType = ..#TYPESCHEDULE) || ..IsScheduleWrite(pType)
    If pEndpoint = ..#ENDPOINTPURGESETTINGS Quit (pType = ..#TYPESETTING) || (pType = ..#TYPEPURGESETTINGSET)
    If pEndpoint = ..#ENDPOINTPURGE Quit (pType = ..#TYPEPURGESTATE) || (pType = ..#TYPEPURGE)
    If pEndpoint = ..#ENDPOINTSUSPENDEDMESSAGES Quit ..SuspendedKind(pType) '= ""
    If pEndpoint = ..#ENDPOINTARCHIVESETTINGS Quit (pType = ..#TYPESETTING) || (pType = ..#TYPEARCHIVESETTINGSET)
    If pEndpoint = ..#ENDPOINTARCHIVE Quit (pType = ..#TYPEARCHIVESTATE) || (pType = ..#TYPEARCHIVE)
    If pEndpoint = ..#ENDPOINTARCHIVEERRORS Quit 0
    If pEndpoint = ..#ENDPOINTMANAGEDALERTS Quit (pType = ..#TYPEALERT) || (pType = ..#TYPEALERTOWNERS) || (pType = ..#TYPEUPDATEALERT)
    If pEndpoint = ..#ENDPOINTMANAGEDALERTACTIONS Quit 0
    If pEndpoint = ..#ENDPOINTRULELOG Quit (pType = ..#TYPERULELOGSTATE) || (pType = ..#TYPEPURGERULELOG)
    If pEndpoint = ..#ENDPOINTPROCESSLOG Quit (pType = ..#TYPEPROCESSLOGSTATE) || (pType = ..#TYPEPURGEPROCESSLOG)
    If pEndpoint = ..#ENDPOINTITEMTEST Quit (pType = ..#TYPETESTTARGET) || (pType = ..#TYPESENDTEST)
    If pEndpoint = ..#ENDPOINTTRANSFORMS Quit (pType = ..#TYPETRANSFORM) || (pType = ..#TYPETRANSFORMTEST)
    If pEndpoint = ..#ENDPOINTMESSAGES Quit ..IsMessageType(pType)
    If pEndpoint '= ..#ENDPOINTPRODUCTIONS Quit 0
    Quit (pType = ..#TYPESTATE) || (pType = ..#TYPESTARTUP) || ..IsWrite(pType) || ..IsStartupWrite(pType)
}

/// <p>The code a write of type <var>pType</var> is refused with, or <code>""</code> when it may go ahead
/// (AD-62): whatever the vendor would answer as a silent success, or refuse, is refused here by its own
/// name. <var>pWord</var> is the target's state word, <var>pCurrent</var> the namespace's current
/// production (<code>""</code> when none), <var>pId</var> the target and <var>pNeedsUpdate</var>
/// whether the running production has an update pending. Pure.</p>
/// <ul>
/// <li>Any word outside <parameter>ACTIONABLEWORDS</parameter>: <code>INTEROP.PRODUCTION.STATE</code>.</li>
/// <li>Start: <code>RUNNING</code> when the target runs, <code>TROUBLED</code> when it is troubled,
/// <code>OTHER</code> when another production is current.</li>
/// <li>Stop and restart: <code>NOTRUNNING</code> unless the target runs.</li>
/// <li>Update: <code>NOTRUNNING</code> unless the target runs, then <code>UPTODATE</code> when nothing is
/// pending.</li>
/// <li>Recover: <code>NOTTROUBLED</code> unless the target is troubled.</li>
/// </ul>
ClassMethod Refusal(pType As %String, pWord As %String, pCurrent As %String, pId As %String, pNeedsUpdate As %Boolean) As %String
{
    If '$ListFind($ListFromString(..#ACTIONABLEWORDS), pWord) Quit ##class(OcuPilot.Api.InteropError).#STATE
    If pType = ..#TYPESTART {
        If (pWord = "Running") && (pCurrent = pId) Quit ##class(OcuPilot.Api.InteropError).#RUNNING
        If (pWord = "Troubled") && (pCurrent = pId) Quit ##class(OcuPilot.Api.InteropError).#TROUBLED
        If (pCurrent '= "") && (pCurrent '= pId) Quit ##class(OcuPilot.Api.InteropError).#OTHER
        Quit ""
    }
    If (pType = ..#TYPESTOP) || (pType = ..#TYPERESTART) {
        If pWord '= "Running" Quit ##class(OcuPilot.Api.InteropError).#NOTRUNNING
        Quit ""
    }
    If pType = ..#TYPEUPDATE {
        If pWord '= "Running" Quit ##class(OcuPilot.Api.InteropError).#NOTRUNNING
        If 'pNeedsUpdate Quit ##class(OcuPilot.Api.InteropError).#UPTODATE
        Quit ""
    }
    If pType = ..#TYPERECOVER {
        If pWord '= "Troubled" Quit ##class(OcuPilot.Api.InteropError).#NOTTROUBLED
        Quit ""
    }
    Quit ""
}

/// <p>The codes a write's fresh read refuses with when the action does not fit the production's state,
/// and a namespace that runs no productions, as a <class>%List</class>: the tools'
/// <method>OcuPilot.Screen.Tool.Write.PreconditionCodes</method>, which may not name
/// <class>OcuPilot.Api.InteropError</class> themselves.</p>
ClassMethod PreconditionCodes() As %List
{
    Quit ##class(OcuPilot.Api.InteropError).PreconditionCodes() _ $ListBuild(##class(OcuPilot.Api.InteropError).#NAMESPACE)
}

/// <p>The codes a startup tool's fresh read refuses with when the values do not fit the production, and a namespace that runs no
/// productions, as a <class>%List</class> (Story 24.3): the tools' <method>OcuPilot.Screen.Tool.Write.PreconditionCodes</method>, which
/// may not name <class>OcuPilot.Api.InteropError</class> themselves.</p>
ClassMethod StartupPreconditionCodes() As %List
{
    Quit ##class(OcuPilot.Api.InteropError).StartupPreconditionCodes() _ $ListBuild(##class(OcuPilot.Api.InteropError).#NAMESPACE)
}

/// <p>The published sentence of <var>pCode</var>, <code>""</code> for a code this port does not
/// declare.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    Quit ##class(OcuPilot.Api.InteropError).ReasonFor(pCode)
}

/// <p>Serve <var>pEndpoint</var> for request type <var>pType</var>, after this class's header's
/// gate.</p>
/// <p><var>pQuery</var> carries <parameter>NAMESPACEKEY</parameter> (optional: the request's scope when
/// absent), <parameter>IDKEY</parameter> for a typed call, <parameter>ACTIONKEY</parameter> for a
/// <code>STATE</code> read composed for an action, and <parameter>MAXROWSKEY</parameter> for a list
/// (optional, a whole number above zero). <var>pBody</var> is not read: no write carries one.</p>
/// <p>On success, at 200, <var>pResult</var> is: for <code>LIST</code> on Productions an array of
/// <code>{Name, Status, LastStartTime, LastStopTime}</code>; for <code>LIST</code> on a code list an
/// array of <code>{Name, Modified}</code> (the document name <code>&lt;class&gt;.cls</code> and the
/// class's last change as <code>YYYY-MM-DD HH:MM:SS</code>), cut at <parameter>MAXROWSKEY</parameter>;
/// for <code>STATE</code> and after every write <code>{Name, Namespace, State, Current,
/// NeedsUpdate}</code>; for the nine runtime reads an array of rows (<method>InvokeRuntime</method>); and for the typed
/// queue, entry and job reads and the five queue and job writes one row (<method>InvokeTyped</method>).</p>
/// <p>Otherwise an error status is returned, <var>pHttpStatus</var> is the status to answer with and
/// <var>pFault</var> the wire fault: 403 <code>AUTH.NOPRIVILEGE</code> with
/// <code>detail.failedPair</code>; 400 <code>PORT.VALIDATION</code> for a namespace, id or cap of the
/// wrong shape, or a namespace whose database cannot be resolved; 501
/// <code>PORT.NOTIMPLEMENTED</code>; 409 <parameter>OcuPilot.Api.InteropError.NAMESPACE</parameter> for
/// a namespace that runs no productions; 404 <code>PORT.NOTFOUND</code> for an unknown production,
/// unlogged; 409 with one of the <parameter>OcuPilot.Api.InteropError</parameter> codes
/// (<method>Refusal</method>, or the vendor's own refusal of a busy production); 503
/// <code>PORT.UNAVAILABLE</code> when the runtime lock cannot be taken; 403
/// <code>PORT.ACCESSDENIED</code> for <code>&lt;PROTECT&gt;</code> or #940; and 500
/// <code>INTERNAL</code>, logged, for anything else.</p>
/// <p><var>pCut</var> is 1 when a text the answer carries was cut at <parameter>TESTOUTPUTMAX</parameter> characters (a message's
/// contents); 0 otherwise.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace is
/// unchanged on return.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pCut As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set pCut = 0
    Try {
        If '..Serves(pEndpoint, pType) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tWrite = ..IsAnyWrite(pType)
        Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
        If tNamespace = "" Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        Set tSC = ..Admit(pEndpoint, pType, tNamespace, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit

        If pEndpoint = ..#ENDPOINTITEMS {
            Set tSC = ..InvokeItems(tNamespace, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTSETTINGS {
            Set tSC = ..InvokeSettings(tNamespace, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTITEMTEST {
            Set tSC = ..InvokeItemTest(tNamespace, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTITEMCLASSES {
            Set tSC = ..InvokeItemClasses(tNamespace, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#ENDPOINTTRANSFORMS) && (pType '= ..#TYPELIST) {
            Set tSC = ..InvokeTransformTest(tNamespace, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If $ListFind(..RuntimeEndpoints(), pEndpoint) {
            Set tSC = ..InvokeRuntime(tNamespace, pEndpoint, pType, .pQuery, .pResult, .pHttpStatus, .pFault, .pCut)
            Quit
        }
        If (pEndpoint = ..#ENDPOINTPRODUCTIONS) && ((pType = ..#TYPESTARTUP) || ..IsStartupWrite(pType)) {
            Set tSC = ..InvokeStartup(tNamespace, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#ENDPOINTLOOKUPTABLES) || (pEndpoint = ..#ENDPOINTLOOKUPENTRIES) {
            Set tSC = ..InvokeLookup(tNamespace, pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#ENDPOINTBUSINESSPARTNERS) && (pType '= ..#TYPELIST) {
            Set tSC = ..InvokePartner(tNamespace, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#ENDPOINTDEFAULTSETTINGS) || (pEndpoint = ..#ENDPOINTDEFAULTSETTINGSDIFF) {
            Set tSC = ..InvokeDefaultSetting(tNamespace, pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTCREDENTIALS {
            Set tSC = ..InvokeCredential(tNamespace, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTSCHEDULES {
            Set tSC = ..InvokeSchedule(tNamespace, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTPURGESETTINGS {
            Set tSC = ..InvokePurgeSettings(tNamespace, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTPURGE {
            Set tSC = ..InvokePurge(tNamespace, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTSUSPENDEDMESSAGES {
            Set tSC = ..InvokeSuspended(tNamespace, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTARCHIVESETTINGS {
            Set tSC = ..InvokeArchiveSettings(tNamespace, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#ENDPOINTARCHIVE) || (pEndpoint = ..#ENDPOINTARCHIVEERRORS) {
            Set tSC = ..InvokeArchive(tNamespace, pEndpoint, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#ENDPOINTMANAGEDALERTS) || (pEndpoint = ..#ENDPOINTMANAGEDALERTACTIONS) {
            Set tSC = ..InvokeAlerts(tNamespace, pEndpoint, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#ENDPOINTRULELOG) || (pEndpoint = ..#ENDPOINTPROCESSLOG) {
            Set tSC = ..InvokeLog(tNamespace, pEndpoint, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }

        If pType = ..#TYPELIST {
            Set tMax = 0
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tMax = +tMaxText
            If pEndpoint = ..#ENDPOINTPRODUCTIONS {
                Set tSC = ..ListProductions(tNamespace, tMax, .pResult, .pHttpStatus, .pFault)
            } ElseIf pEndpoint = ..#ENDPOINTBUSINESSPARTNERS {
                Set tSC = ..ListPartners(tNamespace, tMax, .pResult, .pHttpStatus, .pFault)
            } Else {
                Set tSC = ..ListClasses(tNamespace, pEndpoint, tMax, .pResult, .pHttpStatus, .pFault)
            }
            Quit
        }

        Set tId = $Get(pQuery(..#IDKEY))
        If tId = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONIDREQUIRED, .pHttpStatus, .pFault)
            Quit
        }
        Set tAction = $Select(tWrite: pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && '..IsWrite(tAction) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..ReadState(tNamespace, tId, .tFacts, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If tAction '= "" {
            Set tCode = ..Refusal(tAction, tFacts("word"), tFacts("current"), tId, tFacts("needsUpdate"))
            If tCode '= "" {
                Set tSC = ..Conflict(tCode, .pHttpStatus, .pFault)
                Quit
            }
        }
        If 'tWrite {
            Set pResult = ..StateRow(tNamespace, tId, .tFacts)
            Set pHttpStatus = 200
            Quit
        }
        Set tSC = ..Perform(tNamespace, pType, tId, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>This port's gate (AD-29, AD-62), evaluated before any vendor call for <var>pType</var> on
/// <var>pEndpoint</var> in <var>pNamespace</var>, in this order: the endpoint's pairs; the namespace's shape;
/// the namespace reporting interoperability; READ on its globals database (WRITE for a write); and, for an item
/// write, WRITE on its routines database. A refusal is an error status with <var>pHttpStatus</var> and
/// <var>pFault</var> set as <method>Invoke</method> answers them. Names no vendor class.</p>
ClassMethod Admit(pEndpoint As %String, pType As %String, pNamespace As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    ; The owner choices are a read that needs the update's pairs, the database's WRITE among them (Story 24.17 Batch 1).
    Set tWrite = ..IsAnyWrite(pType) || (pType = ..#TYPEALERTOWNERS)
    Set tFailedPair = ""
    ; EvaluateRequired, not EvaluatePairs: a pair list mis-edited to empty fails closed.
    If '$ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(pEndpoint, pType), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    If '$Match(pNamespace, ##class(OcuPilot.Port.AtelierPort).#NAMESPACEPATTERN) Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACESHAPE, .pHttpStatus, .pFault)
    If '##class(OcuPilot.Kernel.Shell.NamespaceFeatures).Reports("interoperability", pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#NAMESPACE, .pHttpStatus, .pFault)
    Set tResource = ""
    If '##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase(pNamespace, .tResource, .tReadOnly) || (tResource = "") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
    If '$ClassMethod(..GateClass(), "EvaluateRequired", $ListBuild($ListBuild(tResource, $Select(tWrite: ..#WRITEPERMISSION, 1: ..#READPERMISSION))), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    ; An item write also writes the routines database (^oddDEF), after the globals one.
    If '..IsItemWrite(pType) && '..IsSettingWrite(pType) Quit $$$OK
    Set tRoutineResource = ""
    If '..RoutineResource(pNamespace, .tRoutineResource) || (tRoutineResource = "") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONROUTINESUNKNOWN, .pHttpStatus, .pFault)
    If '$ClassMethod(..GateClass(), "EvaluateRequired", $ListBuild($ListBuild(tRoutineResource, ..#WRITEPERMISSION)), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>The Productions list: one row per <code>Ens.Config.Production</code>, <code>{Name, Status,
/// LastStartTime, LastStopTime, AutoStart, StartupPriority, ShutdownGroup}</code> (<code>AutoStart</code> is <code>Yes</code> for the
/// production the namespace starts with the instance and <code>No</code> otherwise, <code>StartupPriority</code> is empty unless
/// <code>Yes</code>, and <code>ShutdownGroup</code> is the group the vendor reads for it), at most <var>pMax</var> of them when it is above zero. The
/// vendor's own query answers them (<code>Ens.Config.Production:ProductionStatus</code>); only vendor
/// classes run while the namespace is switched, and the rows are built once it is restored.</p>
ClassMethod ListProductions(pNamespace As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tCaught = ""
    Set tStatusSC = $$$OK
    Kill tFound
    Set tFound = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tAutoName = $Get(^Ens.AutoStart)
        Set tResultSet = ##class(%ResultSet).%New("Ens.Config.Production:ProductionStatus")
        Set tStatusSC = tResultSet.Execute()
        If $$$ISOK(tStatusSC) {
            While tResultSet.Next() {
                If (pMax > 0) && (tFound >= pMax) Quit
                Set tFound = tFound + 1
                Set tWord = ##class(Ens.Config.Production).ProductionStateToText(+tResultSet.GetData(5), 0)
                If $Extract(tWord, 1, 13) = "Unrecognized:" Set tWord = "Unknown"
                Set tName = tResultSet.GetData(1)
                Set tAuto = (tAutoName '= "") && (tAutoName = tName)
                Set tFound(tFound) = $ListBuild(tName, tWord, tResultSet.GetData(3), tResultSet.GetData(4), $Select(tAuto: "Yes", 1: "No"), $Select(tAuto: +$Get(^Ens.AutoStart("StartupPriority"), 0), 1: ""), ##class(Ens.Director).GetProductionShutdownGroup(tName, , 0))
            }
            Do tResultSet.Close()
        }
        Set tResultSet = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the production list failed", .pHttpStatus, .pFault)
    If $$$ISERR(tStatusSC) Quit ..Statused(tStatusSC, "the production list failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Set tRow = {}
        Do tRow.%Set("Name", $List(tFound(tI), 1) _ "", "string")
        Do tRow.%Set("Status", $List(tFound(tI), 2) _ "", "string")
        Do tRow.%Set("LastStartTime", $List(tFound(tI), 3) _ "", "string")
        Do tRow.%Set("LastStopTime", $List(tFound(tI), 4) _ "", "string")
        Do tRow.%Set("AutoStart", $List(tFound(tI), 5), "string")
        Do tRow.%Set("StartupPriority", $List(tFound(tI), 6) _ "", "string")
        Do tRow.%Set("ShutdownGroup", $List(tFound(tI), 7) _ "", "string")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The classes of <var>pEndpoint</var>'s kind in <var>pNamespace</var>, at most <var>pMax</var> of
/// them when it is above zero: the subclasses of <code>Ens.BusinessProcess</code> less
/// <code>Ens.BusinessProcessBPL</code>, of <code>Ens.DataTransform</code> less
/// <code>Ens.DataTransformDTL</code>, and of <code>Ens.Rule.Definition</code>, through
/// <code>%Dictionary.ClassDefinition:SubclassOf</code>, which writes nothing. A Rules row is
/// <code>{Name, Modified}</code>, and a Processes or Transforms row is <code>{Name, Modified, Coded}</code>: the document name
/// <code>&lt;class&gt;.cls</code>, the class's <code>TimeChanged</code> as local <code>YYYY-MM-DD HH:MM:SS</code>, and a
/// boolean that is true when the class is not a subclass of the excluded class (<code>Ens.BusinessProcessBPL</code> or
/// <code>Ens.DataTransformDTL</code>) in the dictionary, compiled or not, which is the classic lists' <code>IsBPL</code> and
/// <code>IsDTL</code> answered the other way (AD-62 item 13).</p>
ClassMethod ListClasses(pNamespace As %String, pEndpoint As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tCaught = ""
    Set tStatusSC = $$$OK
    Set tSuper = $Case(pEndpoint, ..#ENDPOINTPROCESSES: "Ens.BusinessProcess", ..#ENDPOINTTRANSFORMS: "Ens.DataTransform", : "Ens.Rule.Definition")
    Set tExcluded = $Case(pEndpoint, ..#ENDPOINTPROCESSES: "Ens.BusinessProcessBPL", ..#ENDPOINTTRANSFORMS: "Ens.DataTransformDTL", : "")
    Kill tFound, tDeclarative
    Set tFound = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If tExcluded '= "" {
            Set tResultSet = ##class(%ResultSet).%New("%Dictionary.ClassDefinition:SubclassOf")
            Set tStatusSC = tResultSet.Execute(tExcluded)
            If $$$ISOK(tStatusSC) {
                While tResultSet.Next() {
                    Set tName = tResultSet.GetData(1)
                    If tName '= "" Set tDeclarative(tName) = ""
                }
                Do tResultSet.Close()
            }
        }
        If $$$ISOK(tStatusSC) {
            Set tResultSet = ##class(%ResultSet).%New("%Dictionary.ClassDefinition:SubclassOf")
            Set tStatusSC = tResultSet.Execute(tSuper)
        }
        If $$$ISOK(tStatusSC) {
            While tResultSet.Next() {
                If (pMax > 0) && (tFound >= pMax) Quit
                Set tName = tResultSet.GetData(1)
                If (tName = "") || (tName = tExcluded) Continue
                Set tModified = ""
                Set tDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(tName)
                If $IsObject(tDefinition) {
                    If tDefinition.TimeChanged '= "" Set tModified = $ZDateTime(tDefinition.TimeChanged, 3)
                }
                Set tDefinition = ""
                Set tFound = tFound + 1
                Set tFound(tFound) = $ListBuild(tName, tModified, '$Data(tDeclarative(tName)))
            }
            Do tResultSet.Close()
        }
        Set tResultSet = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the " _ pEndpoint _ " list failed", .pHttpStatus, .pFault)
    If $$$ISERR(tStatusSC) Quit ..Statused(tStatusSC, "the " _ pEndpoint _ " list failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Set tRow = {}
        Do tRow.%Set("Name", $List(tFound(tI), 1) _ ".cls", "string")
        Do tRow.%Set("Modified", $List(tFound(tI), 2) _ "", "string")
        If tExcluded '= "" Do tRow.%Set("Coded", $List(tFound(tI), 3), "boolean")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Whether class <var>pName</var> (no extension) is a subclass of <var>pBase</var> other than
/// <var>pBase</var> itself in namespace <var>pNamespace</var>'s class dictionary, compiled or not (AD-62
/// item 14): the test <method>ListClasses</method> applies to list a rule, a business process written in BPL
/// or a data transformation written in DTL. It reads the dictionary with
/// <code>%Dictionary.ClassDefinition:SubclassOf</code>, which writes nothing, and calls no
/// <code>OcuPilot.*</code> class while switched (AD-16). This port's gate (<method>Admit</method>) is asked first,
/// as for the list of the kind's code (the rule list for <code>Ens.Rule.Definition</code>, the process list for
/// <code>Ens.BusinessProcessBPL</code>, the transformation list otherwise).</p>
/// <p><var>pRead</var> is 1 only when the dictionary was read. A caller the gate refuses, a namespace that does
/// not report interoperability, an unknown namespace, a namespace of the wrong shape and a dictionary that cannot
/// be read answer 0 with <var>pRead</var> 0, so a caller that refuses on an unread answer fails closed.</p>
/// <p><b>Caller contract:</b> not called from an escalated frame (AD-9). The caller's namespace is restored
/// whatever the outcome.</p>
ClassMethod IsCodeOfKind(pNamespace As %String, pName As %String, pBase As %String, Output pRead As %Boolean) As %Boolean
{
    Set pRead = 0
    Set tKind = 0
    Set tOrigNS = $NAMESPACE
    Try {
        If (pNamespace = "") || (pName = "") || (pBase = "") Quit
        Set tEndpoint = $Case(pBase, "Ens.Rule.Definition": ..#ENDPOINTRULES, "Ens.BusinessProcessBPL": ..#ENDPOINTPROCESSES, : ..#ENDPOINTTRANSFORMS)
        If $$$ISERR(..Admit(tEndpoint, ..#TYPELIST, pNamespace, .tHttp, .tFault)) Quit
        Set $NAMESPACE = pNamespace
        Set tResultSet = ##class(%ResultSet).%New("%Dictionary.ClassDefinition:SubclassOf")
        Set tStatusSC = tResultSet.Execute(pBase)
        Set tFound = 0
        If $$$ISOK(tStatusSC) {
            While tResultSet.Next() {
                If tResultSet.GetData(1) = pName {
                    Set tFound = 1
                    Quit
                }
            }
            Do tResultSet.Close()
        }
        Set tResultSet = ""
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tStatusSC) Quit
        Set pRead = 1
        Set tKind = tFound && (pName '= pBase)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pRead = 0
        Set tKind = 0
    }
    Quit tKind
}

/// <p>The facts one state read gathers, in <var>pFacts</var>: <code>word</code>, the target's state
/// word (the current production's state word when it is the target, else <code>Stopped</code>, as the
/// vendor's own list reads it; a mirror backup's word is kept, and any other unnamed state reads
/// <code>Unknown</code>); <code>current</code>, the namespace's current production, <code>""</code>
/// when none; and <code>needsUpdate</code>, whether the vendor reports an update pending, asked only
/// when the target is current and running.</p>
/// <p>An id absent from <code>Ens.Config.Production</code> (exact) is 404 <code>PORT.NOTFOUND</code>,
/// unlogged. A lock the vendor cannot take is 503 <code>PORT.UNAVAILABLE</code>, for the status read and
/// for the update-pending read alike, since a busy answer is no answer.</p>
ClassMethod ReadState(pNamespace As %String, pId As %String, Output pFacts, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill pFacts
    Set pHttpStatus = 0
    Set pFault = ""
    Set tCaught = ""
    Set tExists = 0
    Set tCurrent = ""
    Set tState = 0
    Set tStatusSC = $$$OK
    Set tNeeds = 0
    Set tNeedsKnown = 1
    Set tWord = "Unknown"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tExists = ''##class(Ens.Config.Production).%ExistsId(pId)
        If tExists {
            Set tStatusSC = ##class(Ens.Director).GetProductionStatus(.tCurrent, .tState, 2)
            If $$$ISOK(tStatusSC) {
                Set tCurrent = $Get(tCurrent)
                If (tCurrent = pId) {
                    Set tTargetState = tState
                } Else {
                    Set tTargetState = $Select(tState < 0: -2, 1: 2)
                }
                Set tWord = ##class(Ens.Config.Production).ProductionStateToText(tTargetState, 0)
                If $Extract(tWord, 1, 13) = "Unrecognized:" Set tWord = "Unknown"
                If (tCurrent = pId) && (tState = 1) {
                    ; The vendor's quick lock gives up after a tenth of a second; a few more tries cost less
                    ; than a read refused as unavailable.
                    For tTry = 1:1:5 {
                        Set tNeeds = ''##class(Ens.Director).ProductionNeedsUpdate(.tReason, 1)
                        If $Get(tReason) '= -1 Quit
                        Hang 0.2
                    }
                    If $Get(tReason) = -1 Set tNeedsKnown = 0
                }
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the production state read failed", .pHttpStatus, .pFault)
    If 'tExists Quit ..Absent(.pHttpStatus, .pFault)
    If $$$ISERR(tStatusSC) Quit ..Statused(tStatusSC, "the production state read failed", .pHttpStatus, .pFault)
    If 'tNeedsKnown Quit ..Unavailable(.pHttpStatus, .pFault)
    Set pFacts("word") = tWord
    Set pFacts("current") = tCurrent
    Set pFacts("needsUpdate") = tNeeds
    Quit $$$OK
}

/// <p>The answer a state read or a write gives: <code>{Name, Namespace, State, Current,
/// NeedsUpdate}</code> from <var>pFacts</var>.</p>
ClassMethod StateRow(pNamespace As %String, pId As %String, ByRef pFacts) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Name", pId, "string")
    Do tRow.%Set("Namespace", pNamespace, "string")
    Do tRow.%Set("State", pFacts("word"), "string")
    Do tRow.%Set("Current", pFacts("current"), "string")
    Do tRow.%Set("NeedsUpdate", ''pFacts("needsUpdate"), "boolean")
    Quit tRow
}

/// <p>Run write <var>pType</var> against production <var>pId</var> in <var>pNamespace</var> and answer
/// the state it leaves. Stop, restart and update pass the production's own timeout capped at
/// <method>StopSeconds</method>. The vendor writes nothing to the current device (measured: no line on
/// a capture around each call, Story 20.2's Task 0), and no capture is opened here, because a capture
/// refuses to open inside another. Clean is never called.</p>
ClassMethod Perform(pNamespace As %String, pType As %String, pId As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tCaught = ""
    Set tVendorSC = $$$OK
    Set tCap = ..StopSeconds()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If pType = ..#TYPESTART {
            Set tVendorSC = ##class(Ens.Director).StartProduction(pId)
        } ElseIf pType = ..#TYPERECOVER {
            Set tVendorSC = ##class(Ens.Director).RecoverProduction()
        } ElseIf pType = ..#TYPEUPDATE {
            Set tTimeout = ##class(Ens.Director).GetRunningProductionUpdateTimeout()
            If tTimeout > tCap Set tTimeout = tCap
            Set tVendorSC = ##class(Ens.Director).UpdateProduction(tTimeout, 0)
        } Else {
            Set tTimeout = ##class(Ens.Director).GetRunningProductionShutdownTimeout()
            If tTimeout > tCap Set tTimeout = tCap
            If pType = ..#TYPESTOP {
                Set tVendorSC = ##class(Ens.Director).StopProduction(tTimeout, 0)
            } Else {
                Set tVendorSC = ##class(Ens.Director).RestartProduction(tTimeout, 0)
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the production " _ pType _ " failed", .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the production " _ pType _ " failed", .pHttpStatus, .pFault)
    Set tReadSC = ..ReadState(pNamespace, pId, .tFacts, .pHttpStatus, .pFault)
    If $$$ISERR(tReadSC) Quit tReadSC
    Set pResult = ..StateRow(pNamespace, pId, .tFacts)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The resource guarding <var>pNamespace</var>'s routines database, which an item write also needs
/// WRITE on, as <method>OcuPilot.Kernel.Shell.Namespaces.RoutineDatabase</method> reports it; 0 when the
/// instance reports none. Overridable so a fixture can name another resource, because in a namespace whose
/// routines and globals share a database no principal can hold one without the other; production never
/// overrides it.</p>
ClassMethod RoutineResource(pNamespace As %String, Output pResource As %String) As %Boolean
{
    Quit ##class(OcuPilot.Kernel.Shell.Namespaces).RoutineDatabase(pNamespace, .pResource, .tReadOnly)
}

/// <p>Whether <var>pNamespace</var> is under source control, which refuses every item write. Overridable
/// so a fixture can answer 1; production never overrides it.</p>
ClassMethod SourceControlled(pNamespace As %String) As %Boolean
{
    Quit ''##class(%CSP.Portal.SourceControl.Util).IsEnabled(pNamespace)
}

/// <p>Serve the Items endpoint (Stories 20.3 and 20.25) after <method>Invoke</method>'s gate. A <code>LIST</code> names
/// its production under <parameter>PRODUCTIONKEY</parameter>; every other type names an item by the
/// composite id <code>[Production, Name]</code> under <parameter>IDKEY</parameter>, never by the vendor's
/// integer id, which a recompile renumbers. <code>ITEMRUN</code> and the three runtime writes
/// (<method>IsItemRunWrite</method>) go to <method>ReadItemRun</method> and <method>PerformItemRun</method>.</p>
ClassMethod InvokeItems(pNamespace As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType = ..#TYPELIST {
            Set tProduction = $Get(pQuery(..#PRODUCTIONKEY))
            If tProduction = "" {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONIDREQUIRED, .pHttpStatus, .pFault)
                Quit
            }
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..ListItems(pNamespace, tProduction, +tMaxText, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite($Get(pQuery(..#IDKEY)))
        If ($ListLength(tParts) '= 2) || ($List(tParts, 1) = "") || ($List(tParts, 2) = "") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONITEMIDREQUIRED, .pHttpStatus, .pFault)
            Quit
        }
        Set tProduction = $List(tParts, 1)
        Set tName = $List(tParts, 2)
        If (pType = ..#TYPEITEMRUN) || ..IsItemRunWrite(pType) {
            Set tAction = $Select(..IsItemRunWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
            If (tAction '= "") && '..IsItemRunWrite(tAction) {
                Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
                Quit
            }
            If ..IsItemRunWrite(pType) {
                Set tSC = ..PerformItemRun(pNamespace, pType, tProduction, tName, .pResult, .pHttpStatus, .pFault)
            } Else {
                Set tSC = ..ReadItemRun(pNamespace, tProduction, tName, tAction, .pResult, .pHttpStatus, .pFault)
            }
            Quit
        }
        Set tAction = $Select(..IsItemWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && '..IsItemWrite(tAction) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tNewClass = $Get(pQuery(..#NEWCLASSKEY))
        Set tReviewed = $Get(pQuery(..#DIGESTKEY))
        If ..IsItemWrite(pType) {
            Set tSC = ..PerformItem(pNamespace, pType, tProduction, tName, pBody, .pResult, .pHttpStatus, .pFault, "", "", tNewClass, tReviewed)
            Quit
        }
        Set tSC = ..ReadItem(pNamespace, tProduction, tName, tAction, .pResult, .pHttpStatus, .pFault, ($Data(pQuery(..#NEWCLASSKEY)) # 2), tNewClass, tReviewed)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the item call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether <var>pName</var> breaks the item name rule, as <code>OcuPilot.Api.InteropError.ITEMNAME</code>,
/// else <code>""</code> (Story 20.3). It mirrors <code>Ens.Config.Item.CheckForIllegalCharacters</code>, which
/// the vendor runs at <code>%Save</code>: none of <code>| ; , [</code>, not beginning with <code>-</code> or
/// <code>_</code>, not ending with <code>-</code>, <code>!</code> or <code>$</code>, and not <code>*</code>.
/// It adds the 128-character limit and refuses a control character and a space at either end. Pure, so it
/// runs before the namespace is switched.</p>
ClassMethod NameProblem(pName As %String) As %String
{
    Set tProblem = ##class(OcuPilot.Api.InteropError).#ITEMNAME
    If (pName = "") || ($Length(pName) > 128) Quit tProblem
    If $ZStrip(pName, "<>", " ") '= pName Quit tProblem
    If $ZStrip(pName, "*C") '= pName Quit tProblem
    If (pName [ "|") || (pName [ ";") || (pName [ ",") || (pName [ "[") Quit tProblem
    If $Extract(pName) = "-" Quit tProblem
    If $Extract(pName) = "_" Quit tProblem
    If ($Extract(pName, *) = "-") || ($Extract(pName, *) = "!") || ($Extract(pName, *) = "$") Quit tProblem
    If pName = "*" Quit tProblem
    Quit ""
}

/// <p>Every rule over an add's fields, in <var>pViolations</var> as <code>pViolations(n) =
/// $ListBuild(field, code)</code> with the count in <code>pViolations</code> (Story 20.3): the name
/// (<method>NameProblem</method>); <code>ClassName</code> must be a class of <var>pNamespace</var> that
/// <code>Ens.Config.Item</code> types as a business service, process or operation; <code>PoolSize</code>,
/// <code>Category</code> and <code>Comment</code> must be what <code>Ens.Config.Item</code>'s own
/// <code>&lt;Prop&gt;IsValid</code> accepts; <code>Enabled</code> must be a boolean. A field of the wrong
/// JSON type is <code>PORT.FIELD.SHAPE</code>. The vendor classes run in <var>pNamespace</var>, switched
/// by explicit save and restore, and only once this port's gate admits an add there (<method>Admit</method>);
/// when it does not, only the rules that need no vendor class are judged, and the caller's next
/// <method>Invoke</method> answers the gate's refusal.</p>
ClassMethod AddViolations(pNamespace As %String, pName As %String, pBody As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tAdmitted = $$$ISOK(..Admit(..#ENDPOINTITEMS, ..#TYPEADD, pNamespace, .tHttp, .tFault))
    Try {
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Set pBody = {}
        If ..NameProblem(pName) '= "" Set pViolations($Increment(pViolations)) = $ListBuild("Name", ##class(OcuPilot.Api.InteropError).#ITEMNAME)
        Set tShape = ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE
        Set tCodeClass = ##class(OcuPilot.Api.InteropError).#ITEMCLASS
        Set tCodeValue = ##class(OcuPilot.Api.InteropError).#ITEMVALUE
        Set tClassType = pBody.%GetTypeOf("ClassName")
        Set tClass = ""
        If tClassType = "string" Set tClass = pBody.%Get("ClassName")
        Set tClassOk = 0
        If (tClassType '= "string") && (tClassType '= "unassigned") {
            Set pViolations($Increment(pViolations)) = $ListBuild("ClassName", tShape)
        } ElseIf '$Match(tClass, "^[A-Za-z%][A-Za-z0-9%._]*$") || ($Length(tClass) > 128) {
            Set pViolations($Increment(pViolations)) = $ListBuild("ClassName", tCodeClass)
        } Else {
            Set tClassOk = 1
        }
        Set tPoolType = pBody.%GetTypeOf("PoolSize")
        Set tCategoryType = pBody.%GetTypeOf("Category")
        Set tCommentType = pBody.%GetTypeOf("Comment")
        Set tEnabledType = pBody.%GetTypeOf("Enabled")
        If (tPoolType '= "unassigned") && (tPoolType '= "number") Set pViolations($Increment(pViolations)) = $ListBuild("PoolSize", tShape)
        If (tCategoryType '= "unassigned") && (tCategoryType '= "string") Set pViolations($Increment(pViolations)) = $ListBuild("Category", tShape)
        If (tCommentType '= "unassigned") && (tCommentType '= "string") Set pViolations($Increment(pViolations)) = $ListBuild("Comment", tShape)
        If (tEnabledType '= "unassigned") && (tEnabledType '= "boolean") Set pViolations($Increment(pViolations)) = $ListBuild("Enabled", tShape)
        If 'tAdmitted Quit
        Set $NAMESPACE = pNamespace
        If tClassOk {
            Set tItem = ##class(Ens.Config.Item).%New(tClass)
            Set tBusinessType = tItem.BusinessType()
            Set tItem = ""
            If (tBusinessType '= 1) && (tBusinessType '= 2) && (tBusinessType '= 3) Set pViolations($Increment(pViolations)) = $ListBuild("ClassName", tCodeClass)
        }
        If (tPoolType = "number") && '##class(Ens.Config.Item).PoolSizeIsValid(pBody.%Get("PoolSize")) Set pViolations($Increment(pViolations)) = $ListBuild("PoolSize", tCodeValue)
        If (tCategoryType = "string") && '##class(Ens.Config.Item).CategoryIsValid(pBody.%Get("Category")) Set pViolations($Increment(pViolations)) = $ListBuild("Category", tCodeValue)
        If (tCommentType = "string") && '##class(Ens.Config.Item).CommentIsValid(pBody.%Get("Comment")) Set pViolations($Increment(pViolations)) = $ListBuild("Comment", tCodeValue)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every rule over a copy's fields, in <var>pViolations</var> as <method>AddViolations</method> answers them (Story 20.40):
/// the new name (<method>NameProblem</method>); then <code>CopyFrom</code>, which must be a string
/// (<code>PORT.FIELD.SHAPE</code> otherwise) and not empty (<code>COPYSOURCE</code>); then, once this port's gate admits a
/// copy in <var>pNamespace</var> and the namespace is not under source control, the number of items of the
/// production <var>pProduction</var> named <code>CopyFrom</code> without regard to case: none is
/// <code>COPYSOURCE</code> and more than one is <code>AMBIGUOUS</code>. A production the namespace does not hold is left to
/// the write's own 404.</p>
ClassMethod CopyViolations(pNamespace As %String, pProduction As %String, pName As %String, pBody As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set tAdmitted = $$$ISOK(..Admit(..#ENDPOINTITEMS, ..#TYPECOPY, pNamespace, .tHttp, .tFault))
    Try {
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Set pBody = {}
        If ..NameProblem(pName) '= "" Set pViolations($Increment(pViolations)) = $ListBuild("Name", ##class(OcuPilot.Api.InteropError).#ITEMNAME)
        Set tType = pBody.%GetTypeOf("CopyFrom")
        Set tFrom = ""
        If tType = "string" Set tFrom = pBody.%Get("CopyFrom")
        If (tType '= "string") && (tType '= "unassigned") {
            Set pViolations($Increment(pViolations)) = $ListBuild("CopyFrom", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        } ElseIf tFrom = "" {
            Set pViolations($Increment(pViolations)) = $ListBuild("CopyFrom", ##class(OcuPilot.Api.InteropError).#ITEMCOPYSOURCE)
        } ElseIf tAdmitted && '..SourceControlled(pNamespace) {
            Set tReadSC = ..GatherItems(pNamespace, pProduction, tFrom, 0, .tExists, .tFound, .tCount, .tCaught)
            If $IsObject(tCaught) Throw tCaught
            If tExists && (tCount = 0) Set pViolations($Increment(pViolations)) = $ListBuild("CopyFrom", ##class(OcuPilot.Api.InteropError).#ITEMCOPYSOURCE)
            If tExists && (tCount > 1) Set pViolations($Increment(pViolations)) = $ListBuild("CopyFrom", ##class(OcuPilot.Api.InteropError).#ITEMAMBIGUOUS)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether <var>pClass</var> has the shape of a class name an item's class may take: a letter or <code>%</code>, then letters,
/// digits, <code>%</code>, dots and underscores, at most 128 characters (Story 20.41). Pure.</p>
ClassMethod NewClassShape(pClass As %String) As %Boolean
{
    Quit $Match(pClass, "^[A-Za-z%][A-Za-z0-9%._]*$") && ($Length(pClass) <= 128)
}

/// <p>The classes an item of business type <var>pType</var> can change to, in <var>pFound</var> as <code>pFound(class) = kind</code>,
/// <code>kind</code> 1, 2 or 3 for a service, a process or an operation (Story 20.41): the compiled, non-abstract subclasses of
/// <code>Ens.BusinessService</code>, <code>Ens.BusinessProcess</code> or <code>Ens.BusinessOperation</code>, which are the lists
/// <code>Ens.ContextSearch</code> gives the classic Change Class dialog. A <var>pType</var> that is none of the three
/// (<code>Ens.Config.Item:GetBusinessType</code> answers another value for a class it does not know) lists all three. It reads
/// <code>%Dictionary.ClassDefinition:SubclassOf</code> and <code>%Dictionary.CompiledClass</code> and writes nothing. Called while
/// the production's namespace is switched; only vendor classes run.</p>
ClassMethod CandidateClasses(pType As %Integer, ByRef pFound) [ Private ]
{
    Kill pFound
    For tKind = 1, 2, 3 {
        If (pType = 1) || (pType = 2) || (pType = 3) {
            If tKind '= pType Continue
        }
        Set tSuper = $Case(tKind, 1: "Ens.BusinessService", 2: "Ens.BusinessProcess", : "Ens.BusinessOperation")
        Set tResult = ##class(%ResultSet).%New("%Dictionary.ClassDefinition:SubclassOf")
        Set tStatus = tResult.Execute(tSuper)
        If $$$ISERR(tStatus) Throw ##class(%Exception.StatusException).CreateFromStatus(tStatus)
        While tResult.Next() {
            Set tName = tResult.GetData(1)
            If (tName = "") || $Data(pFound(tName)) Continue
            Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(tName)
            If '$IsObject(tCompiled) Continue
            Set tAbstract = tCompiled.Abstract
            Set tCompiled = ""
            If tAbstract Continue
            Set pFound(tName) = tKind
        }
        Do tResult.Close()
        Set tResult = ""
    }
}

/// <p>The settings of the item <var>pItem</var> that a change to the class <var>pNewClass</var> removes, in <var>pDropped</var> as
/// <code>pDropped(n) = $ListBuild(Target, Name, Value)</code> with the count in <var>pDropped</var>, and each one's position in the
/// item's settings in <var>pPositions</var> (Story 20.41). It is the rule of the classic Change Class action
/// (<code>EnsPortal.ProductionConfig:HostChangeClass</code>), applied over the stored settings: a Host setting is removed unless
/// <var>pNewClass</var> declares it in <code>GetSettings</code> and its <code>&lt;Name&gt;IsValid</code> accepts the stored value;
/// an Adapter setting is judged the same way against the adapter class <var>pNewClass</var> names; a setting of any other target is
/// removed; and a setting whose <code>IsValid</code> raises is removed. <var>pItem</var> is an <code>Ens.Config.Item</code>, typed
/// <code>%RegisteredObject</code> so the class compiles where interoperability is not enabled (AD-62 item 12); it is not changed.
/// Called while the production's namespace is switched; only vendor classes run.</p>
ClassMethod DroppedSettings(pItem As %RegisteredObject, pNewClass As %String, Output pDropped, Output pPositions) [ Private ]
{
    Kill pDropped, pPositions
    Set pDropped = 0
    Kill tClassSettings, tAdapterSettings
    Set tTransient = ##class(Ens.Config.Item).%New(pNewClass)
    Set tAdapter = tTransient.AdapterClassName()
    Set tTransient = ""
    Do $ClassMethod(pNewClass, "GetSettings", .tClassSettings)
    Try {
        If tAdapter '= "" Do $ClassMethod(tAdapter, "GetSettings", .tAdapterSettings)
    } Catch {
    }
    Set tSettings = pItem.Settings
    For tI = 1:1:tSettings.Count() {
        Set tSetting = tSettings.GetAt(tI)
        Set tTarget = tSetting.Target
        Set tName = tSetting.Name
        Set tValue = tSetting.Value
        Set tRemove = 1
        Try {
            If tTarget = "Host" {
                Set tStatus = $ClassMethod(pNewClass, tName _ "IsValid", tValue)
                Set tRemove = $Select($$$ISERR(tStatus): 1, 1: '$Data(tClassSettings(":", tName)))
            } ElseIf tTarget = "Adapter" {
                Set tStatus = $ClassMethod(tAdapter, tName _ "IsValid", tValue)
                Set tRemove = $Select($$$ISERR(tStatus): 1, 1: '$Data(tAdapterSettings(":", tName)))
            }
        } Catch {
            Set tRemove = 1
        }
        If tRemove {
            Set pDropped($Increment(pDropped)) = $ListBuild(tTarget, tName, tValue)
            Set pPositions(pDropped) = tI
        }
    }
    Set tSettings = ""
    Set tSetting = ""
}

/// <p>Judge the change of the item <var>pItem</var> to the class <var>pNewClass</var> (Story 20.41): <var>pRefusal</var> is
/// <code>SAMECLASS</code> when it already has that class, else <code>NEWCLASS</code> when the class is not one of
/// <method>CandidateClasses</method> for the item's kind, else <code>""</code> and <var>pDropped</var> and <var>pPositions</var> are
/// <method>DroppedSettings</method>'s. <var>pOld</var> is the item's class. Called while the production's namespace is switched; only
/// vendor classes run.</p>
ClassMethod JudgeChange(pItem As %RegisteredObject, pNewClass As %String, Output pRefusal As %String, Output pOld As %String, Output pDropped, Output pPositions) [ Private ]
{
    Kill pDropped, pPositions
    Set pDropped = 0
    Set pRefusal = ""
    Set pOld = pItem.ClassName
    If pOld = pNewClass {
        Set pRefusal = "SAMECLASS"
        Quit
    }
    Do ..CandidateClasses(##class(Ens.Config.Item).GetBusinessType(pOld, pItem), .tCandidates)
    If '$Data(tCandidates(pNewClass)) {
        Set pRefusal = "NEWCLASS"
        Quit
    }
    Do ..DroppedSettings(pItem, pNewClass, .pDropped, .pPositions)
}

/// <p>The SHA-256 over the change of the item <var>pItem</var> of <var>pProduction</var> from <var>pOld</var> to <var>pNew</var> and
/// the settings <var>pDropped</var> it removes (Story 20.41): the target and name of each, and its value unless the name is a
/// credential's (<method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method>), whose value takes no part. It names an
/// <code>OcuPilot.*</code> class, so it is called after the namespace is restored.</p>
ClassMethod ChangeDigest(pProduction As %String, pItem As %String, pOld As %String, pNew As %String, ByRef pDropped) As %String
{
    Set tList = $ListBuild(pProduction, pItem, pOld, pNew)
    For tI = 1:1:+$Get(pDropped) {
        Set tSecret = ''##class(OcuPilot.Kernel.Audit.Log).IsCredentialName($List(pDropped(tI), 2))
        Set tList = tList _ $ListBuild($List(pDropped(tI), 1), $List(pDropped(tI), 2), $Select(tSecret: "", 1: $List(pDropped(tI), 3)), tSecret)
    }
    Quit ..Sha256Hex(tList)
}

/// <p>The item row <var>pRow</var> of the item <var>pName</var>, composed for the change to the class <var>pNewClass</var> (Story
/// 20.41): it also carries <code>NewClass</code>, <code>Dropped</code>, <code>Reviewed</code> and <code>Digest</code>
/// (<method>ChangeDigest</method>). A class the shape rule refuses, one the item's Classes tab does not list and one the item
/// already has are 409 <code>INTEROP.ITEM.NEWCLASS</code> and <code>INTEROP.ITEM.SAMECLASS</code>, before any setting is judged.
/// Composed for the action <var>pAction</var> (the change itself), a <var>pReviewed</var> that is not the digest of the settings
/// as they stand is 409 <code>INTEROP.ITEM.REVIEWCHANGED</code>, and <code>Reviewed</code> answers <var>pReviewed</var>; a read
/// composed for no action, such as the agent's confirm re-read, which carries the digest its proposal was read at, answers
/// <code>Reviewed</code> empty, as its mint did.</p>
ClassMethod ComposeChange(pNamespace As %String, pProduction As %String, pName As %String, pAction As %String, pNewClass As %String, pReviewed As %String, ByRef pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    If '..NewClassShape(pNewClass) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMNEWCLASS, .pHttpStatus, .pFault)
    Set tCaught = ""
    Set tRefusal = ""
    Set tOld = ""
    Set tAbsent = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tProduction = ##class(Ens.Config.Production).%OpenId(pProduction)
        Set tItem = $Select($IsObject(tProduction): ..ItemObject(tProduction, pName), 1: "")
        If '$IsObject(tItem) {
            Set tAbsent = 1
        } Else {
            Do ..JudgeChange(tItem, pNewClass, .tRefusal, .tOld, .tDropped, .tPositions)
        }
        Set tItem = ""
        Set tProduction = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the change of class could not be judged", .pHttpStatus, .pFault)
    If tAbsent Quit ..Absent(.pHttpStatus, .pFault)
    If tRefusal '= "" Quit ..Conflict(..ItemCode(tRefusal), .pHttpStatus, .pFault)
    Set tDigest = ..ChangeDigest(pProduction, pName, tOld, pNewClass, .tDropped)
    If (pAction = ..#TYPECHANGECLASS) && (pReviewed '= "") && (pReviewed '= tDigest) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMREVIEWCHANGED, .pHttpStatus, .pFault)
    Set tRows = []
    For tI = 1:1:+$Get(tDropped) {
        Set tSecret = ''##class(OcuPilot.Kernel.Audit.Log).IsCredentialName($List(tDropped(tI), 2))
        Set tDroppedRow = {}
        Do tDroppedRow.%Set("Target", $List(tDropped(tI), 1) _ "", "string")
        Do tDroppedRow.%Set("Name", $List(tDropped(tI), 2) _ "", "string")
        Do tDroppedRow.%Set("Value", $Select(tSecret: "", 1: $List(tDropped(tI), 3) _ ""), "string")
        Do tDroppedRow.%Set("Secret", tSecret, "boolean")
        Do tRows.%Push(tDroppedRow)
    }
    Do pRow.%Set("NewClass", pNewClass, "string")
    Do pRow.%Set("Dropped", tRows)
    Do pRow.%Set("Reviewed", $Select(pAction '= "": pReviewed, 1: ""), "string")
    Do pRow.%Set("Digest", tDigest, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The change of class itself, in the current namespace, which must be <var>pNamespace</var>, against the production
/// <var>pLocked</var>, which <method>PerformItem</method> holds at concurrency 4 (Story 20.41). In <var>pStep</var>: <code>absent</code>,
/// <code>refusal</code> (a token <method>ItemCode</method> names), <code>vendor</code>, <code>audit</code> and <code>save</code>
/// statuses, and <code>after</code> and <code>afterCount</code>, the item as it reads once changed. In this order, under the lock: the item is
/// gathered (absent, or held more than once), the class and the dropped settings are judged again (<method>JudgeChange</method>),
/// the digest is taken (<method>ChangeDigest</method>, with the install namespace current) and a <var>pReviewed</var> other than
/// it is <code>REVIEWCHANGED</code>, before anything is written; then the class is set, the dropped settings removed, the item saved,
/// <code>Ens.Util.Auditing</code>'s <code>ModifyConfiguration</code> recorded naming the old and the new class and each dropped
/// setting's target and name, never a value, and the production class saved.</p>
ClassMethod ChangeStep(pNamespace As %String, pProduction As %String, pName As %String, pNewClass As %String, pReviewed As %String, pOrigNS As %String, pLocked As %RegisteredObject, Output pStep) [ Private ]
{
    Kill pStep
    Set pStep("absent") = 0
    Set pStep("refusal") = ""
    Set pStep("vendor") = $$$OK
    Set pStep("audit") = $$$OK
    Set pStep("save") = $$$OK
    Set pStep("after") = ""
    Set pStep("afterCount") = 0
    Set tGatherSC = ..GatherItems(pNamespace, pProduction, pName, 0, .tExists, .tFound, .tCount, .tGatherCaught)
    If $IsObject(tGatherCaught) Throw tGatherCaught
    If tCount = 0 {
        Set pStep("absent") = 1
        Quit
    }
    If tCount > 1 {
        Set pStep("refusal") = "AMBIGUOUS"
        Quit
    }
    Set tItemName = $List(tFound(1), 1)
    Set tItem = ..ItemObject(pLocked, tItemName)
    If '$IsObject(tItem) {
        Set pStep("absent") = 1
        Quit
    }
    Do ..JudgeChange(tItem, pNewClass, .tRefusal, .tOld, .tDropped, .tPositions)
    If tRefusal '= "" {
        Set pStep("refusal") = tRefusal
        Quit
    }
    Set $NAMESPACE = pOrigNS
    Set tDigest = ..ChangeDigest(pProduction, tItemName, tOld, pNewClass, .tDropped)
    Set $NAMESPACE = pNamespace
    If (pReviewed '= "") && (pReviewed '= tDigest) {
        Set pStep("refusal") = "REVIEWCHANGED"
        Quit
    }
    Set tItem.ClassName = pNewClass
    For tI = tDropped:-1:1 {
        Do tItem.Settings.RemoveAt(tPositions(tI))
    }
    Set pStep("vendor") = tItem.%Save()
    If $$$ISOK(pStep("vendor")) {
        Set tActions = "item class changed by OcuPilot from " _ tOld _ " to " _ pNewClass
        For tI = 1:1:tDropped {
            Set tActions($List(tDropped(tI), 1) _ "." _ $List(tDropped(tI), 2)) = ""
        }
        Set pStep("audit") = ##class(Ens.Util.Auditing).AuditModifyProductionConfig(pProduction, tItemName, .tActions)
        Set pStep("save") = pLocked.SaveToClass(tItem)
        Set tItem = ""
        Set tAfterSC = ..GatherItems(pNamespace, pProduction, tItemName, 0, .tAfterExists, .tAfterFound, .tAfterCount, .tAfterCaught)
        If $IsObject(tAfterCaught) Throw tAfterCaught
        If tAfterCount > 0 Set pStep("after") = tAfterFound(1)
        Set pStep("afterCount") = tAfterCount
    }
    Set tItem = ""
}

/// <p>Serve the ItemClasses endpoint (Story 20.41) after <method>Invoke</method>'s gate: a <code>LIST</code> for the item
/// <parameter>ITEMKEY</parameter> names, as the composite <code>[Production, Name]</code> or the vendor's
/// <code>Production||Name</code>.</p>
ClassMethod InvokeItemClasses(pNamespace As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If '..ItemParts($Get(pQuery(..#ITEMKEY)), .tProduction, .tItem) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONITEMIDREQUIRED, .pHttpStatus, .pFault)
            Quit
        }
        Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
        If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..ListItemClasses(pNamespace, tProduction, tItem, +tMaxText, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the item classes call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The classes the item <var>pItem</var> of <var>pProduction</var> can change to, one row for each, at most <var>pMax</var> when
/// it is above zero: <code>{Production, Item, ClassName, Type, Current}</code>, services then processes then operations, each in
/// class-name order, <code>Current</code> true for the item's own class (Story 20.41). An item the production does not hold is 404
/// <code>PORT.NOTFOUND</code>, unlogged, and a name it holds more than once is <code>INTEROP.ITEM.AMBIGUOUS</code>, both before
/// any class is read. The classes are <method>CandidateClasses</method>'s for the item's kind, or all three kinds' for an item whose
/// class reads as no business host.</p>
ClassMethod ListItemClasses(pNamespace As %String, pProduction As %String, pItem As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..GatherItems(pNamespace, pProduction, pItem, 0, .tExists, .tFound, .tCount, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item classes list failed", .pHttpStatus, .pFault)
    If 'tExists || (tCount = 0) Quit ..Absent(.pHttpStatus, .pFault)
    If tCount > 1 Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMAMBIGUOUS, .pHttpStatus, .pFault)
    Set tLine = tFound(1)
    Set tCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..CandidateClasses(+$List(tLine, 3), .tCandidates)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item classes list failed", .pHttpStatus, .pFault)
    Set tName = ""
    For {
        Set tName = $Order(tCandidates(tName), 1, tKind)
        If tName = "" Quit
        Set tSorted(tKind, tName) = ""
    }
    Set pRows = []
    Set tRowCount = 0
    For tKind = 1, 2, 3 {
        Set tName = ""
        For {
            Set tName = $Order(tSorted(tKind, tName))
            If tName = "" Quit
            If (pMax > 0) && (tRowCount >= pMax) Quit
            Set tRowCount = tRowCount + 1
            Set tRow = {}
            Do tRow.%Set("Production", pProduction, "string")
            Do tRow.%Set("Item", $List(tLine, 1) _ "", "string")
            Do tRow.%Set("ClassName", tName, "string")
            Do tRow.%Set("Type", $Case(tKind, 1: "service", 2: "process", : "operation"), "string")
            Do tRow.%Set("Current", (tName = $List(tLine, 2)), "boolean")
            Do pRows.%Push(tRow)
        }
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Whether <var>pNamespace</var> holds the production <var>pProduction</var>. A namespace this port's gate
/// does not admit an item read in (<method>Admit</method>), and a fault in the look-up, answer 1 without a
/// vendor call, so the write's own refusal decides rather than this one.</p>
ClassMethod ProductionHeld(pNamespace As %String, pProduction As %String) As %Boolean
{
    If $$$ISERR(..Admit(..#ENDPOINTITEMS, ..#TYPEITEM, pNamespace, .tHttp, .tFault)) Quit 1
    Set tSC = ..GatherItems(pNamespace, pProduction, "", 1, .tExists, .tFound, .tCount, .tCaught)
    Quit $IsObject(tCaught) || tExists
}

/// <p>The 422 refusal an add's <var>pViolations</var> earn (AD-39): the envelope carries the first
/// violation's code and sentence and <code>detail.violations</code> every one.</p>
ClassMethod Violations(ByRef pViolations, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {"violations": []}
    For tI = 1:1:pViolations {
        Set tCode = $List(pViolations(tI), 2)
        Do tDetail.%Get("violations").%Push({"field": ($List(pViolations(tI), 1)), "code": (tCode), "reason": (##class(OcuPilot.Api.Error).ReasonForViolation(tCode))})
    }
    Set tFirst = $List(pViolations(1), 2)
    Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, tFirst, ##class(OcuPilot.Api.Error).ReasonForViolation(tFirst), .pHttpStatus, .pFault, tDetail)
}

/// <p>The item code an item write <var>pType</var> is refused with, or <code>""</code> when it may go
/// ahead (Story 20.3): whatever the vendor would store twice, answer as a silent success, or change in the
/// wrong place is refused here by its own name. <var>pCount</var> is how many items of the name the
/// production holds (without regard to case), <var>pEnabled</var> the first one's effective
/// <code>Enabled</code>, <var>pSource</var> <code>default</code> when a system default supplies it,
/// <var>pBusinessType</var> its host type code and <var>pPoolSize</var> its pool size. Pure.</p>
/// <ul>
/// <li>Add and copy: <code>TAKEN</code> when the name is held.</li>
/// <li>Any other write: <code>AMBIGUOUS</code> when more than one item holds the name.</li>
/// <li>Enable: <code>ENABLED</code> when it is, else <code>DEFAULTSETTING</code> when a system default
/// supplies <code>Enabled</code>.</li>
/// <li>Disable: <code>DISABLED</code> when it is, then <code>DEFAULTSETTING</code>, then
/// <code>POOLZERO</code> for a business process whose pool size is 0.</li>
/// <li>Remove: <code>DEFAULTSETTING</code> while a system default keeps it enabled, else
/// <code>ENABLEDREMOVE</code> while it is enabled.</li>
/// </ul>
ClassMethod ItemRefusal(pType As %String, pCount As %Integer, pEnabled As %Boolean, pSource As %String, pBusinessType As %Integer, pPoolSize As %String) As %String
{
    Quit ..ItemCode(..ItemRefusalToken(pType, pCount, pEnabled, pSource, pBusinessType, pPoolSize))
}

/// <p><method>ItemRefusal</method>'s decision as the last segment of the code (<code>ENABLED</code>,
/// <code>TAKEN</code> and so on), <code>""</code> for none. It names no other class, so it runs while the
/// production's namespace is switched, where a reference to another OcuPilot class does not resolve.</p>
ClassMethod ItemRefusalToken(pType As %String, pCount As %Integer, pEnabled As %Boolean, pSource As %String, pBusinessType As %Integer, pPoolSize As %String) As %String
{
    If (pType = ..#TYPEADD) || (pType = ..#TYPECOPY) {
        If pCount > 0 Quit "TAKEN"
        Quit ""
    }
    If pCount > 1 Quit "AMBIGUOUS"
    If pType = ..#TYPEENABLE {
        If pEnabled Quit "ENABLED"
        If pSource = "default" Quit "DEFAULTSETTING"
        Quit ""
    }
    If pType = ..#TYPEDISABLE {
        If 'pEnabled Quit "DISABLED"
        If pSource = "default" Quit "DEFAULTSETTING"
        If (pBusinessType = 2) && (pPoolSize = 0) Quit "POOLZERO"
        Quit ""
    }
    If pType = ..#TYPEREMOVE {
        If pEnabled && (pSource = "default") Quit "DEFAULTSETTING"
        If pEnabled Quit "ENABLEDREMOVE"
        Quit ""
    }
    Quit ""
}

/// <p>Whether an enable or a disable (<var>pType</var>) of the one item <var>pLine</var>
/// (<method>GatherItems</method>'s element, <var>pCount</var> items of the name) would not find it:
/// <code>Ens.Director:EnableConfigItem</code> skips an item whose class it types as no business host and
/// answers <code>ErrConfigItemNotFound</code>, so such an item reads absent to an enable and a disable, as it
/// does to the vendor. It names no other class, so it runs while the production's namespace is switched.</p>
ClassMethod VendorCannotFind(pType As %String, pCount As %Integer, pLine As %List) As %Boolean
{
    If (pType '= ..#TYPEENABLE) && (pType '= ..#TYPEDISABLE) Quit 0
    If (pCount '= 1) || (pLine = "") Quit 0
    Quit (+$List(pLine, 3) = 0)
}

/// <p>The code <var>pToken</var> names: <code>INTEROP.ITEM.</code> and the token; <code>""</code> for no
/// token.</p>
ClassMethod ItemCode(pToken As %String) As %String
{
    If pToken = "" Quit ""
    Quit ..#ITEMCODEPREFIX _ pToken
}

/// <p>The token (<code>NOTRUNNING</code>, <code>AMBIGUOUS</code>, <code>NOTENABLED</code>, <code>TEMPSTOPPED</code>,
/// <code>NOTTEMPSTOPPED</code> or <code>NOJOBS</code>) naming why the item runtime action <var>pType</var>
/// (<method>IsItemRunWrite</method>) is refused, <code>""</code> for none (Story 20.25), judged in this order. <var>pCount</var> is
/// the number of items of the name, <var>pRunning</var> whether the item's production is the namespace's running one,
/// <var>pEnabled</var> the item's effective <code>Enabled</code>, <var>pTempStopped</var> whether the vendor's temporary-stop flag
/// is set and <var>pOwnJobs</var> whether the item runs jobs of its own. Each is a case the vendor answers as a silent success
/// or with an error status. Pure, and it names no other class.</p>
/// <ul>
/// <li>Any action: <code>NOTRUNNING</code>, <code>AMBIGUOUS</code>, <code>NOTENABLED</code>.</li>
/// <li>Stop and restart: <code>TEMPSTOPPED</code> when the flag is set, then <code>NOJOBS</code> when the item runs no jobs of its own.</li>
/// <li>Start: <code>NOTTEMPSTOPPED</code> when the flag is not set.</li>
/// </ul>
ClassMethod ItemRunRefusal(pType As %String, pCount As %Integer, pRunning As %Boolean, pEnabled As %Boolean, pTempStopped As %Boolean, pOwnJobs As %Boolean) As %String
{
    If 'pRunning Quit "NOTRUNNING"
    If pCount > 1 Quit "AMBIGUOUS"
    If 'pEnabled Quit "NOTENABLED"
    If pType = ..#TYPESTARTITEM {
        If 'pTempStopped Quit "NOTTEMPSTOPPED"
        Quit ""
    }
    If pTempStopped Quit "TEMPSTOPPED"
    If 'pOwnJobs Quit "NOJOBS"
    Quit ""
}

/// <p>Whether an item runs jobs of its own while not stopped, from the job and pool size the running production holds for it
/// (<method>ItemRuntime</method>), judged as the vendor's <code>TempStopConfigItem</code> judges them: both nonzero. The job reads
/// <code>-1</code> for an item whose adapter runs one job whatever its pool size (<code>SINGLEPOOLJOB</code>, a TCP inbound
/// service's), 0 for an item that runs in its callers' jobs or the shared actor pool, has no adapter, or is stopped.</p>
ClassMethod OwnsJobs(pRunAsJob As %Integer, pPoolSize As %Integer) As %Boolean
{
    Quit (+pRunAsJob '= 0) && (+pPoolSize '= 0)
}

/// <p>The code <method>ItemRunRefusal</method>'s token <var>pToken</var> names: the production's
/// <code>NOTRUNNING</code>, else <method>ItemCode</method>'s; <code>""</code> for no token.</p>
ClassMethod ItemRunCode(pToken As %String) As %String
{
    If pToken = "" Quit ""
    If pToken = "NOTRUNNING" Quit ##class(OcuPilot.Api.InteropError).#NOTRUNNING
    Quit ..ItemCode(pToken)
}

/// <p>Read the items of <var>pProduction</var> in <var>pNamespace</var> whose name is <var>pName</var>
/// without regard to case, or every item when it is <code>""</code> (at most <var>pMax</var> of them when
/// that is above zero), without changing anything. <var>pExists</var> is whether the production is there.
/// <var>pFound(n)</var> is <code>$ListBuild(Name, ClassName, Type code, Enabled, EnabledSource, PoolSize,
/// Category, Comment)</code>, <code>Enabled</code> the effective value and <code>EnabledSource</code>
/// <code>default</code> when a system default supplies it, <code>production</code> else, as the vendor's own
/// check reads it (<code>Ens.Config.DefaultSettings:%GetSetting</code>). <var>pCount</var> counts every item
/// of the name. A fault is <var>pCaught</var>, with the namespace restored. Only vendor classes and this
/// class run while the namespace is switched.</p>
ClassMethod GatherItems(pNamespace As %String, pProduction As %String, pName As %String, pMax As %Integer, Output pExists As %Boolean, ByRef pFound, Output pCount As %Integer, Output pCaught) As %Status [ Private ]
{
    Kill pFound
    Set pFound = 0
    Set pExists = 0
    Set pCount = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set pExists = ''##class(Ens.Config.Production).%ExistsId(pProduction)
        If pExists {
            Set tProduction = ##class(Ens.Config.Production).%OpenId(pProduction)
            If $IsObject(tProduction) {
                Set tWanted = $ZConvert(pName, "U")
                For tI = 1:1:tProduction.Items.Count() {
                    Set tItem = tProduction.Items.GetAt(tI)
                    If '$IsObject(tItem) Continue
                    If (pName '= "") && ($ZConvert(tItem.Name, "U") '= tWanted) Continue
                    Set pCount = pCount + 1
                    If (pMax > 0) && (pFound >= pMax) Quit
                    Set tClass = tItem.ClassName
                    Set tEnabled = ''tItem.Enabled
                    Set tSource = "production"
                    If ##class(Ens.Config.DefaultSettings).%GetSetting(pProduction, tItem.Name, tClass, "", "Enabled", .tDefault) {
                        Set tEnabled = ''(+tDefault)
                        Set tSource = "default"
                    }
                    Set pFound($Increment(pFound)) = $ListBuild(tItem.Name, tClass, ##class(Ens.Config.Item).GetBusinessType(tClass, tItem), tEnabled, tSource, tItem.PoolSize, tItem.Category, tItem.Comment)
                }
            }
            Set tItem = ""
            Set tProduction = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The item row <var>pLine</var> (<method>GatherItems</method>'s element) of <var>pProduction</var> as
/// the list and the item read answer it: <code>{Production, Name, ClassName, Type, Enabled,
/// EnabledSource, PoolSize, Category, Comment}</code>, <code>Type</code> one of <code>service</code>,
/// <code>process</code>, <code>operation</code> and <code>unknown</code>; with <var>pNamespace</var> and
/// <var>pCount</var> it also carries <code>Namespace</code> and <code>Count</code>.</p>
ClassMethod ItemRow(pProduction As %String, pLine As %List, pNamespace As %String = "", pCount As %Integer = "") As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Production", pProduction, "string")
    Do tRow.%Set("Name", $List(pLine, 1) _ "", "string")
    Do tRow.%Set("ClassName", $List(pLine, 2) _ "", "string")
    Do tRow.%Set("Type", $Case($List(pLine, 3), 1: "service", 2: "process", 3: "operation", : "unknown"), "string")
    Do tRow.%Set("Enabled", ''$List(pLine, 4), "boolean")
    Do tRow.%Set("EnabledSource", $List(pLine, 5), "string")
    Do tRow.%Set("PoolSize", +$List(pLine, 6), "number")
    Do tRow.%Set("Category", $List(pLine, 7) _ "", "string")
    Do tRow.%Set("Comment", $List(pLine, 8) _ "", "string")
    If pNamespace '= "" {
        Do tRow.%Set("Namespace", pNamespace, "string")
        Do tRow.%Set("Count", +pCount, "number")
    }
    Quit tRow
}

/// <p>The items of <var>pProduction</var>, one row per item in the production's order, at most
/// <var>pMax</var> when it is above zero. An unknown production is 404 <code>PORT.NOTFOUND</code>,
/// unlogged.</p>
ClassMethod ListItems(pNamespace As %String, pProduction As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..GatherItems(pNamespace, pProduction, "", pMax, .tExists, .tFound, .tCount, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item list failed", .pHttpStatus, .pFault)
    If 'tExists Quit ..Absent(.pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..ItemRow(pProduction, tFound(tI)))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>One item, fresh (Story 20.3): the item row with <code>Namespace</code> and <code>Count</code>.
/// A namespace under source control is <code>INTEROP.ITEM.SOURCECONTROL</code> first; an item the
/// production does not hold, or a production it does not hold, is 404 <code>PORT.NOTFOUND</code>,
/// unlogged, and so is an item an enable or a disable would not find (<method>VendorCannotFind</method>); a
/// name the production holds more than once is <code>AMBIGUOUS</code>. With <var>pAction</var> it refuses
/// what that action would be refused
/// (<method>ItemRefusal</method>); for an add or a copy (AD-54) it inverts, so absence is the 404 the create
/// expects and a held name is <code>TAKEN</code>.</p>
/// <p><var>pComposed</var> is 1 when the query names <parameter>NEWCLASSKEY</parameter>, and a change of class
/// (<var>pAction</var> <parameter>TYPECHANGECLASS</parameter>) is always composed: the row then also answers
/// <code>NewClass</code>, <code>Dropped</code> (<code>[{Target, Name, Value, Secret}]</code>, an empty <code>Value</code>
/// for a credential-named setting), <code>Reviewed</code> (<var>pReviewed</var>) and <code>Digest</code>
/// (<method>ComposeChange</method>).</p>
ClassMethod ReadItem(pNamespace As %String, pProduction As %String, pName As %String, pAction As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pComposed As %Boolean = 0, pNewClass As %String = "", pReviewed As %String = "") As %Status [ Private ]
{
    Set pRow = ""
    If ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMSOURCECONTROL, .pHttpStatus, .pFault)
    Set tSC = ..GatherItems(pNamespace, pProduction, pName, 0, .tExists, .tFound, .tCount, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item read failed", .pHttpStatus, .pFault)
    If (pAction = ..#TYPEADD) || (pAction = ..#TYPECOPY) {
        If tCount > 0 Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMTAKEN, .pHttpStatus, .pFault)
        Quit ..Absent(.pHttpStatus, .pFault)
    }
    If 'tExists || (tCount = 0) Quit ..Absent(.pHttpStatus, .pFault)
    Set tLine = tFound(1)
    If tCount > 1 Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMAMBIGUOUS, .pHttpStatus, .pFault)
    If ..VendorCannotFind(pAction, tCount, tLine) Quit ..Absent(.pHttpStatus, .pFault)
    If pAction '= "" {
        Set tCode = ..ItemRefusal(pAction, tCount, $List(tLine, 4), $List(tLine, 5), $List(tLine, 3), $List(tLine, 6))
        If tCode '= "" Quit ..Conflict(tCode, .pHttpStatus, .pFault)
    }
    Set pRow = ..ItemRow(pProduction, tLine, pNamespace, tCount)
    If pComposed || (pAction = ..#TYPECHANGECLASS) {
        Set tComposeSC = ..ComposeChange(pNamespace, pProduction, $List(tLine, 1), pAction, pNewClass, pReviewed, pRow, .pHttpStatus, .pFault)
        If $$$ISERR(tComposeSC) Set pRow = ""
        Quit tComposeSC
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The vendor's runtime facts for the item <var>pItemName</var> in <var>pNamespace</var> (Story 20.25), read from
/// <code>^Ens.Runtime("ConfigItem",&lt;name&gt;,...)</code> and written by nothing here: <var>pStopped</var> whether the
/// temporary-stop flag is set, <var>pRunAsJob</var> and <var>pPoolSize</var> the job and pool size the running production
/// holds for it (<method>OwnsJobs</method> reads them). A fault is <var>pCaught</var>, with the namespace restored. Only this
/// class runs while the namespace is switched.</p>
ClassMethod ItemRuntime(pNamespace As %String, pItemName As %String, Output pStopped As %Boolean, Output pRunAsJob As %Integer, Output pPoolSize As %Integer, Output pCaught) As %Status [ Private ]
{
    Set pStopped = 0
    Set pRunAsJob = 0
    Set pPoolSize = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set pStopped = ''$Get(^Ens.Runtime("ConfigItem", pItemName, "TemporarilyStop"))
        Set pRunAsJob = +$Get(^Ens.Runtime("ConfigItem", pItemName, "Job"))
        Set pPoolSize = +$Get(^Ens.Runtime("ConfigItem", pItemName, "PoolSize"))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>One item's runtime, fresh (Story 20.25): <code>{Production, Name, ClassName, Enabled, EnabledSource, Count, State,
/// Current, TemporarilyStopped, OwnJobs, Jobs, NeedsUpdate, Namespace}</code>. <code>State</code> and <code>Current</code> are the
/// production's (<method>ReadState</method>); <code>TemporarilyStopped</code>, <code>OwnJobs</code> (the item runs jobs of its own
/// while not stopped) and <code>Jobs</code> (the processes the host holds now) are read only while the item's production is the
/// namespace's running one and are false, false and 0 otherwise. An unknown production or item is 404 <code>PORT.NOTFOUND</code>,
/// unlogged; a name the production holds more than once is <code>AMBIGUOUS</code>. With <var>pAction</var>, one of the item runtime
/// writes, it refuses what that action would be refused (<method>ItemRunRefusal</method>).</p>
ClassMethod ReadItemRun(pNamespace As %String, pProduction As %String, pName As %String, pAction As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set tSC = ..ReadState(pNamespace, pProduction, .tFacts, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..GatherItems(pNamespace, pProduction, pName, 0, .tExists, .tFound, .tCount, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item runtime read failed", .pHttpStatus, .pFault)
    If 'tExists || (tCount = 0) Quit ..Absent(.pHttpStatus, .pFault)
    If tCount > 1 Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMAMBIGUOUS, .pHttpStatus, .pFault)
    Set tLine = tFound(1)
    Set tRunning = (tFacts("current") = pProduction) && (tFacts("word") = "Running")
    Set tStopped = 0
    Set tOwnJobs = 0
    Set tJobs = 0
    If tRunning {
        Set tSC = ..ItemRuntime(pNamespace, $List(tLine, 1), .tStopped, .tRunAsJob, .tPoolSize, .tCaught)
        If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item runtime read failed", .pHttpStatus, .pFault)
        Set tOwnJobs = ..OwnsJobs(tRunAsJob, tPoolSize)
        Set tSC = ..GatherJobs(pNamespace, pProduction, $List(tLine, 1), 0, .tCurrent, .tJobLines, .tCaught)
        If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item runtime read failed", .pHttpStatus, .pFault)
        For tI = 1:1:tJobLines {
            If '..JobRow(tJobLines(tI)).%Get("Dead") Set tJobs = tJobs + 1
        }
    }
    If ..IsItemRunWrite(pAction) {
        Set tCode = ..ItemRunCode(..ItemRunRefusal(pAction, tCount, tRunning, $List(tLine, 4), tStopped, tOwnJobs))
        If tCode '= "" Quit ..Conflict(tCode, .pHttpStatus, .pFault)
    }
    Set tRow = {}
    Do tRow.%Set("Production", pProduction, "string")
    Do tRow.%Set("Name", $List(tLine, 1) _ "", "string")
    Do tRow.%Set("ClassName", $List(tLine, 2) _ "", "string")
    Do tRow.%Set("Enabled", ''$List(tLine, 4), "boolean")
    Do tRow.%Set("EnabledSource", $List(tLine, 5), "string")
    Do tRow.%Set("Count", +tCount, "number")
    Do tRow.%Set("State", tFacts("word"), "string")
    Do tRow.%Set("Current", tFacts("current"), "string")
    Do tRow.%Set("TemporarilyStopped", ''tStopped, "boolean")
    Do tRow.%Set("OwnJobs", ''tOwnJobs, "boolean")
    Do tRow.%Set("Jobs", tJobs, "number")
    Do tRow.%Set("NeedsUpdate", ''$Select(tRunning: tFacts("needsUpdate"), 1: 0), "boolean")
    Do tRow.%Set("Namespace", pNamespace, "string")
    Set pRow = tRow
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The production's own update, with the wait capped at <var>pCap</var> seconds (<method>Perform</method>'s shape): the
/// production's update timeout, or <var>pCap</var> when that is longer. Called while the production's namespace is switched; only
/// vendor classes run.</p>
ClassMethod UpdateCapped(pCap As %Integer) As %Status [ Private ]
{
    Set tTimeout = ##class(Ens.Director).GetRunningProductionUpdateTimeout()
    If tTimeout > pCap Set tTimeout = pCap
    Quit ##class(Ens.Director).UpdateProduction(tTimeout, 0)
}

/// <p>Stop, start or restart one item's jobs (Story 20.25) and answer the item's runtime as it stands. The item is read first
/// and judged by <method>ItemRunRefusal</method>, so a production that is not running, a disabled item, a start of an item not
/// stopped, a stop of one already stopped or running no jobs of its own, and a name held twice are refused with their own codes,
/// 409, before any vendor call. Then, in one switched block, as the classic page does:</p>
/// <ul>
/// <li>Stop: <code>TempStopConfigItem(...,1,0)</code> and the production's capped update. An update the vendor refuses
/// (<code>INTEROP.PRODUCTION.BUSY</code>) is followed by <code>TempStopConfigItem(...,0,0)</code>, so the flag is not left set.</li>
/// <li>Start: <code>TempStopConfigItem(...,0,0)</code> and the capped update. An update the vendor refuses is
/// <code>INTEROP.ITEM.STARTPENDING</code>: the flag is cleared and the next update starts the item.</li>
/// <li>Restart: the stop, then the start.</li>
/// </ul>
/// <p>The update is the production's own, so it also applies any other change waiting for the production. Neither
/// <code>EnableConfigItem</code> nor an update inside <code>TempStopConfigItem</code> is used. The vendor records
/// <code>ModifyConfiguration</code> for each flag change, and the port records nothing of its own.</p>
ClassMethod PerformItemRun(pNamespace As %String, pType As %String, pProduction As %String, pName As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..ReadItemRun(pNamespace, pProduction, pName, pType, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tConfigName = pProduction _ "||" _ tRow.%Get("Name")
    Set tCap = ..StopSeconds()
    Set tVendorSC = $$$OK
    Set tRestoreSC = $$$OK
    Set tStage = "stop"
    Set tCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If pType '= ..#TYPESTARTITEM {
            Set tVendorSC = ##class(Ens.Director).TempStopConfigItem(tConfigName, 1, 0)
            If $$$ISOK(tVendorSC) {
                Set tVendorSC = ..UpdateCapped(tCap)
                If $$$ISERR(tVendorSC) Set tRestoreSC = ##class(Ens.Director).TempStopConfigItem(tConfigName, 0, 0)
            }
        }
        If $$$ISOK(tVendorSC) && (pType '= ..#TYPESTOPITEM) {
            Set tStage = "start"
            Set tVendorSC = ##class(Ens.Director).TempStopConfigItem(tConfigName, 0, 0)
            If $$$ISOK(tVendorSC) Set tVendorSC = ..UpdateCapped(tCap)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $$$ISERR(tRestoreSC) Do ..LogFault("the item's temporary stop could not be cleared", tRestoreSC)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item " _ pType _ " failed", .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) {
        If (tStage = "start") && '..HasCode(tVendorSC, ..#CODEPRIVILEGE) && '(($System.Status.GetErrorText(tVendorSC)) [ "<PROTECT>") {
            If '..HasCode(tVendorSC, ..#CODENOTQUIESCENT) && '..HasCode(tVendorSC, ..#CODEJOBNOTSTOPPED) Do ..LogFault("the item start's update failed", tVendorSC)
            Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMSTARTPENDING, .pHttpStatus, .pFault)
        }
        Quit ..Statused(tVendorSC, "the item " _ pType _ " failed", .pHttpStatus, .pFault)
    }
    Set pResult = tRow
    If $$$ISOK(..ReadItemRun(pNamespace, pProduction, pName, "", .tAfter, .tAfterHttp, .tAfterFault)) Set pResult = tAfter
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The in-memory item of <var>pProduction</var> named exactly <var>pName</var>, or <code>""</code>.
/// <var>pProduction</var> is an <code>Ens.Config.Production</code> and the item an <code>Ens.Config.Item</code>, typed
/// <code>%RegisteredObject</code> so the class compiles where interoperability is not enabled (AD-62 item 12).
/// Called while the production's namespace is switched; only vendor classes run.</p>
ClassMethod ItemObject(pProduction As %RegisteredObject, pName As %String) As %RegisteredObject [ Private ]
{
    Set tFound = ""
    For tI = 1:1:pProduction.Items.Count() {
        Set tItem = pProduction.Items.GetAt(tI)
        If $IsObject(tItem) && (tItem.Name = pName) {
            Set tFound = tItem
            Quit
        }
    }
    Quit tFound
}

/// <p>Run item write <var>pType</var> against the item <var>pName</var> of <var>pProduction</var> in
/// <var>pNamespace</var>, and answer the item as it stands (Story 20.3). It changes the stored production
/// configuration and the production class and nothing else: it never updates, starts, stops or recovers a
/// production, so a running one reads update pending until 20.2's confirmed Update applies the change.
/// The sequence, in one switched block:</p>
/// <ol>
/// <li>A namespace under source control is refused, before anything is read.</li>
/// <li>An add's fields are validated (<method>AddViolations</method>), and a copy's (<method>CopyViolations</method>): 422.</li>
/// <li>The production is opened at concurrency 4, so writers on one production wait on the vendor's row
/// lock; a lock not taken in time is 503 <code>PORT.UNAVAILABLE</code>.</li>
/// <li>The item's facts are read under that lock and judged by <method>ItemRefusal</method>: 409.</li>
/// <li>Enable and disable call <code>Ens.Director:EnableConfigItem</code> with no update; add and copy insert a new
/// <code>Ens.Config.Item</code> and saves the production; remove calls <code>RemoveItem</code> and saves
/// it. Add and remove record <code>%Ensemble/%Production/ModifyConfiguration</code> through
/// <code>Ens.Util.Auditing</code>, naming the operation and the item and never a value; enable and
/// disable carry the vendor's own event. A copy (Story 20.40) refuses the new name held (<code>TAKEN</code>) and a source
/// the production does not hold once (<code>COPYSOURCE</code> or <code>AMBIGUOUS</code>), 409, under the same lock; it
/// inserts the source's clone, named, disabled, with a pool size of 1 when a business process's was 0, saves the production
/// and records the vendor's event naming both items. The vendor answers an error status only when the audit call
/// raises (an event that is disabled is dropped without one); that status is logged once the namespace is
/// restored and never fails the write.</li>
/// <li>The production class is saved every time (<code>SaveToClass</code>), because the configuration
/// alone is reverted by the next compile of the class. A failure there, after the configuration saved, is
/// a logged 500.</li>
/// </ol>
/// <p>A change of class (Story 20.41) runs <method>ChangeStep</method> under the same lock, with <var>pNewClass</var> and the digest
/// <var>pReviewed</var>, and answers the item as it then reads. Every reference is dropped before the namespace is restored.</p>
ClassMethod PerformItem(pNamespace As %String, pType As %String, pProduction As %String, pName As %String, pBody As %DynamicObject, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pSettingTarget As %String = "", pSettingName As %String = "", pNewClass As %String = "", pReviewed As %String = "") As %Status [ Private ]
{
    Set pResult = ""
    If ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMSOURCECONTROL, .pHttpStatus, .pFault)
    If (pType = ..#TYPECHANGECLASS) && '..NewClassShape(pNewClass) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMNEWCLASS, .pHttpStatus, .pFault)
    Set tSetting = ..IsSettingWrite(pType)
    If pType = ..#TYPESET {
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONITEMBODY, .pHttpStatus, .pFault)
        Set tViolationSC = ..SettingViolations(pNamespace, pProduction, pName, pSettingTarget, pSettingName, pBody, .tViolations)
        If $$$ISERR(tViolationSC) Quit ..Fail("the setting's value could not be judged", tViolationSC, .pHttpStatus, .pFault)
        If tViolations > 0 Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    }
    If (pType = ..#TYPEADD) || (pType = ..#TYPECOPY) {
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONITEMBODY, .pHttpStatus, .pFault)
        If pType = ..#TYPECOPY {
            Set tViolationSC = ..CopyViolations(pNamespace, pProduction, pName, pBody, .tViolations)
        } Else {
            Set tViolationSC = ..AddViolations(pNamespace, pName, pBody, .tViolations)
        }
        If $$$ISERR(tViolationSC) Quit ..Fail("the item's fields could not be judged", tViolationSC, .pHttpStatus, .pFault)
        If tViolations > 0 Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    }
    Set tCaught = ""
    Set tAbsent = 0
    Set tBusy = 0
    Set tRefusal = ""
    Set tVendorSC = $$$OK
    Set tSaveSC = $$$OK
    Set tAuditSC = $$$OK
    Set tAfter = ""
    Set tCount = 0
    Set tLocation = ""
    Set tItemName = pName
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If '##class(Ens.Config.Production).%ExistsId(pProduction) {
            Set tAbsent = 1
        } Else {
            Set tProduction = ##class(Ens.Config.Production).%OpenId(pProduction, 4)
            If '$IsObject(tProduction) {
                Set tBusy = 1
            } ElseIf tSetting {
                Do ..SettingStep(pNamespace, pType, pProduction, pName, pSettingTarget, pSettingName, pBody, tOrigNS, tProduction, .tStep)
                Set tAbsent = tStep("absent")
                Set tRefusal = tStep("refusal")
                Set tLocation = tStep("location")
                Set tVendorSC = tStep("vendor")
                Set tAuditSC = tStep("audit")
                Set tSaveSC = tStep("save")
                Set tAfter = tStep("after")
                Set tCount = tStep("afterCount")
                Set tItemName = tStep("itemName")
            } ElseIf pType = ..#TYPECHANGECLASS {
                Do ..ChangeStep(pNamespace, pProduction, pName, pNewClass, pReviewed, tOrigNS, tProduction, .tStep)
                Set tAbsent = tStep("absent")
                Set tRefusal = tStep("refusal")
                Set tVendorSC = tStep("vendor")
                Set tAuditSC = tStep("audit")
                Set tSaveSC = tStep("save")
                Set tAfter = tStep("after")
                Set tAfterCount = tStep("afterCount")
            } Else {
                Set tFactsSC = ..GatherItems(pNamespace, pProduction, pName, 0, .tExists, .tFound, .tCount, .tGatherCaught)
                If $IsObject(tGatherCaught) Throw tGatherCaught
                Set tLine = $Get(tFound(1))
                If (pType '= ..#TYPEADD) && (pType '= ..#TYPECOPY) && (tCount = 0) {
                    Set tAbsent = 1
                } ElseIf ..VendorCannotFind(pType, tCount, tLine) {
                    Set tAbsent = 1
                } Else {
                    If tLine = "" {
                        Set tRefusal = ..ItemRefusalToken(pType, tCount, 0, "", 0, "")
                    } Else {
                        Set tRefusal = ..ItemRefusalToken(pType, tCount, $List(tLine, 4), $List(tLine, 5), $List(tLine, 3), $List(tLine, 6))
                    }
                }
                If (pType = ..#TYPECOPY) && (tRefusal = "") && 'tAbsent {
                    ; The source is read under the same lock and copied as it stands now.
                    Set tSourceSC = ..GatherItems(pNamespace, pProduction, pBody.%Get("CopyFrom"), 0, .tSourceExists, .tSourceFound, .tSourceCount, .tSourceCaught)
                    If $IsObject(tSourceCaught) Throw tSourceCaught
                    If tSourceCount = 0 Set tRefusal = "COPYSOURCE"
                    If tSourceCount > 1 Set tRefusal = "AMBIGUOUS"
                }
                If (tRefusal = "") && 'tAbsent {
                    Set tName = $Select(tLine = "": pName, 1: $List(tLine, 1))
                    Set tTarget = ""
                    If (pType = ..#TYPEENABLE) || (pType = ..#TYPEDISABLE) {
                        Set tVendorSC = ##class(Ens.Director).EnableConfigItem(pProduction _ "||" _ tName, (pType = ..#TYPEENABLE), 0)
                        If $$$ISOK(tVendorSC) Set tSaveSC = tProduction.SaveToClass(..ItemObject(tProduction, tName))
                    } ElseIf pType = ..#TYPECOPY {
                        Set tSourceName = $List(tSourceFound(1), 1)
                        Kill %objlasterror
                        Set tNew = ..ItemObject(tProduction, tSourceName).%ConstructClone(1)
                        If '$IsObject(tNew) {
                            Set tVendorSC = $$$ERROR($$$GeneralError, "the source item could not be cloned: " _ $System.Status.GetErrorText($Get(%objlasterror, $$$OK)))
                        } Else {
                            Set tNew.Name = pName
                            Set tNew.Enabled = 0
                            If (tNew.BusinessType() = 2) && (tNew.PoolSize = 0) Set tNew.PoolSize = 1
                            Do tProduction.Items.Insert(tNew)
                            Set tVendorSC = tProduction.%Save()
                        }
                        If $$$ISOK(tVendorSC) {
                            Set tActions = "item added by OcuPilot as a copy of " _ tSourceName
                            Set tAuditSC = ##class(Ens.Util.Auditing).AuditModifyProductionConfig(pProduction, pName, .tActions)
                            Set tSaveSC = tProduction.SaveToClass(tNew)
                        }
                        Set tNew = ""
                    } ElseIf pType = ..#TYPEADD {
                        Set tNew = ##class(Ens.Config.Item).%New(pBody.%Get("ClassName"))
                        Set tNew.Name = pName
                        Set tNew.Enabled = $Select(pBody.%GetTypeOf("Enabled") = "boolean": pBody.%Get("Enabled"), 1: 0)
                        If pBody.%GetTypeOf("PoolSize") = "number" Set tNew.PoolSize = pBody.%Get("PoolSize")
                        If pBody.%GetTypeOf("Category") = "string" Set tNew.Category = pBody.%Get("Category")
                        If pBody.%GetTypeOf("Comment") = "string" Set tNew.Comment = pBody.%Get("Comment")
                        Do tProduction.Items.Insert(tNew)
                        Set tVendorSC = tProduction.%Save()
                        If $$$ISOK(tVendorSC) {
                            Set tActions = "item added by OcuPilot"
                            Set tAuditSC = ##class(Ens.Util.Auditing).AuditModifyProductionConfig(pProduction, pName, .tActions)
                            Set tSaveSC = tProduction.SaveToClass(tNew)
                        }
                        Set tNew = ""
                    } Else {
                        Set tTarget = ..ItemObject(tProduction, tName)
                        Do tProduction.RemoveItem(tTarget)
                        Set tTarget = ""
                        Set tVendorSC = tProduction.%Save()
                        If $$$ISOK(tVendorSC) {
                            Set tActions = "item removed by OcuPilot"
                            Set tAuditSC = ##class(Ens.Util.Auditing).AuditModifyProductionConfig(pProduction, tName, .tActions)
                            Set tSaveSC = tProduction.SaveToClass()
                        }
                    }
                    If $$$ISOK(tVendorSC) && (pType '= ..#TYPEREMOVE) {
                        Set tAfterSC = ..GatherItems(pNamespace, pProduction, pName, 0, .tAfterExists, .tAfterFound, .tAfterCount, .tAfterCaught)
                        If $IsObject(tAfterCaught) Throw tAfterCaught
                        If tAfterCount > 0 Set tAfter = tAfterFound(1)
                    }
                }
            }
        }
        Set tTarget = ""
        Set tNew = ""
        Set tProduction = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        ; The production's lock is released in the namespace it was taken in: a setting write may have left it to
        ; judge a server path.
        Try {
            Set $NAMESPACE = pNamespace
        } Catch {
        }
        Set tTarget = "", tNew = "", tProduction = ""
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $$$ISERR(tAuditSC) Do ..LogFault("the item " _ pType _ " was saved but its audit record could not be written", tAuditSC)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item " _ pType _ " failed", .pHttpStatus, .pFault)
    If tAbsent Quit ..Absent(.pHttpStatus, .pFault)
    If tBusy Quit ..Unavailable(.pHttpStatus, .pFault)
    If tSetting && (tRefusal '= "") Quit ..Conflict(..SettingCode(tRefusal), .pHttpStatus, .pFault)
    If tRefusal '= "" Quit ..Conflict(..ItemCode(tRefusal), .pHttpStatus, .pFault)
    If tLocation '= "" {
        If pType = ..#TYPERESET Quit ..ConflictFor(tLocation, .pHttpStatus, .pFault)
        Set tViolations = 1
        Set tViolations(1) = $ListBuild("Value", tLocation)
        Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    }
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the item " _ pType _ " failed", .pHttpStatus, .pFault)
    If $$$ISERR(tSaveSC) Quit ..Fail("the production class could not be saved after the item " _ pType, tSaveSC, .pHttpStatus, .pFault)
    If tSetting && (tAfter '= "") {
        Set pResult = ..SettingRow(pProduction, tItemName, tAfter, pNamespace, tCount)
    } ElseIf tAfter = "" {
        Set pResult = {}
        Do pResult.%Set("Production", pProduction, "string")
        Do pResult.%Set("Name", pName, "string")
        Do pResult.%Set("Namespace", pNamespace, "string")
        Do pResult.%Set("Count", 0, "number")
    } Else {
        Set pResult = ..ItemRow(pProduction, tAfter, pNamespace, tAfterCount)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Serve the Settings endpoint (Story 20.22) after <method>Invoke</method>'s gate. A <code>LIST</code> names its
/// item under <parameter>ITEMKEY</parameter>; every other type names a setting by the composite id
/// <code>[Production, Item, Target, Name]</code> under <parameter>IDKEY</parameter>. A setting whose name the
/// credential pattern matches is refused <code>INTEROP.SETTING.SECRET</code> for a write and for a read composed for
/// one, on the name alone, before the namespace is switched.</p>
ClassMethod InvokeSettings(pNamespace As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType = ..#TYPELIST {
            If '..ItemParts($Get(pQuery(..#ITEMKEY)), .tProduction, .tItem) {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONITEMIDREQUIRED, .pHttpStatus, .pFault)
                Quit
            }
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..ListSettings(pNamespace, tProduction, tItem, +tMaxText, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite($Get(pQuery(..#IDKEY)))
        Set tValid = ($ListLength(tParts) = 4)
        For tI = 1:1:$Select(tValid: 4, 1: 0) {
            If $List(tParts, tI) = "" Set tValid = 0
        }
        If tValid && '$ListFind($ListBuild(..#TARGETCORE, ..#TARGETHOST, ..#TARGETADAPTER), $List(tParts, 3)) Set tValid = 0
        If 'tValid {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONSETTINGID, .pHttpStatus, .pFault)
            Quit
        }
        Set tProduction = $List(tParts, 1)
        Set tItem = $List(tParts, 2)
        Set tTarget = $List(tParts, 3)
        Set tSetting = $List(tParts, 4)
        Set tAction = $Select(..IsSettingWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && '..IsSettingWrite(tAction) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If (tAction '= "") && ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tSetting) {
            Set tSC = ..Conflict(##class(OcuPilot.Api.InteropError).#SETTINGSECRET, .pHttpStatus, .pFault)
            Quit
        }
        If ..IsSettingWrite(pType) {
            Set tSC = ..PerformItem(pNamespace, pType, tProduction, tItem, pBody, .pResult, .pHttpStatus, .pFault, tTarget, tSetting)
            Quit
        }
        Set tSC = ..ReadSetting(pNamespace, tProduction, tItem, tTarget, tSetting, tAction, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the setting call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The production and the item <var>pText</var> names, in <var>pProduction</var> and <var>pItem</var>: the item's
/// composite id <code>[Production, Name]</code>, or the vendor's config name <code>Production||Name</code>. Neither
/// name can hold a vertical bar, so a text with another is not one. Pure.</p>
ClassMethod ItemParts(pText As %String, Output pProduction As %String, Output pItem As %String) As %Boolean
{
    Set pProduction = ""
    Set pItem = ""
    If pText = "" Quit 0
    If pText [ $Char(1) {
        Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pText)
        If $ListLength(tParts) '= 2 Quit 0
        Set pProduction = $List(tParts, 1)
        Set pItem = $List(tParts, 2)
    } ElseIf pText [ "||" {
        Set pProduction = $Piece(pText, "||", 1)
        Set pItem = $Piece(pText, "||", 2, *)
    } Else {
        Quit 0
    }
    If (pProduction = "") || (pItem = "") || (pProduction [ "|") || (pItem [ "|") {
        Set pProduction = ""
        Set pItem = ""
        Quit 0
    }
    Quit 1
}

/// <p>The decision on a setting read or write, as the last segment of the code (<code>AMBIGUOUS</code>,
/// <code>SUPPLIED</code>, <code>CORE</code>, <code>DEFAULTED</code>), <code>""</code> for none (Story 20.22). It names
/// no other class, so it runs while the production's namespace is switched. <var>pSource</var> is the setting's value
/// source (1 production, 2 system default, 3 class default, 4 service registry), <var>pCount</var> how many items
/// of the name the production holds. Pure.</p>
/// <ul>
/// <li>More than one item of the name: <code>AMBIGUOUS</code>, which is <code>INTEROP.ITEM.AMBIGUOUS</code>.</li>
/// <li>A value a service registry entry supplies, and a Core setting a system default supplies:
/// <code>SUPPLIED</code>.</li>
/// <li>Reset: <code>CORE</code> for one of the item's own properties, then <code>DEFAULTED</code> when the
/// production holds no value of its own.</li>
/// </ul>
ClassMethod SettingRefusalToken(pType As %String, pTarget As %String, pSource As %Integer, pCount As %Integer) As %String
{
    If pCount > 1 Quit "AMBIGUOUS"
    If pSource = 4 Quit "SUPPLIED"
    If (pTarget = "Core") && (pSource = 2) Quit "SUPPLIED"
    If pType = "RESET" {
        If pTarget = "Core" Quit "CORE"
        If pSource '= 1 Quit "DEFAULTED"
    }
    Quit ""
}

/// <p>The code <var>pToken</var> names (<method>SettingRefusalToken</method>, or <code>SAME</code>):
/// <code>INTEROP.ITEM.AMBIGUOUS</code> for <code>AMBIGUOUS</code>, else <code>INTEROP.SETTING.</code> and the token;
/// <code>""</code> for no token.</p>
ClassMethod SettingCode(pToken As %String) As %String
{
    If pToken = "" Quit ""
    If pToken = "AMBIGUOUS" Quit ..#ITEMCODEPREFIX _ pToken
    Quit ..#SETTINGCODEPREFIX _ pToken
}

/// <p>Whether a set of <var>pValue</var> would store what the production already holds (Story 20.22): its own
/// value for a Host or Adapter setting (<var>pSource</var> 1), the property's for one of the item's own. Pure.</p>
ClassMethod SameValue(pTarget As %String, pSource As %Integer, pHeld As %String, pValue As %String) As %Boolean
{
    If (pTarget '= "Core") && (pSource '= 1) Quit 0
    Quit (pHeld = pValue)
}

/// <p>The word for a value source code, <code>""</code> for any other: <code>production</code>,
/// <code>systemDefault</code>, <code>classDefault</code> or <code>registry</code>. Pure.</p>
ClassMethod SourceWord(pCode As %Integer) As %String
{
    Quit $Case(+pCode, 1: "production", 2: "systemDefault", 3: "classDefault", 4: "registry", : "")
}

/// <p><code>directory</code> when the editor context <var>pContext</var> has the component
/// <parameter>LOCATIONDIRECTORY</parameter> (the part before <code>?</code>), <code>file</code> for
/// <parameter>LOCATIONFILE</parameter>, else <code>""</code> (Story 20.22). A setting of either kind is a location on
/// the server. Pure.</p>
ClassMethod LocationKind(pContext As %String) As %String
{
    Set tComponent = $Piece(pContext, "?", 1)
    If tComponent = ..#LOCATIONDIRECTORY Quit "directory"
    If tComponent = ..#LOCATIONFILE Quit "file"
    Quit ""
}

/// <p>The class that answers the path predicates (AD-21, AD-62). Overridable so a fixture can move the served
/// directory; production never overrides it.</p>
ClassMethod PathPortClass() As %String
{
    Quit "OcuPilot.Port.PathPort"
}

/// <p><var>pValue</var> as the running process resolves it, in the current namespace, where a relative value is read
/// against that namespace's database directory: <code>%File</code>'s one-argument <code>NormalizeDirectory</code> for a
/// <code>directory</code>, <code>NormalizeFilename</code> for a <code>file</code>; <code>""</code> for either other
/// kind and for an empty value. It names no other OcuPilot class, so it runs while the production's namespace is
/// switched.</p>
ClassMethod NormalizeLocation(pKind As %String, pValue As %String) As %String
{
    If pValue = "" Quit ""
    If pKind = "directory" Quit ##class(%File).NormalizeDirectory(pValue)
    If pKind = "file" Quit ##class(%File).NormalizeFilename(pValue)
    Quit ""
}

/// <p>The code a server path is refused with, or <code>""</code> (Story 20.22): the self-protection <class>OcuPilot.Port.PathPort</class>
/// keeps, evaluated through <method>PathPortClass</method> on <var>pNormalized</var>, the value as
/// <method>NormalizeLocation</method> answers it. A <code>directory</code> is refused for the manager directory
/// itself (<code>PATH.MANAGERDIR</code>) and for the served directory or anything under it
/// (<code>PATH.SERVED</code>); with <var>pLevels</var> above zero, also when the adapter would descend that many
/// levels into either (<method>DescentReaches</method>). A <code>file</code> is refused directly in the manager
/// directory (<code>PATH.MANAGER</code>) and under the served directory (<code>PATH.SERVED</code>). The order is
/// <method>OcuPilot.Port.PathPort.Resolve</method>'s. Runs only in the install namespace.</p>
ClassMethod LocationProblem(pKind As %String, pNormalized As %String, pLevels As %Integer = 0) As %String
{
    If pNormalized = "" Quit ""
    Set tPath = ..PathPortClass()
    If pKind = "directory" {
        If $ClassMethod(tPath, "IsManagerDirectory", pNormalized) Quit ##class(OcuPilot.Api.Error).#PATHMANAGERDIR
        If $ClassMethod(tPath, "InServedDirectory", pNormalized) Quit ##class(OcuPilot.Api.Error).#PATHSERVED
        If (+pLevels > 0) && ..DescentReaches(pNormalized, pLevels) Quit ##class(OcuPilot.Api.InteropError).#SETTINGDESCENT
        Quit ""
    }
    If pKind = "file" {
        If $ClassMethod(tPath, "DirectlyInManagerDirectory", pNormalized) Quit ##class(OcuPilot.Api.Error).#PATHMANAGER
        If $ClassMethod(tPath, "InServedDirectory", pNormalized) Quit ##class(OcuPilot.Api.Error).#PATHSERVED
    }
    Quit ""
}

/// <p>Whether an adapter that starts in the normalized directory <var>pDirectory</var> and descends
/// <var>pLevels</var> levels of subdirectories would enter the manager directory or the directory OcuPilot serves
/// its files from (Story 20.22). Each is read through <method>PathPortClass</method> and normalized; one that lies
/// strictly below <var>pDirectory</var> is approached one segment at a time up to <var>pLevels</var>, and each
/// directory entered is tested with the same predicates the directory itself is. Textual, as the predicates are.
/// Runs only in the install namespace.</p>
ClassMethod DescentReaches(pDirectory As %String, pLevels As %Integer) As %Boolean
{
    If (pDirectory = "") || (+pLevels < 1) Quit 0
    Set tPath = ..PathPortClass()
    Set tDirectory = ##class(%File).NormalizeDirectory(pDirectory)
    If tDirectory = "" Quit 0
    Set tSeparator = $Extract(tDirectory, *)
    Set tReached = 0
    For tMethod = "ManagerDirectory", "ServedDirectory" {
        Set tProtected = $ClassMethod(tPath, tMethod)
        If tProtected '= "" Set tProtected = ##class(%File).NormalizeDirectory(tProtected)
        If (tProtected = "") || (tProtected = tDirectory) Continue
        If '$ClassMethod(tPath, "Contains", tDirectory, tProtected) Continue
        Set tRelative = $Extract(tProtected, $Length(tDirectory) + 1, *)
        Set tDepth = $Length(tRelative, tSeparator) - 1
        Set tCandidate = tDirectory
        For tK = 1:1:$Select(tDepth < +pLevels: tDepth, 1: +pLevels) {
            Set tCandidate = tCandidate _ $Piece(tRelative, tSeparator, tK) _ tSeparator
            If $ClassMethod(tPath, "IsManagerDirectory", tCandidate) || $ClassMethod(tPath, "InServedDirectory", tCandidate) {
                Set tReached = 1
                Quit
            }
        }
        If tReached Quit
    }
    Quit tReached
}

/// <p>The code the change <var>pFacts</var> describes is refused with on a server path, or <code>""</code> (Story
/// 20.22). <var>pFacts</var> is <method>SettingFacts</method>'s. A change of the subdirectory levels is judged by
/// <method>DescentReaches</method> alone, on the effective file path and the levels that would take effect; any
/// other location is judged by <method>LocationProblem</method>, with the effective levels when it is the file path of
/// an item that holds both settings. Runs only in the install namespace.</p>
ClassMethod ChangeProblem(ByRef pFacts) As %String
{
    Set tTarget = $Get(pFacts("target"))
    Set tName = $Get(pFacts("name"))
    Set tDescent = +$Get(pFacts("hasDescent")) && (tTarget = ..#TARGETADAPTER)
    If tDescent && (tName = ..#DESCENTSETTING) {
        If $Get(pFacts("pathNorm")) = "" Quit ""
        If ..DescentReaches(pFacts("pathNorm"), +$Get(pFacts("newValue"))) Quit ##class(OcuPilot.Api.InteropError).#SETTINGDESCENT
        Quit ""
    }
    Set tLevels = $Select(tDescent && (tName = ..#DESCENTPATH): +$Get(pFacts("levels")), 1: 0)
    Quit ..LocationProblem($Get(pFacts("kind")), $Get(pFacts("normalized")), tLevels)
}

/// <p>The item <var>pItem</var> of <var>pProduction</var> in <var>pNamespace</var>, whose name matches without
/// regard to case, with its settings (Story 20.22). <var>pExists</var> is whether the production is there,
/// <var>pCount</var> how many items bear the name; only when it is one are <var>pFound</var> and
/// <var>pFacts</var> filled. <var>pFound(n)</var> is <code>$ListBuild(Target, Name, Value, Source code, Default,
/// DefaultSource code, Type, Category, EditorContext, Value normalized, Default normalized)</code>: the item's own
/// settable properties first (<code>Core</code>, less the read-only ones and <code>Enabled</code>), then its Host
/// settings, then its Adapter settings, each value the effective one. The two normalized values are the value and
/// the default of a server path as <method>NormalizeLocation</method> reads them in this namespace, else
/// <code>""</code>. <var>pFacts</var> holds <code>name</code>, <code>class</code> and <code>adapter</code>, the item's
/// own name and its host and adapter classes. A fault is <var>pCaught</var>, with the namespace restored. Only
/// vendor classes and this class run while the namespace is switched.</p>
ClassMethod GatherSettings(pNamespace As %String, pProduction As %String, pItem As %String, Output pExists As %Boolean, Output pCount As %Integer, ByRef pFound, Output pFacts, Output pCaught) As %Status [ Private ]
{
    Kill pFound
    Kill pFacts
    Set pFound = 0
    Set pExists = 0
    Set pCount = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set pExists = ''##class(Ens.Config.Production).%ExistsId(pProduction)
        If pExists {
            Set tProduction = ##class(Ens.Config.Production).%OpenId(pProduction)
            If $IsObject(tProduction) {
                Set tWanted = $ZConvert(pItem, "U")
                Set tChosen = ""
                For tI = 1:1:tProduction.Items.Count() {
                    Set tCandidate = tProduction.Items.GetAt(tI)
                    If '$IsObject(tCandidate) Continue
                    If $ZConvert(tCandidate.Name, "U") '= tWanted Continue
                    Set pCount = pCount + 1
                    If pCount = 1 Set tChosen = tCandidate
                }
                If pCount = 1 {
                    Set pFacts("name") = tChosen.Name
                    Set pFacts("class") = tChosen.ClassName
                    Set pFacts("adapter") = tChosen.AdapterClassName()
                    Kill tStatic
                    Set tStaticSC = tChosen.GetStaticSettings(.tStatic)
                    If $$$ISERR(tStaticSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tStaticSC)
                    Set tKey = ""
                    For {
                        Set tKey = $Order(tStatic(tKey))
                        If tKey = "" Quit
                        Set tRow = tStatic(tKey)
                        If (+$List(tRow, 4) = 0) || ($List(tRow, 2) = "Enabled") Continue
                        Set pFound($Increment(pFound)) = ..SettingLine(tRow, "Core")
                    }
                    Set tVirtualSC = tChosen.PopulateVirtualSettings()
                    If $$$ISERR(tVirtualSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tVirtualSC)
                    For tGroup = "Host", "Adapter" {
                        For tI = 1:1:tChosen.VirtualSettings.Count() {
                            Set tRow = tChosen.VirtualSettings.GetAt(tI)
                            If $List(tRow, 1) '= tGroup Continue
                            Set pFound($Increment(pFound)) = ..SettingLine(tRow, tGroup)
                        }
                    }
                }
            }
            Set tChosen = ""
            Set tCandidate = ""
            Set tProduction = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The line <method>GatherSettings</method> keeps of one setting row <var>pRow</var> of group
/// <var>pTarget</var>, the vendor's 18-element row (Story 20.22). Called while the namespace is switched.</p>
ClassMethod SettingLine(pRow As %List, pTarget As %String) As %List [ Private ]
{
    Set tKind = ..LocationKind($List(pRow, 18))
    Set tValue = $List(pRow, 3)
    Set tDefault = $List(pRow, 5)
    Quit $ListBuild(pTarget, $List(pRow, 2), tValue, +$List(pRow, 4), tDefault, +$List(pRow, 6), $List(pRow, 8), $List(pRow, 16), $List(pRow, 18), ..NormalizeLocation(tKind, tValue), ..NormalizeLocation(tKind, tDefault))
}

/// <p>Everything one setting call needs, read in the current namespace, which must be <var>pNamespace</var>
/// (Story 20.22), in <var>pFacts</var>. It is <method>GatherSettings</method> and the facts about the one setting
/// <var>pTarget</var>/<var>pName</var> that <var>pType</var> (<code>SET</code>, <code>RESET</code> or
/// <code>""</code>) is about:</p>
/// <ul>
/// <li><code>exists</code>, <code>count</code>, <code>itemName</code>, <code>class</code>, <code>adapter</code>,
/// <code>rows</code> and <code>row(n)</code>: the production, how many items bear the name, the item and its
/// settings. <code>line</code> is the one setting's line, <code>""</code> when the item declares none.</li>
/// <li><code>kind</code>: <method>LocationKind</method> of the setting. <code>newValue</code> and
/// <code>normalized</code>: the value the change leaves in force and its normalized form, which a set takes from
/// <var>pValue</var> and a reset from the default.</li>
/// <li><code>hasDescent</code>, <code>pathNorm</code> and <code>levels</code>: whether the item holds both
/// <parameter>DESCENTSETTING</parameter> and <parameter>DESCENTPATH</parameter> as adapter settings, the effective
/// file path normalized and the effective levels.</li>
/// <li><code>valid</code>: for a set, whether the declaring class's <code>&lt;Name&gt;IsValid</code> accepts
/// <var>pValue</var> (<method>ValueAccepted</method>).</li>
/// </ul>
/// <p>A fault is thrown. Only vendor classes and this class run.</p>
ClassMethod SettingFacts(pNamespace As %String, pProduction As %String, pItem As %String, pTarget As %String, pName As %String, pType As %String, pValue As %String, Output pFacts) [ Private ]
{
    Kill pFacts
    Set pFacts("exists") = 0
    Set pFacts("count") = 0
    Set pFacts("itemName") = ""
    Set pFacts("class") = ""
    Set pFacts("adapter") = ""
    Set pFacts("rows") = 0
    Set pFacts("line") = ""
    Set pFacts("target") = pTarget
    Set pFacts("name") = pName
    Set pFacts("kind") = ""
    Set pFacts("newValue") = ""
    Set pFacts("normalized") = ""
    Set pFacts("hasDescent") = 0
    Set pFacts("pathNorm") = ""
    Set pFacts("levels") = 0
    Set pFacts("valid") = 1
    Set tGatherSC = ..GatherSettings(pNamespace, pProduction, pItem, .tExists, .tCount, .tFound, .tItemFacts, .tCaught)
    If $IsObject(tCaught) Throw tCaught
    Set pFacts("exists") = tExists
    Set pFacts("count") = tCount
    If tCount '= 1 Quit
    Set pFacts("itemName") = tItemFacts("name")
    Set pFacts("class") = tItemFacts("class")
    Set pFacts("adapter") = tItemFacts("adapter")
    Set pFacts("rows") = tFound
    Set tHasLevels = 0
    Set tHasPath = 0
    For tI = 1:1:tFound {
        Set tLine = tFound(tI)
        Set pFacts("row", tI) = tLine
        If $List(tLine, 1) = ..#TARGETADAPTER {
            If $List(tLine, 2) = ..#DESCENTSETTING {
                Set tHasLevels = 1
                Set pFacts("levels") = +$List(tLine, 3)
            } ElseIf $List(tLine, 2) = ..#DESCENTPATH {
                Set tHasPath = 1
                Set pFacts("pathNorm") = $List(tLine, 10)
            }
        }
        If ($List(tLine, 1) = pTarget) && ($List(tLine, 2) = pName) Set pFacts("line") = tLine
    }
    Set pFacts("hasDescent") = (tHasLevels && tHasPath)
    If pFacts("line") = "" Quit
    Set tKind = ..LocationKind($List(pFacts("line"), 9))
    Set pFacts("kind") = tKind
    If pType = ..#TYPESET {
        Set pFacts("newValue") = pValue
        Set pFacts("normalized") = ..NormalizeLocation(tKind, pValue)
        Set pFacts("valid") = ..ValueAccepted(.pFacts, pTarget, pName, pValue)
    } ElseIf pType = ..#TYPERESET {
        Set pFacts("newValue") = $List(pFacts("line"), 5)
        Set pFacts("normalized") = $List(pFacts("line"), 11)
    }
}

/// <p>Whether the class that declares the setting accepts <var>pValue</var> (Story 20.22): an item's own property by
/// <code>Ens.Config.Item</code>'s <code>&lt;Name&gt;IsValid</code>, a Host setting by the item's class, an Adapter
/// setting by its adapter class, as the classic configuration page asks them. An empty value is not judged for a
/// Host or Adapter setting, as there; a class that has no such method accepts anything. Called while the namespace
/// is switched.</p>
ClassMethod ValueAccepted(ByRef pFacts, pTarget As %String, pName As %String, pValue As %String) As %Boolean [ Private ]
{
    Set tClass = $Case(pTarget, "Core": "Ens.Config.Item", "Host": pFacts("class"), "Adapter": pFacts("adapter"), : "")
    If tClass = "" Quit 1
    If (pTarget '= "Core") && (pValue = "") Quit 1
    If '##class(%Dictionary.CompiledMethod).%ExistsId(tClass _ "||" _ pName _ "IsValid") Quit 1
    Quit ''$$$ISOK($ClassMethod(tClass, pName _ "IsValid", pValue))
}

/// <p>The setting row <var>pLine</var> (<method>GatherSettings</method>'s element) of item <var>pItemName</var> of
/// <var>pProduction</var> as the list and the setting read answer it: <code>{Production, Item, Target, Name, Value,
/// Source, Default, DefaultSource, Type, Category, Location, Secret}</code>; with <var>pNamespace</var> and
/// <var>pCount</var> it also carries <code>Namespace</code> and <code>Count</code>. A setting whose name the
/// credential pattern matches (<method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method>) answers an empty
/// <code>Value</code> and <code>Default</code> and <code>Secret</code> true: the value is dropped here, in the
/// install namespace, and reaches nothing that renders the row (AD-35, Story 20.22).</p>
ClassMethod SettingRow(pProduction As %String, pItemName As %String, pLine As %List, pNamespace As %String = "", pCount As %Integer = "") As %DynamicObject [ Private ]
{
    Set tName = $List(pLine, 2)
    Set tSecret = ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tName)
    Set tRow = {}
    Do tRow.%Set("Production", pProduction, "string")
    Do tRow.%Set("Item", pItemName, "string")
    Do tRow.%Set("Target", $List(pLine, 1) _ "", "string")
    Do tRow.%Set("Name", tName _ "", "string")
    Do tRow.%Set("Value", $Select(tSecret: "", 1: $List(pLine, 3) _ ""), "string")
    Do tRow.%Set("Source", ..SourceWord($List(pLine, 4)), "string")
    Do tRow.%Set("Default", $Select(tSecret: "", 1: $List(pLine, 5) _ ""), "string")
    Do tRow.%Set("DefaultSource", ..SourceWord($List(pLine, 6)), "string")
    Do tRow.%Set("Type", $List(pLine, 7) _ "", "string")
    Do tRow.%Set("Category", $List(pLine, 8) _ "", "string")
    Do tRow.%Set("Location", ''(..LocationKind($List(pLine, 9)) '= ""), "boolean")
    Do tRow.%Set("Secret", ''tSecret, "boolean")
    If pNamespace '= "" {
        Do tRow.%Set("Namespace", pNamespace, "string")
        Do tRow.%Set("Count", +pCount, "number")
    }
    Quit tRow
}

/// <p>The facts of <var>pType</var> on one setting, read in <var>pNamespace</var> (<method>SettingFacts</method>),
/// with the namespace restored whatever happens. A fault is <var>pCaught</var>.</p>
ClassMethod SettingsOf(pNamespace As %String, pProduction As %String, pItem As %String, pTarget As %String, pName As %String, pType As %String, pValue As %String, Output pFacts, Output pCaught) [ Private ]
{
    Kill pFacts
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..SettingFacts(pNamespace, pProduction, pItem, pTarget, pName, pType, pValue, .pFacts)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>The settings of the item <var>pItem</var> of <var>pProduction</var>, one row per setting in
/// <method>GatherSettings</method>'s order, at most <var>pMax</var> when it is above zero (Story 20.22). An unknown
/// production or item is 404 <code>PORT.NOTFOUND</code>, unlogged; a name the production holds more than once is
/// <code>INTEROP.ITEM.AMBIGUOUS</code>.</p>
ClassMethod ListSettings(pNamespace As %String, pProduction As %String, pItem As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Do ..SettingsOf(pNamespace, pProduction, pItem, "", "", "", "", .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item settings list failed", .pHttpStatus, .pFault)
    If 'tFacts("exists") || (tFacts("count") = 0) Quit ..Absent(.pHttpStatus, .pFault)
    If tFacts("count") > 1 Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMAMBIGUOUS, .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFacts("rows") {
        If (pMax > 0) && (tI > pMax) Quit
        Do pRows.%Push(..SettingRow(pProduction, tFacts("itemName"), tFacts("row", tI)))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>One setting, fresh (Story 20.22): the setting row with <code>Namespace</code> and <code>Count</code>. A
/// namespace under source control is <code>INTEROP.ITEM.SOURCECONTROL</code> first; an unknown production, item or
/// setting, and <code>Enabled</code>, are 404 <code>PORT.NOTFOUND</code>, unlogged; a name the production holds more
/// than once is <code>AMBIGUOUS</code>. With <var>pAction</var> it refuses what that action would be refused
/// (<method>SettingRefusalToken</method>), and for a reset the server path the default would leave in force
/// (<method>ChangeProblem</method>), 409 with that code.</p>
ClassMethod ReadSetting(pNamespace As %String, pProduction As %String, pItem As %String, pTarget As %String, pName As %String, pAction As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    If ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMSOURCECONTROL, .pHttpStatus, .pFault)
    Do ..SettingsOf(pNamespace, pProduction, pItem, pTarget, pName, $Select(pAction = ..#TYPERESET: pAction, 1: ""), "", .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the setting read failed", .pHttpStatus, .pFault)
    Set tCount = tFacts("count")
    If 'tFacts("exists") || (tCount = 0) Quit ..Absent(.pHttpStatus, .pFault)
    If tCount > 1 Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMAMBIGUOUS, .pHttpStatus, .pFault)
    Set tLine = tFacts("line")
    If tLine = "" Quit ..Absent(.pHttpStatus, .pFault)
    If pAction '= "" {
        Set tToken = ..SettingRefusalToken(pAction, pTarget, $List(tLine, 4), tCount)
        If tToken '= "" Quit ..Conflict(..SettingCode(tToken), .pHttpStatus, .pFault)
        If pAction = ..#TYPERESET {
            Set tLocation = ..ChangeProblem(.tFacts)
            If tLocation '= "" Quit ..ConflictFor(tLocation, .pHttpStatus, .pFault)
        }
    }
    Set pRow = ..SettingRow(pProduction, tFacts("itemName"), tLine, pNamespace, tCount)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Every rule over a set's value, in <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field, code)</code>
/// with the count in <code>pViolations</code> (Story 20.22), for the setting <var>pTarget</var>/<var>pName</var> of the
/// item <var>pItem</var> of <var>pProduction</var>: <code>Value</code> must be a JSON string
/// (<code>PORT.FIELD.SHAPE</code>); a Host or Adapter value has no space or control character at either end, which the
/// vendor would store trimmed; the declaring class's <code>&lt;Name&gt;IsValid</code> accepts it
/// (<code>INTEROP.SETTING.VALUE</code>, <method>ValueAccepted</method>); and a server path breaks no self-protection
/// (<method>ChangeProblem</method>: <code>PATH.MANAGERDIR</code>, <code>PATH.SERVED</code>, <code>PATH.MANAGER</code> or
/// <code>INTEROP.SETTING.DESCENT</code>). A setting the item does not declare earns none, and the call answers its 404.
/// The vendor classes run in <var>pNamespace</var>, switched by explicit save and restore, and only once this port's gate
/// admits a set there (<method>Admit</method>).</p>
ClassMethod SettingViolations(pNamespace As %String, pProduction As %String, pItem As %String, pTarget As %String, pName As %String, pBody As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tAdmitted = $$$ISOK(..Admit(..#ENDPOINTSETTINGS, ..#TYPESET, pNamespace, .tHttp, .tFault))
    Try {
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Set pBody = {}
        If pBody.%GetTypeOf("Value") '= "string" {
            Set pViolations($Increment(pViolations)) = $ListBuild("Value", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
            Quit
        }
        If 'tAdmitted Quit
        Set tValue = pBody.%Get("Value")
        If (pTarget '= ..#TARGETCORE) && ($ZStrip(tValue, "<>WC") '= tValue) {
            Set pViolations($Increment(pViolations)) = $ListBuild("Value", ##class(OcuPilot.Api.InteropError).#SETTINGVALUE)
            Quit
        }
        Do ..SettingsOf(pNamespace, pProduction, pItem, pTarget, pName, ..#TYPESET, tValue, .tFacts, .tCaught)
        If $IsObject(tCaught) {
            Set tSC = tCaught.AsStatus()
            Quit
        }
        If (tFacts("count") '= 1) || (tFacts("line") = "") Quit
        If 'tFacts("valid") {
            Set pViolations($Increment(pViolations)) = $ListBuild("Value", ##class(OcuPilot.Api.InteropError).#SETTINGVALUE)
            Quit
        }
        Set tCode = ..ChangeProblem(.tFacts)
        If tCode '= "" Set pViolations($Increment(pViolations)) = $ListBuild("Value", tCode)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The in-lock part of a setting write (Story 20.22), called by <method>PerformItem</method> while the namespace
/// is switched to <var>pNamespace</var> and <var>pLocked</var>, the production, is open at concurrency 4 with the lock
/// held. It reads the setting's facts under that lock and answers in <var>pStep</var>:</p>
/// <ul>
/// <li><code>absent</code>: the production holds no such item, or the item declares no such setting.</li>
/// <li><code>refusal</code>: <method>SettingRefusalToken</method>'s decision, else <code>SAME</code> for a set of the value
/// the production already holds.</li>
/// <li><code>location</code>: the code <method>ChangeProblem</method> refuses a server path with, judged from the rows
/// just read. The namespace is left for that judgement, which calls classes it cannot see, and entered again; the
/// production stays open, so its lock is held throughout, and nothing is stored when a code is answered.</li>
/// <li>Otherwise the write: an item's own property is set; a Host or Adapter setting is updated or inserted, or, for
/// a reset, removed; the item is saved; <code>%Ensemble/%Production/ModifyConfiguration</code> is recorded through
/// <code>Ens.Util.Auditing</code>, naming the setting and never a value; and the production class is saved
/// (<code>SaveToClass</code>). <code>vendor</code>, <code>audit</code> and <code>save</code> are the three statuses;
/// <code>after</code> and <code>afterCount</code> are the setting's line and its item count once saved.</li>
/// </ul>
ClassMethod SettingStep(pNamespace As %String, pType As %String, pProduction As %String, pItem As %String, pTarget As %String, pName As %String, pBody As %DynamicObject, pOrigNS As %String, pLocked As %RegisteredObject, Output pStep) [ Private ]
{
    Kill pStep
    Set pStep("absent") = 0
    Set pStep("refusal") = ""
    Set pStep("location") = ""
    Set pStep("vendor") = $$$OK
    Set pStep("audit") = $$$OK
    Set pStep("save") = $$$OK
    Set pStep("after") = ""
    Set pStep("afterCount") = 0
    Set pStep("itemName") = pItem
    Set tValue = $Select(pType = ..#TYPESET: pBody.%Get("Value"), 1: "")
    Do ..SettingFacts(pNamespace, pProduction, pItem, pTarget, pName, pType, tValue, .tFacts)
    Set tCount = tFacts("count")
    Set tLine = tFacts("line")
    If (tCount = 0) || ((tCount = 1) && (tLine = "")) {
        Set pStep("absent") = 1
        Quit
    }
    Set pStep("itemName") = tFacts("itemName")
    Set tSource = $Select(tLine = "": 0, 1: +$List(tLine, 4))
    Set pStep("refusal") = ..SettingRefusalToken(pType, pTarget, tSource, tCount)
    If (pStep("refusal") = "") && (pType = ..#TYPESET) && ..SameValue(pTarget, tSource, $List(tLine, 3), tValue) Set pStep("refusal") = "SAME"
    If pStep("refusal") '= "" Quit
    Set $NAMESPACE = pOrigNS
    Set pStep("location") = ..ChangeProblem(.tFacts)
    Set $NAMESPACE = pNamespace
    If pStep("location") '= "" Quit
    Set tItemObject = ..ItemObject(pLocked, tFacts("itemName"))
    If pTarget = ..#TARGETCORE {
        Set $Property(tItemObject, pName) = tValue
    } ElseIf pType = ..#TYPESET {
        Set tHeld = tItemObject.FindSettingByName(pName, pTarget)
        If '$IsObject(tHeld) {
            Set tHeld = ##class(Ens.Config.Setting).%New()
            Set tHeld.Target = pTarget
            Set tHeld.Name = pName
            Do tItemObject.Settings.Insert(tHeld)
        }
        Set tHeld.Value = tValue
    } Else {
        For tI = 1:1:tItemObject.Settings.Count() {
            Set tHeld = tItemObject.Settings.GetAt(tI)
            If (tHeld.Name = pName) && (tHeld.Target = pTarget) {
                Do tItemObject.Settings.RemoveAt(tI)
                Quit
            }
        }
    }
    Set pStep("vendor") = tItemObject.%Save()
    If $$$ISOK(pStep("vendor")) {
        Set tActions = "setting " _ $Select(pType = ..#TYPESET: "set", 1: "reset") _ " by OcuPilot"
        Set tActions(pTarget _ ":" _ pName) = ""
        Set pStep("audit") = ##class(Ens.Util.Auditing).AuditModifyProductionConfig(pProduction, tFacts("itemName"), .tActions)
        Set pStep("save") = pLocked.SaveToClass(tItemObject)
        Set tHeld = ""
        Set tItemObject = ""
        Do ..SettingFacts(pNamespace, pProduction, pItem, pTarget, pName, "", "", .tAfter)
        Set pStep("after") = tAfter("line")
        Set pStep("afterCount") = tAfter("count")
    }
    Set tHeld = ""
    Set tItemObject = ""
}

/// <p>Whether status <var>pStatus</var> carries vendor status code <var>pCode</var>, as one whole entry of
/// its comma-separated code list.</p>
ClassMethod HasCode(pStatus As %Status, pCode As %String) As %Boolean [ Private ]
{
    Set tCodes = ""
    Try {
        Set tCodes = $System.Status.GetErrorCodes(pStatus)
    } Catch {
        Set tCodes = ""
    }
    Quit ($ListFind($ListFromString(tCodes, ","), pCode) > 0)
}

/// <p>A vendor status <var>pStatus</var> in this port's own words: a production that did not quiesce in
/// time, <code>&lt;Ens&gt;ErrProductionNotQuiescent</code> and <code>&lt;Ens&gt;ErrJobNotStopped</code>, is
/// <parameter>OcuPilot.Api.InteropError.BUSY</parameter>; jobs that outlasted the wait after the production
/// quiesced, <code>&lt;Ens&gt;ErrJobsNotStopped</code>, are
/// <parameter>OcuPilot.Api.InteropError.PARTSTOPPED</parameter>, unlogged; <code>ErrProductionAlreadyRunning</code>,
/// <code>ErrProductionNotShutdownCleanly</code> and <code>ErrProductionSuspendedMismatch</code> are
/// <code>RUNNING</code>, <code>TROUBLED</code> and <code>OTHER</code>, each unlogged; a lock the vendor
/// could not take is 503 <code>PORT.UNAVAILABLE</code>; <code>&lt;PROTECT&gt;</code> and #940 are 403
/// <code>PORT.ACCESSDENIED</code>; anything else is 500 <code>INTERNAL</code>. The last two log the
/// vendor's text under <var>pMessage</var>.</p>
ClassMethod Statused(pStatus As %Status, pMessage As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    If ..HasCode(pStatus, ..#CODENOTQUIESCENT) || ..HasCode(pStatus, ..#CODEJOBNOTSTOPPED) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#BUSY, .pHttpStatus, .pFault)
    If ..HasCode(pStatus, ..#CODEJOBSNOTSTOPPED) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#PARTSTOPPED, .pHttpStatus, .pFault)
    If ..HasCode(pStatus, ..#CODEALREADYRUNNING) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#RUNNING, .pHttpStatus, .pFault)
    If ..HasCode(pStatus, ..#CODENOTSHUTDOWNCLEANLY) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#TROUBLED, .pHttpStatus, .pFault)
    If ..HasCode(pStatus, ..#CODESUSPENDEDMISMATCH) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#OTHER, .pHttpStatus, .pFault)
    If ..HasCode(pStatus, ..#CODERUNTIMELOCK) Quit ..Unavailable(.pHttpStatus, .pFault)
    Set tText = ""
    Try {
        Set tText = $System.Status.GetErrorText(pStatus)
    } Catch {
        Set tText = ""
    }
    If (tText [ "<PROTECT>") || ..HasCode(pStatus, ..#CODEPRIVILEGE) {
        Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .pFault, .tDetail)
        Set pHttpStatus = 403
        Do ..LogFault(pMessage, pStatus, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED)
        Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED)
    }
    Quit ..Fail(pMessage, pStatus, .pHttpStatus, .pFault)
}

/// <p>A vendor exception <var>pException</var> in this port's own words: a lock the vendor could not take is 503
/// <code>PORT.UNAVAILABLE</code>, unlogged, as <method>Statused</method> answers it; <code>&lt;PROTECT&gt;</code>
/// is 403 <code>PORT.ACCESSDENIED</code>, anything else 500 <code>INTERNAL</code>, each logging the
/// vendor's text under <var>pMessage</var>.</p>
ClassMethod Mapped(pException As %Exception.AbstractException, pMessage As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    If ..HasCode(pException.AsStatus(), ..#CODERUNTIMELOCK) Quit ..Unavailable(.pHttpStatus, .pFault)
    Set tProtect = 0
    Try {
        Set tProtect = (pException.Name [ "<PROTECT>")
    } Catch {
        Set tProtect = 0
    }
    If tProtect {
        Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .pFault, .tDetail)
        Set pHttpStatus = 403
        Do ..LogFault(pMessage, pException.AsStatus(), ##class(OcuPilot.Api.Error).#PORTACCESSDENIED)
        Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTACCESSDENIED)
    }
    Quit ..Fail(pMessage, pException.AsStatus(), .pHttpStatus, .pFault)
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture
/// the line; production never overrides it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>The privilege refusal naming <var>pFailedPair</var> (AD-8, AD-39).</p>
ClassMethod Deny(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDenial = ##class(OcuPilot.Kernel.Denial).Detail(pFailedPair)
    Quit ..Refuse(##class(OcuPilot.Kernel.Denial).#STATUS, ##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason(), .pHttpStatus, .pFault, tDenial)
}

/// <p>A refusal this port decided, with a written reason. <var>pDetail</var>, when supplied, becomes
/// the fault's <code>detail</code> (AD-39).</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pDetail As %DynamicObject = "") As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    If $IsObject(pDetail) Do pFault.%Set("detail", pDetail)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>The 409 refusal <var>pCode</var>, with its published sentence.</p>
ClassMethod Conflict(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, pCode, ##class(OcuPilot.Api.InteropError).ReasonFor(pCode), .pHttpStatus, .pFault)
}

/// <p>The 409 refusal <var>pCode</var>, with the sentence <method>OcuPilot.Api.Error.ReasonForViolation</method> gives
/// it: a code of this port's own or one of <class>OcuPilot.Port.PathPort</class>'s.</p>
ClassMethod ConflictFor(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, pCode, ##class(OcuPilot.Api.Error).ReasonForViolation(pCode), .pHttpStatus, .pFault)
}

/// <p>404 <code>PORT.NOTFOUND</code>: the production is not there. Unlogged (AD-2).</p>
ClassMethod Absent(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Do ##class(OcuPilot.Kernel.Fault).Outcome(404, $$$OK, .pFault, .tDetail)
    Set pHttpStatus = 404
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTNOTFOUND)
}

/// <p>503 <code>PORT.UNAVAILABLE</code>: the runtime lock could not be taken, so the state is
/// unknown. Unlogged: the caller may try again.</p>
ClassMethod Unavailable(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(503, ##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#PORTUNAVAILABLE, ..#REASONLOCK, .pHttpStatus, .pFault)
}

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p>Serve one of the runtime endpoints after <method>Invoke</method>'s gate. <code>LIST</code> answers an array of
/// rows, at most <parameter>MAXROWSKEY</parameter> of them when that is above zero, and writes nothing:
/// <code>Ens.Job:Enumerate</code>, whose <code>MarkDeadJobs</code> writes, is never called.</p>
/// <ul>
/// <li>Messages takes the search criteria <method>ListMessages</method> names; MessageHeader, MessageContents and MessageTrace take the
/// header's id under <parameter>MESSAGEKEY</parameter> (Stories 20.9 and 20.30); Sessions, SessionSummary and SessionMessages take the
/// criteria <method>ListSessions</method>, <method>ReadSessionSummary</method> and <method>ListSessionMessages</method> name (Story 24.4).</li>
/// <li>Monitor, Queues and Jobs take no criterion; QueueItems takes <parameter>QUEUEKEY</parameter>; every other
/// endpoint takes the item under <parameter>ITEMKEY</parameter> (the composite id or <code>Production||Name</code>),
/// resolved as an item read resolves it: 400 when it is not one, 404 for an unknown production or item, 409
/// <code>INTEROP.ITEM.AMBIGUOUS</code> for a name the production holds more than once.</li>
/// <li>Queues, QueueItems and Jobs also serve a typed read (<parameter>TYPEQUEUE</parameter>, <parameter>TYPEENTRY</parameter>,
/// <parameter>TYPEJOB</parameter>) and the action writes of Story 20.23 (<method>InvokeTyped</method>); Messages serves the four
/// resend types of Story 20.31 (<method>InvokeMessageAction</method>).</li>
/// </ul>
ClassMethod InvokeRuntime(pNamespace As %String, pEndpoint As %String, pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pCut As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pCut = 0
    Try {
        If pType '= ..#TYPELIST {
            If pEndpoint = ..#ENDPOINTMESSAGES {
                Set tSC = ..InvokeMessageAction(pNamespace, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            } Else {
                Set tSC = ..InvokeTyped(pNamespace, pEndpoint, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            }
            Quit
        }
        Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
        If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
            Quit
        }
        Set tMax = +tMaxText
        If pEndpoint = ..#ENDPOINTMONITOR {
            Set tSC = ..ListMonitor(pNamespace, tMax, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTQUEUES {
            Set tSC = ..ListQueues(pNamespace, tMax, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTJOBS {
            Set tSC = ..ListJobs(pNamespace, "", "", tMax, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTQUEUEITEMS {
            Set tQueue = $Get(pQuery(..#QUEUEKEY))
            If tQueue = "" {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONQUEUEREQUIRED, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..ListQueueEntries(pNamespace, tQueue, "", "", "", tMax, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTMESSAGES {
            Set tSC = ..ListMessages(pNamespace, .pQuery, tMax, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTSESSIONS {
            Set tSC = ..ListSessions(pNamespace, .pQuery, tMax, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTSESSIONSUMMARY {
            Set tSC = ..ReadSessionSummary(pNamespace, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTSESSIONMESSAGES {
            Set tSC = ..ListSessionMessages(pNamespace, .pQuery, tMax, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#ENDPOINTMESSAGEHEADER) || (pEndpoint = ..#ENDPOINTMESSAGECONTENTS) || (pEndpoint = ..#ENDPOINTMESSAGETRACE) {
            Set tMessage = $Get(pQuery(..#MESSAGEKEY))
            If '$Match(tMessage, ..#MESSAGEIDPATTERN) {
                Set tSC = ..RefuseCriterion("message", .pHttpStatus, .pFault)
                Quit
            }
            If pEndpoint = ..#ENDPOINTMESSAGEHEADER {
                Set tSC = ..ReadMessageHeader(pNamespace, tMessage, .pResult, .pHttpStatus, .pFault)
            } ElseIf pEndpoint = ..#ENDPOINTMESSAGETRACE {
                Set tSC = ..ListMessageTrace(pNamespace, tMessage, tMax, .pResult, .pHttpStatus, .pFault)
            } Else {
                Set tSC = ..ReadMessageContents(pNamespace, tMessage, tMax, .pResult, .pHttpStatus, .pFault, .pCut)
            }
            Quit
        }
        If '..ItemParts($Get(pQuery(..#ITEMKEY)), .tProduction, .tItem) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONITEMIDREQUIRED, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..ResolveItem(pNamespace, tProduction, tItem, .tLine, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tName = $List(tLine, 1)
        If pEndpoint = ..#ENDPOINTITEMSTATUS {
            Set tSC = ..ReadItemStatus(pNamespace, tProduction, tLine, .pResult, .pHttpStatus, .pFault)
        } ElseIf pEndpoint = ..#ENDPOINTITEMQUEUE {
            Set tSC = ..ItemQueueEntries(pNamespace, tProduction, tName, tMax, .pResult, .pHttpStatus, .pFault)
        } ElseIf pEndpoint = ..#ENDPOINTITEMLOG {
            Set tSC = ..ListItemLog(pNamespace, tProduction, tName, tMax, .pResult, .pHttpStatus, .pFault)
        } ElseIf pEndpoint = ..#ENDPOINTITEMMESSAGES {
            Set tSC = ..ListItemMessages(pNamespace, tProduction, tName, tMax, .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..ListJobs(pNamespace, tProduction, tName, tMax, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The item <var>pItem</var> of <var>pProduction</var> in <var>pNamespace</var>, as <method>GatherItems</method>
/// reads it, in <var>pLine</var> (its element), whose name is the item's own spelling. An unknown production or item is
/// 404 <code>PORT.NOTFOUND</code>, unlogged; a name the production holds more than once is
/// <code>INTEROP.ITEM.AMBIGUOUS</code>, the count rule an item read applies.</p>
ClassMethod ResolveItem(pNamespace As %String, pProduction As %String, pItem As %String, Output pLine As %List, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pLine = ""
    Set tSC = ..GatherItems(pNamespace, pProduction, pItem, 0, .tExists, .tFound, .tCount, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item could not be read", .pHttpStatus, .pFault)
    If 'tExists || (tCount = 0) Quit ..Absent(.pHttpStatus, .pFault)
    If tCount > 1 Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMAMBIGUOUS, .pHttpStatus, .pFault)
    Set pLine = tFound(1)
    Quit $$$OK
}

/// <p>The namespace's current production when it is running or troubled (<parameter>LIVEWORDS</parameter>) and, when
/// <var>pProduction</var> is given, is that production; <code>""</code> otherwise, so a stopped production answers
/// nothing a stale host record could fill. Called while the production's namespace is switched; a fault is
/// thrown.</p>
ClassMethod LiveCurrent(pProduction As %String) As %String [ Private ]
{
    Set tSC = ##class(Ens.Director).GetProductionStatus(.tCurrent, .tState, 2)
    If $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
    Set tCurrent = $Get(tCurrent)
    If tCurrent = "" Quit ""
    If (pProduction '= "") && (pProduction '= tCurrent) Quit ""
    Set tWord = ##class(Ens.Config.Production).ProductionStateToText(+$Get(tState), 0)
    Quit $Select($ListFind($ListFromString(..#LIVEWORDS), tWord): tCurrent, 1: "")
}

/// <p>The host monitor's rows (<code>Ens.Util.Statistics:EnumerateHostStatus</code>) for the hosts the namespace's
/// current production configures, and only while that production is running or troubled
/// (<method>LiveCurrent</method>); <var>pCurrent</var> is that production, <code>""</code> when there are no rows to
/// give. <var>pProduction</var> limits it to that production, and <var>pName</var> to the host of that name. The
/// vendor's own hosts the production does not configure (<code>Ens.Actor</code>, <code>Ens.ScheduleHandler</code>) are
/// left out. <var>pFound(n)</var> is <code>$ListBuild(Name, Type, Status, AdapterState, LastActivity, ElapsedTime,
/// Queue, Count)</code>, at most <var>pMax</var> of them when that is above zero. A fault is <var>pCaught</var>, with
/// the namespace restored. Only vendor classes and this class run while it is switched.</p>
ClassMethod GatherHosts(pNamespace As %String, pProduction As %String, pName As %String, pMax As %Integer, Output pCurrent As %String, ByRef pFound, Output pCaught) As %Status [ Private ]
{
    Kill pFound
    Set pFound = 0
    Set pCurrent = ""
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tCurrent = ..LiveCurrent(pProduction)
        If tCurrent '= "" {
            Set pCurrent = tCurrent
            Kill tNames
            Set tProduction = ##class(Ens.Config.Production).%OpenId(tCurrent)
            If $IsObject(tProduction) {
                For tI = 1:1:tProduction.Items.Count() {
                    Set tItem = tProduction.Items.GetAt(tI)
                    If $IsObject(tItem) Set tNames(tItem.Name) = ""
                }
            }
            Set tItem = ""
            Set tProduction = ""
            Set tResult = ##class(%ResultSet).%New("Ens.Util.Statistics:EnumerateHostStatus")
            Set tExecuteSC = tResult.Execute()
            If $$$ISERR(tExecuteSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tExecuteSC)
            While tResult.Next() {
                Set tHost = tResult.GetData(1)
                If '$Data(tNames(tHost)) Continue
                If (pName '= "") && (tHost '= pName) Continue
                If (pMax > 0) && (pFound >= pMax) Quit
                Set pFound($Increment(pFound)) = $ListBuild(tHost, tResult.GetData(2), tResult.GetData(3), tResult.GetData(4), tResult.GetData(5), tResult.GetData(6), tResult.GetData(7), tResult.GetData(8))
            }
            Do tResult.Close()
            Set tResult = ""
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The host monitor's row <var>pLine</var> (<method>GatherHosts</method>'s element) of production
/// <var>pProduction</var> as the monitor answers it: <code>{Production, Item, Name, Type, Status, AdapterState,
/// LastActivity, ElapsedTime, Queue, Count}</code>, <code>Item</code> the item's <code>Production||Name</code> and
/// <code>LastActivity</code> the instance's local clock time as the log readers write it. Runs in the install
/// namespace.</p>
ClassMethod HostRow(pProduction As %String, pLine As %List) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Production", pProduction, "string")
    Do tRow.%Set("Item", pProduction _ "||" _ $List(pLine, 1), "string")
    Do tRow.%Set("Name", $List(pLine, 1) _ "", "string")
    Do tRow.%Set("Type", $List(pLine, 2) _ "", "string")
    Do tRow.%Set("Status", $List(pLine, 3) _ "", "string")
    Do tRow.%Set("AdapterState", $List(pLine, 4) _ "", "string")
    Do tRow.%Set("LastActivity", ##class(OcuPilot.Port.LogSourcePort).ClockStamp($List(pLine, 5)), "string")
    Do tRow.%Set("ElapsedTime", +$List(pLine, 6), "number")
    Do tRow.%Set("Queue", +$List(pLine, 7), "number")
    Do tRow.%Set("Count", +$List(pLine, 8), "number")
    Quit tRow
}

/// <p>The production monitor (Story 20.4): one row per host the namespace's running or troubled production configures
/// (<method>GatherHosts</method>, <method>HostRow</method>), none while it is not running.</p>
ClassMethod ListMonitor(pNamespace As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..GatherHosts(pNamespace, "", "", pMax, .tCurrent, .tFound, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the production monitor failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..HostRow(tCurrent, tFound(tI)))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>One item's status (Story 20.4): <code>{Production, Name, ClassName, Type, Enabled, Status, AdapterState,
/// LastActivity}</code> as one row. The first five are the item's configuration (<var>pLine</var>,
/// <method>GatherItems</method>'s element, as <method>ItemRow</method> gives them); the last three are its host
/// monitor row's, and empty while the item's production is not the namespace's running or troubled one or the monitor
/// holds no host of the name.</p>
ClassMethod ReadItemStatus(pNamespace As %String, pProduction As %String, pLine As %List, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..GatherHosts(pNamespace, pProduction, $List(pLine, 1), 1, .tCurrent, .tFound, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item status failed", .pHttpStatus, .pFault)
    Set tRow = ..ItemRow(pProduction, pLine)
    For tKey = "EnabledSource", "PoolSize", "Category", "Comment" {
        Do tRow.%Remove(tKey)
    }
    Set tHost = $Select(tFound > 0: ..HostRow(pProduction, tFound(1)), 1: {})
    For tKey = "Status", "AdapterState", "LastActivity" {
        Do tRow.%Set(tKey, $Select(tHost.%IsDefined(tKey): tHost.%Get(tKey), 1: ""), "string")
    }
    Set pRows = [(tRow)]
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The job rows of the host <var>pHost</var>, or of every host <code>Ens.Util.Statistics:EnumerateHostStatus</code>
/// answers when it is empty (the vendor's own hosts the production does not configure included, unlike
/// <method>GatherHosts</method>), only while the namespace's production is running or troubled and, when
/// <var>pProduction</var> is given, is that production: <var>pFound(n)</var> is <code>Ens.Util.Statistics:EnumerateJobStatus</code>'s row
/// <code>$ListBuild(Name, Job, Status, AdapterState, LastActivity, Count, Method, Retry, ActiveMessage)</code>, at most
/// <var>pMax</var> when that is above zero. With <var>pJob</var> only the job of that process id is kept, across every host.
/// <var>pCurrent</var> is the production they belong to, <code>""</code> when there are none to give. A fault is
/// <var>pCaught</var>, with the namespace restored.</p>
ClassMethod GatherJobs(pNamespace As %String, pProduction As %String, pHost As %String, pMax As %Integer, Output pCurrent As %String, ByRef pFound, Output pCaught, pJob As %String = "") As %Status [ Private ]
{
    Kill pFound
    Set pFound = 0
    Set pCurrent = ""
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tCurrent = ..LiveCurrent(pProduction)
        If tCurrent '= "" {
            Set pCurrent = tCurrent
            Kill tHosts
            If pHost '= "" {
                Set tHosts(1) = pHost
                Set tHosts = 1
            } Else {
                Set tHosts = 0
                Set tHostResult = ##class(%ResultSet).%New("Ens.Util.Statistics:EnumerateHostStatus")
                Set tHostSC = tHostResult.Execute()
                If $$$ISERR(tHostSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tHostSC)
                While tHostResult.Next() {
                    Set tHosts($Increment(tHosts)) = tHostResult.GetData(1)
                }
                Do tHostResult.Close()
                Set tHostResult = ""
            }
            For tH = 1:1:tHosts {
                If (pMax > 0) && (pFound >= pMax) Quit
                If (pJob '= "") && pFound Quit
                Set tResult = ##class(%ResultSet).%New("Ens.Util.Statistics:EnumerateJobStatus")
                Set tExecuteSC = tResult.Execute(tHosts(tH))
                If $$$ISERR(tExecuteSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tExecuteSC)
                While tResult.Next() {
                    If (pMax > 0) && (pFound >= pMax) Quit
                    If (pJob '= "") && (tResult.GetData(2) '= pJob) Continue
                    Set pFound($Increment(pFound)) = $ListBuild(tResult.GetData(1), tResult.GetData(2), tResult.GetData(3), tResult.GetData(4), tResult.GetData(5), tResult.GetData(6), tResult.GetData(7), tResult.GetData(8), tResult.GetData(9))
                }
                Do tResult.Close()
                Set tResult = ""
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The job row <var>pLine</var> (<method>GatherJobs</method>'s element) as the Jobs reads answer it: <code>{Job,
/// Host, Status, AdapterState, LastActivity, Retry, ActiveMessage, Dead}</code>. <code>Dead</code> is true when no
/// process holds the job (<code>^$JOB</code>), the vendor's ghost ids among them: such a row is answered and never
/// repaired. With <var>pProduction</var> the row also carries <code>Production</code> and <code>Item</code>
/// (<code>Production||Host</code>). Pure but for the process table.</p>
ClassMethod JobRow(pLine As %List, pProduction As %String = "") As %DynamicObject
{
    Set tJob = $List(pLine, 2) _ ""
    Set tRow = {}
    If pProduction '= "" {
        Do tRow.%Set("Production", pProduction, "string")
        Do tRow.%Set("Item", pProduction _ "||" _ $List(pLine, 1), "string")
    }
    Do tRow.%Set("Job", tJob, "string")
    Do tRow.%Set("Host", $List(pLine, 1) _ "", "string")
    Do tRow.%Set("Status", $List(pLine, 3) _ "", "string")
    Do tRow.%Set("AdapterState", $List(pLine, 4) _ "", "string")
    Do tRow.%Set("LastActivity", ##class(OcuPilot.Port.LogSourcePort).ClockStamp($List(pLine, 5)), "string")
    Do tRow.%Set("Retry", +$List(pLine, 8), "number")
    Do tRow.%Set("ActiveMessage", $List(pLine, 9) _ "", "string")
    Set tDead = 1
    If tJob '= "" Set tDead = '$Data(^$JOB(tJob))
    Do tRow.%Set("Dead", ''tDead, "boolean")
    Quit tRow
}

/// <p>The running production's jobs (Story 20.4): every host's, or with <var>pHost</var> one item's of
/// <var>pProduction</var>; none while the production is not running or troubled. A job no process holds is answered
/// <code>Dead</code> (<method>JobRow</method>).</p>
ClassMethod ListJobs(pNamespace As %String, pProduction As %String, pHost As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..GatherJobs(pNamespace, pProduction, pHost, pMax, .tCurrent, .tFound, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the job list failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..JobRow(tFound(tI), $Select(pHost '= "": tCurrent, 1: "")))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The namespace's queues and the count of active messages in each (Story 20.4): <code>{Name, Count, Active,
/// Created}</code> from <code>Ens.Queue:Enumerate</code>, <code>Active</code> the jobs of the host of that name that
/// hold a message (<code>Ens.Util.Statistics:EnumerateJobStatus</code>), at most <var>pMax</var> when that is above
/// zero. A queue of a stopped production still lists, as the vendor's query lists it. With <var>pName</var> only the queue
/// of exactly that name is answered.</p>
ClassMethod ListQueues(pNamespace As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pName As %String = "") As %Status [ Private ]
{
    Set pRows = ""
    Set tCaught = ""
    Kill tFound
    Set tFound = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tResult = ##class(%ResultSet).%New("Ens.Queue:Enumerate")
        Set tExecuteSC = tResult.Execute()
        If $$$ISERR(tExecuteSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tExecuteSC)
        While tResult.Next() {
            If (pMax > 0) && (tFound >= pMax) Quit
            Set tName = tResult.GetData(1)
            If (pName '= "") && (tName '= pName) Continue
            Set tActive = 0
            Set tJobs = ##class(%ResultSet).%New("Ens.Util.Statistics:EnumerateJobStatus")
            Set tJobSC = tJobs.Execute(tName)
            If $$$ISERR(tJobSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tJobSC)
            While tJobs.Next() {
                If tJobs.GetData(9) '= "" Set tActive = tActive + 1
            }
            Do tJobs.Close()
            Set tJobs = ""
            Set tFound($Increment(tFound)) = $ListBuild(tName, tResult.GetData(2), tActive, tResult.GetData(3))
        }
        Do tResult.Close()
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the queue list failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Set tRow = {}
        Do tRow.%Set("Name", $List(tFound(tI), 1) _ "", "string")
        Do tRow.%Set("Count", +$List(tFound(tI), 2), "number")
        Do tRow.%Set("Active", +$List(tFound(tI), 3), "number")
        Do tRow.%Set("Created", ##class(OcuPilot.Port.LogSourcePort).ClockStamp($List(tFound(tI), 4)), "string")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The queue an item's messages wait in, and the target that tells them apart from the other messages of that
/// queue (Story 20.4). A business process of pool size 0 shares <parameter>ACTORQUEUE</parameter> with the others of
/// its kind, so its queue is that one and <var>pTarget</var> is the item's name; any other item's is
/// <code>Ens.Config.Item.QueueName()</code> and <var>pTarget</var> is <code>""</code>. <var>pItem</var> is an
/// <code>Ens.Config.Item</code>, typed <code>%RegisteredObject</code> so the class compiles where interoperability is not
/// enabled (AD-62 item 12). Called while the production's namespace is switched; only vendor classes run.</p>
ClassMethod ItemQueueName(pItem As %RegisteredObject, Output pTarget As %String) As %String
{
    Set pTarget = ""
    If (pItem.BusinessType() = 2) && (+pItem.PoolSize = 0) {
        Set pTarget = pItem.Name
        Quit ..#ACTORQUEUE
    }
    Quit pItem.QueueName()
}

/// <p>The queue of the item <var>pItem</var> of <var>pProduction</var> (<method>ItemQueueName</method>) in
/// <var>pQueue</var> and its target in <var>pTarget</var>; both <code>""</code> when the production or the item is not
/// there. <var>pCurrent</var> is whether <var>pProduction</var> is the production the namespace has current (running,
/// troubled or suspended), the only one whose queues the item reads, as the classic configuration page reads them. A fault
/// is <var>pCaught</var>, with the namespace restored.</p>
ClassMethod QueueOf(pNamespace As %String, pProduction As %String, pItem As %String, Output pQueue As %String, Output pTarget As %String, Output pCurrent As %Boolean, Output pCaught) As %Status [ Private ]
{
    Set pQueue = ""
    Set pTarget = ""
    Set pCurrent = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tProduction = ##class(Ens.Config.Production).%OpenId(pProduction)
        If $IsObject(tProduction) {
            Set tItem = ..ItemObject(tProduction, pItem)
            If $IsObject(tItem) Set pQueue = ..ItemQueueName(tItem, .pTarget)
        }
        Set tItem = ""
        Set tProduction = ""
        Set tStatusSC = ##class(Ens.Director).GetProductionStatus(.tCurrent, .tState, 2)
        If $$$ISERR(tStatusSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tStatusSC)
        Set pCurrent = ($Get(tCurrent) = pProduction)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The entries of the queue <var>pQueue</var> (<code>Ens.Queue:EnumerateItem</code>), each joined to its message
/// header (<code>%OpenId</code>): <var>pFound(n)</var> is <code>$ListBuild(Priority, Index, MessageId, Source, Target,
/// BodyClass, TimeCreated, Status)</code>, <code>Status</code> the display word. With <var>pTarget</var> an entry whose
/// header names another target is left out; an entry whose header is gone is kept with empty fields. At most
/// <var>pMax</var> are kept when that is above zero, and at most <parameter>QUEUESCANMAX</parameter> are examined.</p>
/// <p>With <var>pMessageId</var> only the entry holding that message is kept, and the walk stops at it. With
/// <var>pBare</var> no header is opened, so each element carries its priority, index and message id alone and
/// <var>pTarget</var> is not applied (a queue abort's enumeration, Story 20.23). A fault is <var>pCaught</var>, with the
/// namespace restored. Only vendor classes and this class run while it is switched.</p>
ClassMethod GatherQueueEntries(pNamespace As %String, pQueue As %String, pTarget As %String, pMax As %Integer, ByRef pFound, Output pCaught, pMessageId As %String = "", pBare As %Boolean = 0) As %Status [ Private ]
{
    Kill pFound
    Set pFound = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tResult = ##class(%ResultSet).%New("Ens.Queue:EnumerateItem")
        Set tExecuteSC = tResult.Execute(pQueue)
        If $$$ISERR(tExecuteSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tExecuteSC)
        Set tScanned = 0
        While tResult.Next() {
            Set tScanned = tScanned + 1
            If tScanned > ..#QUEUESCANMAX Quit
            Set tMessageId = tResult.GetData(3)
            If (pMessageId '= "") && (tMessageId '= pMessageId) Continue
            Set (tSource, tTarget, tBody, tCreated, tStatus) = ""
            If 'pBare {
                Set tHeader = ##class(Ens.MessageHeader).%OpenId(tMessageId)
                If $IsObject(tHeader) {
                    Set tSource = tHeader.SourceConfigName
                    Set tTarget = tHeader.TargetConfigName
                    Set tBody = tHeader.MessageBodyClassName
                    Set tCreated = tHeader.TimeCreated
                    Set tStatus = ##class(Ens.DataType.MessageStatus).LogicalToDisplay(tHeader.Status)
                }
                Set tHeader = ""
                If (pTarget '= "") && (tTarget '= "") && (tTarget '= pTarget) Continue
            }
            If (pMax > 0) && (pFound >= pMax) Quit
            Set pFound($Increment(pFound)) = $ListBuild(tResult.GetData(1), tResult.GetData(2), tMessageId, tSource, tTarget, tBody, tCreated, tStatus)
            If pMessageId '= "" Quit
        }
        Do tResult.Close()
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>A UTC <code>YYYY-MM-DD HH:MM:SS[.fff]</code> as the instance's local clock time in the form the log readers
/// write it (<method>OcuPilot.Port.LogSourcePort.LocalFromUtc</method>); <code>""</code> for a value that is not
/// one. The vendor's own queries answer the local time, and a header's and a log row's stamps are UTC, so the
/// Queue, Log and Messages tabs convert theirs. Runs in the install namespace.</p>
ClassMethod LocalStamp(pUtc As %String) As %String [ Private ]
{
    Quit ##class(OcuPilot.Port.LogSourcePort).LocalFromUtc(pUtc)
}

/// <p>The queue entry <var>pLine</var> (<method>GatherQueueEntries</method>'s element) of queue <var>pQueue</var> as the
/// queue reads answer it: <code>{Queue, Priority, Index, MessageId, Source, Target, BodyClass, TimeCreated,
/// Status}</code>; with <var>pProduction</var> and <var>pItem</var> it also carries <code>Production</code> and
/// <code>Item</code> (<code>Production||Item</code>). Runs in the install namespace.</p>
ClassMethod QueueEntryRow(pQueue As %String, pLine As %List, pProduction As %String = "", pItem As %String = "") As %DynamicObject [ Private ]
{
    Set tRow = {}
    If pProduction '= "" {
        Do tRow.%Set("Production", pProduction, "string")
        Do tRow.%Set("Item", pProduction _ "||" _ pItem, "string")
    }
    Do tRow.%Set("Queue", pQueue, "string")
    Do tRow.%Set("Priority", +$List(pLine, 1), "number")
    Do tRow.%Set("Index", +$List(pLine, 2), "number")
    Do tRow.%Set("MessageId", $List(pLine, 3) _ "", "string")
    Do tRow.%Set("Source", $List(pLine, 4) _ "", "string")
    Do tRow.%Set("Target", $List(pLine, 5) _ "", "string")
    Do tRow.%Set("BodyClass", $List(pLine, 6) _ "", "string")
    Do tRow.%Set("TimeCreated", ..LocalStamp($List(pLine, 7)), "string")
    Do tRow.%Set("Status", $List(pLine, 8) _ "", "string")
    Quit tRow
}

/// <p>The entries of queue <var>pQueue</var> with their headers (Story 20.4): <method>GatherQueueEntries</method>'s,
/// <method>QueueEntryRow</method>'s. With <var>pProduction</var> and <var>pItem</var> the rows carry that item as their
/// parent.</p>
ClassMethod ListQueueEntries(pNamespace As %String, pQueue As %String, pTarget As %String, pProduction As %String, pItem As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..GatherQueueEntries(pNamespace, pQueue, pTarget, pMax, .tFound, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the queue entries failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..QueueEntryRow(pQueue, tFound(tI), pProduction, pItem))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>An item's queue (Story 20.4): the entries of the queue <method>ItemQueueName</method> names for the item
/// <var>pItem</var> of <var>pProduction</var>, with their headers; none when <var>pProduction</var> is not the namespace's
/// current production, whose queue of that name is another item's.</p>
ClassMethod ItemQueueEntries(pNamespace As %String, pProduction As %String, pItem As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..QueueOf(pNamespace, pProduction, pItem, .tQueue, .tTarget, .tCurrent, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item's queue could not be named", .pHttpStatus, .pFault)
    If tQueue = "" Quit ..Absent(.pHttpStatus, .pFault)
    If 'tCurrent {
        Set pRows = []
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Quit ..ListQueueEntries(pNamespace, tQueue, tTarget, pProduction, pItem, pMax, .pRows, .pHttpStatus, .pFault)
}

/// <p>Run the statement <var>pSql</var> in <var>pNamespace</var> with the values <var>pArgs</var> bound, through
/// <code>%SQL.Statement:%ExecDirectNoPriv</code>: the vendor's grants on the interoperability tables are not kept per
/// namespace (a holder of every read resource was answered SQLCODE -99), so the port's gate is the whole gate and runs
/// first (AD-29). <var>pSql</var> nests no query that carries <code>TOP</code>: compiled cold, such a statement is refused
/// SQLCODE -99 to a caller with no SQL privilege on the table even through <code>%ExecDirectNoPriv</code> (measured).
/// <var>pFound(n)</var> is the row as a <code>%List</code> of its columns. A fault is <var>pCaught</var>, with the namespace
/// restored.</p>
ClassMethod SqlRows(pNamespace As %String, pSql As %String, ByRef pFound, Output pCaught, pArgs...) As %Status [ Private ]
{
    Kill pFound
    Set pFound = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(.tStatement, pSql, pArgs...)
        If '$IsObject(tResult) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the statement answered no result"))
        If tResult.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLCode, tResult.%SQLCODE, tResult.%Message))
        Set tColumns = tResult.%ResultColumnCount
        While tResult.%Next(.tNextSC) {
            Set tLine = ""
            For tC = 1:1:tColumns {
                Set tLine = tLine _ $ListBuild(tResult.%GetData(tC))
            }
            Set pFound($Increment(pFound)) = tLine
        }
        If $$$ISERR($Get(tNextSC, $$$OK)) Throw ##class(%Exception.StatusException).CreateFromStatus(tNextSC)
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The rows of the Log tab's statement: the item's event log rows newest first, as the classic configuration page's
/// own query reads them (<code>EnsPortal.Utils</code>), with the type as its display word. The stamp is read as stored, in
/// UTC: <code>%EXTERNAL</code> would convert it to the reading process's zone, and <method>LocalStamp</method> does that
/// once.</p>
Parameter LOGSQL = "SELECT TOP ? ID, TimeLogged, %EXTERNAL(Type), Text, Job, SessionId FROM Ens_Util.Log WHERE ConfigName = ? ORDER BY ID DESC";

/// <p>The rows of the Messages tab's statement: the newest headers sourced by the item and the newest targeted at it, as
/// the classic configuration page's Messages tab reads them (<code>EnsPortal.ProductionConfig</code>), as two top-level
/// branches because <method>SqlRows</method> takes no nested <code>TOP</code>. Each branch's <code>ORDER BY</code> orders
/// that branch alone (measured), so its <code>TOP</code> takes its newest; the two together come in no order, and a header
/// that is both comes twice (a <code>UNION</code> would fold the names to upper case); <method>ListItemMessages</method>
/// merges, orders and caps them. Both branches read the same columns. The stamp is read as stored, as the Log
/// statement's is.</p>
Parameter MESSAGESQL = "SELECT TOP ? ID, TimeCreated, %EXTERNAL(Status), SourceConfigName, TargetConfigName, MessageBodyClassName, SessionId FROM Ens.MessageHeader WHERE SourceConfigName = ? ORDER BY ID DESC UNION ALL SELECT TOP ? ID, TimeCreated, %EXTERNAL(Status), SourceConfigName, TargetConfigName, MessageBodyClassName, SessionId FROM Ens.MessageHeader WHERE TargetConfigName = ? ORDER BY ID DESC";

/// <p>The most rows a statement of the Log or Messages tab asks for when the call gives no cap.</p>
Parameter SQLMAX = 1000;

/// <p>The item's event log (Story 20.4): <code>{Production, Item, ID, TimeLogged, Type, Text, Job, SessionId}</code>,
/// newest first, at most <var>pMax</var> (<parameter>SQLMAX</parameter> when that is not above zero). The rows are the
/// ones whose <code>ConfigName</code> is the item's name: the vendor keeps no production on a log row, so an item of a
/// production that is not current reads the rows of any item of that name, as the classic page does. Every value is
/// bound, and <code>TimeLogged</code> is the instance's local clock time (<method>LocalStamp</method>).</p>
ClassMethod ListItemLog(pNamespace As %String, pProduction As %String, pItem As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tTop = $Select(pMax > 0: pMax, 1: ..#SQLMAX)
    Set tSC = ..SqlRows(pNamespace, ..#LOGSQL, .tFound, .tCaught, tTop, pItem)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item's event log failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Set tLine = tFound(tI)
        Set tRow = {}
        Do tRow.%Set("Production", pProduction, "string")
        Do tRow.%Set("Item", pProduction _ "||" _ pItem, "string")
        Do tRow.%Set("ID", $List(tLine, 1) _ "", "string")
        Do tRow.%Set("TimeLogged", ..LocalStamp($List(tLine, 2)), "string")
        Do tRow.%Set("Type", $List(tLine, 3) _ "", "string")
        Do tRow.%Set("Text", $List(tLine, 4) _ "", "string")
        Do tRow.%Set("Job", $List(tLine, 5) _ "", "string")
        Do tRow.%Set("SessionId", $List(tLine, 6) _ "", "string")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The item's message headers (Story 20.4): <code>{Production, Item, ID, TimeCreated, Status, Source, Target,
/// BodyClass, SessionId}</code>, newest first, the headers sourced by the item's name and those targeted at it (a
/// header names no production, as a log row does not), at most <var>pMax</var> (<parameter>SQLMAX</parameter> when that
/// is not above zero). No body or contents are read. Every value is bound, and <code>TimeCreated</code> is the instance's local clock time (<method>LocalStamp</method>).</p>
ClassMethod ListItemMessages(pNamespace As %String, pProduction As %String, pItem As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tTop = $Select(pMax > 0: pMax, 1: ..#SQLMAX)
    Set tSC = ..SqlRows(pNamespace, ..#MESSAGESQL, .tFound, .tCaught, tTop, pItem, tTop, pItem)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item's messages failed", .pHttpStatus, .pFault)
    For tI = 1:1:tFound {
        Set tById(+$List(tFound(tI), 1)) = tFound(tI)
    }
    Set pRows = []
    Set tCount = 0
    Set tId = $Order(tById(""), -1)
    While (tId '= "") && (tCount < tTop) {
        Set tCount = tCount + 1
        Set tLine = tById(tId)
        Set tId = $Order(tById(tId), -1)
        Do pRows.%Push(..MessageRow(tLine, pProduction, pItem))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>One message header's row, built from <var>pLine</var>, a statement's columns in the order <code>ID, TimeCreated,
/// Status (display word), Source, Target, BodyClass, SessionId</code> and, for <var>pSearch</var>, <code>Type (display
/// word), IsError</code> after them: <code>{ID, TimeCreated, Status, Source, Target, BodyClass, SessionId}</code>, with
/// <code>Production</code> and <code>Item</code> (<code>Production||Item</code>) first when <var>pProduction</var> is given and
/// <code>Type</code> and <code>Error</code> (a boolean) last for a search. <code>TimeCreated</code> is the instance's local clock
/// time (<method>LocalStamp</method>). Shared by the item's Messages tab and the Messages search (Story 20.9). Runs in the
/// install namespace.</p>
ClassMethod MessageRow(pLine As %List, pProduction As %String = "", pItem As %String = "", pSearch As %Boolean = 0) As %DynamicObject [ Private ]
{
    Set tRow = {}
    If pProduction '= "" {
        Do tRow.%Set("Production", pProduction, "string")
        Do tRow.%Set("Item", pProduction _ "||" _ pItem, "string")
    }
    Do tRow.%Set("ID", $List(pLine, 1) _ "", "string")
    Do tRow.%Set("TimeCreated", ..LocalStamp($List(pLine, 2)), "string")
    Do tRow.%Set("Status", $List(pLine, 3) _ "", "string")
    Do tRow.%Set("Source", $List(pLine, 4) _ "", "string")
    Do tRow.%Set("Target", $List(pLine, 5) _ "", "string")
    Do tRow.%Set("BodyClass", $List(pLine, 6) _ "", "string")
    Do tRow.%Set("SessionId", $List(pLine, 7) _ "", "string")
    If pSearch {
        Do tRow.%Set("Type", $List(pLine, 8) _ "", "string")
        Do tRow.%Set("Error", ''$List(pLine, 9), "boolean")
    }
    Quit tRow
}

/// <p>The statements of the message reads (Story 20.9). The first two give the window's ID bounds, as the classic message viewer
/// finds them (<code>EnsPortal.MsgFilter.Assistant</code>): the first header created at or after the start and the last created
/// at or before the end. They are separate top-level statements, because a nested <code>TOP</code> is refused on a cold cached
/// query (<method>SqlRows</method>). Each bound value is a UTC stamp in the stored form.</p>
Parameter LOWERIDSQL = "SELECT TOP 1 %ID FROM Ens.MessageHeader WHERE TimeCreated >= ? ORDER BY TimeCreated ASC, %ID ASC";

Parameter UPPERIDSQL = "SELECT TOP 1 %ID FROM Ens.MessageHeader WHERE TimeCreated <= ? ORDER BY TimeCreated DESC, %ID DESC";

/// <p>The search statement's head: the newest headers from the window's first ID, with the columns
/// <method>MessageRow</method> builds a search row from. <method>ListMessages</method> adds a fixed fragment for each criterion
/// given, in a fixed order, and <code>ORDER BY ID DESC</code>.</p>
Parameter SEARCHSQL = "SELECT TOP ? ID, TimeCreated, %EXTERNAL(Status), SourceConfigName, TargetConfigName, MessageBodyClassName, SessionId, %EXTERNAL(Type), IsError FROM Ens.MessageHeader WHERE ID >= ?";

/// <p>One header's twenty-three properties, in <parameter>HEADERFIELDS</parameter>' order: the enumerations as their display
/// words, the stamps as stored (UTC) for <method>LocalStamp</method>, and <code>ErrorStatus</code> as stored for
/// <method>ErrorText</method>.</p>
Parameter HEADERSQL = "SELECT ID, %EXTERNAL(Type), %EXTERNAL(Priority), %EXTERNAL(Invocation), TimeCreated, TimeProcessed, %EXTERNAL(Status), IsError, ErrorStatus, SourceConfigName, TargetConfigName, %EXTERNAL(SourceBusinessType), %EXTERNAL(TargetBusinessType), SessionId, SuperSession, CorrespondingMessageId, BusinessProcessId, TargetQueueName, ReturnQueueName, MessageBodyClassName, MessageBodyId, Description, Resent FROM Ens.MessageHeader WHERE ID = ?";

/// <p>The header properties a Header read answers, in order (Story 20.9). Their order is the rows' <code>Position</code>.</p>
Parameter HEADERFIELDS = "ID,Type,Priority,Invocation,TimeCreated,TimeProcessed,Status,IsError,ErrorStatus,SourceConfigName,TargetConfigName,SourceBusinessType,TargetBusinessType,SessionId,SuperSession,CorrespondingMessageId,BusinessProcessId,TargetQueueName,ReturnQueueName,MessageBodyClassName,MessageBodyId,Description,Resent";

/// <p>The statement that names a header's body.</p>
Parameter BODYSQL = "SELECT MessageBodyClassName, MessageBodyId FROM Ens.MessageHeader WHERE ID = ?";

/// <p>The display words of a header's status and type, in the order of their stored values (1 to 9, and 1 to 2): the fixed map a
/// search criterion is turned into its stored value by. <code>Terminate</code>, the vendor's third type, is not searched.</p>
Parameter STATUSWORDS = "Created,Queued,Delivered,Discarded,Suspended,Deferred,Aborted,Error,Completed";

Parameter TYPEWORDS = "Request,Response";

/// <p>The longest line a contents read answers, in characters; a longer line ends with <parameter>TESTCUT</parameter>.</p>
Parameter CONTENTLINEMAX = 4000;

/// <p>The shape of a message header's id: digits, not beginning with zero, kept exactly (AD-13).</p>
Parameter MESSAGEIDPATTERN = "^[1-9][0-9]{0,18}$";

/// <p>The shape of a class name.</p>
Parameter CLASSNAMEPATTERN = "^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$";

/// <p>The sentence a refused message criterion carries: its name, then what it must be (Story 20.9).</p>
ClassMethod MessageCriterionReason(pName As %String) As %String
{
    If pName = "beginDateTime" Quit pName _ " is required, as a local date and time written YYYY-MM-DD HH:MM:SS."
    If pName = "endDateTime" Quit pName _ " must be a local date and time, written YYYY-MM-DD HH:MM:SS."
    If pName = "status" Quit pName _ " must be one of " _ $Replace(..#STATUSWORDS, ",", ", ") _ "."
    If pName = "type" Quit pName _ " must be Request or Response."
    If pName = "session" Quit pName _ " must be digits."
    If pName = "bodyClass" Quit pName _ " must be a class name."
    If pName = "errors" Quit pName _ " must be yes or no."
    If pName = "message" Quit pName _ " must be a message header's ID: digits, not beginning with zero."
    If pName = "hours" Quit pName _ " must be a whole number from 1 to " _ ..#SESSIONHOURSMAX _ "."
    ; A session search names its status criterion as a list; the reason is spelled under its own key so a message search's keeps its sentence.
    If pName = "statusList" Quit "status must name one to nine of " _ $Replace(..#STATUSWORDS, ",", ", ") _ "."
    If pName = "superSession" Quit "Give either superSession or session, not both and not neither."
    If pName = "className" Quit pName _ " must be a class name."
    If pName = "match" Quit pName _ " must be any, source, target or body."
    If pName = "Messages" Quit pName _ " must name 1 to " _ ..#RESENDMAX _ " message header IDs, separated by commas: digits, not beginning with zero."
    If pName = "separator" Quit pName _ " must be one of " _ $Replace(..#EXPORTSEPARATORS, ",", ", ") _ "."
    If pName = "charset" Quit pName _ " must be one of the character sets this instance lists."
    Quit pName _ " is not valid."
}

/// <p>Refuse the message criterion <var>pName</var> by name: 400 <code>PORT.VALIDATION</code> (Story 20.9).</p>
ClassMethod RefuseCriterion(pName As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..MessageCriterionReason(pName), .pHttpStatus, .pFault)
}

/// <p>A local <code>YYYY-MM-DD HH:MM:SS[.fff]</code> as the UTC stamp a header's <code>TimeCreated</code> is stored as,
/// <code>YYYY-MM-DD HH:MM:SS</code>, or <code>""</code> for a value that is not one (<method>OcuPilot.Kernel.Audit.Ledger.LocalToUtc</method>).
/// Runs in the install namespace.</p>
ClassMethod StoredStamp(pLocal As %String) As %String [ Private ]
{
    Set tUtc = ##class(OcuPilot.Kernel.Audit.Ledger).LocalToUtc(pLocal)
    If tUtc = "" Quit ""
    Quit $Translate($Extract(tUtc, 1, 19), "T", " ")
}

/// <p>The message headers matching a search, newest first, at most <var>pMax</var> (<parameter>SQLMAX</parameter> when that is
/// not above zero), as <method>MessageRow</method> builds them with its search columns (Story 20.9). <var>pQuery</var> carries the
/// criteria, each optional but <code>beginDateTime</code>:</p>
/// <ul>
/// <li><code>beginDateTime</code> (required) and <code>endDateTime</code>: instance local times, turned into the window's ID bounds by
/// <parameter>LOWERIDSQL</parameter> and <parameter>UPPERIDSQL</parameter>, the end taken to the last millisecond of its second as the
/// classic viewer takes it. A bound that finds no header means no row.</li>
/// <li><code>status</code> and <code>type</code>: display words, turned into stored values by <parameter>STATUSWORDS</parameter> and
/// <parameter>TYPEWORDS</parameter>.</li>
/// <li><code>source</code>, <code>target</code> and <code>bodyClass</code>: matched whole, in any letter case (the columns'
/// collation); <code>session</code>: digits; <code>errors</code>: <code>yes</code> or <code>no</code>.</li>
/// </ul>
/// <p>A criterion of the wrong shape is 400 <code>PORT.VALIDATION</code> naming it, and nothing is read. Every value is bound; the
/// statement is the head <parameter>SEARCHSQL</parameter> and one fixed fragment for each criterion given, so no caller value reaches
/// SQL text (AD-21).</p>
ClassMethod ListMessages(pNamespace As %String, ByRef pQuery, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tTop = $Select(pMax > 0: pMax, 1: ..#SQLMAX)
    Set tBegin = ..StoredStamp($Get(pQuery("beginDateTime")))
    If tBegin = "" Quit ..RefuseCriterion("beginDateTime", .pHttpStatus, .pFault)
    Set tEnd = ""
    If $Get(pQuery("endDateTime")) '= "" {
        Set tEnd = ..StoredStamp(pQuery("endDateTime"))
        If tEnd = "" Quit ..RefuseCriterion("endDateTime", .pHttpStatus, .pFault)
        Set tEnd = tEnd _ ".999"
    }
    Set tStatus = $Get(pQuery("status"))
    Set tStatusValue = $Select(tStatus = "": "", 1: $ListFind($ListFromString(..#STATUSWORDS), tStatus))
    If (tStatus '= "") && 'tStatusValue Quit ..RefuseCriterion("status", .pHttpStatus, .pFault)
    Set tType = $Get(pQuery("type"))
    Set tTypeValue = $Select(tType = "": "", 1: $ListFind($ListFromString(..#TYPEWORDS), tType))
    If (tType '= "") && 'tTypeValue Quit ..RefuseCriterion("type", .pHttpStatus, .pFault)
    Set tSession = $Get(pQuery("session"))
    If (tSession '= "") && '$Match(tSession, "^[0-9]{1,19}$") Quit ..RefuseCriterion("session", .pHttpStatus, .pFault)
    Set tBodyClass = $Get(pQuery("bodyClass"))
    If (tBodyClass '= "") && '$Match(tBodyClass, ..#CLASSNAMEPATTERN) Quit ..RefuseCriterion("bodyClass", .pHttpStatus, .pFault)
    Set tErrors = $Get(pQuery("errors"))
    If (tErrors '= "") && (tErrors '= "yes") && (tErrors '= "no") Quit ..RefuseCriterion("errors", .pHttpStatus, .pFault)

    Set tSC = ..SqlRows(pNamespace, ..#LOWERIDSQL, .tLower, .tCaught, tBegin)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the message window's first header could not be found", .pHttpStatus, .pFault)
    Set tUpperId = ""
    If tLower && (tEnd '= "") {
        Set tSC = ..SqlRows(pNamespace, ..#UPPERIDSQL, .tUpper, .tCaught, tEnd)
        If $IsObject(tCaught) Quit ..Mapped(tCaught, "the message window's last header could not be found", .pHttpStatus, .pFault)
        If tUpper Set tUpperId = +$List(tUpper(1), 1)
    }
    If 'tLower || ((tEnd '= "") && (tUpperId = "")) {
        Set pRows = []
        Set pHttpStatus = 200
        Quit $$$OK
    }

    Set tSql = ..#SEARCHSQL
    Kill tArgs
    Set tArgs = 2
    Set tArgs(1) = tTop
    Set tArgs(2) = +$List(tLower(1), 1)
    If tUpperId '= "" Set tSql = tSql _ " AND ID <= ?", tArgs($Increment(tArgs)) = tUpperId
    If tStatusValue Set tSql = tSql _ " AND Status = ?", tArgs($Increment(tArgs)) = tStatusValue
    If tTypeValue Set tSql = tSql _ " AND Type = ?", tArgs($Increment(tArgs)) = tTypeValue
    If $Get(pQuery("source")) '= "" Set tSql = tSql _ " AND SourceConfigName = ?", tArgs($Increment(tArgs)) = pQuery("source")
    If $Get(pQuery("target")) '= "" Set tSql = tSql _ " AND TargetConfigName = ?", tArgs($Increment(tArgs)) = pQuery("target")
    If tBodyClass '= "" Set tSql = tSql _ " AND MessageBodyClassName = ?", tArgs($Increment(tArgs)) = tBodyClass
    If tSession '= "" Set tSql = tSql _ " AND SessionId = ?", tArgs($Increment(tArgs)) = +tSession
    If tErrors '= "" Set tSql = tSql _ " AND IsError = ?", tArgs($Increment(tArgs)) = (tErrors = "yes")
    Set tSql = tSql _ " ORDER BY ID DESC"
    Set tSC = ..SqlRows(pNamespace, tSql, .tFound, .tCaught, tArgs...)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the message search failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..MessageRow(tFound(tI), "", "", 1))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The two statements of the session trace (Story 20.30), each top-level (<method>SqlRows</method> takes no nested
/// <code>TOP</code>): the session of one header, and that session's headers in <code>ID</code> order with the columns
/// <method>MessageRow</method> builds a search row from. The second binds the cap first, then the session;
/// <method>ListSessionMessages</method> reads it too, its <code>ORDER BY</code> moved after the bounds it adds.</p>
Parameter TRACESESSIONSQL = "SELECT SessionId FROM Ens.MessageHeader WHERE ID = ?";

Parameter TRACESQL = "SELECT TOP ? ID, TimeCreated, %EXTERNAL(Status), SourceConfigName, TargetConfigName, MessageBodyClassName, SessionId, %EXTERNAL(Type), IsError FROM Ens.MessageHeader WHERE SessionId = ? ORDER BY ID";

/// <p>The whole session of the message header <var>pId</var> (Story 20.30): every header that shares its <code>SessionId</code>, in
/// <code>ID</code> order, at most <var>pMax</var> (<parameter>SQLMAX</parameter> when that is not above zero) of them, as
/// <method>MessageRow</method> builds a search row, with <code>Message</code> (<var>pId</var>) and <code>Step</code> (1 to n in
/// <code>ID</code> order, a JSON number) added. A header that is gone, or one saved with no session, reads as no rows (AD-37); the
/// id's shape is judged by the caller. Every value is bound. The trace reads no event, rule or I/O log entry, which the classic
/// Visual Trace adds, and, like the classic page, does not follow <code>SuperSession</code>.</p>
ClassMethod ListMessageTrace(pNamespace As %String, pId As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tTop = $Select(pMax > 0: pMax, 1: ..#SQLMAX)
    Set tSC = ..SqlRows(pNamespace, ..#TRACESESSIONSQL, .tSession, .tCaught, +pId)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the message's session could not be read", .pHttpStatus, .pFault)
    Set tSessionId = $Select(tSession: $List(tSession(1), 1), 1: "")
    Set pRows = []
    Set pHttpStatus = 200
    If tSessionId = "" Quit $$$OK
    Set tSC = ..SqlRows(pNamespace, ..#TRACESQL, .tFound, .tCaught, tTop, +tSessionId)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the message's trace failed", .pHttpStatus, .pFault)
    For tI = 1:1:tFound {
        Set tRow = ..MessageRow(tFound(tI), "", "", 1)
        Do tRow.%Set("Message", pId, "string")
        Do tRow.%Set("Step", tI, "number")
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

/// <p>The widest window a session search spans, in hours, and the one it takes when the call names none (Story 24.4).</p>
Parameter SESSIONHOURSMAX = 720;

Parameter SESSIONHOURSDEFAULT = 24;

/// <p>What a session search leads on, comma-separated: the window kinds <parameter>SESSIONWINDOWKINDS</parameter> name, and the keyed kinds
/// <code>session</code>, <code>supersession</code> and <code>related</code>, which take no window.</p>
Parameter SESSIONKINDS = "time,status,source,target,bodyclass,class,session,supersession,related";

Parameter SESSIONWINDOWKINDS = "time,status,source,target,bodyclass,class";

/// <p>The columns of a session search, one row per session: its id, the earliest creation time, the lowest source, target and body class
/// names and the lowest status among its matching headers, and how many of those headers there are and how many are errors. Every
/// session statement is <code>SELECT TOP ?</code>, these columns, a <code>FROM</code> and <code>WHERE</code> chosen from fixed
/// fragments, and <parameter>SESSIONTAIL</parameter>.</p>
Parameter SESSIONCOLUMNS = "mh.SessionId, MIN(mh.TimeCreated), MIN(%EXACT(mh.SourceConfigName)), MIN(%EXACT(mh.TargetConfigName)), MIN(%EXACT(mh.MessageBodyClassName)), MIN(mh.Status), COUNT(*), SUM(mh.IsError)";

Parameter SESSIONTAIL = " GROUP BY mh.SessionId ORDER BY MIN(mh.TimeCreated) DESC, mh.SessionId DESC";

/// <p>The super-session key of the session a call names: the key the vendor's index holds for any of its headers.</p>
Parameter SESSIONKEYSQL = "SELECT TOP 1 ssi.SuperSession FROM Ens.SuperSessionIndex ssi JOIN Ens.MessageHeader mh ON ssi.MessageHeader = mh.ID WHERE mh.SessionId = ?";

/// <p>The two statements of a session summary, each top-level: the session's counts and time span, and its first header's body class.</p>
Parameter SUMMARYSQL = "SELECT COUNT(*), SUM(IsError), MIN(TimeCreated), MAX(TimeCreated) FROM Ens.MessageHeader WHERE SessionId = ?";

Parameter SUMMARYROOTSQL = "SELECT TOP 1 MessageBodyClassName FROM Ens.MessageHeader WHERE SessionId = ? ORDER BY ID";

/// <p>The window of a session search as ID bounds: <var>pLower</var> and <var>pUpper</var>, the first header created at or after the
/// window's start and the last created at or before its end, as <method>ListMessages</method> finds them, both <code>""</code> when
/// the namespace holds no header at one of them. The window is <code>hours</code> (whole, 1 to <parameter>SESSIONHOURSMAX</parameter>,
/// <parameter>SESSIONHOURSDEFAULT</parameter> when absent) ending at <code>endDateTime</code> (the instance's local time, now when
/// absent), the end taken to the last millisecond of its second. A criterion of the wrong shape is 400 <code>PORT.VALIDATION</code>
/// naming it, and nothing is read.</p>
ClassMethod SessionWindow(pNamespace As %String, ByRef pQuery, Output pLower As %String, Output pUpper As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pLower = ""
    Set pUpper = ""
    Set tHours = $Get(pQuery("hours"))
    If tHours = "" Set tHours = ..#SESSIONHOURSDEFAULT
    If '$Match(tHours, "^[1-9][0-9]{0,3}$") || (tHours > ..#SESSIONHOURSMAX) Quit ..RefuseCriterion("hours", .pHttpStatus, .pFault)
    If $Get(pQuery("endDateTime")) '= "" {
        Set tEnd = ..StoredStamp(pQuery("endDateTime"))
        If tEnd = "" Quit ..RefuseCriterion("endDateTime", .pHttpStatus, .pFault)
    } Else {
        Set tEnd = $Extract($ZDateTime($ZTimeStamp, 3, 1), 1, 19)
    }
    Set tHoro = $ZDateTimeH(tEnd, 3)
    Set tDays = $Piece(tHoro, ",", 1)
    Set tSeconds = $Piece(tHoro, ",", 2) - (tHours * 3600)
    While tSeconds < 0 {
        Set tSeconds = tSeconds + 86400
        Set tDays = tDays - 1
    }
    Set tBegin = $ZDateTime(tDays _ "," _ tSeconds, 3)
    Set tSC = ..SqlRows(pNamespace, ..#LOWERIDSQL, .tLower, .tCaught, tBegin)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the session window's first header could not be found", .pHttpStatus, .pFault)
    Set tSC = ..SqlRows(pNamespace, ..#UPPERIDSQL, .tUpper, .tCaught, tEnd _ ".999")
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the session window's last header could not be found", .pHttpStatus, .pFault)
    If tLower && tUpper {
        Set pLower = +$List(tLower(1), 1)
        Set pUpper = +$List(tUpper(1), 1)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>One session search row from <var>pLine</var>, <parameter>SESSIONCOLUMNS</parameter>' values in order: <code>{SessionId, FirstTime,
/// Source, Target, BodyClass, Status, Messages, Errors}</code>, the id as a string kept exactly, <code>FirstTime</code> the instance's
/// local clock time (<method>LocalStamp</method>), <code>Status</code> a display word and the two counts JSON numbers.</p>
ClassMethod SessionRow(pLine As %List) As %DynamicObject [ Private ]
{
    Set tStatus = +$List(pLine, 6)
    Set tRow = {}
    Do tRow.%Set("SessionId", $List(pLine, 1) _ "", "string")
    Do tRow.%Set("FirstTime", ..LocalStamp($List(pLine, 2)), "string")
    Do tRow.%Set("Source", $List(pLine, 3) _ "", "string")
    Do tRow.%Set("Target", $List(pLine, 4) _ "", "string")
    Do tRow.%Set("BodyClass", $List(pLine, 5) _ "", "string")
    Do tRow.%Set("Status", $Select((tStatus >= 1) && (tStatus <= 9): $List($ListFromString(..#STATUSWORDS), tStatus), 1: ""), "string")
    Do tRow.%Set("Messages", +$List(pLine, 7), "number")
    Do tRow.%Set("Errors", +$List(pLine, 8), "number")
    Quit tRow
}

/// <p>The sessions a search finds, newest first, at most <var>pMax</var> (<parameter>SQLMAX</parameter> when that is not above zero), as
/// <method>SessionRow</method> builds them (Story 24.4). <var>pQuery</var>("kind") is one of <parameter>SESSIONKINDS</parameter> and
/// names the criteria the search takes:</p>
/// <ul>
/// <li><code>time</code>: none beyond the window. <code>status</code>: <code>status</code>, one to nine display words, comma-separated.
/// <code>source</code>, <code>target</code> and <code>bodyclass</code>: <code>source</code>, <code>target</code> and <code>bodyClass</code>,
/// matched whole, in any letter case. <code>class</code>: <code>className</code>, matched against the source, target and body class
/// columns, or one of them by <code>match</code> (<code>any</code>, <code>source</code>, <code>target</code> or <code>body</code>).
/// Each of these also takes <code>hours</code> and <code>endDateTime</code> (<method>SessionWindow</method>).</li>
/// <li><code>session</code>: <code>session</code>, digits. <code>supersession</code>: either <code>superSession</code> or <code>session</code>,
/// whose own key is used. <code>related</code>: <code>session</code>, the sessions that share its key, without it. These take no
/// window, and a session with no key reads as no rows.</li>
/// </ul>
/// <p>A criterion of the wrong shape is 400 <code>PORT.VALIDATION</code> naming it, and nothing is read. Every value is bound; the
/// statement is <parameter>SESSIONCOLUMNS</parameter>, a fixed <code>FROM</code> and <code>WHERE</code> and
/// <parameter>SESSIONTAIL</parameter>, so no caller value reaches SQL text (AD-21). A super-session key is matched on the index's own
/// collation, <code>%SQLUPPER(250)</code>, and then on the whole value.</p>
ClassMethod ListSessions(pNamespace As %String, ByRef pQuery, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tTop = $Select(pMax > 0: pMax, 1: ..#SQLMAX)
    Set tKind = $Get(pQuery("kind"))
    If '$ListFind($ListFromString(..#SESSIONKINDS), tKind) Quit ..RefuseCriterion("kind", .pHttpStatus, .pFault)
    Kill tValues
    Set tValues = 0
    Set tFrom = "Ens.MessageHeader mh"
    Set tWhere = ""
    Set tNoRows = 0
    If $ListFind($ListFromString(..#SESSIONWINDOWKINDS), tKind) {
        Set tFragment = ""
        If tKind = "status" {
            Set tWords = $ListFromString($Get(pQuery("status")))
            Set tMarks = ""
            Kill tSeen
            Set tBad = (($Get(pQuery("status")) = "") || ($ListLength(tWords) > 9))
            For tI = 1:1:$ListLength(tWords) {
                If tBad Quit
                Set tNumber = $ListFind($ListFromString(..#STATUSWORDS), $List(tWords, tI))
                If 'tNumber {
                    Set tBad = 1
                    Quit
                }
                If $Data(tSeen(tNumber)) Continue
                Set tSeen(tNumber) = ""
                Set tMarks = tMarks _ $Select(tMarks = "": "?", 1: ", ?")
                Set tValues($Increment(tValues)) = tNumber
            }
            If tBad Quit ..RefuseCriterion("statusList", .pHttpStatus, .pFault)
            Set tFragment = " AND mh.Status IN (" _ tMarks _ ")"
        } ElseIf (tKind = "source") || (tKind = "target") {
            Set tName = $Get(pQuery(tKind))
            If (tName = "") || ($Length(tName) > 256) Quit ..RefuseCriterion(tKind, .pHttpStatus, .pFault)
            Set tFragment = " AND mh." _ $Select(tKind = "source": "SourceConfigName", 1: "TargetConfigName") _ " = ?"
            Set tValues($Increment(tValues)) = tName
        } ElseIf tKind = "bodyclass" {
            Set tBodyClass = $Get(pQuery("bodyClass"))
            If '$Match(tBodyClass, ..#CLASSNAMEPATTERN) Quit ..RefuseCriterion("bodyClass", .pHttpStatus, .pFault)
            Set tFragment = " AND mh.MessageBodyClassName = ?"
            Set tValues($Increment(tValues)) = tBodyClass
        } ElseIf tKind = "class" {
            Set tClass = $Get(pQuery("className"))
            If '$Match(tClass, ..#CLASSNAMEPATTERN) Quit ..RefuseCriterion("className", .pHttpStatus, .pFault)
            Set tMatch = $Get(pQuery("match"), "any")
            If tMatch = "" Set tMatch = "any"
            If tMatch = "any" {
                Set tFragment = " AND (mh.SourceConfigName = ? OR mh.TargetConfigName = ? OR mh.MessageBodyClassName = ?)"
                For tI = 1:1:3 Set tValues($Increment(tValues)) = tClass
            } ElseIf tMatch = "source" {
                Set tFragment = " AND mh.SourceConfigName = ?"
                Set tValues($Increment(tValues)) = tClass
            } ElseIf tMatch = "target" {
                Set tFragment = " AND mh.TargetConfigName = ?"
                Set tValues($Increment(tValues)) = tClass
            } ElseIf tMatch = "body" {
                Set tFragment = " AND mh.MessageBodyClassName = ?"
                Set tValues($Increment(tValues)) = tClass
            } Else {
                Quit ..RefuseCriterion("match", .pHttpStatus, .pFault)
            }
        }
        Set tSC = ..SessionWindow(pNamespace, .pQuery, .tLower, .tUpper, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        Set tNoRows = (tLower = "")
        Set tWhere = "mh.ID >= ? AND mh.ID <= ? AND mh.SessionId IS NOT NULL" _ tFragment
        Kill tHeld
        Merge tHeld = tValues
        Kill tValues
        Set tValues = 2
        Set tValues(1) = tLower
        Set tValues(2) = tUpper
        For tI = 1:1:+$Get(tHeld) Set tValues($Increment(tValues)) = tHeld(tI)
    } Else {
        Set tSeed = $Get(pQuery("session"))
        If (tKind = "supersession") && ((tSeed = "") = ($Get(pQuery("superSession")) = "")) Quit ..RefuseCriterion("superSession", .pHttpStatus, .pFault)
        If (tSeed '= "") || (tKind '= "supersession") {
            If '$Match(tSeed, "^[0-9]{1,19}$") Quit ..RefuseCriterion("session", .pHttpStatus, .pFault)
        }
        If tKind = "session" {
            Set tWhere = "mh.SessionId = ?"
            Set tValues($Increment(tValues)) = +tSeed
        } Else {
            Set tKey = $Select(tKind = "supersession": $Get(pQuery("superSession")), 1: "")
            If $Length(tKey) > 300 Quit ..RefuseCriterion("superSession", .pHttpStatus, .pFault)
            If tKey = "" {
                Set tSC = ..SqlRows(pNamespace, ..#SESSIONKEYSQL, .tKeyFound, .tCaught, +tSeed)
                If $IsObject(tCaught) Quit ..Mapped(tCaught, "the session's super-session could not be read", .pHttpStatus, .pFault)
                If tKeyFound Set tKey = $List(tKeyFound(1), 1) _ ""
            }
            Set tNoRows = (tKey = "")
            Set tFrom = "Ens.SuperSessionIndex ssi JOIN Ens.MessageHeader mh ON ssi.MessageHeader = mh.ID"
            Set tWhere = "%SQLUPPER(ssi.SuperSession, 250) = %SQLUPPER(?, 250) AND ssi.SuperSession = ? AND mh.SessionId IS NOT NULL"
            Set tValues($Increment(tValues)) = tKey
            Set tValues($Increment(tValues)) = tKey
            If tKind = "related" {
                Set tWhere = tWhere _ " AND mh.SessionId <> ?"
                Set tValues($Increment(tValues)) = +tSeed
            }
        }
    }
    Set pRows = []
    Set pHttpStatus = 200
    If tNoRows Quit $$$OK
    Kill tArgs
    Set tArgs = 1
    Set tArgs(1) = tTop
    For tI = 1:1:tValues Set tArgs($Increment(tArgs)) = tValues(tI)
    Set tSql = "SELECT TOP ? " _ ..#SESSIONCOLUMNS _ " FROM " _ tFrom _ " WHERE " _ tWhere _ ..#SESSIONTAIL
    Set tSC = ..SqlRows(pNamespace, tSql, .tFound, .tCaught, tArgs...)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the session search failed", .pHttpStatus, .pFault)
    For tI = 1:1:tFound {
        Do pRows.%Push(..SessionRow(tFound(tI)))
    }
    Quit $$$OK
}

/// <p>The summary of the session <var>pQuery</var>("session") names (Story 24.4), one row <code>{SessionId, Messages, Errors, FirstTime,
/// LastTime, Seconds, RootBodyClass}</code>: the header count and error count, the earliest and latest creation time as the instance's
/// local clock time, the seconds between them as a JSON number, and the body class of the session's first header. A session no header
/// holds reads as no rows (AD-37); a session that is not 1 to 19 digits is 400 <code>PORT.VALIDATION</code> naming <code>session</code>.</p>
ClassMethod ReadSessionSummary(pNamespace As %String, ByRef pQuery, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSession = $Get(pQuery("session"))
    If '$Match(tSession, "^[0-9]{1,19}$") Quit ..RefuseCriterion("session", .pHttpStatus, .pFault)
    Set tSC = ..SqlRows(pNamespace, ..#SUMMARYSQL, .tFound, .tCaught, +tSession)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the session's summary could not be read", .pHttpStatus, .pFault)
    Set pRows = []
    Set pHttpStatus = 200
    If 'tFound || (+$List(tFound(1), 1) = 0) Quit $$$OK
    Set tLine = tFound(1)
    Set tSC = ..SqlRows(pNamespace, ..#SUMMARYROOTSQL, .tRoot, .tCaught, +tSession)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the session's first header could not be read", .pHttpStatus, .pFault)
    Set tFirst = $ZDateTimeH($List(tLine, 3), 3)
    Set tLast = $ZDateTimeH($List(tLine, 4), 3)
    Set tSeconds = (($Piece(tLast, ",", 1) - $Piece(tFirst, ",", 1)) * 86400) + ($Piece(tLast, ",", 2) - $Piece(tFirst, ",", 2))
    Set tRow = {}
    Do tRow.%Set("SessionId", (+tSession) _ "", "string")
    Do tRow.%Set("Messages", +$List(tLine, 1), "number")
    Do tRow.%Set("Errors", +$List(tLine, 2), "number")
    Do tRow.%Set("FirstTime", ..LocalStamp($List(tLine, 3)), "string")
    Do tRow.%Set("LastTime", ..LocalStamp($List(tLine, 4)), "string")
    Do tRow.%Set("Seconds", +$FNumber(tSeconds, "", 3), "number")
    Do tRow.%Set("RootBodyClass", $Select(tRoot: $List(tRoot(1), 1) _ "", 1: ""), "string")
    Do pRows.%Push(tRow)
    Quit $$$OK
}

/// <p>The headers of the session <var>pQuery</var>("session") names, in <code>ID</code> order, at most <var>pMax</var>
/// (<parameter>SQLMAX</parameter> when that is not above zero) of them, as <method>MessageRow</method> builds a search row with
/// <code>Step</code> (1 to n in the order answered, a JSON number) added (Story 24.4). <code>beginDateTime</code> and
/// <code>endDateTime</code>, the instance's local time, bound the headers' creation time, the end taken to the last millisecond of its
/// second; <code>errors</code> is <code>yes</code> for the error headers alone. A criterion of the wrong shape is 400
/// <code>PORT.VALIDATION</code> naming it, and a session no header holds reads as no rows (AD-37). Every value is bound.</p>
ClassMethod ListSessionMessages(pNamespace As %String, ByRef pQuery, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tTop = $Select(pMax > 0: pMax, 1: ..#SQLMAX)
    Set tSession = $Get(pQuery("session"))
    If '$Match(tSession, "^[0-9]{1,19}$") Quit ..RefuseCriterion("session", .pHttpStatus, .pFault)
    ; The session trace's statement without its ORDER BY: a fixed fragment is added for each bound the call gives, then the order.
    Set tSql = $Piece(..#TRACESQL, " ORDER BY ", 1)
    Kill tArgs
    Set tArgs = 2
    Set tArgs(1) = tTop
    Set tArgs(2) = +tSession
    If $Get(pQuery("beginDateTime")) '= "" {
        Set tBegin = ..StoredStamp(pQuery("beginDateTime"))
        If tBegin = "" Quit ..RefuseCriterion("beginDateTime", .pHttpStatus, .pFault)
        Set tSql = tSql _ " AND TimeCreated >= ?"
        Set tArgs($Increment(tArgs)) = tBegin
    }
    If $Get(pQuery("endDateTime")) '= "" {
        Set tEnd = ..StoredStamp(pQuery("endDateTime"))
        If tEnd = "" Quit ..RefuseCriterion("endDateTime", .pHttpStatus, .pFault)
        Set tSql = tSql _ " AND TimeCreated <= ?"
        Set tArgs($Increment(tArgs)) = tEnd _ ".999"
    }
    Set tErrors = $Get(pQuery("errors"))
    If (tErrors '= "") && (tErrors '= "yes") && (tErrors '= "no") Quit ..RefuseCriterion("errors", .pHttpStatus, .pFault)
    If tErrors '= "" {
        Set tSql = tSql _ " AND IsError = ?"
        Set tArgs($Increment(tArgs)) = (tErrors = "yes")
    }
    Set tSql = tSql _ " ORDER BY ID"
    Set tSC = ..SqlRows(pNamespace, tSql, .tFound, .tCaught, tArgs...)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the session's headers could not be read", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Set tRow = ..MessageRow(tFound(tI), "", "", 1)
        Do tRow.%Set("Step", tI, "number")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p><var>pStatus</var>, a header's stored <code>ErrorStatus</code>, as its error text, or <code>""</code> when it is empty or
/// reads OK. Runs in the install namespace.</p>
ClassMethod ErrorText(pStatus As %String) As %String [ Private ]
{
    If pStatus = "" Quit ""
    Set tText = ""
    Try {
        If '$System.Status.IsOK(pStatus) Set tText = $System.Status.GetErrorText(pStatus)
    } Catch {
        Set tText = ""
    }
    Quit tText
}

/// <p>The header <var>pId</var> as <code>{Message, Position, Name, Value}</code> rows, one for each of the twenty-three properties
/// in <parameter>HEADERFIELDS</parameter>' order, <code>Position</code> from 1 (a JSON number) and every <code>Value</code> a string:
/// the enumerations as display words, <code>TimeCreated</code> and <code>TimeProcessed</code> as the instance's local clock time
/// (<method>LocalStamp</method>), and <code>ErrorStatus</code> as its error text (<method>ErrorText</method>). An id no header holds
/// reads as no rows (AD-37). The id's shape is judged by the caller.</p>
ClassMethod ReadMessageHeader(pNamespace As %String, pId As %String, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..SqlRows(pNamespace, ..#HEADERSQL, .tFound, .tCaught, +pId)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the message header could not be read", .pHttpStatus, .pFault)
    Set pRows = []
    If tFound {
        Set tLine = tFound(1)
        Set tNames = $ListFromString(..#HEADERFIELDS)
        For tI = 1:1:$ListLength(tNames) {
            Set tName = $List(tNames, tI)
            Set tValue = $List(tLine, tI)
            If (tName = "TimeCreated") || (tName = "TimeProcessed") {
                Set tValue = ..LocalStamp(tValue)
            } ElseIf tName = "ErrorStatus" {
                Set tValue = ..ErrorText(tValue)
            }
            Set tRow = {}
            Do tRow.%Set("Message", pId, "string")
            Do tRow.%Set("Position", tI, "number")
            Do tRow.%Set("Name", tName, "string")
            Do tRow.%Set("Value", tValue _ "", "string")
            Do pRows.%Push(tRow)
        }
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Whether the message body <var>pClass</var> <var>pBodyId</var> is there: the class name has a class name's shape, the class
/// is compiled here and holds the id. <code>0</code> for a header that names no body, which is no body gone. Called while the
/// message's namespace is switched; nothing is opened.</p>
ClassMethod BodyExistsHere(pClass As %String, pBodyId As %String) As %Boolean [ Private ]
{
    If (pClass = "") || (pBodyId = "") || '$Match(pClass, ..#CLASSNAMEPATTERN) Quit 0
    If '##class(%Dictionary.CompiledClass).%ExistsId(pClass) Quit 0
    Set tExists = 0
    Try {
        Set tExists = ''$ClassMethod(pClass, "%ExistsId", pBodyId)
    } Catch {
        Set tExists = 0
    }
    Quit tExists
}

/// <p>The object <var>pClass</var> <var>pBodyId</var>, or <code>""</code> when the class is not a compiled persistent or stream class
/// of this namespace or holds no such id (a stream class would open an id it does not hold as an empty stream). The class name is
/// judged by <parameter>CLASSNAMEPATTERN</parameter> before it is called. The opener of a message's body (<method>ContentsText</method>)
/// and of a host test's response (<method>CollectResponseHere</method>). Called while the message's namespace is switched.</p>
ClassMethod OpenBodyHere(pClass As %String, pBodyId As %String) As %RegisteredObject [ Private ]
{
    If '$Match(pClass, ..#CLASSNAMEPATTERN) Quit ""
    If '##class(%Dictionary.CompiledClass).%ExistsId(pClass) Quit ""
    If '($ClassMethod(pClass, "%Extends", "%Library.Persistent") || $ClassMethod(pClass, "%Extends", "%Stream.Object")) Quit ""
    If '$ClassMethod(pClass, "%ExistsId", pBodyId) Quit ""
    Set tObject = ""
    Try {
        Set tObject = $ClassMethod(pClass, "%OpenId", pBodyId)
    } Catch {
        Set tObject = ""
    }
    Quit $Select($IsObject(tObject): tObject, 1: "")
}

/// <p>Record that the body <var>pClass</var> <var>pBodyId</var> of header <var>pHeaderId</var> was viewed, as the classic Contents
/// pane records it: the vendor's own <code>%Ensemble/%Message/ViewContents</code> row, through
/// <code>Ens.Util.Auditing.AuditViewMessage</code>, with the source <code>OcuPilot</code>. The pane skips <code>Ens.AlarmRequest</code>
/// and <code>Ens.AlarmResponse</code>, and so does this. A failure to audit is not a failure to read. Called while the message's
/// namespace is switched.</p>
ClassMethod AuditViewHere(pHeaderId As %String, pClass As %String, pBodyId As %String) [ Private ]
{
    If (pClass = "Ens.AlarmRequest") || (pClass = "Ens.AlarmResponse") Quit
    Try {
        Do ##class(Ens.Util.Auditing).AuditViewMessage("OcuPilot", pHeaderId, pClass, pBodyId)
    } Catch {
    }
}

/// <p>Open the body <var>pClass</var> <var>pBodyId</var> of header <var>pHeaderId</var> in <var>pNamespace</var>, record the view
/// (<method>AuditViewHere</method>), and render it as text in <var>pText</var>. <var>pOutcome</var> is <code>none</code> when the
/// class or the body is not there (nothing is audited), <code>text</code>, or <code>notext</code> for a body that opened and is
/// neither a virtual document, an <parameter>XMLADAPTOR</parameter> object nor a character stream, such as a binary stream; the view
/// of a <code>notext</code> body has been recorded. A fault is <var>pCaught</var>, with the namespace restored. Only vendor classes
/// and this class run while it is switched.</p>
ClassMethod ContentsText(pNamespace As %String, pHeaderId As %String, pClass As %String, pBodyId As %String, Output pOutcome As %String, Output pText As %String, Output pCaught) As %Status [ Private ]
{
    Set pOutcome = "none"
    Set pText = ""
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tObject = ..OpenBodyHere(pClass, pBodyId)
        If $IsObject(tObject) {
            Do ..AuditViewHere(pHeaderId, pClass, pBodyId)
            Set pOutcome = "notext"
            If tObject.%Extends("%Stream.Object") {
                If tObject.IsCharacter() {
                    Do tObject.Rewind()
                    Set pText = ..StreamText(tObject)
                    Set pOutcome = "text"
                }
            } ElseIf $$$ISOK(..RenderTargetHere(tObject, .pText)) {
                Set pOutcome = "text"
            } Else {
                Set pText = ""
            }
        }
        Set tObject = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The message <var>pId</var>'s body as text lines (Story 20.9): <code>{Message, Line, Text}</code>, <code>Line</code> from 1 (a
/// JSON number), at most <var>pMax</var> (<parameter>SQLMAX</parameter> when that is not above zero) of them, each cut at
/// <parameter>CONTENTLINEMAX</parameter> characters with <parameter>TESTCUT</parameter>, and the whole text cut at
/// <parameter>TESTOUTPUTMAX</parameter> characters, which sets <var>pCut</var>. The text is split on <code>CRLF</code>, <code>LF</code> or <code>CR</code>, and a
/// final terminator ends the last line. A header that is gone, one that names no body and a body that no longer opens read as no rows,
/// and record no view. A body that opens is recorded (<method>AuditViewHere</method>) before it is rendered
/// (<method>ContentsText</method>); one that is not text is 409 <parameter>OcuPilot.Api.InteropError.MESSAGECONTENTS</parameter>. The
/// id's shape is judged by the caller.</p>
ClassMethod ReadMessageContents(pNamespace As %String, pId As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pCut As %Boolean) As %Status [ Private ]
{
    Set pRows = ""
    Set pCut = 0
    Set tTop = $Select(pMax > 0: pMax, 1: ..#SQLMAX)
    Set tSC = ..SqlRows(pNamespace, ..#BODYSQL, .tFound, .tCaught, +pId)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the message's body could not be named", .pHttpStatus, .pFault)
    Set tClass = $Select(tFound: $List(tFound(1), 1) _ "", 1: "")
    Set tBodyId = $Select(tFound: $List(tFound(1), 2) _ "", 1: "")
    Set pRows = []
    Set pHttpStatus = 200
    If (tClass = "") || (tBodyId = "") Quit $$$OK
    Set tSC = ..ContentsText(pNamespace, pId, tClass, tBodyId, .tOutcome, .tText, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the message's body could not be shown", .pHttpStatus, .pFault)
    If tOutcome = "notext" {
        Set pRows = ""
        Quit ..Conflict(##class(OcuPilot.Api.InteropError).#MESSAGECONTENTS, .pHttpStatus, .pFault)
    }
    If tOutcome '= "text" Quit $$$OK
    If $Length(tText) > ..#TESTOUTPUTMAX {
        Set tText = $Extract(tText, 1, ..#TESTOUTPUTMAX) _ ..#TESTCUT
        Set pCut = 1
    }
    Set tText = $Replace($Replace(tText, $Char(13, 10), $Char(10)), $Char(13), $Char(10))
    If $Extract(tText, *) = $Char(10) Set tText = $Extract(tText, 1, *-1)
    Set tPos = 1
    Set tLength = $Length(tText)
    If tLength = 0 Quit $$$OK
    For tLine = 1:1:tTop {
        If tPos > (tLength + 1) Quit
        Set tEndAt = $Find(tText, $Char(10), tPos)
        If tEndAt = 0 {
            Set tPiece = $Extract(tText, tPos, tLength)
            Set tPos = tLength + 2
        } Else {
            Set tPiece = $Extract(tText, tPos, tEndAt - 2)
            Set tPos = tEndAt
        }
        If $Length(tPiece) > ..#CONTENTLINEMAX Set tPiece = $Extract(tPiece, 1, ..#CONTENTLINEMAX) _ ..#TESTCUT
        Set tRow = {}
        Do tRow.%Set("Message", pId, "string")
        Do tRow.%Set("Line", tLine, "number")
        Do tRow.%Set("Text", tPiece, "string")
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

/// <p>The SHA-256 of <var>pText</var>, taken as UTF-8, as lower-case hex. Pure.</p>
ClassMethod Sha256Hex(pText As %String) As %String
{
    Quit $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.SHAHash(256, $ZConvert(pText, "O", "UTF8"))), "L")
}

/// <p>The message header ids <var>pText</var> names (Story 20.31, AD-13), in <var>pIds</var> as a <class>%List</class>: comma-separated
/// ids, each of the shape <parameter>MESSAGEIDPATTERN</parameter> once its surrounding blanks are taken off, each named once whatever
/// the repeats, in ascending order. Answers 1 for 1 to <parameter>RESENDMAX</parameter> ids, else 0 with <var>pIds</var>
/// <code>""</code>: an empty set, a member of another shape (<code>0x1</code>, <code>007</code>, an empty one) and a set over the cap
/// are each refused whole, never cut. Once every member has that shape, the set is the <code>interop-message</code> entity's own
/// canonical spelling (<method>OcuPilot.Kernel.EntityRef.NormalizedId</method>, AD-13), so no id is read as a number. Pure.</p>
ClassMethod MessageSet(pText As %String, Output pIds As %List) As %Boolean
{
    Set pIds = ""
    If pText = "" Quit 0
    For tI = 1:1:$Length(pText, ",") {
        If '$Match($ZStrip($Piece(pText, ",", tI), "<>W"), ..#MESSAGEIDPATTERN) Return 0
    }
    Set tCanonical = ##class(OcuPilot.Kernel.EntityRef).NormalizedId(..#ENTITYMESSAGE, pText)
    If $Length(tCanonical, ",") > ..#RESENDMAX Quit 0
    Set pIds = $ListFromString(tCanonical, ",")
    Quit 1
}

/// <p>The one verdict a message reads before a resend (Story 20.31), checked in this order, the first that holds winning:
/// <code>gone</code> when no header has the id (<var>pExists</var> 0); <code>nobody</code> when the header names a body class and id
/// and the body is no longer there (<var>pBodyGone</var>); <code>targetoff</code> for a request (<var>pType</var>
/// <code>Request</code>) whose target is not an enabled item of the running production (<var>pEnabledTarget</var> 0), which the
/// vendor queues and answers OK for (measured); <code>noreplyqueue</code> for any other type, a response, whose reply queue no longer
/// exists (<var>pReplyQueue</var> 0); else <code>resend</code>. <var>pType</var> is the display word.</p>
/// <p>For a suspended message (Story 24.16) <var>pKind</var> is the action, <code>resubmit</code>, <code>edit</code>, <code>discard</code> or
/// <code>delete</code> (<method>SuspendedKind</method>), and a header that is not <var>pSuspended</var> reads <code>notsuspended</code>
/// straight after <code>gone</code>. A discard and a delete read no body or target and answer the action's own word; a resubmit and an edit
/// are judged as a resend is and answer <code>resubmit</code>.</p>
/// <p>For an export (Story 24.16 Batch 3) <var>pKind</var> is <code>export</code>: after <code>gone</code>, <code>nobody</code> for a header whose body is not there
/// (<var>pBodyGone</var>), <code>notext</code> for a body that cannot be shown as text (<var>pNoText</var>), else <code>export</code>. Pure.</p>
ClassMethod MessageVerdict(pType As %String, pExists As %Boolean, pBodyGone As %Boolean, pEnabledTarget As %Boolean, pReplyQueue As %Boolean, pKind As %String = "", pSuspended As %Boolean = 1, pNoText As %Boolean = 0) As %String
{
    If 'pExists Quit "gone"
    If pKind = "export" {
        If pBodyGone Quit "nobody"
        Quit $Select(pNoText: "notext", 1: "export")
    }
    If (pKind '= "") && 'pSuspended Quit "notsuspended"
    If (pKind = "discard") || (pKind = "delete") Quit pKind
    If pBodyGone Quit "nobody"
    If pType = "Request" {
        If 'pEnabledTarget Quit "targetoff"
    } ElseIf 'pReplyQueue {
        Quit "noreplyqueue"
    }
    Quit $Select(pKind = "": "resend", 1: "resubmit")
}

/// <p>The digest that stands for the verdicts <var>pVerdicts</var> (<code>id=verdict</code> joined by a comma, in id order) of the
/// running production <var>pProduction</var>: the SHA-256 of <code>Production|Verdicts</code> as lower-case hex. The same verdicts in
/// another order give another digest. Pure.</p>
ClassMethod ResendDigest(pProduction As %String, pVerdicts As %String) As %String
{
    Quit ..Sha256Hex(pProduction _ "|" _ pVerdicts)
}

/// <p>The words that say verdict <var>pVerdict</var> (<method>OcuPilot.Api.InteropError.VerdictSentence</method>).</p>
ClassMethod VerdictSentence(pVerdict As %String) As %String
{
    Quit ##class(OcuPilot.Api.InteropError).VerdictSentence(pVerdict)
}

/// <p>The sentence of the interoperability code <var>pCode</var> (<method>OcuPilot.Api.InteropError.ReasonFor</method>), or
/// <code>""</code>. The tools that quote a refusal in a card reach the sentences through the port, as they reach every other fact of the
/// interoperability API.</p>
ClassMethod Sentence(pCode As %String) As %String
{
    Quit ##class(OcuPilot.Api.InteropError).ReasonFor(pCode)
}

/// <p>The words that follow a message id in an outcome line: <code>resent as</code> when <var>pResent</var> is 1, else <code>not
/// resent</code> (<parameter>OcuPilot.Api.InteropError.OUTCOMERESENT</parameter> and <parameter>OUTCOMEFAILED</parameter>).</p>
ClassMethod OutcomeWord(pResent As %Boolean) As %String
{
    Quit $Select(pResent: ##class(OcuPilot.Api.InteropError).#OUTCOMERESENT, 1: ##class(OcuPilot.Api.InteropError).#OUTCOMEFAILED)
}

/// <p>The words that follow a message id in the outcome line of a suspended write (Story 24.16): for the action <var>pKind</var>
/// (<method>SuspendedKind</method>; an edit reads as a resubmit) <code>resubmitted</code>, <code>discarded</code> or <code>deleted</code> when <var>pDone</var> is 1, else
/// <code>not resubmitted</code>, <code>not discarded</code> or <code>not deleted</code> (<class>OcuPilot.Api.InteropError</class>'s <code>OUTCOME</code>
/// parameters).</p>
ClassMethod SuspendedOutcomeWord(pKind As %String, pDone As %Boolean) As %String
{
    If pKind = "discard" Quit $Select(pDone: ##class(OcuPilot.Api.InteropError).#OUTCOMEDISCARDED, 1: ##class(OcuPilot.Api.InteropError).#OUTCOMENOTDISCARDED)
    If pKind = "delete" Quit $Select(pDone: ##class(OcuPilot.Api.InteropError).#OUTCOMEDELETED, 1: ##class(OcuPilot.Api.InteropError).#OUTCOMENOTDELETED)
    If pKind = "export" Quit $Select(pDone: ##class(OcuPilot.Api.InteropError).#OUTCOMEEXPORTED, 1: ##class(OcuPilot.Api.InteropError).#OUTCOMENOTEXPORTED)
    Quit $Select(pDone: ##class(OcuPilot.Api.InteropError).#OUTCOMERESUBMITTED, 1: ##class(OcuPilot.Api.InteropError).#OUTCOMENOTRESUBMITTED)
}

/// <p>The namespace's production while it is running, in <var>pProduction</var> (<code>""</code> when none is: stopped, suspended or
/// troubled), switched by explicit save and restore. A fault, a status the vendor could not read among them, is <var>pCaught</var>,
/// with the namespace restored. Only vendor classes run while the namespace is switched.</p>
ClassMethod RunningProduction(pNamespace As %String, Output pProduction As %String, Output pCaught) As %Status [ Private ]
{
    Set pProduction = ""
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = ##class(Ens.Director).GetProductionStatus(.tCurrent, .tState, 2)
        If $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
        If +$Get(tState) = 1 Set pProduction = $Get(tCurrent)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>Judge the messages <var>pIds</var> (<method>MessageSet</method>'s list) of the running production <var>pProduction</var>
/// (Story 20.31): one <method>MessageVerdict</method> each, read from the header, whether its body is there
/// (<method>HeaderFacts</method>), whether the item its request names is enabled in the production
/// (<method>GatherItems</method>, the effective <code>Enabled</code>) and whether the queue its response replies to exists. Nothing is
/// called that changes anything.</p>
/// <p><var>pRows</var> is one <code>{ID, Type, Source, Target, Verdict}</code> each, in order, the three descriptive members
/// <code>""</code> for a header that is gone; <var>pFacts</var><code>(n)</code> is <code>$ListBuild(ID, Type, Source, Target,
/// BodyClass, BodyId, Verdict)</code>; <var>pVerdicts</var> is <code>id=verdict</code> joined by a comma; <var>pEligible</var> counts
/// <code>resend</code>.</p>
/// <p>For a suspended message (Story 24.16) <var>pKind</var> is the action (<method>MessageVerdict</method>): a header whose status is not
/// Suspended reads <code>notsuspended</code>, <var>pEligible</var> counts the action's own verdict, and a discard or a delete reads no
/// production, so <var>pProduction</var> may be <code>""</code> for them.</p>
ClassMethod JudgeMessages(pNamespace As %String, pProduction As %String, pIds As %List, Output pRows As %DynamicArray, ByRef pFacts, Output pVerdicts As %String, Output pEligible As %Integer, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pKind As %String = "") As %Status [ Private ]
{
    Kill pFacts
    Set pFacts = 0
    Set pRows = ""
    Set pVerdicts = ""
    Set pEligible = 0
    Set tOk = $Select(pKind = "": "resend", (pKind = "edit"): "resubmit", 1: pKind)
    Kill tEnabled
    If (pKind '= "discard") && (pKind '= "delete") && (pKind '= "export") {
        Set tSC = ..GatherItems(pNamespace, pProduction, "", 0, .tExists, .tFound, .tCount, .tCaught)
        If $IsObject(tCaught) Quit ..Mapped(tCaught, "the production's items could not be read", .pHttpStatus, .pFault)
        For tI = 1:1:tFound {
            If $List(tFound(tI), 4) Set tEnabled($ZConvert($List(tFound(tI), 1), "U")) = 1
        }
    }
    Set pRows = []
    For tI = 1:1:$ListLength(pIds) {
        Set tId = $List(pIds, tI)
        Set tSC = ..HeaderFacts(pNamespace, tId, .tHeaderExists, .tQueue, .tStatus, .tCaught, .tType, .tSource, .tTarget, .tBodyClass, .tBodyId, .tBodyExists, .tQueueExists)
        If $IsObject(tCaught) Quit
        Set tBodyGone = tHeaderExists && (tBodyClass '= "") && (tBodyId '= "") && 'tBodyExists
        Set tNoText = 0
        If (pKind = "export") && tHeaderExists {
            Set tBodyGone = ((tBodyClass = "") || (tBodyId = "") || 'tBodyExists)
            If 'tBodyGone Set tNoText = '..TextBodyHere(pNamespace, tBodyClass, tBodyId)
        }
        Set tTargetEnabled = $Select(tTarget = "": 0, 1: ''$Data(tEnabled($ZConvert(tTarget, "U"))))
        Set tVerdict = ..MessageVerdict(tType, tHeaderExists, tBodyGone, tTargetEnabled, tQueueExists, pKind, (tStatus = "Suspended"), tNoText)
        If tVerdict = tOk Set pEligible = pEligible + 1
        Set pVerdicts = pVerdicts _ $Select(pVerdicts = "": "", 1: ",") _ tId _ "=" _ tVerdict
        Set pFacts($Increment(pFacts)) = $ListBuild(tId, tType, tSource, tTarget, tBodyClass, tBodyId, tVerdict)
        Set tRow = {}
        Do tRow.%Set("ID", tId, "string")
        Do tRow.%Set("Type", tType, "string")
        Do tRow.%Set("Source", tSource, "string")
        Do tRow.%Set("Target", tTarget, "string")
        Do tRow.%Set("Verdict", tVerdict, "string")
        Do pRows.%Push(tRow)
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "a message header could not be read", .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>The messages <var>pText</var> names as the resend read answers them (Story 20.31), composed for the action
/// <var>pAction</var> (<code>""</code> for the plain read): <code>{Namespace, Production, Messages: [{ID, Type, Source, Target,
/// Verdict}], Verdicts, Eligible, Reviewed, Digest}</code>. <code>Reviewed</code> is <var>pReviewed</var>, the digest a person
/// reviewed the verdicts at, <code>""</code> for none; <code>Digest</code> is <method>ResendDigest</method>.</p>
/// <p>A set that is not 1 to <parameter>RESENDMAX</parameter> message ids is 400 <code>PORT.VALIDATION</code> naming
/// <code>Messages</code>, before anything is read. A namespace whose production is not running is 409
/// <code>INTEROP.PRODUCTION.NOTRUNNING</code> as a whole. Composed for an action, a <var>pReviewed</var> the verdicts no longer give
/// is 409 <code>INTEROP.RESEND.CHANGED</code>. Whether anything can be resent is the write's to refuse
/// (<method>PerformResend</method>), so a dry run still answers the lines.</p>
/// <p>For a suspended message (Story 24.16) <var>pKind</var> is the action (<method>MessageVerdict</method>); only a resubmit reads the
/// production's state, a discard and a delete answer <code>Production</code> <code>""</code>, and a moved review is 409
/// <code>INTEROP.SUSPENDED.CHANGED</code>.</p>
/// <p>For an export (Story 24.16 Batch 3) <var>pKind</var> is <code>export</code>: only the verdicts are read, no production's state, and a moved review is 409
/// <code>INTEROP.EXPORT.CHANGED</code>.</p>
ClassMethod ReadResend(pNamespace As %String, pText As %String, pAction As %String, pReviewed As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pKind As %String = "") As %Status [ Private ]
{
    Set pRow = ""
    If '..MessageSet(pText, .tIds) Quit ..RefuseCriterion("Messages", .pHttpStatus, .pFault)
    Set tProduction = ""
    If (pKind '= "discard") && (pKind '= "delete") && (pKind '= "export") {
        Set tSC = ..RunningProduction(pNamespace, .tProduction, .tCaught)
        If $IsObject(tCaught) Quit ..Mapped(tCaught, "the production's state could not be read", .pHttpStatus, .pFault)
        If tProduction = "" Quit ..Conflict(##class(OcuPilot.Api.InteropError).#NOTRUNNING, .pHttpStatus, .pFault)
    }
    Set tSC = ..JudgeMessages(pNamespace, tProduction, tIds, .tRows, .tFacts, .tVerdicts, .tEligible, .pHttpStatus, .pFault, pKind)
    If $$$ISERR(tSC) Quit tSC
    Set tDigest = ..ResendDigest(tProduction, tVerdicts)
    If (pAction '= "") && (pReviewed '= "") && (pReviewed '= tDigest) Quit ..Conflict($Select(pKind = "": ##class(OcuPilot.Api.InteropError).#RESENDCHANGED, pKind = "export": ##class(OcuPilot.Api.InteropError).#EXPORTCHANGED, 1: ##class(OcuPilot.Api.InteropError).#SUSPENDEDCHANGED), .pHttpStatus, .pFault)
    Set pRow = {}
    Do pRow.%Set("Namespace", pNamespace, "string")
    Do pRow.%Set("Production", tProduction, "string")
    Do pRow.%Set("Messages", tRows)
    Do pRow.%Set("Verdicts", tVerdicts, "string")
    Do pRow.%Set("Eligible", tEligible, "number")
    Do pRow.%Set("Reviewed", pReviewed, "string")
    Do pRow.%Set("Digest", tDigest, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p><code>Ens.MessageHeader.ResendDuplicatedMessage</code> of the header <var>pId</var> in <var>pNamespace</var>, switched by
/// explicit save and restore: the new header's id in <var>pNewId</var>. A thrown fault is <var>pCaught</var>. Only vendor classes
/// run while it is switched. Overridable so a test can fail one message; production never overrides it.</p>
ClassMethod VendorResend(pNamespace As %String, pId As %String, Output pNewId As %String, Output pCaught) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pNewId = ""
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = ##class(Ens.MessageHeader).ResendDuplicatedMessage(pId, .pNewId)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit tSC
}

/// <p>Resend the messages <var>pText</var> names whose verdict is <code>resend</code> (Story 20.31), one
/// <code>ResendDuplicatedMessage</code> each in ascending id order, and answer <code>{Namespace, Resent, Failed, Messages: [{ID,
/// NewId}|{ID, Error}]}</code>, one entry for each message sent. The set is read and judged again first
/// (<method>ReadResend</method>, composed for this write): a <var>pReviewed</var> the verdicts no longer give is 409
/// <code>INTEROP.RESEND.CHANGED</code>, and no message reading <code>resend</code> is 409 <code>INTEROP.RESEND.NONE</code>, each
/// with nothing sent. A message the vendor refuses is recorded with its text (cut at <parameter>ERRORTEXTMAX</parameter>) and the
/// rest still go; a vendor <code>&lt;PROTECT&gt;</code> stops the write as 403 <code>PORT.ACCESSDENIED</code>. The vendor audits each
/// new header, so this records nothing.</p>
/// <p>For a suspended message (Story 24.16) <var>pKind</var> is <code>resubmit</code>, <code>discard</code> or <code>delete</code>
/// (<method>SuspendedKind</method>): the same read, judgment and loop, each message whose verdict is the action's own acted on by
/// <method>VendorSuspended</method>, the answer <code>{Namespace, Done, Failed, Messages: [{ID}|{ID, Error}]}</code>, no message acted on
/// 409 <code>INTEROP.SUSPENDED.NONE</code> and a moved review 409 <code>INTEROP.SUSPENDED.CHANGED</code>. The vendor audits a resubmit
/// itself; a discard and a delete, which it does not audit, record OcuPilot's own row naming the namespace, the action and the ids done
/// and failed (<method>AuditRuntime</method>), a vendor error text never reaching a log line.</p>
ClassMethod PerformResend(pNamespace As %String, pText As %String, pReviewed As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pKind As %String = "") As %Status [ Private ]
{
    Set pResult = ""
    Set tSuspended = (pKind '= "")
    Set tSC = ..ReadResend(pNamespace, pText, $Select('tSuspended: ..#TYPERESENDMESSAGES, 1: ..SuspendedWriteType(pKind)), pReviewed, .tRow, .pHttpStatus, .pFault, pKind)
    If $$$ISERR(tSC) Quit tSC
    If 'tRow.%Get("Eligible") Quit ..Conflict($Select('tSuspended: ##class(OcuPilot.Api.InteropError).#RESENDNONE, 1: ##class(OcuPilot.Api.InteropError).#SUSPENDEDNONE), .pHttpStatus, .pFault)
    Set tOk = $Select('tSuspended: "resend", 1: pKind)
    Set tSent = []
    Set tResent = 0
    Set tFailed = 0
    Set tStopped = ""
    Set tDone = ""
    Set tNot = ""
    Set tIterator = tRow.%Get("Messages").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMessage) {
        If tMessage.%Get("Verdict") '= tOk Continue
        Set tId = tMessage.%Get("ID")
        Set tNewId = ""
        If tSuspended {
            Set tVendorSC = ..VendorSuspended(pNamespace, pKind, tId, .tCaught)
        } Else {
            Set tVendorSC = ..VendorResend(pNamespace, tId, .tNewId, .tCaught)
        }
        If $IsObject(tCaught) Set tVendorSC = tCaught.AsStatus()
        Set tEntry = {}
        Do tEntry.%Set("ID", tId, "string")
        If $$$ISOK(tVendorSC) {
            If 'tSuspended Do tEntry.%Set("NewId", tNewId _ "", "string")
            Set tResent = tResent + 1
            Set tDone = tDone _ $Select(tDone = "": "", 1: ",") _ tId
        } Else {
            Set tText = $System.Status.GetErrorText(tVendorSC)
            If tText [ "<PROTECT>" {
                Set tStopped = tVendorSC
                Quit
            }
            Do ..LogFault($Select('tSuspended: "a message could not be resent", 1: "a suspended message could not be acted on"), $Select('tSuspended: tVendorSC, 1: ..VendorCodesStatus(tVendorSC)))
            Do tEntry.%Set("Error", $Extract(tText, 1, ..#ERRORTEXTMAX), "string")
            Set tFailed = tFailed + 1
            Set tNot = tNot _ $Select(tNot = "": "", 1: ",") _ tId
        }
        Do tSent.%Push(tEntry)
    }
    Set tAudited = tDone _ $Select((tDone '= "") && (tNot '= ""): ",", 1: "") _ tNot
    If ((pKind = "discard") || (pKind = "delete")) && (tAudited '= "") {
        Set tEffects = {}
        Do tEffects.%Set("namespace", pNamespace, "string")
        Do tEffects.%Set("action", pKind, "string")
        Do tEffects.%Set("done", tDone, "string")
        Do tEffects.%Set("failed", tNot, "string")
        Do ..AuditRuntime($Select(pKind = "discard": ..#VERBDISCARD, 1: ..#VERBDELETE), ..#ENTITYMESSAGE, tAudited, tEffects)
    }
    If tStopped '= "" Quit ..Statused(tStopped, $Select('tSuspended: "the message resend failed", 1: "the suspended message write failed"), .pHttpStatus, .pFault)
    Set pResult = {}
    Do pResult.%Set("Namespace", pNamespace, "string")
    Do pResult.%Set($Select('tSuspended: "Resent", 1: "Done"), tResent, "number")
    Do pResult.%Set("Failed", tFailed, "number")
    Do pResult.%Set("Messages", tSent)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Whether the body <var>pClass</var> <var>pBodyId</var> in <var>pNamespace</var> can be written as text by an export: a character stream, an EDI document or an
/// <parameter>XMLADAPTOR</parameter> object, the kinds <method>ContentsText</method> draws. Nothing is audited. A body that does not open, or a fault, reads <code>0</code>. Switches
/// the namespace by explicit save and restore; only this class runs while it is switched.</p>
ClassMethod TextBodyHere(pNamespace As %String, pClass As %String, pBodyId As %String) As %Boolean [ Private ]
{
    Set tText = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tObject = ..OpenBodyHere(pClass, pBodyId)
        If $IsObject(tObject) {
            If tObject.%Extends("%Stream.Object") {
                Set tText = ''tObject.IsCharacter()
            } Else {
                Set tText = ''(tObject.%Extends(..#DOCUMENTBASE) || tObject.%Extends(..#XMLADAPTOR))
            }
        }
        Set tObject = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tText = 0
    }
    Quit tText
}

/// <p>The character sets this instance lists for a file, as a <class>%List</class>: the classic export dialog's own list (<code>GetIONames^%SYS.NLS</code>), read at the call.
/// <parameter>DEFAULTCHARSET</parameter> is the one preselected.</p>
ClassMethod ExportCharsets() As %List
{
    Set tNames = $$GetIONames^%SYS.NLS(.tDefaults, 1)
    Set tList = ""
    For tI = 1:1:$Length(tNames, ",") {
        If $Piece(tNames, ",", tI) '= "" Set tList = tList _ $ListBuild($Piece(tNames, ",", tI))
    }
    Quit tList
}

/// <p>The characters that separate two messages in a file for the separator <var>pName</var> (<parameter>EXPORTSEPARATORS</parameter>), as the classic export writes them;
/// <code>""</code> for <code>None</code> and for a name that is not one. Pure.</p>
ClassMethod ExportSeparatorChars(pName As %String) As %String
{
    Quit $Case(pName, "CRLF": $Char(13, 10), "CR": $Char(13), "LF": $Char(10), "MLLP": $Char(28), "Tab": $Char(9), : "")
}

/// <p>The bytes a file for the character set <var>pCharset</var> begins with, which the classic export's file stream writes before its first character: the byte order mark of
/// <code>UnicodeLittle</code> and <code>UnicodeBig</code>, none for any other. Pure.</p>
ClassMethod ExportByteOrderMark(pCharset As %String) As %String
{
    Quit $Case(pCharset, "UnicodeLittle": $Char(255, 254), "UnicodeBig": $Char(254, 255), : "")
}

/// <p><var>pText</var> as the classic export's device carries it: each character above 255, which a byte cannot hold, is <code>?</code>. Pure.</p>
ClassMethod ExportNarrow(pText As %String) As %String
{
    If '$ZIsWide(pText) Quit pText
    Set tOut = ""
    Set tFrom = 1
    Set tLength = $Length(pText)
    For tI = 1:1:tLength {
        If $Ascii($Extract(pText, tI)) > 255 {
            Set tOut = tOut _ $Extract(pText, tFrom, tI - 1) _ "?"
            Set tFrom = tI + 1
        }
    }
    Quit tOut _ $Extract(pText, tFrom, tLength)
}

/// <p>Write <var>pText</var> to <var>pBytes</var> converted to the character set <var>pCharset</var>, <parameter>EXPORTCHUNK</parameter> characters at a time, so no converted
/// piece passes the longest string the instance holds in any character set; a piece never ends between the two halves of a surrogate pair. Stops, answering 1, once
/// <var>pBytes</var> holds more than <parameter>EXPORTMAXBYTES</parameter> bytes; else 0.</p>
ClassMethod ExportWrite(pBytes As %Stream.Object, pText As %String, pCharset As %String) As %Boolean
{
    Set tFrom = 1
    Set tLength = $Length(pText)
    While (tFrom <= tLength) && (pBytes.Size '> ..#EXPORTMAXBYTES) {
        Set tTo = tFrom + ..#EXPORTCHUNK - 1
        If (tTo < tLength) && ($Ascii(pText, tTo) >= 55296) && ($Ascii(pText, tTo) <= 56319) Set tTo = tTo + 1
        Do pBytes.Write($ZConvert($Extract(pText, tFrom, tTo), "O", pCharset))
        Set tFrom = tTo + 1
    }
    Quit (pBytes.Size > ..#EXPORTMAXBYTES)
}

/// <p>The text of the body <var>pObject</var> of header <var>pHeaderId</var> as the classic export writes it to its device (Story 24.16 Batch 3), in <var>pWire</var>, one
/// character a byte: an EDI document as <code>OutputToDevice</code> writes it (an EDI XML document with <code>wt</code>) with each character above 255 a <code>?</code>, an
/// <parameter>XMLADAPTOR</parameter> object as an indented <code>%XML.Writer</code> writes it, its UTF-8 bytes each a character, and a character stream as its text. At most
/// <parameter>EXPORTMAXBYTES</parameter> + 1 characters are read, and <var>pTooLarge</var> is 1 when there was more. A body of another kind is an error status. Called while the
/// message's namespace is switched. Overridable so a test can fail one message's render; production never overrides it.</p>
ClassMethod ExportRenderHere(pHeaderId As %String, pObject As %RegisteredObject, Output pWire As %String, Output pTooLarge As %Boolean) As %Status [ Private ]
{
    Set pWire = ""
    Set pTooLarge = 0
    Set tLimit = ..#EXPORTMAXBYTES + 1
    If pObject.%Extends("%Stream.Object") {
        If 'pObject.IsCharacter() Quit $$$ERROR($$$GeneralError, "The body is not text.")
        Do pObject.Rewind()
        Set pWire = pObject.Read(tLimit)
        Set pTooLarge = 'pObject.AtEnd
        Quit $$$OK
    }
    If pObject.%Extends(..#DOCUMENTBASE) {
        Set tStream = ##class(%Stream.TmpCharacter).%New()
        If pObject.%Extends(..#XMLDOCUMENT) {
            Set tSC = pObject.OutputToLibraryStream(tStream, "wt")
        } Else {
            Set tSC = pObject.OutputToLibraryStream(tStream)
        }
        If $$$ISERR(tSC) Quit tSC
        Do tStream.Rewind()
        Set tText = tStream.Read(tLimit)
        Set pTooLarge = 'tStream.AtEnd
        Set pWire = ..ExportNarrow(tText)
        Quit $$$OK
    }
    If pObject.%Extends(..#XMLADAPTOR) {
        Set tStream = ##class(%Stream.TmpBinary).%New()
        Set tWriter = ##class(%XML.Writer).%New()
        Set tWriter.Indent = 1
        Set tSC = tWriter.OutputToStream(tStream)
        If $$$ISOK(tSC) Set tSC = tWriter.RootObject(pObject)
        If $$$ISERR(tSC) Quit tSC
        Do tStream.Rewind()
        Set pWire = tStream.Read(tLimit)
        Set pTooLarge = 'tStream.AtEnd
        Quit $$$OK
    }
    Quit $$$ERROR($$$GeneralError, "The body is not text.")
}

/// <p>Render the body of message header <var>pHeaderId</var> in <var>pNamespace</var> into <var>pBytes</var> as one member of an export: <var>pPrefix</var> (the separator, or
/// the MLLP start) and the body's text (<method>ExportRenderHere</method>), a <code>CRLF</code> inside them one <code>LF</code> as the classic export's file stream writes it, then
/// converted to the character set <var>pCharset</var>. <var>pClass</var> and <var>pBodyId</var> name the body for the view audit, which this does not write. <var>pRenderSC</var>
/// is the render's status, <var>pTooLarge</var> 1 when the body, or the bytes so far, pass <parameter>EXPORTMAXBYTES</parameter>, and a thrown fault is <var>pCaught</var>, with the
/// namespace restored. Only this class and vendor classes run while the namespace is switched.</p>
ClassMethod ExportMemberHere(pNamespace As %String, pHeaderId As %String, pPrefix As %String, pCharset As %String, pBytes As %Stream.Object, Output pClass As %String, Output pBodyId As %String, Output pRenderSC As %Status, Output pTooLarge As %Boolean, Output pCaught) As %Status [ Private ]
{
    Set pClass = ""
    Set pBodyId = ""
    Set pRenderSC = $$$OK
    Set pTooLarge = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tHeader = ##class(Ens.MessageHeader).%OpenId(pHeaderId)
        If $IsObject(tHeader) {
            Set pClass = tHeader.MessageBodyClassName
            Set pBodyId = tHeader.MessageBodyId
        }
        Set tHeader = ""
        Set tObject = ..OpenBodyHere(pClass, pBodyId)
        If '$IsObject(tObject) {
            Set pRenderSC = $$$ERROR($$$GeneralError, "The message body is no longer there.")
        } Else {
            Set pRenderSC = ..ExportRenderHere(pHeaderId, tObject, .tWire, .pTooLarge)
            If $$$ISOK(pRenderSC) && 'pTooLarge Set pTooLarge = ..ExportWrite(pBytes, $Replace(pPrefix _ tWire, $Char(13, 10), $Char(10)), pCharset)
        }
        Set tObject = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>Record the view of each body of <var>pViews</var> (<code>pViews(n)</code> is <code>$ListBuild(header id, body class, body id)</code>, <var>pViews</var> the count), as the classic
/// Contents pane records it (<method>AuditViewHere</method>), in <var>pNamespace</var>. A fault is <var>pCaught</var>, with the namespace restored.</p>
ClassMethod AuditViewsHere(pNamespace As %String, ByRef pViews, Output pCaught) As %Status [ Private ]
{
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        For tI = 1:1:+$Get(pViews) Do ..AuditViewHere($List(pViews(tI), 1), $List(pViews(tI), 2), $List(pViews(tI), 3))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>Whether <var>pType</var> is one of the Messages endpoint's three export types (Story 24.16 Batch 3): the composed review, the write and the choices read.</p>
ClassMethod IsMessageExportType(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEEXPORT) || (pType = ..#TYPEEXPORTMESSAGES) || (pType = ..#TYPEEXPORTCHOICES)
}

/// <p>The two lists an export is made with, <code>{Separators: [], Charsets: [], DefaultSeparator, DefaultCharset}</code> (<parameter>EXPORTSEPARATORS</parameter> and
/// <method>ExportCharsets</method>).</p>
ClassMethod ExportChoices() As %DynamicObject
{
    Set tChoices = {}
    Set tSeparators = []
    For tI = 1:1:$Length(..#EXPORTSEPARATORS, ",") Do tSeparators.%Push($Piece(..#EXPORTSEPARATORS, ",", tI), "string")
    Set tCharsets = []
    Set tList = ..ExportCharsets()
    For tI = 1:1:$ListLength(tList) Do tCharsets.%Push($List(tList, tI), "string")
    Do tChoices.%Set("Separators", tSeparators)
    Do tChoices.%Set("Charsets", tCharsets)
    Do tChoices.%Set("DefaultSeparator", ..#DEFAULTSEPARATOR, "string")
    Do tChoices.%Set("DefaultCharset", ..#DEFAULTCHARSET, "string")
    Quit tChoices
}

/// <p>The review of an export (Story 24.16 Batch 3): <method>ReadResend</method>'s answer for the messages <var>pText</var> names, judged for an export, and
/// <code>{Separator, Charset, Separators, Charsets}</code> beside it. An empty <var>pSeparator</var> or <var>pCharset</var> reads <parameter>DEFAULTSEPARATOR</parameter> or
/// <parameter>DEFAULTCHARSET</parameter>. A set that is not 1 to <parameter>RESENDMAX</parameter> ids, a separator outside <parameter>EXPORTSEPARATORS</parameter> and a
/// character set the instance does not list are each 400 <code>PORT.VALIDATION</code> naming it, before anything is read.</p>
ClassMethod ReadExport(pNamespace As %String, pText As %String, pAction As %String, pReviewed As %String, pSeparator As %String, pCharset As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set tSeparator = $Select(pSeparator = "": ..#DEFAULTSEPARATOR, 1: pSeparator)
    Set tCharset = $Select(pCharset = "": ..#DEFAULTCHARSET, 1: pCharset)
    If '..MessageSet(pText, .tIds) Quit ..RefuseCriterion("Messages", .pHttpStatus, .pFault)
    If '$ListFind($ListFromString(..#EXPORTSEPARATORS), tSeparator) Quit ..RefuseCriterion("separator", .pHttpStatus, .pFault)
    If '$ListFind(..ExportCharsets(), tCharset) Quit ..RefuseCriterion("charset", .pHttpStatus, .pFault)
    Set tSC = ..ReadResend(pNamespace, pText, pAction, pReviewed, .pRow, .pHttpStatus, .pFault, "export")
    If $$$ISERR(tSC) || '$IsObject(pRow) Quit tSC
    Set tChoices = ..ExportChoices()
    Do pRow.%Set("Separator", tSeparator, "string")
    Do pRow.%Set("Charset", tCharset, "string")
    Do pRow.%Set("Separators", tChoices.%Get("Separators"))
    Do pRow.%Set("Charsets", tChoices.%Get("Charsets"))
    Quit $$$OK
}

/// <p>Export the messages <var>pText</var> names whose verdict is <code>export</code> (Story 24.16 Batch 3): the review is made again first (<method>ReadExport</method>, composed for
/// this write), so a <var>pReviewed</var> the verdicts no longer give is 409 <code>INTEROP.EXPORT.CHANGED</code> and no message reading <code>export</code> is 409
/// <code>INTEROP.EXPORT.NONE</code>, each with nothing rendered. The bodies are rendered in ascending id order as the classic export writes them
/// (<method>ExportMemberHere</method>), the separator before each but the first and after the last, and an MLLP file framed as the classic frames it, into a stream the file is
/// built in; nothing is written to the instance's disk. A body whose render fails is recorded with the vendor's text (cut at <parameter>ERRORTEXTMAX</parameter>) and the rest are still
/// exported; a render that throws is 500, after the namespace is restored. A file over <parameter>EXPORTMAXBYTES</parameter> is 409 <code>INTEROP.EXPORT.TOOLARGE</code>, decided
/// before any view is audited and before any byte leaves. Only then is the view of each body exported recorded (<method>AuditViewsHere</method>), and the answer is
/// <code>{Namespace, Exported, Failed, Messages: [{ID}|{ID, Error}], File}</code>, <code>File</code> the bytes base64-encoded in one call, <code>""</code> when none was exported.
/// OcuPilot records no row of its own: an export changes nothing.</p>
ClassMethod PerformExport(pNamespace As %String, pText As %String, pReviewed As %String, pSeparator As %String, pCharset As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..ReadExport(pNamespace, pText, ..#TYPEEXPORTMESSAGES, pReviewed, pSeparator, pCharset, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If 'tRow.%Get("Eligible") Quit ..Conflict(##class(OcuPilot.Api.InteropError).#EXPORTNONE, .pHttpStatus, .pFault)
    Set tSeparatorName = tRow.%Get("Separator")
    Set tCharset = tRow.%Get("Charset")
    Set tSeparator = ..ExportSeparatorChars(tSeparatorName)
    Set tBytes = ##class(%Stream.TmpBinary).%New()
    Do tBytes.Write(..ExportByteOrderMark(tCharset))
    Set tSent = []
    Set tExported = 0
    Set tFailed = 0
    Set tViews = 0
    Set tIterator = tRow.%Get("Messages").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tMessage) {
        If tMessage.%Get("Verdict") '= "export" Continue
        Set tId = tMessage.%Get("ID")
        Set tPrefix = $Select(tExported = 0: $Select(tSeparatorName = "MLLP": $Char(11), 1: ""), 1: tSeparator)
        Set tSC = ..ExportMemberHere(pNamespace, tId, tPrefix, tCharset, tBytes, .tClass, .tBodyId, .tRenderSC, .tTooLarge, .tCaught)
        If $IsObject(tCaught) Quit
        If tTooLarge Quit
        Set tEntry = {}
        Do tEntry.%Set("ID", tId, "string")
        If $$$ISOK(tRenderSC) {
            Set tExported = tExported + 1
            Set tViews = tViews + 1
            Set tViews(tViews) = $ListBuild(tId, tClass, tBodyId)
        } Else {
            Do ..LogFault("a message could not be exported", ..VendorCodesStatus(tRenderSC))
            Do tEntry.%Set("Error", $Extract($System.Status.GetErrorText(tRenderSC), 1, ..#ERRORTEXTMAX), "string")
            Set tFailed = tFailed + 1
        }
        Do tSent.%Push(tEntry)
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the message export failed", .pHttpStatus, .pFault)
    If tTooLarge Quit ..Conflict(##class(OcuPilot.Api.InteropError).#EXPORTTOOLARGE, .pHttpStatus, .pFault)
    Set tFile = ""
    If tExported {
        Do tBytes.Write(..ExportTail(tSeparatorName, tCharset))
        If tBytes.Size > ..#EXPORTMAXBYTES Quit ..Conflict(##class(OcuPilot.Api.InteropError).#EXPORTTOOLARGE, .pHttpStatus, .pFault)
        Set tSC = ..AuditViewsHere(pNamespace, .tViews, .tCaught)
        If $IsObject(tCaught) Quit ..Mapped(tCaught, "the message export could not be recorded", .pHttpStatus, .pFault)
        Do tBytes.Rewind()
        Set tFile = $System.Encryption.Base64Encode(tBytes.Read(tBytes.Size), 1)
    }
    Set pResult = {}
    Do pResult.%Set("Namespace", pNamespace, "string")
    Do pResult.%Set("Exported", tExported, "number")
    Do pResult.%Set("Failed", tFailed, "number")
    Do pResult.%Set("Messages", tSent)
    Do pResult.%Set("File", tFile, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The bytes an export file ends with, as the classic export writes them after its last message: the separator, and for MLLP a carriage return after it, with a
/// <code>CRLF</code> one <code>LF</code>, converted to the character set <var>pCharset</var>. Pure.</p>
ClassMethod ExportTail(pSeparatorName As %String, pCharset As %String) As %String
{
    Quit $ZConvert($Replace(..ExportSeparatorChars(pSeparatorName) _ $Select(pSeparatorName = "MLLP": $Char(13), 1: ""), $Char(13, 10), $Char(10)), "O", pCharset)
}

/// <p>Serve the export types of the Messages endpoint after <method>Invoke</method>'s gate (Story 24.16 Batch 3): the review (<code>EXPORT</code>), the write
/// (<code>EXPORTMESSAGES</code>) and the two lists (<code>EXPORTCHOICES</code>). The messages travel under <parameter>IDKEY</parameter> as the set <method>MessageSet</method>
/// reads, the separator and the character set under <parameter>SEPARATORKEY</parameter> and <parameter>CHARSETKEY</parameter>, the digest a person reviewed under
/// <parameter>DIGESTKEY</parameter>. A read composed for an action carries it under <parameter>ACTIONKEY</parameter>, which must be the export's write, else 501.</p>
ClassMethod InvokeMessageExport(pNamespace As %String, pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType = ..#TYPEEXPORTCHOICES {
            Set pResult = ..ExportChoices()
            Set pHttpStatus = 200
            Quit
        }
        Set tAction = $Select(pType = ..#TYPEEXPORTMESSAGES: pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && (tAction '= ..#TYPEEXPORTMESSAGES) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPEEXPORTMESSAGES {
            Set tSC = ..PerformExport(pNamespace, $Get(pQuery(..#IDKEY)), $Get(pQuery(..#DIGESTKEY)), $Get(pQuery(..#SEPARATORKEY)), $Get(pQuery(..#CHARSETKEY)), .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..ReadExport(pNamespace, $Get(pQuery(..#IDKEY)), tAction, $Get(pQuery(..#DIGESTKEY)), $Get(pQuery(..#SEPARATORKEY)), $Get(pQuery(..#CHARSETKEY)), .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the message export call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The lines <method>Snippet</method> adds for the export write (Story 24.16 Batch 3), from the stored payload of <var>pContext</var> and the query <var>pQuery</var>: for each id of
/// the set <var>pId</var> names that the payload's <code>Verdicts</code> reads <code>export</code> (every id when it holds none), the body opened and written to the terminal
/// as <code>OutputToDevice</code> writes it, the separator before it when it is not the first, and the view recorded (<code>AuditViewMessage</code>); then the separator after the last,
/// and for MLLP the carriage return. <code>""</code>, so no draft is rendered, for a set that is not 1 to <parameter>RESENDMAX</parameter> message ids, a separator outside
/// <parameter>EXPORTSEPARATORS</parameter> or a character set the instance does not list. Every id is a string literal and each separator its character codes, so nothing the
/// query or the payload carries runs as code.</p>
ClassMethod ExportSnippet(pId As %String, ByRef pQuery, pContext As %DynamicObject) As %String [ Private ]
{
    If '..MessageSet(pId, .tAll) Quit ""
    Set tPayload = ""
    If $IsObject(pContext) && (pContext.%GetTypeOf("payload") = "object") Set tPayload = pContext.%Get("payload")
    Set tSeparator = $Get(pQuery(..#SEPARATORKEY))
    If (tSeparator = "") && $IsObject(tPayload) && (tPayload.%GetTypeOf("Separator") = "string") Set tSeparator = tPayload.%Get("Separator")
    If tSeparator = "" Set tSeparator = ..#DEFAULTSEPARATOR
    Set tCharset = $Get(pQuery(..#CHARSETKEY))
    If (tCharset = "") && $IsObject(tPayload) && (tPayload.%GetTypeOf("Charset") = "string") Set tCharset = tPayload.%Get("Charset")
    If tCharset = "" Set tCharset = ..#DEFAULTCHARSET
    If '$ListFind($ListFromString(..#EXPORTSEPARATORS), tSeparator) || '$ListFind(..ExportCharsets(), tCharset) Quit ""
    Kill tReviewed
    If $IsObject(tPayload) && (tPayload.%GetTypeOf("Verdicts") = "string") {
        Set tVerdicts = tPayload.%Get("Verdicts")
        For tI = 1:1:$Length(tVerdicts, ",") {
            Set tPair = $Piece(tVerdicts, ",", tI)
            If $Match($Piece(tPair, "=", 1), ..#MESSAGEIDPATTERN) Set tReviewed($Piece(tPair, "=", 1)) = $Piece(tPair, "=", 2)
        }
    }
    Set tIds = ""
    For tI = 1:1:$ListLength(tAll) {
        If $Data(tReviewed($List(tAll, tI))) && (tReviewed($List(tAll, tI)) '= "export") Continue
        Set tIds = tIds _ $ListBuild($List(tAll, tI))
    }
    Set tNL = $Char(10)
    Set tCodes = ""
    For tI = 1:1:$Length(..ExportSeparatorChars(tSeparator)) Set tCodes = tCodes _ $Select(tCodes = "": "", 1: ", ") _ $Ascii($Extract(..ExportSeparatorChars(tSeparator), tI))
    Set tSep = $Select(tCodes = "": """""", 1: "$Char(" _ tCodes _ ")")
    Set tText = tNL _ " Set tSC = 1"
    ; The script writes to the terminal that runs it, with the command's abbreviation: AD-12 allows no other spelling of the command in this tree.
    If tSeparator = "MLLP" Set tText = tText _ tNL _ " W $Char(11)"
    For tI = 1:1:$ListLength(tIds) {
        Set tId = ..Literal($List(tIds, tI))
        If tI > 1 Set tText = tText _ tNL _ " W " _ tSep
        Set tText = tText _ tNL _ " Set tHeader = ##class(Ens.MessageHeader).%OpenId(" _ tId _ ")"
        Set tText = tText _ tNL _ " Set tBody = $ClassMethod(tHeader.MessageBodyClassName, ""%OpenId"", tHeader.MessageBodyId)"
        Set tText = tText _ tNL _ " If tBody.%Extends(""EnsLib.EDI.XML.Document"") { Do tBody.OutputToDevice(""wt"") } ElseIf tBody.%Extends(""EnsLib.EDI.Document"") { Do tBody.OutputToDevice() } ElseIf tBody.%Extends(""%Stream.Object"") { Do tBody.OutputToDevice() } ElseIf tBody.%Extends(""%XML.Adaptor"") { Set tWriter = ##class(%XML.Writer).%New(), tWriter.Indent = 1 Set tSC = $System.Status.AppendStatus(tSC, tWriter.OutputToDevice()) Set tSC = $System.Status.AppendStatus(tSC, tWriter.RootObject(tBody)) }"
        Set tText = tText _ tNL _ " Do ##class(Ens.Util.Auditing).AuditViewMessage(""OcuPilot"", " _ tId _ ", tHeader.MessageBodyClassName, tHeader.MessageBodyId)"
    }
    Set tText = tText _ tNL _ " W " _ tSep
    If tSeparator = "MLLP" Set tText = tText _ ", $Char(13)"
    Quit tText
}

/// <p>The body of the message header <var>pHeaderId</var> as an edit reads it (Story 20.31), in <var>pFacts</var>, opened and
/// recorded as viewed (<method>AuditViewHere</method>) while the namespace is switched; a fault is <var>pCaught</var>, with it
/// restored. <var>pFacts</var><code>("editable")</code> is 1 for a body OcuPilot edits and 0 otherwise: a header that
/// names no body, a body that does not open, a stream, a class that is not persistent, a class whose name begins
/// <parameter>OWNCLASSPREFIX</parameter> in any letter case (it is not opened), a document that is not an HL7 v2 message, one over
/// <parameter>TESTOUTPUTMAX</parameter> characters, and a class with no field a person can set.
/// <code>("kind")</code> is <code>document</code> or <code>object</code>. A document's raw view (<method>RenderTargetHere</method>) is
/// <var>pFacts</var><code>("text")</code>; an object's fields are <code>("meta")</code> and <code>("meta", n)</code>
/// (<method>ClassFieldsHere</method>'s records), each current value as the class stores it <code>("logical", n)</code> and as a
/// person types it <code>("display", n)</code>, read along the field's path.</p>
ClassMethod EditBodyFacts(pNamespace As %String, pHeaderId As %String, pBodyClass As %String, pBodyId As %String, ByRef pFacts, Output pCaught) As %Status [ Private ]
{
    Kill pFacts
    Set pFacts("editable") = 0
    Set pFacts("kind") = ""
    Set pFacts("text") = ""
    Set pFacts("meta") = 0
    Set pCaught = ""
    If $Extract($ZConvert(pBodyClass, "L"), 1, $Length(..#OWNCLASSPREFIX)) = ..#OWNCLASSPREFIX Quit $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tObject = ..OpenBodyHere(pBodyClass, pBodyId)
        If $IsObject(tObject) {
            Do ..AuditViewHere(pHeaderId, pBodyClass, pBodyId)
            If tObject.%Extends("%Library.Persistent") && 'tObject.%Extends("%Stream.Object") {
                If tObject.%Extends("EnsLib.HL7.Message") {
                    Set tRender = ..RenderTargetHere(tObject, .tText)
                    If $$$ISOK(tRender) && ($Length(tText) <= ..#TESTOUTPUTMAX) {
                        Set pFacts("editable") = 1
                        Set pFacts("kind") = "document"
                        Set pFacts("text") = tText
                    }
                } ElseIf '..IsDocumentClassHere(pBodyClass) {
                    Do ..ClassFieldsHere(pBodyClass, .tMeta)
                    If tMeta {
                        Set pFacts("editable") = 1
                        Set pFacts("kind") = "object"
                        Set pFacts("meta") = tMeta
                        For tI = 1:1:tMeta {
                            Set pFacts("meta", tI) = tMeta(tI)
                            Set tPath = $List(tMeta(tI), 2)
                            Set tCurrent = tObject
                            For tJ = 1:1:$Length(tPath, ".") - 1 {
                                Set tCurrent = $Property(tCurrent, $Piece(tPath, ".", tJ))
                                If '$IsObject(tCurrent) Quit
                            }
                            Set tLogical = $Select($IsObject(tCurrent): $Property(tCurrent, $List(tMeta(tI), 3)), 1: "")
                            Set tDisplay = tLogical
                            If (tLogical '= "") && ##class(%Dictionary.CompiledMethod).%ExistsId($List(tMeta(tI), 8) _ "||" _ $List(tMeta(tI), 3) _ "LogicalToDisplay") {
                                Set tDisplay = $ClassMethod($List(tMeta(tI), 8), $List(tMeta(tI), 3) _ "LogicalToDisplay", tLogical)
                            }
                            Set pFacts("logical", tI) = tLogical
                            Set pFacts("display", tI) = tDisplay
                        }
                    }
                }
            }
        }
        Set tObject = ""
        Set tCurrent = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The virtual document class <var>pClass</var> parsed from the text <var>pText</var>, or <code>""</code> with the parser's refusal in
/// <var>pStatus</var>. An <code>EnsLib.HL7.Message</code> (or <var>pAsStream</var> for any class) goes through a
/// <class>%Stream.TmpCharacter</class> and <code>ImportFromLibraryStream</code>, as the classic dialogs parse it: <code>ImportFromString</code>
/// translates text already decoded a second time, and a character past Latin-1 arrives as <code>?</code>. Every other document class keeps
/// <code>ImportFromString</code>. Called while the document's namespace is switched.</p>
ClassMethod ImportDocumentHere(pClass As %String, pText As %String, Output pStatus As %Status, pAsStream As %Boolean = 0) [ Private ]
{
    Set pStatus = $$$OK
    If 'pAsStream && '$ClassMethod(pClass, "%Extends", ..#HL7MESSAGE) Quit $ClassMethod(pClass, "ImportFromString", pText, .pStatus)
    Set tStream = ##class(%Stream.TmpCharacter).%New()
    Do tStream.Write(pText)
    Do tStream.Rewind()
    Quit $ClassMethod(pClass, "ImportFromLibraryStream", tStream, .pStatus)
}

/// <p>The text <var>pText</var> parsed as the HL7 v2 message class <var>pClass</var> would parse an edited body, and rendered as its
/// raw view in <var>pNewText</var> (Story 20.31): the text is written to a <class>%Stream.TmpCharacter</class> and handed to the
/// class's <code>ImportFromLibraryStream</code>, as the classic edit does. <var>pStatus</var> is the parser's refusal. Called while
/// the message's namespace is switched.</p>
ClassMethod ParseEditDocumentHere(pClass As %String, pText As %String, Output pNewText As %String, Output pStatus As %Status) [ Private ]
{
    Set pNewText = ""
    Set pStatus = $$$OK
    Set tTemp = ..ImportDocumentHere(pClass, pText, .pStatus, 1)
    If $$$ISERR(pStatus) Quit
    If '$IsObject(tTemp) {
        Set pStatus = $$$ERROR($$$GeneralError, "the text did not give an HL7 message")
        Quit
    }
    Set pStatus = ..RenderTargetHere(tTemp, .pNewText)
}

/// <p><var>pText</var> as <method>ParseEditDocumentHere</method> parses it in <var>pNamespace</var>, switched by explicit save and
/// restore; a fault is <var>pCaught</var>, with the namespace restored.</p>
ClassMethod ParseEditDocument(pNamespace As %String, pClass As %String, pText As %String, Output pNewText As %String, Output pStatus As %Status, Output pCaught) As %Status [ Private ]
{
    Set pNewText = ""
    Set pStatus = $$$OK
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..ParseEditDocumentHere(pClass, pText, .pNewText, .pStatus)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>Convert the plan <var>pPlan</var> of an edit to the logical values its fields store and judge them
/// (<method>ConvertPlanHere</method>), in <var>pNamespace</var>, switched by explicit save and restore. <var>pViolations</var> is
/// <method>ConvertPlanHere</method>'s; a fault is <var>pCaught</var>, with the namespace restored.</p>
ClassMethod ConvertEditPlan(pNamespace As %String, ByRef pPlan, Output pViolations, Output pCaught) As %Status [ Private ]
{
    Kill pViolations
    Set pViolations = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..ConvertPlanHere(.pPlan, .pViolations)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The edit of one message as the edit read answers it (Story 20.31), composed for the action <var>pAction</var> (<code>""</code>
/// for the plain read): <code>{Namespace, Production, Message, Type, Source, Target, BodyClass, Kind, Verdict, Form: [{RequestClass,
/// Kind, Field, Type, Required, MaxLength, Values, Secret, Value}], Fields, Changed, Before, After, Original, Reviewed, Digest}</code>.</p>
/// <ul>
/// <li>A namespace whose production is not running is 409 <code>INTEROP.PRODUCTION.NOTRUNNING</code>; a header that is gone is 404
/// <code>PORT.NOTFOUND</code>, unlogged. A message that reads anything but <code>resend</code> is answered with its verdict, no
/// <code>Kind</code> and no form, and its body is not opened.</li>
/// <li>A message that reads <code>resend</code> has its body opened and recorded as viewed (<method>EditBodyFacts</method>), and one
/// OcuPilot does not edit is 409 <code>INTEROP.EDIT.NOTEDITABLE</code>. <code>Kind</code> is <code>document</code> (an HL7 v2
/// message, one field, <code>content</code>, whose <code>Value</code> is the raw view) or <code>object</code> (the class's plain
/// fields, <code>Value</code> as a person types it, blank for a credential-named field).</li>
/// <li><code>Original</code> is the SHA-256 of the form; <code>Digest</code> is the SHA-256 of <code>Verdict|Original</code>.</li>
/// <li><var>pFieldsText</var> is the supplied fields, JSON object text of text values, <code>""</code> for none (400
/// <code>PORT.VALIDATION</code> otherwise). <code>Fields</code> echoes them, a credential-named one left out. <code>Changed</code>
/// lists the paths whose value differs from the current one (a document by the raw view of the parsed text);
/// <code>Before</code> and <code>After</code> are those fields as <code>&lt;path&gt;: &lt;value&gt;</code> lines, or, for a
/// document, <method>OcuPilot.Screen.Tool.ExplorerSaveMint.Hunk</method>'s two texts.</li>
/// <li>Composed for an action, a <var>pReviewed</var> the message and its form no longer give is 409
/// <code>INTEROP.RESEND.CHANGED</code>, then the supplied fields are judged, 422 on the field: <code>INTEROP.EDIT.FIELD</code> for a
/// path that is not a field, <code>.SECRET</code> for a credential-named one, <code>.VALUE</code> for a value its datatype refuses, a
/// value outside a closed list, a required field left empty, a member that is not text, or a document the parser refuses.</li>
/// </ul>
/// <p><var>pPlan</var> answers what an edit sends from, as <method>ReadTestTarget</method>'s: <code>pPlan("kind")</code>, for a
/// document <code>pPlan("content")</code>, else <code>pPlan</code> fields and <code>pPlan(n)</code> <code>$ListBuild(path, leaf,
/// owner, chain, typed, logical)</code> for each changed field.</p>
/// <p>For a suspended message (Story 24.16) <var>pSuspended</var> is 1: the message is judged as <code>edit</code>
/// (<method>MessageVerdict</method>), so one that is not Suspended reads <code>notsuspended</code> and is not opened, an eligible one reads
/// <code>resubmit</code>, and a moved review is 409 <code>INTEROP.SUSPENDED.CHANGED</code>.</p>
ClassMethod ReadEdit(pNamespace As %String, pId As %String, pAction As %String, pFieldsText As %String, pReviewed As %String, Output pRow As %DynamicObject, ByRef pPlan, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pSuspended As %Boolean = 0) As %Status [ Private ]
{
    Set pRow = ""
    Kill pPlan
    Set pPlan = 0
    If '..ParseTestFields(pFieldsText, .tInput, .tBad) Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONTESTFIELDS, .pHttpStatus, .pFault)
    Set tSC = ..RunningProduction(pNamespace, .tProduction, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the production's state could not be read", .pHttpStatus, .pFault)
    If tProduction = "" Quit ..Conflict(##class(OcuPilot.Api.InteropError).#NOTRUNNING, .pHttpStatus, .pFault)
    Set tSC = ..JudgeMessages(pNamespace, tProduction, $ListBuild(pId), .tRows, .tFacts, .tVerdicts, .tEligible, .pHttpStatus, .pFault, $Select(pSuspended: "edit", 1: ""))
    If $$$ISERR(tSC) Quit tSC
    Set tFact = tFacts(1)
    Set tVerdict = $List(tFact, 7)
    If tVerdict = "gone" Quit ..Absent(.pHttpStatus, .pFault)
    Set tBodyClass = $List(tFact, 5)
    Kill tBody
    Set tBody("editable") = 0
    Set tBody("kind") = ""
    Set tBody("meta") = 0
    If tVerdict = $Select(pSuspended: "resubmit", 1: "resend") {
        Set tSC = ..EditBodyFacts(pNamespace, pId, tBodyClass, $List(tFact, 6), .tBody, .tCaught)
        If $IsObject(tCaught) Quit ..Mapped(tCaught, "the message body could not be read", .pHttpStatus, .pFault)
        If 'tBody("editable") Quit ..Conflict(##class(OcuPilot.Api.InteropError).#EDITNOTEDITABLE, .pHttpStatus, .pFault)
    }
    Set tKind = tBody("kind")

    ; The form: the body's fields as the Test tab lists them, with the value each holds now. A credential-named field shows none.
    Set tForm = []
    Set tOriginalText = ""
    If tKind = "document" {
        Do tForm.%Push(..TestFieldRow("", "", $ListBuild(tBodyClass, "document", ..#DOCUMENTFIELD, ..#DOCUMENTFIELD, "%Library.String", 1, "", "", tBodyClass, ""), 1, tBody("text")))
        Set tOriginalText = tBody("text")
    } ElseIf tKind = "object" {
        For tI = 1:1:tBody("meta") {
            Set tPath = $List(tBody("meta", tI), 2)
            Set tShown = $Select(..SecretPath(tPath): "", 1: tBody("display", tI))
            Do tForm.%Push(..TestFieldRow("", "", $ListBuild(tBodyClass) _ tBody("meta", tI), 1, tShown))
            Set tOriginalText = tOriginalText _ tPath _ $Char(1) _ tShown _ $Char(2)
        }
    }
    Set tOriginal = $Select(tKind = "": "", 1: ..Sha256Hex(tBodyClass _ $Char(3) _ tOriginalText))
    Set tDigest = ..Sha256Hex(tVerdict _ "|" _ tOriginal)
    If (pAction '= "") && (pReviewed '= "") && (pReviewed '= tDigest) Quit ..Conflict($Select(pSuspended: ##class(OcuPilot.Api.InteropError).#SUSPENDEDCHANGED, 1: ##class(OcuPilot.Api.InteropError).#RESENDCHANGED), .pHttpStatus, .pFault)

    ; The supplied fields.
    Kill tViolations
    Set tViolations = 0
    Set tChanged = []
    Set tBefore = ""
    Set tAfter = ""
    Set tNL = $Char(10)
    Set tKey = ""
    For {
        Set tKey = $Order(tBad(tKey))
        If tKey = "" Quit
        Set tViolations($Increment(tViolations)) = $ListBuild(tKey, ##class(OcuPilot.Api.InteropError).#EDITVALUE)
    }
    If tKind = "document" {
        Set tKey = ""
        For {
            Set tKey = $Order(tInput(tKey))
            If tKey = "" Quit
            If tKey '= ..#DOCUMENTFIELD Set tViolations($Increment(tViolations)) = $ListBuild(tKey, ##class(OcuPilot.Api.InteropError).#EDITFIELD)
        }
        If $Data(tInput(..#DOCUMENTFIELD)) {
            Set tText = tInput(..#DOCUMENTFIELD)
            If ($Length(tText) < 1) || ($Length(tText) > ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS) {
                Set tViolations($Increment(tViolations)) = $ListBuild(..#DOCUMENTFIELD, ##class(OcuPilot.Api.InteropError).#EDITVALUE)
            } Else {
                Set tSC = ..ParseEditDocument(pNamespace, tBodyClass, tText, .tNewText, .tParse, .tCaught)
                If $IsObject(tCaught) Quit ..Mapped(tCaught, "the edited message could not be parsed", .pHttpStatus, .pFault)
                If $$$ISERR(tParse) {
                    Do ..LogFault("the edited message could not be parsed", tParse)
                    Set tViolations($Increment(tViolations)) = $ListBuild(..#DOCUMENTFIELD, ##class(OcuPilot.Api.InteropError).#EDITVALUE)
                } ElseIf tNewText '= tBody("text") {
                    Do tChanged.%Push(..#DOCUMENTFIELD, "string")
                    Set tHunk = ##class(OcuPilot.Screen.Tool.ExplorerSaveMint).Hunk(tBody("text"), tNewText)
                    Set tBefore = tHunk.%Get("before")
                    Set tAfter = tHunk.%Get("after")
                    Set pPlan("kind") = "document"
                    Set pPlan("content") = tText
                }
            }
        }
    } ElseIf tKind = "object" {
        For tI = 1:1:tBody("meta") {
            Set tPaths($List(tBody("meta", tI), 2)) = tI
        }
        Kill tPlan
        Set tPlan = 0
        Set tKey = ""
        For {
            Set tKey = $Order(tInput(tKey), 1, tTyped)
            If tKey = "" Quit
            If '$Data(tPaths(tKey)) {
                Set tViolations($Increment(tViolations)) = $ListBuild(tKey, ##class(OcuPilot.Api.InteropError).#EDITFIELD)
                Continue
            }
            If ..SecretPath(tKey) {
                Set tViolations($Increment(tViolations)) = $ListBuild(tKey, ##class(OcuPilot.Api.InteropError).#EDITSECRET)
                Continue
            }
            Set tRecord = tBody("meta", tPaths(tKey))
            If ($List(tRecord, 7) '= "") && (tTyped '= "") && '$ListFind($List(tRecord, 7), tTyped) {
                Set tViolations($Increment(tViolations)) = $ListBuild(tKey, ##class(OcuPilot.Api.InteropError).#EDITVALUE)
                Continue
            }
            If $List(tRecord, 6) && (tTyped = "") {
                Set tViolations($Increment(tViolations)) = $ListBuild(tKey, ##class(OcuPilot.Api.InteropError).#EDITVALUE)
                Continue
            }
            Set tPlan($Increment(tPlan)) = $ListBuild(tKey, $List(tRecord, 3), $List(tRecord, 8), $List(tRecord, 9), tTyped, tTyped)
        }
        If tPlan {
            Set tSC = ..ConvertEditPlan(pNamespace, .tPlan, .tConverted, .tCaught)
            If $IsObject(tCaught) Quit ..Mapped(tCaught, "the edited values could not be judged", .pHttpStatus, .pFault)
            Kill tBadPath
            For tI = 1:1:tConverted {
                Set tBadPath($List(tConverted(tI), 1)) = ""
                Set tViolations($Increment(tViolations)) = $ListBuild($List(tConverted(tI), 1), ##class(OcuPilot.Api.InteropError).#EDITVALUE)
            }
            For tI = 1:1:tPlan {
                Set tPath = $List(tPlan(tI), 1)
                If $Data(tBadPath(tPath)) Continue
                ; A value the field's conversion turned into nothing would clear the field in place of the value the card shows.
                If ($List(tPlan(tI), 5) '= "") && ($List(tPlan(tI), 6) = "") {
                    Set tBadPath(tPath) = ""
                    Set tViolations($Increment(tViolations)) = $ListBuild(tPath, ##class(OcuPilot.Api.InteropError).#EDITVALUE)
                    Continue
                }
                If $List(tPlan(tI), 6) = tBody("logical", tPaths(tPath)) Continue
                Do tChanged.%Push(tPath, "string")
                Set tBefore = tBefore _ $Select(tBefore = "": "", 1: tNL) _ tPath _ ": " _ tBody("display", tPaths(tPath))
                Set tAfter = tAfter _ $Select(tAfter = "": "", 1: tNL) _ tPath _ ": " _ $List(tPlan(tI), 5)
                Set pPlan($Increment(pPlan)) = tPlan(tI)
            }
            If pPlan Set pPlan("kind") = "object"
        }
    }
    If (pAction '= "") && tViolations Quit ..Violations(.tViolations, .pHttpStatus, .pFault)

    ; What the answer echoes of the fields: none of a credential-named field's value.
    Set tKey = ""
    For {
        Set tKey = $Order(tInput(tKey))
        If tKey = "" Quit
        If ..SecretPath(tKey) Kill tInput(tKey)
    }
    Set pRow = {}
    Do pRow.%Set("Namespace", pNamespace, "string")
    Do pRow.%Set("Production", tProduction, "string")
    Do pRow.%Set("Message", pId, "string")
    Do pRow.%Set("Type", $List(tFact, 2), "string")
    Do pRow.%Set("Source", $List(tFact, 3), "string")
    Do pRow.%Set("Target", $List(tFact, 4), "string")
    Do pRow.%Set("BodyClass", tBodyClass, "string")
    Do pRow.%Set("Kind", tKind, "string")
    Do pRow.%Set("Verdict", tVerdict, "string")
    Do pRow.%Set("Form", tForm)
    Do pRow.%Set("Fields", ..CanonicalFields(.tInput, 1), "string")
    Do pRow.%Set("Changed", tChanged)
    Do pRow.%Set("Before", tBefore, "string")
    Do pRow.%Set("After", tAfter, "string")
    Do pRow.%Set("Original", tOriginal, "string")
    Do pRow.%Set("Reviewed", pReviewed, "string")
    Do pRow.%Set("Digest", tDigest, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Save a clone of the body of the message header <var>pHeaderId</var> that carries the changed fields of the plan
/// <var>pPlan</var> (<method>ReadEdit</method>'s), and resend the header with it (Story 20.31): the new header's id in
/// <var>pNewId</var>, the clone's class and id in <var>pCloneClass</var> and <var>pCloneId</var>, the vendor's answer in
/// <var>pStatus</var>. The original body is never changed.</p>
/// <ul>
/// <li>A document is cloned as the classic edit page clones it: the clone keeps the original's <code>ParentId</code>, is cleared,
/// takes the original's <code>Source</code> followed by a carriage return and <parameter>EDITEDCOPY</parameter> and the original
/// body's id, then the parsed text's <code>Separators</code> and, by <code>CopyValues</code>, its segments.</li>
/// <li>An object is cloned (<code>%ConstructClone</code>), each changed field is set along its path on the clone
/// (<method>ApplyFieldsHere</method>, an embedded object the original shares first copied), and the clone is validated.</li>
/// </ul>
/// <p>A resend the vendor refuses after the clone was saved deletes the clone when no header names it. Called while the message's
/// namespace is switched.</p>
/// <p>With <var>pSuspended</var> (Story 24.16) the header is resubmitted under its own id (<method>VendorResubmitWithBody</method>) and
/// <var>pNewId</var> is that id.</p>
ClassMethod EditCloneHere(pHeaderId As %String, ByRef pPlan, Output pNewId As %String, Output pCloneClass As %String, Output pCloneId As %String, Output pStatus As %Status, pSuspended As %Boolean = 0) [ Private ]
{
    Set pNewId = ""
    Set pCloneClass = ""
    Set pCloneId = ""
    Set pStatus = $$$OK
    Set tHeader = ##class(Ens.MessageHeader).%OpenId(pHeaderId)
    If '$IsObject(tHeader) {
        Set pStatus = $$$ERROR($$$GeneralError, "the message header is gone")
        Quit
    }
    Set tClass = tHeader.MessageBodyClassName
    Set tBodyId = tHeader.MessageBodyId
    Set tHeader = ""
    Set tOriginal = ..OpenBodyHere(tClass, tBodyId)
    If '$IsObject(tOriginal) {
        Set pStatus = $$$ERROR($$$GeneralError, "the message body is gone")
        Quit
    }
    If pPlan("kind") = "document" {
        Set tParent = tOriginal.ParentId
        Set tSource = tOriginal.Source _ $Char(13) _ ..#EDITEDCOPY _ tBodyId
        Set tClone = tOriginal.%ConstructClone()
        If '$IsObject(tClone) {
            Set pStatus = $$$ERROR($$$GeneralError, "the message body could not be cloned")
            Quit
        }
        Set tClone.ParentId = tParent
        Set pStatus = tClone.Clear()
        If $$$ISERR(pStatus) Quit
        Set tClone.Source = tSource
        Set tStream = ##class(%Stream.TmpCharacter).%New()
        Do tStream.Write(pPlan("content"))
        Do tStream.Rewind()
        Set tTemp = $ClassMethod(tClass, "ImportFromLibraryStream", tStream, .pStatus)
        If $$$ISERR(pStatus) Quit
        If '$IsObject(tTemp) {
            Set pStatus = $$$ERROR($$$GeneralError, "the text did not give an HL7 message")
            Quit
        }
        Set tClone.Separators = tTemp.Separators
        Set pStatus = tClone.CopyValues(tTemp, "()", "()", "set", "")
        If $$$ISERR(pStatus) Quit
    } Else {
        Set tClone = tOriginal.%ConstructClone(0)
        If '$IsObject(tClone) {
            Set pStatus = $$$ERROR($$$GeneralError, "the message body could not be cloned")
            Quit
        }
        Set tFailed = ..ApplyFieldsHere(tClone, .pPlan, 1)
        If tFailed '= "" {
            Set pStatus = $$$ERROR($$$GeneralError, tFailed)
            Quit
        }
        Set pStatus = tClone.%ValidateObject()
        If $$$ISERR(pStatus) Quit
    }
    If pSuspended {
        Set pStatus = ..VendorResubmitWithBody(pHeaderId, tClone, .pNewId)
    } Else {
        Set pStatus = ..VendorResendWithBody(pHeaderId, tClone, .pNewId)
    }
    Set pCloneClass = tClone.%ClassName(1)
    Set pCloneId = tClone.%Id()
    If $$$ISERR(pStatus) && (pCloneId '= "") {
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(.tStatement, "SELECT COUNT(*) FROM Ens.MessageHeader WHERE MessageBodyClassName = ? AND MessageBodyId = ?", pCloneClass, pCloneId)
        If $IsObject(tResult) && tResult.%Next() && ('tResult.%GetData(1)) {
            Set tClone = ""
            Do $ClassMethod(pCloneClass, "%DeleteId", pCloneId)
        }
    }
}

/// <p><code>Ens.MessageHeader.ResendDuplicatedMessage</code> of the header <var>pHeaderId</var> with the body <var>pClone</var>, the
/// new header's id in <var>pNewId</var>. Called while the message's namespace is switched. Overridable so a test can refuse the
/// resend after the clone was saved; production never overrides it.</p>
ClassMethod VendorResendWithBody(pHeaderId As %String, pClone As %RegisteredObject, Output pNewId As %String) As %Status [ Private ]
{
    Quit ##class(Ens.MessageHeader).ResendDuplicatedMessage(pHeaderId, .pNewId, "", pClone)
}

/// <p><code>Ens.MessageHeader.ResubmitMessage</code> of the suspended header <var>pHeaderId</var> with the body <var>pClone</var> and no new
/// target (Story 24.16), as the classic Edit and Resend page does for a suspended message: the header keeps its id, which is
/// <var>pNewId</var>, takes the clone as its body and goes back on its target's queue. Called while the message's namespace is switched.
/// Overridable so a test can refuse the resubmit after the clone was saved; production never overrides it.</p>
ClassMethod VendorResubmitWithBody(pHeaderId As %String, pClone As %RegisteredObject, Output pNewId As %String) As %Status [ Private ]
{
    Set pNewId = pHeaderId
    Quit ##class(Ens.MessageHeader).ResubmitMessage(pHeaderId, "", pClone)
}

/// <p><method>EditCloneHere</method> in <var>pNamespace</var>, switched by explicit save and restore; a fault is
/// <var>pCaught</var>, with the namespace restored. Only vendor classes and this class run while it is switched. Overridable so a
/// test can fail the resend after the clone was saved; production never overrides it.</p>
ClassMethod VendorEditResend(pNamespace As %String, pHeaderId As %String, ByRef pPlan, Output pNewId As %String, Output pCloneClass As %String, Output pCloneId As %String, Output pCaught, pSuspended As %Boolean = 0) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..EditCloneHere(pHeaderId, .pPlan, .pNewId, .pCloneClass, .pCloneId, .tSC, pSuspended)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit tSC
}

/// <p>Edit and resend the message <var>pId</var> (Story 20.31): the edit is read and judged again first
/// (<method>ReadEdit</method>, composed for this write), and refused with nothing sent when the message reads anything but
/// <code>resend</code> (409 <code>INTEROP.RESEND.NONE</code>) or when no supplied field changes it (409
/// <code>INTEROP.EDIT.NOCHANGE</code>); a <var>pReviewed</var> the message no longer gives is 409
/// <code>INTEROP.RESEND.CHANGED</code>. Then a clone of the body carrying the changes is saved and the header resent with it
/// (<method>EditCloneHere</method>). The answer is <code>{Namespace, Message, NewId, BodyClass, BodyId}</code>: the new header's id
/// and the clone it names. The vendor audits the new header, so this records nothing.</p>
/// <p>For a suspended message (<var>pSuspended</var>, Story 24.16) the header must read <code>resubmit</code> (else 409
/// <code>INTEROP.SUSPENDED.NONE</code>) and is resubmitted under its own id with the clone, <code>NewId</code> being that id; a vendor
/// error reaches the log as its error codes alone (<method>VendorCodesStatus</method>).</p>
ClassMethod PerformEditResend(pNamespace As %String, pId As %String, pFieldsText As %String, pReviewed As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pSuspended As %Boolean = 0) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..ReadEdit(pNamespace, pId, $Select(pSuspended: ..#TYPEEDITRESUBMIT, 1: ..#TYPEEDITRESEND), pFieldsText, pReviewed, .tRow, .tPlan, .pHttpStatus, .pFault, pSuspended)
    If $$$ISERR(tSC) Quit tSC
    If tRow.%Get("Verdict") '= $Select(pSuspended: "resubmit", 1: "resend") Quit ..Conflict($Select(pSuspended: ##class(OcuPilot.Api.InteropError).#SUSPENDEDNONE, 1: ##class(OcuPilot.Api.InteropError).#RESENDNONE), .pHttpStatus, .pFault)
    If 'tRow.%Get("Changed").%Size() Quit ..Conflict(##class(OcuPilot.Api.InteropError).#EDITNOCHANGE, .pHttpStatus, .pFault)
    Set tVendorSC = ..VendorEditResend(pNamespace, pId, .tPlan, .tNewId, .tCloneClass, .tCloneId, .tCaught, pSuspended)
    If pSuspended {
        If $IsObject(tCaught) Set tVendorSC = tCaught.AsStatus()
        If $$$ISERR(tVendorSC) Quit ..Statused(..VendorCodesStatus(tVendorSC), "the edited suspended message could not be resubmitted", .pHttpStatus, .pFault)
    } Else {
        If $IsObject(tCaught) Quit ..Mapped(tCaught, "the edited message could not be resent", .pHttpStatus, .pFault)
        If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the edited message could not be resent", .pHttpStatus, .pFault)
    }
    Set pResult = {}
    Do pResult.%Set("Namespace", pNamespace, "string")
    Do pResult.%Set("Message", pId, "string")
    Do pResult.%Set("NewId", tNewId _ "", "string")
    Do pResult.%Set("BodyClass", tCloneClass, "string")
    Do pResult.%Set("BodyId", tCloneId _ "", "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Serve a Messages call of Story 20.31 after <method>Invoke</method>'s gate: the resend read (<code>RESEND</code>), the resend
/// (<code>RESENDMESSAGES</code>), the edit read (<code>EDIT</code>) and the edit-and-resend (<code>EDITRESEND</code>). The messages
/// travel under <parameter>IDKEY</parameter> as the set <method>MessageSet</method> reads, or for an edit the one message; the
/// fields of an edit under <parameter>FIELDSKEY</parameter>, as JSON object text; the digest a person reviewed under
/// <parameter>DIGESTKEY</parameter>. A read composed for an action carries it under <parameter>ACTIONKEY</parameter>, which must be
/// the write of its own family, else 501.</p>
ClassMethod InvokeMessageAction(pNamespace As %String, pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If ..IsMessageExportType(pType) {
            Set tSC = ..InvokeMessageExport(pNamespace, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tEdit = (pType = ..#TYPEEDIT) || (pType = ..#TYPEEDITRESEND)
        Set tWrite = ..IsMessageWrite(pType)
        Set tAction = $Select(tWrite: pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && (tAction '= $Select(tEdit: ..#TYPEEDITRESEND, 1: ..#TYPERESENDMESSAGES)) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tId = $Get(pQuery(..#IDKEY))
        Set tReviewed = $Get(pQuery(..#DIGESTKEY))
        If tEdit {
            If '$Match(tId, ..#MESSAGEIDPATTERN) {
                Set tSC = ..RefuseCriterion("message", .pHttpStatus, .pFault)
                Quit
            }
            If tWrite {
                Set tSC = ..PerformEditResend(pNamespace, tId, $Get(pQuery(..#FIELDSKEY)), tReviewed, .pResult, .pHttpStatus, .pFault)
            } Else {
                Set tSC = ..ReadEdit(pNamespace, tId, tAction, $Get(pQuery(..#FIELDSKEY)), tReviewed, .pResult, .tPlan, .pHttpStatus, .pFault)
            }
            Quit
        }
        If tWrite {
            Set tSC = ..PerformResend(pNamespace, tId, tReviewed, .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..ReadResend(pNamespace, tId, tAction, tReviewed, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the message resend call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The lines <method>Snippet</method> adds for a Messages write of Story 20.31, from the stored payload of <var>pContext</var> and
/// the query <var>pQuery</var>. A resend: <code>ResendDuplicatedMessage</code> of each id the payload's <code>Verdicts</code> reads
/// <code>resend</code> (none when it holds no verdicts), each failure kept in <code>tSC</code>. An
/// edit-and-resend: the header and its body opened, the body cloned, each supplied field set on the clone along its path (a document
/// as the classic edit page rebuilds it: cleared, its <code>Source</code> annotated, the text parsed from a character stream and
/// copied in), and the header resent with the clone. The body's class and fields are read in the namespace
/// <parameter>NAMESPACEKEY</parameter> names; a class they cannot be read for gives the lines without a field. Every id, name and
/// value is a string literal, so nothing the payload carries runs as code, and every line closes any block it opens. A
/// credential-named field is left out. With <var>pResubmit</var> (Story 24.16) the edit's last line is <code>ResubmitMessage</code> of the
/// suspended header with the clone and no new target, which keeps the header's id, run only while the header still reads Suspended.</p>
ClassMethod MessageSnippet(pType As %String, pId As %String, ByRef pQuery, pContext As %DynamicObject, pResubmit As %Boolean = 0) As %String [ Private ]
{
    Set tNL = $Char(10)
    Set tPayload = ""
    If $IsObject(pContext) && (pContext.%GetTypeOf("payload") = "object") Set tPayload = pContext.%Get("payload")
    If pType = ..#TYPERESENDMESSAGES {
        Set tIds = ""
        If $IsObject(tPayload) && (tPayload.%GetTypeOf("Verdicts") = "string") {
            Set tVerdicts = tPayload.%Get("Verdicts")
            For tI = 1:1:$Length(tVerdicts, ",") {
                Set tPair = $Piece(tVerdicts, ",", tI)
                If $Piece(tPair, "=", 2) = "resend" Set tIds = tIds _ $ListBuild($Piece(tPair, "=", 1))
            }
        }
        Set tText = tNL _ " Set tSC = 1"
        For tI = 1:1:$ListLength(tIds) {
            Set tText = tText _ tNL _ " Set tSC = $System.Status.AppendStatus(tSC, ##class(Ens.MessageHeader).ResendDuplicatedMessage(" _ ..Literal($List(tIds, tI)) _ ", .tNew))"
        }
        Quit tText
    }
    If '..ParseTestFields($Get(pQuery(..#FIELDSKEY)), .tInput, .tBad) Kill tInput
    Set tClass = ""
    Set tMeta = 0
    Set tDocument = 0
    Kill tConvert
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = $Get(pQuery(..#NAMESPACEKEY))
        Set tHeader = ##class(Ens.MessageHeader).%OpenId(pId)
        If $IsObject(tHeader) Set tClass = tHeader.MessageBodyClassName
        Set tHeader = ""
        If $Match(tClass, ..#CLASSNAMEPATTERN) && ##class(%Dictionary.CompiledClass).%ExistsId(tClass) {
            Set tDocument = ''$ClassMethod(tClass, "%Extends", "EnsLib.HL7.Message")
            If 'tDocument {
                Do ..ClassFieldsHere(tClass, .tMeta)
                For tI = 1:1:tMeta {
                    Set tConvert(tI) = ##class(%Dictionary.CompiledMethod).%ExistsId($List(tMeta(tI), 8) _ "||" _ $List(tMeta(tI), 3) _ "DisplayToLogical")
                }
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tClass = ""
        Set tDocument = 0
        Set tMeta = 0
        Kill tConvert
    }
    Set tId = ..Literal(pId)
    Set tText = tNL _ " Set tHeader = ##class(Ens.MessageHeader).%OpenId(" _ tId _ ")"
    Set tText = tText _ tNL _ " Set tOriginal = $ClassMethod(tHeader.MessageBodyClassName, ""%OpenId"", tHeader.MessageBodyId)"
    If tDocument {
        Set tText = tText _ tNL _ " Set tSource = tOriginal.Source _ $Char(13) _ " _ ..Literal(..#EDITEDCOPY) _ " _ tHeader.MessageBodyId"
        Set tText = tText _ tNL _ " Set tParent = tOriginal.ParentId"
        Set tText = tText _ tNL _ " Set tClone = tOriginal.%ConstructClone()"
        Set tText = tText _ tNL _ " Set tClone.ParentId = tParent"
        Set tText = tText _ tNL _ " Set tSC = tClone.Clear()"
        Set tText = tText _ tNL _ " Set tClone.Source = tSource"
        Set tText = tText _ tNL _ " Set tStream = ##class(%Stream.TmpCharacter).%New()"
        Set tText = tText _ tNL _ " Do tStream.Write(" _ ..Literal($Get(tInput(..#DOCUMENTFIELD))) _ ")"
        Set tText = tText _ tNL _ " Do tStream.Rewind()"
        Set tText = tText _ tNL _ " Set tTemp = $ClassMethod(tHeader.MessageBodyClassName, ""ImportFromLibraryStream"", tStream, .tSC)"
        Set tText = tText _ tNL _ " Set tClone.Separators = tTemp.Separators"
        Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = tClone.CopyValues(tTemp, ""()"", ""()"", ""set"", """")"
    } Else {
        Set tText = tText _ tNL _ " Set tClone = tOriginal.%ConstructClone(0)"
        Kill tVariable
        Set tVariables = 0
        For tI = 1:1:tMeta {
            Set tRecord = tMeta(tI)
            Set tPath = $List(tRecord, 2)
            If '$Data(tInput(tPath)) || ..SecretPath(tPath) Continue
            Set tCurrent = "tClone"
            For tJ = 1:1:$Length(tPath, ".") - 1 {
                Set tPrefix = $Piece(tPath, ".", 1, tJ)
                If '$Data(tVariable(tPrefix)) {
                    Set tVariable(tPrefix) = "tPart" _ $Increment(tVariables)
                    Set tText = tText _ tNL _ " Set " _ tVariable(tPrefix) _ " = $Select($IsObject($Property(" _ tCurrent _ ", " _ ..Literal($Piece(tPath, ".", tJ)) _ ")): $Property(" _ tCurrent _ ", " _ ..Literal($Piece(tPath, ".", tJ)) _ ").%ConstructClone(1), 1: $ClassMethod(" _ ..Literal($List($List(tRecord, 9), tJ)) _ ", ""%New""))"
                    Set tText = tText _ tNL _ " Set $Property(" _ tCurrent _ ", " _ ..Literal($Piece(tPath, ".", tJ)) _ ") = " _ tVariable(tPrefix)
                }
                Set tCurrent = tVariable(tPrefix)
            }
            Set tValue = ..Literal(tInput(tPath))
            If tInput(tPath) '= "" && $Get(tConvert(tI)) Set tValue = "$ClassMethod(" _ ..Literal($List(tRecord, 8)) _ ", " _ ..Literal($List(tRecord, 3) _ "DisplayToLogical") _ ", " _ tValue _ ")"
            Set tText = tText _ tNL _ " Set $Property(" _ tCurrent _ ", " _ ..Literal($List(tRecord, 3)) _ ") = " _ tValue
        }
        Set tText = tText _ tNL _ " Set tSC = tClone.%ValidateObject()"
    }
    If pResubmit Quit tText _ tNL _ " If $System.Status.IsOK(tSC) && (tHeader.Status = " _ ..#STATUSSUSPENDEDVALUE _ ") Set tSC = ##class(Ens.MessageHeader).ResubmitMessage(" _ tId _ ", """", tClone)"
    Quit tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = ##class(Ens.MessageHeader).ResendDuplicatedMessage(" _ tId _ ", .tNew, """", tClone)"
}

/// <p>Whether a queue or job action of type <var>pType</var> is refused for the target state the arguments give, and the code
/// it is refused with, or <code>""</code> when it may go ahead (Story 20.23): whatever the vendor would answer as a silent
/// success is refused here by its own code, and nothing is called. Pure.</p>
/// <ul>
/// <li><parameter>TYPEABORTQUEUE</parameter> with <var>pEntries</var> 0: <code>INTEROP.QUEUE.EMPTY</code>. <var>pEntries</var> is
/// how many entries the queue read enumerated.</li>
/// <li>A job action (<parameter>TYPEABORTJOB</parameter>, <parameter>TYPESUSPENDJOB</parameter>, <parameter>TYPESTOPJOB</parameter>)
/// with <var>pDead</var>, a job no process holds: <code>INTEROP.JOB.DEAD</code>.</li>
/// <li>An abort or suspend unless <var>pStatus</var> reads <code>Retry</code> and <var>pActive</var>, the message the job is
/// working on, is not empty: <code>INTEROP.JOB.NOTRETRYING</code>. The vendor answers either for any job and leaves its request
/// set, and a request left on an idle job kept the next production stop from quiescing (measured).</li>
/// </ul>
ClassMethod RuntimeRefusal(pType As %String, pDead As %Boolean, pStatus As %String, pActive As %String, pEntries As %Integer) As %String
{
    If (pType = ..#TYPEABORTQUEUE) && 'pEntries Quit ##class(OcuPilot.Api.InteropError).#QUEUEEMPTY
    If ((pType = ..#TYPEABORTJOB) || (pType = ..#TYPESUSPENDJOB) || (pType = ..#TYPESTOPJOB)) && pDead Quit ##class(OcuPilot.Api.InteropError).#JOBDEAD
    If ((pType = ..#TYPEABORTJOB) || (pType = ..#TYPESUSPENDJOB)) && ((pStatus '= "Retry") || (pActive = "")) Quit ##class(OcuPilot.Api.InteropError).#JOBNOTRETRYING
    Quit ""
}

/// <p><method>RuntimeRefusal</method> for the row <var>pRow</var> a queue or job read answered, which carries the fields it
/// judges: <code>Entries</code>, <code>Dead</code>, <code>Status</code> and <code>ActiveMessage</code>.</p>
ClassMethod RowRefusal(pType As %String, pRow As %DynamicObject) As %String
{
    If '$IsObject(pRow) Quit ""
    Quit ..RuntimeRefusal(pType, ''pRow.%Get("Dead"), pRow.%Get("Status"), pRow.%Get("ActiveMessage"), +pRow.%Get("Entries"))
}

/// <p>The digest that stands for the queue entries <var>pFound</var> (<method>GatherQueueEntries</method>'s array): the
/// SHA-256 of their <code>priority:index:messageId</code> lines in the order given, as lower-case hex. The same entries in
/// another order give another digest. Pure.</p>
ClassMethod QueueDigest(ByRef pFound) As %String
{
    Set tText = ""
    For tI = 1:1:+$Get(pFound) {
        Set tText = tText _ $List(pFound(tI), 1) _ ":" _ $List(pFound(tI), 2) _ ":" _ $List(pFound(tI), 3) _ $Char(10)
    }
    Quit ..Sha256Hex(tText)
}

/// <p>Serve a typed call on Queues, QueueItems or Jobs (Story 20.23) after <method>Invoke</method>'s gate: the read of one
/// queue, entry or job, or one of the five writes. The target is named under <parameter>IDKEY</parameter>: 400 when it is
/// not, with the reason of its kind. An <parameter>ACTIONKEY</parameter> that is not one of this endpoint's writes is 501.</p>
ClassMethod InvokeTyped(pNamespace As %String, pEndpoint As %String, pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tId = $Get(pQuery(..#IDKEY))
    If tId = "" {
        Set tReason = $Case(pEndpoint, ..#ENDPOINTQUEUES: ..#REASONQUEUEREQUIRED, ..#ENDPOINTQUEUEITEMS: ..#REASONMESSAGEREQUIRED, : ..#REASONJOBREQUIRED)
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, tReason, .pHttpStatus, .pFault)
    }
    Set tWrite = ..IsRuntimeWrite(pType)
    Set tAction = $Select(tWrite: pType, 1: $Get(pQuery(..#ACTIONKEY)))
    If (tAction '= "") && '(..IsRuntimeWrite(tAction) && ..Serves(pEndpoint, tAction)) {
        Quit ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
    }
    If tWrite Quit ..PerformRuntime(pNamespace, pType, tId, .pQuery, .pResult, .pHttpStatus, .pFault)
    If pType = ..#TYPEQUEUE {
        Set tSC = ..ReadQueue(pNamespace, tId, .tRow, .tFound, .pHttpStatus, .pFault)
    } ElseIf pType = ..#TYPEENTRY {
        Set tSC = ..ReadEntry(pNamespace, tId, .tRow, .pHttpStatus, .pFault)
    } Else {
        Set tSC = ..ReadJob(pNamespace, tId, .tRow, .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) Quit tSC
    If tAction '= "" {
        Set tCode = ..RowRefusal(tAction, tRow)
        If tCode '= "" Quit ..Conflict(tCode, .pHttpStatus, .pFault)
    }
    Set pResult = tRow
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The queue <var>pName</var> as the queue abort reads it, in <var>pRow</var> (<code>{Name, Count, Active, Created, Entries,
/// Digest, Namespace}</code>), with the entries <code>Entries</code> and <code>Digest</code> stand for in <var>pFound</var>:
/// the queue's first <parameter>ABORTMAX</parameter> entries, enumerated without opening their headers. A queue the vendor
/// does not list is 404 <code>PORT.NOTFOUND</code>, unlogged.</p>
ClassMethod ReadQueue(pNamespace As %String, pName As %String, Output pRow As %DynamicObject, ByRef pFound, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set tSC = ..ListQueues(pNamespace, 0, .tRows, .pHttpStatus, .pFault, pName)
    If $$$ISERR(tSC) Quit tSC
    If 'tRows.%Size() Quit ..Absent(.pHttpStatus, .pFault)
    Set tSC = ..GatherQueueEntries(pNamespace, pName, "", ..#ABORTMAX, .pFound, .tCaught, "", 1)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the queue's entries could not be read", .pHttpStatus, .pFault)
    Set pRow = tRows.%Get(0)
    Do pRow.%Set("Entries", pFound, "number")
    Do pRow.%Set("Digest", ..QueueDigest(.pFound), "string")
    Do pRow.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The message header <var>pId</var> of <var>pNamespace</var>: <var>pExists</var>, the queue its own
/// <code>TargetQueueName</code> names and its status as the display word. A fault is <var>pCaught</var>, with the namespace
/// restored. No body is opened.</p>
/// <p>For the resend reads (Story 20.31) it also answers the header's type as the display word, source and target configuration
/// names, body class and body id, whether the body it names is still there (<var>pBodyExists</var>: a compiled class that holds the
/// id; <code>0</code> too when the header names none), and whether the queue its own <code>TargetQueueName</code> names exists
/// (<var>pQueueExists</var>: <code>Ens.Queue.Exists</code> throws on an empty name, so an empty name reads <code>0</code>).</p>
ClassMethod HeaderFacts(pNamespace As %String, pId As %String, Output pExists As %Boolean, Output pQueue As %String, Output pStatus As %String, Output pCaught, Output pType As %String, Output pSource As %String, Output pTarget As %String, Output pBodyClass As %String, Output pBodyId As %String, Output pBodyExists As %Boolean, Output pQueueExists As %Boolean) As %Status [ Private ]
{
    Set pExists = 0
    Set pQueue = ""
    Set pStatus = ""
    Set pCaught = ""
    Set pType = ""
    Set pSource = ""
    Set pTarget = ""
    Set pBodyClass = ""
    Set pBodyId = ""
    Set pBodyExists = 0
    Set pQueueExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tHeader = ##class(Ens.MessageHeader).%OpenId(pId)
        If $IsObject(tHeader) {
            Set pExists = 1
            Set pQueue = tHeader.TargetQueueName
            Set pStatus = ##class(Ens.DataType.MessageStatus).LogicalToDisplay(tHeader.Status)
            Set pType = ##class(Ens.DataType.MessageType).LogicalToDisplay(tHeader.Type)
            Set pSource = tHeader.SourceConfigName
            Set pTarget = tHeader.TargetConfigName
            Set pBodyClass = tHeader.MessageBodyClassName
            Set pBodyId = tHeader.MessageBodyId
            Set pBodyExists = ..BodyExistsHere(pBodyClass, pBodyId)
            Set pQueueExists = $Select(pQueue = "": 0, 1: ''##class(Ens.Queue).Exists(pQueue))
        }
        Set tHeader = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The queue entry of the message header <var>pId</var>, in <var>pRow</var> (<method>QueueEntryRow</method>'s fields and
/// <code>Namespace</code>), found in the queue the header's own <code>TargetQueueName</code> names, so a message to a
/// business process of pool size 0 is found in <parameter>ACTORQUEUE</parameter>. A header that is gone, one that names no
/// queue and one whose message no longer waits in its queue are each 404 <code>PORT.NOTFOUND</code>, unlogged. Only the first
/// <parameter>QUEUESCANMAX</parameter> entries of the queue are examined.</p>
ClassMethod ReadEntry(pNamespace As %String, pId As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    If '$Match(pId, "^[1-9][0-9]*$") Quit ..Absent(.pHttpStatus, .pFault)
    Set tSC = ..HeaderFacts(pNamespace, pId, .tExists, .tQueue, .tStatus, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the message header could not be read", .pHttpStatus, .pFault)
    If 'tExists || (tQueue = "") Quit ..Absent(.pHttpStatus, .pFault)
    Set tSC = ..GatherQueueEntries(pNamespace, tQueue, "", 0, .tFound, .tCaught, pId)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the message's queue could not be read", .pHttpStatus, .pFault)
    If 'tFound Quit ..Absent(.pHttpStatus, .pFault)
    Set pRow = ..QueueEntryRow(tQueue, tFound(1))
    Do pRow.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The job of process id <var>pPid</var> among the running production's, across every host, in <var>pRow</var>
/// (<method>JobRow</method>'s fields with <code>Production</code>, <code>Item</code> and <code>Namespace</code>). A namespace
/// with no running or troubled production is 409 <parameter>OcuPilot.Api.InteropError.NOTRUNNING</parameter>; a pid no job of
/// that production holds is 404 <code>PORT.NOTFOUND</code>, unlogged.</p>
ClassMethod ReadJob(pNamespace As %String, pPid As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set tSC = ..GatherJobs(pNamespace, "", "", 0, .tCurrent, .tFound, .tCaught, pPid)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the job could not be read", .pHttpStatus, .pFault)
    If tCurrent = "" Quit ..Conflict(##class(OcuPilot.Api.InteropError).#NOTRUNNING, .pHttpStatus, .pFault)
    If 'tFound Quit ..Absent(.pHttpStatus, .pFault)
    Set pRow = ..JobRow(tFound(1), tCurrent)
    Do pRow.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>A vendor status <var>pStatus</var> from a job action in this port's own words: a job that did not stop even forced is
/// 409 <parameter>OcuPilot.Api.InteropError.JOBNOTSTOPPED</parameter>; the request lock and the status lock the vendor takes
/// on a job are 503 <code>PORT.UNAVAILABLE</code>; anything else is <method>Statused</method>'s.</p>
ClassMethod JobStatused(pStatus As %Status, pMessage As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    If ..HasCode(pStatus, ..#CODEJOBNOTSTOPPED) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#JOBNOTSTOPPED, .pHttpStatus, .pFault)
    If ..HasCode(pStatus, ..#CODEJOBLOCK) || ..HasCode(pStatus, ..#CODEJOBSTATUSLOCKED) Quit ..Unavailable(.pHttpStatus, .pFault)
    Quit ..Statused(pStatus, pMessage, .pHttpStatus, .pFault)
}

/// <p>Run queue or job write <var>pType</var> on <var>pId</var> in <var>pNamespace</var> (Story 20.23) and answer what it
/// leaves. The target is read again and judged by <method>RowRefusal</method> first, under the caller's per-target hold, so a
/// state that moved since the review is refused by its own code with no vendor call.</p>
ClassMethod PerformRuntime(pNamespace As %String, pType As %String, pId As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If pType = ..#TYPEABORTMESSAGE Quit ..PerformAbortMessage(pNamespace, pId, .pResult, .pHttpStatus, .pFault)
    If pType = ..#TYPEABORTQUEUE Quit ..PerformAbortQueue(pNamespace, pId, $Get(pQuery(..#DIGESTKEY)), ''$Data(pQuery(..#DIGESTKEY)), .pResult, .pHttpStatus, .pFault)
    Quit ..PerformJobAction(pNamespace, pType, pId, .pResult, .pHttpStatus, .pFault)
}

/// <p><code>Ens.Queue.AbortItem</code> of one entry, in <var>pNamespace</var>, switched by explicit save and restore. A thrown
/// fault is <var>pCaught</var>. Only vendor classes run while it is switched.</p>
ClassMethod VendorAbortItem(pNamespace As %String, pQueue As %String, pPriority As %Integer, pIndex As %Integer, Output pCaught) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tSC = ##class(Ens.Queue).AbortItem(pQueue, pPriority, pIndex)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit tSC
}

/// <p>Abort the one waiting message <var>pId</var> (<code>AbortItem</code> at the queue, priority and index its read gives).
/// The entry is read first: a message that is gone or no longer waits is 404, with no vendor call. A vendor error whose entry
/// is gone on a re-read is 404 too. The answer is the entry's row with the status the header reads once aborted.</p>
ClassMethod PerformAbortMessage(pNamespace As %String, pId As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..ReadEntry(pNamespace, pId, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tQueue = tRow.%Get("Queue")
    Set tVendorSC = ..VendorAbortItem(pNamespace, tQueue, tRow.%Get("Priority"), tRow.%Get("Index"), .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the message abort failed", .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) {
        Set tAgainSC = ..ReadEntry(pNamespace, pId, .tAgain, .tAgainHttp, .tAgainFault)
        If $$$ISERR(tAgainSC) && (tAgainHttp = 404) Quit ..Absent(.pHttpStatus, .pFault)
        Quit ..Statused(tVendorSC, "the message abort failed", .pHttpStatus, .pFault)
    }
    Set tSC = ..HeaderFacts(pNamespace, pId, .tExists, .tHeaderQueue, .tStatus, .tCaught)
    If tExists && (tStatus '= "") Do tRow.%Set("Status", tStatus, "string")
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("queue", tQueue, "string")
    Do ..AuditRuntime(..#VERBABORT, ..#ENTITYMESSAGE, pId, tEffects)
    Set pResult = tRow
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Abort the messages of queue <var>pName</var> its read enumerated, one <code>AbortItem</code> each, and leave the rest.
/// An empty queue is 409 <code>INTEROP.QUEUE.EMPTY</code>. With <var>pHasDigest</var>, a queue whose enumerated entries no
/// longer give <var>pDigest</var> is 409 <code>INTEROP.QUEUE.CHANGED</code>, with nothing aborted. An entry that left the
/// queue meanwhile counts <code>Skipped</code>; one the vendor refuses while it is still queued fails the call. The answer is
/// <code>{Name, Count, Aborted, Skipped, Namespace}</code>, <code>Count</code> the entries enumerated.</p>
ClassMethod PerformAbortQueue(pNamespace As %String, pName As %String, pDigest As %String, pHasDigest As %Boolean, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..ReadQueue(pNamespace, pName, .tRow, .tFound, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tCode = ..RowRefusal(..#TYPEABORTQUEUE, tRow)
    If tCode '= "" Quit ..Conflict(tCode, .pHttpStatus, .pFault)
    If pHasDigest && (pDigest '= tRow.%Get("Digest")) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#QUEUECHANGED, .pHttpStatus, .pFault)
    Set tAborted = 0
    Set tCaughtAny = ""
    Kill tRefused
    For tI = 1:1:tFound {
        Set tVendorSC = ..VendorAbortItem(pNamespace, pName, $List(tFound(tI), 1), $List(tFound(tI), 2), .tCaught)
        If $IsObject(tCaught) {
            Set tCaughtAny = tCaught
            Quit
        }
        If $$$ISOK(tVendorSC) {
            Set tAborted = tAborted + 1
        } Else {
            Set tRefused($Increment(tRefused)) = $ListBuild($List(tFound(tI), 1), $List(tFound(tI), 2), tVendorSC)
        }
    }
    ; An entry the vendor refused is skipped only if it has left the queue; one still queued is a real refusal.
    Set tSkipped = 0
    Set tHardSC = $$$OK
    If $Get(tRefused) {
        Set tSC = ..GatherQueueEntries(pNamespace, pName, "", ..#ABORTMAX, .tNow, .tNowCaught, "", 1)
        Kill tStillQueued
        If '$IsObject(tNowCaught) {
            For tI = 1:1:tNow {
                Set tStillQueued($List(tNow(tI), 1), $List(tNow(tI), 2)) = ""
            }
        }
        For tI = 1:1:tRefused {
            If '$IsObject(tNowCaught) && '$Data(tStillQueued($List(tRefused(tI), 1), $List(tRefused(tI), 2))) {
                Set tSkipped = tSkipped + 1
            } ElseIf $$$ISOK(tHardSC) {
                Set tHardSC = $List(tRefused(tI), 3)
            }
        }
    }
    If tAborted > 0 {
        Set tEffects = {}
        Do tEffects.%Set("namespace", pNamespace, "string")
        Do tEffects.%Set("queue", pName, "string")
        Do tEffects.%Set("aborted", tAborted, "number")
        Do tEffects.%Set("skipped", tSkipped, "number")
        Do ..AuditRuntime(..#VERBABORTALL, ..#ENTITYQUEUE, pName, tEffects)
    }
    If $IsObject(tCaughtAny) Quit ..Mapped(tCaughtAny, "the queue abort failed", .pHttpStatus, .pFault)
    If $$$ISERR(tHardSC) Quit ..Statused(tHardSC, "the queue abort failed", .pHttpStatus, .pFault)
    Set pResult = {}
    Do pResult.%Set("Name", pName, "string")
    Do pResult.%Set("Count", tFound, "number")
    Do pResult.%Set("Aborted", tAborted, "number")
    Do pResult.%Set("Skipped", tSkipped, "number")
    Do pResult.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The vendor call of job write <var>pType</var> on process <var>pPid</var>, in <var>pNamespace</var>, switched by explicit
/// save and restore: <code>AbortOperation</code>, <code>SuspendOperation</code>, or <code>Stop</code> with the production's
/// update timeout capped at <var>pCap</var> seconds and force on, as the classic Jobs page stops. A thrown fault is
/// <var>pCaught</var>. Only vendor classes run while it is switched.</p>
ClassMethod VendorJob(pNamespace As %String, pType As %String, pPid As %String, pCap As %Integer, Output pCaught) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If pType = ..#TYPEABORTJOB {
            Set tSC = ##class(Ens.Job).AbortOperation(pPid)
        } ElseIf pType = ..#TYPESUSPENDJOB {
            Set tSC = ##class(Ens.Job).SuspendOperation(pPid)
        } Else {
            Set tTimeout = ##class(Ens.Director).GetRunningProductionUpdateTimeout()
            If tTimeout > pCap Set tTimeout = pCap
            Set tSC = ##class(Ens.Job).Stop(pPid, tTimeout, 1)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit tSC
}

/// <p>Abort or suspend the message job <var>pPid</var> is retrying, or stop the job (Story 20.23). The job is read first and
/// judged by <method>RowRefusal</method>: a namespace with no running production is 409
/// <code>INTEROP.PRODUCTION.NOTRUNNING</code>, a pid no job of it holds 404, a dead job 409 <code>INTEROP.JOB.DEAD</code>, and an
/// abort or suspend of a job not retrying 409 <code>INTEROP.JOB.NOTRETRYING</code>, each with no vendor call and no request left
/// for the job. A stop passes the production's update timeout capped at <method>StopSeconds</method>.</p>
/// <p>An abort or suspend answers the job's row read again; a stop answers <code>{Job, Host, Stopped, Namespace}</code>.</p>
ClassMethod PerformJobAction(pNamespace As %String, pType As %String, pPid As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..ReadJob(pNamespace, pPid, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tCode = ..RowRefusal(pType, tRow)
    If tCode '= "" Quit ..Conflict(tCode, .pHttpStatus, .pFault)
    Set tVendorSC = ..VendorJob(pNamespace, pType, pPid, ..StopSeconds(), .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the job " _ pType _ " failed", .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..JobStatused(tVendorSC, "the job " _ pType _ " failed", .pHttpStatus, .pFault)
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("host", tRow.%Get("Host"), "string")
    If pType = ..#TYPESTOPJOB {
        Do ..AuditRuntime(..#VERBSTOP, ..#ENTITYJOB, pPid, tEffects)
        Set pResult = {}
        Do pResult.%Set("Job", pPid, "string")
        Do pResult.%Set("Host", tRow.%Get("Host"), "string")
        Do pResult.%Set("Stopped", 1, "boolean")
        Do pResult.%Set("Namespace", pNamespace, "string")
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Do ..AuditRuntime($Select(pType = ..#TYPEABORTJOB: ..#VERBABORT, 1: ..#VERBSUSPEND), ..#ENTITYJOB, pPid, tEffects)
    Set pResult = tRow
    If $$$ISOK(..ReadJob(pNamespace, pPid, .tAfter, .tAfterHttp, .tAfterFault)) Set pResult = tAfter
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Record OcuPilot's own <code>ConfigChange</code> row for one queue, job or lookup write, a lookup export, a host test or a data
/// transformation test, that read OK (AD-15, Stories 20.23, 20.5, 20.6 and 20.27), from whichever caller made it: the vendor records none. <var>pVerb</var> is one of the
/// <code>VERB</code> parameters, <var>pType</var> the entity type of the target and <var>pId</var> its id; <var>pEffects</var>
/// names the namespace and, as the action has them, the queue, the table, the counts, the host or the classes and status of a
/// transformation run, and never a message's content or an entry's value. It never fails the write.
/// Called after the namespace is restored. A seam a test reads through the audit database.</p>
ClassMethod AuditRuntime(pVerb As %String, pType As %String, pId As %String, pEffects As %DynamicObject)
{
    Try {
        Do ##class(OcuPilot.Kernel.Audit.Event).Record(pVerb, pType, pId, {}, 0, pEffects)
    } Catch ex {
        Do ..LogFault("the interoperability write could not be audited", ex.AsStatus())
    }
}

/// <p><code>objectscript</code> for each write this port carries; <code>""</code> for
/// <parameter>TYPELIST</parameter>, <parameter>TYPESTATE</parameter>, <parameter>TYPEITEM</parameter>, the queue, entry and job
/// reads and anything else, which have no script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If (pEndpoint = ..#ENDPOINTITEMS) && (..IsItemWrite(pType) || ..IsItemRunWrite(pType)) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTSETTINGS) && ..IsSettingWrite(pType) Quit "objectscript"
    If ..IsRuntimeWrite(pType) && ..Serves(pEndpoint, pType) Quit "objectscript"
    If (..IsLookupWrite(pType) || ((pType = ..#TYPEEXPORT) && (pEndpoint = ..#ENDPOINTLOOKUPTABLES))) && ..Serves(pEndpoint, pType) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTBUSINESSPARTNERS) && ..IsPartnerWrite(pType) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTDEFAULTSETTINGS) && ..IsDefaultSettingWrite(pType) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTCREDENTIALS) && ..IsCredentialWrite(pType) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTSCHEDULES) && ..IsScheduleWrite(pType) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTPURGESETTINGS) && (pType = ..#TYPEPURGESETTINGSET) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTPURGE) && (pType = ..#TYPEPURGE) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTARCHIVESETTINGS) && (pType = ..#TYPEARCHIVESETTINGSET) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTARCHIVE) && (pType = ..#TYPEARCHIVE) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTMANAGEDALERTS) && (pType = ..#TYPEUPDATEALERT) Quit "objectscript"
    If ((pEndpoint = ..#ENDPOINTRULELOG) || (pEndpoint = ..#ENDPOINTPROCESSLOG)) && ..IsLogPurgeWrite(pType) && ..Serves(pEndpoint, pType) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTSUSPENDEDMESSAGES) && ..IsSuspendedWrite(pType) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTITEMTEST) && ..IsTestWrite(pType) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTTRANSFORMS) && (pType = ..#TYPETRANSFORMTEST) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTMESSAGES) && (..IsMessageWrite(pType) || (pType = ..#TYPEEXPORTMESSAGES)) Quit "objectscript"
    If pEndpoint '= ..#ENDPOINTPRODUCTIONS Quit ""
    If ..IsWrite(pType) || ..IsStartupWrite(pType) Quit "objectscript"
    Quit ""
}

/// <p><method>Perform</method>'s and <method>PerformItem</method>'s branches as a script (AD-59), in the
/// namespace <parameter>NAMESPACEKEY</parameter> names: <code>Ens.Director</code>'s
/// <code>StartProduction</code> of the one production, <code>StopProduction</code>,
/// <code>RestartProduction</code> and <code>UpdateProduction</code> with the production's own timeout capped
/// at <parameter>STOPSECONDS</parameter>, and <code>RecoverProduction</code>; an item's
/// <code>EnableConfigItem</code>, add, copy, change of class and remove, each followed by the production class's
/// <code>SaveToClass</code>; the queue and job actions (<method>RuntimeSnippet</method>); and the message resend and edit and resend
/// (<method>MessageSnippet</method>); and the business partner writes (<method>PartnerSnippet</method>). A read writes nothing and answers no step. Every value is rendered as a
/// string literal, so nothing the query carries runs as code, and every line closes any block it opens.
/// Whoever runs the script is checked by the vendor's own run resource, and a recover by the namespace's
/// database alone; an item write is checked by the databases alone.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tText = " Set $NAMESPACE = " _ ..Literal($Get(pQuery(..#NAMESPACEKEY)))
    If pEndpoint = ..#ENDPOINTPURGESETTINGS {
        Set tPart = ..PurgeSettingSnippet($Get(pQuery(..#IDKEY)), pBody)
        If tPart = "" Quit []
        Set tText = tText _ tPart
    } ElseIf pEndpoint = ..#ENDPOINTPURGE {
        Set tPart = ..PurgeSnippet($Get(pQuery(..#PURGEDAYSKEY)))
        If tPart = "" Quit []
        Set tText = tText _ tPart
    } ElseIf pEndpoint = ..#ENDPOINTARCHIVESETTINGS {
        Set tPart = ..ArchiveSettingSnippet($Get(pQuery(..#IDKEY)), pBody, $Get(pQuery(..#NAMESPACEKEY)))
        If tPart = "" Quit []
        Set tText = tText _ tPart
    } ElseIf pEndpoint = ..#ENDPOINTARCHIVE {
        Set tText = tText _ ..ArchiveSnippet()
    } ElseIf pEndpoint = ..#ENDPOINTMANAGEDALERTS {
        Set tPart = ..AlertSnippet($Get(pQuery(..#IDKEY)), .pQuery)
        If tPart = "" Quit []
        Set tText = tText _ tPart
    } ElseIf (pEndpoint = ..#ENDPOINTRULELOG) || (pEndpoint = ..#ENDPOINTPROCESSLOG) {
        Set tPart = ..LogPurgeSnippet(pEndpoint, $Get(pQuery(..#NAMESPACEKEY)), $Get(pQuery(..#PURGEDAYSKEY)))
        If tPart = "" Quit []
        Set tText = tText _ tPart
    } ElseIf pEndpoint = ..#ENDPOINTSUSPENDEDMESSAGES {
        Set tPart = ..SuspendedSnippet(pType, $Get(pQuery(..#IDKEY)), .pQuery, pContext)
        If tPart = "" Quit []
        Set tText = tText _ tPart
    } ElseIf pEndpoint = ..#ENDPOINTITEMS {
        Set tText = tText _ ..ItemSnippet(pType, $Get(pQuery(..#IDKEY)), pBody, .pQuery, pContext)
    } ElseIf pEndpoint = ..#ENDPOINTSETTINGS {
        Set tText = tText _ ..SettingSnippet(pType, $Get(pQuery(..#IDKEY)), pBody)
    } ElseIf pEndpoint = ..#ENDPOINTBUSINESSPARTNERS {
        Set tText = tText _ ..PartnerSnippet(pType, $Get(pQuery(..#IDKEY)), pBody)
    } ElseIf pEndpoint = ..#ENDPOINTDEFAULTSETTINGS {
        Set tText = tText _ ..DefaultSettingSnippet(pType, $Get(pQuery(..#IDKEY)), pBody)
    } ElseIf pEndpoint = ..#ENDPOINTCREDENTIALS {
        Set tText = tText _ ..CredentialSnippet(pType, $Get(pQuery(..#IDKEY)), pBody)
    } ElseIf pEndpoint = ..#ENDPOINTSCHEDULES {
        Set tText = tText _ ..ScheduleSnippet(pType, $Get(pQuery(..#IDKEY)), pBody)
    } ElseIf pEndpoint = ..#ENDPOINTITEMTEST {
        Set tText = tText _ ..TestSnippet($Get(pQuery(..#IDKEY)), .pQuery)
    } ElseIf pEndpoint = ..#ENDPOINTTRANSFORMS {
        Set tText = tText _ ..TransformSnippet($Get(pQuery(..#IDKEY)), .pQuery)
    } ElseIf (pEndpoint = ..#ENDPOINTMESSAGES) && (pType = ..#TYPEEXPORTMESSAGES) {
        Set tPart = ..ExportSnippet($Get(pQuery(..#IDKEY)), .pQuery, pContext)
        If tPart = "" Quit []
        Set tText = tText _ tPart
    } ElseIf pEndpoint = ..#ENDPOINTMESSAGES {
        Set tText = tText _ ..MessageSnippet(pType, $Get(pQuery(..#IDKEY)), .pQuery, pContext)
    } ElseIf ..IsRuntimeWrite(pType) {
        Set tText = tText _ ..RuntimeSnippet(pType, $Get(pQuery(..#IDKEY)), pContext)
    } ElseIf (pType = ..#TYPEIMPORT) || (pType = ..#TYPEEXPORT) {
        Set tText = tText _ ..TransferSnippet(pType, $Get(pQuery(..#IDKEY)), .pQuery)
    } ElseIf ..IsLookupWrite(pType) {
        Set tText = tText _ ..LookupSnippet(pType, $Get(pQuery(..#IDKEY)), pBody)
    } ElseIf ..IsStartupWrite(pType) {
        Set tText = tText _ ..StartupSnippet(pType, $Get(pQuery(..#IDKEY)), pBody)
    } ElseIf pType = ..#TYPESTART {
        Set tText = tText _ $Char(10) _ " Set tSC = ##class(Ens.Director).StartProduction(" _ ..Literal($Get(pQuery(..#IDKEY))) _ ")"
    } ElseIf pType = ..#TYPERECOVER {
        Set tText = tText _ $Char(10) _ " Set tSC = ##class(Ens.Director).RecoverProduction()"
    } ElseIf pType = ..#TYPEUPDATE {
        Set tText = tText _ $Char(10) _ " Set tTimeout = ##class(Ens.Director).GetRunningProductionUpdateTimeout()"
        Set tText = tText _ $Char(10) _ " If tTimeout > " _ ..#STOPSECONDS _ " Set tTimeout = " _ ..#STOPSECONDS
        Set tText = tText _ $Char(10) _ " Set tSC = ##class(Ens.Director).UpdateProduction(tTimeout, 0)"
    } Else {
        Set tText = tText _ $Char(10) _ " Set tTimeout = ##class(Ens.Director).GetRunningProductionShutdownTimeout()"
        Set tText = tText _ $Char(10) _ " If tTimeout > " _ ..#STOPSECONDS _ " Set tTimeout = " _ ..#STOPSECONDS
        Set tText = tText _ $Char(10) _ " Set tSC = ##class(Ens.Director)." _ $Select(pType = ..#TYPESTOP: "StopProduction", 1: "RestartProduction") _ "(tTimeout, 0)"
    }
    Set tStep = {}
    Do tStep.%Set("kind", "objectscript", "string")
    Do tStep.%Set("text", tText, "string")
    Quit [(tStep)]
}

/// <p>The lines <method>Snippet</method> adds for the queue or job write <var>pType</var> (Story 20.23): the reviewed values
/// of <var>pContext</var>'s <code>payload</code>, or the id <var>pId</var> the query names, each a string literal.
/// <code>AbortItem</code> of the queue, priority and index the entry read gave; an <code>EnumerateItem</code> loop of the queue
/// calling <code>AbortItem</code> for at most the payload's <code>Entries</code> (<parameter>ABORTMAX</parameter> when it holds
/// none) and keeping every failure in <code>tSC</code>; <code>AbortOperation</code> or <code>SuspendOperation</code> of the job; or the production's
/// update timeout capped at <parameter>STOPSECONDS</parameter> and <code>Stop</code> of the job with force on. Every line closes
/// any block it opens.</p>
ClassMethod RuntimeSnippet(pType As %String, pId As %String, pContext As %DynamicObject) As %String [ Private ]
{
    Set tNL = $Char(10)
    Set tPayload = ""
    If $IsObject(pContext) && (pContext.%GetTypeOf("payload") = "object") Set tPayload = pContext.%Get("payload")
    If pType = ..#TYPEABORTMESSAGE {
        Set tQueue = ""
        Set tPriority = ""
        Set tIndex = ""
        If $IsObject(tPayload) {
            If tPayload.%GetTypeOf("Queue") = "string" Set tQueue = tPayload.%Get("Queue")
            If tPayload.%IsDefined("Priority") Set tPriority = tPayload.%Get("Priority")
            If tPayload.%IsDefined("Index") Set tIndex = tPayload.%Get("Index")
        }
        Quit tNL _ " Set tSC = ##class(Ens.Queue).AbortItem(" _ ..Literal(tQueue) _ ", " _ ..Literal(tPriority) _ ", " _ ..Literal(tIndex) _ ")"
    }
    If pType = ..#TYPEABORTQUEUE {
        Set tName = ..Literal(pId)
        Set tEntries = ..#ABORTMAX
        If $IsObject(tPayload) && (tPayload.%GetTypeOf("Entries") = "number") Set tEntries = tPayload.%Get("Entries")
        Set tText = tNL _ " Set tResult = ##class(%ResultSet).%New(""Ens.Queue:EnumerateItem"")"
        Set tText = tText _ tNL _ " Set tSC = tResult.Execute(" _ tName _ "), tLeft = " _ ..Literal(tEntries)
        Set tText = tText _ tNL _ " While (tLeft > 0) && tResult.Next() { Set tLeft = tLeft - 1, tSC = $System.Status.AppendStatus(tSC, ##class(Ens.Queue).AbortItem(" _ tName _ ", tResult.GetData(1), tResult.GetData(2))) }"
        Quit tText
    }
    If pType = ..#TYPESTOPJOB {
        Set tText = tNL _ " Set tTimeout = ##class(Ens.Director).GetRunningProductionUpdateTimeout()"
        Set tText = tText _ tNL _ " If tTimeout > " _ ..#STOPSECONDS _ " Set tTimeout = " _ ..#STOPSECONDS
        Set tText = tText _ tNL _ " Set tSC = ##class(Ens.Job).Stop(" _ ..Literal(pId) _ ", tTimeout, 1)"
        Quit tText
    }
    Quit tNL _ " Set tSC = ##class(Ens.Job)." _ $Select(pType = ..#TYPEABORTJOB: "AbortOperation", 1: "SuspendOperation") _ "(" _ ..Literal(pId) _ ")"
}

/// <p>The lines <method>Snippet</method> adds for the item write <var>pType</var> of the item the composite
/// id <var>pId</var> names, carrying the add's or the copy's body <var>pBody</var>. A change of class sets the class
/// <var>pQuery</var> names under <parameter>NEWCLASSKEY</parameter> and removes the settings the proposal's stored payload
/// (<var>pContext</var>'s <code>payload.Dropped</code>) lists. The last line drops the production, so a
/// terminal that runs the script does not keep its exclusive lock.</p>
ClassMethod ItemSnippet(pType As %String, pId As %String, pBody As %DynamicAbstractObject, ByRef pQuery, pContext As %DynamicObject = "") As %String [ Private ]
{
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pId)
    Set tProduction = ..Literal($ListGet(tParts, 1))
    Set tName = ..Literal($ListGet(tParts, 2))
    Set tConfigName = ..Literal($ListGet(tParts, 1) _ "||" _ $ListGet(tParts, 2))
    Set tNL = $Char(10)
    If ..IsItemRunWrite(pType) Quit ..ItemRunSnippet(pType, tConfigName)
    Set tText = tNL _ " Set tProduction = ##class(Ens.Config.Production).%OpenId(" _ tProduction _ ", 4)"
    If (pType = ..#TYPEENABLE) || (pType = ..#TYPEDISABLE) {
        Set tText = tText _ tNL _ " Set tSC = ##class(Ens.Director).EnableConfigItem(" _ tConfigName _ ", " _ (pType = ..#TYPEENABLE) _ ", 0)"
        Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = tProduction.SaveToClass(tProduction.FindItemByConfigName(" _ tName _ "))"
    } ElseIf pType = ..#TYPEADD {
        Set tClass = ""
        If $IsObject(pBody) && (pBody.%GetTypeOf("ClassName") = "string") Set tClass = pBody.%Get("ClassName")
        Set tText = tText _ tNL _ " Set tItem = ##class(Ens.Config.Item).%New(" _ ..Literal(tClass) _ ")"
        Set tText = tText _ tNL _ " Set tItem.Name = " _ tName
        Set tEnabled = 0
        If $IsObject(pBody) && (pBody.%GetTypeOf("Enabled") = "boolean") Set tEnabled = ''pBody.%Get("Enabled")
        Set tText = tText _ tNL _ " Set tItem.Enabled = " _ tEnabled
        If $IsObject(pBody) && (pBody.%GetTypeOf("PoolSize") = "number") Set tText = tText _ tNL _ " Set tItem.PoolSize = " _ ..Literal(pBody.%Get("PoolSize"))
        If $IsObject(pBody) && (pBody.%GetTypeOf("Category") = "string") Set tText = tText _ tNL _ " Set tItem.Category = " _ ..Literal(pBody.%Get("Category"))
        If $IsObject(pBody) && (pBody.%GetTypeOf("Comment") = "string") Set tText = tText _ tNL _ " Set tItem.Comment = " _ ..Literal(pBody.%Get("Comment"))
        Set tText = tText _ tNL _ " Do tProduction.Items.Insert(tItem)"
        Set tText = tText _ tNL _ " Set tSC = tProduction.%Save()"
        Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = tProduction.SaveToClass(tItem)"
    } ElseIf pType = ..#TYPECOPY {
        Set tFrom = ""
        If $IsObject(pBody) && (pBody.%GetTypeOf("CopyFrom") = "string") Set tFrom = pBody.%Get("CopyFrom")
        Set tText = tText _ tNL _ " Set tItem = tProduction.FindItemByConfigName(" _ ..Literal(tFrom) _ ").%ConstructClone(1)"
        Set tText = tText _ tNL _ " Set tItem.Name = " _ tName
        Set tText = tText _ tNL _ " Set tItem.Enabled = 0"
        Set tText = tText _ tNL _ " If (tItem.BusinessType() = 2) && (tItem.PoolSize = 0) Set tItem.PoolSize = 1"
        Set tText = tText _ tNL _ " Do tProduction.Items.Insert(tItem)"
        Set tText = tText _ tNL _ " Set tSC = tProduction.%Save()"
        Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = tProduction.SaveToClass(tItem)"
    } ElseIf pType = ..#TYPECHANGECLASS {
        Set tText = tText _ tNL _ " Set tItem = tProduction.FindItemByConfigName(" _ tName _ ")"
        Set tText = tText _ tNL _ " Set tItem.ClassName = " _ ..Literal($Get(pQuery(..#NEWCLASSKEY)))
        Set tDropped = ""
        If $IsObject(pContext) && (pContext.%GetTypeOf("payload") = "object") && (pContext.%Get("payload").%GetTypeOf("Dropped") = "array") {
            Set tIterator = pContext.%Get("payload").%Get("Dropped").%GetIterator()
            While tIterator.%GetNext(.tIndex, .tEntry) {
                If $IsObject(tEntry) Set tDropped = tDropped _ $Select(tDropped = "": "", 1: ", ") _ ..Literal(tEntry.%Get("Target") _ "." _ tEntry.%Get("Name"))
            }
        }
        If tDropped '= "" Set tText = tText _ tNL _ " For tI = tItem.Settings.Count():-1:1 { Set tSetting = tItem.Settings.GetAt(tI) If $ListFind($ListBuild(" _ tDropped _ "), tSetting.Target _ ""."" _ tSetting.Name) Do tItem.Settings.RemoveAt(tI) }"
        Set tText = tText _ tNL _ " Set tSC = tItem.%Save()"
        Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = tProduction.SaveToClass(tItem)"
    } Else {
        Set tText = tText _ tNL _ " Do tProduction.RemoveItem(tProduction.FindItemByConfigName(" _ tName _ "))"
        Set tText = tText _ tNL _ " Set tSC = tProduction.%Save()"
        Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = tProduction.SaveToClass()"
    }
    ; The production was opened with its exclusive lock, which lasts while a reference to it does.
    Set tText = tText _ tNL _ " Kill tItem, tProduction"
    Quit tText
}

/// <p>The lines <method>ItemSnippet</method> adds for the item runtime write <var>pType</var> (Story 20.25) of the item the string
/// literal <var>pConfigName</var> names (<code>Production||Name</code>): <code>TempStopConfigItem</code> with no update, then the
/// production's update timeout capped at <parameter>STOPSECONDS</parameter> and <code>UpdateProduction</code>; after a refused
/// stop's update the flag is cleared again. A restart does the stop and then the start. Each line closes any block it opens, and every
/// condition takes a block, so no command after it on the line is conditional on it.</p>
ClassMethod ItemRunSnippet(pType As %String, pConfigName As %String) As %String [ Private ]
{
    Set tNL = $Char(10)
    Set tText = ""
    If pType '= ..#TYPESTARTITEM {
        Set tText = tText _ tNL _ " Set tSC = ##class(Ens.Director).TempStopConfigItem(" _ pConfigName _ ", 1, 0)"
        Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) { Set tTimeout = ##class(Ens.Director).GetRunningProductionUpdateTimeout() If tTimeout > " _ ..#STOPSECONDS _ " { Set tTimeout = " _ ..#STOPSECONDS _ " } Set tSC = ##class(Ens.Director).UpdateProduction(tTimeout, 0) If $System.Status.IsError(tSC) { Do ##class(Ens.Director).TempStopConfigItem(" _ pConfigName _ ", 0, 0) } }"
    }
    If pType '= ..#TYPESTOPITEM {
        Set tText = tText _ tNL _ " If " _ $Select(pType = ..#TYPESTARTITEM: "1", 1: "$System.Status.IsOK(tSC)") _ " { Set tSC = ##class(Ens.Director).TempStopConfigItem(" _ pConfigName _ ", 0, 0)"
        Set tText = tText _ " If $System.Status.IsOK(tSC) { Set tTimeout = ##class(Ens.Director).GetRunningProductionUpdateTimeout() If tTimeout > " _ ..#STOPSECONDS _ " { Set tTimeout = " _ ..#STOPSECONDS _ " } Set tSC = ##class(Ens.Director).UpdateProduction(tTimeout, 0) } }"
    }
    Quit tText
}

/// <p>The lines <method>Snippet</method> adds for the setting write <var>pType</var> of the setting the composite id
/// <var>pId</var> names, carrying the set's body <var>pBody</var> (Story 20.22): the item opened with the production,
/// the property or the setting stored or removed, the item saved and the production class saved. Names and values are
/// string literals. The last line drops the production, so a terminal that runs the script does not keep its
/// exclusive lock.</p>
ClassMethod SettingSnippet(pType As %String, pId As %String, pBody As %DynamicAbstractObject) As %String [ Private ]
{
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pId)
    Set tProduction = ..Literal($ListGet(tParts, 1))
    Set tItemName = ..Literal($ListGet(tParts, 2))
    Set tTarget = $ListGet(tParts, 3)
    Set tName = ..Literal($ListGet(tParts, 4))
    Set tNL = $Char(10)
    Set tValue = ""
    If $IsObject(pBody) && (pBody.%GetTypeOf("Value") = "string") Set tValue = pBody.%Get("Value")
    Set tText = tNL _ " Set tProduction = ##class(Ens.Config.Production).%OpenId(" _ tProduction _ ", 4)"
    Set tText = tText _ tNL _ " Set tItem = tProduction.FindItemByConfigName(" _ tItemName _ ")"
    If tTarget = ..#TARGETCORE {
        Set tText = tText _ tNL _ " Set $Property(tItem, " _ tName _ ") = " _ ..Literal(tValue)
    } ElseIf pType = ..#TYPESET {
        Set tText = tText _ tNL _ " Set tSetting = tItem.FindSettingByName(" _ tName _ ", " _ ..Literal(tTarget) _ ")"
        Set tText = tText _ tNL _ " If '$IsObject(tSetting) Set tSetting = ##class(Ens.Config.Setting).%New(), tSetting.Target = " _ ..Literal(tTarget) _ ", tSetting.Name = " _ tName _ " Do tItem.Settings.Insert(tSetting)"
        Set tText = tText _ tNL _ " Set tSetting.Value = " _ ..Literal(tValue)
    } Else {
        Set tText = tText _ tNL _ " For tI = 1:1:tItem.Settings.Count() { If (tItem.Settings.GetAt(tI).Name = " _ tName _ ") && (tItem.Settings.GetAt(tI).Target = " _ ..Literal(tTarget) _ ") { Do tItem.Settings.RemoveAt(tI) Quit } }"
    }
    Set tText = tText _ tNL _ " Set tSC = tItem.%Save()"
    Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = tProduction.SaveToClass(tItem)"
    ; The production was opened with its exclusive lock, which lasts while a reference to it does.
    Set tText = tText _ tNL _ " Kill tSetting, tItem, tProduction"
    Quit tText
}

/// <p>Whether <var>pType</var> is one of the lookup writes this port carries (Story 20.5): an entry's add, set or remove, a
/// table's delete, or an import. Each needs WRITE on the namespace's globals database and no routines database. An export reads
/// the table and is not one.</p>
ClassMethod IsLookupWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEADDENTRY) || (pType = ..#TYPESETENTRY) || (pType = ..#TYPEREMOVEENTRY) || (pType = ..#TYPEDELETETABLE) || (pType = ..#TYPEIMPORT)
}

/// <p>Take the vendor's own lock on lookup table <var>pTable</var> in the current namespace, as the classic page's save takes it,
/// waiting at most <parameter>LOCKSECONDS</parameter>; 1 when it is held. Called while the table's namespace is switched.
/// Overridable so a fixture can answer 0; production never overrides it.</p>
ClassMethod LockTable(pTable As %String) As %Boolean
{
    Set tWait = ..#LOCKSECONDS
    Lock +^Ens.LookupTable(pTable):tWait
    Quit $Test
}

/// <p>Release <method>LockTable</method>'s lock. Called while the table's namespace is switched.</p>
ClassMethod UnlockTable(pTable As %String)
{
    Lock -^Ens.LookupTable(pTable)
}

/// <p>Whether the instance can address <code>^Ens.LookupTable</code> by the table <var>pTable</var> and, when it is not empty, the
/// key <var>pKey</var> (Story 20.5). A reference past the instance's limit raises <code>&lt;SUBSCRIPT&gt;</code>, and the limit counts
/// encoded bytes over the global's name and both subscripts, so a table and a key each within its own bound can pass it together,
/// sooner when they hold characters outside ASCII (measured: a 255-character table takes a key of at most 238 characters). The test
/// reads a process-private global whose name is as long as the vendor's, which nothing writes. Pure; it names no other class, so it
/// runs while a namespace is switched.</p>
ClassMethod LookupFits(pTable As %String, pKey As %String = "") As %Boolean
{
    Set tFits = 1
    Try {
        If pKey = "" {
            Set tProbe = $Data(^||Ens.LookupTable(pTable))
        } Else {
            Set tProbe = $Data(^||Ens.LookupTable(pTable, pKey))
        }
    } Catch {
        Set tFits = 0
    }
    Quit tFits
}

/// <p>Whether <code>$System.OBJ</code>'s export names the table <var>pTable</var>'s <code>.LUT</code> document exactly, in the array
/// form <method>ExportTable</method> passes it (Story 20.5): a name holding a character of <parameter>UNADDRESSABLE</parameter>, or
/// beginning with an apostrophe (an exclusion), exports other documents, none, or one with no entry (measured). No export writes such
/// a table, so <method>ImportFile</method> refuses one too. Pure.</p>
ClassMethod LookupAddressable(pTable As %String) As %Boolean
{
    Quit ($Translate(pTable, ..#UNADDRESSABLE) = pTable) && ($Extract(pTable) '= "'")
}

/// <p>The 422 violations of an entry's fields, in <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field, code)</code>
/// with the count in <code>pViolations</code> (Story 20.5): <code>Table</code> and <code>Key</code> are 1 to 255 characters with
/// no control character, the table alone and the two together within what the instance can address (<method>LookupFits</method>;
/// a pair past it is the key's violation, since a key is what either dialog lets a person shorten), and <code>Value</code> is at
/// most 32,000 characters. They are the vendor's own limits (measured), and the vendor would refuse each with an error that names
/// none of them. Pure.</p>
ClassMethod LookupViolations(pTable As %String, pKey As %String, pValue As %String, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tTableShaped = (pTable '= "") && ($Length(pTable) <= ..#TABLEMAX) && ($ZStrip(pTable, "*C") = pTable) && ..LookupFits(pTable)
    Set tKeyShaped = (pKey '= "") && ($Length(pKey) <= ..#KEYMAX) && ($ZStrip(pKey, "*C") = pKey)
    If 'tTableShaped Set pViolations($Increment(pViolations)) = $ListBuild("Table", ##class(OcuPilot.Api.InteropError).#LOOKUPTABLENAME)
    If 'tKeyShaped || (tTableShaped && '..LookupFits(pTable, pKey)) Set pViolations($Increment(pViolations)) = $ListBuild("Key", ##class(OcuPilot.Api.InteropError).#LOOKUPKEY)
    If $Length(pValue) > ..#VALUEMAX Set pViolations($Increment(pViolations)) = $ListBuild("Value", ##class(OcuPilot.Api.InteropError).#LOOKUPVALUE)
    Quit $$$OK
}

/// <p>The decision a lookup write <var>pType</var> is refused with, as the last segment of its code (<code>TAKEN</code>,
/// <code>TABLECASE</code>, <code>SAME</code>) or <code>ABSENT</code> for a target that is not there, else <code>""</code>
/// (Story 20.5): whatever the vendor would answer as a silent success, or get wrong, is refused here by its own name.
/// <var>pExists</var> is whether the table is held under exactly that name, <var>pMatch</var> the spelling it is held under in
/// another letter case (<code>""</code> when none), <var>pKeyExists</var> and <var>pHeld</var> whether the entry is there and what
/// it holds, and <var>pValue</var> the value being written. It names no other class, so it runs while the table's namespace is
/// switched. Pure.</p>
/// <ul>
/// <li>Add: <code>TAKEN</code> when the key is held, <code>TABLECASE</code> when the table is absent but held in another
/// letter case.</li>
/// <li>Set: <code>ABSENT</code> unless the entry is held, then <code>SAME</code> when it holds the value.</li>
/// <li>Remove: <code>ABSENT</code> unless the entry is held. Delete: <code>ABSENT</code> unless the table is held.</li>
/// </ul>
ClassMethod LookupWriteToken(pType As %String, pExists As %Boolean, pMatch As %String, pKeyExists As %Boolean, pHeld As %String, pValue As %String) As %String
{
    If pType = ..#TYPEADDENTRY {
        If pKeyExists Quit "TAKEN"
        If 'pExists && (pMatch '= "") Quit "TABLECASE"
        Quit ""
    }
    If pType = ..#TYPESETENTRY {
        If 'pExists || 'pKeyExists Quit "ABSENT"
        If pHeld = pValue Quit "SAME"
        Quit ""
    }
    If pType = ..#TYPEREMOVEENTRY {
        If 'pExists || 'pKeyExists Quit "ABSENT"
        Quit ""
    }
    If 'pExists Quit "ABSENT"
    Quit ""
}

/// <p>Serve the LookupTables and LookupEntries endpoints (Story 20.5) after <method>Invoke</method>'s gate. A <code>LIST</code>
/// of entries names its table under <parameter>TABLEKEY</parameter>; a table is named under <parameter>IDKEY</parameter> by its
/// name, and an entry by the composite <code>[Table, Key]</code>, each part kept exactly (AD-13). An <parameter>ACTIONKEY</parameter>
/// names the write a single-object read is composed for: <method>ReadLookupTable</method> and <method>ReadLookupEntry</method>
/// then refuse what that write would be refused.</p>
ClassMethod InvokeLookup(pNamespace As %String, pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType = ..#TYPELIST {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            If pEndpoint = ..#ENDPOINTLOOKUPTABLES {
                Set tSC = ..ListLookupTables(pNamespace, +tMaxText, .pResult, .pHttpStatus, .pFault)
                Quit
            }
            Set tTable = $Get(pQuery(..#TABLEKEY))
            If tTable = "" {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONTABLEREQUIRED, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..ListLookupEntries(pNamespace, tTable, +tMaxText, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tId = $Get(pQuery(..#IDKEY))
        Set tAction = $Select(..IsLookupWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && '((..IsLookupWrite(tAction) || (tAction = ..#TYPEEXPORT)) && ..Serves(pEndpoint, tAction)) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#ENDPOINTLOOKUPTABLES {
            If tId = "" {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONTABLEREQUIRED, .pHttpStatus, .pFault)
                Quit
            }
            If pType = ..#TYPEEXPORT {
                Set tSC = ..ExportTable(pNamespace, tId, .pQuery, .pResult, .pHttpStatus, .pFault)
            } ElseIf pType = ..#TYPEIMPORTTABLE {
                Set tSC = ..ReadImportTable(pNamespace, tId, tAction, .pQuery, .pResult, .pHttpStatus, .pFault)
            } ElseIf pType = ..#TYPEIMPORT {
                Set tSC = ..PerformImport(pNamespace, tId, .pQuery, .pResult, .pHttpStatus, .pFault)
            } ElseIf ..IsLookupWrite(pType) {
                Set tSC = ..PerformLookup(pNamespace, pType, tId, "", pBody, .pResult, .pHttpStatus, .pFault)
            } Else {
                Set tSC = ..ReadLookupTable(pNamespace, tId, tAction, $Get(pQuery(..#ROOTKEY)), $Get(pQuery(..#PATHKEY)), .pResult, .pHttpStatus, .pFault)
            }
            Quit
        }
        Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(tId)
        If ($ListLength(tParts) '= 2) || ($List(tParts, 1) = "") || ($List(tParts, 2) = "") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONENTRYID, .pHttpStatus, .pFault)
            Quit
        }
        If ..IsLookupWrite(pType) {
            Set tSC = ..PerformLookup(pNamespace, pType, $List(tParts, 1), $List(tParts, 2), pBody, .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..ReadLookupEntry(pNamespace, $List(tParts, 1), $List(tParts, 2), tAction, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the lookup call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The facts about lookup table <var>pTable</var> and, when <var>pKey</var> is not empty, its entry, read in
/// <var>pNamespace</var> and kept in <var>pFacts</var>: <code>exists</code> (the table is held under exactly that name),
/// <code>match</code> (the spelling it is held under in another letter case, else <code>""</code>, found by comparing every table's
/// name in upper case, so the work is bounded by the table count), <code>keyExists</code> and
/// <code>value</code> (the entry), <code>stamp</code> (the vendor's <code>$ZTIMESTAMP</code> stamp of the table), and, when
/// <var>pCount</var> is true, <code>entries</code> (how many entries it holds). Nothing is written. A fault is
/// <var>pCaught</var>, with the namespace restored.</p>
ClassMethod LookupFacts(pNamespace As %String, pTable As %String, pKey As %String, pCount As %Boolean, Output pFacts, Output pCaught) As %Status [ Private ]
{
    Kill pFacts
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..LookupFactsHere(pTable, pKey, pCount, .pFacts)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p><method>LookupFacts</method>'s reads, in the current namespace, which the caller has already switched. Only vendor
/// classes and globals run. A table or an entry the instance cannot address (<method>LookupFits</method>) is not held.</p>
ClassMethod LookupFactsHere(pTable As %String, pKey As %String, pCount As %Boolean, ByRef pFacts) [ Private ]
{
    Kill pFacts
    Set tFits = ..LookupFits(pTable)
    Set pFacts("exists") = (tFits && ($Data(^Ens.LookupTable(pTable)) > 0))
    Set pFacts("match") = ""
    Set pFacts("keyExists") = 0
    Set pFacts("value") = ""
    Set pFacts("entries") = 0
    Set pFacts("stamp") = ""
    If 'pFacts("exists") {
        If 'tFits Quit
        Set tUpper = $ZConvert(pTable, "U")
        Set tName = ""
        For {
            Set tName = $Order(^Ens.LookupTable(tName))
            If tName = "" Quit
            If $ZConvert(tName, "U") = tUpper {
                Set pFacts("match") = tName
                Quit
            }
        }
        Quit
    }
    Set pFacts("stamp") = ##class(Ens.Util.LookupTable).getTimestamp(pTable)
    If (pKey '= "") && ..LookupFits(pTable, pKey) && ($Data(^Ens.LookupTable(pTable, pKey)) # 2) {
        Set pFacts("keyExists") = 1
        Set pFacts("value") = ^Ens.LookupTable(pTable, pKey)
    }
    If pCount {
        Set tKey = ""
        For {
            Set tKey = $Order(^Ens.LookupTable(pTable, tKey))
            If tKey = "" Quit
            Set pFacts("entries") = pFacts("entries") + 1
        }
    }
}

/// <p>The vendor's table stamp <var>pStamp</var> (<code>$ZTIMESTAMP</code>, UTC) as the instance's local clock time in the form
/// the log readers write it (<method>LocalStamp</method>); <code>""</code> for a table with none. Runs in the install
/// namespace.</p>
ClassMethod LookupModified(pStamp As %String) As %String [ Private ]
{
    If '$Match(pStamp, "^[0-9]+,[0-9]+(\.[0-9]+)?$") Quit ""
    Set tUtc = ""
    Try {
        Set tUtc = $ZDateTime(pStamp, 3, , 3)
    } Catch {
        Set tUtc = ""
    }
    Quit ..LocalStamp(tUtc)
}

/// <p>The table row a list and the table read answer: <code>{Name, Modified}</code>, and, with <var>pNamespace</var> (the table
/// read), <code>Entries</code> and <code>Namespace</code> too. Runs in the install namespace.</p>
ClassMethod LookupTableRow(pName As %String, pStamp As %String, pNamespace As %String = "", pEntries As %Integer = 0) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Name", pName, "string")
    If pNamespace '= "" Do tRow.%Set("Entries", +pEntries, "number")
    Do tRow.%Set("Modified", ..LookupModified(pStamp), "string")
    If pNamespace '= "" Do tRow.%Set("Namespace", pNamespace, "string")
    Quit tRow
}

/// <p>The entry row a list and the entry read answer: <code>{Table, Key, Value, Secret}</code>, and with <var>pNamespace</var>
/// also <code>Namespace</code>. An entry whose key matches the credential pattern
/// (<method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method>) is answered with an empty <code>Value</code> and
/// <code>Secret</code> true (AD-35), so its value never reaches a screen, the context, a read tool or the ledger. Runs in the
/// install namespace.</p>
ClassMethod LookupEntryRow(pTable As %String, pKey As %String, pValue As %String, pNamespace As %String = "") As %DynamicObject [ Private ]
{
    Set tSecret = ''##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(pKey)
    Set tRow = {}
    Do tRow.%Set("Table", pTable, "string")
    Do tRow.%Set("Key", pKey, "string")
    Do tRow.%Set("Value", $Select(tSecret: "", 1: pValue), "string")
    Do tRow.%Set("Secret", tSecret, "boolean")
    If pNamespace '= "" Do tRow.%Set("Namespace", pNamespace, "string")
    Quit tRow
}

/// <p>The namespace's lookup tables, one row per table in the vendor's order, <code>{Name, Modified}</code>, at most
/// <var>pMax</var> when it is above zero (Story 20.5). The vendor's own query lists the names
/// (<code>Ens.Util.LookupTable:Enumerate</code>) and nothing is written.</p>
ClassMethod ListLookupTables(pNamespace As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tCaught = ""
    Set tStatusSC = $$$OK
    Kill tFound
    Set tFound = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tResultSet = ##class(%ResultSet).%New("Ens.Util.LookupTable:Enumerate")
        Set tStatusSC = tResultSet.Execute()
        If $$$ISOK(tStatusSC) {
            While tResultSet.Next() {
                If (pMax > 0) && (tFound >= pMax) Quit
                Set tName = tResultSet.GetData(1)
                Set tFound = tFound + 1
                Set tFound(tFound) = $ListBuild(tName, ##class(Ens.Util.LookupTable).getTimestamp(tName))
            }
            Do tResultSet.Close()
        }
        Set tResultSet = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the lookup table list failed", .pHttpStatus, .pFault)
    If $$$ISERR(tStatusSC) Quit ..Statused(tStatusSC, "the lookup table list failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..LookupTableRow($List(tFound(tI), 1), $List(tFound(tI), 2)))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The entries of table <var>pTable</var>, one row per entry in the vendor's subscript order, <code>{Table, Key, Value,
/// Secret}</code>, at most <var>pMax</var> when it is above zero (Story 20.5). A table that is not held under exactly that
/// name is 404 <code>PORT.NOTFOUND</code>, unlogged.</p>
ClassMethod ListLookupEntries(pNamespace As %String, pTable As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tCaught = ""
    Set tExists = 0
    Kill tFound
    Set tFound = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tExists = (..LookupFits(pTable) && ($Data(^Ens.LookupTable(pTable)) > 0))
        If tExists {
            Set tKey = ""
            For {
                Set tKey = $Order(^Ens.LookupTable(pTable, tKey))
                If tKey = "" Quit
                If (pMax > 0) && (tFound >= pMax) Quit
                Set tFound = tFound + 1
                Set tFound(tFound) = $ListBuild(tKey, $Get(^Ens.LookupTable(pTable, tKey)))
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the lookup entry list failed", .pHttpStatus, .pFault)
    If 'tExists Quit ..Absent(.pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..LookupEntryRow(pTable, $List(tFound(tI), 1), $List(tFound(tI), 2)))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>One lookup table, fresh (Story 20.5): <code>{Name, Entries, Modified, Namespace}</code>. A table that is not held under
/// exactly that name is 404 <code>PORT.NOTFOUND</code>, unlogged. With a lookup write as <var>pAction</var> (the table delete) a
/// namespace under source control is <code>INTEROP.LOOKUP.SOURCECONTROL</code> first. An export names a file by <var>pRoot</var> and
/// <var>pPath</var>, which the row always carries (empty when none), so the export's card shows the file and its fingerprint covers it.</p>
ClassMethod ReadLookupTable(pNamespace As %String, pName As %String, pAction As %String, pRoot As %String, pPath As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    If ..IsLookupWrite(pAction) && ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#LOOKUPSOURCECONTROL, .pHttpStatus, .pFault)
    Set tSC = ..LookupFacts(pNamespace, pName, "", 1, .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the lookup table read failed", .pHttpStatus, .pFault)
    If 'tFacts("exists") Quit ..Absent(.pHttpStatus, .pFault)
    Set pRow = ..LookupTableRow(pName, tFacts("stamp"), pNamespace, tFacts("entries"))
    Do pRow.%Set(..#ROOTKEY, pRoot, "string")
    Do pRow.%Set(..#PATHKEY, pPath, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>One lookup entry, fresh (Story 20.5): <code>{Table, Key, Value, Secret, Namespace}</code>, with no count. An entry the
/// table does not hold, or a table not held under exactly that name, is 404 <code>PORT.NOTFOUND</code>, unlogged. With
/// <var>pAction</var> it refuses what that write would be refused, in this order: <code>SOURCECONTROL</code> for any write; for
/// an add (AD-54, which inverts the read) <code>TAKEN</code> when the key is held, <code>TABLECASE</code> when the table is
/// absent but held in another letter case, <code>SECRET</code> for a key that matches the credential pattern, and otherwise
/// the 404 a create expects; for a set <code>SECRET</code> first.</p>
ClassMethod ReadLookupEntry(pNamespace As %String, pTable As %String, pKey As %String, pAction As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    If (pAction '= "") && ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#LOOKUPSOURCECONTROL, .pHttpStatus, .pFault)
    Set tSecret = ''##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(pKey)
    If (pAction = ..#TYPESETENTRY) && tSecret Quit ..Conflict(##class(OcuPilot.Api.InteropError).#LOOKUPSECRET, .pHttpStatus, .pFault)
    Set tSC = ..LookupFacts(pNamespace, pTable, pKey, 0, .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the lookup entry read failed", .pHttpStatus, .pFault)
    If pAction = ..#TYPEADDENTRY {
        Set tToken = ..LookupWriteToken(pAction, tFacts("exists"), tFacts("match"), tFacts("keyExists"), tFacts("value"), "")
        If tToken '= "" Quit ..Conflict(..#LOOKUPCODEPREFIX _ tToken, .pHttpStatus, .pFault)
        If tSecret Quit ..Conflict(##class(OcuPilot.Api.InteropError).#LOOKUPSECRET, .pHttpStatus, .pFault)
        Quit ..Absent(.pHttpStatus, .pFault)
    }
    If 'tFacts("exists") || 'tFacts("keyExists") Quit ..Absent(.pHttpStatus, .pFault)
    Set pRow = ..LookupEntryRow(pTable, pKey, tFacts("value"), pNamespace)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Run lookup write <var>pType</var> on the table <var>pTable</var> (and the entry <var>pKey</var>) in <var>pNamespace</var>
/// and answer what it leaves (Story 20.5). The sequence:</p>
/// <ol>
/// <li>A namespace under source control is <code>INTEROP.LOOKUP.SOURCECONTROL</code>, before anything is read.</li>
/// <li>An add's or set's fields are judged by <method>LookupViolations</method> (422), then a key that matches the credential
/// pattern is <code>INTEROP.LOOKUP.SECRET</code>; a remove's entry or a delete's table the instance cannot address
/// (<method>LookupFits</method>) is 404.</li>
/// <li>The vendor's own table lock is taken, as the classic page's save takes it; a lock not got in
/// <parameter>LOCKSECONDS</parameter> is <code>INTEROP.LOOKUP.LOCKED</code>, with nothing written.</li>
/// <li>Under the lock the target is read again and judged by <method>LookupWriteToken</method>, so a state that moved since the
/// review is refused by its own code with no vendor call; then <code>%UpdateValue</code>, <code>%RemoveValue</code> or
/// <code>%ClearTable</code> runs.</li>
/// <li>The lock is released and the namespace restored, then OcuPilot's own audit row is recorded
/// (<method>AuditRuntime</method>), because the vendor records none. It never carries a value.</li>
/// </ol>
/// <p>The answer is the entry's row read again; after a remove <code>{Table, Key, Namespace}</code>, because a table's last entry
/// takes the table with it; after a delete <code>{Name, Namespace, Entries}</code> with <code>Entries</code> 0.</p>
ClassMethod PerformLookup(pNamespace As %String, pType As %String, pTable As %String, pKey As %String, pBody As %DynamicAbstractObject, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#LOOKUPSOURCECONTROL, .pHttpStatus, .pFault)
    Set tValue = ""
    If (pType = ..#TYPEADDENTRY) || (pType = ..#TYPESETENTRY) {
        Set tViolations = 0
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Set pBody = {}
        Set tValueType = pBody.%GetTypeOf("Value")
        If tValueType = "string" {
            Set tValue = pBody.%Get("Value")
        } ElseIf (tValueType '= "unassigned") || (pType = ..#TYPESETENTRY) {
            Set tViolations($Increment(tViolations)) = $ListBuild("Value", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
        Set tSC = ..LookupViolations(pTable, pKey, tValue, .tFieldViolations)
        If $$$ISERR(tSC) Quit tSC
        For tI = 1:1:tFieldViolations {
            Set tViolations($Increment(tViolations)) = tFieldViolations(tI)
        }
        If tViolations Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
        If ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(pKey) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#LOOKUPSECRET, .pHttpStatus, .pFault)
    }
    ; A remove's entry or a delete's table the instance cannot address is not held: the lock would raise <SUBSCRIPT>.
    If '..LookupFits(pTable, pKey) Quit ..Absent(.pHttpStatus, .pFault)
    Set tToken = ""
    Set tCaught = ""
    Set tVendorSC = $$$OK
    Set tEntries = 0
    Set tLocked = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tLocked = ..LockTable(pTable)
        If 'tLocked {
            Set tToken = "LOCKED"
        } Else {
            Do ..LookupFactsHere(pTable, pKey, (pType = ..#TYPEDELETETABLE), .tFacts)
            Set tEntries = tFacts("entries")
            Set tToken = ..LookupWriteToken(pType, tFacts("exists"), tFacts("match"), tFacts("keyExists"), tFacts("value"), tValue)
            If tToken = "" {
                If pType = ..#TYPEADDENTRY {
                    Set tVendorSC = ##class(Ens.Util.LookupTable).%UpdateValue(pTable, pKey, tValue, 1)
                } ElseIf pType = ..#TYPESETENTRY {
                    Set tVendorSC = ##class(Ens.Util.LookupTable).%UpdateValue(pTable, pKey, tValue, 0)
                } ElseIf pType = ..#TYPEREMOVEENTRY {
                    Set tVendorSC = ##class(Ens.Util.LookupTable).%RemoveValue(pTable, pKey)
                } Else {
                    Do ##class(Ens.Util.LookupTable).%ClearTable(pTable)
                }
            }
            Do ..UnlockTable(pTable)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
        If tLocked {
            Try {
                Set $NAMESPACE = pNamespace
                Do ..UnlockTable(pTable)
            } Catch {
            }
            Set $NAMESPACE = tOrigNS
        }
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the lookup write failed", .pHttpStatus, .pFault)
    If tToken = "ABSENT" Quit ..Absent(.pHttpStatus, .pFault)
    If tToken '= "" Quit ..Conflict(..#LOOKUPCODEPREFIX _ tToken, .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the lookup write failed", .pHttpStatus, .pFault)
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("table", pTable, "string")
    If pType = ..#TYPEDELETETABLE {
        Do tEffects.%Set("entries", tEntries, "number")
        Do ..AuditRuntime(..#VERBDELETE, ..#ENTITYLOOKUPTABLE, pTable, tEffects)
        Set pResult = {}
        Do pResult.%Set("Name", pTable, "string")
        Do pResult.%Set("Namespace", pNamespace, "string")
        Do pResult.%Set("Entries", 0, "number")
        Set pHttpStatus = 200
        Quit $$$OK
    }
    ; Named entry, not key: the audit writer redacts a member whose name matches the credential pattern.
    Do tEffects.%Set("entry", pKey, "string")
    Do ..AuditRuntime($Case(pType, ..#TYPEADDENTRY: ..#VERBADD, ..#TYPESETENTRY: ..#VERBSET, : ..#VERBREMOVE), ..#ENTITYLOOKUPENTRY, ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pTable, pKey)), tEffects)
    If pType = ..#TYPEREMOVEENTRY {
        Set pResult = {}
        Do pResult.%Set("Table", pTable, "string")
        Do pResult.%Set("Key", pKey, "string")
        Do pResult.%Set("Namespace", pNamespace, "string")
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Set tSC = ..LookupFacts(pNamespace, pTable, pKey, 0, .tAfter, .tAfterCaught)
    Set pResult = ..LookupEntryRow(pTable, pKey, $Select($IsObject(tAfterCaught): tValue, 1: tAfter("value")), pNamespace)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The text of the file an import names in <var>pQuery</var>, in <var>pText</var>, with <var>pLabel</var> the name it is known by
/// (Story 20.5): the server file <parameter>ROOTKEY</parameter> and <parameter>PATHKEY</parameter> name, resolved through
/// <class>OcuPilot.Port.PathPort</class> as a <code>source</code> and read as UTF-8 text
/// (<method>OcuPilot.Port.AtelierPort.ReadText</method>), or the local file <parameter>FILENAMEKEY</parameter> and
/// <parameter>CONTENTKEY</parameter> send. Refused before any vendor call: 400 <code>PORT.VALIDATION</code> when both files or neither
/// is named, or a local file's name is longer than 255 characters or holds <code>/</code>, <code>\</code> or a control character; the
/// resolve's own refusal on its field; and 409 <code>INTEROP.LOOKUP.TOOLARGE</code> for text longer than
/// <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter>.</p>
ClassMethod ImportText(ByRef pQuery, Output pText As %String, Output pLabel As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pText = ""
    Set pLabel = ""
    Set tRoot = $Get(pQuery(..#ROOTKEY))
    Set tPath = $Get(pQuery(..#PATHKEY))
    Set tFileName = $Get(pQuery(..#FILENAMEKEY))
    Set tContent = $Get(pQuery(..#CONTENTKEY))
    Set tServer = (tRoot '= "") || (tPath '= "")
    Set tLocal = (tFileName '= "") || (tContent '= "")
    If tServer = tLocal Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONIMPORTSOURCE, .pHttpStatus, .pFault)
    Set tMax = ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS
    If tLocal {
        If (tFileName = "") || ($Length(tFileName) > ##class(OcuPilot.Port.AtelierPort).#MAXFILENAME) || (tFileName [ "/") || (tFileName [ "\") || ($ZStrip(tFileName, "*C") '= tFileName) {
            Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONIMPORTFILENAME, .pHttpStatus, .pFault)
        }
        If $Length(tContent) > tMax Quit ..Conflict(##class(OcuPilot.Api.InteropError).#LOOKUPTOOLARGE, .pHttpStatus, .pFault)
        Set pLabel = tFileName
        Set pText = tContent
        Quit $$$OK
    }
    Set tPathPort = ..PathPortClass()
    Set tSC = $ClassMethod(tPathPort, "Resolve", tRoot, tPath, $Parameter(tPathPort, "KINDSOURCE"), ..#ROOTKEY, ..#PATHKEY, .tResolved, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pLabel = tPath
    Set tSC = ##class(OcuPilot.Port.AtelierPort).ReadText(tResolved, .pText, .tTooLarge)
    If $$$ISERR(tSC) Quit ..Fail("the import's file could not be read", tSC, .pHttpStatus, .pFault)
    If tTooLarge {
        Set pText = ""
        Quit ..Conflict(##class(OcuPilot.Api.InteropError).#LOOKUPTOOLARGE, .pHttpStatus, .pFault)
    }
    Quit $$$OK
}

/// <p>What <var>pText</var> is as an import file (Story 20.5): <var>pTable</var> the one lookup table its one
/// <code>.LUT</code> document holds, <code>""</code> when the text is anything else; <var>pFileEntries</var> how many entries that
/// document carries; <var>pDigest</var> its SHA-256 as lower-case hex. The vendor lists the file's documents without loading
/// them (<code>$System.OBJ.LoadStream</code> with list-only), so a file that also holds a class or a routine, one that holds two tables,
/// and the legacy form that holds no document (which the lister rejects) are each no table. A fault is <var>pCaught</var>, with
/// the namespace restored.</p>
ClassMethod ImportShape(pNamespace As %String, pText As %String, Output pTable As %String, Output pFileEntries As %Integer, Output pDigest As %String, Output pCaught) As %Status [ Private ]
{
    Set pTable = ""
    Set pFileEntries = 0
    Set pCaught = ""
    Set pDigest = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tBytes = ##class(%Stream.GlobalBinary).%New()
        Set tLength = $Length(pText)
        For tAt = 1:30000:tLength {
            Do tBytes.Write($ZConvert($Extract(pText, tAt, tAt + 29999), "O", "UTF8"))
        }
        Do tBytes.Rewind()
        Set tHash = $System.Encryption.SHAHashStream(256, tBytes, .tHashSC)
        If $$$ISERR(tHashSC) Quit
        Set pDigest = $ZConvert(##class(%xsd.hexBinary).LogicalToXSD(tHash), "L")
        Set tStream = ##class(%Stream.GlobalCharacter).%New()
        Do tStream.Write(pText)
        Do tStream.Rewind()
        Set $NAMESPACE = pNamespace
        Kill tLoaded
        Set tListSC = $System.OBJ.LoadStream(tStream, "-d", .tErrorLog, .tLoaded, 1)
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tListSC) Quit
        Set tItem = $Order(tLoaded(""))
        If (tItem = "") || ($Order(tLoaded(tItem)) '= "") Quit
        Set tSuffix = ..#LUTEXTENSION
        Set tStem = $Length(tItem) - $Length(tSuffix)
        If (tStem < 1) || ($Extract(tItem, tStem + 1, $Length(tItem)) '= tSuffix) Quit
        Set tTable = $Extract(tItem, 1, tStem)
        Do tBytes.Rewind()
        Set tCount = 0
        Set tSC = ##class(%XML.TextReader).ParseStream(tBytes, .tReader)
        If $$$ISERR(tSC) Quit
        While tReader.Read() {
            If (tReader.NodeType = "element") && (tReader.Name = "entry") Set tCount = tCount + 1
        }
        If tCount < 1 Quit
        Set pTable = tTable
        Set pFileEntries = tCount
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
        Set pTable = ""
    }
    Quit $$$OK
}

/// <p>The import file a query names, examined (Story 20.5): its text and label (<method>ImportText</method>), then its shape
/// (<method>ImportShape</method>). <var>pId</var>, unless it is <parameter>IMPORTID</parameter>, names the table the file must hold.
/// 409 <code>INTEROP.LOOKUP.IMPORTSHAPE</code> when the file is not exactly one lookup table with at least one entry, holds another
/// table than <var>pId</var> names, or holds a table whose name the export cannot name (<method>LookupAddressable</method>) or the
/// instance cannot address (<method>LookupFits</method>), which no export writes.</p>
ClassMethod ImportFile(pNamespace As %String, pId As %String, ByRef pQuery, Output pText As %String, Output pTable As %String, Output pFileEntries As %Integer, Output pDigest As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pTable = ""
    Set pFileEntries = 0
    Set pDigest = ""
    Set tSC = ..ImportText(.pQuery, .pText, .tLabel, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ImportShape(pNamespace, pText, .pTable, .pFileEntries, .pDigest, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the import file could not be examined", .pHttpStatus, .pFault)
    If (pTable = "") || '..LookupAddressable(pTable) || '..LookupFits(pTable) || ((pId '= ..#IMPORTID) && (pId '= pTable)) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#LOOKUPIMPORTSHAPE, .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>The import row (Story 20.5): <code>{Table, FileEntries, Digest, Present, Entries, Modified, Namespace, root, path,
/// fileName, content}</code> for the file <var>pQuery</var> names and the table it holds as it stands, with <code>root</code>,
/// <code>path</code> and <code>fileName</code> as the query carried them and <code>content</code> always empty: the row names the
/// property a local file's text is set on, and never holds the text. With <var>pAction</var> a namespace
/// under source control is <code>INTEROP.LOOKUP.SOURCECONTROL</code> first, and a file's table that is absent under exactly that
/// name but held in another letter case is <code>INTEROP.LOOKUP.TABLECASE</code>, since the import would create a second table.</p>
ClassMethod ReadImportTable(pNamespace As %String, pId As %String, pAction As %String, ByRef pQuery, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    If (pAction '= "") && ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#LOOKUPSOURCECONTROL, .pHttpStatus, .pFault)
    Set tSC = ..ImportFile(pNamespace, pId, .pQuery, .tText, .tTable, .tFileEntries, .tDigest, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..LookupFacts(pNamespace, tTable, "", 1, .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the lookup table read failed", .pHttpStatus, .pFault)
    If (pAction '= "") && 'tFacts("exists") && (tFacts("match") '= "") Quit ..Conflict(##class(OcuPilot.Api.InteropError).#LOOKUPTABLECASE, .pHttpStatus, .pFault)
    Set pRow = {}
    Do pRow.%Set("Table", tTable, "string")
    Do pRow.%Set("FileEntries", tFileEntries, "number")
    Do pRow.%Set("Digest", tDigest, "string")
    Do pRow.%Set("Present", tFacts("exists"), "boolean")
    Do pRow.%Set("Entries", +tFacts("entries"), "number")
    Do pRow.%Set("Modified", ..LookupModified(tFacts("stamp")), "string")
    Do pRow.%Set("Namespace", pNamespace, "string")
    Do pRow.%Set(..#ROOTKEY, $Get(pQuery(..#ROOTKEY)), "string")
    Do pRow.%Set(..#PATHKEY, $Get(pQuery(..#PATHKEY)), "string")
    Do pRow.%Set(..#FILENAMEKEY, $Get(pQuery(..#FILENAMEKEY)), "string")
    Do pRow.%Set(..#CONTENTKEY, "", "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Replace, or create, the table the import file holds with the file's entries (Story 20.5). The sequence:</p>
/// <ol>
/// <li>A namespace under source control is <code>INTEROP.LOOKUP.SOURCECONTROL</code>, before anything is read.</li>
/// <li>The file is examined (<method>ImportFile</method>) and the table it holds read as it stands; unless the file's digest, the
/// table's entry count and its stamp are the reviewed <parameter>DIGESTKEY</parameter>, <parameter>ENTRIESKEY</parameter> and
/// <parameter>MODIFIEDKEY</parameter> of the query, the write is <code>INTEROP.LOOKUP.IMPORTCHANGED</code>, with nothing loaded.</li>
/// <li>The vendor's table lock is taken (<code>LOCKED</code> past <parameter>LOCKSECONDS</parameter>); under it a table absent
/// under exactly that name but held in another letter case is <code>INTEROP.LOOKUP.TABLECASE</code>, the table's entry count and
/// stamp are checked again, and the file's one <code>.LUT</code> document is loaded by name
/// (<code>$System.OBJ.LoadStream</code> with a selected array), which replaces the table: a key the file lacks is removed. A load
/// that answers OK without loading that document is <code>INTEROP.LOOKUP.IMPORTSHAPE</code>.</li>
/// <li>OcuPilot's own audit row is recorded after the lock is released, with counts and never a value.</li>
/// </ol>
/// <p>The answer is the table read again, <code>{Name, Entries, Modified, Namespace}</code>.</p>
ClassMethod PerformImport(pNamespace As %String, pId As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#LOOKUPSOURCECONTROL, .pHttpStatus, .pFault)
    Set tSC = ..ImportFile(pNamespace, pId, .pQuery, .tText, .tTable, .tFileEntries, .tDigest, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..LookupFacts(pNamespace, tTable, "", 1, .tPre, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the lookup table read failed", .pHttpStatus, .pFault)
    If '$Data(pQuery(..#DIGESTKEY)) || '$Data(pQuery(..#ENTRIESKEY)) || '$Data(pQuery(..#MODIFIEDKEY)) || (pQuery(..#DIGESTKEY) '= tDigest) || (pQuery(..#ENTRIESKEY) '= +tPre("entries")) || (pQuery(..#MODIFIEDKEY) '= ..LookupModified(tPre("stamp"))) {
        Quit ..Conflict(##class(OcuPilot.Api.InteropError).#LOOKUPIMPORTCHANGED, .pHttpStatus, .pFault)
    }
    Set tToken = ""
    Set tCaught = ""
    Set tVendorSC = $$$OK
    Set tLocked = 0
    Set tAfterEntries = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tStream = ##class(%Stream.GlobalCharacter).%New()
        Do tStream.Write(tText)
        Do tStream.Rewind()
        Set $NAMESPACE = pNamespace
        Set tLocked = ..LockTable(tTable)
        If 'tLocked {
            Set tToken = "LOCKED"
        } Else {
            Do ..LookupFactsHere(tTable, "", 1, .tNow)
            If 'tNow("exists") && (tNow("match") '= "") {
                Set tToken = "TABLECASE"
            } ElseIf (tNow("stamp") '= tPre("stamp")) || (tNow("entries") '= tPre("entries")) {
                Set tToken = "IMPORTCHANGED"
            } Else {
                Kill tLoaded, tSelected
                Set tSelected(tTable _ ..#LUTEXTENSION) = ""
                Set tVendorSC = $System.OBJ.LoadStream(tStream, "-d", .tErrorLog, .tLoaded, 0, .tSelected)
                If $$$ISOK(tVendorSC) && '$Data(tLoaded(tTable _ ..#LUTEXTENSION)) Set tToken = "IMPORTSHAPE"
                Do ..LookupFactsHere(tTable, "", 1, .tAfter)
                Set tAfterEntries = tAfter("entries")
            }
            Do ..UnlockTable(tTable)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
        If tLocked {
            Try {
                Set $NAMESPACE = pNamespace
                Do ..UnlockTable(tTable)
            } Catch {
            }
            Set $NAMESPACE = tOrigNS
        }
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the lookup import failed", .pHttpStatus, .pFault)
    If tToken '= "" Quit ..Conflict(..#LOOKUPCODEPREFIX _ tToken, .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the lookup import failed", .pHttpStatus, .pFault)
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("table", tTable, "string")
    Do tEffects.%Set("entries", tAfterEntries, "number")
    Do tEffects.%Set("fileEntries", tFileEntries, "number")
    Do ..AuditRuntime(..#VERBIMPORT, ..#ENTITYLOOKUPTABLE, tTable, tEffects)
    Set tSC = ..LookupFacts(pNamespace, tTable, "", 1, .tPost, .tPostCaught)
    Set pResult = ..LookupTableRow(tTable, $Select($IsObject(tPostCaught): "", 1: tPost("stamp")), pNamespace, $Select($IsObject(tPostCaught): tAfterEntries, 1: tPost("entries")))
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The export's file for <var>pRoot</var> and <var>pPath</var>, resolved through <method>PathPortClass</method> as a
/// <code>file</code> with <parameter>EXPORTOVERWRITES</parameter>, each refusal on its field, then
/// <code>EXPLORER.EXPORT.DIRECTORY</code> when the resolved name's directory does not exist; a directory is never created. On success
/// <var>pResolved</var> is the path.</p>
ClassMethod ExportFile(pRoot As %String, pPath As %String, Output pResolved As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResolved = ""
    Set tPathPort = ..PathPortClass()
    Set tSC = $ClassMethod(tPathPort, "Resolve", pRoot, pPath, $Parameter(tPathPort, "KINDFILE"), ..#ROOTKEY, ..#PATHKEY, .pResolved, .pHttpStatus, .pFault, ..#EXPORTOVERWRITES)
    If $$$ISERR(tSC) {
        Set pResolved = ""
        Quit tSC
    }
    If '##class(%File).DirectoryExists(##class(%File).GetDirectory(pResolved)) {
        Set pResolved = ""
        Quit ..ConflictFor(##class(OcuPilot.Api.AtelierError).#EXPORTDIRECTORY, .pHttpStatus, .pFault)
    }
    Quit $$$OK
}

/// <p>The export's file for <var>pRoot</var> and <var>pPath</var>, resolved and checked exactly as <method>ExportTable</method> checks
/// it before its vendor call, for a mint that must refuse what the write would (Story 20.5): the endpoint's pairs, then
/// <method>ExportFile</method>. Nothing is written.</p>
ClassMethod CheckExport(pRoot As %String, pPath As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tFailedPair = ""
        If '$ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(..#ENDPOINTLOOKUPTABLES, ..#TYPEEXPORT), .tFailedPair) {
            Set tSC = ..Deny(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..ExportFile(pRoot, pPath, .tResolved, .pHttpStatus, .pFault)
    } Catch ex {
        Set tSC = ..Fail("the export's file could not be checked", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Export table <var>pTable</var>'s <code>.LUT</code> document, the vendor's own (Story 20.5): to the server file
/// <parameter>ROOTKEY</parameter> and <parameter>PATHKEY</parameter> name, resolved and checked by <method>ExportFile</method> before
/// the call (<code>$System.OBJ.Export</code>), the answer <code>{Name, Namespace, root, path}</code>; or, naming neither, as lines for the
/// browser (<code>$System.OBJ.ExportToStream</code>), the answer <code>{Name, Namespace, lines}</code>, 409
/// <code>INTEROP.LOOKUP.TOOLARGE</code> past <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter> characters. A table that is
/// not held under exactly that name is 404, and one whose name the vendor's export cannot address exactly
/// (<method>LookupAddressable</method>) is 409 <code>INTEROP.LOOKUP.EXPORTNAME</code>, before the file is resolved. The document is
/// passed in the array form, so a comma in the name is not a separator. It writes nothing but the file, and records OcuPilot's own
/// audit row.</p>
ClassMethod ExportTable(pNamespace As %String, pTable As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tRoot = $Get(pQuery(..#ROOTKEY))
    Set tPath = $Get(pQuery(..#PATHKEY))
    Set tToFile = (tRoot '= "") || (tPath '= "")
    Set tSC = ..LookupFacts(pNamespace, pTable, "", 1, .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the lookup table read failed", .pHttpStatus, .pFault)
    If 'tFacts("exists") Quit ..Absent(.pHttpStatus, .pFault)
    If '..LookupAddressable(pTable) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#LOOKUPEXPORTNAME, .pHttpStatus, .pFault)
    Set tResolved = ""
    If tToFile {
        Set tSC = ..ExportFile(tRoot, tPath, .tResolved, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
    }
    Kill tItems
    Set tItems(pTable _ ..#LUTEXTENSION) = ""
    Set tCaught = ""
    Set tVendorSC = $$$OK
    Set tText = ""
    Set tTooLarge = 0
    Set tMax = ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If tToFile {
            Set tVendorSC = $System.OBJ.Export(.tItems, tResolved, "-d")
        } Else {
            Set tStream = ##class(%Stream.GlobalCharacter).%New()
            Set tVendorSC = $System.OBJ.ExportToStream(.tItems, .tStream, "-d")
            If $$$ISOK(tVendorSC) {
                If tStream.Size > tMax {
                    Set tTooLarge = 1
                } Else {
                    Do tStream.Rewind()
                    Set tText = tStream.Read(tMax)
                }
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the lookup export failed", .pHttpStatus, .pFault)
    If tTooLarge Quit ..Conflict(##class(OcuPilot.Api.InteropError).#LOOKUPTOOLARGE, .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the lookup export failed", .pHttpStatus, .pFault)
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("table", pTable, "string")
    Do tEffects.%Set("entries", +tFacts("entries"), "number")
    Do tEffects.%Set("toFile", ''tToFile, "boolean")
    Do ..AuditRuntime(..#VERBEXPORT, ..#ENTITYLOOKUPTABLE, pTable, tEffects)
    Set pResult = {}
    Do pResult.%Set("Name", pTable, "string")
    Do pResult.%Set("Namespace", pNamespace, "string")
    If tToFile {
        Do pResult.%Set(..#ROOTKEY, tRoot, "string")
        Do pResult.%Set(..#PATHKEY, tPath, "string")
    } Else {
        Set tLines = []
        Set tLength = $Length(tText, $Char(10))
        For tI = 1:1:tLength {
            Set tLine = $Piece(tText, $Char(10), tI)
            If (tI = tLength) && (tLine = "") Quit
            Do tLines.%Push(tLine, "string")
        }
        Do pResult.%Set("lines", tLines)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The lines <method>Snippet</method> adds for an import or an export of the table <var>pTable</var> (Story 20.5): the vendor's own
/// call on the table's one <code>.LUT</code> document, named in the array form the port passes, in the lock the import takes. A
/// server file is named by its allowed directory and relative name in a comment, since the directory is resolved when the write
/// runs; a local file's text is never in a script, so its import loads a stream the comment says it holds.</p>
ClassMethod TransferSnippet(pType As %String, pTable As %String, ByRef pQuery) As %String [ Private ]
{
    Set tNL = $Char(10)
    Set tItems = tNL _ " Set tItems(" _ ..Literal(pTable _ ..#LUTEXTENSION) _ ") = """""
    Set tPath = $Get(pQuery(..#PATHKEY))
    Set tFile = ..Literal(tPath)
    Set tSource = tNL _ " ; The server file is the allowed directory " _ $Translate($Get(pQuery(..#ROOTKEY)), $Char(10) _ $Char(13), "  ") _ " and the name " _ $Translate(tPath, $Char(10) _ $Char(13), "  ")
    If pType = ..#TYPEEXPORT {
        If tPath = "" Quit tItems _ tNL _ " Set tStream = ##class(%Stream.GlobalCharacter).%New()" _ tNL _ " Set tSC = $System.OBJ.ExportToStream(.tItems, .tStream, ""-d"")"
        Quit tSource _ tItems _ tNL _ " Set tSC = $System.OBJ.Export(.tItems, " _ tFile _ ", ""-d"")"
    }
    Set tLoad = "$System.OBJ.Load(" _ tFile _ ", ""-d"", .tErrorLog, .tLoaded, 0, .tItems)"
    If tPath = "" {
        Set tSource = tNL _ " ; tStream holds the text of the file this browser sent, which no script carries"
        Set tLoad = "$System.OBJ.LoadStream(tStream, ""-d"", .tErrorLog, .tLoaded, 0, .tItems)"
    }
    Quit tSource _ tItems _ tNL _ " Lock +^Ens.LookupTable(" _ ..Literal(pTable) _ "):" _ ..#LOCKSECONDS _ tNL _ " If $Test { Set tSC = " _ tLoad _ " } Else { Set tSC = $System.Status.Error(5001, ""the lookup table lock is held"") }" _ tNL _ " Lock -^Ens.LookupTable(" _ ..Literal(pTable) _ ")"
}

/// <p>The namespace's business partners, one row per partner, at most <var>pMax</var> when it is above zero (Story 20.5):
/// <code>{Name, Description}</code> and, for each of the two contacts, its name, title, email, phone, mobile and notes
/// (<code>PrimaryContact</code>, <code>PrimaryTitle</code>, <code>PrimaryEmail</code>, <code>PrimaryPhone</code>,
/// <code>PrimaryMobile</code>, <code>PrimaryNotes</code> and the same six after <code>Alternative</code>). The vendor's own query
/// lists the partners (<code>Ens.Config.BusinessPartner:List</code>) and each surviving row is opened for its contacts. Nothing
/// is written.</p>
ClassMethod ListPartners(pNamespace As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tCaught = ""
    Set tStatusSC = $$$OK
    Kill tFound
    Set tFound = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tResultSet = ##class(%ResultSet).%New("Ens.Config.BusinessPartner:List")
        Set tStatusSC = tResultSet.Execute()
        If $$$ISOK(tStatusSC) {
            While tResultSet.Next() {
                If (pMax > 0) && (tFound >= pMax) Quit
                Set tName = tResultSet.GetData(1)
                Set tLine = $ListBuild(tName, tResultSet.GetData(2))
                Set tPartner = ##class(Ens.Config.BusinessPartner).%OpenId(tName)
                Set tLine = tLine _ ..PartnerContacts(tPartner)
                Set tPartner = ""
                Set tFound = tFound + 1
                Set tFound(tFound) = tLine
            }
            Do tResultSet.Close()
        }
        Set tResultSet = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the business partner list failed", .pHttpStatus, .pFault)
    If $$$ISERR(tStatusSC) Quit ..Statused(tStatusSC, "the business partner list failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..PartnerRow(tFound(tI)))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Whether the instance can address <code>^Ens.Config.BusinessPartnerD</code> by the name <var>pName</var> (Story 20.26): a
/// name whose encoded form is past the instance's subscript limit raises <code>&lt;SUBSCRIPT&gt;</code> in the vendor's own
/// calls, so no partner holds it. The test reads a process-private global whose name is as long as the vendor's, which nothing
/// writes. Pure; it names no other class, so it runs while a namespace is switched.</p>
ClassMethod PartnerFits(pName As %String) As %Boolean
{
    Set tFits = 1
    Try {
        Set tProbe = $Data(^||Ens.Config.BusinessPartnerD(pName))
    } Catch {
        Set tFits = 0
    }
    Quit tFits
}

/// <p>The most characters the vendor stores for the partner field <var>pField</var> (Story 20.26, measured): 5,000 for the
/// description, 1,000 for a contact's notes, 50 for a phone or mobile number and 255 for every other field. Pure.</p>
ClassMethod PartnerLimit(pField As %String) As %Integer
{
    Quit $Case(pField, "Description": 5000, "PrimaryNotes": 1000, "AlternativeNotes": 1000, "PrimaryPhone": 50, "PrimaryMobile": 50, "AlternativePhone": 50, "AlternativeMobile": 50, : ..#PARTNERNAMEMAX)
}

/// <p>The 422 violations of a partner's name and fields, in <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field,
/// code)</code> with the count in <code>pViolations</code> (Story 20.26): <code>Name</code> is 1 to 255 characters with no control
/// character and one the instance can address (<method>PartnerFits</method>), judged only when <var>pJudgeName</var> (an add: a
/// partner already held keeps the name it has), and each of the thirteen fields in
/// <var>pFields</var> (<code>pFields(field) = value</code>, a field not supplied is not judged) is within
/// <method>PartnerLimit</method>. They are the vendor's own limits (measured), and the vendor would refuse each with an error that
/// names none of them. Pure.</p>
ClassMethod PartnerViolations(pName As %String, ByRef pFields, Output pViolations, pJudgeName As %Boolean = 1) As %Status
{
    Kill pViolations
    Set pViolations = 0
    If pJudgeName && ((pName = "") || ($Length(pName) > ..#PARTNERNAMEMAX) || ($ZStrip(pName, "*C") '= pName) || '..PartnerFits(pName)) {
        Set pViolations($Increment(pViolations)) = $ListBuild("Name", ##class(OcuPilot.Api.InteropError).#PARTNERNAME)
    }
    Set tNames = $ListFromString(..#PARTNERSETFIELDS)
    For tI = 1:1:$ListLength(tNames) {
        Set tField = $List(tNames, tI)
        If $Length($Get(pFields(tField))) > ..PartnerLimit(tField) Set pViolations($Increment(pViolations)) = $ListBuild(tField, ##class(OcuPilot.Api.InteropError).#PARTNERLENGTH)
    }
    Quit $$$OK
}

/// <p>The decision a partner write <var>pType</var> is refused with, as the last segment of its code (<code>TAKEN</code>,
/// <code>NAMECASE</code>, <code>NAMED</code>) or <code>ABSENT</code> for a target that is not there, else <code>""</code> (Story
/// 20.26): whatever the vendor would answer as a silent success, or get wrong, is refused here by its own name. <var>pExists</var>
/// is whether the partner is held under exactly that name, <var>pMatch</var> the spelling it is held under in another letter case
/// (<code>""</code> when none) and <var>pNamed</var> how many items of any production name it. It names no other class, so it runs
/// while the partner's namespace is switched. Pure.</p>
/// <ul>
/// <li>Add: <code>TAKEN</code> when the name is held, <code>NAMECASE</code> when it is absent but held in another letter case.</li>
/// <li>Set: <code>ABSENT</code> unless the partner is held.</li>
/// <li>Remove: <code>ABSENT</code> unless the partner is held, then <code>NAMED</code> while any item names it.</li>
/// </ul>
ClassMethod PartnerWriteToken(pType As %String, pExists As %Boolean, pMatch As %String, pNamed As %Integer) As %String
{
    If pType = ..#TYPEADDPARTNER {
        If pExists Quit "TAKEN"
        If pMatch '= "" Quit "NAMECASE"
        Quit ""
    }
    If 'pExists Quit "ABSENT"
    If (pType = ..#TYPEREMOVEPARTNER) && (pNamed > 0) Quit "NAMED"
    Quit ""
}

/// <p>The dotted path, from the partner, of the property its field <var>pField</var> names (Story 20.26): <code>Description</code>,
/// or a contact's property, <code>PrimaryContact.Name</code> for <code>PrimaryContact</code> and so on. Pure.</p>
ClassMethod PartnerPath(pField As %String) As %String
{
    If pField = "Description" Quit "Description"
    Set tPrimary = ($Extract(pField, 1, 7) = "Primary")
    Set tRest = $Extract(pField, $Select(tPrimary: 8, 1: 12), *)
    Quit $Select(tPrimary: "PrimaryContact", 1: "AlternativeContact") _ "." _ $Case(tRest, "Contact": "Name", "Phone": "PhoneNumber", "Mobile": "MobileNumber", : tRest)
}

/// <p>Store <var>pValue</var> in the field <var>pField</var> of the partner <var>pPartner</var>, making its contact when it has none
/// (Story 20.26). It runs while a namespace is switched.</p>
ClassMethod PartnerSet(pPartner As %RegisteredObject, pField As %String, pValue As %String) [ Private ]
{
    Set tPath = ..PartnerPath(pField)
    If tPath '[ "." {
        Set $Property(pPartner, tPath) = pValue
        Quit
    }
    Set tContact = $Piece(tPath, ".", 1)
    Set tObject = $Property(pPartner, tContact)
    If '$IsObject(tObject) {
        Set $Property(pPartner, tContact) = ##class(Ens.Config.BusinessPartnerContact).%New()
        Set tObject = $Property(pPartner, tContact)
    }
    Set $Property(tObject, $Piece(tPath, ".", 2)) = pValue
}

/// <p>The twelve contact fields of the partner <var>pPartner</var>, as a <class>%List</class> in <parameter>PARTNERFIELDS</parameter>'
/// order after the description: the primary contact's name, title, email, phone, mobile and notes, then the alternative's. A
/// partner with no contact object, or no partner, reads as empty (Story 20.26). It runs while a namespace is switched.</p>
ClassMethod PartnerContacts(pPartner As %RegisteredObject) As %List [ Private ]
{
    Set tLine = ""
    For tContact = "PrimaryContact", "AlternativeContact" {
        Set tObject = $Select($IsObject(pPartner): $Property(pPartner, tContact), 1: "")
        If $IsObject(tObject) {
            Set tLine = tLine _ $ListBuild(tObject.Name, tObject.Title, tObject.Email, tObject.PhoneNumber, tObject.MobileNumber, tObject.Notes)
        } Else {
            Set tLine = tLine _ $ListBuild("", "", "", "", "", "")
        }
        Set tObject = ""
    }
    Quit tLine
}

/// <p>The partner <var>pPartner</var> named <var>pName</var> as the fourteen values <parameter>PARTNERFIELDS</parameter> names, in
/// order (Story 20.26). It runs while a namespace is switched.</p>
ClassMethod PartnerLine(pName As %String, pPartner As %RegisteredObject) As %List [ Private ]
{
    Quit $ListBuild(pName, $Select($IsObject(pPartner): pPartner.Description, 1: "")) _ ..PartnerContacts(pPartner)
}

/// <p>The row a partner list and the partner read answer, from the fourteen values <var>pLine</var> of
/// <method>PartnerLine</method>: <code>{Name, Description, ...}</code>, all strings; with <var>pNamespace</var> (the partner read)
/// <code>NamedBy</code>, how many items name the partner, and <code>Namespace</code> too. Runs in the install namespace.</p>
ClassMethod PartnerRow(pLine As %List, pNamed As %Integer = 0, pNamespace As %String = "") As %DynamicObject [ Private ]
{
    Set tNames = $ListFromString(..#PARTNERFIELDS)
    Set tRow = {}
    For tJ = 1:1:$ListLength(tNames) {
        Do tRow.%Set($List(tNames, tJ), $List(pLine, tJ) _ "", "string")
    }
    If pNamespace '= "" {
        Do tRow.%Set("NamedBy", +pNamed, "number")
        Do tRow.%Set("Namespace", pNamespace, "string")
    }
    Quit tRow
}

/// <p>How many items of every production of the current namespace name the partner <var>pName</var> in their Host
/// <code>BusinessPartner</code> setting, compared exactly, a running production or not (Story 20.26). A production whose
/// listing fails raises, so a partner is never read as named by nothing for want of an answer. Only vendor classes run, so it
/// runs while a namespace is switched. A credential, a system default setting or a managed alert that names the partner is not
/// counted.</p>
ClassMethod PartnerNamedByHere(pName As %String) As %Integer
{
    Set tCount = 0
    Kill tProductions
    Set tResultSet = ##class(%ResultSet).%New("Ens.Config.Production:ProductionStatus")
    Set tStatus = tResultSet.Execute()
    If $$$ISERR(tStatus) Throw ##class(%Exception.StatusException).CreateFromStatus(tStatus)
    While tResultSet.Next() {
        Set tProductions($Increment(tProductions)) = tResultSet.GetData(1)
    }
    Do tResultSet.Close()
    Set tResultSet = ""
    For tI = 1:1:$Get(tProductions) {
        Set tProduction = ##class(Ens.Config.Production).%OpenId(tProductions(tI))
        If '$IsObject(tProduction) Continue
        For tJ = 1:1:tProduction.Items.Count() {
            Set tItem = tProduction.Items.GetAt(tJ)
            If '$IsObject(tItem) Continue
            Set tSetting = tItem.FindSettingByName("BusinessPartner", "Host")
            If $IsObject(tSetting) && (tSetting.Value = pName) Set tCount = tCount + 1
        }
        Set tSetting = ""
        Set tItem = ""
        Set tProduction = ""
    }
    Quit tCount
}

/// <p>The facts about the partner <var>pName</var>, read in the current namespace, which the caller has already switched, and kept
/// in <var>pFacts</var>: <code>exists</code> (the partner is held under exactly that name), <code>match</code> (the spelling it
/// is held under in another letter case, else <code>""</code>, found by comparing every partner's name in upper case, so the work
/// is bounded by the partner count), and, for a partner that exists, <code>line</code> (<method>PartnerLine</method>) and
/// <code>named</code> (<method>PartnerNamedByHere</method>). A name the instance cannot address is not held. Nothing is written
/// (Story 20.26).</p>
ClassMethod PartnerFactsHere(pName As %String, ByRef pFacts) [ Private ]
{
    Kill pFacts
    Set pFacts("exists") = 0
    Set pFacts("match") = ""
    Set pFacts("named") = 0
    Set pFacts("line") = ""
    If '..PartnerFits(pName) Quit
    Set pFacts("exists") = ''##class(Ens.Config.BusinessPartner).%ExistsId(pName)
    If 'pFacts("exists") {
        Set tUpper = $ZConvert(pName, "U")
        Set tResultSet = ##class(%ResultSet).%New("Ens.Config.BusinessPartner:List")
        Set tStatus = tResultSet.Execute()
        If $$$ISOK(tStatus) {
            While tResultSet.Next() {
                Set tHeld = tResultSet.GetData(1)
                If $ZConvert(tHeld, "U") = tUpper {
                    Set pFacts("match") = tHeld
                    Quit
                }
            }
            Do tResultSet.Close()
        }
        Set tResultSet = ""
        Quit
    }
    Set tPartner = ##class(Ens.Config.BusinessPartner).%OpenId(pName)
    If $IsObject(tPartner) Set pFacts("line") = ..PartnerLine(pName, tPartner)
    Set tPartner = ""
    Set pFacts("named") = ..PartnerNamedByHere(pName)
}

/// <p><method>PartnerFactsHere</method> in <var>pNamespace</var>; a fault is <var>pCaught</var>, with the namespace restored
/// (Story 20.26).</p>
ClassMethod PartnerFacts(pNamespace As %String, pName As %String, Output pFacts, Output pCaught) [ Private ]
{
    Kill pFacts
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..PartnerFactsHere(pName, .pFacts)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>One business partner, fresh (Story 20.26): the fourteen fields of <method>ListPartners</method> and <code>NamedBy</code> (how
/// many items name it) and <code>Namespace</code>. A partner not held under exactly that name is 404 <code>PORT.NOTFOUND</code>,
/// unlogged. With <var>pAction</var> it refuses what that write would be refused, in this order: <code>SOURCECONTROL</code> for any
/// write; for an add (AD-54, which inverts the read) <code>TAKEN</code> when the name is held, <code>NAMECASE</code> when it is held
/// in another letter case, and otherwise the 404 a create expects; for a remove <code>NAMED</code> while any item names it.</p>
ClassMethod ReadPartner(pNamespace As %String, pName As %String, pAction As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    If (pAction '= "") && ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#PARTNERSOURCECONTROL, .pHttpStatus, .pFault)
    Do ..PartnerFacts(pNamespace, pName, .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the business partner read failed", .pHttpStatus, .pFault)
    If pAction = ..#TYPEADDPARTNER {
        Set tToken = ..PartnerWriteToken(pAction, tFacts("exists"), tFacts("match"), 0)
        If tToken '= "" Quit ..Conflict(..#PARTNERCODEPREFIX _ tToken, .pHttpStatus, .pFault)
        Quit ..Absent(.pHttpStatus, .pFault)
    }
    If 'tFacts("exists") Quit ..Absent(.pHttpStatus, .pFault)
    If pAction '= "" {
        Set tToken = ..PartnerWriteToken(pAction, 1, "", tFacts("named"))
        If tToken '= "" Quit ..Conflict(..#PARTNERCODEPREFIX _ tToken, .pHttpStatus, .pFault)
    }
    Set pRow = ..PartnerRow(tFacts("line"), tFacts("named"), pNamespace)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Serve the BusinessPartners endpoint's single-partner types (Story 20.26) after <method>Invoke</method>'s gate: the
/// <code>PARTNER</code> read and the three writes, the partner named under <parameter>IDKEY</parameter> by its name, kept exactly
/// (AD-13). An <parameter>ACTIONKEY</parameter> names the write the read is composed for.</p>
ClassMethod InvokePartner(pNamespace As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Set tName = $Get(pQuery(..#IDKEY))
        If tName = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONIDREQUIRED, .pHttpStatus, .pFault)
            Quit
        }
        Set tAction = $Select(..IsPartnerWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && '..IsPartnerWrite(tAction) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If ..IsPartnerWrite(pType) {
            Set tSC = ..PerformPartner(pNamespace, pType, tName, pBody, .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..ReadPartner(pNamespace, tName, tAction, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the business partner call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Run partner write <var>pType</var> on the partner <var>pName</var> in <var>pNamespace</var> and answer what it leaves (Story
/// 20.26). The sequence:</p>
/// <ol>
/// <li>A namespace under source control is <code>INTEROP.PARTNER.SOURCECONTROL</code>, before anything is read.</li>
/// <li>An add's or set's fields are judged by <method>PartnerViolations</method> (422, a value that is not a string the field's
/// shape); a remove of a name the instance cannot address is 404.</li>
/// <li>In the namespace the partner is read again and judged by <method>PartnerWriteToken</method>, so a state that moved since the
/// review is refused by its own code with no vendor call; then the vendor's <code>%Save</code> of a new partner, <code>%Save</code>
/// of the opened partner (concurrency 4, the reference dropped right after) with each field that differs, or
/// <code>%DeleteId</code> runs. A set that moves no field calls nothing. A partner another process holds locked is 503.</li>
/// <li>The namespace is restored, then OcuPilot's own audit row is recorded (<method>AuditRuntime</method>), because the vendor
/// records none. It carries the namespace and, for a set, the names of the fields it changed, never a value.</li>
/// </ol>
/// <p>The answer is the partner's row read again (<method>ReadPartner</method>); after a remove <code>{Name, Namespace}</code>.</p>
ClassMethod PerformPartner(pNamespace As %String, pType As %String, pName As %String, pBody As %DynamicAbstractObject, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#PARTNERSOURCECONTROL, .pHttpStatus, .pFault)
    Kill tValues
    Set tFields = $ListFromString(..#PARTNERSETFIELDS)
    If pType '= ..#TYPEREMOVEPARTNER {
        Set tViolations = 0
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Set pBody = {}
        For tI = 1:1:$ListLength(tFields) {
            Set tField = $List(tFields, tI)
            Set tFieldType = pBody.%GetTypeOf(tField)
            If tFieldType = "string" {
                Set tValues(tField) = pBody.%Get(tField)
            } ElseIf tFieldType '= "unassigned" {
                Set tViolations($Increment(tViolations)) = $ListBuild(tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
            }
        }
        Set tSC = ..PartnerViolations(pName, .tValues, .tFieldViolations, (pType = ..#TYPEADDPARTNER))
        If $$$ISERR(tSC) Quit tSC
        For tI = 1:1:tFieldViolations {
            Set tViolations($Increment(tViolations)) = tFieldViolations(tI)
        }
        If tViolations Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    } ElseIf '..PartnerFits(pName) {
        Quit ..Absent(.pHttpStatus, .pFault)
    }
    Set tToken = ""
    Set tCaught = ""
    Set tVendorSC = $$$OK
    Set tBusy = 0
    Set tChanged = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..PartnerFactsHere(pName, .tFacts)
        Set tToken = ..PartnerWriteToken(pType, tFacts("exists"), tFacts("match"), tFacts("named"))
        If tToken = "" {
            If pType = ..#TYPEADDPARTNER {
                Set tPartner = ##class(Ens.Config.BusinessPartner).%New()
                Set tPartner.PartnerName = pName
                For tI = 1:1:$ListLength(tFields) {
                    Do ..PartnerSet(tPartner, $List(tFields, tI), $Get(tValues($List(tFields, tI))))
                }
                Set tVendorSC = tPartner.%Save()
            } ElseIf pType = ..#TYPESETPARTNER {
                Set tPartner = ##class(Ens.Config.BusinessPartner).%OpenId(pName, 4)
                If '$IsObject(tPartner) {
                    Set tBusy = 1
                } Else {
                    Set tHeld = ..PartnerLine(pName, tPartner)
                    For tI = 1:1:$ListLength(tFields) {
                        Set tField = $List(tFields, tI)
                        If '$Data(tValues(tField)) Continue
                        If $List(tHeld, $ListFind($ListFromString(..#PARTNERFIELDS), tField)) = tValues(tField) Continue
                        Do ..PartnerSet(tPartner, tField, tValues(tField))
                        Set tChanged = tChanged _ $ListBuild(tField)
                    }
                    If tChanged '= "" Set tVendorSC = tPartner.%Save()
                }
            } Else {
                Set tVendorSC = ##class(Ens.Config.BusinessPartner).%DeleteId(pName)
            }
        }
        ; The partner's lock is released in the namespace it was taken in.
        Set tPartner = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Try {
            Set $NAMESPACE = pNamespace
        } Catch {
        }
        Set tPartner = ""
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the business partner write failed", .pHttpStatus, .pFault)
    If tBusy Quit ..Unavailable(.pHttpStatus, .pFault)
    If tToken = "ABSENT" Quit ..Absent(.pHttpStatus, .pFault)
    If tToken '= "" Quit ..Conflict(..#PARTNERCODEPREFIX _ tToken, .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the business partner write failed", .pHttpStatus, .pFault)
    If (pType '= ..#TYPESETPARTNER) || (tChanged '= "") {
        Set tEffects = {}
        Do tEffects.%Set("namespace", pNamespace, "string")
        If pType = ..#TYPESETPARTNER Do tEffects.%Set("fields", $ListToString(tChanged, ","), "string")
        Do ..AuditRuntime($Case(pType, ..#TYPEADDPARTNER: ..#VERBADD, ..#TYPESETPARTNER: ..#VERBSET, : ..#VERBREMOVE), ..#ENTITYPARTNER, pName, tEffects)
    }
    If pType = ..#TYPEREMOVEPARTNER {
        Set pResult = {}
        Do pResult.%Set("Name", pName, "string")
        Do pResult.%Set("Namespace", pNamespace, "string")
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Set tReadSC = ..ReadPartner(pNamespace, pName, "", .tRow, .tReadHttp, .tReadFault)
    If $$$ISERR(tReadSC) {
        Set tRow = {}
        Do tRow.%Set("Name", pName, "string")
        Do tRow.%Set("Namespace", pNamespace, "string")
    }
    Set pResult = tRow
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>The statement the default setting list and the comparison read: every row of <code>Ens.Config.DefaultSettings</code> as its key,
/// value, description and deployable flag, in key order (Story 24.15).</p>
Parameter DEFAULTSETTINGSQL = "SELECT TOP ? ProductionName, ItemName, HostClassName, SettingName, SettingValue, Description, Deployable FROM Ens_Config.DefaultSettings ORDER BY ProductionName, ItemName, HostClassName, SettingName";

/// <p>Whether the caller holds the <code>%All</code> role, as the vendor's own macro asks it (<code>$$$IOwnAllRole</code>): the roles
/// list begins with it. A test seam overrides it (<class>OcuPilot.Test.InteropDefaultSettingRoleSeam</class>).</p>
ClassMethod HoldsAllRole() As %Boolean
{
    Quit ($Extract($Roles, 1, 4) = "%All")
}

/// <p>Whether the caller holds <var>pPermission</var> on <var>pResource</var>, asked through the gate class at the time of the call
/// (Story 24.15).</p>
ClassMethod DefaultSettingHolds(pResource As %String, pPermission As %String) As %Boolean [ Private ]
{
    Quit ''$ClassMethod(..GateClass(), "EvaluateRequired", $ListBuild($ListBuild(pResource, pPermission)), .tFailedPair)
}

/// <p>Whether the caller may not write the default setting named <var>pSetting</var>, by the classic page's own per-setting rules
/// (<code>EnsPortal.DefaultSettings</code>' <code>canEditSettingName</code>), restated here because its checks cache in the web session and
/// these are asked at every call (Story 24.15, AD-8): the setting <code>Enabled</code> needs <parameter>ITEMRUNPAIR</parameter>; then a
/// holder of the <code>%All</code> role may write any; a caller without <parameter>DEFAULTSETTINGRESTRICTEDPAIR</parameter> may write any;
/// and a restricted caller never writes <code>*</code> and writes a setting <code>N</code> only with <code>%Ens_SystemDefaultSettings_N:USE</code>.</p>
ClassMethod DefaultSettingRestricted(pSetting As %String) As %Boolean
{
    If (pSetting = ..#DEFAULTSETTINGENABLED) && '..DefaultSettingHolds($Piece(..#ITEMRUNPAIR, ":", 1), $Piece(..#ITEMRUNPAIR, ":", 2)) Quit 1
    If ..HoldsAllRole() Quit 0
    If '..DefaultSettingHolds($Piece(..#DEFAULTSETTINGRESTRICTEDPAIR, ":", 1), $Piece(..#DEFAULTSETTINGRESTRICTEDPAIR, ":", 2)) Quit 0
    If pSetting = "*" Quit 1
    Quit '..DefaultSettingHolds(..#DEFAULTSETTINGRESOURCEPREFIX _ pSetting, "USE")
}

/// <p>The vendor's id of the default setting whose four key parts <var>pParts</var> holds: the parts joined by <code>||</code>.</p>
ClassMethod DefaultSettingId(pParts As %List) As %String [ Private ]
{
    Quit $ListToString(pParts, "||")
}

/// <p>Whether <var>pPart</var> is a valid part of a default setting's key: 1 to <parameter>DEFAULTSETTINGKEYMAX</parameter> characters
/// with no control character, no <code>||</code>, and no <code>|</code> at either end, since the vendor's id joins the parts with
/// <code>||</code> and a bar at a part's edge would split that id at another place. Pure.</p>
ClassMethod DefaultSettingPartOK(pPart As %String) As %Boolean
{
    Quit (pPart '= "") && ($Length(pPart) <= ..#DEFAULTSETTINGKEYMAX) && ($ZStrip(pPart, "*C") = pPart) && (pPart '[ "||") && ($Extract(pPart) '= "|") && ($Extract(pPart, *) '= "|")
}

/// <p>Whether the instance can address <code>^Ens.Config.DefaultSettingsD</code> by the four parts <var>pParts</var>: a key whose encoded
/// form is past the instance's subscript limit raises <code>&lt;SUBSCRIPT&gt;</code> in the vendor's own calls, so no setting holds it.
/// The test reads a process-private global whose name is as long as the vendor's, which nothing writes. Names no other class, so it runs
/// while a namespace is switched.</p>
ClassMethod DefaultSettingFits(pParts As %List) As %Boolean
{
    Set tFits = 1
    Try {
        Set tProbe = $Data(^||Ens.Config.DefaultSettingsD($List(pParts, 1), $List(pParts, 2), $List(pParts, 3), $List(pParts, 4)))
    } Catch {
        Set tFits = 0
    }
    Quit tFits
}

/// <p>Whether <var>pParts</var> is four valid key parts the instance can address (<method>DefaultSettingPartOK</method>,
/// <method>DefaultSettingFits</method>). Pure.</p>
ClassMethod DefaultSettingKeyOK(pParts As %List) As %Boolean
{
    If '$ListValid(pParts) || ($ListLength(pParts) '= 4) Quit 0
    Set tValid = 1
    For tI = 1:1:4 {
        If '..DefaultSettingPartOK($List(pParts, tI)) Set tValid = 0
    }
    If 'tValid Quit 0
    Quit ..DefaultSettingFits(pParts)
}

/// <p>Whether the vendor accepts <var>pValue</var> for the setting the key parts name, in <var>pNamespace</var>: a transient
/// <code>Ens.Config.DefaultSettings</code> is validated, never saved, so the vendor's own <code>%OnValidateObject</code> judges the value as
/// its classic page does. The vendor's text is logged and never shown (Story 24.15).</p>
ClassMethod DefaultSettingAccepts(pNamespace As %String, pParts As %List, pValue As %String) As %Boolean
{
    Set tVendorSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tObject = ##class(Ens.Config.DefaultSettings).%New()
        Set tObject.ProductionName = $List(pParts, 1)
        Set tObject.ItemName = $List(pParts, 2)
        Set tObject.HostClassName = $List(pParts, 3)
        Set tObject.SettingName = $List(pParts, 4)
        Set tObject.SettingValue = pValue
        Set tVendorSC = tObject.%ValidateObject()
        Set tObject = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tVendorSC = ex.AsStatus()
    }
    If $$$ISERR(tVendorSC) Do ..LogFault("a default setting value did not pass the vendor's validation", tVendorSC)
    Quit $$$ISOK(tVendorSC)
}

/// <p>The 422 violations of a default setting's key and fields, in <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field,
/// code)</code> with the count in <code>pViolations</code> (Story 24.15): a key part that <method>DefaultSettingPartOK</method> refuses, or
/// a key the instance cannot address, is <code>KEY</code> on that part (judged only when <var>pJudgeKey</var>, which an add passes); a value
/// or description past <parameter>DEFAULTSETTINGTEXTMAX</parameter> is <code>VALUE</code>; a field of the wrong type is
/// <code>PORT.FIELD.SHAPE</code>; and, with <var>pJudgeValue</var>, when nothing else is wrong and a value is given, or an add names none
/// (the empty value), a value the vendor refuses (<method>DefaultSettingAccepts</method>) is <code>VALUE</code>. The vendor is never asked
/// about a setting whose name the credential pattern matches, which every write refuses by its name. A caller that has not yet passed the
/// port's gate and refusals passes <var>pJudgeValue</var> 0, so no vendor call runs before them. <var>pFields</var> is the body:
/// <code>Value</code> and <code>Description</code> strings and <code>Deployable</code> a boolean.</p>
ClassMethod DefaultSettingViolations(pNamespace As %String, pProduction As %String, pItem As %String, pHostClass As %String, pSetting As %String, pFields As %DynamicObject, Output pViolations, pJudgeKey As %Boolean = 1, pJudgeValue As %Boolean = 1) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tParts = $ListBuild(pProduction, pItem, pHostClass, pSetting)
    Set tNames = $ListBuild("Production", "Item", "HostClass", "Setting")
    If pJudgeKey {
        For tI = 1:1:4 {
            If '..DefaultSettingPartOK($List(tParts, tI)) Set pViolations($Increment(pViolations)) = $ListBuild($List(tNames, tI), ##class(OcuPilot.Api.InteropError).#DEFAULTSETTINGKEY)
        }
        If 'pViolations && '..DefaultSettingFits(tParts) Set pViolations($Increment(pViolations)) = $ListBuild("Setting", ##class(OcuPilot.Api.InteropError).#DEFAULTSETTINGKEY)
    }
    If '$IsObject(pFields) || 'pFields.%IsA("%Library.DynamicObject") Set pFields = {}
    For tField = "Value", "Description" {
        Set tType = pFields.%GetTypeOf(tField)
        If tType = "string" {
            If $Length(pFields.%Get(tField)) > ..#DEFAULTSETTINGTEXTMAX Set pViolations($Increment(pViolations)) = $ListBuild(tField, ##class(OcuPilot.Api.InteropError).#DEFAULTSETTINGVALUE)
        } ElseIf tType '= "unassigned" {
            Set pViolations($Increment(pViolations)) = $ListBuild(tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
    }
    Set tType = pFields.%GetTypeOf("Deployable")
    If (tType '= "boolean") && (tType '= "unassigned") Set pViolations($Increment(pViolations)) = $ListBuild("Deployable", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
    If pViolations || 'pJudgeValue || ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(pSetting) Quit $$$OK
    If ((pFields.%GetTypeOf("Value") = "string") || (pJudgeKey && (pFields.%GetTypeOf("Value") = "unassigned"))) && '..DefaultSettingAccepts(pNamespace, tParts, pFields.%Get("Value")) {
        Set pViolations($Increment(pViolations)) = $ListBuild("Value", ##class(OcuPilot.Api.InteropError).#DEFAULTSETTINGVALUE)
    }
    Quit $$$OK
}

/// <p>The decision a default setting write <var>pType</var> is refused with, as the last segment of its code (<code>TAKEN</code>) or
/// <code>ABSENT</code> for a target that is not there, else <code>""</code> (Story 24.15): an add of a key the namespace holds is
/// <code>TAKEN</code>; a set or a remove of a key it does not hold is <code>ABSENT</code>. <var>pExists</var> is whether the setting is held
/// under exactly that key. Pure.</p>
ClassMethod DefaultSettingWriteToken(pType As %String, pExists As %Boolean) As %String
{
    If pType = ..#TYPEADDDEFAULT Quit $Select(pExists: "TAKEN", 1: "")
    Quit $Select(pExists: "", 1: "ABSENT")
}

/// <p>The setting <var>pObject</var> as the seven values <parameter>DEFAULTSETTINGFIELDS</parameter> names, in that order. Runs while the
/// setting's namespace is switched.</p>
ClassMethod DefaultSettingLine(pObject As %RegisteredObject) As %List [ Private ]
{
    Set tValue = pObject.SettingValue
    If tValue = $Char(0) Set tValue = ""
    Set tDescription = pObject.Description
    If tDescription = $Char(0) Set tDescription = ""
    Quit $ListBuild(pObject.ProductionName, pObject.ItemName, pObject.HostClassName, pObject.SettingName, tValue, tDescription, ''pObject.Deployable)
}

/// <p>The row a default setting list and read answer, from the seven values <var>pLine</var> (<method>DefaultSettingLine</method>):
/// <code>{Production, Item, HostClass, Setting, Value, Description, Deployable, Secret}</code>, and with <var>pNamespace</var>
/// <code>Namespace</code> too. A setting whose name the credential pattern matches
/// (<method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method>) answers an empty <code>Value</code> and <code>Secret</code> true: the value
/// is dropped here, in the install namespace, and reaches nothing that renders the row (AD-35, Story 24.15).</p>
ClassMethod DefaultSettingRow(pLine As %List, pNamespace As %String = "") As %DynamicObject [ Private ]
{
    Set tSecret = ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName($List(pLine, 4))
    Set tRow = {}
    Do tRow.%Set("Production", $List(pLine, 1) _ "", "string")
    Do tRow.%Set("Item", $List(pLine, 2) _ "", "string")
    Do tRow.%Set("HostClass", $List(pLine, 3) _ "", "string")
    Do tRow.%Set("Setting", $List(pLine, 4) _ "", "string")
    Do tRow.%Set("Value", $Select(tSecret: "", 1: $List(pLine, 5) _ ""), "string")
    Do tRow.%Set("Description", $List(pLine, 6) _ "", "string")
    Do tRow.%Set("Deployable", ''$List(pLine, 7), "boolean")
    Do tRow.%Set("Secret", ''tSecret, "boolean")
    If pNamespace '= "" Do tRow.%Set("Namespace", pNamespace, "string")
    Quit tRow
}

/// <p>The namespace's system default settings, one row per setting, at most <var>pMax</var> when it is above zero (Story 24.15):
/// <method>DefaultSettingRow</method>'s fields, in key order. Read with <code>%ExecDirectNoPriv</code> after the gate (<method>SqlRows</method>);
/// nothing is written.</p>
ClassMethod ListDefaultSettings(pNamespace As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..SqlRows(pNamespace, ..#DEFAULTSETTINGSQL, .tFound, .tCaught, $Select(pMax > 0: pMax, 1: ..#SQLMAX))
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the system default setting list failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..DefaultSettingRow(tFound(tI)))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The facts about the default setting the key parts <var>pParts</var> name, read in the current namespace, which the caller has already
/// switched, and kept in <var>pFacts</var>: <code>exists</code> (the namespace holds it under exactly that key) and, when it does,
/// <code>line</code> (<method>DefaultSettingLine</method>). A key the instance cannot address is not held. Nothing is written.</p>
ClassMethod DefaultSettingFactsHere(pParts As %List, ByRef pFacts) [ Private ]
{
    Kill pFacts
    Set pFacts("exists") = 0
    Set pFacts("line") = ""
    If '..DefaultSettingFits(pParts) Quit
    Set tId = ..DefaultSettingId(pParts)
    If '##class(Ens.Config.DefaultSettings).%ExistsId(tId) Quit
    Set tObject = ##class(Ens.Config.DefaultSettings).%OpenId(tId)
    If $IsObject(tObject) {
        Set pFacts("exists") = 1
        Set pFacts("line") = ..DefaultSettingLine(tObject)
    }
    Set tObject = ""
}

/// <p><method>DefaultSettingFactsHere</method> in <var>pNamespace</var>; a fault is <var>pCaught</var>, with the namespace restored.</p>
ClassMethod DefaultSettingFacts(pNamespace As %String, pParts As %List, Output pFacts, Output pCaught) [ Private ]
{
    Kill pFacts
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..DefaultSettingFactsHere(pParts, .pFacts)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>403 <code>INTEROP.DEFAULTSETTING.RESTRICTED</code>: the classic page would not let the caller change this setting's default.</p>
ClassMethod DefaultSettingRestrictedRefusal(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tCode = ##class(OcuPilot.Api.InteropError).#DEFAULTSETTINGRESTRICTED
    Quit ..Refuse(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, tCode, ##class(OcuPilot.Api.InteropError).ReasonFor(tCode), .pHttpStatus, .pFault)
}

/// <p>The refusals every default setting write is judged on before its namespace is read, as an error status with
/// <var>pHttpStatus</var> and <var>pFault</var> set, or <code>$$$OK</code> (Story 24.15): <code>RESTRICTED</code> by the classic page's
/// per-setting rules (<method>DefaultSettingRestricted</method>), <code>SOURCECONTROL</code> for a namespace under source control, then
/// <code>SECRET</code> for a setting whose name the credential pattern matches.</p>
ClassMethod DefaultSettingWriteRefusal(pNamespace As %String, pSetting As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    If ..DefaultSettingRestricted(pSetting) Quit ..DefaultSettingRestrictedRefusal(.pHttpStatus, .pFault)
    If ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#DEFAULTSETTINGSOURCECONTROL, .pHttpStatus, .pFault)
    If ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(pSetting) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#DEFAULTSETTINGSECRET, .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>One system default setting, fresh (Story 24.15): <method>DefaultSettingRow</method>'s fields and <code>Namespace</code>. A setting
/// not held under exactly that key, or a key that is not four valid parts, is 404 <code>PORT.NOTFOUND</code>, unlogged. With
/// <var>pAction</var> it refuses what that write would be refused, in this order (<method>DefaultSettingWriteRefusal</method>):
/// <code>RESTRICTED</code>, <code>SOURCECONTROL</code>, <code>SECRET</code>; then, for an add (AD-54, which inverts the read),
/// <code>TAKEN</code> when the key is held and otherwise the 404 a create expects.</p>
ClassMethod ReadDefaultSetting(pNamespace As %String, pParts As %List, pAction As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    If '..DefaultSettingKeyOK(pParts) Quit ..Absent(.pHttpStatus, .pFault)
    If pAction '= "" {
        Set tSC = ..DefaultSettingWriteRefusal(pNamespace, $List(pParts, 4), .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
    }
    Do ..DefaultSettingFacts(pNamespace, pParts, .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the system default setting read failed", .pHttpStatus, .pFault)
    If pAction = ..#TYPEADDDEFAULT {
        If ..DefaultSettingWriteToken(pAction, tFacts("exists")) '= "" Quit ..Conflict(##class(OcuPilot.Api.InteropError).#DEFAULTSETTINGTAKEN, .pHttpStatus, .pFault)
        Quit ..Absent(.pHttpStatus, .pFault)
    }
    If 'tFacts("exists") Quit ..Absent(.pHttpStatus, .pFault)
    Set pRow = ..DefaultSettingRow(tFacts("line"), pNamespace)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Serve the DefaultSettings endpoint's <code>LIST</code> and typed types, and the DefaultSettingsDiff endpoint's <code>LIST</code>, after
/// <method>Invoke</method>'s gate (Story 24.15). A typed call names the setting under <parameter>IDKEY</parameter> by the composite
/// <code>[Production, Item, HostClass, Setting]</code>, each part kept exactly (AD-13); an id that is not four parts is 404. An
/// <parameter>ACTIONKEY</parameter> names the write the read is composed for.</p>
ClassMethod InvokeDefaultSetting(pNamespace As %String, pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType = ..#TYPELIST {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            If pEndpoint = ..#ENDPOINTDEFAULTSETTINGSDIFF {
                Set tSC = ..ListDefaultSettingDiff(pNamespace, $Get(pQuery(..#DIFFTARGETKEY)), +tMaxText, .pResult, .pHttpStatus, .pFault)
            } Else {
                Set tSC = ..ListDefaultSettings(pNamespace, +tMaxText, .pResult, .pHttpStatus, .pFault)
            }
            Quit
        }
        Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite($Get(pQuery(..#IDKEY)))
        Set tAction = $Select(..IsDefaultSettingWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && '..IsDefaultSettingWrite(tAction) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If ..IsDefaultSettingWrite(pType) {
            Set tSC = ..PerformDefaultSetting(pNamespace, pType, tParts, pBody, .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..ReadDefaultSetting(pNamespace, tParts, tAction, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the system default setting call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Run default setting write <var>pType</var> on the setting the key parts <var>pParts</var> name in <var>pNamespace</var> and answer
/// what it leaves (Story 24.15). The sequence:</p>
/// <ol>
/// <li>The refusals of <method>DefaultSettingWriteRefusal</method>, before anything is read.</li>
/// <li>An add's or set's key and fields are judged by <method>DefaultSettingViolations</method> (422); a remove of a key that is not four
/// valid parts is 404.</li>
/// <li>In the namespace the setting is read again and judged by <method>DefaultSettingWriteToken</method>, so a state that moved since the
/// review is refused by its own code with no vendor call; then the vendor's <code>%Save</code> of a new setting, <code>%Save</code> of the
/// opened setting (concurrency 4, the reference dropped right after) with each field that differs, or <code>%DeleteId</code> runs. A set that
/// moves no field calls nothing. A setting another process holds locked is 503.</li>
/// </ol>
/// <p>The vendor records its own audit row for each insert, update and delete (measured), so the port records none. The answer is the
/// setting's row read again (<method>ReadDefaultSetting</method>); after a remove <code>{Production, Item, HostClass, Setting, Namespace}</code>.</p>
ClassMethod PerformDefaultSetting(pNamespace As %String, pType As %String, pParts As %List, pBody As %DynamicAbstractObject, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If '$ListValid(pParts) || ($ListLength(pParts) '= 4) Quit ..Absent(.pHttpStatus, .pFault)
    Set tSC = ..DefaultSettingWriteRefusal(pNamespace, $List(pParts, 4), .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Set pBody = {}
    If pType = ..#TYPEREMOVEDEFAULT {
        If '..DefaultSettingKeyOK(pParts) Quit ..Absent(.pHttpStatus, .pFault)
    } Else {
        Set tSC = ..DefaultSettingViolations(pNamespace, $List(pParts, 1), $List(pParts, 2), $List(pParts, 3), $List(pParts, 4), pBody, .tViolations, (pType = ..#TYPEADDDEFAULT))
        If $$$ISERR(tSC) Quit tSC
        If tViolations Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
        If '..DefaultSettingKeyOK(pParts) Quit ..Absent(.pHttpStatus, .pFault)
    }
    Set tToken = ""
    Set tCaught = ""
    Set tVendorSC = $$$OK
    Set tBusy = 0
    Set tChanged = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..DefaultSettingFactsHere(pParts, .tFacts)
        Set tToken = ..DefaultSettingWriteToken(pType, tFacts("exists"))
        If tToken = "" {
            Set tId = ..DefaultSettingId(pParts)
            If pType = ..#TYPEADDDEFAULT {
                Set tObject = ##class(Ens.Config.DefaultSettings).%New()
                Set tObject.ProductionName = $List(pParts, 1)
                Set tObject.ItemName = $List(pParts, 2)
                Set tObject.HostClassName = $List(pParts, 3)
                Set tObject.SettingName = $List(pParts, 4)
                If pBody.%GetTypeOf("Value") = "string" Set tObject.SettingValue = pBody.%Get("Value")
                If pBody.%GetTypeOf("Description") = "string" Set tObject.Description = pBody.%Get("Description")
                If pBody.%GetTypeOf("Deployable") = "boolean" Set tObject.Deployable = pBody.%Get("Deployable")
                Set tVendorSC = tObject.%Save()
            } ElseIf pType = ..#TYPESETDEFAULT {
                Set tObject = ##class(Ens.Config.DefaultSettings).%OpenId(tId, 4)
                If '$IsObject(tObject) {
                    Set tBusy = 1
                } Else {
                    Set tHeld = ..DefaultSettingLine(tObject)
                    If (pBody.%GetTypeOf("Value") = "string") && (pBody.%Get("Value") '= $List(tHeld, 5)) {
                        Set tObject.SettingValue = pBody.%Get("Value")
                        Set tChanged = tChanged _ $ListBuild("Value")
                    }
                    If (pBody.%GetTypeOf("Description") = "string") && (pBody.%Get("Description") '= $List(tHeld, 6)) {
                        Set tObject.Description = pBody.%Get("Description")
                        Set tChanged = tChanged _ $ListBuild("Description")
                    }
                    If (pBody.%GetTypeOf("Deployable") = "boolean") && (''pBody.%Get("Deployable") '= $List(tHeld, 7)) {
                        Set tObject.Deployable = pBody.%Get("Deployable")
                        Set tChanged = tChanged _ $ListBuild("Deployable")
                    }
                    If tChanged '= "" Set tVendorSC = tObject.%Save()
                }
            } Else {
                Set tVendorSC = ##class(Ens.Config.DefaultSettings).%DeleteId(tId)
            }
        }
        ; The setting's lock is released in the namespace it was taken in.
        Set tObject = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Try {
            Set $NAMESPACE = pNamespace
        } Catch {
        }
        Set tObject = ""
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the system default setting write failed", .pHttpStatus, .pFault)
    If tBusy Quit ..Unavailable(.pHttpStatus, .pFault)
    If tToken = "ABSENT" Quit ..Absent(.pHttpStatus, .pFault)
    If tToken '= "" Quit ..Conflict(..#DEFAULTSETTINGCODEPREFIX _ tToken, .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the system default setting write failed", .pHttpStatus, .pFault)
    If pType = ..#TYPEREMOVEDEFAULT {
        Set pResult = {}
        Set tNames = $ListFromString(..#DEFAULTSETTINGFIELDS)
        For tI = 1:1:4 {
            Do pResult.%Set($List(tNames, tI), $List(pParts, tI), "string")
        }
        Do pResult.%Set("Namespace", pNamespace, "string")
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Set tReadSC = ..ReadDefaultSetting(pNamespace, pParts, "", .tRow, .tReadHttp, .tReadFault)
    If $$$ISERR(tReadSC) {
        Set tRow = {}
        Do tRow.%Set("Setting", $List(pParts, 4), "string")
        Do tRow.%Set("Namespace", pNamespace, "string")
    }
    Set pResult = tRow
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>The default settings of <var>pNamespace</var>, as <method>SqlRows</method> reads them, kept in <var>pSide</var> by key
/// (<code>pSide("k" _ production, "k" _ item, "k" _ host class, "k" _ setting) = $ListBuild(value, description, deployable)</code>, so no
/// subscript is empty or reads as a number) with the count in <var>pCount</var>. A side with more than
/// <parameter>DEFAULTSETTINGSIDEMAX</parameter> rows is <var>pTooMany</var> and keeps none. A fault is <var>pCaught</var>.</p>
ClassMethod DefaultSettingSide(pNamespace As %String, Output pSide, Output pCount As %Integer, Output pTooMany As %Boolean, Output pCaught) [ Private ]
{
    Kill pSide
    Set pCount = 0
    Set pTooMany = 0
    Set tSC = ..SqlRows(pNamespace, ..#DEFAULTSETTINGSQL, .tFound, .pCaught, ..#DEFAULTSETTINGSIDEMAX + 1)
    If $IsObject(pCaught) Quit
    If tFound > ..#DEFAULTSETTINGSIDEMAX {
        Set pTooMany = 1
        Quit
    }
    For tI = 1:1:tFound {
        Set tLine = tFound(tI)
        Set pSide("k" _ $List(tLine, 1), "k" _ $List(tLine, 2), "k" _ $List(tLine, 3), "k" _ $List(tLine, 4)) = $ListBuild($List(tLine, 5), $List(tLine, 6), ''$List(tLine, 7))
    }
    Set pCount = tFound
}

/// <p>The system default settings that differ between <var>pNamespace</var> and the namespace <var>pTarget</var> names (Story 24.15,
/// DW-2636), one row per setting, at most <var>pMax</var> when it is above zero, in key order:
/// <code>{Production, Item, HostClass, Setting, Change, Value, OtherValue, Secret, Namespace, OtherNamespace}</code>. The settings are keyed
/// by the exact composite key; <code>Change</code> is <parameter>DIFFONLYHERE</parameter>, <parameter>DIFFONLYTHERE</parameter> or
/// <parameter>DIFFDIFFERS</parameter> (a different value, description or deployable flag); identical settings are not listed. A setting whose
/// name the credential pattern matches shows neither value and still compares.</p>
/// <p>Refused before any read: a <var>pTarget</var> that is empty or the route's namespace (400); the target not admitted as the route's
/// namespace is (<method>Admit</method>: a malformed namespace name 400, a missing pair 403, a namespace that does not report interoperability,
/// an unknown one included, 409 <code>INTEROP.NAMESPACE</code> naming it); a side over <parameter>DEFAULTSETTINGSIDEMAX</parameter> (409
/// <code>INTEROP.DEFAULTSETTING.TOOMANY</code> naming it).</p>
ClassMethod ListDefaultSettingDiff(pNamespace As %String, pTarget As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    If (pTarget = "") || ($ZConvert(pTarget, "U") = $ZConvert(pNamespace, "U")) Quit ..RefuseCriterion(..#DIFFTARGETKEY, .pHttpStatus, .pFault)
    Set tSC = ..Admit(..#ENDPOINTDEFAULTSETTINGSDIFF, ..#TYPELIST, pTarget, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        If pHttpStatus = 409 Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.InteropError).#NAMESPACE, ##class(OcuPilot.Api.InteropError).#REASONNAMESPACE, .pHttpStatus, .pFault, {"namespace": (pTarget)})
        Quit tSC
    }
    Do ..DefaultSettingSide(pNamespace, .tHere, .tHereCount, .tHereMany, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the system default settings could not be read", .pHttpStatus, .pFault)
    If tHereMany Quit ..DefaultSettingTooMany(pNamespace, .pHttpStatus, .pFault)
    Do ..DefaultSettingSide(pTarget, .tThere, .tThereCount, .tThereMany, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the system default settings could not be read", .pHttpStatus, .pFault)
    If tThereMany Quit ..DefaultSettingTooMany(pTarget, .pHttpStatus, .pFault)
    ; The union of both sides' keys, walked in order.
    Merge tAll = tHere
    Merge tAll = tThere
    Set pRows = []
    Set tCount = 0
    Set tP = ""
    For {
        Set tP = $Order(tAll(tP))
        If tP = "" Quit
        Set tI = ""
        For {
            Set tI = $Order(tAll(tP, tI))
            If tI = "" Quit
            Set tC = ""
            For {
                Set tC = $Order(tAll(tP, tI, tC))
                If tC = "" Quit
                Set tS = ""
                For {
                    Set tS = $Order(tAll(tP, tI, tC, tS))
                    If tS = "" Quit
                    If (pMax > 0) && (tCount >= pMax) Quit
                    Set tChange = ""
                    Set tHeldHere = $Data(tHere(tP, tI, tC, tS), tLineHere)
                    Set tHeldThere = $Data(tThere(tP, tI, tC, tS), tLineThere)
                    If tHeldHere && 'tHeldThere {
                        Set tChange = ..#DIFFONLYHERE
                    } ElseIf 'tHeldHere && tHeldThere {
                        Set tChange = ..#DIFFONLYTHERE
                    } ElseIf tLineHere '= tLineThere {
                        Set tChange = ..#DIFFDIFFERS
                    }
                    If tChange = "" Continue
                    Set tSetting = $Extract(tS, 2, *)
                    Set tSecret = ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tSetting)
                    Set tRow = {}
                    Do tRow.%Set("Production", $Extract(tP, 2, *), "string")
                    Do tRow.%Set("Item", $Extract(tI, 2, *), "string")
                    Do tRow.%Set("HostClass", $Extract(tC, 2, *), "string")
                    Do tRow.%Set("Setting", tSetting, "string")
                    Do tRow.%Set("Change", tChange, "string")
                    Do tRow.%Set("Value", $Select(tSecret || 'tHeldHere: "", 1: $List(tLineHere, 1) _ ""), "string")
                    Do tRow.%Set("OtherValue", $Select(tSecret || 'tHeldThere: "", 1: $List(tLineThere, 1) _ ""), "string")
                    Do tRow.%Set("Secret", ''tSecret, "boolean")
                    Do tRow.%Set("Namespace", pNamespace, "string")
                    Do tRow.%Set("OtherNamespace", pTarget, "string")
                    Do pRows.%Push(tRow)
                    Set tCount = tCount + 1
                }
            }
        }
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>409 <code>INTEROP.DEFAULTSETTING.TOOMANY</code> naming <var>pNamespace</var> in <code>detail.namespace</code>.</p>
ClassMethod DefaultSettingTooMany(pNamespace As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tCode = ##class(OcuPilot.Api.InteropError).#DEFAULTSETTINGTOOMANY
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, tCode, ##class(OcuPilot.Api.InteropError).ReasonFor(tCode), .pHttpStatus, .pFault, {"namespace": (pNamespace)})
}

/// <p>The lines <method>Snippet</method> adds for the default setting write <var>pType</var> of the setting the composite id
/// <var>pId</var> names (Story 24.15): the vendor's <code>%Save</code> of a new setting with each field the body <var>pBody</var> carries,
/// a <code>%Save</code> of the setting opened at concurrency 4 with the fields it carries, or <code>%DeleteId</code>. Keys and values are
/// string literals; the value of a setting whose name the credential pattern matches is rendered as <code>&lt;Value&gt;</code>, never as
/// sent (AD-35).</p>
ClassMethod DefaultSettingSnippet(pType As %String, pId As %String, pBody As %DynamicAbstractObject) As %String [ Private ]
{
    Set tNL = $Char(10)
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pId)
    Set tId = ..Literal($ListToString(tParts, "||"))
    If pType = ..#TYPEREMOVEDEFAULT Quit tNL _ " Set tSC = ##class(Ens.Config.DefaultSettings).%DeleteId(" _ tId _ ")"
    If pType = ..#TYPEADDDEFAULT {
        Set tText = tNL _ " Set tSetting = ##class(Ens.Config.DefaultSettings).%New()"
        Set tNames = $ListBuild("ProductionName", "ItemName", "HostClassName", "SettingName")
        For tI = 1:1:4 {
            Set tText = tText _ tNL _ " Set tSetting." _ $List(tNames, tI) _ " = " _ ..Literal($ListGet(tParts, tI))
        }
    } Else {
        Set tText = tNL _ " Set tSetting = ##class(Ens.Config.DefaultSettings).%OpenId(" _ tId _ ", 4)"
    }
    For tField = "Value", "Description", "Deployable" {
        Set tProperty = $Case(tField, "Value": "SettingValue", : tField)
        Set tType = $Select($IsObject(pBody): pBody.%GetTypeOf(tField), 1: "unassigned")
        If tType = "string" {
            Set tValue = $Select((tField = "Value") && ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName($ListGet(tParts, 4)): "<Value>", 1: pBody.%Get(tField))
            Set tText = tText _ tNL _ " Set tSetting." _ tProperty _ " = " _ ..Literal(tValue)
        } ElseIf tType = "boolean" {
            Set tText = tText _ tNL _ " Set tSetting." _ tProperty _ " = " _ (''pBody.%Get(tField))
        }
    }
    Quit tText _ tNL _ " Set tSC = tSetting.%Save()" _ tNL _ " Set tSetting = """""
}

/// <p>The statement the credential list reads: every credential's name, user name and business partner, in name order (Story 24.15). It names
/// no password column, so the list never reads one.</p>
Parameter CREDENTIALSQL = "SELECT TOP ? SystemName, Username, BusinessPartner FROM Ens_Config.Credentials ORDER BY SystemName";

/// <p>Whether <var>pName</var> is a name the vendor stores for a credential (Story 24.15): 1 to <parameter>CREDENTIALNAMEMAX</parameter>
/// characters with no control character. Pure.</p>
ClassMethod CredentialNameOK(pName As %String) As %Boolean
{
    Quit (pName '= "") && ($Length(pName) <= ..#CREDENTIALNAMEMAX) && ($ZStrip(pName, "*C") = pName)
}

/// <p>Whether a password is stored for the credential <var>pName</var> in the current namespace, which the caller has already switched: the
/// vendor's secondary node exists and is not empty (measured). The password is tested in one expression and never held, compared or returned.</p>
ClassMethod CredentialStoredHere(pName As %String) As %Boolean [ Private ]
{
    If pName = "" Quit 0
    Quit ($Length($Get(^Ens.SecondaryData.Password(pName))) > 0)
}

/// <p>The credential as the four values <parameter>CREDENTIALFIELDS</parameter> names, in that order, the last 1 when a password is stored. Runs
/// while the credential's namespace is switched.</p>
ClassMethod CredentialLine(pName As %String, pUsername As %String, pPartner As %String) As %List [ Private ]
{
    If pUsername = $Char(0) Set pUsername = ""
    If pPartner = $Char(0) Set pPartner = ""
    Quit $ListBuild(pName, pUsername, pPartner, ''..CredentialStoredHere(pName))
}

/// <p>The row a credential list and read answer, from the four values <var>pLine</var> (<method>CredentialLine</method>):
/// <code>{Name, Username, BusinessPartner, Password}</code>, and with <var>pNamespace</var> <code>Namespace</code> too. <code>Password</code> is
/// <parameter>CREDENTIALSTORED</parameter> or <parameter>CREDENTIALNOTSTORED</parameter> and never a value (AD-35, Story 24.15).</p>
ClassMethod CredentialRow(pLine As %List, pNamespace As %String = "") As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Name", $List(pLine, 1) _ "", "string")
    Do tRow.%Set("Username", $List(pLine, 2) _ "", "string")
    Do tRow.%Set("BusinessPartner", $List(pLine, 3) _ "", "string")
    Do tRow.%Set("Password", $Select($List(pLine, 4): ..#CREDENTIALSTORED, 1: ..#CREDENTIALNOTSTORED), "string")
    If pNamespace '= "" Do tRow.%Set("Namespace", pNamespace, "string")
    Quit tRow
}

/// <p>The credentials of the current namespace, which the caller has already switched, as <var>pFound</var>(n) = <method>CredentialLine</method>,
/// at most <var>pMax</var>. Read with <code>%ExecDirectNoPriv</code> after the gate; nothing is written.</p>
ClassMethod CredentialLinesHere(pMax As %Integer, Output pFound) [ Private ]
{
    Kill pFound
    Set pFound = 0
    Set tStatement = ##class(%SQL.Statement).%New()
    Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(.tStatement, ..#CREDENTIALSQL, pMax)
    If '$IsObject(tResult) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the statement answered no result"))
    If tResult.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLCode, tResult.%SQLCODE, tResult.%Message))
    While tResult.%Next(.tNextSC) {
        Set pFound($Increment(pFound)) = ..CredentialLine(tResult.%GetData(1), tResult.%GetData(2), tResult.%GetData(3))
    }
    If $$$ISERR($Get(tNextSC, $$$OK)) Throw ##class(%Exception.StatusException).CreateFromStatus(tNextSC)
}

/// <p>The namespace's credentials, one row per credential, at most <var>pMax</var> when it is above zero (Story 24.15):
/// <method>CredentialRow</method>'s fields, in name order. Nothing is written and no password is read.</p>
ClassMethod ListCredentials(pNamespace As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..CredentialLinesHere($Select(pMax > 0: pMax, 1: ..#SQLMAX), .tFound)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the credential list failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..CredentialRow(tFound(tI)))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The facts about the credential <var>pName</var>, read in the current namespace, which the caller has already switched, and kept in
/// <var>pFacts</var>: <code>exists</code> (held under exactly that name), <code>folded</code> (how many credentials hold that name in any letter
/// case) and, when it exists, <code>line</code> (<method>CredentialLine</method>). A name the vendor cannot store is not held. Nothing is
/// written.</p>
ClassMethod CredentialFactsHere(pName As %String, ByRef pFacts) [ Private ]
{
    Kill pFacts
    Set pFacts("exists") = 0
    Set pFacts("folded") = 0
    Set pFacts("line") = ""
    If '..CredentialNameOK(pName) Quit
    Set pFacts("exists") = ''##class(Ens.Config.Credentials).%ExistsId(pName)
    Set tStatement = ##class(%SQL.Statement).%New()
    Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(.tStatement, "SELECT COUNT(*) FROM Ens_Config.Credentials WHERE LOWER(SystemName) = ?", $ZConvert(pName, "L"))
    If '$IsObject(tResult) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the statement answered no result"))
    If tResult.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLCode, tResult.%SQLCODE, tResult.%Message))
    If tResult.%Next() Set pFacts("folded") = +tResult.%GetData(1)
    Set tResult = ""
    If 'pFacts("exists") Quit
    Set tObject = ##class(Ens.Config.Credentials).%OpenId(pName)
    If $IsObject(tObject) {
        Set pFacts("line") = ..CredentialLine(pName, tObject.Username, tObject.BusinessPartner)
    } Else {
        Set pFacts("exists") = 0
    }
    Set tObject = ""
}

/// <p><method>CredentialFactsHere</method> in <var>pNamespace</var>; a fault is <var>pCaught</var>, with the namespace restored.</p>
ClassMethod CredentialFacts(pNamespace As %String, pName As %String, Output pFacts, Output pCaught) [ Private ]
{
    Kill pFacts
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..CredentialFactsHere(pName, .pFacts)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>An edit's body <var>pBody</var> without the user name or business partner the credential <var>pName</var> in <var>pNamespace</var> already
/// holds, so the edit's rules judge only what it changes: a partner removed since it was set, or one stored as free text elsewhere, does not
/// refuse an edit of the user name (Story 24.15). A credential that cannot be read leaves the body whole; the write then answers for it.</p>
ClassMethod CredentialMoves(pNamespace As %String, pName As %String, pBody As %DynamicObject) As %DynamicObject [ Private ]
{
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit pBody
    Do ..CredentialFacts(pNamespace, pName, .tFacts, .tCaught)
    If $IsObject(tCaught) || ($Get(tFacts("line")) = "") Quit pBody
    Set tMoves = ##class(%DynamicAbstractObject).%FromJSON(pBody.%ToJSON())
    If (tMoves.%GetTypeOf("Username") = "string") && (tMoves.%Get("Username") = $List(tFacts("line"), 2)) Do tMoves.%Remove("Username")
    If (tMoves.%GetTypeOf("BusinessPartner") = "string") && (tMoves.%Get("BusinessPartner") = $List(tFacts("line"), 3)) Do tMoves.%Remove("BusinessPartner")
    Quit tMoves
}

/// <p>Whether <var>pNamespace</var> holds a business partner named exactly <var>pPartner</var>. A failed read answers 0, so a partner the
/// instance cannot confirm is refused, never accepted (Story 24.15).</p>
ClassMethod CredentialPartnerHeld(pNamespace As %String, pPartner As %String) As %Boolean
{
    Set tHeld = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tHeld = ''##class(Ens.Config.BusinessPartner).%ExistsId(pPartner)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tHeld = 0
    }
    Quit tHeld
}

/// <p>Whether the vendor accepts <var>pUsername</var> as a credential's user name, in <var>pNamespace</var>: the vendor's own datatype check of the
/// property judges the value, and nothing is created or saved. The vendor's text is logged and never shown (Story 24.15).</p>
ClassMethod CredentialAccepts(pNamespace As %String, pUsername As %String) As %Boolean
{
    Set tVendorSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tVendorSC = ##class(Ens.Config.Credentials).UsernameIsValid(pUsername)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tVendorSC = ex.AsStatus()
    }
    If $$$ISERR(tVendorSC) Do ..LogFault("a credential user name did not pass the vendor's validation", tVendorSC)
    Quit $$$ISOK(tVendorSC)
}

/// <p>The 422 violations of a credential's name and fields, in <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field, code)</code>
/// with the count in <code>pViolations</code> (Story 24.15): a name <method>CredentialNameOK</method> refuses is <code>NAME</code> (judged only when
/// <var>pJudgeName</var>, which an add passes); a field that is not a string is <code>PORT.FIELD.SHAPE</code>; a user name past
/// <parameter>CREDENTIALUSERMAX</parameter> is <code>VALUE</code>; and, with <var>pJudgeValue</var> and nothing else wrong, a business partner
/// the namespace does not hold is <code>PARTNER</code> and a user name the vendor refuses is <code>VALUE</code>. A caller that has not yet passed
/// the port's gate passes <var>pJudgeValue</var> 0, so no vendor call runs before it. <var>pFields</var> is the body: <code>Username</code>,
/// <code>BusinessPartner</code> and <code>Password</code> strings.</p>
ClassMethod CredentialViolations(pNamespace As %String, pName As %String, pFields As %DynamicObject, Output pViolations, pJudgeName As %Boolean = 1, pJudgeValue As %Boolean = 1) As %Status
{
    Kill pViolations
    Set pViolations = 0
    If pJudgeName && '..CredentialNameOK(pName) Set pViolations($Increment(pViolations)) = $ListBuild("Name", ##class(OcuPilot.Api.InteropError).#CREDENTIALNAME)
    If '$IsObject(pFields) || 'pFields.%IsA("%Library.DynamicObject") Set pFields = {}
    For tField = "Username", "BusinessPartner", "Password" {
        Set tType = pFields.%GetTypeOf(tField)
        If (tType '= "string") && (tType '= "unassigned") Set pViolations($Increment(pViolations)) = $ListBuild(tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
    }
    If (pFields.%GetTypeOf("Username") = "string") && ($Length(pFields.%Get("Username")) > ..#CREDENTIALUSERMAX) Set pViolations($Increment(pViolations)) = $ListBuild("Username", ##class(OcuPilot.Api.InteropError).#CREDENTIALVALUE)
    If pViolations || 'pJudgeValue Quit $$$OK
    If (pFields.%GetTypeOf("BusinessPartner") = "string") && (pFields.%Get("BusinessPartner") '= "") && '..CredentialPartnerHeld(pNamespace, pFields.%Get("BusinessPartner")) {
        Set pViolations($Increment(pViolations)) = $ListBuild("BusinessPartner", ##class(OcuPilot.Api.InteropError).#CREDENTIALPARTNER)
    }
    If (pFields.%GetTypeOf("Username") = "string") && '..CredentialAccepts(pNamespace, pFields.%Get("Username")) {
        Set pViolations($Increment(pViolations)) = $ListBuild("Username", ##class(OcuPilot.Api.InteropError).#CREDENTIALVALUE)
    }
    Quit $$$OK
}

/// <p>The decision a credential write <var>pType</var> is refused with, as the last segment of its code (<code>TAKEN</code>) or
/// <code>ABSENT</code> for a target that is not there, else <code>""</code> (Story 24.15): an add of a name the namespace holds in any letter case is
/// <code>TAKEN</code> (the vendor's adapters resolve a name ignoring case); any other write of a name it does not hold exactly is <code>ABSENT</code>.
/// <var>pExists</var> is whether the credential is held under exactly that name and <var>pFolded</var> how many hold it in any letter case. Pure.</p>
ClassMethod CredentialWriteToken(pType As %String, pExists As %Boolean, pFolded As %Integer) As %String
{
    If pType = ..#TYPEADDCREDENTIAL Quit $Select(pExists || (pFolded > 0): "TAKEN", 1: "")
    Quit $Select(pExists: "", 1: "ABSENT")
}

/// <p>One credential, fresh (Story 24.15): <method>CredentialRow</method>'s fields and <code>Namespace</code>. A credential not held under exactly
/// that name, or a name the vendor cannot store, is 404 <code>PORT.NOTFOUND</code>, unlogged. With <var>pAction</var> an add (AD-54, which inverts the
/// read) is <code>TAKEN</code> when the name is held in any letter case and otherwise the 404 a create expects.</p>
ClassMethod ReadCredential(pNamespace As %String, pName As %String, pAction As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    If '..CredentialNameOK(pName) Quit ..Absent(.pHttpStatus, .pFault)
    Do ..CredentialFacts(pNamespace, pName, .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the credential read failed", .pHttpStatus, .pFault)
    If pAction = ..#TYPEADDCREDENTIAL {
        If ..CredentialWriteToken(pAction, tFacts("exists"), tFacts("folded")) '= "" Quit ..Conflict(##class(OcuPilot.Api.InteropError).#CREDENTIALTAKEN, .pHttpStatus, .pFault)
        Quit ..Absent(.pHttpStatus, .pFault)
    }
    If 'tFacts("exists") Quit ..Absent(.pHttpStatus, .pFault)
    Set pRow = ..CredentialRow(tFacts("line"), pNamespace)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Serve the Credentials endpoint's <code>LIST</code> and typed types after <method>Invoke</method>'s gate (Story 24.15): the
/// <code>CREDENTIAL</code> read and the four writes, the credential named under <parameter>IDKEY</parameter> by its name, kept exactly (AD-13). An
/// <parameter>ACTIONKEY</parameter> names the write the read is composed for.</p>
ClassMethod InvokeCredential(pNamespace As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType = ..#TYPELIST {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..ListCredentials(pNamespace, +tMaxText, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tName = $Get(pQuery(..#IDKEY))
        If tName = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONIDREQUIRED, .pHttpStatus, .pFault)
            Quit
        }
        Set tAction = $Select(..IsCredentialWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && '..IsCredentialWrite(tAction) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If ..IsCredentialWrite(pType) {
            Set tSC = ..PerformCredential(pNamespace, pType, tName, pBody, .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..ReadCredential(pNamespace, tName, tAction, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the credential call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Run credential write <var>pType</var> on the credential <var>pName</var> in <var>pNamespace</var> and answer what it leaves (Story 24.15).
/// The sequence:</p>
/// <ol>
/// <li>An add's or edit's fields are judged by <method>CredentialViolations</method> (422), and a password write needs a non-empty
/// <code>Password</code> string; a name the vendor cannot store is 404 for any write but an add.</li>
/// <li>In the namespace the credential is read again and judged by <method>CredentialWriteToken</method>, so a state that moved since the review is
/// refused by its own code with no vendor call; then the vendor's <code>%Save</code> of a new credential (its password, when one is sent, set through
/// the vendor's own <code>PasswordSet</code>), <code>%Save</code> of the opened credential (concurrency 4, the reference dropped right after) with
/// each field that differs or its new password, or <code>%DeleteId</code>, which removes the password with it. An edit that moves no field calls
/// nothing. A credential another process holds locked is 503.</li>
/// <li>The namespace is restored, then OcuPilot's own audit row is recorded (<method>AuditRuntime</method>), because the vendor records none. It
/// carries the namespace and the names of the fields written, never a value.</li>
/// </ol>
/// <p>The password is passed to the vendor and nowhere else: it is in no row, no audit payload, no log line and no refusal text. The answer is the
/// credential's row read again (<method>ReadCredential</method>); after a remove <code>{Name, Namespace}</code>.</p>
ClassMethod PerformCredential(pNamespace As %String, pType As %String, pName As %String, pBody As %DynamicAbstractObject, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Set pBody = {}
    Set tPasswordType = pBody.%GetTypeOf("Password")
    Set tPassword = $Select(tPasswordType = "string": pBody.%Get("Password"), 1: "")
    If pType = ..#TYPEREMOVECREDENTIAL {
        If '..CredentialNameOK(pName) Quit ..Absent(.pHttpStatus, .pFault)
    } ElseIf pType = ..#TYPEPASSWORDCREDENTIAL {
        If '..CredentialNameOK(pName) Quit ..Absent(.pHttpStatus, .pFault)
        If tPassword = "" {
            Set tViolations(1) = $ListBuild("Password", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
            Set tViolations = 1
            Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
        }
    } Else {
        If (pType = ..#TYPESETCREDENTIAL) && '..CredentialNameOK(pName) Quit ..Absent(.pHttpStatus, .pFault)
        Set tJudged = $Select(pType = ..#TYPESETCREDENTIAL: ..CredentialMoves(pNamespace, pName, pBody), 1: pBody)
        Set tSC = ..CredentialViolations(pNamespace, pName, tJudged, .tViolations, (pType = ..#TYPEADDCREDENTIAL))
        If $$$ISERR(tSC) Quit tSC
        If tViolations Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    }
    Set tToken = ""
    Set tCaught = ""
    Set tVendorSC = $$$OK
    Set tBusy = 0
    Set tChanged = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..CredentialFactsHere(pName, .tFacts)
        Set tToken = ..CredentialWriteToken(pType, tFacts("exists"), tFacts("folded"))
        If tToken = "" {
            If pType = ..#TYPEADDCREDENTIAL {
                Set tObject = ##class(Ens.Config.Credentials).%New()
                Set tObject.SystemName = pName
                If pBody.%GetTypeOf("Username") = "string" Set tObject.Username = pBody.%Get("Username")
                If pBody.%GetTypeOf("BusinessPartner") = "string" Set tObject.BusinessPartner = pBody.%Get("BusinessPartner")
                If tPassword '= "" Set tVendorSC = tObject.PasswordSet(tPassword)
                If $$$ISOK(tVendorSC) Set tVendorSC = tObject.%Save()
            } ElseIf pType = ..#TYPEREMOVECREDENTIAL {
                Set tVendorSC = ##class(Ens.Config.Credentials).%DeleteId(pName)
            } Else {
                Set tObject = ##class(Ens.Config.Credentials).%OpenId(pName, 4)
                If '$IsObject(tObject) {
                    Set tBusy = 1
                } ElseIf pType = ..#TYPEPASSWORDCREDENTIAL {
                    Set tVendorSC = tObject.PasswordSet(tPassword)
                    If $$$ISOK(tVendorSC) Set tVendorSC = tObject.%Save()
                } Else {
                    Set tHeld = ..CredentialLine(pName, tObject.Username, tObject.BusinessPartner)
                    If (pBody.%GetTypeOf("Username") = "string") && (pBody.%Get("Username") '= $List(tHeld, 2)) {
                        Set tObject.Username = pBody.%Get("Username")
                        Set tChanged = tChanged _ $ListBuild("Username")
                    }
                    If (pBody.%GetTypeOf("BusinessPartner") = "string") && (pBody.%Get("BusinessPartner") '= $List(tHeld, 3)) {
                        Set tObject.BusinessPartner = pBody.%Get("BusinessPartner")
                        Set tChanged = tChanged _ $ListBuild("BusinessPartner")
                    }
                    If tChanged '= "" Set tVendorSC = tObject.%Save()
                }
            }
        }
        ; The credential's lock is released in the namespace it was taken in.
        Set tObject = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Try {
            Set $NAMESPACE = pNamespace
        } Catch {
        }
        Set tObject = ""
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the credential write failed", .pHttpStatus, .pFault)
    If tBusy Quit ..Unavailable(.pHttpStatus, .pFault)
    If tToken = "ABSENT" Quit ..Absent(.pHttpStatus, .pFault)
    If tToken '= "" Quit ..Conflict(..#CREDENTIALCODEPREFIX _ tToken, .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the credential write failed", .pHttpStatus, .pFault)
    If (pType '= ..#TYPESETCREDENTIAL) || (tChanged '= "") {
        If pType = ..#TYPEADDCREDENTIAL {
            For tField = "Username", "BusinessPartner" {
                If (pBody.%GetTypeOf(tField) = "string") && (pBody.%Get(tField) '= "") Set tChanged = tChanged _ $ListBuild(tField)
            }
            If tPassword '= "" Set tChanged = tChanged _ $ListBuild("Password")
        } ElseIf pType = ..#TYPEPASSWORDCREDENTIAL {
            Set tChanged = $ListBuild("Password")
        }
        Set tEffects = {}
        Do tEffects.%Set("namespace", pNamespace, "string")
        If pType '= ..#TYPEREMOVECREDENTIAL Do tEffects.%Set("fields", $ListToString(tChanged, ","), "string")
        Do ..AuditRuntime($Case(pType, ..#TYPEADDCREDENTIAL: ..#VERBADD, ..#TYPEREMOVECREDENTIAL: ..#VERBREMOVE, : ..#VERBSET), ..#ENTITYCREDENTIAL, pName, tEffects)
    }
    If pType = ..#TYPEREMOVECREDENTIAL {
        Set pResult = {}
        Do pResult.%Set("Name", pName, "string")
        Do pResult.%Set("Namespace", pNamespace, "string")
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Set tReadSC = ..ReadCredential(pNamespace, pName, "", .tRow, .tReadHttp, .tReadFault)
    If $$$ISERR(tReadSC) {
        Set tRow = {}
        Do tRow.%Set("Name", pName, "string")
        Do tRow.%Set("Namespace", pNamespace, "string")
    }
    Set pResult = tRow
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>The two lines that open a create's script for a name compared ignoring letter case (AD-59): <code>tHeld</code> counts the rows of the SQL
/// table <var>pTable</var> whose column <var>pColumn</var> equals the name <var>pName</var> in any letter case, the port's own taken-name rule, and
/// is 1 when the count cannot be read; <code>tSC</code> is the refusal's sentence <var>pReason</var>, which only the create's own save replaces. Each
/// step after them is gated on <code>'tHeld</code> on its own line.</p>
ClassMethod FoldedFreeLines(pTable As %String, pColumn As %String, pName As %String, pReason As %String) As %String [ Private ]
{
    Set tNL = $Char(10)
    Set tCount = ..Literal("SELECT COUNT(*) FROM " _ pTable _ " WHERE LOWER(" _ pColumn _ ") = ?")
    Set tText = tNL _ " Set tRS = ##class(%SQL.Statement).%ExecDirect(, " _ tCount _ ", $ZConvert(" _ ..Literal(pName) _ ", ""L"")), tHeld = $Select(tRS.%Next(): ''tRS.%GetData(1), 1: 1), tRS = """""
    Quit tText _ tNL _ " Set tSC = $System.Status.Error(5001, " _ ..Literal(pReason) _ ")"
}

/// <p>The lines <method>Snippet</method> adds for the credential write <var>pType</var> of the credential named <var>pName</var> (Story 24.15): the
/// vendor's <code>%Save</code> of a new credential, each step gated on a free name in any letter case (<method>FoldedFreeLines</method>), of the
/// credential opened at concurrency 4 with the fields <var>pBody</var> carries, or <code>%DeleteId</code>. Names and values are string literals; a
/// password is never rendered as sent: its line takes the placeholder <code>&lt;Password&gt;</code> where the body carries one (AD-35, AD-59).</p>
ClassMethod CredentialSnippet(pType As %String, pName As %String, pBody As %DynamicAbstractObject) As %String [ Private ]
{
    Set tNL = $Char(10)
    Set tName = ..Literal(pName)
    If pType = ..#TYPEREMOVECREDENTIAL Quit tNL _ " Set tSC = ##class(Ens.Config.Credentials).%DeleteId(" _ tName _ ")"
    Set tGate = ""
    If pType = ..#TYPEADDCREDENTIAL {
        Set tGate = "If 'tHeld "
        Set tText = ..FoldedFreeLines("Ens_Config.Credentials", "SystemName", pName, ##class(OcuPilot.Api.InteropError).#REASONCREDENTIALTAKEN)
        Set tText = tText _ tNL _ " " _ tGate _ "Set tCredential = ##class(Ens.Config.Credentials).%New(), tCredential.SystemName = " _ tName
    } Else {
        Set tText = tNL _ " Set tCredential = ##class(Ens.Config.Credentials).%OpenId(" _ tName _ ", 4)"
    }
    If pType '= ..#TYPEPASSWORDCREDENTIAL {
        For tField = "Username", "BusinessPartner" {
            Set tSupplied = $IsObject(pBody) && (pBody.%GetTypeOf(tField) = "string")
            If tSupplied || (pType = ..#TYPEADDCREDENTIAL) Set tText = tText _ tNL _ " " _ tGate _ "Set tCredential." _ tField _ " = " _ ..Literal($Select(tSupplied: pBody.%Get(tField), 1: ""))
        }
    }
    If (pType = ..#TYPEPASSWORDCREDENTIAL) || ((pType = ..#TYPEADDCREDENTIAL) && $IsObject(pBody) && (pBody.%GetTypeOf("Password") = "string")) {
        Set tText = tText _ tNL _ " " _ tGate _ "Set tSC = tCredential.PasswordSet(""<Password>"")"
    }
    Quit tText _ tNL _ " " _ tGate _ "Set tSC = tCredential.%Save()" _ tNL _ " Set tCredential = """""
}

/// <p>The statement the schedule spec list reads: every schedule spec's name, description, spec and deployable flag, in name order (Story 24.15).</p>
Parameter SCHEDULESQL = "SELECT TOP ? Name, Description, ScheduleSpec, Deployable FROM Ens_Util.Schedule ORDER BY Name";

/// <p>Whether <var>pName</var> is a name this port writes for a schedule spec (Story 24.15): 1 to <parameter>SCHEDULENAMEMAX</parameter>
/// characters with no control character. Pure.</p>
ClassMethod ScheduleNameOK(pName As %String) As %Boolean
{
    Quit (pName '= "") && ($Length(pName) <= ..#SCHEDULENAMEMAX) && ($ZStrip(pName, "*C") = pName)
}

/// <p>The schedule spec as the four values <parameter>SCHEDULEFIELDS</parameter> names, in that order, the last 1 or 0. Pure.</p>
ClassMethod ScheduleLine(pName As %String, pDescription As %String, pSpec As %String, pDeployable As %Boolean) As %List [ Private ]
{
    If pDescription = $Char(0) Set pDescription = ""
    If pSpec = $Char(0) Set pSpec = ""
    Quit $ListBuild(pName, pDescription, pSpec, ''pDeployable)
}

/// <p>The row a schedule spec list and read answer, from the four values <var>pLine</var> (<method>ScheduleLine</method>):
/// <code>{Name, Description, ScheduleSpec, Deployable}</code>, and with <var>pNamespace</var> <code>Namespace</code> too. The spec is text and is
/// never run.</p>
ClassMethod ScheduleRow(pLine As %List, pNamespace As %String = "") As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Name", $List(pLine, 1) _ "", "string")
    Do tRow.%Set("Description", $List(pLine, 2) _ "", "string")
    Do tRow.%Set("ScheduleSpec", $List(pLine, 3) _ "", "string")
    Do tRow.%Set("Deployable", ''$List(pLine, 4), "boolean")
    If pNamespace '= "" Do tRow.%Set("Namespace", pNamespace, "string")
    Quit tRow
}

/// <p>The namespace's schedule specs, one row per schedule spec, at most <var>pMax</var> when it is above zero (Story 24.15):
/// <method>ScheduleRow</method>'s fields, in name order. Read with <code>%ExecDirectNoPriv</code> after the gate (<method>SqlRows</method>);
/// nothing is written.</p>
ClassMethod ListSchedules(pNamespace As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..SqlRows(pNamespace, ..#SCHEDULESQL, .tFound, .tCaught, $Select(pMax > 0: pMax, 1: ..#SQLMAX))
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the schedule spec list failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Set tLine = tFound(tI)
        Do pRows.%Push(..ScheduleRow(..ScheduleLine($List(tLine, 1), $List(tLine, 2), $List(tLine, 3), $List(tLine, 4))))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The facts about the schedule spec <var>pName</var>, read in the current namespace, which the caller has already switched, and kept in
/// <var>pFacts</var>: <code>exists</code> (held under exactly that name), <code>folded</code> (how many schedule specs hold that name in any letter
/// case) and, when it exists, <code>line</code> (<method>ScheduleLine</method>). A name this port does not write is not held. Nothing is
/// written.</p>
ClassMethod ScheduleFactsHere(pName As %String, ByRef pFacts) [ Private ]
{
    Kill pFacts
    Set pFacts("exists") = 0
    Set pFacts("folded") = 0
    Set pFacts("line") = ""
    If '..ScheduleNameOK(pName) Quit
    Set pFacts("exists") = ''##class(Ens.Util.Schedule).%ExistsId(pName)
    Set tStatement = ##class(%SQL.Statement).%New()
    Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(.tStatement, "SELECT COUNT(*) FROM Ens_Util.Schedule WHERE LOWER(Name) = ?", $ZConvert(pName, "L"))
    If '$IsObject(tResult) Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the statement answered no result"))
    If tResult.%SQLCODE < 0 Throw ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$SQLCode, tResult.%SQLCODE, tResult.%Message))
    If tResult.%Next() Set pFacts("folded") = +tResult.%GetData(1)
    Set tResult = ""
    If 'pFacts("exists") Quit
    Set tObject = ##class(Ens.Util.Schedule).%OpenId(pName)
    If $IsObject(tObject) {
        Set pFacts("line") = ..ScheduleLine(pName, tObject.Description, tObject.ScheduleSpec, tObject.Deployable)
    } Else {
        Set pFacts("exists") = 0
    }
    Set tObject = ""
}

/// <p><method>ScheduleFactsHere</method> in <var>pNamespace</var>; a fault is <var>pCaught</var>, with the namespace restored.</p>
ClassMethod ScheduleFacts(pNamespace As %String, pName As %String, Output pFacts, Output pCaught) [ Private ]
{
    Kill pFacts
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..ScheduleFactsHere(pName, .pFacts)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>The vendor's status <var>pStatus</var> without any text it carries: an error status naming only the vendor's error codes, which is what
/// reaches the log, because the vendor's text echoes the spec, the name or the description (Story 24.15). A lock the vendor could not take and a
/// privilege refusal are kept as they came, so <method>Statused</method> still answers them as they are answered everywhere. Pure.</p>
ClassMethod ScheduleVendorStatus(pStatus As %Status) As %Status
{
    If ..HasCode(pStatus, ..#CODERUNTIMELOCK) || ..HasCode(pStatus, ..#CODEPRIVILEGE) Quit pStatus
    Set tCodes = ""
    Set tProtect = 0
    Try {
        Set tCodes = $System.Status.GetErrorCodes(pStatus)
        Set tProtect = ($System.Status.GetErrorText(pStatus) [ "<PROTECT>")
    } Catch {
        Set tCodes = ""
    }
    If tProtect Quit pStatus
    Quit $$$ERROR($$$GeneralError, "the vendor refused the schedule spec write with error code " _ tCodes)
}

/// <p>Whether the vendor accepts <var>pSpec</var> as a schedule spec (Story 24.15): the vendor's own <code>ValidateScheduleSpec</code>, the
/// check the classic page makes, which is pure and writes nothing; <code>ParseScheduleSpec</code> is never called, because it logs a bad spec. The
/// empty spec is refused, since the vendor reads one as always on. The vendor's segment errors echo the spec, so only their error codes reach the
/// log, and the spec reaches no line (<method>ScheduleVendorStatus</method>).</p>
ClassMethod ScheduleSpecAccepted(pSpec As %String) As %Boolean
{
    If pSpec = "" Quit 0
    Set tVendorSC = $$$OK
    Try {
        Set tSpec = pSpec
        Kill tErrors
        Set tVendorSC = $ClassMethod("Ens.ScheduleHandler", ..#SCHEDULEVALIDATOR, .tSpec, .tErrors, .tLength)
    } Catch ex {
        Set tVendorSC = ex.AsStatus()
    }
    If $$$ISERR(tVendorSC) Do ..LogFault("a schedule spec did not pass the vendor's validation", ..ScheduleVendorStatus(tVendorSC))
    Quit $$$ISOK(tVendorSC)
}

/// <p>The 422 violations of a schedule spec's name and fields, in <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field, code)</code>
/// with the count in <code>pViolations</code> (Story 24.15): a name <method>ScheduleNameOK</method> refuses is <code>NAME</code> (judged only when
/// <var>pJudgeName</var>, which an add passes); a field of the wrong type is <code>PORT.FIELD.SHAPE</code>; a description past
/// <parameter>SCHEDULEDESCRIPTIONMAX</parameter> characters is <code>DESCRIPTION</code>; and, with <var>pJudgeSpec</var> and nothing else wrong, a
/// spec the vendor refuses is <code>SPEC</code>. An add with no spec (<var>pRequireSpec</var>) is <code>SPEC</code> too. A caller that has not yet
/// passed the port's gate passes <var>pJudgeSpec</var> 0, so no vendor call runs before it. <var>pFields</var> is the body: <code>ScheduleSpec</code>
/// and <code>Description</code> strings and <code>Deployable</code> a boolean.</p>
ClassMethod ScheduleViolations(pName As %String, pFields As %DynamicObject, Output pViolations, pJudgeName As %Boolean = 1, pJudgeSpec As %Boolean = 1, pRequireSpec As %Boolean = 0) As %Status
{
    Kill pViolations
    Set pViolations = 0
    If pJudgeName && '..ScheduleNameOK(pName) Set pViolations($Increment(pViolations)) = $ListBuild("Name", ##class(OcuPilot.Api.InteropError).#SCHEDULENAME)
    If '$IsObject(pFields) || 'pFields.%IsA("%Library.DynamicObject") Set pFields = {}
    For tField = "ScheduleSpec", "Description" {
        Set tType = pFields.%GetTypeOf(tField)
        If (tType '= "string") && (tType '= "unassigned") Set pViolations($Increment(pViolations)) = $ListBuild(tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
    }
    Set tType = pFields.%GetTypeOf("Deployable")
    If (tType '= "boolean") && (tType '= "unassigned") Set pViolations($Increment(pViolations)) = $ListBuild("Deployable", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
    If (pFields.%GetTypeOf("Description") = "string") && ($Length(pFields.%Get("Description")) > ..#SCHEDULEDESCRIPTIONMAX) Set pViolations($Increment(pViolations)) = $ListBuild("Description", ##class(OcuPilot.Api.InteropError).#SCHEDULEDESCRIPTION)
    If pViolations || 'pJudgeSpec Quit $$$OK
    Set tSpecType = pFields.%GetTypeOf("ScheduleSpec")
    If ((tSpecType = "string") || pRequireSpec) && '..ScheduleSpecAccepted($Select(tSpecType = "string": pFields.%Get("ScheduleSpec"), 1: "")) {
        Set pViolations($Increment(pViolations)) = $ListBuild("ScheduleSpec", ##class(OcuPilot.Api.InteropError).#SCHEDULESPEC)
    }
    Quit $$$OK
}

/// <p>The decision a schedule spec write <var>pType</var> is refused with, as the last segment of its code (<code>TAKEN</code>) or
/// <code>ABSENT</code> for a target that is not there, else <code>""</code> (Story 24.15): an add of a name the namespace holds in any letter case is
/// <code>TAKEN</code> (the vendor notifies a running production by a name compared ignoring case); any other write of a name it does not hold
/// exactly is <code>ABSENT</code>. <var>pExists</var> is whether the schedule spec is held under exactly that name and <var>pFolded</var> how many
/// hold it in any letter case. Pure.</p>
ClassMethod ScheduleWriteToken(pType As %String, pExists As %Boolean, pFolded As %Integer) As %String
{
    If pType = ..#TYPEADDSCHEDULE Quit $Select(pExists || (pFolded > 0): "TAKEN", 1: "")
    Quit $Select(pExists: "", 1: "ABSENT")
}

/// <p>409 <code>INTEROP.SCHEDULE.SOURCECONTROL</code> when <var>pNamespace</var> is under source control, which refuses every schedule spec write,
/// else <code>$$$OK</code> (Story 24.15).</p>
ClassMethod ScheduleWriteRefusal(pNamespace As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    If ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#SCHEDULESOURCECONTROL, .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>One schedule spec, fresh (Story 24.15): <method>ScheduleRow</method>'s fields and <code>Namespace</code>. A schedule spec not held under exactly
/// that name, or a name this port does not write, is 404 <code>PORT.NOTFOUND</code>, unlogged. With <var>pAction</var> it refuses what that write
/// would be refused (<method>ScheduleWriteRefusal</method>); then an add (AD-54, which inverts the read) is <code>TAKEN</code> when the name is held
/// in any letter case and otherwise the 404 a create expects.</p>
ClassMethod ReadSchedule(pNamespace As %String, pName As %String, pAction As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    If '..ScheduleNameOK(pName) Quit ..Absent(.pHttpStatus, .pFault)
    If pAction '= "" {
        Set tSC = ..ScheduleWriteRefusal(pNamespace, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
    }
    Do ..ScheduleFacts(pNamespace, pName, .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the schedule spec read failed", .pHttpStatus, .pFault)
    If pAction = ..#TYPEADDSCHEDULE {
        If ..ScheduleWriteToken(pAction, tFacts("exists"), tFacts("folded")) '= "" Quit ..Conflict(##class(OcuPilot.Api.InteropError).#SCHEDULETAKEN, .pHttpStatus, .pFault)
        Quit ..Absent(.pHttpStatus, .pFault)
    }
    If 'tFacts("exists") Quit ..Absent(.pHttpStatus, .pFault)
    Set pRow = ..ScheduleRow(tFacts("line"), pNamespace)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Serve the Schedules endpoint's <code>LIST</code> and typed types after <method>Invoke</method>'s gate (Story 24.15): the
/// <code>SCHEDULE</code> read and the three writes, the schedule spec named under <parameter>IDKEY</parameter> by its name, kept exactly (AD-13).
/// An <parameter>ACTIONKEY</parameter> names the write the read is composed for.</p>
ClassMethod InvokeSchedule(pNamespace As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType = ..#TYPELIST {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..ListSchedules(pNamespace, +tMaxText, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tName = $Get(pQuery(..#IDKEY))
        If tName = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONIDREQUIRED, .pHttpStatus, .pFault)
            Quit
        }
        Set tAction = $Select(..IsScheduleWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && '..IsScheduleWrite(tAction) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If ..IsScheduleWrite(pType) {
            Set tSC = ..PerformSchedule(pNamespace, pType, tName, pBody, .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..ReadSchedule(pNamespace, tName, tAction, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the schedule spec call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Run schedule spec write <var>pType</var> on the schedule spec <var>pName</var> in <var>pNamespace</var> and answer what it leaves (Story 24.15).
/// The sequence:</p>
/// <ol>
/// <li>A namespace under source control refuses every write (<method>ScheduleWriteRefusal</method>), before anything is judged or read.</li>
/// <li>An add's or edit's fields are judged by <method>ScheduleViolations</method> (422); a name this port does not write is 404 for any write
/// but an add.</li>
/// <li>In the namespace the schedule spec is read again and judged by <method>ScheduleWriteToken</method>, so a state that moved since the review is
/// refused by its own code with no vendor call; then the vendor's <code>%Save</code> of a new schedule spec, <code>%Save</code> of the opened
/// schedule spec (concurrency 4, the reference dropped right after) with each field that differs, or <code>%DeleteId</code>. An edit that moves no
/// field calls nothing. A schedule spec another process holds locked is 503.</li>
/// <li>The namespace is restored, then OcuPilot's own audit row is recorded (<method>AuditRuntime</method>), because the vendor records none. It
/// carries the namespace and the names of the fields written, never a value.</li>
/// </ol>
/// <p>The vendor notifies a running production of an edit that changes the spec, in the confirming request; nothing is started, stopped or updated
/// here. A vendor refusal reaches the log as its error codes alone (<method>ScheduleVendorStatus</method>). The answer is the schedule spec's row read
/// again (<method>ReadSchedule</method>); after a remove <code>{Name, Namespace}</code>.</p>
ClassMethod PerformSchedule(pNamespace As %String, pType As %String, pName As %String, pBody As %DynamicAbstractObject, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..ScheduleWriteRefusal(pNamespace, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Set pBody = {}
    If pType = ..#TYPEREMOVESCHEDULE {
        If '..ScheduleNameOK(pName) Quit ..Absent(.pHttpStatus, .pFault)
    } Else {
        If (pType = ..#TYPESETSCHEDULE) && '..ScheduleNameOK(pName) Quit ..Absent(.pHttpStatus, .pFault)
        Set tSC = ..ScheduleViolations(pName, pBody, .tViolations, (pType = ..#TYPEADDSCHEDULE), 1, (pType = ..#TYPEADDSCHEDULE))
        If $$$ISERR(tSC) Quit tSC
        If tViolations Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    }
    Set tToken = ""
    Set tCaught = ""
    Set tVendorSC = $$$OK
    Set tBusy = 0
    Set tChanged = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..ScheduleFactsHere(pName, .tFacts)
        Set tToken = ..ScheduleWriteToken(pType, tFacts("exists"), tFacts("folded"))
        If tToken = "" {
            If pType = ..#TYPEADDSCHEDULE {
                Set tObject = ##class(Ens.Util.Schedule).%New()
                Set tObject.Name = pName
                If pBody.%GetTypeOf("ScheduleSpec") = "string" Set tObject.ScheduleSpec = pBody.%Get("ScheduleSpec")
                If pBody.%GetTypeOf("Description") = "string" Set tObject.Description = pBody.%Get("Description")
                If pBody.%GetTypeOf("Deployable") = "boolean" Set tObject.Deployable = pBody.%Get("Deployable")
                Set tVendorSC = tObject.%Save()
            } ElseIf pType = ..#TYPEREMOVESCHEDULE {
                Set tVendorSC = ##class(Ens.Util.Schedule).%DeleteId(pName)
            } Else {
                Set tObject = ##class(Ens.Util.Schedule).%OpenId(pName, 4)
                If '$IsObject(tObject) {
                    Set tBusy = 1
                } Else {
                    Set tHeld = ..ScheduleLine(pName, tObject.Description, tObject.ScheduleSpec, tObject.Deployable)
                    If (pBody.%GetTypeOf("ScheduleSpec") = "string") && (pBody.%Get("ScheduleSpec") '= $List(tHeld, 3)) {
                        Set tObject.ScheduleSpec = pBody.%Get("ScheduleSpec")
                        Set tChanged = tChanged _ $ListBuild("ScheduleSpec")
                    }
                    If (pBody.%GetTypeOf("Description") = "string") && (pBody.%Get("Description") '= $List(tHeld, 2)) {
                        Set tObject.Description = pBody.%Get("Description")
                        Set tChanged = tChanged _ $ListBuild("Description")
                    }
                    If (pBody.%GetTypeOf("Deployable") = "boolean") && (''pBody.%Get("Deployable") '= $List(tHeld, 4)) {
                        Set tObject.Deployable = pBody.%Get("Deployable")
                        Set tChanged = tChanged _ $ListBuild("Deployable")
                    }
                    If tChanged '= "" Set tVendorSC = tObject.%Save()
                }
            }
        }
        ; The schedule spec's lock is released in the namespace it was taken in.
        Set tObject = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Try {
            Set $NAMESPACE = pNamespace
        } Catch {
        }
        Set tObject = ""
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the schedule spec write failed", .pHttpStatus, .pFault)
    If tBusy Quit ..Unavailable(.pHttpStatus, .pFault)
    If tToken = "ABSENT" Quit ..Absent(.pHttpStatus, .pFault)
    If tToken '= "" Quit ..Conflict(..#SCHEDULECODEPREFIX _ tToken, .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(..ScheduleVendorStatus(tVendorSC), "the schedule spec write failed", .pHttpStatus, .pFault)
    If (pType '= ..#TYPESETSCHEDULE) || (tChanged '= "") {
        If pType = ..#TYPEADDSCHEDULE {
            Set tChanged = $ListBuild("ScheduleSpec")
            If (pBody.%GetTypeOf("Description") = "string") && (pBody.%Get("Description") '= "") Set tChanged = tChanged _ $ListBuild("Description")
            If (pBody.%GetTypeOf("Deployable") = "boolean") && pBody.%Get("Deployable") Set tChanged = tChanged _ $ListBuild("Deployable")
        }
        Set tEffects = {}
        Do tEffects.%Set("namespace", pNamespace, "string")
        If pType '= ..#TYPEREMOVESCHEDULE Do tEffects.%Set("fields", $ListToString(tChanged, ","), "string")
        Do ..AuditRuntime($Case(pType, ..#TYPEADDSCHEDULE: ..#VERBADD, ..#TYPEREMOVESCHEDULE: ..#VERBREMOVE, : ..#VERBSET), ..#ENTITYSCHEDULE, pName, tEffects)
    }
    If pType = ..#TYPEREMOVESCHEDULE {
        Set pResult = {}
        Do pResult.%Set("Name", pName, "string")
        Do pResult.%Set("Namespace", pNamespace, "string")
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Set tReadSC = ..ReadSchedule(pNamespace, pName, "", .tRow, .tReadHttp, .tReadFault)
    If $$$ISERR(tReadSC) {
        Set tRow = {}
        Do tRow.%Set("Name", pName, "string")
        Do tRow.%Set("Namespace", pNamespace, "string")
    }
    Set pResult = tRow
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>The lines <method>Snippet</method> adds for the schedule spec write <var>pType</var> of the schedule spec named <var>pName</var> (Story 24.15):
/// the vendor's <code>%Save</code> of a new schedule spec, each step gated on a free name in any letter case (<method>FoldedFreeLines</method>), of
/// the schedule spec opened at concurrency 4 with the fields <var>pBody</var> carries, or <code>%DeleteId</code>. Names and values are string
/// literals.</p>
ClassMethod ScheduleSnippet(pType As %String, pName As %String, pBody As %DynamicAbstractObject) As %String [ Private ]
{
    Set tNL = $Char(10)
    Set tName = ..Literal(pName)
    If pType = ..#TYPEREMOVESCHEDULE Quit tNL _ " Set tSC = ##class(Ens.Util.Schedule).%DeleteId(" _ tName _ ")"
    Set tGate = ""
    If pType = ..#TYPEADDSCHEDULE {
        Set tGate = "If 'tHeld "
        Set tText = ..FoldedFreeLines("Ens_Util.Schedule", "Name", pName, ##class(OcuPilot.Api.InteropError).#REASONSCHEDULETAKEN)
        Set tText = tText _ tNL _ " " _ tGate _ "Set tSchedule = ##class(Ens.Util.Schedule).%New(), tSchedule.Name = " _ tName
    } Else {
        Set tText = tNL _ " Set tSchedule = ##class(Ens.Util.Schedule).%OpenId(" _ tName _ ", 4)"
    }
    For tField = "ScheduleSpec", "Description", "Deployable" {
        Set tType = $Select($IsObject(pBody): pBody.%GetTypeOf(tField), 1: "unassigned")
        If tType = "string" {
            Set tText = tText _ tNL _ " " _ tGate _ "Set tSchedule." _ tField _ " = " _ ..Literal(pBody.%Get(tField))
        } ElseIf tType = "boolean" {
            Set tText = tText _ tNL _ " " _ tGate _ "Set tSchedule." _ tField _ " = " _ (''pBody.%Get(tField))
        }
    }
    Quit tText _ tNL _ " " _ tGate _ "Set tSC = tSchedule.%Save()" _ tNL _ " Set tSchedule = """""
}

/// <p>The Purge data settings endpoint (Story 24.16): <code>LIST</code>, one setting (<code>SETTING</code>) and the write <code>SETTINGSET</code>, over
/// the classic pages' own store, <code>^Ens.Configuration("PurgeSettings")</code>. No vendor method writes it, so the port sets the node.</p>
Parameter ENDPOINTPURGESETTINGS = "PurgeSettings";

/// <p>The Purge management data endpoint (Story 24.16): <code>LIST</code> (the six record counts of <code>Ens.Purge.GetAllCounts</code>),
/// <code>PURGESTATE</code> (the settings a purge will use and whether one is running) and the write <code>PURGE</code> (<code>Ens.Purge.PurgeAll</code>).</p>
Parameter ENDPOINTPURGE = "Purge";

/// <p>The pairs the PurgeSettings endpoint requires: the classic Interoperability menu's <code>%Ens_Portal:USE</code> and the resource of
/// <code>EnsPortal.PurgeSettings</code>, which the classic page asks at WRITE to show itself at all.</p>
Parameter PURGESETTINGPAIRS = "%Ens_Portal:USE,%Ens_PurgeSettings:WRITE";

/// <p>The pairs the Purge endpoint requires: <code>%Ens_Portal:USE</code> and the resource of <code>EnsPortal.PurgeAll</code>. No vendor purge asks it
/// (measured), so these, and WRITE on the namespace's globals database for a purge, are the whole gate.</p>
Parameter PURGEPAIRS = "%Ens_Portal:USE,%Ens_Purge:USE";

/// <p>The write of one purge data setting (<code>SETTINGSET</code>, the read is <parameter>TYPESETTING</parameter>) and the purge's read of its state and its write.</p>
Parameter TYPEPURGESETTINGSET = "SETTINGSET";

Parameter TYPEPURGESTATE = "PURGESTATE";

Parameter TYPEPURGE = "PURGE";

/// <p>The query key carrying the days a purge keeps, a whole number from 0 to <parameter>PURGEMAXDAYS</parameter>, judged at the write.</p>
Parameter PURGEDAYSKEY = "days";

Parameter PURGEMAXDAYS As INTEGER = 99999;

/// <p>The longest description a purge setting holds, and the entity types and verb the audit rows of a purge write name.</p>
Parameter PURGETEXTMAX As INTEGER = 2000;

Parameter ENTITYPURGE = "interop-purge";

Parameter ENTITYPURGESETTING = "interop-purge-setting";

Parameter VERBPURGE = "purge";

/// <p>Whether <var>pType</var> is one of the writes the two purge endpoints carry (Story 24.16): the set of one purge setting and the purge itself,
/// each needing WRITE on the namespace's globals database and no routines database.</p>
ClassMethod IsPurgeWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEPURGESETTINGSET) || (pType = ..#TYPEPURGE)
}

/// <p>The four purge data settings, in the classic pages' order, as a <class>%List</class> of <class>%List</class>s:
/// <code>name, node, default, kind</code>. The names are the classic captions; the node is the subscript under
/// <code>^Ens.Configuration("PurgeSettings")</code>, and the default is what the classic page reads for a node that is not stored. Pure.</p>
ClassMethod PurgeSettingRoster() As %List
{
    Quit $ListBuild($ListBuild("Include message bodies", "BodiesToo", 0, "boolean"), $ListBuild("Purge only completed sessions", "KeepIntegrity", 1, "boolean"), $ListBuild("Run bitmap cleanup for namespace", "NamespaceBitmapMaint", 0, "boolean"), $ListBuild("Description", "Desc", "", "text"))
}

/// <p>The roster entry of the setting <var>pName</var>, or <code>""</code> for a name the classic pages have no setting for. Pure.</p>
ClassMethod PurgeSettingEntry(pName As %String) As %List
{
    Set tRoster = ..PurgeSettingRoster()
    Set tFound = ""
    For tI = 1:1:$ListLength(tRoster) {
        If $List($List(tRoster, tI), 1) = pName Set tFound = $List(tRoster, tI)
    }
    Quit tFound
}

/// <p>The limits of the setting <var>pName</var> in <code>ConfigPort.Limits</code>' shape: a boolean is 0 or 1 and the description is text of at most
/// <parameter>PURGETEXTMAX</parameter> characters; <code>""</code> for a name the classic pages have no setting for. Pure. The rules class asks it.</p>
ClassMethod PurgeSettingLimits(pName As %String) As %List
{
    Set tEntry = ..PurgeSettingEntry(pName)
    If tEntry = "" Quit ""
    If $List(tEntry, 4) = "boolean" Quit $ListBuild("boolean", "", "", "", "", "")
    Quit $ListBuild("text", "", "", "", ..#PURGETEXTMAX, "")
}

/// <p>The settings as they stand in the current namespace, which the caller has already switched, in <var>pFound</var>: one
/// <code>$ListBuild(name, value, stored)</code> per roster entry. A node that is not stored reads the classic default; a boolean reads 0 or 1 as the classic
/// page's <code>+$G()</code> does. Nothing is written.</p>
ClassMethod PurgeSettingsHere(Output pFound) [ Private ]
{
    Kill pFound
    Set tRoster = ..PurgeSettingRoster()
    Set pFound = $ListLength(tRoster)
    For tI = 1:1:pFound {
        Set tEntry = $List(tRoster, tI)
        Set tNode = $List(tEntry, 2)
        Set tStored = ($Data(^Ens.Configuration("PurgeSettings", tNode)) # 2)
        Set tValue = $Get(^Ens.Configuration("PurgeSettings", tNode), $List(tEntry, 3))
        If $List(tEntry, 4) = "boolean" Set tValue = $Select(+tValue: 1, 1: 0)
        Set pFound(tI) = $ListBuild($List(tEntry, 1), tValue _ "", tStored)
    }
}

/// <p>The row a purge setting list and read answer, from the setting <var>pName</var>, its <var>pValue</var> and whether it is <var>pStored</var>:
/// <code>{Name, Value, Stored, Kind, Accepts, Namespace}</code>. A description is text and is never run.</p>
ClassMethod PurgeSettingRow(pName As %String, pValue As %String, pStored As %Boolean, pNamespace As %String) As %DynamicObject [ Private ]
{
    Set tLimits = ..PurgeSettingLimits(pName)
    Set tRow = {}
    Do tRow.%Set("Name", pName, "string")
    Do tRow.%Set("Value", pValue, "string")
    Do tRow.%Set("Stored", ''pStored, "boolean")
    Do tRow.%Set("Kind", $ListGet(tLimits, 1), "string")
    Do tRow.%Set("Accepts", ##class(OcuPilot.Port.ConfigPort).AcceptsOf(tLimits), "string")
    Do tRow.%Set("Namespace", pNamespace, "string")
    Quit tRow
}

/// <p>The settings of <var>pNamespace</var> as <method>PurgeSettingsHere</method> reads them; a fault is <var>pCaught</var>, with the namespace restored.</p>
ClassMethod PurgeSettingsIn(pNamespace As %String, Output pFound, Output pCaught) [ Private ]
{
    Kill pFound
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..PurgeSettingsHere(.pFound)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>The refusal <var>pCode</var> of <class>OcuPilot.Api.ConfigError</class>, on that class's status and slug, with its sentence.</p>
ClassMethod PurgeConfigRefused(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(##class(OcuPilot.Api.ConfigError).HttpStatusFor(pCode), ##class(OcuPilot.Api.ConfigError).SlugFor(pCode), pCode, ##class(OcuPilot.Api.ConfigError).ReasonFor(pCode), .pHttpStatus, .pFault)
}

/// <p>One purge setting, fresh (Story 24.16): <method>PurgeSettingRow</method>. A name the classic pages have no setting for is 404
/// <code>CONFIG.SETTING.NOTFOUND</code>, with or without <var>pAction</var>, which only names the write the read is composed for.</p>
ClassMethod ReadPurgeSetting(pNamespace As %String, pName As %String, pAction As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    If ..PurgeSettingEntry(pName) = "" Quit ..PurgeConfigRefused(##class(OcuPilot.Api.ConfigError).#SETTINGNOTFOUND, .pHttpStatus, .pFault)
    Do ..PurgeSettingsIn(pNamespace, .tFound, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the purge setting read failed", .pHttpStatus, .pFault)
    For tI = 1:1:tFound {
        If $List(tFound(tI), 1) '= pName Continue
        Set pRow = ..PurgeSettingRow(pName, $List(tFound(tI), 2), $List(tFound(tI), 3), pNamespace)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Serve the PurgeSettings endpoint after <method>Invoke</method>'s gate (Story 24.16): <code>LIST</code>, the <code>SETTING</code> read of the setting named
/// under <parameter>IDKEY</parameter> and the write <code>SETTINGSET</code>.</p>
ClassMethod InvokePurgeSettings(pNamespace As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType = ..#TYPELIST {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Do ..PurgeSettingsIn(pNamespace, .tFound, .tCaught)
            If $IsObject(tCaught) {
                Set tSC = ..Mapped(tCaught, "the purge settings list failed", .pHttpStatus, .pFault)
                Quit
            }
            Set pResult = []
            For tI = 1:1:tFound {
                Do pResult.%Push(..PurgeSettingRow($List(tFound(tI), 1), $List(tFound(tI), 2), $List(tFound(tI), 3), pNamespace))
            }
            Set pHttpStatus = 200
            Quit
        }
        Set tName = $Get(pQuery(..#IDKEY))
        If tName = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONIDREQUIRED, .pHttpStatus, .pFault)
            Quit
        }
        Set tAction = $Select(..IsPurgeWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && (tAction '= ..#TYPEPURGESETTINGSET) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPEPURGESETTINGSET {
            Set tSC = ..PerformPurgeSetting(pNamespace, tName, pBody, .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..ReadPurgeSetting(pNamespace, tName, tAction, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the purge setting call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Store the value <code>Value</code> of <var>pBody</var> for the purge setting <var>pName</var> in <var>pNamespace</var> and answer the setting's row, read
/// again (Story 24.16). A name the classic pages have no setting for is 404 <code>CONFIG.SETTING.NOTFOUND</code> and a value the setting's kind does not accept
/// is 400 <code>CONFIG.SETTING.VALUE</code>, each before anything is written. The node is set as the classic page's Save sets it, a boolean as 0 or 1. The
/// namespace is restored, then OcuPilot's own audit row is recorded (<method>AuditRuntime</method>), because the classic page records none: it names the namespace and
/// the setting, never the value.</p>
ClassMethod PerformPurgeSetting(pNamespace As %String, pName As %String, pBody As %DynamicAbstractObject, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tEntry = ..PurgeSettingEntry(pName)
    If tEntry = "" Quit ..PurgeConfigRefused(##class(OcuPilot.Api.ConfigError).#SETTINGNOTFOUND, .pHttpStatus, .pFault)
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") || (pBody.%GetTypeOf("Value") '= "string") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Port.ConfigPort).#REASONBODY, .pHttpStatus, .pFault)
    Set tValue = pBody.%Get("Value")
    If '##class(OcuPilot.Area.Interop.PurgeSettingRules).ValueHolds(..PurgeSettingLimits(pName), tValue) Quit ..PurgeConfigRefused(##class(OcuPilot.Api.ConfigError).#SETTINGVALUE, .pHttpStatus, .pFault)
    Set tCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set ^Ens.Configuration("PurgeSettings", $List(tEntry, 2)) = $Select($List(tEntry, 4) = "boolean": +tValue, 1: tValue)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the purge setting write failed", .pHttpStatus, .pFault)
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("setting", pName, "string")
    Do ..AuditRuntime(..#VERBSET, ..#ENTITYPURGESETTING, pName, tEffects)
    Set tReadSC = ..ReadPurgeSetting(pNamespace, pName, "", .tRow, .tReadHttp, .tReadFault)
    If $$$ISERR(tReadSC) || '$IsObject(tRow) {
        Set tRow = {}
        Do tRow.%Set("Name", pName, "string")
        Do tRow.%Set("Namespace", pNamespace, "string")
    }
    Set pResult = tRow
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>Whether <var>pDays</var> is a whole number from 0 to <parameter>PURGEMAXDAYS</parameter>, written without a sign, a point or a leading zero. Pure.</p>
ClassMethod PurgeDaysOK(pDays As %String) As %Boolean
{
    Quit $Match(pDays, "^(0|[1-9][0-9]{0,4})$") && (+pDays '> ..#PURGEMAXDAYS)
}

/// <p>The published sentence of <code>INTEROP.PURGE.DAYS</code>, which the purge tool's argument rule answers with.</p>
ClassMethod PurgeDaysReason() As %String
{
    Quit ##class(OcuPilot.Api.InteropError).ReasonFor(##class(OcuPilot.Api.InteropError).#PURGEDAYS)
}

/// <p>Whether the classic page's purge lock is held in the current namespace, which the caller has already switched: the lock is taken at once and let go when it
/// was free. The lock is the vendor page's own (<code>^IRIS.Temp.EnsPurgeAll($Namespace,"lock")</code>); no node of that global is written.</p>
ClassMethod PurgeRunningHere() As %Boolean [ Private ]
{
    Lock +^IRIS.Temp.EnsPurgeAll($Namespace, "lock"):0
    If '$Test Quit 1
    Lock -^IRIS.Temp.EnsPurgeAll($Namespace, "lock")
    Quit 0
}

/// <p>The purge's state in <var>pNamespace</var> (Story 24.16): the three settings and the description a purge will use, and whether one is running, in
/// <var>pFacts</var> (<code>settings</code> as <method>PurgeSettingsHere</method> builds it, <code>running</code>); a fault is <var>pCaught</var>, with the namespace restored.</p>
ClassMethod PurgeFacts(pNamespace As %String, Output pFacts, Output pCaught) [ Private ]
{
    Kill pFacts
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..PurgeSettingsHere(.tFound)
        For tI = 1:1:tFound {
            Set pFacts("settings", $List(tFound(tI), 1)) = $List(tFound(tI), 2)
        }
        Set pFacts("running") = ..PurgeRunningHere()
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>The purge's state row (Story 24.16): <code>{BodiesToo, KeepIntegrity, NamespaceBitmapMaint, Description, DaysToKeep, Running, Namespace}</code>. The days belong to
/// the call that asks for the purge, so <code>DaysToKeep</code> reads empty here. With <var>pAction</var> <parameter>TYPEPURGE</parameter> a purge that is already running is
/// 409 <code>INTEROP.PURGE.RUNNING</code>.</p>
ClassMethod ReadPurge(pNamespace As %String, pAction As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Do ..PurgeFacts(pNamespace, .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the purge state read failed", .pHttpStatus, .pFault)
    If (pAction = ..#TYPEPURGE) && tFacts("running") Quit ..Conflict(##class(OcuPilot.Api.InteropError).#PURGERUNNING, .pHttpStatus, .pFault)
    Set pRow = {}
    Do pRow.%Set("BodiesToo", ''tFacts("settings", "Include message bodies"), "boolean")
    Do pRow.%Set("KeepIntegrity", ''tFacts("settings", "Purge only completed sessions"), "boolean")
    Do pRow.%Set("NamespaceBitmapMaint", ''tFacts("settings", "Run bitmap cleanup for namespace"), "boolean")
    Do pRow.%Set("Description", tFacts("settings", "Description"), "string")
    Do pRow.%Set("DaysToKeep", "", "string")
    Do pRow.%Set("Running", ''tFacts("running"), "boolean")
    Do pRow.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The six record counts of <var>pNamespace</var>, one row each in the classic page's order, <code>{Type, Count, Namespace}</code>, <code>Type</code> the vendor's own
/// name (Story 24.16): <code>Ens.Purge.GetAllCounts</code>, which reads and writes nothing.</p>
ClassMethod ListPurgeCounts(pNamespace As %String, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ##class(Ens.Purge).GetAllCounts(.tCount)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the purge counts read failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tType = "Event Log", "Messages", "Business Processes", "Business Rule Log", "I/O Log", "Managed Alerts" {
        Set tRow = {}
        Do tRow.%Set("Type", tType, "string")
        Do tRow.%Set("Count", +$Get(tCount(tType)), "number")
        Do tRow.%Set("Namespace", pNamespace, "string")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Serve the Purge endpoint after <method>Invoke</method>'s gate (Story 24.16): <code>LIST</code> (<method>ListPurgeCounts</method>), the <code>PURGESTATE</code> read
/// (<method>ReadPurge</method>) and the write <code>PURGE</code> (<method>PerformPurge</method>). The purge's days travel in <parameter>PURGEDAYSKEY</parameter>.</p>
ClassMethod InvokePurge(pNamespace As %String, pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType = ..#TYPELIST {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..ListPurgeCounts(pNamespace, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tAction = $Select(..IsPurgeWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && (tAction '= ..#TYPEPURGE) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPEPURGE {
            Set tSC = ..PerformPurge(pNamespace, $Get(pQuery(..#PURGEDAYSKEY)), .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..ReadPurge(pNamespace, tAction, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the purge call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The vendor's status <var>pStatus</var> without any text it carries: an error status naming only the vendor's error codes, which is what reaches the log
/// (Story 24.16). A lock the vendor could not take and a privilege refusal are kept as they came. Pure.</p>
ClassMethod PurgeVendorStatus(pStatus As %Status) As %Status
{
    Quit ..VendorCodesStatus(pStatus, "the purge")
}

/// <p>The vendor's status <var>pStatus</var> without any text it carries, as <method>PurgeVendorStatus</method> gives it for a purge: an error status that says only that the
/// vendor reported <var>pWhat</var> with its error codes, which is what reaches the log (Story 24.16). A lock the vendor could not take and a privilege refusal are kept as they
/// came, so <method>Statused</method> still maps them. Pure.</p>
ClassMethod VendorCodesStatus(pStatus As %Status, pWhat As %String = "the call") As %Status
{
    If ..HasCode(pStatus, ..#CODERUNTIMELOCK) || ..HasCode(pStatus, ..#CODEPRIVILEGE) Quit pStatus
    Set tCodes = ""
    Set tProtect = 0
    Try {
        Set tCodes = $System.Status.GetErrorCodes(pStatus)
        Set tProtect = ($System.Status.GetErrorText(pStatus) [ "<PROTECT>")
    } Catch {
        Set tCodes = ""
    }
    If tProtect Quit pStatus
    Quit $$$ERROR($$$GeneralError, "the vendor reported " _ pWhat _ " with error code " _ tCodes)
}

/// <p>The vendor's purge of the current namespace, which the caller has already switched, run in a frame of its own that saves the process's roles and gives them back on
/// every exit, a thrown error included (<method>VendorPurge</method>). The vendor's bitmap cleanup adds <code>%All</code> in a frame of its own and drops it when it
/// returns; this frame keeps any vendor path that does not from reaching the request's later code or the pooled process's next request. With <var>pKind</var>
/// <parameter>LOGKINDRULE</parameter> or <parameter>LOGKINDPROCESS</parameter> the frame runs that log's purge (<method>VendorLogPurge</method>, Story 24.17 Batch 2) and
/// the other arguments are not used; <code>""</code> is the full purge.</p>
ClassMethod PurgeFrame(pDays As %Integer, pKeepIntegrity As %Boolean, pBodiesToo As %Boolean, pBitmap As %Boolean, Output pDeleted, pKind As %String = "") As %Status
{
    New $ROLES
    If pKind '= "" Quit ..VendorLogPurge(pKind, pDays, .pDeleted)
    Quit ..VendorPurge(pDays, pKeepIntegrity, pBodiesToo, pBitmap, .pDeleted)
}

/// <p><code>Ens.Purge.PurgeAll</code> with the classic page's own arguments, the bitmap cleanup asked for only when <var>pBitmap</var> is set (the one extended option the port
/// passes). <var>pDeleted</var> is the vendor's count for each kind it purged. Overridable so a fixture can answer a fault; production never overrides it.</p>
ClassMethod VendorPurge(pDays As %Integer, pKeepIntegrity As %Boolean, pBodiesToo As %Boolean, pBitmap As %Boolean, Output pDeleted) As %Status
{
    If pBitmap Set tOptions("NamespaceBitmapMaint") = 1
    Quit ##class(Ens.Purge).PurgeAll(.pDeleted, pDays, pKeepIntegrity, pBodiesToo, , .tOptions)
}

/// <p>Purge <var>pNamespace</var> as the classic Start Purge does, in this request (Story 24.16), and answer the purge's state row, read again. The sequence:</p>
/// <ol>
/// <li>The days are judged (<method>PurgeDaysOK</method>), 422 <code>INTEROP.PURGE.DAYS</code>, before any vendor call.</li>
/// <li>In the namespace the classic page's lock is taken at once and held for the whole of the vendor call; a purge already running is 409
/// <code>INTEROP.PURGE.RUNNING</code> and deletes nothing. The three settings are read at this moment, so a purge uses what is stored when it runs. An unset
/// Purge only completed sessions is used as 1, as both classic pages display it; the classic Start Purge passes 0 for it.</li>
/// <li>The vendor's <code>PurgeAll</code> runs (<method>PurgeFrame</method>) with no transaction; the lock is let go, the namespace restored, and OcuPilot's own audit row recorded
/// (<method>AuditRuntime</method>) whatever the vendor answered, because the vendor records none: it names the namespace, the days, the three settings and the count the
/// vendor deleted of each kind, never the description.</li>
/// </ol>
/// <p>A purge that outlasts the Web Gateway's response timeout runs to its end in this process, and its audit row is written then.</p>
ClassMethod PerformPurge(pNamespace As %String, pDays As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If '..PurgeDaysOK(pDays) {
        Set tViolations = 1
        Set tViolations(1) = $ListBuild("DaysToKeep", ##class(OcuPilot.Api.InteropError).#PURGEDAYS)
        Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    }
    Set tCaught = ""
    Set tHeld = 0
    Set tVendorSC = $$$OK
    Set tRan = 0
    Kill tDeleted, tSettings
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Lock +^IRIS.Temp.EnsPurgeAll($Namespace, "lock"):0
        Set tHeld = $Test
        If tHeld {
            Do ..PurgeSettingsHere(.tFound)
            For tI = 1:1:tFound {
                Set tSettings($List(tFound(tI), 1)) = $List(tFound(tI), 2)
            }
            Set tRan = 1
            ; The vendor reads a cut-off before the instance's first day as an error, so days past the instance's calendar keep every record, as they say.
            Set tKeepDays = $Select(+pDays > (+$Horolog - 2): +$Horolog - 2, 1: +pDays)
            Set tVendorSC = ..PurgeFrame(tKeepDays, tSettings("Purge only completed sessions"), tSettings("Include message bodies"), tSettings("Run bitmap cleanup for namespace"), .tDeleted)
            Lock -^IRIS.Temp.EnsPurgeAll($Namespace, "lock")
            Set tHeld = 0
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Try {
            Set $NAMESPACE = pNamespace
            If tHeld Lock -^IRIS.Temp.EnsPurgeAll($Namespace, "lock")
        } Catch {
        }
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Statused(..PurgeVendorStatus(tCaught.AsStatus()), "the purge failed", .pHttpStatus, .pFault)
    If 'tRan Quit ..Conflict(##class(OcuPilot.Api.InteropError).#PURGERUNNING, .pHttpStatus, .pFault)
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("daysToKeep", +pDays, "number")
    Do tEffects.%Set("bodiesToo", ''tSettings("Include message bodies"), "boolean")
    Do tEffects.%Set("keepIntegrity", ''tSettings("Purge only completed sessions"), "boolean")
    Do tEffects.%Set("bitmapMaint", ''tSettings("Run bitmap cleanup for namespace"), "boolean")
    Set tDeletedRow = {}
    Do tDeletedRow.%Set("eventLog", +$Get(tDeleted("Event Logs")), "number")
    Do tDeletedRow.%Set("messages", +$Get(tDeleted("Ensemble Messages")), "number")
    Do tDeletedRow.%Set("messageBodies", +$Get(tDeleted("Message Bodies")), "number")
    Do tDeletedRow.%Set("businessProcesses", +$Get(tDeleted("Business Processes")), "number")
    Do tDeletedRow.%Set("businessRuleLog", +$Get(tDeleted("Business Rule Logs")), "number")
    Do tDeletedRow.%Set("ioLog", +$Get(tDeleted("I/O Logs")), "number")
    Do tDeletedRow.%Set("hostMonitor", +$Get(tDeleted("Host Monitor Data")), "number")
    Do tDeletedRow.%Set("managedAlerts", +$Get(tDeleted("Managed Alerts")), "number")
    Do tEffects.%Set("deleted", tDeletedRow)
    Do tEffects.%Set("completed", $$$ISOK(tVendorSC), "boolean")
    Do ..AuditRuntime(..#VERBPURGE, ..#ENTITYPURGE, pNamespace, tEffects)
    If $$$ISERR(tVendorSC) Quit ..Statused(..PurgeVendorStatus(tVendorSC), "the purge failed", .pHttpStatus, .pFault)
    Set tReadSC = ..ReadPurge(pNamespace, "", .tRow, .tReadHttp, .tReadFault)
    If $$$ISERR(tReadSC) || '$IsObject(tRow) {
        Set tRow = {}
        Do tRow.%Set("Namespace", pNamespace, "string")
    }
    Set pResult = tRow
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>The lines <method>Snippet</method> adds for the purge write of the purge setting <var>pName</var> with <var>pBody</var> (Story 24.16): the one global set the port
/// makes, the value as a string literal, a boolean as 0 or 1. <code>""</code> for a name or a value the port would refuse, which renders no draft.</p>
ClassMethod PurgeSettingSnippet(pName As %String, pBody As %DynamicAbstractObject) As %String [ Private ]
{
    Set tEntry = ..PurgeSettingEntry(pName)
    If (tEntry = "") || '$IsObject(pBody) || (pBody.%GetTypeOf("Value") '= "string") Quit ""
    Set tValue = pBody.%Get("Value")
    If '##class(OcuPilot.Area.Interop.PurgeSettingRules).ValueHolds(..PurgeSettingLimits(pName), tValue) Quit ""
    Quit $Char(10) _ " Set ^Ens.Configuration(""PurgeSettings"", " _ ..Literal($List(tEntry, 2)) _ ") = " _ $Select($List(tEntry, 4) = "boolean": +tValue, 1: ..Literal(tValue))
}

/// <p>The lines <method>Snippet</method> adds for the purge of the days <var>pDays</var> (Story 24.16): the classic page's lock taken at once, the three settings read, and
/// <code>Ens.Purge.PurgeAll</code> called while the lock is held. <code>""</code> for days the port would refuse, which renders no draft.</p>
ClassMethod PurgeSnippet(pDays As %String) As %String [ Private ]
{
    If '..PurgeDaysOK(pDays) Quit ""
    Set tNL = $Char(10)
    Set tText = tNL _ " Lock +^IRIS.Temp.EnsPurgeAll($Namespace, ""lock""):0"
    Set tText = tText _ tNL _ " Set tHeld = $Test"
    Set tText = tText _ tNL _ " If 'tHeld Set tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.InteropError).#REASONPURGERUNNING) _ ")"
    Set tText = tText _ tNL _ " If tHeld Set tBodies = +$Get(^Ens.Configuration(""PurgeSettings"", ""BodiesToo"")), tKeep = +$Get(^Ens.Configuration(""PurgeSettings"", ""KeepIntegrity""), 1), tBitmap = +$Get(^Ens.Configuration(""PurgeSettings"", ""NamespaceBitmapMaint""))"
    Set tText = tText _ tNL _ " If tHeld, tBitmap Set tOptions(""NamespaceBitmapMaint"") = 1"
    ; The days the port itself would pass (PerformPurge): past the instance's calendar, the calendar's own count.
    Set tDaysText = $Select(+pDays > (+$Horolog - 2): "+$Horolog - 2", 1: +pDays)
    Set tText = tText _ tNL _ " If tHeld Set tSC = ##class(Ens.Purge).PurgeAll(.tDeleted, " _ tDaysText _ ", tKeep, tBodies, , .tOptions)"
    Set tText = tText _ tNL _ " If tHeld Lock -^IRIS.Temp.EnsPurgeAll($Namespace, ""lock"")"
    Quit tText
}

/// <p>The Archive settings endpoint (Story 24.16 Batch 4): <code>LIST</code>, one setting (<code>SETTING</code>) and the write <code>SETTINGSET</code>, over the vendor's own
/// <code>Ens.Archive.Manager.GetArchiveParameters</code> and <code>SetArchiveParameters</code>. The archive class is shown and never set.</p>
Parameter ENDPOINTARCHIVESETTINGS = "ArchiveSettings";

/// <p>The Archive endpoint (Story 24.16 Batch 4): <code>LIST</code> (the last run's history, the classic page's eight rows), <code>ARCHIVESTATE</code> (what a run would use and
/// whether one is running) and the write <code>ARCHIVE</code>, the vendor's <code>Ens.Archive.Manager.DoArchive</code> run in the request while the port holds the vendor's lock.</p>
Parameter ENDPOINTARCHIVE = "Archive";

/// <p>The Archive errors endpoint (Story 24.16 Batch 4): <code>LIST</code>, the vendor's <code>Ens.Archive.Manager:Errors</code> query.</p>
Parameter ENDPOINTARCHIVEERRORS = "ArchiveErrors";

/// <p>The pairs the three archive endpoints require: <code>%Ens_Portal:USE</code> and the classic Archive Manager page's own <code>%Ens_ArchiveManager:READ</code>. A write adds
/// <parameter>ARCHIVEWRITEPAIR</parameter>, the classic page's edit resource; a run also needs WRITE on the target's globals database, judged at the write.</p>
Parameter ARCHIVEPAIRS = "%Ens_Portal:USE,%Ens_ArchiveManager:READ";

Parameter ARCHIVEWRITEPAIR = "%Ens_ArchiveManager:WRITE";

Parameter TYPEARCHIVESETTINGSET = "SETTINGSET";

Parameter TYPEARCHIVESTATE = "ARCHIVESTATE";

Parameter TYPEARCHIVE = "ARCHIVE";

/// <p>The most days before archiving a set accepts, and the vendor's class a run is allowed to use.</p>
Parameter ARCHIVEMAXDAYS As INTEGER = 36500;

Parameter ARCHIVECLASSNAME = "Ens.Archive.Manager";

/// <p>The most message headers a namespace may hold for one archive run here to take: the vendor's run opens every header and body of the namespace. A run of twice this many took
/// at most 20.1 seconds on the throwaway (measured), and half of that, times 1.5, stays inside 30 seconds on a runner that is slower (inference). A namespace above it is refused whole.</p>
Parameter ARCHIVEMAXMESSAGES As INTEGER = 5000;

/// <p>The most error rows the Archive errors list answers when the call gives no cap.</p>
Parameter ARCHIVEERRORSMAX As INTEGER = 2000;

/// <p>The most characters a stored archive class name is shown with.</p>
Parameter ARCHIVETEXTMAX As INTEGER = 256;

Parameter ENTITYARCHIVE = "interop-archive";

Parameter ENTITYARCHIVESETTING = "interop-archive-setting";

Parameter VERBARCHIVE = "archive";

/// <p>Whether <var>pType</var> is the archive run, which needs WRITE on the namespace's globals database and, judged at the write, on the target's.</p>
ClassMethod IsArchiveWrite(pType As %String) As %Boolean
{
    Quit pType = ..#TYPEARCHIVE
}

/// <p>The namespaces the classic Archive Manager page offers as Archive to namespace: the instance's interoperability namespaces
/// (<code>^%SYS("Ensemble","InstalledNamespace")</code>) other than <var>pNamespace</var>, as a <class>%List</class>. Read at the call.</p>
ClassMethod ArchiveTargets(pNamespace As %String) As %List
{
    Set tList = ""
    Set tName = ""
    For {
        Set tName = $Order(^%SYS("Ensemble", "InstalledNamespace", tName))
        If tName = "" Quit
        If tName '= $ZConvert(pNamespace, "U") Set tList = tList _ $ListBuild(tName)
    }
    Quit tList
}

/// <p>The three archive settings, in the classic page's order, as a <class>%List</class> of <class>%List</class>s: <code>name, node, default, kind</code>. The name is the classic
/// caption; the node is the subscript under <code>^Ens.ArchiveManager</code>, and the default is what the vendor reads for a node that is not stored. Pure.</p>
ClassMethod ArchiveSettingRoster() As %List
{
    Quit $ListBuild($ListBuild("Archive to namespace", "Namespace", "", "choice"), $ListBuild("Archive manager class name", "Classname", ..#ARCHIVECLASSNAME, "text"), $ListBuild("Number of days before archiving", "DaysToArchive", 30, "integer"))
}

/// <p>The roster entry of the setting <var>pName</var>, or <code>""</code> for a name the classic page has no setting for. Pure.</p>
ClassMethod ArchiveSettingEntry(pName As %String) As %List
{
    Set tRoster = ..ArchiveSettingRoster()
    Set tFound = ""
    For tI = 1:1:$ListLength(tRoster) {
        If $List($List(tRoster, tI), 1) = pName Set tFound = $List(tRoster, tI)
    }
    Quit tFound
}

/// <p>Whether <var>pName</var> is the archive class setting, which is shown and never set. Pure.</p>
ClassMethod ArchiveSettingReadOnly(pName As %String) As %Boolean
{
    Set tEntry = ..ArchiveSettingEntry(pName)
    Quit (tEntry '= "") && ($List(tEntry, 2) = "Classname")
}

/// <p>The limits of the setting <var>pName</var> in <code>ConfigPort.Limits</code>' shape: Archive to namespace is a choice of <method>ArchiveTargets</method> of <var>pNamespace</var>,
/// the days a whole number from 0 to <parameter>ARCHIVEMAXDAYS</parameter>, the class text; <code>""</code> for a name the classic page has no setting for. The rules class asks it.</p>
ClassMethod ArchiveSettingLimits(pName As %String, pNamespace As %String) As %List
{
    Set tEntry = ..ArchiveSettingEntry(pName)
    If tEntry = "" Quit ""
    Set tKind = $List(tEntry, 4)
    If tKind = "choice" Quit $ListBuild("choice", "", "", ..ArchiveTargets(pNamespace), "", "")
    If tKind = "integer" Quit $ListBuild("integer", 0, ..#ARCHIVEMAXDAYS, "", "", "")
    Quit $ListBuild("text", "", "", "", ..#ARCHIVETEXTMAX, "")
}

/// <p>The settings as they stand in the current namespace, which the caller has already switched, in <var>pFound</var>: one <code>$ListBuild(name, value, stored)</code> per roster
/// entry, read through the vendor's own <code>GetArchiveParameters</code>, which answers the defaults for a node that is not stored. Nothing is written.</p>
ClassMethod ArchiveSettingsHere(Output pFound) [ Private ]
{
    Kill pFound
    Set tRoster = ..ArchiveSettingRoster()
    Set pFound = $ListLength(tRoster)
    Do ##class(Ens.Archive.Manager).GetArchiveParameters(.tTarget, .tClass, .tDays)
    For tI = 1:1:pFound {
        Set tEntry = $List(tRoster, tI)
        Set tNode = $List(tEntry, 2)
        Set tValue = $Case(tNode, "Namespace": tTarget, "Classname": tClass, : tDays)
        Set pFound(tI) = $ListBuild($List(tEntry, 1), tValue _ "", ''($Data(^Ens.ArchiveManager(tNode)) # 2))
    }
}

/// <p>The row an archive setting list and read answer, from the setting <var>pName</var>, its <var>pValue</var> and whether it is <var>pStored</var>:
/// <code>{Name, Value, Stored, Kind, Accepts, ReadOnly, Namespace}</code>. The class row is read-only; Archive to namespace accepts the listed namespaces, or says there are none.</p>
ClassMethod ArchiveSettingRow(pName As %String, pValue As %String, pStored As %Boolean, pNamespace As %String) As %DynamicObject [ Private ]
{
    Set tLimits = ..ArchiveSettingLimits(pName, pNamespace)
    Set tReadOnly = ..ArchiveSettingReadOnly(pName)
    If tReadOnly {
        Set tAccepts = ##class(OcuPilot.Api.ConfigError).#ACCEPTSREADONLY
    } ElseIf ($ListGet(tLimits, 1) = "choice") && ($ListLength($ListGet(tLimits, 4)) = 0) {
        Set tAccepts = ##class(OcuPilot.Api.InteropError).#ACCEPTSNOARCHIVETARGET
    } Else {
        Set tAccepts = ##class(OcuPilot.Port.ConfigPort).AcceptsOf(tLimits)
    }
    Set tRow = {}
    Do tRow.%Set("Name", pName, "string")
    Do tRow.%Set("Value", pValue, "string")
    Do tRow.%Set("Stored", ''pStored, "boolean")
    Do tRow.%Set("Kind", $ListGet(tLimits, 1), "string")
    Do tRow.%Set("Accepts", tAccepts, "string")
    Do tRow.%Set("ReadOnly", ''tReadOnly, "boolean")
    Do tRow.%Set("Namespace", pNamespace, "string")
    Quit tRow
}

/// <p>The settings of <var>pNamespace</var> as <method>ArchiveSettingsHere</method> reads them; a fault is <var>pCaught</var>, with the namespace restored.</p>
ClassMethod ArchiveSettingsIn(pNamespace As %String, Output pFound, Output pCaught) [ Private ]
{
    Kill pFound
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..ArchiveSettingsHere(.pFound)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>One archive setting, fresh (Story 24.16 Batch 4): <method>ArchiveSettingRow</method>. A name the classic page has no setting for is 404
/// <code>CONFIG.SETTING.NOTFOUND</code>.</p>
ClassMethod ReadArchiveSetting(pNamespace As %String, pName As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    If ..ArchiveSettingEntry(pName) = "" Quit ..PurgeConfigRefused(##class(OcuPilot.Api.ConfigError).#SETTINGNOTFOUND, .pHttpStatus, .pFault)
    Do ..ArchiveSettingsIn(pNamespace, .tFound, .tCaught)
    If $IsObject(tCaught) Quit ..ArchiveMapped(tCaught, "the archive setting read failed", .pHttpStatus, .pFault)
    For tI = 1:1:tFound {
        If $List(tFound(tI), 1) '= pName Continue
        Set pRow = ..ArchiveSettingRow(pName, $List(tFound(tI), 2), $List(tFound(tI), 3), pNamespace)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Serve the ArchiveSettings endpoint after <method>Invoke</method>'s gate (Story 24.16 Batch 4): <code>LIST</code>, the <code>SETTING</code> read of the setting named
/// under <parameter>IDKEY</parameter> and the write <code>SETTINGSET</code>.</p>
ClassMethod InvokeArchiveSettings(pNamespace As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType = ..#TYPELIST {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Do ..ArchiveSettingsIn(pNamespace, .tFound, .tCaught)
            If $IsObject(tCaught) {
                Set tSC = ..ArchiveMapped(tCaught, "the archive settings list failed", .pHttpStatus, .pFault)
                Quit
            }
            Set pResult = []
            For tI = 1:1:tFound {
                Do pResult.%Push(..ArchiveSettingRow($List(tFound(tI), 1), $List(tFound(tI), 2), $List(tFound(tI), 3), pNamespace))
            }
            Set pHttpStatus = 200
            Quit
        }
        Set tName = $Get(pQuery(..#IDKEY))
        If tName = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONIDREQUIRED, .pHttpStatus, .pFault)
            Quit
        }
        Set tAction = $Select(pType = ..#TYPEARCHIVESETTINGSET: pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && (tAction '= ..#TYPEARCHIVESETTINGSET) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPEARCHIVESETTINGSET {
            Set tSC = ..PerformArchiveSetting(pNamespace, tName, pBody, .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..ReadArchiveSetting(pNamespace, tName, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..ArchiveMapped(ex, "the archive setting call failed inside the port", .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Store the value <code>Value</code> of <var>pBody</var> for the archive setting <var>pName</var> in <var>pNamespace</var> and answer the setting's row, read again (Story 24.16
/// Batch 4). A name the classic page has no setting for is 404 <code>CONFIG.SETTING.NOTFOUND</code>, the class is 409 <code>CONFIG.SETTING.READONLY</code> and a value the setting's
/// kind does not accept, a target outside the namespaces the classic page lists included, is 400 <code>CONFIG.SETTING.VALUE</code>, each before anything is written. The vendor's
/// <code>SetArchiveParameters</code> is called, as the classic Save calls it, with the two other values read at this moment; the namespace is restored, then OcuPilot's own audit row
/// is recorded (<method>AuditRuntime</method>), because the vendor records none: it names the namespace, the setting and the value.</p>
ClassMethod PerformArchiveSetting(pNamespace As %String, pName As %String, pBody As %DynamicAbstractObject, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tEntry = ..ArchiveSettingEntry(pName)
    If tEntry = "" Quit ..PurgeConfigRefused(##class(OcuPilot.Api.ConfigError).#SETTINGNOTFOUND, .pHttpStatus, .pFault)
    If ..ArchiveSettingReadOnly(pName) Quit ..PurgeConfigRefused(##class(OcuPilot.Api.ConfigError).#SETTINGREADONLY, .pHttpStatus, .pFault)
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") || (pBody.%GetTypeOf("Value") '= "string") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Port.ConfigPort).#REASONBODY, .pHttpStatus, .pFault)
    Set tValue = pBody.%Get("Value")
    If '##class(OcuPilot.Area.Interop.ArchiveSettingRules).ValueHolds(..ArchiveSettingLimits(pName, pNamespace), tValue) Quit ..PurgeConfigRefused(##class(OcuPilot.Api.ConfigError).#SETTINGVALUE, .pHttpStatus, .pFault)
    Set tCaught = ""
    Set tSetSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ##class(Ens.Archive.Manager).GetArchiveParameters(.tTarget, .tClass, .tDays)
        Set tNode = $List(tEntry, 2)
        If tNode = "Namespace" Set tTarget = tValue
        If tNode = "DaysToArchive" Set tDays = tValue
        Set tSetSC = ##class(Ens.Archive.Manager).SetArchiveParameters(tTarget, tClass, tDays)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..ArchiveMapped(tCaught, "the archive setting write failed", .pHttpStatus, .pFault)
    If $$$ISERR(tSetSC) Quit ..Statused(..VendorCodesStatus(tSetSC, "the archive setting write"), "the archive setting write failed", .pHttpStatus, .pFault)
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("setting", pName, "string")
    Do tEffects.%Set("value", tValue, "string")
    Do ..AuditRuntime(..#VERBSET, ..#ENTITYARCHIVESETTING, pName, tEffects)
    Set tReadSC = ..ReadArchiveSetting(pNamespace, pName, .tRow, .tReadHttp, .tReadFault)
    If $$$ISERR(tReadSC) || '$IsObject(tRow) {
        Set tRow = {}
        Do tRow.%Set("Name", pName, "string")
        Do tRow.%Set("Namespace", pNamespace, "string")
    }
    Set pResult = tRow
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>The archive's facts in <var>pNamespace</var> (Story 24.16 Batch 4), in <var>pFacts</var>, read through the vendor's own getters with the namespace switched and nothing else:
/// <code>target</code>, <code>class</code> and <code>days</code> (<code>GetArchiveParameters</code>), <code>running</code> (<code>GetRunningStatus</code>), and the last run's
/// <code>start</code>, <code>stop</code>, <code>counts</code> (<code>GetRunningCount</code>, five comma-separated numbers) and <code>status</code>. A fault is <var>pCaught</var>, with
/// the namespace restored. Nothing is written.</p>
ClassMethod ArchiveFacts(pNamespace As %String, Output pFacts, Output pCaught) [ Private ]
{
    Kill pFacts
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ##class(Ens.Archive.Manager).GetArchiveParameters(.tTarget, .tClass, .tDays)
        Set pFacts("target") = tTarget
        Set pFacts("class") = tClass
        Set pFacts("days") = tDays
        Set pFacts("status") = ##class(Ens.Archive.Manager).GetRunningStatus()
        Set pFacts("running") = (pFacts("status") = "running")
        Set pFacts("start") = ##class(Ens.Archive.Manager).GetRunningStartTime()
        Set pFacts("stop") = ##class(Ens.Archive.Manager).GetRunningStopTime()
        Set pFacts("counts") = ##class(Ens.Archive.Manager).GetRunningCount()
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>The cut-off the vendor's run uses for <var>pDays</var> days, <code>Ens.Purge.GetDoNotDeleteDate</code>, with days past the instance's calendar read as the calendar's own count so the
/// read never raises (the vendor's run logs an error for each message in that case).</p>
ClassMethod ArchiveCutoff(pDays As %Integer) As %String [ Private ]
{
    Quit ##class(Ens.Purge).GetDoNotDeleteDate($Select(+pDays > (+$Horolog - 2): +$Horolog - 2, 1: +pDays))
}

/// <p>The number of message headers <var>pNamespace</var> holds, and how many of them a run with <var>pDays</var> days would move, in <var>pTotal</var> and <var>pMoving</var>: the
/// vendor's own rule, a header whose <code>TimeCreated</code> is before <code>Ens.Purge.GetDoNotDeleteDate(days)</code> (an empty one included), whatever its status. A fault is
/// <var>pCaught</var>.</p>
ClassMethod ArchiveCounts(pNamespace As %String, pDays As %Integer, Output pTotal As %Integer, Output pMoving As %Integer, Output pCaught) [ Private ]
{
    Set pTotal = 0
    Set pMoving = 0
    Set tSC = ..SqlRows(pNamespace, "SELECT COUNT(*) FROM Ens.MessageHeader", .tFound, .pCaught)
    If $IsObject(pCaught) Quit
    Set pTotal = +$List($Get(tFound(1)), 1)
    Set tSC = ..SqlRows(pNamespace, "SELECT COUNT(*) FROM Ens.MessageHeader WHERE TimeCreated IS NULL OR TimeCreated < ?", .tFound, .pCaught, ..ArchiveCutoff(pDays))
    If $IsObject(pCaught) Quit
    Set pMoving = +$List($Get(tFound(1)), 1)
}

/// <p>The first refusal an archive run of <var>pNamespace</var> would meet that the namespace itself decides, as the code of <class>OcuPilot.Api.InteropError</class>, in the order the
/// write judges them, or <code>""</code>: a run already <var>pRunning</var>, a stored class that is not <parameter>ARCHIVECLASSNAME</parameter>, a target that is not one of
/// <method>ArchiveTargets</method>, and more than <parameter>ARCHIVEMAXMESSAGES</parameter> headers. Pure.</p>
ClassMethod ArchiveRefusal(pNamespace As %String, pRunning As %Boolean, pClass As %String, pTarget As %String, pTotal As %Integer) As %String
{
    If pRunning Quit ##class(OcuPilot.Api.InteropError).#ARCHIVERUNNING
    If pClass '= ..#ARCHIVECLASSNAME Quit ##class(OcuPilot.Api.InteropError).#ARCHIVECLASS
    If (pTarget = "") || '$ListFind(..ArchiveTargets(pNamespace), pTarget) Quit ##class(OcuPilot.Api.InteropError).#ARCHIVENOTARGET
    If pTotal > ..#ARCHIVEMAXMESSAGES Quit ##class(OcuPilot.Api.InteropError).#ARCHIVETOOMANY
    Quit ""
}

/// <p>The archive state row (Story 24.16 Batch 4): <code>{Target, Classname, DaysToArchive, Running, Total, ToArchive, Namespace}</code>, which a run would use and what it would
/// move. With <var>pAction</var> <parameter>TYPEARCHIVE</parameter> a run the namespace would refuse (<method>ArchiveRefusal</method>) is 409 with that code.</p>
ClassMethod ReadArchive(pNamespace As %String, pAction As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Do ..ArchiveFacts(pNamespace, .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..ArchiveMapped(tCaught, "the archive state read failed", .pHttpStatus, .pFault)
    Do ..ArchiveCounts(pNamespace, tFacts("days"), .tTotal, .tMoving, .tCaught)
    If $IsObject(tCaught) Quit ..ArchiveMapped(tCaught, "the archive state read failed", .pHttpStatus, .pFault)
    If pAction = ..#TYPEARCHIVE {
        Set tCode = ..ArchiveRefusal(pNamespace, tFacts("running"), tFacts("class"), tFacts("target"), tTotal)
        If tCode '= "" Quit ..Conflict(tCode, .pHttpStatus, .pFault)
    }
    Set pRow = {}
    Do pRow.%Set("Target", tFacts("target"), "string")
    Do pRow.%Set("Classname", tFacts("class"), "string")
    Do pRow.%Set("DaysToArchive", +tFacts("days"), "number")
    Do pRow.%Set("Running", ''tFacts("running"), "boolean")
    Do pRow.%Set("Total", tTotal, "number")
    Do pRow.%Set("ToArchive", tMoving, "number")
    Do pRow.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The last run's history of <var>pNamespace</var>, the classic page's eight rows in its order, <code>{Name, Value, Namespace}</code> (Story 24.16 Batch 4): the start and stop
/// time as the vendor keeps them (empty before any run), the four counts and the number of errors, and <code>idle</code> or <code>running</code>. The rows are always there, so
/// Run archive stays reachable before the first run.</p>
ClassMethod ListArchiveHistory(pNamespace As %String, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Do ..ArchiveFacts(pNamespace, .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..ArchiveMapped(tCaught, "the archive history read failed", .pHttpStatus, .pFault)
    Set tCounts = tFacts("counts")
    Set tLines = $ListBuild($ListBuild("Archive start time", tFacts("start")), $ListBuild("Archive stop time", tFacts("stop")), $ListBuild("Total messages processed", $Piece(tCounts, ",", 1)), $ListBuild("Total messages archived", $Piece(tCounts, ",", 2)), $ListBuild("Total message headers deleted", $Piece(tCounts, ",", 3)), $ListBuild("Total message bodies deleted", $Piece(tCounts, ",", 4)), $ListBuild("Total number of errors", $Piece(tCounts, ",", 5)), $ListBuild("Archive status", tFacts("status")))
    Set pRows = []
    For tI = 1:1:$ListLength(tLines) {
        Set tRow = {}
        Do tRow.%Set("Name", $List($List(tLines, tI), 1), "string")
        Do tRow.%Set("Value", $List($List(tLines, tI), 2) _ "", "string")
        Do tRow.%Set("Namespace", pNamespace, "string")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The last run's error log of <var>pNamespace</var> (Story 24.16 Batch 4): the vendor's <code>Ens.Archive.Manager:Errors</code> query, <code>{ErrorNumber, Time, Description,
/// MessageId}</code>, at most <var>pMax</var> rows (<parameter>ARCHIVEERRORSMAX</parameter> when that is not above zero). The description is the vendor's text, shown and never run.</p>
ClassMethod ListArchiveErrors(pNamespace As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tTop = $Select(pMax > 0: pMax, 1: ..#ARCHIVEERRORSMAX)
    Set tCaught = ""
    Set tStatusSC = $$$OK
    Kill tFound
    Set tFound = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tResultSet = ##class(%ResultSet).%New("Ens.Archive.Manager:Errors")
        Set tStatusSC = tResultSet.Execute()
        If $$$ISOK(tStatusSC) {
            While tResultSet.Next() {
                If tFound >= tTop Quit
                Set tFound = tFound + 1
                Set tFound(tFound) = $ListBuild(tResultSet.GetData(1), tResultSet.GetData(2), tResultSet.GetData(3), tResultSet.GetData(4))
            }
            Do tResultSet.Close()
        }
        Set tResultSet = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..ArchiveMapped(tCaught, "the archive errors read failed", .pHttpStatus, .pFault)
    If $$$ISERR(tStatusSC) Quit ..Statused(tStatusSC, "the archive errors read failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Set tRow = {}
        Do tRow.%Set("ErrorNumber", +$List(tFound(tI), 1), "number")
        Do tRow.%Set("Time", $List(tFound(tI), 2) _ "", "string")
        Do tRow.%Set("Description", $List(tFound(tI), 3) _ "", "string")
        Do tRow.%Set("MessageId", $List(tFound(tI), 4) _ "", "string")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Serve the Archive and ArchiveErrors endpoints after <method>Invoke</method>'s gate (Story 24.16 Batch 4): the history <code>LIST</code>, the <code>ARCHIVESTATE</code> read, the
/// write <code>ARCHIVE</code>, and the error log's <code>LIST</code>.</p>
ClassMethod InvokeArchive(pNamespace As %String, pEndpoint As %String, pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType = ..#TYPELIST {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            If pEndpoint = ..#ENDPOINTARCHIVEERRORS {
                Set tSC = ..ListArchiveErrors(pNamespace, +tMaxText, .pResult, .pHttpStatus, .pFault)
            } Else {
                Set tSC = ..ListArchiveHistory(pNamespace, .pResult, .pHttpStatus, .pFault)
            }
            Quit
        }
        Set tAction = $Select(..IsArchiveWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && (tAction '= ..#TYPEARCHIVE) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPEARCHIVE {
            Set tSC = ..PerformArchive(pNamespace, .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..ReadArchive(pNamespace, tAction, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..ArchiveMapped(ex, "the archive call failed inside the port", .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>A vendor exception <var>pException</var> in this port's own words, as <method>Mapped</method> answers it, except that the status it logs carries the vendor's error codes alone
/// and never the vendor's text (<method>VendorCodesStatus</method>): a lock it could not take is 503, <code>&lt;PROTECT&gt;</code> is 403, anything else 500 <code>INTERNAL</code>.</p>
ClassMethod ArchiveMapped(pException As %Exception.AbstractException, pMessage As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Statused(..VendorCodesStatus(pException.AsStatus(), "the archive"), pMessage, .pHttpStatus, .pFault)
}

/// <p>Take the vendor's archive lock, <code>^Ens.ArchiveManager("lock")</code>, in <var>pNamespace</var> at once, and answer <code>1</code> when it is held. A fault is
/// <var>pCaught</var>, with the namespace restored.</p>
ClassMethod ArchiveTake(pNamespace As %String, Output pCaught) As %Boolean [ Private ]
{
    Set pCaught = ""
    Set tHeld = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Lock +^Ens.ArchiveManager("lock"):0
        Set tHeld = $Test
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit tHeld
}

/// <p>Let go of every hold this process has on the vendor's archive lock of <var>pNamespace</var>: the port's own, and any the vendor's run took and did not give back when it was
/// cut short. Bounded, and it never throws, so the lock is free on every exit.</p>
ClassMethod ArchiveRelease(pNamespace As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tName = $Name(^Ens.ArchiveManager("lock"))
        For tI = 1:1:100 {
            If $Get(^$LOCK(tName, "OWNER")) '= $Job Quit
            Lock -^Ens.ArchiveManager("lock")
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>The ids of the headers <var>pTarget</var> already holds that a run of <var>pNamespace</var> with <var>pDays</var> days would move, comma-separated and empty for none,
/// at most the first ten. A fault is <var>pCaught</var>.</p>
ClassMethod ArchiveTaken(pNamespace As %String, pTarget As %String, pDays As %Integer, Output pCaught) As %String [ Private ]
{
    Set tSC = ..SqlRows(pNamespace, "SELECT ID FROM Ens.MessageHeader WHERE TimeCreated IS NULL OR TimeCreated < ?", .tFound, .pCaught, ..ArchiveCutoff(pDays))
    If $IsObject(pCaught) Quit ""
    Set tTaken = ""
    Set tCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pTarget
        Do ..ArchiveTargetHere()
        For tI = 1:1:tFound {
            Set tId = $List(tFound(tI), 1)
            If $Data(^Ens.MessageHeaderD(tId)) {
                Set tCount = tCount + 1
                If tCount < 11 Set tTaken = tTaken _ $Select(tTaken = "": "", 1: ",") _ tId
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit tTaken
}

/// <p>A point inside the target-switched read of <method>ArchiveTaken</method>, which does nothing. A fixture overrides it to raise a fault there, so a test reads that the fault is
/// logged after the namespace is restored; production never overrides it.</p>
ClassMethod ArchiveTargetHere() [ Private ]
{
}

/// <p>The vendor's run in the current namespace, which the caller has already switched: <code>Ens.Archive.Manager.DoArchive</code>, called while the port holds the vendor's lock
/// (the vendor's own <code>lock +</code> is re-entrant in this process) and with no transaction. Overridable so a fixture can answer a status or a fault; production never overrides it.</p>
ClassMethod VendorArchive() As %Status
{
    Quit ##class(Ens.Archive.Manager).DoArchive()
}

/// <p>The vendor's status <var>pStatus</var> without any text it carries, as <method>PurgeVendorStatus</method> gives it for a purge. Pure.</p>
ClassMethod ArchiveVendorStatus(pStatus As %Status) As %Status
{
    Quit ..VendorCodesStatus(pStatus, "the archive")
}

/// <p>Run the archive of <var>pNamespace</var> (Story 24.16 Batch 4): the vendor's own run, in this request, and answer the archive state row, read again. The sequence, each refusal
/// before any vendor call and each leaving the lock free:</p>
/// <ol>
/// <li>The vendor's lock is taken at once in the namespace; a lock that is held is 409 <code>INTEROP.ARCHIVE.RUNNING</code>.</li>
/// <li>The three settings are read: a stored class other than <parameter>ARCHIVECLASSNAME</parameter> is 409 <code>CLASS</code>, a target that is not a namespace the classic page lists
/// is 409 <code>NOTARGET</code>, more than <parameter>ARCHIVEMAXMESSAGES</parameter> headers is 409 <code>TOOMANY</code>.</li>
/// <li>WRITE on the target's globals database is required, 403 naming the pair (it admits the port's read of the target's ids too, as the vendor needs nothing more); a target that
/// already holds a header id the run would move is 409 <code>TAKEN</code>.</li>
/// <li><method>VendorArchive</method> runs, the namespace is restored, the five counts are read and OcuPilot's own audit row is recorded (<method>AuditRuntime</method>) whatever the vendor
/// answered. A run whose status is an error, or that logged an error, is 500 <code>INTERNAL</code>, as a partial purge is.</li>
/// </ol>
/// <p>The lock is let go on every exit. A run that outlasts the Web Gateway's response timeout runs to its end in this process, and its audit row is written then.</p>
ClassMethod PerformArchive(pNamespace As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tHeld = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ..ArchiveRun(pNamespace, .pResult, .pHttpStatus, .pFault, .tHeld)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pResult = ""
        Set tSC = ..ArchiveMapped(ex, "the archive call failed inside the port", .pHttpStatus, .pFault)
    }
    If tHeld Do ..ArchiveRelease(pNamespace)
    Quit tSC
}

/// <p><method>PerformArchive</method>'s steps; <var>pHeld</var> is set once the lock is taken, so the caller lets go of it whatever this method does.</p>
ClassMethod ArchiveRun(pNamespace As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pHeld As %Boolean) As %Status [ Private ]
{
    Set pResult = ""
    Set pHeld = ..ArchiveTake(pNamespace, .tCaught)
    If $IsObject(tCaught) Quit ..ArchiveMapped(tCaught, "the archive lock could not be taken", .pHttpStatus, .pFault)
    If 'pHeld Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ARCHIVERUNNING, .pHttpStatus, .pFault)
    Do ..ArchiveFacts(pNamespace, .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..ArchiveMapped(tCaught, "the archive state read failed", .pHttpStatus, .pFault)
    Do ..ArchiveCounts(pNamespace, tFacts("days"), .tTotal, .tMoving, .tCaught)
    If $IsObject(tCaught) Quit ..ArchiveMapped(tCaught, "the archive state read failed", .pHttpStatus, .pFault)
    Set tCode = ..ArchiveRefusal(pNamespace, 0, tFacts("class"), tFacts("target"), tTotal)
    If tCode '= "" Quit ..Conflict(tCode, .pHttpStatus, .pFault)
    Set tTarget = tFacts("target")
    Set tDatabase = ""
    If '##class(OcuPilot.Kernel.Shell.Namespaces).GlobalDatabase(tTarget, .tDatabase, .tReadOnly) || (tDatabase = "") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
    Set tFailedPair = ""
    If '$ClassMethod(..GateClass(), "EvaluateRequired", $ListBuild($ListBuild(tDatabase, ..#WRITEPERMISSION)), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    Set tTaken = ..ArchiveTaken(pNamespace, tTarget, tFacts("days"), .tCaught)
    If $IsObject(tCaught) Quit ..ArchiveMapped(tCaught, "the archive target read failed", .pHttpStatus, .pFault)
    If tTaken '= "" Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ARCHIVETAKEN, .pHttpStatus, .pFault)
    Set tVendorSC = $$$OK
    Set tRaised = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tVendorSC = ..VendorArchive()
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tRaised = ex
    }
    Do ..ArchiveFacts(pNamespace, .tAfter, .tAfterCaught)
    Set tCounts = $Select($IsObject(tAfterCaught): "0,0,0,0,0", 1: tAfter("counts"))
    Set tErrors = +$Piece(tCounts, ",", 5)
    Set tCompleted = $$$ISOK(tVendorSC) && '$IsObject(tRaised) && (tErrors = 0) && '$IsObject(tAfterCaught)
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("target", tTarget, "string")
    Do tEffects.%Set("daysToArchive", +tFacts("days"), "number")
    Do tEffects.%Set("processed", +$Piece(tCounts, ",", 1), "number")
    Do tEffects.%Set("archived", +$Piece(tCounts, ",", 2), "number")
    Do tEffects.%Set("headersDeleted", +$Piece(tCounts, ",", 3), "number")
    Do tEffects.%Set("bodiesDeleted", +$Piece(tCounts, ",", 4), "number")
    Do tEffects.%Set("errors", tErrors, "number")
    Do tEffects.%Set("completed", tCompleted, "boolean")
    Do ..AuditRuntime(..#VERBARCHIVE, ..#ENTITYARCHIVE, pNamespace, tEffects)
    If $IsObject(tRaised) Quit ..Statused(..ArchiveVendorStatus(tRaised.AsStatus()), "the archive failed", .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(..ArchiveVendorStatus(tVendorSC), "the archive failed", .pHttpStatus, .pFault)
    If 'tCompleted Quit ..Statused($$$ERROR($$$GeneralError, "the vendor reported the archive with " _ tErrors _ " errors"), "the archive failed", .pHttpStatus, .pFault)
    Set tReadSC = ..ReadArchive(pNamespace, "", .tRow, .tReadHttp, .tReadFault)
    If $$$ISERR(tReadSC) || '$IsObject(tRow) {
        Set tRow = {}
        Do tRow.%Set("Namespace", pNamespace, "string")
    }
    Set pResult = tRow
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>The lines <method>Snippet</method> adds for the archive setting <var>pName</var> set to <var>pBody</var>'s value in <var>pNamespace</var> (Story 24.16 Batch 4): the vendor's two
/// reads and <code>SetArchiveParameters</code> with the one value replaced, as a string literal for a namespace and a whole number for the days. <code>""</code> for a name or a value the
/// port would refuse, which renders no draft.</p>
ClassMethod ArchiveSettingSnippet(pName As %String, pBody As %DynamicAbstractObject, pNamespace As %String) As %String [ Private ]
{
    Set tEntry = ..ArchiveSettingEntry(pName)
    If (tEntry = "") || ..ArchiveSettingReadOnly(pName) || '$IsObject(pBody) || (pBody.%GetTypeOf("Value") '= "string") Quit ""
    Set tValue = pBody.%Get("Value")
    If '##class(OcuPilot.Area.Interop.ArchiveSettingRules).ValueHolds(..ArchiveSettingLimits(pName, pNamespace), tValue) Quit ""
    Set tNL = $Char(10)
    Set tText = tNL _ " Do ##class(Ens.Archive.Manager).GetArchiveParameters(.tTarget, .tClass, .tDays)"
    If $List(tEntry, 2) = "Namespace" {
        Set tText = tText _ tNL _ " Set tTarget = " _ ..Literal(tValue)
    } Else {
        Set tText = tText _ tNL _ " Set tDays = " _ +tValue
    }
    Quit tText _ tNL _ " Set tSC = ##class(Ens.Archive.Manager).SetArchiveParameters(tTarget, tClass, tDays)"
}

/// <p>The lines <method>Snippet</method> adds for the archive run (Story 24.16 Batch 4): the settings read, each refusal as one guard that stops the run, the vendor's lock taken at once,
/// <code>Ens.Archive.Manager.DoArchive</code> called while it is held, and the lock let go. Nothing here runs; a person runs it.</p>
ClassMethod ArchiveSnippet() As %String [ Private ]
{
    Set tNL = $Char(10)
    Set tText = tNL _ " Do ##class(Ens.Archive.Manager).GetArchiveParameters(.tTarget, .tClass, .tDays)"
    Set tText = tText _ tNL _ " Set tOk = 1"
    Set tText = tText _ tNL _ " If tClass '= " _ ..Literal(..#ARCHIVECLASSNAME) _ " Set tOk = 0, tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.InteropError).ReasonFor(##class(OcuPilot.Api.InteropError).#ARCHIVECLASS)) _ ")"
    Set tText = tText _ tNL _ " If tOk, (tTarget = """") || (tTarget = $Namespace) || '$Data(^%SYS(""Ensemble"", ""InstalledNamespace"", tTarget)) Set tOk = 0, tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.InteropError).ReasonFor(##class(OcuPilot.Api.InteropError).#ARCHIVENOTARGET)) _ ")"
    Set tText = tText _ tNL _ " If tOk { &sql(SELECT COUNT(*) INTO :tTotal FROM Ens.MessageHeader) If tTotal > " _ ..#ARCHIVEMAXMESSAGES _ " Set tOk = 0, tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.InteropError).ReasonFor(##class(OcuPilot.Api.InteropError).#ARCHIVETOOMANY)) _ ") }"
    Set tText = tText _ tNL _ " If tOk { Set tRS = ##class(%SQL.Statement).%ExecDirect(, ""SELECT ID FROM Ens.MessageHeader WHERE TimeCreated IS NULL OR TimeCreated < ?"", ##class(Ens.Purge).GetDoNotDeleteDate(tDays)) While tRS.%Next() { If $Data(^|tTarget|Ens.MessageHeaderD(tRS.%GetData(1))) Set tOk = 0, tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.InteropError).ReasonFor(##class(OcuPilot.Api.InteropError).#ARCHIVETAKEN)) _ ") Quit } }"
    Set tText = tText _ tNL _ " If tOk { Lock +^Ens.ArchiveManager(""lock""):0 Set tHeld = $Test If 'tHeld Set tOk = 0, tSC = $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.InteropError).ReasonFor(##class(OcuPilot.Api.InteropError).#ARCHIVERUNNING)) _ ") }"
    Set tText = tText _ tNL _ " If tOk Set tSC = ##class(Ens.Archive.Manager).DoArchive()"
    Set tText = tText _ tNL _ " If $Get(tHeld) Lock -^Ens.ArchiveManager(""lock"")"
    Quit tText
}

/// <p>The Managed alerts endpoint (Story 24.17 Batch 1): <code>LIST</code> (the namespace's <code>Ens.Alerting.ManagedAlert</code> rows, newest first), <code>ALERT</code> (one alert's state, which the
/// update's review and fingerprint read), <code>ALERTOWNERS</code> (who the classic form offers as an owner) and the write <code>UPDATEALERT</code>, the vendor's
/// <code>UpdateManagedAlert</code>. The values of an update travel in the query under <parameter>ALERTOWNERKEY</parameter> and its four siblings, an absent one meaning unchanged.</p>
Parameter ENDPOINTMANAGEDALERTS = "ManagedAlerts";

/// <p>The Managed alert actions endpoint (Story 24.17 Batch 1): <code>LIST</code> of one alert's history, newest first, the alert named under <parameter>ALERTCRITERION</parameter>.</p>
Parameter ENDPOINTMANAGEDALERTACTIONS = "ManagedAlertActions";

/// <p>The pairs both endpoints require: the portal's and the classic Alerts page's and Managed Alert Viewer's own <code>%Ens_Alerts:READ</code>. The owner choices and the update add
/// <parameter>ALERTWRITEPAIR</parameter>, the classic Alerts page's edit resource (and WRITE on the namespace's globals database, the gate's); an update of an alert another user owns also
/// needs <parameter>ALERTADMINRESOURCE</parameter> at <parameter>ALERTADMINPERMISSION</parameter>, judged at the write.</p>
Parameter ALERTPAIRS = "%Ens_Portal:USE,%Ens_Alerts:READ";

Parameter ALERTWRITEPAIR = "%Ens_Alerts:WRITE";

Parameter ALERTADMINRESOURCE = "%Ens_AlertAdministration";

Parameter ALERTADMINPERMISSION = "USE";

Parameter TYPEALERT = "ALERT";

Parameter TYPEALERTOWNERS = "ALERTOWNERS";

Parameter TYPEUPDATEALERT = "UPDATEALERT";

/// <p>The most alerts a list answers to a call that names no cap of its own: the larger of 1,000 and 2,000 whose read ended within 5 seconds with three history rows each (0.04 seconds at 2,000,
/// measured). A call that names a cap gets that many, so the one row it asks for beyond what it shows reports its truncation (AD-36).</p>
Parameter ALERTSMAX As INTEGER = 2000;

/// <p>The most history rows one alert's list answers to a call that names no cap of its own.</p>
Parameter ALERTACTIONSMAX As INTEGER = 1000;

/// <p>The most minutes a next action time may be set ahead, two weeks, and the most characters of a reason (the vendor's <code>Ens.Alerting.Action.Reason</code>).</p>
Parameter ALERTNEXTMAX As INTEGER = 20160;

Parameter ALERTREASONMAX As INTEGER = 500;

/// <p>The shape of an alert's id: a whole number without a leading zero.</p>
Parameter ALERTIDPATTERN = "^[1-9][0-9]{0,17}$";

/// <p>The criterion of the history list: the alert's id.</p>
Parameter ALERTCRITERION = "alert";

/// <p>The query keys of an update's values, each present only when the caller sends that value.</p>
Parameter ALERTOWNERKEY = "alertowner";

Parameter ALERTOPENKEY = "alertopen";

Parameter ALERTLEVELKEY = "alertlevel";

Parameter ALERTMINUTESKEY = "alertminutes";

Parameter ALERTREASONKEY = "alertreason";

/// <p>The vendor's action bits (<code>EnsConstants.inc</code>): the four an update sets. The send-update and reoccurrence bits are never sent.</p>
Parameter ALERTBITOWNER As INTEGER = 1;

Parameter ALERTBITOPEN As INTEGER = 2;

Parameter ALERTBITLEVEL As INTEGER = 4;

Parameter ALERTBITNEXT As INTEGER = 8;

Parameter ENTITYALERT = "interop-managed-alert";

Parameter VERBALERTUPDATE = "update";

/// <p>The columns of a list row, in the order <method>AlertRow</method> reads them.</p>
Parameter ALERTCOLUMNS = "ID, AlertTime, AlertText, SourceConfigName, Production, SessionId, CurrentOwner, EscalationLevel, IsOpen, LastActionTime, NextActionTime";

/// <p>The columns of a history row, in the order <method>AlertActionRow</method> reads them.</p>
Parameter ALERTACTIONCOLUMNS = "Actions_ActionTime, Actions_Username, Actions_Action, Actions_Reason, Actions_OldValues, Actions_NewValues";

/// <p>Whether <var>pType</var> is the managed alert update, which needs WRITE on the namespace's globals database.</p>
ClassMethod IsAlertWrite(pType As %String) As %Boolean
{
    Quit pType = ..#TYPEUPDATEALERT
}

/// <p>The most rows a managed alert read answers: <var>pMax</var> when it is above zero, else <var>pLimit</var>, as the other capped lists of this port answer. Pure.</p>
ClassMethod AlertCap(pMax As %Integer, pLimit As %Integer) As %Integer
{
    Quit $Select(pMax > 0: pMax, 1: pLimit)
}

/// <p>Whether <var>pId</var> has an alert id's shape. Pure.</p>
ClassMethod AlertIdOK(pId As %String) As %Boolean
{
    Quit $Match(pId, ..#ALERTIDPATTERN)
}

/// <p>Whether <var>pReason</var> is 1 to <parameter>ALERTREASONMAX</parameter> characters with no control character. Pure.</p>
ClassMethod AlertReasonOK(pReason As %String) As %Boolean
{
    Quit ($Length(pReason) > 0) && ($Length(pReason) '> ..#ALERTREASONMAX) && ($ZStrip(pReason, "*C") = pReason)
}

/// <p>Whether <var>pMinutes</var> is a whole number from 1 to <parameter>ALERTNEXTMAX</parameter>, written without a sign, a point or a leading zero. Pure.</p>
ClassMethod AlertMinutesOK(pMinutes As %String) As %Boolean
{
    Quit $Match(pMinutes, "^[1-9][0-9]{0,4}$") && (+pMinutes '> ..#ALERTNEXTMAX)
}

/// <p>Whether <var>pLevel</var> is a whole number written without a sign, a point or a leading zero. Pure.</p>
ClassMethod AlertLevelShapeOK(pLevel As %String) As %Boolean
{
    Quit $Match(pLevel, "^(0|[1-9][0-9]{0,8})$")
}

/// <p>Whether <var>pOwner</var> is a plausible owner name: at most 256 characters and no control character. The owner list judges the rest. Pure.</p>
ClassMethod AlertOwnerShapeOK(pOwner As %String) As %Boolean
{
    Quit ($Length(pOwner) '> 256) && ($ZStrip(pOwner, "*C") = pOwner)
}

/// <p>The published sentence a value of kind <var>pKind</var> (<code>id</code>, <code>owner</code>, <code>level</code>, <code>minutes</code> or <code>reason</code>) is refused with, which the
/// update tool's argument rules answer with, or <code>""</code> for another kind. Pure.</p>
ClassMethod AlertProblem(pKind As %String) As %String
{
    Set tCode = $Case(pKind, "id": ##class(OcuPilot.Api.InteropError).#ALERTNOTFOUND, "owner": ##class(OcuPilot.Api.InteropError).#ALERTOWNER, "level": ##class(OcuPilot.Api.InteropError).#ALERTLEVEL, "minutes": ##class(OcuPilot.Api.InteropError).#ALERTNEXTACTION, "reason": ##class(OcuPilot.Api.InteropError).#ALERTREASON, : "")
    If tCode = "" Quit ""
    Quit ##class(OcuPilot.Api.InteropError).ReasonFor(tCode)
}

/// <p>A point inside each namespace-switched block of the owner list and the update, which does nothing. A fixture overrides it to raise a fault there, so a test reads that the fault is
/// logged after the namespace is restored; production never overrides it.</p>
ClassMethod AlertHere() [ Private ]
{
}

/// <p>The vendor's update of alert <var>pId</var> in the current namespace, which the caller has already switched: <code>Ens.Alerting.ManagedAlert.UpdateManagedAlert</code> with
/// <var>pBits</var>, the new values in <var>pChanges</var> by property name and the reason. Overridable so a fixture can answer a status or a fault; production never overrides it.</p>
ClassMethod VendorAlertUpdate(pId As %String, pBits As %Integer, ByRef pChanges, pReason As %String) As %Status
{
    Quit ##class(Ens.Alerting.ManagedAlert).UpdateManagedAlert(pId, pBits, .pChanges, pReason)
}

/// <p>A vendor exception <var>pException</var> in this port's own words, as <method>ArchiveMapped</method> answers one: the status it logs carries the vendor's error codes alone.</p>
ClassMethod AlertMapped(pException As %Exception.AbstractException, pMessage As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Statused(..VendorCodesStatus(pException.AsStatus(), "the managed alert call"), pMessage, .pHttpStatus, .pFault)
}

/// <p>404 <code>INTEROP.ALERT.NOTFOUND</code>: the alert is not there.</p>
ClassMethod AlertGone(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.InteropError).#ALERTNOTFOUND, ##class(OcuPilot.Api.InteropError).#REASONALERTNOTFOUND, .pHttpStatus, .pFault)
}

/// <p>One list row of the columns <parameter>ALERTCOLUMNS</parameter> read as <var>pLine</var>: <code>{ID, AlertTime, AlertText, SourceConfigName, Production, SessionId, CurrentOwner,
/// EscalationLevel, IsOpen, LastActionTime, NextActionTime, Namespace}</code>, the times as the instance's local time as the other lists show them.</p>
ClassMethod AlertRow(pLine As %List, pNamespace As %String) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("ID", $List(pLine, 1) _ "", "string")
    Do tRow.%Set("AlertTime", ..AlertLocal($List(pLine, 2)), "string")
    Do tRow.%Set("AlertText", ..AlertText($List(pLine, 3)), "string")
    Do tRow.%Set("SourceConfigName", ..AlertText($List(pLine, 4)), "string")
    Do tRow.%Set("Production", ..AlertText($List(pLine, 5)), "string")
    Do tRow.%Set("SessionId", ..AlertText($List(pLine, 6)), "string")
    Do tRow.%Set("CurrentOwner", ..AlertText($List(pLine, 7)), "string")
    Do tRow.%Set("EscalationLevel", +$List(pLine, 8), "number")
    Do tRow.%Set("IsOpen", ''$List(pLine, 9), "boolean")
    Do tRow.%Set("LastActionTime", ..AlertLocal($List(pLine, 10)), "string")
    Do tRow.%Set("NextActionTime", ..AlertLocal($List(pLine, 11)), "string")
    Do tRow.%Set("Namespace", pNamespace, "string")
    Quit tRow
}

/// <p>A stored text as it reads: <code>$Char(0)</code>, which a cleared string column reads as, is empty. Pure.</p>
ClassMethod AlertText(pValue As %String) As %String [ Private ]
{
    Quit $Select(pValue = $Char(0): "", 1: pValue _ "")
}

/// <p>The stored UTC stamp <var>pUtc</var> as the instance's local time, or <code>""</code>.</p>
ClassMethod AlertLocal(pUtc As %String) As %String [ Private ]
{
    Set tText = ..AlertText(pUtc)
    If tText = "" Quit ""
    Quit ..LocalStamp(tText)
}

/// <p>The whole minutes from now until the stored UTC stamp <var>pNext</var>, rounded to the nearest minute, or <code>""</code> when it is empty or unreadable. Reads the clock.</p>
ClassMethod AlertNextMinutes(pNext As %String) As %String [ Private ]
{
    If pNext = "" Quit ""
    Set tNext = ""
    Try {
        Set tNext = $ZDateTimeH(pNext, 3)
    } Catch {
        Set tNext = ""
    }
    If tNext = "" Quit ""
    Set tNow = $ZTimeStamp
    Set tSeconds = (($Piece(tNext, ",", 1) - $Piece(tNow, ",", 1)) * 86400) + ($Piece(tNext, ",", 2) - $Piece(tNow, ",", 2))
    Quit (tSeconds + 30) \ 60
}

/// <p>The managed alerts of <var>pNamespace</var>, newest first, at most <var>pMax</var> (<parameter>ALERTSMAX</parameter> when that is not above zero): <code>{ID, AlertTime, AlertText, SourceConfigName,
/// Production, SessionId, CurrentOwner, EscalationLevel, IsOpen, LastActionTime, NextActionTime, Namespace}</code>. The criterion <code>open</code> is <code>yes</code> or <code>no</code>; absent lists all.
/// Every value is bound. A longer list than the cap is the caller's truncation, which it reads from the one row it asked for beyond its own cap.</p>
ClassMethod ListAlerts(pNamespace As %String, ByRef pQuery, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tOpen = $Get(pQuery("open"))
    If (tOpen '= "") && (tOpen '= "yes") && (tOpen '= "no") Quit ..RefuseCriterion("open", .pHttpStatus, .pFault)
    Kill tArgs
    Set tArgs = 1
    Set tArgs(1) = ..AlertCap(pMax, ..#ALERTSMAX)
    Set tSql = "SELECT TOP ? " _ ..#ALERTCOLUMNS _ " FROM Ens_Alerting.ManagedAlert"
    If tOpen '= "" {
        Set tSql = tSql _ " WHERE IsOpen = ?"
        Set tArgs(2) = (tOpen = "yes")
        Set tArgs = 2
    }
    Set tSql = tSql _ " ORDER BY ID DESC"
    Set tSC = ..SqlRows(pNamespace, tSql, .tFound, .tCaught, tArgs...)
    If $IsObject(tCaught) Quit ..AlertMapped(tCaught, "the managed alert list failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..AlertRow(tFound(tI), pNamespace))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>A stored array of name and value pairs (<code>$ListBuild($ListBuild(name, value), ...)</code>) as the text <code>Name: value</code> joined by <code>; </code>. Pure.</p>
ClassMethod AlertValuesText(pStored As %String) As %String [ Private ]
{
    Set tText = ""
    If '$ListValid(pStored) Quit tText
    For tI = 1:1:$ListLength(pStored) {
        Set tPair = $List(pStored, tI)
        If '$ListValid(tPair) || ($ListLength(tPair) < 1) Continue
        Set tText = tText _ $Select(tText = "": "", 1: "; ") _ $List(tPair, 1) _ ": " _ $ListGet(tPair, 2)
    }
    Quit tText
}

/// <p>One history row of the columns <parameter>ALERTACTIONCOLUMNS</parameter> read as <var>pLine</var>: <code>{ActionTime, Username, Action, Reason, OldValues, NewValues}</code>, the action as the vendor's
/// own words (<code>Ens.DataType.ManagedAlertAction.GetText</code>), the time as the instance's local time.</p>
ClassMethod AlertActionRow(pLine As %List) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("ActionTime", ..AlertLocal($List(pLine, 1)), "string")
    Do tRow.%Set("Username", ..AlertText($List(pLine, 2)), "string")
    Do tRow.%Set("Action", ##class(Ens.DataType.ManagedAlertAction).GetText(+$List(pLine, 3)), "string")
    Do tRow.%Set("Reason", ..AlertText($List(pLine, 4)), "string")
    Do tRow.%Set("OldValues", ..AlertValuesText($List(pLine, 5)), "string")
    Do tRow.%Set("NewValues", ..AlertValuesText($List(pLine, 6)), "string")
    Quit tRow
}

/// <p>The history of the alert named under <parameter>ALERTCRITERION</parameter>, newest first, at most <var>pMax</var> rows (<parameter>ALERTACTIONSMAX</parameter> when that is not above zero):
/// <code>{ActionTime, Username, Action, Reason, OldValues, NewValues}</code>. A missing or malformed id is a 400 naming the criterion; an alert that is gone has no rows.</p>
ClassMethod ListAlertActions(pNamespace As %String, ByRef pQuery, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tId = $Get(pQuery(..#ALERTCRITERION))
    If '..AlertIdOK(tId) Quit ..RefuseCriterion(..#ALERTCRITERION, .pHttpStatus, .pFault)
    Set tSql = "SELECT TOP ? " _ ..#ALERTACTIONCOLUMNS _ " FROM Ens_Alerting.ManagedAlert_Actions WHERE ManagedAlert = ? ORDER BY element_key DESC"
    Set tSC = ..SqlRows(pNamespace, tSql, .tFound, .tCaught, ..AlertCap(pMax, ..#ALERTACTIONSMAX), +tId)
    If $IsObject(tCaught) Quit ..AlertMapped(tCaught, "the managed alert history failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..AlertActionRow(tFound(tI)))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The alert <var>pId</var> of <var>pNamespace</var> as it stands, in <var>pFacts</var>: <code>found</code> (1 or 0), <code>owner</code>, <code>open</code> (0 or 1), <code>level</code>,
/// <code>next</code> (the stored UTC stamp) and <code>count</code> (history rows). A fault is <var>pCaught</var>. Nothing is written.</p>
ClassMethod AlertFacts(pNamespace As %String, pId As %String, Output pFacts, Output pCaught) [ Private ]
{
    Kill pFacts
    Set pFacts("found") = 0
    Set pCaught = ""
    If '..AlertIdOK(pId) Quit
    Set tSC = ..SqlRows(pNamespace, "SELECT CurrentOwner, IsOpen, EscalationLevel, NextActionTime FROM Ens_Alerting.ManagedAlert WHERE ID = ?", .tFound, .pCaught, +pId)
    If $IsObject(pCaught) || 'tFound Quit
    Set pFacts("found") = 1
    Set pFacts("owner") = ..AlertText($List(tFound(1), 1))
    Set pFacts("open") = ''$List(tFound(1), 2)
    Set pFacts("level") = +$List(tFound(1), 3)
    Set pFacts("next") = ..AlertText($List(tFound(1), 4))
    Set tSC = ..SqlRows(pNamespace, "SELECT COUNT(*) FROM Ens_Alerting.ManagedAlert_Actions WHERE ManagedAlert = ?", .tCount, .pCaught, +pId)
    If $IsObject(pCaught) Quit
    Set pFacts("count") = +$List($Get(tCount(1)), 1)
}

/// <p>Whether the caller may update an alert whose stored owner is <var>pOwner</var>, as the vendor's own save rule reads it: an unassigned alert or the caller's own needs nothing more, and another
/// user's needs <parameter>ALERTADMINRESOURCE</parameter> at <parameter>ALERTADMINPERMISSION</parameter>, which <var>pFailedPair</var> names when it is not held.</p>
ClassMethod AlertAdminHeld(pOwner As %String, Output pFailedPair As %String) As %Boolean [ Private ]
{
    Set pFailedPair = ""
    If (pOwner = "") || (pOwner = $USERNAME) Quit 1
    Quit $ClassMethod(..GateClass(), "EvaluateRequired", $ListBuild($ListBuild(..#ALERTADMINRESOURCE, ..#ALERTADMINPERMISSION)), .pFailedPair)
}

/// <p>The state row of alert <var>pId</var> (Story 24.17 Batch 1): <code>{ID, CurrentOwner, IsOpen, EscalationLevel, NextActionTime, ActionCount, Namespace}</code>, the next action time as stored.
/// With <var>pAction</var> <parameter>TYPEUPDATEALERT</parameter> the caller's right to update the alert (<method>AlertAdminHeld</method>) and the values the query carries are judged as the
/// write judges them (<method>AlertJudge</method>), so a refusal is answered before anything is stored.</p>
ClassMethod ReadAlert(pNamespace As %String, pId As %String, pAction As %String, ByRef pQuery, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Do ..AlertFacts(pNamespace, pId, .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..AlertMapped(tCaught, "the managed alert read failed", .pHttpStatus, .pFault)
    If 'tFacts("found") Quit ..AlertGone(.pHttpStatus, .pFault)
    If (pAction = ..#TYPEUPDATEALERT) && '..AlertAdminHeld(tFacts("owner"), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    ; A review that carries no value yet (the dry run that opens the update dialog) reads the state alone.
    If (pAction = ..#TYPEUPDATEALERT) && ..AlertHasValues(.pQuery) {
        Set tSC = ..AlertJudge(pNamespace, .pQuery, .tFacts, .tValues, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
    }
    Set pRow = {}
    Do pRow.%Set("ID", pId, "string")
    Do pRow.%Set("CurrentOwner", tFacts("owner"), "string")
    Do pRow.%Set("IsOpen", ''tFacts("open"), "boolean")
    Do pRow.%Set("EscalationLevel", tFacts("level"), "number")
    Do pRow.%Set("NextActionTime", tFacts("next"), "string")
    Do pRow.%Set("ActionCount", tFacts("count"), "number")
    Do pRow.%Set("Namespace", pNamespace, "string")
    ; The values an update sets, answered as what the alert holds, so a merge that sets one to that leaves it unchanged; the reason reads empty. The next action's minutes read empty
    ; for a review and, for the re-read of a stored update (no action) that carries minutes, are the minutes left until the stored next action time, as text like the review's, which the read-back compares.
    Do pRow.%Set("Owner", tFacts("owner"), "string")
    Do pRow.%Set("Open", ''tFacts("open"), "boolean")
    Set tMinutes = ""
    If (pAction '= ..#TYPEUPDATEALERT) && $Data(pQuery(..#ALERTMINUTESKEY)) Set tMinutes = ..AlertNextMinutes(tFacts("next"))
    Do pRow.%Set("NextActionMinutes", tMinutes, "string")
    Do pRow.%Set("Reason", "", "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The owners the classic form offers for <var>pNamespace</var> (<code>%SYS.Ensemble.ListAlertingUsers</code> limited to the namespace), sorted, in <var>pNames</var> as a <class>%List</class>.
/// The vendor adds <code>%All</code> inside its own frame; the process's roles, user and namespace read the same after it (measured). A fault is <var>pCaught</var>, with the namespace restored.</p>
ClassMethod AlertOwnerNames(pNamespace As %String, Output pNames As %List, Output pCaught, Output pStatus As %Status) [ Private ]
{
    Set pNames = ""
    Set pCaught = ""
    Set pStatus = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..AlertHere()
        Kill tUsers
        Set pStatus = ##class(%SYS.Ensemble).ListAlertingUsers(.tUsers, pNamespace)
        Set $NAMESPACE = tOrigNS
        Set tName = ""
        For {
            Set tName = $Order(tUsers(tName))
            If tName = "" Quit
            Set pNames = pNames _ $ListBuild(tName)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>The owner choices (Story 24.17 Batch 1): <code>{Name, Namespace}</code> for each user the classic form lists as one who can work on managed alerts in <var>pNamespace</var>.</p>
ClassMethod ListAlertOwners(pNamespace As %String, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Do ..AlertOwnerNames(pNamespace, .tNames, .tCaught, .tStatus)
    If $IsObject(tCaught) Quit ..AlertMapped(tCaught, "the managed alert owners could not be listed", .pHttpStatus, .pFault)
    If $$$ISERR(tStatus) Quit ..Statused(..VendorCodesStatus(tStatus, "the managed alert owners"), "the managed alert owners could not be listed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:$ListLength(tNames) {
        Set tRow = {}
        Do tRow.%Set("Name", $List(tNames, tI), "string")
        Do tRow.%Set("Namespace", pNamespace, "string")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The update's values in <var>pQuery</var> as <var>pValues</var>, each member present only when the query carries it: <code>owner</code>, <code>open</code> (0 or 1), <code>level</code>,
/// <code>minutes</code> and <code>reason</code>. Answers 0 when the open state is neither <code>0</code> nor <code>1</code>. Pure.</p>
ClassMethod AlertValues(ByRef pQuery, Output pValues) As %Boolean [ Private ]
{
    Kill pValues
    If $Data(pQuery(..#ALERTOWNERKEY)) Set pValues("owner") = pQuery(..#ALERTOWNERKEY)
    If $Data(pQuery(..#ALERTLEVELKEY)) Set pValues("level") = pQuery(..#ALERTLEVELKEY)
    If $Data(pQuery(..#ALERTMINUTESKEY)) Set pValues("minutes") = pQuery(..#ALERTMINUTESKEY)
    Set pValues("reason") = $Get(pQuery(..#ALERTREASONKEY))
    If $Data(pQuery(..#ALERTOPENKEY)) {
        Set tOpen = pQuery(..#ALERTOPENKEY)
        If (tOpen '= 0) && (tOpen '= 1) Quit 0
        Set pValues("open") = +tOpen
    }
    Quit 1
}

/// <p>Whether <var>pQuery</var> carries any of an update's values. Pure.</p>
ClassMethod AlertHasValues(ByRef pQuery) As %Boolean [ Private ]
{
    Quit $Data(pQuery(..#ALERTOWNERKEY)) || $Data(pQuery(..#ALERTOPENKEY)) || $Data(pQuery(..#ALERTLEVELKEY)) || $Data(pQuery(..#ALERTMINUTESKEY)) || $Data(pQuery(..#ALERTREASONKEY))
}

/// <p>Judge the update's values against the alert as it stands (<var>pFacts</var>), in the order the spec names them: the owner (unassigned, the caller, or one of
/// <method>AlertOwnerNames</method>), the escalation level (the current level or one step up or down, never below 0), the next action minutes, the reason, and then that something would change.
/// Each value outside its rule is 422 with its own code, the first one naming the answer; nothing differing is 409 <code>INTEROP.ALERT.UNCHANGED</code>. <var>pValues</var> is
/// <method>AlertValues</method>'s. Judged before any vendor call; nothing is written.</p>
ClassMethod AlertJudge(pNamespace As %String, ByRef pQuery, ByRef pFacts, Output pValues, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    If '..AlertValues(.pQuery, .pValues) Quit ..RefuseCriterion("Open", .pHttpStatus, .pFault)
    Set tViolations = 0
    If $Data(pValues("owner")) && (pValues("owner") '= pFacts("owner")) {
        Set tOwner = pValues("owner")
        Set tOk = ..AlertOwnerShapeOK(tOwner) && ((tOwner = "") || (tOwner = $USERNAME))
        If 'tOk && ..AlertOwnerShapeOK(tOwner) {
            Do ..AlertOwnerNames(pNamespace, .tNames, .tCaught, .tStatus)
            If $IsObject(tCaught) Quit ..AlertMapped(tCaught, "the managed alert owners could not be listed", .pHttpStatus, .pFault)
            If $$$ISERR(tStatus) Quit ..Statused(..VendorCodesStatus(tStatus, "the managed alert owners"), "the managed alert owners could not be listed", .pHttpStatus, .pFault)
            Set tOk = ''$ListFind(tNames, tOwner)
        }
        If 'tOk Set tViolations($Increment(tViolations)) = $ListBuild("Owner", ##class(OcuPilot.Api.InteropError).#ALERTOWNER)
    }
    If $Data(pValues("level")) {
        Set tLevel = pValues("level")
        If '..AlertLevelShapeOK(tLevel) || ($ZAbs(tLevel - pFacts("level")) > 1) Set tViolations($Increment(tViolations)) = $ListBuild("EscalationLevel", ##class(OcuPilot.Api.InteropError).#ALERTLEVEL)
    }
    If $Data(pValues("minutes")) && '..AlertMinutesOK(pValues("minutes")) Set tViolations($Increment(tViolations)) = $ListBuild("NextActionMinutes", ##class(OcuPilot.Api.InteropError).#ALERTNEXTACTION)
    If '..AlertReasonOK(pValues("reason")) Set tViolations($Increment(tViolations)) = $ListBuild("Reason", ##class(OcuPilot.Api.InteropError).#ALERTREASON)
    If tViolations Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    Set tChanges = 0
    If $Data(pValues("owner")) && (pValues("owner") '= pFacts("owner")) Set tChanges = tChanges + 1
    If $Data(pValues("open")) && (pValues("open") '= pFacts("open")) Set tChanges = tChanges + 1
    If $Data(pValues("level")) && (+pValues("level") '= pFacts("level")) Set tChanges = tChanges + 1
    If $Data(pValues("minutes")) Set tChanges = tChanges + 1
    If 'tChanges Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ALERTUNCHANGED, .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>Serve the ManagedAlerts and ManagedAlertActions endpoints after <method>Invoke</method>'s gate (Story 24.17 Batch 1): the lists, the <code>ALERT</code> read, the <code>ALERTOWNERS</code> read
/// and the write <code>UPDATEALERT</code>.</p>
ClassMethod InvokeAlerts(pNamespace As %String, pEndpoint As %String, pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType = ..#TYPELIST {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            If pEndpoint = ..#ENDPOINTMANAGEDALERTACTIONS {
                Set tSC = ..ListAlertActions(pNamespace, .pQuery, +tMaxText, .pResult, .pHttpStatus, .pFault)
            } Else {
                Set tSC = ..ListAlerts(pNamespace, .pQuery, +tMaxText, .pResult, .pHttpStatus, .pFault)
            }
            Quit
        }
        If pType = ..#TYPEALERTOWNERS {
            Set tSC = ..ListAlertOwners(pNamespace, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tAction = $Select(..IsAlertWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && (tAction '= ..#TYPEUPDATEALERT) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tId = $Get(pQuery(..#IDKEY))
        If pType = ..#TYPEUPDATEALERT {
            Set tSC = ..PerformAlertUpdate(pNamespace, tId, .pQuery, .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..ReadAlert(pNamespace, tId, tAction, .pQuery, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..AlertMapped(ex, "the managed alert call failed inside the port", .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Update alert <var>pId</var> of <var>pNamespace</var> as the classic Alerts page's Update does (Story 24.17 Batch 1), through the vendor's own
/// <code>UpdateManagedAlert</code> with only the values that differ and their bits, in this request and with no transaction. The sequence, each refusal before any vendor call:</p>
/// <ol>
/// <li>An alert that is gone, or an id of the wrong shape: 404 <code>INTEROP.ALERT.NOTFOUND</code>.</li>
/// <li>An alert another user owns needs <code>%Ens_AlertAdministration:USE</code>, 403 naming the pair.</li>
/// <li>The values (<method>AlertJudge</method>): 422 for a value outside its rule, 409 <code>INTEROP.ALERT.UNCHANGED</code> when none differs.</li>
/// <li>The vendor's update runs in the namespace; the namespace is restored; OcuPilot's own audit row is recorded (<method>AuditRuntime</method>) whatever the vendor answered, naming the namespace,
/// each changed field with its new value and whether it completed, and never the reason. A vendor error is 500 <code>INTERNAL</code>.</li>
/// </ol>
ClassMethod PerformAlertUpdate(pNamespace As %String, pId As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Do ..AlertFacts(pNamespace, pId, .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..AlertMapped(tCaught, "the managed alert read failed", .pHttpStatus, .pFault)
    If 'tFacts("found") Quit ..AlertGone(.pHttpStatus, .pFault)
    If '..AlertAdminHeld(tFacts("owner"), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    Set tSC = ..AlertJudge(pNamespace, .pQuery, .tFacts, .tValues, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    ; Only what differs goes to the vendor, with its bits, as the classic form sends it.
    Kill tChanges
    Set tBits = 0
    Set tEffects = {}
    Set tChanged = {}
    If $Data(tValues("owner")) && (tValues("owner") '= tFacts("owner")) {
        Set tChanges("CurrentOwner") = tValues("owner")
        Set tBits = tBits + ..#ALERTBITOWNER
        Do tChanged.%Set("CurrentOwner", tValues("owner"), "string")
    }
    If $Data(tValues("open")) && (tValues("open") '= tFacts("open")) {
        Set tChanges("IsOpen") = tValues("open")
        Set tBits = tBits + ..#ALERTBITOPEN
        Do tChanged.%Set("IsOpen", ''tValues("open"), "boolean")
    }
    If $Data(tValues("level")) && (+tValues("level") '= tFacts("level")) {
        Set tChanges("EscalationLevel") = +tValues("level")
        Set tBits = tBits + ..#ALERTBITLEVEL
        Do tChanged.%Set("EscalationLevel", +tValues("level"), "number")
    }
    If $Data(tValues("minutes")) {
        Set tNext = $System.SQL.DATEADD("mi", +tValues("minutes"), $ZDateTime($ZTimeStamp, 3, , 3))
        Set tChanges("NextActionTime") = tNext
        Set tBits = tBits + ..#ALERTBITNEXT
        Do tChanged.%Set("NextActionTime", tNext, "string")
    }
    Set tVendorSC = $$$OK
    Set tRaised = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..AlertHere()
        Set tVendorSC = ..VendorAlertUpdate(pId, tBits, .tChanges, tValues("reason"))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tRaised = ex
    }
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("changed", tChanged)
    Do tEffects.%Set("completed", $$$ISOK(tVendorSC) && '$IsObject(tRaised), "boolean")
    Do ..AuditRuntime(..#VERBALERTUPDATE, ..#ENTITYALERT, pId, tEffects)
    If $IsObject(tRaised) Quit ..Statused(..VendorCodesStatus(tRaised.AsStatus(), "the managed alert update"), "the managed alert update failed", .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(..VendorCodesStatus(tVendorSC, "the managed alert update"), "the managed alert update failed", .pHttpStatus, .pFault)
    Set tReadSC = ..ReadAlert(pNamespace, pId, "", .pQuery, .tRow, .tReadHttp, .tReadFault)
    If $$$ISERR(tReadSC) || '$IsObject(tRow) {
        Set tRow = {}
        Do tRow.%Set("ID", pId, "string")
        Do tRow.%Set("Namespace", pNamespace, "string")
    }
    Set pResult = tRow
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>The lines <method>Snippet</method> adds for the update of alert <var>pId</var> with the values <var>pQuery</var> carries (Story 24.17 Batch 1): the alert read, each refusal as one guard that stops
/// the update, the changed values, and the vendor's <code>UpdateManagedAlert</code>. Every value is rendered as a literal, so nothing the query carries runs as code. <code>""</code> for an id or a value
/// the port would refuse by shape, which renders no draft. Nothing here runs; a person runs it.</p>
ClassMethod AlertSnippet(pId As %String, ByRef pQuery) As %String [ Private ]
{
    If '..AlertIdOK(pId) || '..AlertValues(.pQuery, .tValues) Quit ""
    If $Data(tValues("owner")) && '..AlertOwnerShapeOK(tValues("owner")) Quit ""
    If $Data(tValues("level")) && '..AlertLevelShapeOK(tValues("level")) Quit ""
    If $Data(tValues("minutes")) && '..AlertMinutesOK(tValues("minutes")) Quit ""
    If '..AlertReasonOK(tValues("reason")) Quit ""
    Set tNL = $Char(10)
    Set tError = "$System.Status.Error(5001, "
    Set tText = tNL _ " Set tId = " _ ..Literal(pId) _ ", tOk = 1, tBits = 0"
    Set tText = tText _ tNL _ " If '##class(Ens.Alerting.ManagedAlert).%ExistsId(tId) Set tOk = 0, tSC = " _ tError _ ..Literal(##class(OcuPilot.Api.InteropError).#REASONALERTNOTFOUND) _ ")"
    Set tText = tText _ tNL _ " If tOk Set tAlert = ##class(Ens.Alerting.ManagedAlert).%OpenId(tId)"
    Set tText = tText _ tNL _ " If tOk, (tAlert.CurrentOwner '= """") && (tAlert.CurrentOwner '= $Username) && '$System.Security.Check(" _ ..Literal(..#ALERTADMINRESOURCE) _ ", " _ ..Literal(..#ALERTADMINPERMISSION) _ ") Set tOk = 0, tSC = " _ tError _ ..Literal(##class(OcuPilot.Kernel.Denial).Reason()) _ ")"
    If $Data(tValues("owner")) && (tValues("owner") '= "") {
        Set tText = tText _ tNL _ " If tOk, " _ ..Literal(tValues("owner")) _ " '= tAlert.CurrentOwner { Do ##class(%SYS.Ensemble).ListAlertingUsers(.tOwners, $Namespace) If (" _ ..Literal(tValues("owner")) _ " '= $Username) && '$Data(tOwners(" _ ..Literal(tValues("owner")) _ ")) Set tOk = 0, tSC = " _ tError _ ..Literal(##class(OcuPilot.Api.InteropError).#REASONALERTOWNER) _ ") }"
    }
    If $Data(tValues("level")) {
        Set tText = tText _ tNL _ " If tOk, $ZAbs(" _ +tValues("level") _ " - tAlert.EscalationLevel) > 1 Set tOk = 0, tSC = " _ tError _ ..Literal(##class(OcuPilot.Api.InteropError).#REASONALERTLEVEL) _ ")"
    }
    ; Each line opens no block it does not close, so the script runs pasted line by line (AD-59).
    Set tText = tText _ tNL _ " Kill tNew"
    If $Data(tValues("owner")) Set tText = tText _ tNL _ " If tOk, " _ ..Literal(tValues("owner")) _ " '= tAlert.CurrentOwner Set tNew(""CurrentOwner"") = " _ ..Literal(tValues("owner")) _ ", tBits = tBits + " _ ..#ALERTBITOWNER
    If $Data(tValues("open")) Set tText = tText _ tNL _ " If tOk, " _ tValues("open") _ " '= tAlert.IsOpen Set tNew(""IsOpen"") = " _ tValues("open") _ ", tBits = tBits + " _ ..#ALERTBITOPEN
    If $Data(tValues("level")) Set tText = tText _ tNL _ " If tOk, " _ +tValues("level") _ " '= tAlert.EscalationLevel Set tNew(""EscalationLevel"") = " _ +tValues("level") _ ", tBits = tBits + " _ ..#ALERTBITLEVEL
    If $Data(tValues("minutes")) Set tText = tText _ tNL _ " If tOk Set tNew(""NextActionTime"") = $System.SQL.DATEADD(""mi"", " _ +tValues("minutes") _ ", $ZDateTime($ZTimeStamp, 3, , 3)), tBits = tBits + " _ ..#ALERTBITNEXT
    Set tText = tText _ tNL _ " If tOk, 'tBits Set tOk = 0, tSC = " _ tError _ ..Literal(##class(OcuPilot.Api.InteropError).#REASONALERTUNCHANGED) _ ")"
    Set tText = tText _ tNL _ " If tOk Set tSC = ##class(Ens.Alerting.ManagedAlert).UpdateManagedAlert(tId, tBits, .tNew, " _ ..Literal(tValues("reason")) _ ")"
    Quit tText
}

/// <p>The code prefix of a startup refusal: <code>INTEROP.STARTUP.</code> and the token <method>StartupRefusal</method> answers.</p>
Parameter STARTUPCODEPREFIX = "INTEROP.STARTUP.";

/// <p>The shape violations of a startup write <var>pType</var> over the values <var>pValues</var> (Story 24.3), in
/// <var>pViolations</var> as <code>pViolations(n) = $ListBuild(field, code)</code> with the count in <code>pViolations</code>. For
/// <code>AUTOSTART</code>, <code>pValues("AutoStart")</code> is <code>"1"</code> or <code>"0"</code> and
/// <code>pValues("StartupPriority")</code> an optional minus sign and one to nine digits (<parameter>STARTUPNUMBER</parameter>), or empty
/// beside <code>AutoStart</code> <code>"0"</code>, where it carries nothing; for
/// <code>SHUTDOWNGROUP</code>, <code>pValues("ShutdownGroup")</code> is required and has the same shape. A value that is not a string is
/// the caller's to refuse. Pure.</p>
ClassMethod StartupViolations(pType As %String, ByRef pValues, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    If pType = ..#TYPEAUTOSTART {
        If $Data(pValues("AutoStart")) && (pValues("AutoStart") '= "1") && (pValues("AutoStart") '= "0") Set pViolations($Increment(pViolations)) = $ListBuild("AutoStart", ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        If $Data(pValues("StartupPriority")) && '$Match(pValues("StartupPriority"), ..#STARTUPNUMBER) && '((pValues("StartupPriority") = "") && ($Get(pValues("AutoStart")) = "0")) Set pViolations($Increment(pViolations)) = $ListBuild("StartupPriority", ##class(OcuPilot.Api.InteropError).#STARTUPPRIORITY)
    } ElseIf pType = ..#TYPESHUTDOWNGROUP {
        If '$Data(pValues("ShutdownGroup")) || '$Match($Get(pValues("ShutdownGroup")), ..#STARTUPNUMBER) Set pViolations($Increment(pViolations)) = $ListBuild("ShutdownGroup", ##class(OcuPilot.Api.InteropError).#STARTUPGROUP)
    }
    Quit $$$OK
}

/// <p>The token a startup write <var>pType</var> is refused with, or <code>""</code> when it may go ahead (Story 24.3): whatever the
/// vendor would answer as a silent success is refused by its own name. <var>pAutoNow</var>, <var>pPriorityNow</var> and
/// <var>pGroupNow</var> are what the production holds, and <var>pAutoWant</var>, <var>pPriorityWant</var> and <var>pGroupWant</var>
/// what the write would set (<code>""</code> for a value it does not carry), all of a valid shape
/// (<method>StartupViolations</method>). Pure.</p>
/// <ul>
/// <li><code>NOPRIORITY</code>: a priority beside <code>AutoStart</code> <code>"0"</code>.</li>
/// <li><code>SAME</code>: stopping auto-start for a production that does not start with the instance; auto-start on for one that does,
/// with the priority it holds or none; a shutdown group equal to the one it holds.</li>
/// </ul>
ClassMethod StartupRefusal(pType As %String, pAutoNow As %Boolean, pPriorityNow As %String, pGroupNow As %String, pAutoWant As %String = "", pPriorityWant As %String = "", pGroupWant As %String = "") As %String
{
    If pType = ..#TYPESHUTDOWNGROUP {
        If (pGroupWant '= "") && (+pGroupWant = +pGroupNow) Quit "SAME"
        Quit ""
    }
    If (pAutoWant = "0") && (pPriorityWant '= "") Quit "NOPRIORITY"
    Set tOn = $Select(pAutoWant = "": ''pAutoNow, 1: (pAutoWant = "1"))
    If 'tOn Quit $Select(pAutoNow: "", 1: "SAME")
    If 'pAutoNow Quit ""
    If (pPriorityWant = "") || (+pPriorityWant = +pPriorityNow) Quit "SAME"
    Quit ""
}

/// <p>Whether the caller can read every interoperability namespace's startup settings, as the classic Auto-Start Production and Production
/// Shutdown Group pages ask before they offer a priority or a group: the vendor's own all-namespaces read for <var>pType</var>
/// (<code>GetNamespacesByShutdownGroup</code> for a shutdown group, <code>GetNamespacesByStartupPriority</code> for a priority) answers
/// OK. It leaves <code>$NAMESPACE</code> as it found it and writes nothing (measured). Overridable so a fixture can answer 0 without a
/// second namespace; production never overrides it.</p>
ClassMethod AllNamespacesReadable(pType As %String) As %Boolean
{
    Set tReadable = 0
    Set tOrigNS = $NAMESPACE
    Try {
        If pType = ..#TYPESHUTDOWNGROUP {
            Set tSC = ##class(%Library.EnsembleMgr).GetNamespacesByShutdownGroup(.tList)
        } Else {
            Set tSC = ##class(%Library.EnsembleMgr).GetNamespacesByStartupPriority(.tList)
        }
        Set tReadable = $$$ISOK(tSC)
    } Catch {
        Set tReadable = 0
    }
    Set $NAMESPACE = tOrigNS
    Quit tReadable
}

/// <p>Whether <var>pNamespace</var>'s default database is mounted read-only, as the classic pages read it
/// (<code>%SYS.Namespace.GetNSInfo</code>, <code>ReadOnly</code>). Overridable so a fixture can answer 1; production never overrides
/// it.</p>
ClassMethod DefaultReadOnly(pNamespace As %String) As %Boolean
{
    Set tReadOnly = 0
    Try {
        Do ##class(%SYS.Namespace).GetNSInfo(pNamespace, .tInfo)
        Set tReadOnly = ''+$Get(tInfo("ReadOnly"), 0)
    } Catch {
        Set tReadOnly = 0
    }
    Quit tReadOnly
}

/// <p><code>Ens.Director.SetAutoStart</code> of <var>pName</var> at <var>pPriority</var>, or of <code>""</code> to stop starting a
/// production with the instance. Called while the namespace is switched. Overridable so a fixture can observe the call; production never
/// overrides it.</p>
ClassMethod VendorSetAutoStart(pName As %String, pPriority As %String = "") As %Status
{
    Quit ##class(Ens.Director).SetAutoStart(pName, pPriority)
}

/// <p><code>Ens.Director.SetProductionShutdownGroup</code> (<code>[Internal]</code>, as the classic page calls it) of <var>pName</var>
/// to <var>pGroup</var>. Called while the namespace is switched. Overridable so a fixture can observe the call; production never
/// overrides it.</p>
ClassMethod VendorSetShutdownGroup(pName As %String, pGroup As %Integer) As %Status
{
    Quit ##class(Ens.Director).SetProductionShutdownGroup(pName, pGroup)
}

/// <p>Gather the startup facts of production <var>pName</var> in the namespace already switched to, in <var>pFacts</var>:
/// <code>exists</code>; <code>auto</code>, whether the namespace starts it with the instance (<code>^Ens.AutoStart</code> read as the
/// classic page reads it); <code>other</code>, the namespace's other auto-start production or <code>""</code>; <code>priority</code>, the
/// stored priority when it starts with the instance and otherwise <code>""</code>; and <code>group</code>, the group the vendor reads for
/// it. The vendor's recommended priority (<code>GetAutoStartRecommendedPriority</code>, reserved for the vendor's own use) is not read,
/// and a write that carries no priority sets 0.</p>
ClassMethod StartupFactsHere(pName As %String, Output pFacts) [ Private ]
{
    Kill pFacts
    Set pFacts("exists") = ''##class(Ens.Config.Production).%ExistsId(pName)
    Set pFacts("auto") = 0
    Set pFacts("other") = ""
    Set pFacts("priority") = ""
    Set pFacts("group") = 2
    If 'pFacts("exists") Quit
    Set tAutoName = $Get(^Ens.AutoStart)
    Set pFacts("auto") = (tAutoName '= "") && (tAutoName = pName)
    Set pFacts("other") = $Select(pFacts("auto"): "", 1: tAutoName)
    Set pFacts("priority") = $Select(pFacts("auto"): +$Get(^Ens.AutoStart("StartupPriority"), 0), 1: "")
    Set pFacts("group") = +##class(Ens.Director).GetProductionShutdownGroup(pName, , 0)
}

/// <p><method>StartupFactsHere</method> in <var>pNamespace</var>, switched by explicit save and restore; a fault is
/// <var>pCaught</var>, with the namespace restored.</p>
ClassMethod StartupFacts(pNamespace As %String, pName As %String, Output pFacts, Output pCaught) [ Private ]
{
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..StartupFactsHere(pName, .pFacts)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
}

/// <p>The <code>STARTUP</code> answer from <var>pFacts</var>: <code>{Name, Namespace, AutoStart, StartupPriority, ShutdownGroup,
/// AutoStartOther}</code>, each a string.</p>
ClassMethod StartupRow(pNamespace As %String, pName As %String, ByRef pFacts) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Name", pName, "string")
    Do tRow.%Set("Namespace", pNamespace, "string")
    Do tRow.%Set("AutoStart", $Select(pFacts("auto"): "1", 1: "0"), "string")
    Do tRow.%Set("StartupPriority", pFacts("priority") _ "", "string")
    Do tRow.%Set("ShutdownGroup", pFacts("group") _ "", "string")
    Do tRow.%Set("AutoStartOther", pFacts("other"), "string")
    Quit tRow
}

/// <p>Serve the Productions endpoint's startup types (Story 24.3) after <method>Invoke</method>'s gate: the <code>STARTUP</code> read and
/// the two writes, the production named under <parameter>IDKEY</parameter> by its class name, kept exactly (AD-13). An
/// <parameter>ACTIONKEY</parameter> names the write the read is composed for.</p>
ClassMethod InvokeStartup(pNamespace As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Set tName = $Get(pQuery(..#IDKEY))
        If tName = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONIDREQUIRED, .pHttpStatus, .pFault)
            Quit
        }
        Set tAction = $Select(..IsStartupWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && '..IsStartupWrite(tAction) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If ..IsStartupWrite(pType) {
            Set tSC = ..PerformStartup(pNamespace, pType, tName, pBody, .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..ReadStartup(pNamespace, tName, tAction, .pQuery, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the startup settings call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>One production's startup settings, fresh (Story 24.3): <method>StartupRow</method>. A production the namespace does not hold is
/// 404 <code>PORT.NOTFOUND</code>, unlogged. With <var>pAction</var> and the values the write would carry in <var>pQuery</var>
/// (<parameter>AUTOSTARTKEY</parameter>, <parameter>PRIORITYKEY</parameter>, <parameter>GROUPKEY</parameter>) it refuses what that write
/// would be refused: <code>NOPRIORITY</code> as a 422 violation and <code>SAME</code> as a 409, from values of a valid shape.</p>
ClassMethod ReadStartup(pNamespace As %String, pName As %String, pAction As %String, ByRef pQuery, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Do ..StartupFacts(pNamespace, pName, .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the startup settings read failed", .pHttpStatus, .pFault)
    If 'tFacts("exists") Quit ..Absent(.pHttpStatus, .pFault)
    If pAction '= "" {
        Kill tWant
        If (pAction = ..#TYPEAUTOSTART) && $Data(pQuery(..#AUTOSTARTKEY)) Set tWant("AutoStart") = pQuery(..#AUTOSTARTKEY)
        If (pAction = ..#TYPEAUTOSTART) && $Data(pQuery(..#PRIORITYKEY)) Set tWant("StartupPriority") = pQuery(..#PRIORITYKEY)
        If (pAction = ..#TYPESHUTDOWNGROUP) && $Data(pQuery(..#GROUPKEY)) Set tWant("ShutdownGroup") = pQuery(..#GROUPKEY)
        If ($Get(tWant("AutoStart")) = "0") && ($Get(tWant("StartupPriority")) = "") Kill tWant("StartupPriority")
        Set tCompose = $Data(tWant)
        If tCompose {
            Do ..StartupViolations(pAction, .tWant, .tViolations)
            If tViolations Set tCompose = 0
        }
        If tCompose {
            Set tToken = ..StartupRefusal(pAction, tFacts("auto"), tFacts("priority"), tFacts("group"), $Get(tWant("AutoStart")), $Get(tWant("StartupPriority")), $Get(tWant("ShutdownGroup")))
            If tToken = "NOPRIORITY" {
                Set tNoPriority(1) = $ListBuild("StartupPriority", ##class(OcuPilot.Api.InteropError).#STARTUPNOPRIORITY)
                Set tNoPriority = 1
                Quit ..Violations(.tNoPriority, .pHttpStatus, .pFault)
            }
            If tToken '= "" Quit ..Conflict(..#STARTUPCODEPREFIX _ tToken, .pHttpStatus, .pFault)
        }
    }
    Set pRow = ..StartupRow(pNamespace, pName, .tFacts)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Run startup write <var>pType</var> on the production <var>pName</var> in <var>pNamespace</var> from the body <var>pBody</var>
/// (<code>AutoStart</code> and <code>StartupPriority</code>, or <code>ShutdownGroup</code>, each a string) and answer what it leaves
/// (Story 24.3). The sequence, each step before any vendor call:</p>
/// <ol>
/// <li>The values are judged by <method>StartupViolations</method> (422; a value that is not a string is <code>PORT.FIELD.SHAPE</code>).</li>
/// <li>The production's facts are read in the namespace; a production it does not hold is 404.</li>
/// <li><method>StartupRefusal</method>: <code>NOPRIORITY</code> is a 422 violation and <code>SAME</code> a 409.</li>
/// <li>A shutdown-group change, or a priority different from the one the read answered, needs <method>AllNamespacesReadable</method>
/// (403 <code>INTEROP.STARTUP.ALLNAMESPACES</code>); turning auto-start on or off with the priority the read answered does not.</li>
/// <li>A namespace whose database <method>DefaultReadOnly</method> is 409 <code>INTEROP.STARTUP.READONLY</code>.</li>
/// </ol>
/// <p>Then the vendor call in the namespace (<method>VendorSetAutoStart</method>, <method>VendorSetShutdownGroup</method>), the
/// namespace restored, and OcuPilot's own audit row (<method>AuditRuntime</method>) naming the tool, the namespace and the production
/// and no value. The answer is the production's <code>STARTUP</code> read again.</p>
ClassMethod PerformStartup(pNamespace As %String, pType As %String, pName As %String, pBody As %DynamicAbstractObject, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Kill tValues
    Set tViolations = 0
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Set pBody = {}
    Set tFields = $Select(pType = ..#TYPEAUTOSTART: $ListBuild("AutoStart", "StartupPriority"), 1: $ListBuild("ShutdownGroup"))
    For tI = 1:1:$ListLength(tFields) {
        Set tField = $List(tFields, tI)
        Set tFieldType = pBody.%GetTypeOf(tField)
        If tFieldType = "string" {
            Set tValues(tField) = pBody.%Get(tField)
        } ElseIf tFieldType '= "unassigned" {
            Set tViolations($Increment(tViolations)) = $ListBuild(tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
    }
    If 'tViolations {
        Set tSC = ..StartupViolations(pType, .tValues, .tShape)
        If $$$ISERR(tSC) Quit tSC
        For tI = 1:1:tShape {
            Set tViolations($Increment(tViolations)) = tShape(tI)
        }
    }
    If tViolations Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    If ($Get(tValues("AutoStart")) = "0") && ($Get(tValues("StartupPriority")) = "") Kill tValues("StartupPriority")
    Do ..StartupFacts(pNamespace, pName, .tFacts, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the startup settings write failed", .pHttpStatus, .pFault)
    If 'tFacts("exists") Quit ..Absent(.pHttpStatus, .pFault)
    Set tToken = ..StartupRefusal(pType, tFacts("auto"), tFacts("priority"), tFacts("group"), $Get(tValues("AutoStart")), $Get(tValues("StartupPriority")), $Get(tValues("ShutdownGroup")))
    If tToken = "NOPRIORITY" {
        Set tViolations(1) = $ListBuild("StartupPriority", ##class(OcuPilot.Api.InteropError).#STARTUPNOPRIORITY)
        Set tViolations = 1
        Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    }
    If tToken '= "" Quit ..Conflict(..#STARTUPCODEPREFIX _ tToken, .pHttpStatus, .pFault)
    Set tAutoWant = $Get(tValues("AutoStart"))
    Set tOn = $Select(tAutoWant = "": tFacts("auto"), 1: (tAutoWant = "1"))
    Set tNeedsAll = (pType = ..#TYPESHUTDOWNGROUP) || (tOn && $Data(tValues("StartupPriority")) && (+$Get(tValues("StartupPriority")) '= +tFacts("priority")))
    If tNeedsAll && '..AllNamespacesReadable(pType) {
        Quit ..Refuse(403, ##class(OcuPilot.Api.Error).#FORBIDDEN, ##class(OcuPilot.Api.InteropError).#STARTUPALLNAMESPACES, ##class(OcuPilot.Api.InteropError).ReasonFor(##class(OcuPilot.Api.InteropError).#STARTUPALLNAMESPACES), .pHttpStatus, .pFault)
    }
    If ..DefaultReadOnly(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#STARTUPREADONLY, .pHttpStatus, .pFault)
    Set tCaught = ""
    Set tVendorSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If pType = ..#TYPESHUTDOWNGROUP {
            Set tVendorSC = ..VendorSetShutdownGroup(pName, +tValues("ShutdownGroup"))
        } ElseIf 'tOn {
            Set tVendorSC = ..VendorSetAutoStart("")
        } Else {
            Set tVendorSC = ..VendorSetAutoStart(pName, $Select($Data(tValues("StartupPriority")): +tValues("StartupPriority"), 1: +tFacts("priority")))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the startup settings write failed", .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(tVendorSC, "the startup settings write failed", .pHttpStatus, .pFault)
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("tool", $Select(pType = ..#TYPEAUTOSTART: ..#TOOLAUTOSTART, 1: ..#TOOLSHUTDOWNGROUP), "string")
    If (pType = ..#TYPEAUTOSTART) && tOn && (tFacts("other") '= "") Do tEffects.%Set("replaces", tFacts("other"), "string")
    Do ..AuditRuntime(..#VERBSET, ..#ENTITYPRODUCTION, pName, tEffects)
    Kill tQuery
    Set tReadSC = ..ReadStartup(pNamespace, pName, "", .tQuery, .tRow, .tReadHttp, .tReadFault)
    If $$$ISERR(tReadSC) {
        Set tRow = {}
        Do tRow.%Set("Name", pName, "string")
        Do tRow.%Set("Namespace", pNamespace, "string")
    }
    Set pResult = tRow
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>The lines <method>Snippet</method> adds for the startup write <var>pType</var> of the production <var>pId</var> (Story 24.3),
/// carrying the body <var>pBody</var>: <code>SetAutoStart</code> of the production and the priority the body carries (0 when it
/// carries none, as the write sets), <code>SetAutoStart("")</code> for <code>AutoStart</code> <code>"0"</code>, or
/// <code>SetProductionShutdownGroup</code> of the production and the group. Names are string literals; a priority and a group are
/// written as the numbers the write passes, so a value such as <code>007</code> reaches the vendor as <code>7</code>.</p>
ClassMethod StartupSnippet(pType As %String, pId As %String, pBody As %DynamicAbstractObject) As %String [ Private ]
{
    Set tNL = $Char(10)
    If pType = ..#TYPESHUTDOWNGROUP {
        Set tGroup = ""
        If $IsObject(pBody) && (pBody.%GetTypeOf("ShutdownGroup") = "string") Set tGroup = pBody.%Get("ShutdownGroup")
        Quit tNL _ " Set tSC = ##class(Ens.Director).SetProductionShutdownGroup(" _ ..Literal(pId) _ ", " _ (+tGroup) _ ")"
    }
    If $IsObject(pBody) && (pBody.%GetTypeOf("AutoStart") = "string") && (pBody.%Get("AutoStart") = "0") Quit tNL _ " Set tSC = ##class(Ens.Director).SetAutoStart("""")"
    Set tPriority = ""
    If $IsObject(pBody) && (pBody.%GetTypeOf("StartupPriority") = "string") Set tPriority = pBody.%Get("StartupPriority")
    Quit tNL _ " Set tSC = ##class(Ens.Director).SetAutoStart(" _ ..Literal(pId) _ ", " _ (+tPriority) _ ")"
}

/// <p>The lines <method>Snippet</method> adds for the partner write <var>pType</var> of the partner named <var>pId</var>
/// (Story 20.26): the vendor's <code>%Save</code> of a new partner with each of the thirteen fields the body <var>pBody</var>
/// carries, a <code>%Save</code> of the partner opened at concurrency 4 with the fields it carries, or
/// <code>%DeleteId</code>. Names and values are string literals.</p>
ClassMethod PartnerSnippet(pType As %String, pId As %String, pBody As %DynamicAbstractObject) As %String [ Private ]
{
    Set tNL = $Char(10)
    Set tName = ..Literal(pId)
    If pType = ..#TYPEREMOVEPARTNER Quit tNL _ " Set tSC = ##class(Ens.Config.BusinessPartner).%DeleteId(" _ tName _ ")"
    If pType = ..#TYPEADDPARTNER {
        Set tText = tNL _ " Set tPartner = ##class(Ens.Config.BusinessPartner).%New()" _ tNL _ " Set tPartner.PartnerName = " _ tName
    } Else {
        Set tText = tNL _ " Set tPartner = ##class(Ens.Config.BusinessPartner).%OpenId(" _ tName _ ", 4)"
    }
    Set tFields = $ListFromString(..#PARTNERSETFIELDS)
    For tI = 1:1:$ListLength(tFields) {
        Set tField = $List(tFields, tI)
        Set tValue = ""
        Set tSupplied = $IsObject(pBody) && (pBody.%GetTypeOf(tField) = "string")
        If tSupplied Set tValue = pBody.%Get(tField)
        If tSupplied || (pType = ..#TYPEADDPARTNER) Set tText = tText _ tNL _ " Set tPartner." _ ..PartnerPath(tField) _ " = " _ ..Literal(tValue)
    }
    Quit tText _ tNL _ " Set tSC = tPartner.%Save()" _ tNL _ " Set tPartner = """""
}

/// <p>The lines <method>Snippet</method> adds for the lookup write <var>pType</var> of the table or entry the id <var>pId</var>
/// names (Story 20.5): the vendor's table lock, the call and the unlock, with the add's or set's value from the body
/// <var>pBody</var>. Names and values are string literals.</p>
ClassMethod LookupSnippet(pType As %String, pId As %String, pBody As %DynamicAbstractObject) As %String [ Private ]
{
    Set tNL = $Char(10)
    If pType = ..#TYPEDELETETABLE {
        Set tTable = ..Literal(pId)
        Set tCall = "##class(Ens.Util.LookupTable).%ClearTable(" _ tTable _ ")"
        Quit tNL _ " Lock +^Ens.LookupTable(" _ tTable _ "):" _ ..#LOCKSECONDS _ tNL _ " If $Test { Do " _ tCall _ " } Else { Set tSC = $System.Status.Error(5001, ""the lookup table lock is held"") }" _ tNL _ " Lock -^Ens.LookupTable(" _ tTable _ ")"
    }
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pId)
    Set tTable = ..Literal($ListGet(tParts, 1))
    Set tKey = ..Literal($ListGet(tParts, 2))
    Set tValue = ""
    If $IsObject(pBody) && (pBody.%GetTypeOf("Value") = "string") Set tValue = pBody.%Get("Value")
    If pType = ..#TYPEREMOVEENTRY {
        Set tCall = "##class(Ens.Util.LookupTable).%RemoveValue(" _ tTable _ ", " _ tKey _ ")"
    } Else {
        Set tCall = "##class(Ens.Util.LookupTable).%UpdateValue(" _ tTable _ ", " _ tKey _ ", " _ ..Literal(tValue) _ ", " _ (pType = ..#TYPEADDENTRY) _ ")"
    }
    Quit tNL _ " Lock +^Ens.LookupTable(" _ tTable _ "):" _ ..#LOCKSECONDS _ tNL _ " If $Test { Set tSC = " _ tCall _ " } Else { Set tSC = $System.Status.Error(5001, ""the lookup table lock is held"") }" _ tNL _ " Lock -^Ens.LookupTable(" _ tTable _ ")"
}

/// <p>The most seconds a test waits for its target's answer before it answers <code>waiting</code> (Story 20.6).
/// Overridable so a test can shorten the wait and observe that answer; production never overrides it.</p>
ClassMethod TestWait() As %Numeric
{
    Quit ..#TESTWAIT
}

/// <p>Send <var>pRequest</var> to the host <var>pTarget</var> through <code>EnsLib.Testing.Service</code>, asynchronously, as the
/// classic Testing Service dialog sends it, and answer the session in <var>pSession</var>. Called inside the production's
/// namespace and inside the output capture, because the vendor writes its refusal to the current device
/// (<code>DisplayError</code>). Overridable so a fixture can fail it and write to the device; production never overrides it.</p>
ClassMethod VendorSendTest(pNamespace As %String, pTarget As %String, pRequest As %RegisteredObject, Output pSession As %String) As %Status [ Private ]
{
    Set pSession = ""
    Quit ##class(EnsLib.Testing.Service).SendTestRequest(pTarget, pRequest, , .pSession)
}

/// <p>Serve the ItemTest endpoint (Story 20.6) after <method>Invoke</method>'s gate. A <code>LIST</code> names its item under
/// <parameter>ITEMKEY</parameter>; the typed read and the send name it under <parameter>IDKEY</parameter>, as the composite
/// <code>[Production, Name]</code> or the vendor's <code>Production||Name</code>. The request class and the field values travel
/// under <parameter>REQUESTCLASSKEY</parameter> and <parameter>FIELDSKEY</parameter>.</p>
ClassMethod InvokeItemTest(pNamespace As %String, pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType = ..#TYPELIST {
            If '..ItemParts($Get(pQuery(..#ITEMKEY)), .tProduction, .tItem) {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONITEMIDREQUIRED, .pHttpStatus, .pFault)
                Quit
            }
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..ListTestFields(pNamespace, tProduction, tItem, +tMaxText, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If '..ItemParts($Get(pQuery(..#IDKEY)), .tProduction, .tItem) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONITEMIDREQUIRED, .pHttpStatus, .pFault)
            Quit
        }
        Set tAction = $Select(..IsTestWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && (tAction '= ..#TYPESENDTEST) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If ..IsTestWrite(pType) {
            Set tSC = ..PerformTest(pNamespace, tProduction, tItem, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..ReadTestTarget(pNamespace, tProduction, tItem, tAction, $Get(pQuery(..#REQUESTCLASSKEY)), $Get(pQuery(..#FIELDSKEY)), .pResult, .tPlan, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the host test call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether <var>pClass</var> is a virtual document request: a class that descends from
/// <parameter>DOCUMENTBASE</parameter>, whose request is made of its text alone. Called while the production's namespace is
/// switched.</p>
ClassMethod IsDocumentClassHere(pClass As %String) As %Boolean [ Private ]
{
    Quit ''$ClassMethod(pClass, "%Extends", ..#DOCUMENTBASE)
}

/// <p>The request classes the host class <var>pHostClass</var> names itself, in <var>pOwn</var> (the subscripts): the list its
/// own <code>GetMessageList</code> answers, as the classic Testing Service dialog reads it. The dictionary does not carry that
/// list for every host: a router's, for one, is computed by its own code generator at compile time (measured on
/// <code>HSCUSTOM</code>: 24 of 199 concrete host classes answer a request class that neither their message map nor the signature
/// of their <code>OnMessage</code> or <code>OnRequest</code> names), so the vendor's method is the source. A class the namespace does not hold is left out. Called while the production's namespace is switched.</p>
ClassMethod OwnRequestTypesHere(pHostClass As %String, Output pOwn) [ Private ]
{
    Kill pOwn
    If '$Match(pHostClass, ..#CLASSNAMEPATTERN) Quit
    If '##class(%Dictionary.CompiledClass).%ExistsId(pHostClass) Quit
    If '##class(%Dictionary.CompiledMethod).%ExistsId(pHostClass _ "||GetMessageList") Quit
    Set tList = $ClassMethod(pHostClass, "GetMessageList")
    For tI = 1:1:$ListLength(tList) {
        Set tName = $ListGet(tList, tI)
        If (tName '= "") && ##class(%Dictionary.CompiledClass).%ExistsId(tName) Set pOwn(tName) = ""
    }
}

/// <p>The request classes an item of the host class <var>pHostClass</var> takes, as the classic dialog builds the list: each
/// class the host names itself (<method>OwnRequestTypesHere</method>) that is not abstract, and every subclass of one that is
/// not abstract and extends <code>Ens.Util.MessageBodyMethods</code>. <var>pClasses</var><code>(0, name)</code> holds the
/// host's own and <var>pClasses</var><code>(1, name)</code> the subclasses, each in name order. Called while the production's
/// namespace is switched; nothing is instantiated.</p>
ClassMethod RequestClassesHere(pHostClass As %String, Output pClasses) [ Private ]
{
    Kill pClasses
    Do ..OwnRequestTypesHere(pHostClass, .tOwn)
    Set tName = ""
    For {
        Set tName = $Order(tOwn(tName))
        If tName = "" Quit
        If '$$$comClassKeyGet(tName, $$$cCLASSabstract) Set pClasses(0, tName) = ""
    }
    Set tResult = ##class(%ResultSet).%New("%Dictionary.ClassDefinition:SubclassOf")
    Set tName = ""
    For {
        Set tName = $Order(tOwn(tName))
        If tName = "" Quit
        Set tStatus = tResult.Execute(tName)
        If $$$ISERR(tStatus) Throw ##class(%Exception.StatusException).CreateFromStatus(tStatus)
        While tResult.Next() {
            Set tSub = tResult.GetData(1)
            If (tSub = "") || $Data(pClasses(0, tSub)) Continue
            If '##class(%Dictionary.CompiledClass).%ExistsId(tSub) Continue
            If $$$comClassKeyGet(tSub, $$$cCLASSabstract) Continue
            If '$ClassMethod(tSub, "%Extends", "Ens.Util.MessageBodyMethods") Continue
            Set pClasses(1, tSub) = ""
        }
        Do tResult.Close()
    }
}

/// <p>Whether <var>pClass</var> is a request class an item of the host class <var>pHostClass</var> takes
/// (<method>RequestClassesHere</method>), decided without listing the namespace's classes: a class the host names itself that is
/// not abstract, or a class that is not abstract, extends <code>Ens.Util.MessageBodyMethods</code> and descends from one the
/// host names. <var>pClass</var> reaches no class method until the namespace is known to hold it. Called while the production's
/// namespace is switched.</p>
ClassMethod IsRequestClassHere(pHostClass As %String, pClass As %String) As %Boolean [ Private ]
{
    If '$Match(pClass, ..#CLASSNAMEPATTERN) Quit 0
    If '##class(%Dictionary.CompiledClass).%ExistsId(pClass) Quit 0
    If $$$comClassKeyGet(pClass, $$$cCLASSabstract) Quit 0
    Do ..OwnRequestTypesHere(pHostClass, .tOwn)
    If $Data(tOwn(pClass)) Quit 1
    If '$ClassMethod(pClass, "%Extends", "Ens.Util.MessageBodyMethods") Quit 0
    Set tName = ""
    For {
        Set tName = $Order(tOwn(tName))
        If tName = "" Quit
        If $ClassMethod(pClass, "%Extends", tName) Quit
    }
    Quit (tName '= "")
}

/// <p>The fields a test request of class <var>pClass</var> is made of, as <var>pFields</var> records, from the class dictionary
/// alone (nothing is instantiated and no class code runs): a virtual document is one <code>content</code> field of kind
/// <code>document</code>; any other class lists the properties the classic form lets a person set, in its order -- a datatype,
/// and an embedded serial object expanded to its own fields under a dotted path -- but not an object reference, a
/// collection, a stream, or a property that is internal, private, multidimensional, read-only or calculated. At most
/// <parameter>TESTFIELDMAX</parameter> properties are examined at a level and that many fields listed (the classic form's own
/// bound). <var>pFields</var> is the count, and <var>pFields</var><code>(n)</code> is <code>$ListBuild(kind, path, leaf, type,
/// required, maxLength, values, owner, chain)</code>: <code>values</code> is a closed list's display values (else its values), or
/// <code>0</code> and <code>1</code> for a <code>%Library.Boolean</code>; <code>owner</code> is the class declaring the property and
/// <code>chain</code> the serial classes along the path. Called while the production's namespace is switched.</p>
ClassMethod ClassFieldsHere(pClass As %String, Output pFields) [ Private ]
{
    Kill pFields
    Set pFields = 0
    If '$Match(pClass, ..#CLASSNAMEPATTERN) Quit
    If '##class(%Dictionary.CompiledClass).%ExistsId(pClass) Quit
    If ..IsDocumentClassHere(pClass) {
        Set pFields = 1
        Set pFields(1) = $ListBuild("document", ..#DOCUMENTFIELD, ..#DOCUMENTFIELD, "%Library.String", 1, "", "", pClass, "")
        Quit
    }
    Do ..CollectFieldsHere(pClass, "", "", 0, .pFields)
}

/// <p>The datatype properties of <var>pOwner</var>, and of the serial classes embedded in it, that
/// <method>ClassFieldsHere</method> lists, appended to <var>pFields</var>. <var>pPrefix</var> is the dotted path to
/// <var>pOwner</var>, <var>pChain</var> the serial classes along it.</p>
ClassMethod CollectFieldsHere(pOwner As %String, pPrefix As %String, pChain As %List, pDepth As %Integer, ByRef pFields) [ Private ]
{
    If pDepth > 6 Quit
    Set tClass = ##class(%Dictionary.CompiledClass).%OpenId(pOwner)
    If '$IsObject(tClass) Quit
    Kill tOrder
    For tI = 1:1:tClass.Properties.Count() {
        Set tProperty = tClass.Properties.GetAt(tI)
        If '$IsObject(tProperty) Continue
        Set tSort = (tProperty.Origin = pOwner) _ ":" _ $Translate($Justify(+tProperty.SequenceNumber, 8), " ", "0") _ ":" _ tProperty.Name
        Set tOrder(tSort) = tI
    }
    Set tExamined = 0
    Set tSort = ""
    For {
        Set tSort = $Order(tOrder(tSort), 1, tIndex)
        If tSort = "" Quit
        Set tExamined = tExamined + 1
        If (tExamined > ..#TESTFIELDMAX) || (pFields >= ..#TESTFIELDMAX) Quit
        Set tProperty = tClass.Properties.GetAt(tIndex)
        If tProperty.Collection '= "" Continue
        If tProperty.Internal || tProperty.Private || tProperty.MultiDimensional || tProperty.ReadOnly || tProperty.Calculated Continue
        Set tType = $$$NormalizeClassname(tProperty.Type)
        Set tClassType = $$$comClassKeyGet(tType, $$$cCLASSclasstype)
        Set tPath = pPrefix _ $Select(pPrefix = "": "", 1: ".") _ tProperty.Name
        If tClassType = "datatype" {
            Set tValueText = tProperty.Parameters.GetAt("DISPLAYLIST")
            If tValueText = "" Set tValueText = tProperty.Parameters.GetAt("VALUELIST")
            Set tValues = ""
            If tValueText '= "" {
                Set tDelimiter = $Extract(tValueText, 1)
                For tJ = 2:1:$Length(tValueText, tDelimiter) {
                    Set tValues = tValues _ $ListBuild($Piece(tValueText, tDelimiter, tJ))
                }
            }
            If (tValues = "") && (tType = "%Library.Boolean") Set tValues = $ListBuild("0", "1")
            Set tMaxLength = tProperty.Parameters.GetAt("MAXLEN")
            Set pFields($Increment(pFields)) = $ListBuild("object", tPath, tProperty.Name, tType, ''tProperty.Required, $Select($IsValidNum(tMaxLength): +tMaxLength, 1: ""), tValues, pOwner, pChain)
        } ElseIf tClassType = "serial" {
            Do ..CollectFieldsHere(tType, tPath, pChain _ $ListBuild(tType), pDepth + 1, .pFields)
        }
    }
}

/// <p>Whether a field of the dotted path <var>pPath</var> is credential-named (AD-35): any segment of it matches
/// <method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method>. The port's refusal, the tab's <code>Secret</code> column and the
/// send tool's redaction all ask this one question. Not called while a namespace is switched.</p>
ClassMethod SecretPath(pPath As %String) As %Boolean
{
    Set tSecret = 0
    For tI = 1:1:$Length(pPath, ".") {
        If ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName($Piece(pPath, ".", tI)) {
            Set tSecret = 1
            Quit
        }
    }
    Quit tSecret
}

/// <p>The Test tab's fields for the item <var>pItem</var> of <var>pProduction</var>, at most <var>pMax</var> rows when it is
/// above zero: one row for each field of each request class an item of a process or an operation takes
/// (<method>RequestClassesHere</method>), the host's own classes first and then their subclasses, each in name order; a business
/// service, which takes no test request, gives none. Only the host class's own <code>GetMessageList</code> runs; the subclasses
/// and fields come from the class dictionary, and no request class's code runs. An unknown production or item is 404 <code>PORT.NOTFOUND</code>, unlogged; a name the production holds
/// more than once is <code>INTEROP.ITEM.AMBIGUOUS</code>.</p>
ClassMethod ListTestFields(pNamespace As %String, pProduction As %String, pItem As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..ResolveItem(pNamespace, pProduction, pItem, .tLine, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Kill tFound
    Set tFound = 0
    If $ListFind($ListBuild(2, 3), $List(tLine, 3)) {
        Set tSC = ..GatherTestFields(pNamespace, $List(tLine, 2), pMax, .tFound, .tCaught)
        If $IsObject(tCaught) Quit ..Mapped(tCaught, "the test fields could not be read", .pHttpStatus, .pFault)
    }
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push(..TestFieldRow(pProduction, $List(tLine, 1), tFound(tI)))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The fields of the request classes the host class <var>pHostClass</var> takes, in <var>pFound</var>, at most
/// <var>pMax</var> of them when it is above zero: each element is <code>$ListBuild(class)</code> followed by one
/// <method>ClassFieldsHere</method> record, and a class with no field gives one element of kind <code>object</code> with an
/// empty path. A fault is <var>pCaught</var>, with the namespace restored. Only vendor classes and this class run while the
/// namespace is switched.</p>
ClassMethod GatherTestFields(pNamespace As %String, pHostClass As %String, pMax As %Integer, ByRef pFound, Output pCaught) As %Status [ Private ]
{
    Kill pFound
    Set pFound = 0
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..RequestClassesHere(pHostClass, .tClasses)
        For tRank = 0, 1 {
            Set tClass = ""
            For {
                Set tClass = $Order(tClasses(tRank, tClass))
                If tClass = "" Quit
                If (pMax > 0) && (pFound >= pMax) Quit
                Do ..ClassFieldsHere(tClass, .tFields)
                If 'tFields {
                    Set pFound($Increment(pFound)) = $ListBuild(tClass, "object", "", "", "", 0, "", "", tClass, "")
                    Continue
                }
                For tI = 1:1:tFields {
                    If (pMax > 0) && (pFound >= pMax) Quit
                    Set pFound($Increment(pFound)) = $ListBuild(tClass) _ tFields(tI)
                }
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    Quit $$$OK
}

/// <p>The Test tab's row for the element <var>pLine</var> (<method>GatherTestFields</method>'s) of the item <var>pItemName</var>
/// of <var>pProduction</var>: <code>{Production, Item, RequestClass, Kind, Field, Type, Required, MaxLength, Values, Secret}</code>,
/// <code>Item</code> the item's <code>Production||Name</code>, <code>MaxLength</code> null where the field has none and
/// <code>Values</code> the values a field of a closed list takes, as a person types them. A credential-named field is
/// <code>Secret</code> (AD-35). A document's <code>content</code> is bounded by the longest text the screen sends. With
/// <var>pForm</var> (Story 20.31) the row is an edit form's: <code>{RequestClass, Kind, Field, Type, Required, MaxLength, Values,
/// Secret, Value}</code>, without the production and the item, <code>Value</code> being <var>pValue</var>, the field's current
/// value as a person types it.</p>
ClassMethod TestFieldRow(pProduction As %String, pItemName As %String, pLine As %List, pForm As %Boolean = 0, pValue As %String = "") As %DynamicObject [ Private ]
{
    Set tKind = $List(pLine, 2)
    Set tPath = $List(pLine, 3)
    Set tRow = {}
    If 'pForm {
        Do tRow.%Set("Production", pProduction, "string")
        Do tRow.%Set("Item", pProduction _ "||" _ pItemName, "string")
    }
    Do tRow.%Set("RequestClass", $List(pLine, 1), "string")
    Do tRow.%Set("Kind", tKind, "string")
    Do tRow.%Set("Field", tPath, "string")
    Do tRow.%Set("Type", $List(pLine, 5), "string")
    Do tRow.%Set("Required", ''$List(pLine, 6), "boolean")
    If tKind = "document" {
        Do tRow.%Set("MaxLength", ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS, "number")
    } ElseIf $List(pLine, 7) = "" {
        Do tRow.%Set("MaxLength", "", "null")
    } Else {
        Do tRow.%Set("MaxLength", $List(pLine, 7), "number")
    }
    Set tValues = []
    Set tList = $List(pLine, 8)
    For tI = 1:1:$ListLength(tList) {
        Do tValues.%Push($List(tList, tI), "string")
    }
    Do tRow.%Set("Values", tValues)
    Do tRow.%Set("Secret", $Select(tPath = "": 0, 1: ''..SecretPath(tPath)), "boolean")
    If pForm Do tRow.%Set("Value", pValue, "string")
    Quit tRow
}

/// <p>The request fields <var>pText</var>, JSON object text, as <var>pInput</var>: each member that is text keyed by its name
/// (a name over 200 characters is cut, and an empty one reads <code>(empty name)</code>), <var>pInput</var> the count; each
/// member that is not text is <var>pBad</var>, keyed the same way. <code>""</code> is no fields. 0 when the text is not an
/// object, or names more than <parameter>TESTINPUTMAX</parameter> members. Pure.</p>
ClassMethod ParseTestFields(pText As %String, Output pInput, Output pBad) As %Boolean [ Private ]
{
    Kill pInput, pBad
    Set pInput = 0
    If pText = "" Quit 1
    Set tObject = ""
    Try {
        Set tObject = ##class(%DynamicAbstractObject).%FromJSON(pText)
    } Catch {
        Set tObject = ""
    }
    If '$IsObject(tObject) || 'tObject.%IsA("%Library.DynamicObject") Quit 0
    If tObject.%Size() > ..#TESTINPUTMAX Quit 0
    Set tIterator = tObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue, .tType) {
        Set tName = $Select(tKey = "": "(empty name)", 1: $Extract(tKey, 1, 200))
        If tType = "string" {
            Set pInput(tName) = tValue
            Set pInput = pInput + 1
        } Else {
            Set pBad(tName) = ""
        }
    }
    Quit 1
}

/// <p>The text members of <var>pInput</var> (<method>ParseTestFields</method>) that are not empty, or all of them with
/// <var>pKeepEmpty</var> (an edit may clear a field, Story 20.31), as canonical JSON text: one object whose members are in name
/// order. It is the value <code>Fields</code> reads and the fingerprint covers, so one request reads one text. Pure.</p>
ClassMethod CanonicalFields(ByRef pInput, pKeepEmpty As %Boolean = 0) As %String [ Private ]
{
    Set tObject = {}
    Set tKey = ""
    For {
        Set tKey = $Order(pInput(tKey), 1, tValue)
        If tKey = "" Quit
        If pKeepEmpty || (tValue '= "") Do tObject.%Set(tKey, tValue, "string")
    }
    Quit tObject.%ToJSON()
}

/// <p>The vendor's facts a test is judged by, read in the production's namespace (which the caller has switched to) into
/// <var>pFacts</var>: <code>testing</code>, whether the testing service is registered, from the host monitor's own query
/// (<code>Ens.Util.Statistics:EnumerateHostStatus</code> lists the service, and reads it <code>Disabled</code> once the running
/// production has unregistered it), asked only while the production runs (<var>pRunning</var>); and, for an item that takes a
/// test (<var>pTakesTests</var>) and a non-empty <var>pRequestClass</var>, <code>allowed</code>, whether the host takes that
/// class, then <code>kind</code> and the class's fields, <code>meta</code> their count and <code>meta(n)</code> their
/// <method>ClassFieldsHere</method> records.</p>
ClassMethod TestFactsHere(pHostClass As %String, pRunning As %Boolean, pTakesTests As %Boolean, pRequestClass As %String, Output pFacts) [ Private ]
{
    Kill pFacts
    Set pFacts("testing") = 0
    Set pFacts("allowed") = 0
    Set pFacts("kind") = ""
    Set pFacts("meta") = 0
    If pRunning {
        Set tResult = ##class(%ResultSet).%New("Ens.Util.Statistics:EnumerateHostStatus")
        Set tStatus = tResult.Execute()
        If $$$ISERR(tStatus) Throw ##class(%Exception.StatusException).CreateFromStatus(tStatus)
        While tResult.Next() {
            If (tResult.GetData(1) = ..#TESTSERVICE) && (tResult.GetData(3) '= "Disabled") {
                Set pFacts("testing") = 1
                Quit
            }
        }
        Do tResult.Close()
    }
    If 'pTakesTests || (pRequestClass = "") Quit
    If '..IsRequestClassHere(pHostClass, pRequestClass) Quit
    Set pFacts("allowed") = 1
    Set pFacts("kind") = $Select(..IsDocumentClassHere(pRequestClass): "document", 1: "object")
    Do ..ClassFieldsHere(pRequestClass, .tMeta)
    Set pFacts("meta") = tMeta
    For tI = 1:1:tMeta {
        Set pFacts("meta", tI) = tMeta(tI)
    }
}

/// <p>Convert each field of the plan <var>pPlan</var> to its logical value and judge it, as the classic form does: the
/// declaring class's <code>&lt;Property&gt;DisplayToLogical</code> and then <code>&lt;Property&gt;IsValid</code>. A value
/// they refuse is <var>pViolations</var><code>(n)</code>, <code>$ListBuild(path, "VALUE")</code>; one they accept is the
/// plan element's sixth member. A property whose class carries neither method is taken as typed. Called while the production's
/// namespace is switched.</p>
ClassMethod ConvertPlanHere(ByRef pPlan, Output pViolations) [ Private ]
{
    Kill pViolations
    Set pViolations = 0
    For tI = 1:1:+$Get(pPlan) {
        Set tRecord = pPlan(tI)
        Set tOwner = $List(tRecord, 3)
        Set tLeaf = $List(tRecord, 2)
        Set tLogical = $List(tRecord, 5)
        If ##class(%Dictionary.CompiledMethod).%ExistsId(tOwner _ "||" _ tLeaf _ "DisplayToLogical") {
            Set tLogical = $ClassMethod(tOwner, tLeaf _ "DisplayToLogical", tLogical)
        }
        Set tStatus = $$$OK
        If ##class(%Dictionary.CompiledMethod).%ExistsId(tOwner _ "||" _ tLeaf _ "IsValid") {
            Set tStatus = $ClassMethod(tOwner, tLeaf _ "IsValid", tLogical)
        }
        If $$$ISERR(tStatus) {
            Set pViolations($Increment(pViolations)) = $ListBuild($List(tRecord, 1), "VALUE")
        } Else {
            Set $List(pPlan(tI), 6) = tLogical
        }
    }
}

/// <p>One item's test, read fresh (Story 20.6): <code>{Namespace, Production, Name, Type, Enabled, State, Testing, RequestClass,
/// Kind, Fields, RequestValid}</code>. An unknown production or item is 404 <code>PORT.NOTFOUND</code>, unlogged; a name the
/// production holds more than once is <code>INTEROP.ITEM.AMBIGUOUS</code>. <var>pRequestClass</var> and <var>pFieldsText</var>
/// are the request being tested, echoed as typed and, for <code>Fields</code>, as canonical JSON text; a <var>pFieldsText</var>
/// that is not a JSON object of at most <parameter>TESTINPUTMAX</parameter> members is 400 <code>PORT.VALIDATION</code>.</p>
/// <p>With <var>pAction</var> the send, it refuses what the send would be refused, in this order, each before any request is
/// built and each 409: the production is not running (<code>INTEROP.PRODUCTION.NOTRUNNING</code>, also when the one running is
/// another); <code>DISABLED</code>, the testing service is not registered; <code>TARGETTYPE</code>, the item is not a process
/// or an operation; <code>TARGETDISABLED</code>; <code>REQUESTTYPE</code>, the class is not one the item takes; and
/// <code>SECRET</code>, a value for a credential-named field. Then the fields are judged, 422: <code>FIELD</code> for a name that
/// is not a field of the class, <code>VALUE</code> for a value its class refuses, a value outside the field's listed
/// <code>Values</code>, a required field left empty or a member that is not text. A document is one member, <code>content</code>, 1 to
/// <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter> characters.</p>
/// <p><var>pPlan</var> answers what the send builds from: <code>pPlan("kind")</code>, <code>pPlan("name")</code>, then for a
/// document <code>pPlan("content")</code>, else <code>pPlan</code> fields and <code>pPlan(n)</code>
/// <code>$ListBuild(path, leaf, owner, chain, typed, logical)</code> in the class's order, only for a field given a value.
/// Neither the read nor the plan instantiates a request class.</p>
ClassMethod ReadTestTarget(pNamespace As %String, pProduction As %String, pItem As %String, pAction As %String, pRequestClass As %String, pFieldsText As %String, Output pRow As %DynamicObject, ByRef pPlan, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Kill pPlan
    Set pPlan = 0
    Set tSC = ..ResolveItem(pNamespace, pProduction, pItem, .tLine, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ReadState(pNamespace, pProduction, .tFacts, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '..ParseTestFields(pFieldsText, .tInput, .tBad) Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONTESTFIELDS, .pHttpStatus, .pFault)
    Set tName = $List(tLine, 1)
    Set tBusiness = $List(tLine, 3)
    Set tTakesTests = (tBusiness = 2) || (tBusiness = 3)
    Set tRunning = (tFacts("word") = "Running")
    Set tCaught = ""
    Kill tTest
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..TestFactsHere($List(tLine, 2), tRunning, tTakesTests, pRequestClass, .tTest)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the test target could not be read", .pHttpStatus, .pFault)
    Set tKind = tTest("kind")
    Set tValid = 0
    If pAction '= "" {
        If 'tRunning Quit ..Conflict(##class(OcuPilot.Api.InteropError).#NOTRUNNING, .pHttpStatus, .pFault)
        If 'tTest("testing") Quit ..Conflict(##class(OcuPilot.Api.InteropError).#TESTDISABLED, .pHttpStatus, .pFault)
        If 'tTakesTests Quit ..Conflict(##class(OcuPilot.Api.InteropError).#TESTTARGETTYPE, .pHttpStatus, .pFault)
        If '$List(tLine, 4) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#TESTTARGETDISABLED, .pHttpStatus, .pFault)
        If 'tTest("allowed") Quit ..Conflict(##class(OcuPilot.Api.InteropError).#TESTREQUESTTYPE, .pHttpStatus, .pFault)
        Set tSecret = 0
        For tI = 1:1:tTest("meta") {
            Set tPath = $List(tTest("meta", tI), 2)
            If (tKind = "object") && ($Get(tInput(tPath)) '= "") && ..SecretPath(tPath) {
                Set tSecret = 1
                Quit
            }
        }
        If tSecret Quit ..Conflict(##class(OcuPilot.Api.InteropError).#TESTSECRET, .pHttpStatus, .pFault)
    }
    Kill tViolations
    Set tViolations = 0
    If tTest("allowed") {
        For tI = 1:1:tTest("meta") {
            Set tPaths($List(tTest("meta", tI), 2)) = tI
        }
        Set tKey = ""
        For {
            Set tKey = $Order(tInput(tKey))
            If tKey = "" Quit
            If '$Data(tPaths(tKey)) Set tViolations($Increment(tViolations)) = $ListBuild(tKey, ##class(OcuPilot.Api.InteropError).#TESTFIELD)
        }
        Set tKey = ""
        For {
            Set tKey = $Order(tBad(tKey))
            If tKey = "" Quit
            Set tViolations($Increment(tViolations)) = $ListBuild(tKey, ##class(OcuPilot.Api.InteropError).#TESTVALUE)
        }
        Set pPlan("kind") = tKind
        Set pPlan("name") = tName
        If tKind = "document" {
            Set tContent = $Get(tInput(..#DOCUMENTFIELD))
            Set pPlan("content") = tContent
            If ($Length(tContent) < 1) || ($Length(tContent) > ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS) Set tViolations($Increment(tViolations)) = $ListBuild(..#DOCUMENTFIELD, ##class(OcuPilot.Api.InteropError).#TESTVALUE)
        } Else {
            For tI = 1:1:tTest("meta") {
                Set tRecord = tTest("meta", tI)
                Set tPath = $List(tRecord, 2)
                Set tTyped = $Get(tInput(tPath))
                If tTyped = "" {
                    If $List(tRecord, 5) && ..ParentGiven(tPath, .tInput) Set tViolations($Increment(tViolations)) = $ListBuild(tPath, ##class(OcuPilot.Api.InteropError).#TESTVALUE)
                    Continue
                }
                If ($List(tRecord, 7) '= "") && '$ListFind($List(tRecord, 7), tTyped) {
                    Set tViolations($Increment(tViolations)) = $ListBuild(tPath, ##class(OcuPilot.Api.InteropError).#TESTVALUE)
                    Continue
                }
                Set pPlan($Increment(pPlan)) = $ListBuild(tPath, $List(tRecord, 3), $List(tRecord, 8), $List(tRecord, 9), tTyped, tTyped)
            }
        }
        If (pAction '= "") && (tKind = "object") && pPlan {
            Set tCaught = ""
            Kill tConverted
            Set tOrigNS = $NAMESPACE
            Try {
                Set $NAMESPACE = pNamespace
                Do ..ConvertPlanHere(.pPlan, .tConverted)
                Set $NAMESPACE = tOrigNS
            } Catch ex {
                Set $NAMESPACE = tOrigNS
                Set tCaught = ex
            }
            If $IsObject(tCaught) Quit ..Mapped(tCaught, "the test values could not be judged", .pHttpStatus, .pFault)
            For tI = 1:1:tConverted {
                Set tViolations($Increment(tViolations)) = $ListBuild($List(tConverted(tI), 1), ##class(OcuPilot.Api.InteropError).#TESTVALUE)
            }
        }
        Set tValid = ('tViolations)
    }
    If (pAction '= "") && tViolations Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    Set pRow = {}
    Do pRow.%Set("Namespace", pNamespace, "string")
    Do pRow.%Set("Production", pProduction, "string")
    Do pRow.%Set("Name", tName, "string")
    Do pRow.%Set("Type", $Case(tBusiness, 1: "service", 2: "process", 3: "operation", : "unknown"), "string")
    Do pRow.%Set("Enabled", ''$List(tLine, 4), "boolean")
    Do pRow.%Set("State", tFacts("word"), "string")
    Do pRow.%Set("Testing", ''tTest("testing"), "boolean")
    Do pRow.%Set("RequestClass", pRequestClass, "string")
    Do pRow.%Set("Kind", tKind, "string")
    Do pRow.%Set("Fields", ..CanonicalFields(.tInput), "string")
    Do pRow.%Set("RequestValid", ''tValid, "boolean")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Whether a field of the dotted path <var>pPath</var> sits under a serial object some other field of <var>pInput</var>
/// gives a value, so a required field of an embedded object is asked for only when the object is in use. A field with no parent
/// is always asked for. Pure.</p>
ClassMethod ParentGiven(pPath As %String, ByRef pInput) As %Boolean [ Private ]
{
    If pPath '[ "." Quit 1
    Set tPrefix = $Piece(pPath, ".", 1, $Length(pPath, ".") - 1) _ "."
    Set tKey = ""
    For {
        Set tKey = $Order(pInput(tKey), 1, tValue)
        If tKey = "" Quit
        If (tValue '= "") && ($Extract(tKey, 1, $Length(tPrefix)) = tPrefix) Quit
    }
    Quit (tKey '= "")
}

/// <p>Build the request the plan <var>pPlan</var> (<method>ReadTestTarget</method>) describes, as an instance of
/// <var>pRequestClass</var>, in <var>pRequest</var>, and save it as the classic dialog does: a virtual document is
/// <code>ImportFromString</code> of its text (an EDI XML document's as <method>PastedXmlHere</method> hands it on, and refused as it
/// refuses it, AD-21), any other class a new instance with each field set, along its path, to its logical
/// value, then <code>%ValidateObject</code>; either is then <code>%Save</code>d when it is persistent. A request the vendor cannot
/// build or save is the error status, and <var>pField</var> the field to name it on. Called while the production's namespace is
/// switched, and only with a class <method>IsRequestClassHere</method> has accepted.</p>
ClassMethod BuildTestRequestHere(pRequestClass As %String, ByRef pPlan, Output pRequest, Output pField As %String) As %Status [ Private ]
{
    Set pRequest = ""
    Set pField = "RequestClass"
    Set tSC = $$$OK
    If pPlan("kind") = "document" {
        Set pField = ..#DOCUMENTFIELD
        Set tText = pPlan("content")
        If $ClassMethod(pRequestClass, "%Extends", ..#XMLDOCUMENT) {
            Set tReason = ..PastedXmlHere(pPlan("content"), .tText)
            If tReason '= "" Quit $$$ERROR($$$GeneralError, tReason)
        }
        Set tImport = $$$OK
        Set tObject = ..ImportDocumentHere(pRequestClass, tText, .tImport)
        If $$$ISERR(tImport) Quit tImport
        If '$IsObject(tObject) Quit $$$ERROR($$$GeneralError, "the text did not give a " _ pRequestClass)
    } Else {
        Set tObject = $ClassMethod(pRequestClass, "%New")
        If '$IsObject(tObject) Quit $$$ERROR($$$GeneralError, "a " _ pRequestClass _ " could not be created")
        Set tFailed = ..ApplyFieldsHere(tObject, .pPlan)
        If tFailed '= "" Quit $$$ERROR($$$GeneralError, tFailed)
        Set tSC = tObject.%ValidateObject()
        If $$$ISERR(tSC) Quit tSC
    }
    If tObject.%Extends("%Library.Persistent") {
        Set tSC = tObject.%Save()
        If $$$ISERR(tSC) Quit tSC
    }
    Set pRequest = tObject
    Quit $$$OK
}

/// <p>Set each field of the plan <var>pPlan</var> (<method>ReadTestTarget</method>'s) on <var>pObject</var>, along its path, to the
/// plan element's logical value (its sixth member), creating the embedded serial object a path passes where the object holds none.
/// With <var>pCloneEmbedded</var> an embedded object the object already holds is replaced by a copy of it before its first field is
/// set, so the objects the original shares with a clone of it are never changed (Story 20.31). The answer is <code>""</code>, or
/// what could not be created. Called while the production's namespace is switched.</p>
ClassMethod ApplyFieldsHere(pObject As %RegisteredObject, ByRef pPlan, pCloneEmbedded As %Boolean = 0) As %String [ Private ]
{
    Set tFailed = ""
    Kill tCopied
    For tI = 1:1:+$Get(pPlan) {
        If tFailed '= "" Quit
        Set tRecord = pPlan(tI)
        Set tChain = $List(tRecord, 4)
        Set tCurrent = pObject
        For tJ = 1:1:$Length($List(tRecord, 1), ".") - 1 {
            Set tSegment = $Piece($List(tRecord, 1), ".", tJ)
            Set tPrefix = $Piece($List(tRecord, 1), ".", 1, tJ)
            Set tNext = $Property(tCurrent, tSegment)
            If '$IsObject(tNext) {
                Set tNext = $ClassMethod($List(tChain, tJ), "%New")
                If '$IsObject(tNext) {
                    Set tFailed = "an embedded " _ $List(tChain, tJ) _ " could not be created"
                    Quit
                }
                Set $Property(tCurrent, tSegment) = tNext
                Set tCopied(tPrefix) = ""
            } ElseIf pCloneEmbedded && '$Data(tCopied(tPrefix)) {
                Set tNext = tNext.%ConstructClone(1)
                Set $Property(tCurrent, tSegment) = tNext
                Set tCopied(tPrefix) = ""
            }
            Set tCurrent = tNext
        }
        If tFailed '= "" Quit
        Set $Property(tCurrent, $List(tRecord, 2)) = $List(tRecord, 6)
    }
    Quit tFailed
}

/// <p>Wait, at most <method>TestWait</method> seconds, for the test session <var>pSession</var>'s answer, reading every
/// <parameter>TESTPOLL</parameter> seconds whether the vendor has recorded its <code>response</code> node, the last one it writes
/// for a finished session (after the top node reads <code>Done</code> or <code>Error</code>), as the classic dialog waits on it;
/// then gather what the vendor kept in <var>pAnswer</var>: <code>status</code> (<code>done</code>, <code>error</code> or
/// <code>waiting</code>), then for an error its <code>error</code> text, for a response <code>responseClass</code> and either its
/// text (<code>document</code>) or its fields (<code>field(n)</code>, <code>$ListBuild(path, value)</code>). A finished session's
/// node is killed, as the classic dialog kills it once it has drawn the answer; a session still waiting is left for the vendor's
/// own cleanup. It names the vendor's <code>^IRIS.Temp.EnsRuntimeAppData</code> node directly, because the include file that
/// defines its macro does not exist where interoperability is not enabled (AD-62 item 12). Called while the production's
/// namespace is switched, and inside the output capture.</p>
ClassMethod AwaitTestHere(pSession As %String, Output pAnswer) [ Private ]
{
    Kill pAnswer
    Set pAnswer("status") = "waiting"
    Set pAnswer("responseClass") = ""
    Set pAnswer("fields") = 0
    Set tDeadline = $ZHorolog + ..TestWait()
    Set tAnswered = 0
    For {
        If $Data(^IRIS.Temp.EnsRuntimeAppData($Namespace, ..#TESTSERVICE, pSession, "response")) Set tAnswered = 1 Quit
        If $ZHorolog >= tDeadline Quit
        Hang ..#TESTPOLL
    }
    Set tState = $Select(tAnswered: $Get(^IRIS.Temp.EnsRuntimeAppData($Namespace, ..#TESTSERVICE, pSession)), 1: "")
    If tState = "Error" {
        Set pAnswer("status") = "error"
        Set tError = $Get(^IRIS.Temp.EnsRuntimeAppData($Namespace, ..#TESTSERVICE, pSession, "error"))
        Set pAnswer("error") = $Select(tError = "": "", 1: $System.Status.GetErrorText(tError))
    } ElseIf tState = "Done" {
        Set pAnswer("status") = "done"
        Do ..CollectResponseHere($Get(^IRIS.Temp.EnsRuntimeAppData($Namespace, ..#TESTSERVICE, pSession, "response")), .pAnswer)
    }
    If (tState = "Done") || (tState = "Error") Kill ^IRIS.Temp.EnsRuntimeAppData($Namespace, ..#TESTSERVICE, pSession)
}

/// <p>Open the response <var>pSpec</var> names (<code>$ListBuild(class, id)</code>, the vendor's own record) and gather it into
/// <var>pAnswer</var> as <method>AwaitTestHere</method> describes. A response the namespace no longer holds, or that is not a
/// persistent class, gathers nothing. Called while the production's namespace is switched.</p>
ClassMethod CollectResponseHere(pSpec As %String, ByRef pAnswer) [ Private ]
{
    Set tClass = $Select(pSpec = "": "", 1: $ListGet(pSpec, 1))
    Set tId = $Select(pSpec = "": "", 1: $ListGet(pSpec, 2))
    If tClass = "" Quit
    Set tObject = ..OpenBodyHere(tClass, tId)
    If '$IsObject(tObject) || 'tObject.%Extends("%Library.Persistent") Quit
    Set pAnswer("responseClass") = tClass
    If ..IsDocumentClassHere(tClass) {
        Set tText = ""
        Try {
            Set tText = tObject.OutputToString()
        } Catch {
            Set tText = ""
        }
        Set pAnswer("document") = tText
        Quit
    }
    Do ..ClassFieldsHere(tClass, .tMeta)
    For tI = 1:1:tMeta {
        If $List(tMeta(tI), 1) '= "object" Continue
        Set tPath = $List(tMeta(tI), 2)
        Set tCurrent = tObject
        For tJ = 1:1:$Length(tPath, ".") - 1 {
            Set tCurrent = $Property(tCurrent, $Piece(tPath, ".", tJ))
            If '$IsObject(tCurrent) Quit
        }
        Set tValue = ""
        If $IsObject(tCurrent) {
            Set tValue = $Property(tCurrent, $List(tMeta(tI), 3))
            Set tOwner = $List(tMeta(tI), 8)
            If ##class(%Dictionary.CompiledMethod).%ExistsId(tOwner _ "||" _ $List(tMeta(tI), 3) _ "LogicalToDisplay") {
                Set tValue = $ClassMethod(tOwner, $List(tMeta(tI), 3) _ "LogicalToDisplay", tValue)
            }
        }
        Set pAnswer("fields") = pAnswer("fields") + 1
        Set pAnswer("field", pAnswer("fields")) = $ListBuild(tPath, tValue)
    }
}

/// <p>End the output capture <var>pCookie</var> opened for a test and answer what the vendor wrote to the device, as one text
/// at most <parameter>TESTOUTPUTMAX</parameter> characters long. <var>pLines</var> is the captured lines themselves, a
/// <class>%DynamicArray</class>, for a caller that shows them (Story 20.27). A host test's answer carries none of what it wrote: its
/// caller logs it.</p>
ClassMethod EndTestCapture(pCookie As %String, Output pLines As %DynamicArray) As %String [ Private ]
{
    Set tText = ""
    Set pLines = []
    Try {
        Kill tLines
        Set tEndSC = $$EndCapture^%SYS.Capture(pCookie, .tLines)
        If $IsObject($Get(tLines)) {
            Set pLines = tLines
            Set tIterator = tLines.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tLine) {
                If ($Length(tText) + $Length(tLine)) >= ..#TESTOUTPUTMAX Quit
                Set tText = tText _ tLine
            }
        }
    } Catch {
        Set tText = ""
        Set pLines = []
    }
    Quit tText
}

/// <p>The lines <var>pText</var> is made of, split at a line feed, a carriage return or both, in <var>pLines</var> (a
/// <class>%DynamicArray</class>) after the ones already in it, a trailing empty line left out. <var>pChars</var> counts the
/// characters so far and is not allowed past <parameter>TESTOUTPUTMAX</parameter>: the line that would pass it is cut and
/// marked, and <var>pCut</var> is 1. Pure.</p>
ClassMethod AddTestLines(pText As %String, pLines As %DynamicArray, ByRef pChars As %Integer, ByRef pCut As %Boolean) [ Private ]
{
    Set tText = $Translate($Replace(pText, $Char(13, 10), $Char(10)), $Char(13), $Char(10))
    Set tLength = $Length(tText)
    Set tStart = 1
    While 'pCut && (tStart <= tLength) {
        Set tEnd = $Find(tText, $Char(10), tStart)
        Set tLine = $Extract(tText, tStart, $Select(tEnd: tEnd - 2, 1: tLength))
        Set tStart = $Select(tEnd: tEnd, 1: tLength + 1)
        If (pChars + $Length(tLine)) > ..#TESTOUTPUTMAX {
            Set tLine = $Extract(tLine, 1, ..#TESTOUTPUTMAX - pChars) _ ..#TESTCUT
            Set pCut = 1
        }
        Set pChars = pChars + $Length(tLine)
        Do pLines.%Push(tLine, "string")
    }
}

/// <p>The lines a test answer shows: an error's text, a document response's text, or one <code>Path: value</code> line for each
/// response field, a value cut at <parameter>TESTVALUEMAX</parameter> characters and marked, and a credential-named field
/// blank. The lines of one result hold at most <parameter>TESTOUTPUTMAX</parameter> characters in all, the last marked. Not
/// called while a namespace is switched.</p>
ClassMethod TestLines(ByRef pAnswer) As %DynamicArray [ Private ]
{
    Set tLines = []
    Set tChars = 0
    Set tCut = 0
    If pAnswer("status") = "error" {
        Do ..AddTestLines($Get(pAnswer("error")), tLines, .tChars, .tCut)
        Quit tLines
    }
    If $Data(pAnswer("document")) {
        Do ..AddTestLines(pAnswer("document"), tLines, .tChars, .tCut)
        Quit tLines
    }
    For tI = 1:1:pAnswer("fields") {
        If tCut Quit
        Set tPath = $List(pAnswer("field", tI), 1)
        Set tValue = $List(pAnswer("field", tI), 2)
        If ..SecretPath(tPath) Set tValue = ""
        If $Length(tValue) > ..#TESTVALUEMAX Set tValue = $Extract(tValue, 1, ..#TESTVALUEMAX) _ ..#TESTCUT
        Set tValue = $Translate(tValue, $Char(13, 10), "  ")
        Do ..AddTestLines(tPath _ ": " _ tValue, tLines, .tChars, .tCut)
    }
    Quit tLines
}

/// <p>Send the test <var>pQuery</var> carries to the item <var>pItem</var> of <var>pProduction</var> (Story 20.6). The composed
/// read (<method>ReadTestTarget</method>) refuses first, with the send's action, so nothing is built that would be refused;
/// then, inside the output capture and the production's namespace, the request is built and saved
/// (<method>BuildTestRequestHere</method>), sent asynchronously through <method>VendorSendTest</method> and its answer waited
/// for (<method>AwaitTestHere</method>) for at most <method>TestWait</method> seconds.</p>
/// <p>The answer is <code>{status, sessionId, responseClass, lines, errors}</code>: <code>done</code> with the response's fields
/// (or its text) as <code>lines</code>, or no line for a target that answers nothing; <code>error</code> with the error's text;
/// or <code>waiting</code> with the session, nothing more yet. A request the vendor cannot build or save is 422
/// <code>INTEROP.TEST.REQUEST</code> on the field, its vendor text in the log only; a vendor refusal is mapped to the
/// published code that says it (the testing service not registered is <code>DISABLED</code>), and the text the vendor wrote to
/// the device is logged and never answered. OcuPilot's own audit row records the test, never a field value, an input or an
/// answer (<method>AuditRuntime</method>).</p>
ClassMethod PerformTest(pNamespace As %String, pProduction As %String, pItem As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tClass = $Get(pQuery(..#REQUESTCLASSKEY))
    Set tSC = ..ReadTestTarget(pNamespace, pProduction, pItem, ..#TYPESENDTEST, tClass, $Get(pQuery(..#FIELDSKEY)), .tRow, .tPlan, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tTarget = tRow.%Get("Name")
    Set tCaught = ""
    Set tBuildSC = $$$OK
    Set tSendSC = $$$OK
    Set tSession = ""
    Set tField = "RequestClass"
    Kill tAnswer
    Set tAnswer("status") = "waiting"
    Set tOrigNS = $NAMESPACE
    Set tCaptureSC = $$BeginCapture^%SYS.Capture(.tCookie)
    If $$$ISERR(tCaptureSC) Quit ..Fail("the test could not capture the vendor's output", tCaptureSC, .pHttpStatus, .pFault)
    Try {
        Set $NAMESPACE = pNamespace
        Set tBuildSC = ..BuildTestRequestHere(tClass, .tPlan, .tRequest, .tField)
        If $$$ISOK(tBuildSC) {
            Set tSendSC = ..VendorSendTest(pNamespace, tTarget, tRequest, .tSession)
            Set tRequest = ""
            If $$$ISOK(tSendSC) Do ..AwaitTestHere(tSession, .tAnswer)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    Set tWritten = ..EndTestCapture(tCookie)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the test could not be sent", .pHttpStatus, .pFault)
    If $$$ISERR(tBuildSC) {
        Do ..LogFault("the test request could not be built", tBuildSC)
        Set tViolations = 1
        Set tViolations(1) = $ListBuild(tField, ##class(OcuPilot.Api.InteropError).#TESTREQUEST)
        Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSendSC) {
        Do ..LogFault("the test request could not be sent" _ $Select(tWritten = "": "", 1: "; the vendor wrote: " _ $Extract(tWritten, 1, 1000)), tSendSC)
        If ..HasCode(tSendSC, ..#CODENOTREGISTERED) && ($System.Status.GetErrorText(tSendSC) [ ..#TESTSERVICE) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#TESTDISABLED, .pHttpStatus, .pFault)
        If ..HasCode(tSendSC, ..#CODEPRODUCTIONNOTRUNNING) || ..HasCode(tSendSC, ..#CODEPRODUCTIONQUIESCENT) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#NOTRUNNING, .pHttpStatus, .pFault)
        Quit ..Statused(tSendSC, "the test request could not be sent", .pHttpStatus, .pFault)
    }
    Set tStatus = tAnswer("status")
    Set pResult = {}
    Do pResult.%Set("status", tStatus, "string")
    Do pResult.%Set("sessionId", tSession _ "", "string")
    Do pResult.%Set("responseClass", $Get(tAnswer("responseClass")), "string")
    Do pResult.%Set("lines", ..TestLines(.tAnswer))
    Do pResult.%Set("errors", (tStatus = "error"), "boolean")
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("production", pProduction, "string")
    Do tEffects.%Set("item", tTarget, "string")
    Do tEffects.%Set("requestClass", tClass, "string")
    Do tEffects.%Set("sessionId", tSession _ "", "string")
    Do tEffects.%Set("status", tStatus, "string")
    Do ..AuditRuntime(..#VERBTEST, ..#ENTITYITEM, ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pProduction, tTarget)), tEffects)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Serve the Transforms endpoint's typed calls (Story 20.27) after <method>Invoke</method>'s gate: <code>TRANSFORM</code>, the
/// composed fresh read of a data transformation, and <code>TRANSFORMTEST</code>, its test. The transformation is named under
/// <parameter>IDKEY</parameter> by its document name (<code>&lt;class&gt;.cls</code>, as the list reports it) and the pasted source
/// message travels under <parameter>CONTENTKEY</parameter>. A name that is missing is 400; one that no listed, compiled
/// transformation has is 404 <code>PORT.NOTFOUND</code>.</p>
ClassMethod InvokeTransformTest(pNamespace As %String, pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Set tName = $Get(pQuery(..#IDKEY))
        If tName = "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONTRANSFORMID, .pHttpStatus, .pFault)
            Quit
        }
        Set tAction = $Select(pType = ..#TYPETRANSFORMTEST: pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && (tAction '= ..#TYPETRANSFORMTEST) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPETRANSFORMTEST {
            Set tSC = ..PerformTransformTest(pNamespace, tName, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..ReadTransform(pNamespace, tName, tAction, $Get(pQuery(..#CONTENTKEY)), .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the data transformation call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The class a Transforms row named <var>pName</var> stands for: the name without its <parameter>CLASSEXTENSION</parameter>, or
/// <code>""</code> when <var>pName</var> is not a class document name. Pure.</p>
ClassMethod TransformClassOf(pName As %String) As %String [ Private ]
{
    Set tLength = $Length(pName)
    Set tExtension = $Length(..#CLASSEXTENSION)
    If (tLength <= tExtension) || ($Extract(pName, tLength - tExtension + 1, tLength) '= ..#CLASSEXTENSION) Quit ""
    Set tClass = $Extract(pName, 1, tLength - tExtension)
    If '$Match(tClass, ..#CLASSNAMEPATTERN) Quit ""
    Quit tClass
}

/// <p>The format of the class <var>pClass</var> as the data transformation test reads it, judged in this order: <code>recordmap</code>
/// for a Record Map record or batch class (<parameter>RECORDMAPBASES</parameter>, even though most are
/// <parameter>XMLADAPTOR</parameter>), <code>document</code> for a virtual document (<parameter>DOCUMENTBASE</parameter>, segments and
/// EDI XML included), <code>xml</code> for an <parameter>XMLADAPTOR</parameter> class, and <code>other</code> for anything else,
/// a class the namespace does not hold among it. Called while the production's namespace is switched.</p>
ClassMethod FormatKindHere(pClass As %String) As %String [ Private ]
{
    If '$Match(pClass, ..#CLASSNAMEPATTERN) Quit "other"
    If '##class(%Dictionary.CompiledClass).%ExistsId(pClass) Quit "other"
    Set tRecordMap = 0
    For tI = 1:1:$Length(..#RECORDMAPBASES, ",") {
        If $ClassMethod(pClass, "%Extends", $Piece(..#RECORDMAPBASES, ",", tI)) Set tRecordMap = 1
    }
    If tRecordMap Quit "recordmap"
    If $ClassMethod(pClass, "%Extends", ..#DOCUMENTBASE) Quit "document"
    If $ClassMethod(pClass, "%Extends", ..#XMLADAPTOR) Quit "xml"
    Quit "other"
}

/// <p>The facts of the data transformation class <var>pClass</var> in <var>pFacts</var>: <code>listed</code> (a subclass of
/// <parameter>TRANSFORMBASE</parameter> other than <parameter>TRANSFORMDTL</parameter>, as <method>ListClasses</method> lists it),
/// <code>compiled</code> and, for a class that is both, <code>sourceClass</code>, <code>sourceDocType</code>,
/// <code>sourceKind</code>, <code>targetClass</code>, <code>targetDocType</code>, <code>targetKind</code>, <code>create</code>,
/// <code>sourceXml</code>, <code>targetXml</code> and <code>targetSegmented</code>. It instantiates nothing and calls no <code>Transform</code>. Called
/// while the production's namespace is switched.</p>
ClassMethod TransformFactsHere(pClass As %String, Output pFacts) [ Private ]
{
    Kill pFacts
    Set pFacts("listed") = 0
    Set pFacts("compiled") = 0
    Set tResult = ##class(%ResultSet).%New("%Dictionary.ClassDefinition:SubclassOf")
    Set tStatus = tResult.Execute(..#TRANSFORMBASE)
    If $$$ISERR(tStatus) Throw ##class(%Exception.StatusException).CreateFromStatus(tStatus)
    While tResult.Next() {
        If (tResult.GetData(1) = pClass) && (pClass '= ..#TRANSFORMDTL) {
            Set pFacts("listed") = 1
            Quit
        }
    }
    Do tResult.Close()
    Set tResult = ""
    If 'pFacts("listed") Quit
    If '##class(%Dictionary.CompiledClass).%ExistsId(pClass) Quit
    Set pFacts("compiled") = 1
    Set pFacts("sourceClass") = $ClassMethod(pClass, "GetSourceType")
    Set pFacts("targetClass") = $ClassMethod(pClass, "GetTargetType", .tCreate)
    Set pFacts("create") = $Get(tCreate)
    Set pFacts("sourceDocType") = $ClassMethod(pClass, "GetSourceDocType")
    Set pFacts("targetDocType") = $ClassMethod(pClass, "GetTargetDocType")
    Set pFacts("sourceKind") = ..FormatKindHere(pFacts("sourceClass"))
    Set pFacts("targetKind") = ..FormatKindHere(pFacts("targetClass"))
    Set pFacts("sourceXml") = (pFacts("sourceKind") = "document") && ''$ClassMethod(pFacts("sourceClass"), "%Extends", ..#XMLDOCUMENT)
    Set pFacts("targetXml") = (pFacts("targetKind") = "document") && ''$ClassMethod(pFacts("targetClass"), "%Extends", ..#XMLDOCUMENT)
    Set pFacts("targetSegmented") = (pFacts("targetKind") = "document") && ''$ClassMethod(pFacts("targetClass"), "%Extends", ..#SEGMENTEDDOCUMENT)
}

/// <p>The data transformation <var>pName</var> (<code>&lt;class&gt;.cls</code>), read for the test (Story 20.27) in
/// <var>pRow</var>: <code>{Namespace, Name, SourceClass, SourceDocType, SourceKind, TargetClass, TargetDocType, TargetKind, Create,
/// content}</code>, the kinds being <code>document</code>, <code>xml</code>, <code>recordmap</code> or <code>other</code>
/// (<method>FormatKindHere</method>) and <code>content</code> the pasted message <var>pContent</var> as given. It writes nothing and
/// calls no <code>Transform</code>. A name that is not a listed transformation compiled in the namespace is 404.</p>
/// <p>With <var>pAction</var> (the test) it then refuses, in this order and before anything is parsed or run: 409
/// <code>INTEROP.TRANSFORM.SOURCEFORMAT</code> and <code>TARGETFORMAT</code> for a class that is neither a virtual document nor
/// <parameter>XMLADAPTOR</parameter>, and 422 <code>INTEROP.TRANSFORM.CONTENT</code> on <code>content</code> for a message that is
/// empty or past <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter> characters.</p>
ClassMethod ReadTransform(pNamespace As %String, pName As %String, pAction As %String, pContent As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set tClass = ..TransformClassOf(pName)
    If tClass = "" Quit ..Absent(.pHttpStatus, .pFault)
    Set tCaught = ""
    Kill tFacts
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..TransformFactsHere(tClass, .tFacts)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the data transformation could not be read", .pHttpStatus, .pFault)
    If 'tFacts("listed") || 'tFacts("compiled") Quit ..Absent(.pHttpStatus, .pFault)
    If pAction '= "" {
        If '$ListFind($ListBuild("document", "xml"), tFacts("sourceKind")) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#TRANSFORMSOURCEFORMAT, .pHttpStatus, .pFault)
        If '$ListFind($ListBuild("document", "xml"), tFacts("targetKind")) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#TRANSFORMTARGETFORMAT, .pHttpStatus, .pFault)
        If ($Length(pContent) < 1) || ($Length(pContent) > ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS) {
            Set tViolations = 1
            Set tViolations(1) = $ListBuild(..#CONTENTKEY, ##class(OcuPilot.Api.InteropError).#TRANSFORMCONTENT)
            Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
        }
    }
    Set pRow = {}
    Do pRow.%Set("Namespace", pNamespace, "string")
    Do pRow.%Set("Name", pName, "string")
    Do pRow.%Set("SourceClass", tFacts("sourceClass"), "string")
    Do pRow.%Set("SourceDocType", tFacts("sourceDocType"), "string")
    Do pRow.%Set("SourceKind", tFacts("sourceKind"), "string")
    Do pRow.%Set("TargetClass", tFacts("targetClass"), "string")
    Do pRow.%Set("TargetDocType", tFacts("targetDocType"), "string")
    Do pRow.%Set("TargetKind", tFacts("targetKind"), "string")
    Do pRow.%Set("Create", $Select(tFacts("create") = "": "new", 1: tFacts("create")), "string")
    Do pRow.%Set("content", pContent, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The text of <var>pContent</var> parsed as <var>pClass</var>, an object in <var>pObject</var> and the vendor's status in
/// <var>pStatus</var>: for <code>document</code> its <code>ImportFromString</code>, whose result is made immutable
/// (<code>IsMutable</code> 0) as the vendor's serialized reader makes it; for <code>xml</code> the XML reader's
/// <code>ObjectFromString</code> with <class>%XML.SAX.NullEntityResolver</class>, so a schema the text names is not opened. XML text,
/// an EDI XML document's included, is read as <method>PastedXmlHere</method> hands it on, and refused as it refuses it (AD-21).
/// Called while the production's namespace is switched.</p>
ClassMethod ParseSourceHere(pClass As %String, pKind As %String, pContent As %String, Output pObject, Output pStatus As %Status) [ Private ]
{
    Set pObject = ""
    Set pStatus = $$$OK
    Set tText = pContent
    If (pKind = "xml") || ((pKind = "document") && $ClassMethod(pClass, "%Extends", ..#XMLDOCUMENT)) {
        Set tReason = ..PastedXmlHere(pContent, .tText)
        If tReason '= "" {
            Set pStatus = $$$ERROR($$$GeneralError, tReason)
            Quit
        }
    }
    If pKind = "document" {
        Set pObject = ..ImportDocumentHere(pClass, tText, .pStatus)
        If $IsObject(pObject) {
            Try {
                Set pObject.IsMutable = 0
            } Catch {
            }
        }
        Quit
    }
    Set pStatus = ##class(Ens.Util.XML.Reader).ObjectFromString(.pObject, tText, pClass, ##class(%XML.SAX.NullEntityResolver).%New())
}

/// <p>Pasted XML text <var>pContent</var> as a parser is handed it, in <var>pText</var>: the text from its first character that is not
/// a blank, a line end, another control character or a byte order mark. The answer is <code>""</code>, or the reason the text is not
/// read: its first such character is not <code>&lt;</code>, because an EDI XML document opens text with no <code>&lt;</code> among its
/// first characters as a file name; or it declares a document type, which names a file or URL the parser opens and can declare an
/// entity that reads one (AD-21). Pure.</p>
ClassMethod PastedXmlHere(pContent As %String, Output pText As %String) As %String [ Private ]
{
    Set pText = $ZStrip(pContent, "<WC", $Char(65279))
    If $Extract(pText) '= "<" Quit "Not XML Format"
    If $ZConvert(pText, "U") [ "<!DOCTYPE" Quit "A pasted message is not read with a document type declaration (<!DOCTYPE>)"
    Quit ""
}

/// <p>The separators the raw view of the segmented document <var>pTarget</var> is written with, as the classic Test Transform dialog
/// builds them: the document's own, completed from its first segment's, with the segment terminator of an X12 or EDIFACT document,
/// and each segment followed by a carriage return and line feed. Called while the production's namespace is switched.</p>
ClassMethod SeparatorsHere(pTarget As %RegisteredObject) As %String [ Private ]
{
    Set tSegment = pTarget.GetSegmentAt(1)
    Set tSeparators = $Select($IsObject(tSegment): tSegment.Separators, 1: "")
    Set tOwn = pTarget.Separators
    If $Extract(tOwn, 1, $Length(tSeparators)) '= $Extract(tSeparators, 1, $Length(tOwn)) {
        Set tSeparators = $Extract(tOwn, 1, $Length(tSeparators)) _ $Extract(tSeparators, 1 + $Length(tOwn), *)
    }
    If pTarget.%Extends("EnsLib.EDI.X12.Document") || pTarget.%Extends("EnsLib.EDI.EDIFACT.Document") Set tSeparators = tSeparators _ pTarget.SegmentTerminator
    If $Char(10) '= $Extract(tSeparators, *) Set tSeparators = tSeparators _ $Char(10)
    If $Char(13) '= $Extract(tSeparators, *-1) Set tSeparators = $Extract(tSeparators, 1, *-1) _ $Char(13, 10)
    Quit tSeparators
}

/// <p>The text of the target <var>pTarget</var> in <var>pText</var>, at most <parameter>TESTOUTPUTMAX</parameter> + 1 characters of
/// it, followed by <parameter>TESTCUT</parameter> when the stream held more (the line total <method>AddTestLines</method> keeps does
/// not count line ends, so it cannot see that cut), and the vendor's status: EDI XML as indented XML, any other segmented document as the classic raw view
/// (<method>SeparatorsHere</method>), any other document as its library stream, and an <parameter>XMLADAPTOR</parameter> object
/// through <code>%XML.Writer</code> indented. An object that is neither is an error status. Called while the production's
/// namespace is switched, by the transformation test (Story 20.27) and by a message's Contents read
/// (<method>ContentsText</method>, Story 20.9).</p>
ClassMethod RenderTargetHere(pTarget As %RegisteredObject, Output pText As %String) As %Status [ Private ]
{
    Set pText = ""
    Set tStream = ##class(%Stream.TmpCharacter).%New()
    If pTarget.%Extends(..#DOCUMENTBASE) {
        If pTarget.%Extends(..#XMLDOCUMENT) {
            Set tSC = pTarget.OutputToLibraryStream(tStream, "wt")
        } ElseIf pTarget.%Extends(..#SEGMENTEDDOCUMENT) {
            Set tSC = pTarget.OutputToLibraryStream(tStream, ..SeparatorsHere(pTarget))
        } Else {
            Set tSC = pTarget.OutputToLibraryStream(tStream)
        }
    } ElseIf pTarget.%Extends(..#XMLADAPTOR) {
        Set tWriter = ##class(%XML.Writer).%New()
        Set tWriter.Indent = 1
        Set tSC = tWriter.OutputToStream(tStream)
        If $$$ISOK(tSC) Set tSC = tWriter.RootObject(pTarget)
    } Else {
        Quit $$$ERROR($$$GeneralError, "Object doesn't support EDI or XML output")
    }
    If $$$ISERR(tSC) Quit tSC
    Do tStream.Rewind()
    Set pText = ..StreamText(tStream)
    Quit $$$OK
}

/// <p>The text of the character stream <var>pStream</var> from its current position: at most <parameter>TESTOUTPUTMAX</parameter> + 1
/// characters of it, followed by <parameter>TESTCUT</parameter> when the stream held more. The one reader of a rendered
/// target (<method>RenderTargetHere</method>) and of a message body that is a character stream (<method>ContentsText</method>).</p>
ClassMethod StreamText(pStream As %Stream.Object) As %String [ Private ]
{
    Set tText = pStream.Read(..#TESTOUTPUTMAX + 1)
    If 'pStream.AtEnd Set tText = tText _ ..#TESTCUT
    Quit tText
}

/// <p>Run the data transformation <var>pClass</var> once on the pasted message <var>pContent</var> (Story 20.27): parse it as
/// <var>pSourceClass</var> (<method>ParseSourceHere</method>), create the target for <code>existing</code> with <code>%New()</code>
/// and no argument, call <code>Transform</code> with empty <code>process</code>, <code>context</code> and <code>aux</code>, render the target
/// (<method>RenderTargetHere</method>), then delete every source or target that gained an <code>%Id()</code>, whatever happened.
/// <var>pOutcome</var><code>("status")</code> is <code>done</code>, <code>input</code> (the parse answered an error or no
/// object), <code>transform</code> (an error status or a fault) or <code>output</code> (no target, a render error or a target that is
/// neither kind), <var>pOutcome</var><code>("text")</code> the target's text or the status's error text, and
/// <var>pOutcome</var><code>("deleteFailed")</code> and <code>("deleteStatus")</code> a delete the vendor refused. Called while the
/// production's namespace is switched and inside the output capture; it calls no <code>OcuPilot.*</code> class and the namespace is
/// the one it began in when it returns.</p>
ClassMethod RunTransformHere(pClass As %String, pSourceClass As %String, pSourceKind As %String, pTargetCreate As %String, pTargetClass As %String, pContent As %String, Output pOutcome) [ Private, PublicList = (process, context) ]
{
    Kill pOutcome
    Set pOutcome("status") = "done"
    Set pOutcome("text") = ""
    Set pOutcome("deleteFailed") = 0
    Set tSource = ""
    Set tTarget = ""
    Set tHere = $NAMESPACE
    Set tStage = "input"
    New process, context
    Set process = ""
    Set context = ""
    Try {
        Do ..ParseSourceHere(pSourceClass, pSourceKind, pContent, .tSource, .tParse)
        If $$$ISERR(tParse) || '$IsObject(tSource) {
            Set pOutcome("status") = "input"
            Set pOutcome("text") = $Select($$$ISERR(tParse): $System.Status.GetErrorText(tParse), 1: "")
            Quit
        }
        Set tStage = "transform"
        If pTargetCreate = "existing" {
            Set tTarget = $ClassMethod(pTargetClass, "%New")
            If '$IsObject(tTarget) {
                Set pOutcome("status") = "transform"
                Set pOutcome("text") = "No existing target object"
                Quit
            }
        }
        Set tTransform = $ClassMethod(pClass, "Transform", tSource, .tTarget, "")
        If $NAMESPACE '= tHere Set $NAMESPACE = tHere
        If $$$ISERR(tTransform) {
            Set pOutcome("status") = "transform"
            Set pOutcome("text") = $System.Status.GetErrorText(tTransform)
            Quit
        }
        Set tStage = "output"
        If '$IsObject(tTarget) {
            Set pOutcome("status") = "output"
            Set pOutcome("text") = "No object created"
            Quit
        }
        Set tRender = ..RenderTargetHere(tTarget, .tText)
        If $$$ISERR(tRender) {
            Set pOutcome("status") = "output"
            Set pOutcome("text") = $System.Status.GetErrorText(tRender)
            Quit
        }
        Set pOutcome("text") = tText
    } Catch ex {
        Set pOutcome("status") = tStage
        Set pOutcome("text") = $System.Status.GetErrorText(ex.AsStatus())
    }
    If $NAMESPACE '= tHere Set $NAMESPACE = tHere
    Kill tStored
    Set tStored = 0
    For tObject = tSource, tTarget {
        If '$IsObject(tObject) Continue
        If 'tObject.%Extends("%Library.Persistent") Continue
        If tObject.%Id() = "" Continue
        Set tStored($Increment(tStored)) = $ListBuild(tObject.%ClassName(1), tObject.%Oid())
    }
    Set tObject = ""
    Set tSource = ""
    Set tTarget = ""
    For tI = 1:1:tStored {
        Try {
            Set tDelete = $ClassMethod($List(tStored(tI), 1), "%Delete", $List(tStored(tI), 2))
        } Catch ex {
            Set tDelete = ex.AsStatus()
        }
        If $$$ISERR(tDelete) {
            Set pOutcome("deleteFailed") = 1
            Set pOutcome("deleteStatus") = tDelete
        }
    }
}

/// <p>Run the data transformation <var>pName</var> once on the pasted message <var>pQuery</var> carries under
/// <parameter>CONTENTKEY</parameter> (Story 20.27). The composed read (<method>ReadTransform</method>) refuses first, with the test's
/// action, so nothing is parsed or run that would be refused; then, inside the output capture and the production's namespace,
/// <method>RunTransformHere</method> parses, runs, renders and cleans up; then the namespace is restored and the answer composed.</p>
/// <p>The answer is <code>{status, sourceClass, targetClass, lines, console, errors}</code>: <code>status</code> is
/// <code>done</code>, <code>input</code>, <code>transform</code> or <code>output</code>, <code>errors</code> is true for the last three,
/// <code>lines</code> holds the target's text or the status's error text, and <code>console</code> what the vendor calls wrote to the
/// device. Both go through <method>AddTestLines</method> sharing one <parameter>TESTOUTPUTMAX</parameter> total. A stored object the
/// vendor refuses to delete is logged without any content and does not change the answer. OcuPilot's own audit row records the run,
/// never the message, a line or the console (<method>AuditRuntime</method>).</p>
ClassMethod PerformTransformTest(pNamespace As %String, pName As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tContent = $Get(pQuery(..#CONTENTKEY))
    Set tSC = ..ReadTransform(pNamespace, pName, ..#TYPETRANSFORMTEST, tContent, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tClass = ..TransformClassOf(pName)
    Set tSourceClass = tRow.%Get("SourceClass")
    Set tTargetClass = tRow.%Get("TargetClass")
    Set tCreate = tRow.%Get("Create")
    Set tSourceKind = tRow.%Get("SourceKind")
    Set tRow = ""
    Set tCaught = ""
    Kill tOutcome
    Set tOrigNS = $NAMESPACE
    Set tCaptureSC = $$BeginCapture^%SYS.Capture(.tCookie)
    If $$$ISERR(tCaptureSC) Quit ..Fail("the transformation test could not capture the vendor's output", tCaptureSC, .pHttpStatus, .pFault)
    Try {
        Set $NAMESPACE = pNamespace
        Do ..RunTransformHere(tClass, tSourceClass, tSourceKind, tCreate, tTargetClass, tContent, .tOutcome)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    Do ..EndTestCapture(tCookie, .tCaptured)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the transformation could not be tested", .pHttpStatus, .pFault)
    If $Get(tOutcome("deleteFailed")) Do ..LogFault("a stored object the transformation test made could not be deleted", tOutcome("deleteStatus"))
    Set tStatus = tOutcome("status")
    Set tLines = []
    Set tConsole = []
    Set tChars = 0
    Set tCut = 0
    Do ..AddTestLines(tOutcome("text"), tLines, .tChars, .tCut)
    If $IsObject($Get(tCaptured)) {
        Set tIterator = tCaptured.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLine) {
            Do ..AddTestLines(tLine, tConsole, .tChars, .tCut)
        }
    }
    Set pResult = {}
    Do pResult.%Set("status", tStatus, "string")
    Do pResult.%Set("sourceClass", tSourceClass, "string")
    Do pResult.%Set("targetClass", tTargetClass, "string")
    Do pResult.%Set("lines", tLines)
    Do pResult.%Set("console", tConsole)
    Do pResult.%Set("errors", (tStatus '= "done"), "boolean")
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("sourceClass", tSourceClass, "string")
    Do tEffects.%Set("targetClass", tTargetClass, "string")
    Do tEffects.%Set("status", tStatus, "string")
    Do ..AuditRuntime(..#VERBTEST, ..#ENTITYCLASS, pName, tEffects)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The lines <method>Snippet</method> adds for the host test of the item the composite id <var>pId</var> names (Story 20.6),
/// from the request class and the field values <var>pQuery</var> carries: the request created and each given field set along its
/// path to the logical value its class's <code>&lt;Property&gt;DisplayToLogical</code> makes of the typed one (the typed one where the
/// class has no such method, as the send takes it), a serial object
/// created where the path passes one, the request validated and saved, and the call of <code>EnsLib.Testing.Service</code>. A
/// virtual document is <code>ImportFromString</code> of its text, an EDI XML document's as <method>PastedXmlHere</method> hands it on
/// or the status the send answers for text it refuses. The class's fields are read in the namespace
/// <parameter>NAMESPACEKEY</parameter> names, and a class they cannot be read for gives the lines without a field. Every
/// name and value is a string literal, so nothing the query carries runs as code, and every line closes any block it opens.</p>
ClassMethod TestSnippet(pId As %String, ByRef pQuery) As %String [ Private ]
{
    Set tNL = $Char(10)
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pId)
    Set tClass = $Get(pQuery(..#REQUESTCLASSKEY))
    Set tClassLiteral = ..Literal(tClass)
    If '..ParseTestFields($Get(pQuery(..#FIELDSKEY)), .tInput, .tBad) Kill tInput
    Set tMeta = 0
    Set tXmlDocument = 0
    Set tHL7 = 0
    Kill tConvert
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = $Get(pQuery(..#NAMESPACEKEY))
        Do ..ClassFieldsHere(tClass, .tMeta)
        For tI = 1:1:tMeta {
            Set tConvert(tI) = ##class(%Dictionary.CompiledMethod).%ExistsId($List(tMeta(tI), 8) _ "||" _ $List(tMeta(tI), 3) _ "DisplayToLogical")
        }
        If $Get(tMeta(1)) '= "" && ($List(tMeta(1), 1) = "document") Set tXmlDocument = ''$ClassMethod(tClass, "%Extends", ..#XMLDOCUMENT), tHL7 = ''$ClassMethod(tClass, "%Extends", ..#HL7MESSAGE)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Kill tMeta, tConvert
        Set tMeta = 0
    }
    Set tText = ""
    If $Get(tMeta(1)) '= "" && ($List(tMeta(1), 1) = "document") {
        Set tDocument = $Get(tInput(..#DOCUMENTFIELD))
        Set tReason = ""
        If tXmlDocument Set tReason = ..PastedXmlHere(tDocument, .tDocument)
        If tReason '= "" {
            Set tText = tNL _ " Set tRequest = """", tSC = $System.Status.Error(5001, " _ ..Literal(tReason) _ ")"
        } Else {
            If tHL7 {
                Set tText = tNL _ " Set tStream = ##class(%Stream.TmpCharacter).%New()"
                Set tText = tText _ tNL _ " Do tStream.Write(" _ ..Literal(tDocument) _ ")"
                Set tText = tText _ tNL _ " Do tStream.Rewind()"
                Set tText = tText _ tNL _ " Set tRequest = $ClassMethod(" _ tClassLiteral _ ", ""ImportFromLibraryStream"", tStream, .tSC)"
            } Else {
                Set tText = tNL _ " Set tRequest = $ClassMethod(" _ tClassLiteral _ ", ""ImportFromString"", " _ ..Literal(tDocument) _ ", .tSC)"
            }
            Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = tRequest.%Save()"
        }
    } Else {
        Set tText = tNL _ " Set tRequest = $ClassMethod(" _ tClassLiteral _ ", ""%New"")"
        Kill tVariable
        Set tVariables = 0
        For tI = 1:1:tMeta {
            Set tRecord = tMeta(tI)
            Set tPath = $List(tRecord, 2)
            If $Get(tInput(tPath)) = "" Continue
            Set tCurrent = "tRequest"
            Set tSegments = $Length(tPath, ".")
            For tJ = 1:1:tSegments - 1 {
                Set tPrefix = $Piece(tPath, ".", 1, tJ)
                If '$Data(tVariable(tPrefix)) {
                    Set tVariable(tPrefix) = "tPart" _ $Increment(tVariables)
                    Set tText = tText _ tNL _ " Set " _ tVariable(tPrefix) _ " = $Property(" _ tCurrent _ ", " _ ..Literal($Piece(tPath, ".", tJ)) _ ")"
                    Set tText = tText _ tNL _ " If '$IsObject(" _ tVariable(tPrefix) _ ") Set " _ tVariable(tPrefix) _ " = $ClassMethod(" _ ..Literal($List($List(tRecord, 9), tJ)) _ ", ""%New""), $Property(" _ tCurrent _ ", " _ ..Literal($Piece(tPath, ".", tJ)) _ ") = " _ tVariable(tPrefix)
                }
                Set tCurrent = tVariable(tPrefix)
            }
            Set tValue = ..Literal(tInput(tPath))
            If $Get(tConvert(tI)) Set tValue = "$ClassMethod(" _ ..Literal($List(tRecord, 8)) _ ", " _ ..Literal($List(tRecord, 3) _ "DisplayToLogical") _ ", " _ tValue _ ")"
            Set tText = tText _ tNL _ " Set $Property(" _ tCurrent _ ", " _ ..Literal($List(tRecord, 3)) _ ") = " _ tValue
        }
        Set tText = tText _ tNL _ " Set tSC = tRequest.%ValidateObject()"
        Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = tRequest.%Save()"
    }
    Quit tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = ##class(" _ ..#TESTSERVICE _ ").SendTestRequest(" _ ..Literal($ListGet(tParts, 2)) _ ", tRequest, , .tSession)"
}

/// <p>The lines <method>Snippet</method> adds for the data transformation test of <var>pName</var> (Story 20.27), from the pasted
/// message <var>pQuery</var> carries under <parameter>CONTENTKEY</parameter>: the message parsed as the transformation's source class
/// as the test parses it (<method>ParseSourceHere</method>: XML text as <method>PastedXmlHere</method> hands it on, or the status the
/// test answers for text it refuses; a virtual document's <code>ImportFromString</code>, made immutable, or the XML reader with no
/// entity resolution), the target created for <code>existing</code>, the <code>Transform</code> call with empty <code>process</code>,
/// <code>context</code> and <code>aux</code>, the render the test uses, and the deletion of a source or target that gained an
/// <code>%Id()</code>. The classes are read in the namespace <parameter>NAMESPACEKEY</parameter> names, and a transformation they cannot
/// be read for gives the call alone. Every name and the message are string literals, so nothing the query carries runs as code, and
/// every line closes any block it opens.</p>
ClassMethod TransformSnippet(pName As %String, ByRef pQuery) As %String [ Private ]
{
    Set tNL = $Char(10)
    Set tClass = ..TransformClassOf(pName)
    Kill tFacts
    Set tSourceHL7 = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = $Get(pQuery(..#NAMESPACEKEY))
        Do ..TransformFactsHere(tClass, .tFacts)
        If $Get(tFacts("compiled")) && ($Get(tFacts("sourceKind")) = "document") Set tSourceHL7 = ''$ClassMethod(tFacts("sourceClass"), "%Extends", ..#HL7MESSAGE)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Kill tFacts
        Set tSourceHL7 = 0
    }
    Set tCall = " Set tSC = $ClassMethod(" _ ..Literal(tClass) _ ", ""Transform"", tSource, .tTarget, """")"
    If '$Get(tFacts("compiled")) Quit tNL _ tCall
    Set tMessage = $Get(pQuery(..#CONTENTKEY))
    Set tReason = ""
    If (tFacts("sourceKind") = "xml") || tFacts("sourceXml") Set tReason = ..PastedXmlHere(tMessage, .tMessage)
    Set tContent = ..Literal(tMessage)
    Set tSourceClass = ..Literal(tFacts("sourceClass"))
    If tReason '= "" {
        Set tText = tNL _ " Set tSource = """", tSC = $System.Status.Error(5001, " _ ..Literal(tReason) _ ")"
    } ElseIf tFacts("sourceKind") = "document" {
        If tSourceHL7 {
            Set tText = tNL _ " Set tStream = ##class(%Stream.TmpCharacter).%New()"
            Set tText = tText _ tNL _ " Do tStream.Write(" _ tContent _ ")"
            Set tText = tText _ tNL _ " Do tStream.Rewind()"
            Set tText = tText _ tNL _ " Set tSource = $ClassMethod(" _ tSourceClass _ ", ""ImportFromLibraryStream"", tStream, .tSC)"
        } Else {
            Set tText = tNL _ " Set tSource = $ClassMethod(" _ tSourceClass _ ", ""ImportFromString"", " _ tContent _ ", .tSC)"
        }
        Set tText = tText _ tNL _ " If $IsObject(tSource) Set tSource.IsMutable = 0"
    } Else {
        Set tText = tNL _ " Set tSC = ##class(Ens.Util.XML.Reader).ObjectFromString(.tSource, " _ tContent _ ", " _ tSourceClass _ ", ##class(%XML.SAX.NullEntityResolver).%New())"
    }
    If tFacts("create") = "existing" Set tText = tText _ tNL _ " Set tTarget = $ClassMethod(" _ ..Literal(tFacts("targetClass")) _ ", ""%New"")"
    Set tText = tText _ tNL _ " Set process = """", context = """""
    Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) && $IsObject($Get(tSource)) Set tSC = $ClassMethod(" _ ..Literal(tClass) _ ", ""Transform"", tSource, .tTarget, """")"
    Set tText = tText _ tNL _ " Set tStream = ##class(%Stream.TmpCharacter).%New()"
    Set tText = tText _ tNL _ " Set tRender = $System.Status.IsOK(tSC) && $IsObject($Get(tTarget))"
    If tFacts("targetKind") = "document" {
        If tFacts("targetXml") {
            Set tText = tText _ tNL _ " If tRender Set tSC = tTarget.OutputToLibraryStream(tStream, ""wt"")"
        } ElseIf tFacts("targetSegmented") {
            Set tText = tText _ tNL _ " If tRender Set tSegment = tTarget.GetSegmentAt(1)"
            Set tText = tText _ tNL _ " If tRender Set tSeparators = $Select($IsObject(tSegment): tSegment.Separators, 1: """")"
            Set tText = tText _ tNL _ " If tRender && ($Extract(tTarget.Separators, 1, $Length(tSeparators)) '= $Extract(tSeparators, 1, $Length(tTarget.Separators))) Set tSeparators = $Extract(tTarget.Separators, 1, $Length(tSeparators)) _ $Extract(tSeparators, 1 + $Length(tTarget.Separators), *)"
            Set tText = tText _ tNL _ " If tRender && (tTarget.%Extends(""EnsLib.EDI.X12.Document"") || tTarget.%Extends(""EnsLib.EDI.EDIFACT.Document"")) Set tSeparators = tSeparators _ tTarget.SegmentTerminator"
            Set tText = tText _ tNL _ " If tRender && ($Char(10) '= $Extract(tSeparators, *)) Set tSeparators = tSeparators _ $Char(10)"
            Set tText = tText _ tNL _ " If tRender && ($Char(13) '= $Extract(tSeparators, *-1)) Set tSeparators = $Extract(tSeparators, 1, *-1) _ $Char(13, 10)"
            Set tText = tText _ tNL _ " If tRender Set tSC = tTarget.OutputToLibraryStream(tStream, tSeparators)"
        } Else {
            Set tText = tText _ tNL _ " If tRender Set tSC = tTarget.OutputToLibraryStream(tStream)"
        }
    } Else {
        Set tText = tText _ tNL _ " If tRender Set tWriter = ##class(%XML.Writer).%New()"
        Set tText = tText _ tNL _ " If tRender Set tWriter.Indent = 1"
        Set tText = tText _ tNL _ " If tRender Set tSC = tWriter.OutputToStream(tStream)"
        Set tText = tText _ tNL _ " If tRender && $System.Status.IsOK(tSC) Set tSC = tWriter.RootObject(tTarget)"
    }
    Set tText = tText _ tNL _ " Set tStored = """" For tObject = $Get(tSource), $Get(tTarget) { If $IsObject(tObject) && tObject.%Extends(""%Library.Persistent"") && (tObject.%Id() '= """") { Set tStored = tStored _ $ListBuild($ListBuild(tObject.%ClassName(1), tObject.%Oid())) } }"
    Set tText = tText _ tNL _ " Kill tObject, tSource, tTarget"
    Set tText = tText _ tNL _ " For tI = 1:1:$ListLength(tStored) { Do $ClassMethod($List($List(tStored, tI), 1), ""%Delete"", $List($List(tStored, tI), 2)) }"
    Quit tText
}

/// <p>The Suspended messages endpoint (Story 24.16): <code>LIST</code> (the namespace's headers whose status is Suspended), the four composed reads
/// <code>RESUBMIT</code>, <code>EDITSUBMIT</code>, <code>DISCARD</code> and <code>DELETE</code>, and the four writes <code>RESUBMITMESSAGES</code>,
/// <code>EDITRESUBMIT</code>, <code>DISCARDMESSAGES</code> and <code>DELETEMESSAGES</code>. It extends the resend family of the Messages endpoint
/// (<method>ReadResend</method>, <method>PerformResend</method>, <method>ReadEdit</method>), which each carry the action as a kind
/// (<method>SuspendedKind</method>).</p>
Parameter ENDPOINTSUSPENDEDMESSAGES = "SuspendedMessages";

/// <p>The pair a discard and a delete add to the Messages pairs: the resource of the classic Suspended Messages page's discard and delete.</p>
Parameter DISCARDPAIR = "%Ens_MessageDiscard:USE";

Parameter TYPERESUBMIT = "RESUBMIT";

Parameter TYPEEDITSUBMIT = "EDITSUBMIT";

Parameter TYPEDISCARD = "DISCARD";

Parameter TYPEDELETE = "DELETE";

Parameter TYPERESUBMITMESSAGES = "RESUBMITMESSAGES";

Parameter TYPEEDITRESUBMIT = "EDITRESUBMIT";

Parameter TYPEDISCARDMESSAGES = "DISCARDMESSAGES";

Parameter TYPEDELETEMESSAGES = "DELETEMESSAGES";

/// <p>The most rows a list of suspended messages answers when the call gives no cap, as the classic page's own query; and the status values the
/// list reads and a discard writes.</p>
Parameter SUSPENDEDMAX As INTEGER = 2000;

Parameter STATUSSUSPENDEDVALUE As INTEGER = 5;

Parameter STATUSDISCARDEDVALUE As INTEGER = 4;

/// <p>The audit verb of a discard; a delete takes <parameter>VERBDELETE</parameter>.</p>
Parameter VERBDISCARD = "discard";

/// <p>The statement of the suspended list: <method>MessageRow</method>'s search columns, newest first, the cap and the status bound.</p>
Parameter SUSPENDEDSQL = "SELECT TOP ? ID, TimeCreated, %EXTERNAL(Status), SourceConfigName, TargetConfigName, MessageBodyClassName, SessionId, %EXTERNAL(Type), IsError FROM Ens.MessageHeader WHERE Status = ? ORDER BY ID DESC";

/// <p>The statements the delete of a suspended message reads and writes with, each bound: the header's body, the headers that name a body, and
/// the header's removal.</p>
Parameter DELETEBODYSQL = "SELECT MessageBodyId, MessageBodyClassName FROM Ens.MessageHeader WHERE ID = ?";

Parameter DELETESHAREDSQL = "SELECT COUNT(*) FROM Ens.MessageHeader WHERE MessageBodyId = ? AND MessageBodyClassName = ?";

Parameter DELETEHEADERSQL = "DELETE FROM Ens.MessageHeader WHERE ID = ?";

/// <p>The verdict words of a suspended action, as <code>id=verdict</code> pairs a stored payload carries.</p>
Parameter SUSPENDEDVERDICTS = "gone,notsuspended,nobody,targetoff,noreplyqueue,resubmit,discard,delete";

/// <p>The action a Suspended messages type belongs to, <code>resubmit</code>, <code>edit</code>, <code>discard</code> or <code>delete</code>, for the read and the
/// write of each; <code>""</code> for any other type. Pure.</p>
ClassMethod SuspendedKind(pType As %String) As %String
{
    If (pType = ..#TYPERESUBMIT) || (pType = ..#TYPERESUBMITMESSAGES) Quit "resubmit"
    If (pType = ..#TYPEEDITSUBMIT) || (pType = ..#TYPEEDITRESUBMIT) Quit "edit"
    If (pType = ..#TYPEDISCARD) || (pType = ..#TYPEDISCARDMESSAGES) Quit "discard"
    If (pType = ..#TYPEDELETE) || (pType = ..#TYPEDELETEMESSAGES) Quit "delete"
    Quit ""
}

/// <p>The write of the action <var>pKind</var> (<method>SuspendedKind</method>), <code>""</code> for any other word. Pure.</p>
ClassMethod SuspendedWriteType(pKind As %String) As %String
{
    Quit $Case(pKind, "resubmit": ..#TYPERESUBMITMESSAGES, "edit": ..#TYPEEDITRESUBMIT, "discard": ..#TYPEDISCARDMESSAGES, "delete": ..#TYPEDELETEMESSAGES, : "")
}

/// <p>Whether <var>pType</var> is one of the four writes of the Suspended messages endpoint (Story 24.16): an action-style write over a
/// port-composed read of the messages, needing WRITE on the namespace's globals database and no routines database.</p>
ClassMethod IsSuspendedWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPERESUBMITMESSAGES) || (pType = ..#TYPEEDITRESUBMIT) || (pType = ..#TYPEDISCARDMESSAGES) || (pType = ..#TYPEDELETEMESSAGES)
}

/// <p>The headers of <var>pNamespace</var> whose status is Suspended (Story 24.16), newest first, at most <var>pMax</var>
/// (<parameter>SUSPENDEDMAX</parameter> when that is not above zero), as <code>{ID, TimeCreated, SessionId, Error, Type, Source, Target,
/// BodyClass}</code>. The status and the cap are bound and no body is read.</p>
ClassMethod ListSuspended(pNamespace As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tTop = $Select(pMax > 0: pMax, 1: ..#SUSPENDEDMAX)
    Set tSC = ..SqlRows(pNamespace, ..#SUSPENDEDSQL, .tFound, .tCaught, tTop, ..#STATUSSUSPENDEDVALUE)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the suspended messages could not be listed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Set tRow = ..MessageRow(tFound(tI), "", "", 1)
        Do tRow.%Remove("Status")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Serve the Suspended messages endpoint after <method>Invoke</method>'s gate (Story 24.16): <code>LIST</code> (<method>ListSuspended</method>) and the
/// four actions' reads and writes. The messages travel under <parameter>IDKEY</parameter> as the set <method>MessageSet</method> reads, or for an edit the
/// one message; the fields of an edit under <parameter>FIELDSKEY</parameter>; the digest a person reviewed under <parameter>DIGESTKEY</parameter>. A read
/// composed for an action carries it under <parameter>ACTIONKEY</parameter>, which must be the write of its own action, else 501.</p>
ClassMethod InvokeSuspended(pNamespace As %String, pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType = ..#TYPELIST {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..ListSuspended(pNamespace, +tMaxText, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tKind = ..SuspendedKind(pType)
        Set tWrite = ..IsSuspendedWrite(pType)
        Set tAction = $Select(tWrite: pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && (tAction '= ..SuspendedWriteType(tKind)) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tId = $Get(pQuery(..#IDKEY))
        Set tReviewed = $Get(pQuery(..#DIGESTKEY))
        If tKind = "edit" {
            If '$Match(tId, ..#MESSAGEIDPATTERN) {
                Set tSC = ..RefuseCriterion("message", .pHttpStatus, .pFault)
                Quit
            }
            If tWrite {
                Set tSC = ..PerformEditResend(pNamespace, tId, $Get(pQuery(..#FIELDSKEY)), tReviewed, .pResult, .pHttpStatus, .pFault, 1)
            } Else {
                Set tSC = ..ReadEdit(pNamespace, tId, tAction, $Get(pQuery(..#FIELDSKEY)), tReviewed, .pResult, .tPlan, .pHttpStatus, .pFault, 1)
            }
            Quit
        }
        If tWrite {
            Set tSC = ..PerformResend(pNamespace, tId, tReviewed, .pResult, .pHttpStatus, .pFault, tKind)
        } Else {
            Set tSC = ..ReadResend(pNamespace, tId, tAction, tReviewed, .pResult, .pHttpStatus, .pFault, tKind)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the suspended messages call failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether the body class <var>pClass</var> is one the classic Suspended Messages delete removes a body of: a compiled class that is persistent or a
/// stream, whose <code>ENSPURGE</code> parameter is not 0. Called while the message's namespace is switched.</p>
ClassMethod BodyPurgeableHere(pClass As %String) As %Boolean [ Private ]
{
    If '$Match(pClass, ..#CLASSNAMEPATTERN) || '##class(%Dictionary.CompiledClass).%ExistsId(pClass) Quit 0
    If '($ClassMethod(pClass, "%IsA", "%Library.Persistent") || $ClassMethod(pClass, "%IsA", "%Stream.Object")) Quit 0
    Quit ($Parameter(pClass, "ENSPURGE") '= 0)
}

/// <p>The vendor's status codes a delete of a body that is already gone answers, which the classic page treats as done: an object not found, a file that cannot be
/// deleted and a value that is not an instance (<code>DeleteObjectNotFound</code>, <code>FileCanNotDelete</code>, <code>NotAnInstanceError</code>).</p>
Parameter DELETETOLERATEDCODES = "5810,5019,5825";

/// <p>Whether <var>pStatus</var> is one of <parameter>DELETETOLERATEDCODES</parameter>. Pure.</p>
ClassMethod DeleteTolerated(pStatus As %Status) As %Boolean [ Private ]
{
    Set tTolerated = 0
    For tI = 1:1:$Length(..#DELETETOLERATEDCODES, ",") {
        If $System.Status.Equals(pStatus, +$Piece(..#DELETETOLERATEDCODES, ",", tI)) {
            Set tTolerated = 1
            Quit
        }
    }
    Quit tTolerated
}

/// <p>Delete the message header <var>pId</var> as the classic Suspended Messages page's delete does (Story 24.16), in the namespace the caller has already
/// switched to: its body, with its search table entries, when no other header names it and the class is one <method>BodyPurgeableHere</method> admits, then
/// the header by a bound delete. The classic page's journaling suspension and bitmap clean-up are not part of it. A body that cannot be deleted leaves the
/// header in place; a header that is gone or a delete SQL refuses is an error status. A search table removal that fails does not stop the delete: its status
/// is <var>pSearchSC</var>, for the caller to log once the namespace is restored. Every value is bound.</p>
ClassMethod DeleteHeaderHere(pId As %String, Output pSearchSC As %Status) As %Status [ Private ]
{
    Set pSearchSC = $$$OK
    Set tStatement = ##class(%SQL.Statement).%New()
    Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(.tStatement, ..#DELETEBODYSQL, pId)
    If tResult.%SQLCODE < 0 Quit $$$ERROR($$$SQLCode, tResult.%SQLCODE, tResult.%Message)
    If 'tResult.%Next() Quit $$$ERROR($$$DeleteObjectNotFound, "Ens.MessageHeader", pId)
    Set tBodyId = tResult.%GetData(1)
    Set tClass = tResult.%GetData(2)
    Set tResult = ""
    If tBodyId '= "" {
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(.tStatement, ..#DELETESHAREDSQL, tBodyId, tClass)
        If tResult.%SQLCODE < 0 Quit $$$ERROR($$$SQLCode, tResult.%SQLCODE, tResult.%Message)
        Set tHolders = $Select(tResult.%Next(): +tResult.%GetData(1), 1: 0)
        Set tResult = ""
        If tHolders = 1 {
            If (tClass = "") && (tBodyId = +tBodyId) Set tClass = "Ens.MessageBody"
            If (tClass '= "") && ..BodyPurgeableHere(tClass) {
                Try {
                    Set tBodySC = $ClassMethod(tClass, "%DeleteId", tBodyId)
                } Catch ex {
                    Set tBodySC = ex.AsStatus()
                }
                If $$$ISOK(tBodySC) || ..DeleteTolerated(tBodySC) {
                    Set tSearchSC = ..VendorRemoveSearchEntries(tClass, tBodyId)
                    If $$$ISERR(tSearchSC) && '..DeleteTolerated(tSearchSC) Set pSearchSC = tSearchSC
                } Else {
                    Quit tBodySC
                }
            }
        }
    }
    Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(.tStatement, ..#DELETEHEADERSQL, pId)
    If tResult.%SQLCODE < 0 Quit $$$ERROR($$$SQLCode, tResult.%SQLCODE, tResult.%Message)
    Quit $$$OK
}

/// <p><code>Ens.SearchTableBase.RemoveSearchTableEntries</code> of the deleted body <var>pId</var> of class <var>pClass</var>, as the classic page's delete calls it
/// (Story 24.16). Called while the message's namespace is switched. Overridable so a test can fail it; production never overrides it.</p>
ClassMethod VendorRemoveSearchEntries(pClass As %String, pId As %String) As %Status [ Private ]
{
    Quit ##class(Ens.SearchTableBase).RemoveSearchTableEntries(pClass, pId, 1)
}

/// <p>The vendor's act on the suspended header <var>pId</var> in <var>pNamespace</var>, switched by explicit save and restore (Story 24.16): <code>resubmit</code>
/// is <code>Ens.MessageHeader.ResubmitMessage</code>, which keeps the id; <code>discard</code> opens the header, <code>SetStatus</code> to Discarded and saves it, as the
/// classic page does; <code>delete</code> is <method>DeleteHeaderHere</method>. A thrown fault is <var>pCaught</var>. Only vendor classes and this class run while it
/// is switched; a search table removal the delete could not make is logged, as its error codes alone, once the namespace is restored. Overridable so a test can
/// fail one message; production never overrides it.</p>
ClassMethod VendorSuspended(pNamespace As %String, pKind As %String, pId As %String, Output pCaught) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pCaught = ""
    Set tSearchSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If pKind = "resubmit" {
            Set tSC = ##class(Ens.MessageHeader).ResubmitMessage(pId)
        } ElseIf pKind = "discard" {
            Set tHeader = ##class(Ens.MessageHeader).%OpenId(pId, , .tSC)
            If $IsObject(tHeader) {
                Do tHeader.SetStatus(..#STATUSDISCARDEDVALUE)
                Set tSC = tHeader.%Save()
            } ElseIf $$$ISOK(tSC) {
                Set tSC = $$$ERROR($$$LoadObjectNotFound, "Ens.MessageHeader", pId)
            }
            Set tHeader = ""
        } Else {
            Set tSC = ..DeleteHeaderHere(pId, .tSearchSC)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pCaught = ex
    }
    If $$$ISERR(tSearchSC) Do ..LogFault("the search table entries of a deleted message body could not be removed", ..VendorCodesStatus(tSearchSC, "the search table removal"))
    Quit tSC
}

/// <p>The lines <method>Snippet</method> adds for the Suspended messages write <var>pType</var> (Story 24.16), from the stored payload of <var>pContext</var> and
/// the query <var>pQuery</var>: for a resubmit, a discard or a delete, one block for each id of the set <var>pId</var> names (<method>MessageSet</method>) that the payload's
/// <code>Verdicts</code> does not read as another verdict, each failure kept in <code>tSC</code>; for an edit-and-resubmit, <method>MessageSnippet</method>'s lines ending in
/// <code>ResubmitMessage</code>. Each block acts only on a header whose status still reads Suspended when the script runs, and a delete's block does what
/// <method>DeleteHeaderHere</method> does: a body it cannot delete keeps the header, and a refused header delete is kept in <code>tSC</code>. An id that is not of the
/// shape <parameter>MESSAGEIDPATTERN</parameter> makes <code>""</code> (no draft is rendered). Every id, name and value is a string literal, so nothing the payload carries
/// runs as code.</p>
ClassMethod SuspendedSnippet(pType As %String, pId As %String, ByRef pQuery, pContext As %DynamicObject) As %String [ Private ]
{
    Set tKind = ..SuspendedKind(pType)
    If tKind = "edit" {
        If '$Match(pId, ..#MESSAGEIDPATTERN) Quit ""
        Quit ..MessageSnippet(..#TYPEEDITRESEND, pId, .pQuery, pContext, 1)
    }
    If '..MessageSet(pId, .tAll) Quit ""
    Set tPayload = ""
    If $IsObject(pContext) && (pContext.%GetTypeOf("payload") = "object") Set tPayload = pContext.%Get("payload")
    Kill tReviewed
    If $IsObject(tPayload) && (tPayload.%GetTypeOf("Verdicts") = "string") {
        Set tVerdicts = tPayload.%Get("Verdicts")
        For tI = 1:1:$Length(tVerdicts, ",") {
            Set tPair = $Piece(tVerdicts, ",", tI)
            If $Match($Piece(tPair, "=", 1), ..#MESSAGEIDPATTERN) && $ListFind($ListFromString(..#SUSPENDEDVERDICTS), $Piece(tPair, "=", 2)) Set tReviewed($Piece(tPair, "=", 1)) = $Piece(tPair, "=", 2)
        }
    }
    ; An id the review read as another verdict is left out; one it did not read is in the set the target names, and every block checks the status itself.
    Set tIds = ""
    For tI = 1:1:$ListLength(tAll) {
        If $Data(tReviewed($List(tAll, tI))) && (tReviewed($List(tAll, tI)) '= tKind) Continue
        Set tIds = tIds _ $ListBuild($List(tAll, tI))
    }
    Set tNL = $Char(10)
    Set tSuspended = "$IsObject(tHeader) && (tHeader.Status = " _ ..#STATUSSUSPENDEDVALUE _ ")"
    Set tText = tNL _ " Set tSC = 1"
    For tI = 1:1:$ListLength(tIds) {
        Set tId = ..Literal($List(tIds, tI))
        Set tText = tText _ tNL _ " Set tHeader = ##class(Ens.MessageHeader).%OpenId(" _ tId _ ")"
        If tKind = "resubmit" {
            Set tText = tText _ tNL _ " Set tGo = " _ tSuspended _ ", tHeader = """""
            Set tText = tText _ tNL _ " If tGo Set tSC = $System.Status.AppendStatus(tSC, ##class(Ens.MessageHeader).ResubmitMessage(" _ tId _ "))"
        } ElseIf tKind = "discard" {
            Set tText = tText _ tNL _ " If " _ tSuspended _ " { Do tHeader.SetStatus(" _ ..#STATUSDISCARDEDVALUE _ ") Set tSC = $System.Status.AppendStatus(tSC, tHeader.%Save()) }"
            Set tText = tText _ tNL _ " Set tHeader = """""
        } Else {
            Set tText = tText _ tNL _ " If " _ tSuspended _ " { Set tGo = 1, tBodyClass = tHeader.MessageBodyClassName, tBodyId = tHeader.MessageBodyId } Else { Set tGo = 0, tBodyClass = """", tBodyId = """" }"
            Set tText = tText _ tNL _ " Set tHeader = """""
            Set tText = tText _ tNL _ " Set tHolders = 0 If tBodyId '= """" { Set tResult = ##class(%SQL.Statement).%ExecDirect(, ""SELECT COUNT(*) FROM Ens.MessageHeader WHERE MessageBodyId = ? AND MessageBodyClassName = ?"", tBodyId, tBodyClass) If tResult.%Next() Set tHolders = tResult.%GetData(1) }"
            Set tText = tText _ tNL _ " If (tHolders = 1) && (tBodyClass = """") && (tBodyId = +tBodyId) Set tBodyClass = ""Ens.MessageBody"""
            Set tText = tText _ tNL _ " Set tBodySC = 1 If (tHolders = 1) && (tBodyClass '= """") && ##class(%Dictionary.CompiledClass).%ExistsId(tBodyClass) && ($ClassMethod(tBodyClass, ""%IsA"", ""%Library.Persistent"") || $ClassMethod(tBodyClass, ""%IsA"", ""%Stream.Object"")) && ($Parameter(tBodyClass, ""ENSPURGE"") '= 0) { Set tBodySC = $ClassMethod(tBodyClass, ""%DeleteId"", tBodyId) If $System.Status.IsOK(tBodySC) || $System.Status.Equals(tBodySC, " _ ..#DELETETOLERATEDCODES _ ") { Set tBodySC = 1 Do ##class(Ens.SearchTableBase).RemoveSearchTableEntries(tBodyClass, tBodyId, 1) } }"
            Set tText = tText _ tNL _ " Set tSC = $System.Status.AppendStatus(tSC, tBodySC)"
            Set tText = tText _ tNL _ " If tGo && $System.Status.IsOK(tBodySC) { Set tResult = ##class(%SQL.Statement).%ExecDirect(, ""DELETE FROM Ens.MessageHeader WHERE ID = ?"", " _ tId _ ") If tResult.%SQLCODE < 0 Set tSC = $System.Status.AppendStatus(tSC, $System.Error.FromSQLCode(tResult.%SQLCODE, tResult.%Message).Status) }"
        }
    }
    Quit tText
}

/// <p><var>pValue</var> as an ObjectScript string literal, a control character spelled as a
/// <code>$Char</code>.</p>
ClassMethod Literal(pValue As %String) As %String [ Private ]
{
    Set tText = """" _ $Replace(pValue, """", """""") _ """"
    For tCode = 0:1:31 {
        If tText [ $Char(tCode) Set tText = $Replace(tText, $Char(tCode), """_$Char(" _ tCode _ ")_""")
    }
    Quit tText
}

/// <p>The Business rule log endpoint (Story 24.17 Batch 2): <code>LIST</code> (the namespace's <code>Ens_Rule.Log</code> rows, newest first), <code>RULELOGSTATE</code> (the entries counted, which
/// a purge's review and fingerprint read) and the write <code>PURGERULELOG</code>, the vendor's <code>Ens.Purge.PurgeRuleLogsByDate</code> with the days to keep in <parameter>PURGEDAYSKEY</parameter>.</p>
Parameter ENDPOINTRULELOG = "RuleLog";

/// <p>The Business process log endpoint (Story 24.17 Batch 2): <code>LIST</code> (the namespace's <code>Ens.BusinessProcess</code> rows, newest first), <code>PROCESSLOGSTATE</code> and the write
/// <code>PURGEPROCESSLOG</code>, the vendor's <code>Ens.Purge.PurgeBusinessProcessesByDate</code> with integrity kept.</p>
Parameter ENDPOINTPROCESSLOG = "ProcessLog";

/// <p>The pairs each log endpoint requires: the portal's and the classic page's own resource (<code>EnsPortal.RuleLog</code>'s <code>%Ens_RuleLog:USE</code>,
/// <code>EnsPortal.BPInstances</code>'s <code>%Ens_Jobs:READ</code>). A purge adds <parameter>LOGPURGEPAIR</parameter>, both pages' edit resource, and the gate's WRITE on the namespace's
/// globals database. Every read also needs the SQL SELECT privilege on the log's table (<method>LogSelectGate</method>).</p>
Parameter RULELOGPAIRS = "%Ens_Portal:USE,%Ens_RuleLog:USE";

Parameter PROCESSLOGPAIRS = "%Ens_Portal:USE,%Ens_Jobs:READ";

Parameter LOGPURGEPAIR = "%Ens_Purge:USE";

Parameter TYPERULELOGSTATE = "RULELOGSTATE";

Parameter TYPEPURGERULELOG = "PURGERULELOG";

Parameter TYPEPROCESSLOGSTATE = "PROCESSLOGSTATE";

Parameter TYPEPURGEPROCESSLOG = "PURGEPROCESSLOG";

/// <p>The most rows each log list answers to a call that names no cap of its own: the classic pages' largest page size, within the 5 seconds the read may take (measured, Task 0).</p>
Parameter RULELOGMAX As INTEGER = 2000;

Parameter PROCESSLOGMAX As INTEGER = 2000;

/// <p>The two kinds of log, which <method>PurgeFrame</method> takes to run one log's purge.</p>
Parameter LOGKINDRULE = "rulelog";

Parameter LOGKINDPROCESS = "processlog";

Parameter ENTITYRULELOG = "interop-rule-log";

Parameter ENTITYPROCESSLOG = "interop-process-log";

/// <p>The columns of a list row, in the order <method>RuleLogRow</method> and <method>ProcessLogRow</method> read them, and the tables they come from.</p>
Parameter RULELOGCOLUMNS = "ID, TimeExecuted, SessionId, RuleName, ConfigName, IsError, ReturnValue, Reason";

Parameter PROCESSLOGCOLUMNS = "ID, %TimeCreated, %TimeCompleted, %IsCompleted, %ConfigName, %SessionId";

Parameter RULELOGTABLE = "Ens_Rule.Log";

Parameter PROCESSLOGTABLE = "Ens.BusinessProcess";

/// <p>The criteria of the two lists: <code>errors</code> and <code>completed</code>, each <code>yes</code> or <code>no</code>; absent lists all.</p>
Parameter LOGERRORSCRITERION = "errors";

Parameter LOGCOMPLETEDCRITERION = "completed";

/// <p>Whether <var>pType</var> is one of the two log purges, which need WRITE on the namespace's globals database.</p>
ClassMethod IsLogPurgeWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEPURGERULELOG) || (pType = ..#TYPEPURGEPROCESSLOG)
}

/// <p>The kind of log <var>pEndpoint</var> serves, <parameter>LOGKINDRULE</parameter> or <parameter>LOGKINDPROCESS</parameter>, or <code>""</code>. Pure.</p>
ClassMethod LogKind(pEndpoint As %String) As %String
{
    Quit $Select(pEndpoint = ..#ENDPOINTRULELOG: ..#LOGKINDRULE, pEndpoint = ..#ENDPOINTPROCESSLOG: ..#LOGKINDPROCESS, 1: "")
}

/// <p>The SQL table the log of kind <var>pKind</var> lives in. Pure.</p>
ClassMethod LogTable(pKind As %String) As %String [ Private ]
{
    Quit $Select(pKind = ..#LOGKINDRULE: ..#RULELOGTABLE, 1: ..#PROCESSLOGTABLE)
}

/// <p>The days a log purge hands the vendor for <var>pDays</var>: days past the instance's calendar are the calendar's own count, since the vendor reads a cut-off before the
/// instance's first day as an error and the days past it keep every record. Reads the clock.</p>
ClassMethod LogKeepDays(pDays As %String) As %Integer
{
    Quit $Select(+pDays > (+$Horolog - 2): +$Horolog - 2, 1: +pDays)
}

/// <p>A point inside each namespace-switched block of the privilege check and the state read, which does nothing. A fixture overrides it to raise a fault there, so a test reads that the fault is
/// logged after the namespace is restored; production never overrides it.</p>
ClassMethod LogHere() [ Private ]
{
}

/// <p>A vendor exception <var>pException</var> of a log call in this port's own words, as <method>AlertMapped</method> answers one: the status it logs carries the vendor's error codes alone.</p>
ClassMethod LogMapped(pException As %Exception.AbstractException, pMessage As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Statused(..VendorCodesStatus(pException.AsStatus(), "the log call"), pMessage, .pHttpStatus, .pFault)
}

/// <p>The vendor's purge of the log of kind <var>pKind</var> in the current namespace, which the caller has already switched, with <var>pDays</var> as <code>Ens.Purge</code> takes them:
/// the business rule log's <code>PurgeRuleLogsByDate</code> or the business process purge <code>PurgeBusinessProcessesByDate</code> with integrity kept. <var>pDeleted</var> is the vendor's
/// count. Overridable so a fixture can answer a fault; production never overrides it. Reached only through <method>PurgeFrame</method>.</p>
ClassMethod VendorLogPurge(pKind As %String, pDays As %Integer, Output pDeleted) As %Status
{
    If pKind = ..#LOGKINDRULE Quit ##class(Ens.Purge).PurgeRuleLogsByDate(pDays, .pDeleted)
    Quit ##class(Ens.Purge).PurgeBusinessProcessesByDate(pDays, .pDeleted, 1)
}

/// <p>The check that stands in for the classic pages' own query, which the vendor runs with the caller's SQL privileges: whether the caller's effective SQL SELECT privilege on the
/// log of kind <var>pKind</var> is held in <var>pNamespace</var>, asked of the vendor (<code>$SYSTEM.SQL.Security.CheckPrivilege</code>) with the namespace switched, so roles, <code>%All</code> and
/// grants through a role resolve as the vendor resolves them. 403 <code>AUTH.NOPRIVILEGE</code> naming the table and <code>SELECT</code> when it is not; the port's other reads run without it
/// (<code>%ExecDirectNoPriv</code>), so this is what keeps a list from showing a caller what the classic page would refuse.</p>
ClassMethod LogSelectGate(pNamespace As %String, pKind As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tTable = ..LogTable(pKind)
    Set tHeld = 0
    Set tCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..LogHere()
        Set tAnswer = ##class(%SYSTEM.SQL.Security).CheckPrivilege($USERNAME, 1, tTable, "s", pNamespace)
        Set $NAMESPACE = tOrigNS
        Set tHeld = (tAnswer = 1)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..LogMapped(tCaught, "the log table privilege check failed", .pHttpStatus, .pFault)
    If 'tHeld Quit ..Deny(tTable _ ":SELECT", .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>One list row of the columns <parameter>RULELOGCOLUMNS</parameter> read as <var>pLine</var>: <code>{ID, TimeExecuted, SessionId, RuleName, ConfigName, IsError, ReturnValue, Reason,
/// Namespace}</code>, the time as the instance's local time as the other lists show it.</p>
ClassMethod RuleLogRow(pLine As %List, pNamespace As %String) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("ID", $List(pLine, 1) _ "", "string")
    Do tRow.%Set("TimeExecuted", ..AlertLocal($List(pLine, 2)), "string")
    Do tRow.%Set("SessionId", ..AlertText($List(pLine, 3)), "string")
    Do tRow.%Set("RuleName", ..AlertText($List(pLine, 4)), "string")
    Do tRow.%Set("ConfigName", ..AlertText($List(pLine, 5)), "string")
    Do tRow.%Set("IsError", ''$List(pLine, 6), "boolean")
    Do tRow.%Set("ReturnValue", ..AlertText($List(pLine, 7)), "string")
    Do tRow.%Set("Reason", ..AlertText($List(pLine, 8)), "string")
    Do tRow.%Set("Namespace", pNamespace, "string")
    Quit tRow
}

/// <p>One list row of the columns <parameter>PROCESSLOGCOLUMNS</parameter> read as <var>pLine</var>: <code>{ID, TimeCreated, TimeCompleted, IsCompleted, ConfigName, SessionId, Namespace}</code>.</p>
ClassMethod ProcessLogRow(pLine As %List, pNamespace As %String) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("ID", $List(pLine, 1) _ "", "string")
    Do tRow.%Set("TimeCreated", ..AlertLocal($List(pLine, 2)), "string")
    Do tRow.%Set("TimeCompleted", ..AlertLocal($List(pLine, 3)), "string")
    Do tRow.%Set("IsCompleted", ''$List(pLine, 4), "boolean")
    Do tRow.%Set("ConfigName", ..AlertText($List(pLine, 5)), "string")
    Do tRow.%Set("SessionId", ..AlertText($List(pLine, 6)), "string")
    Do tRow.%Set("Namespace", pNamespace, "string")
    Quit tRow
}

/// <p>The log of kind <var>pKind</var> of <var>pNamespace</var>, newest first, at most <var>pMax</var> rows (the log's own maximum when that is not above zero). The criterion <code>errors</code>
/// (the rule log) or <code>completed</code> (business processes) is <code>yes</code> or <code>no</code>; absent lists all. The caller's SQL SELECT privilege is judged first
/// (<method>LogSelectGate</method>). Every value is bound. A longer list than the cap is the caller's truncation, which it reads from the one row it asked for beyond its own cap.</p>
ClassMethod ListLog(pNamespace As %String, pKind As %String, ByRef pQuery, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tSC = ..LogSelectGate(pNamespace, pKind, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tRule = (pKind = ..#LOGKINDRULE)
    Set tCriterion = $Select(tRule: ..#LOGERRORSCRITERION, 1: ..#LOGCOMPLETEDCRITERION)
    Set tValue = $Get(pQuery(tCriterion))
    If (tValue '= "") && (tValue '= "yes") && (tValue '= "no") Quit ..RefuseCriterion(tCriterion, .pHttpStatus, .pFault)
    Kill tArgs
    Set tArgs = 1
    Set tArgs(1) = ..AlertCap(pMax, $Select(tRule: ..#RULELOGMAX, 1: ..#PROCESSLOGMAX))
    Set tSql = "SELECT TOP ? " _ $Select(tRule: ..#RULELOGCOLUMNS, 1: ..#PROCESSLOGCOLUMNS) _ " FROM " _ ..LogTable(pKind)
    If tValue '= "" {
        Set tSql = tSql _ " WHERE " _ $Select(tRule: "IsError", 1: "%IsCompleted") _ " = ?"
        Set tArgs(2) = (tValue = "yes")
        Set tArgs = 2
    }
    Set tSql = tSql _ " ORDER BY ID DESC"
    Set tSC = ..SqlRows(pNamespace, tSql, .tFound, .tCaught, tArgs...)
    If $IsObject(tCaught) Quit ..LogMapped(tCaught, $Select(tRule: "the business rule log list failed", 1: "the business process log list failed"), .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Do pRows.%Push($Select(tRule: ..RuleLogRow(tFound(tI), pNamespace), 1: ..ProcessLogRow(tFound(tI), pNamespace)))
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The state row of the log of kind <var>pKind</var> (Story 24.17 Batch 2): <code>{Count, DaysToKeep, Namespace}</code>, <code>Count</code> the vendor's own count of the log's records
/// (<code>Ens.Purge.RuleLogCount</code> or <code>BusinessProcessCount</code>) and <code>DaysToKeep</code> empty, since the days belong to the call that asks for the purge. The caller's SQL SELECT
/// privilege is judged first, as the list's is (<method>LogSelectGate</method>); the vendor's count is embedded SQL, which checks no SQL privilege of its own.</p>
ClassMethod ReadLogState(pNamespace As %String, pKind As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set tSC = ..LogSelectGate(pNamespace, pKind, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tCount = 0
    Set tCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ..LogHere()
        Set tCount = $Select(pKind = ..#LOGKINDRULE: ##class(Ens.Purge).RuleLogCount(), 1: ##class(Ens.Purge).BusinessProcessCount())
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    If $IsObject(tCaught) Quit ..LogMapped(tCaught, "the log state read failed", .pHttpStatus, .pFault)
    Set pRow = {}
    Do pRow.%Set("Count", +tCount, "number")
    Do pRow.%Set("DaysToKeep", "", "string")
    Do pRow.%Set("Namespace", pNamespace, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Purge the log of kind <var>pKind</var> of <var>pNamespace</var> as the classic page's <code>DoPurge</code> does, in this request (Story 24.17 Batch 2), and answer its state row, read again. The days are
/// judged first (<method>PurgeDaysOK</method>), 422 <code>INTEROP.PURGE.DAYS</code>, before any vendor call. The vendor's purge runs in the namespace inside <method>PurgeFrame</method>, with no lock and no
/// transaction, and the namespace is restored; OcuPilot's own audit row is recorded whatever the vendor answered, because the vendor records none: it names the namespace, the days, the count the vendor
/// deleted and whether it completed. A vendor error status or a fault is 500 <code>INTERNAL</code>, never 200, even after a partial delete.</p>
/// <p>A purge that outlasts the Web Gateway's response timeout runs to its end in this process, and its audit row is written then.</p>
ClassMethod PerformLogPurge(pNamespace As %String, pKind As %String, pDays As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If '..PurgeDaysOK(pDays) {
        Set tViolations = 1
        Set tViolations(1) = $ListBuild("DaysToKeep", ##class(OcuPilot.Api.InteropError).#PURGEDAYS)
        Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    }
    Set tRule = (pKind = ..#LOGKINDRULE)
    Set tCaught = ""
    Set tVendorSC = $$$OK
    Kill tDeleted
    Set tKeepDays = ..LogKeepDays(pDays)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tVendorSC = ..PurgeFrame(tKeepDays, 1, 0, 0, .tDeleted, pKind)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCaught = ex
    }
    Set tEffects = {}
    Do tEffects.%Set("namespace", pNamespace, "string")
    Do tEffects.%Set("daysToKeep", +pDays, "number")
    Do tEffects.%Set("deleted", +$Get(tDeleted), "number")
    Do tEffects.%Set("completed", ($$$ISOK(tVendorSC) && '$IsObject(tCaught)), "boolean")
    Do ..AuditRuntime(..#VERBPURGE, $Select(tRule: ..#ENTITYRULELOG, 1: ..#ENTITYPROCESSLOG), pNamespace, tEffects)
    Set tMessage = $Select(tRule: "the business rule log purge failed", 1: "the business process purge failed")
    If $IsObject(tCaught) Quit ..Statused(..VendorCodesStatus(tCaught.AsStatus(), "the purge"), tMessage, .pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) Quit ..Statused(..VendorCodesStatus(tVendorSC, "the purge"), tMessage, .pHttpStatus, .pFault)
    Set tReadSC = ..ReadLogState(pNamespace, pKind, .tRow, .tReadHttp, .tReadFault)
    If $$$ISERR(tReadSC) || '$IsObject(tRow) {
        Set tRow = {}
        Do tRow.%Set("Namespace", pNamespace, "string")
    }
    Set pResult = tRow
    Set pHttpStatus = 200
    Set pFault = ""
    Quit $$$OK
}

/// <p>Serve the RuleLog and ProcessLog endpoints after <method>Invoke</method>'s gate (Story 24.17 Batch 2): the list, the state read and the write, the purge of that log.</p>
ClassMethod InvokeLog(pNamespace As %String, pEndpoint As %String, pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        Set tKind = ..LogKind(pEndpoint)
        If pType = ..#TYPELIST {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..ListLog(pNamespace, tKind, .pQuery, +tMaxText, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tWrite = $Select(tKind = ..#LOGKINDRULE: ..#TYPEPURGERULELOG, 1: ..#TYPEPURGEPROCESSLOG)
        Set tAction = $Select(..IsLogPurgeWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && (tAction '= tWrite) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If pType = tWrite {
            Set tSC = ..PerformLogPurge(pNamespace, tKind, $Get(pQuery(..#PURGEDAYSKEY)), .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..ReadLogState(pNamespace, tKind, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..LogMapped(ex, "the log call failed inside the port", .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The lines <method>Snippet</method> adds for the purge of the log <var>pEndpoint</var> serves with the days <var>pDays</var> (Story 24.17 Batch 2): the vendor's call, with the days the port itself would
/// pass (<method>LogKeepDays</method>). <code>""</code> for a namespace or days the port would refuse by shape, which renders no draft. Nothing here runs; a person runs it.</p>
ClassMethod LogPurgeSnippet(pEndpoint As %String, pNamespace As %String, pDays As %String) As %String [ Private ]
{
    If '$Match(pNamespace, ##class(OcuPilot.Port.AtelierPort).#NAMESPACEPATTERN) || '..PurgeDaysOK(pDays) Quit ""
    Set tNL = $Char(10)
    Set tDaysText = $Select(+pDays > (+$Horolog - 2): "+$Horolog - 2", 1: +pDays)
    If pEndpoint = ..#ENDPOINTRULELOG Quit tNL _ " Set tSC = ##class(Ens.Purge).PurgeRuleLogsByDate(" _ tDaysText _ ", .tDeleted)"
    Quit tNL _ " Set tSC = ##class(Ens.Purge).PurgeBusinessProcessesByDate(" _ tDaysText _ ", .tDeleted, 1)"
}

}
