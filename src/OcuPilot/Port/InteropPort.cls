Include Ensemble

/// <p>The port to the instance's interoperability runtime (AD-62, AD-29, AD-52, Stories 20.2, 20.3, 20.5, 20.6 and 20.23): <b>the
/// only product class that starts, stops, restarts, updates or recovers a production, enables, disables,
/// adds or removes one of its items, aborts a queued message, a queue's messages or a job's retried message,
/// suspends that message or stops a job, adds, changes or removes a lookup table's entry, deletes, imports or exports a lookup
/// table, or sends a test request to an item</b>, and the only one that reads the interoperability configuration for
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
/// <p><b>The host test</b> (Story 20.6, the <code>ItemTest</code> endpoint) lists the request classes an item takes (the host class's
/// own <code>GetMessageList</code>, as the classic dialog reads it, then their subclasses from the class dictionary) and their
/// settable fields from the class dictionary, and sends one test request through <code>EnsLib.Testing.Service</code> as the
/// classic Testing Service dialog does, asynchronously. It refuses by name, before any vendor call, whatever the vendor would
/// answer as a silent success or write to the device about: the production not running, testing not enabled, a target that is
/// not an enabled process or operation, a request class the target does not take, and a value for a credential-named field.
/// Every vendor call that can write to the device runs inside the output capture, so the answer stays JSON, and what a test
/// answered reaches the screen and the proposal card only (AD-39's seventh exception). The vendor audits no test, so the port
/// records OcuPilot's own row (<method>AuditRuntime</method>).</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>LogFault</method>,
/// <method>StopSeconds</method>, <method>RoutineResource</method>, <method>SourceControlled</method>,
/// <method>VendorAbortItem</method>, <method>VendorJob</method>, <method>LockTable</method>, <method>VendorSendTest</method>
/// and <method>TestWait</method>, and the parameter <parameter>ABORTMAX</parameter>. Production overrides none.</p>
Class OcuPilot.Port.InteropPort Extends %RegisteredObject
{

/// <p>The class the pair sets are evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The endpoints this port serves, comma-separated: the namespace's productions, business
/// processes, data transformations and business rules, and a production's items.
/// <file>ui/tools/screen-mirror.mjs</file> reads this list.</p>
Parameter ENDPOINTS = "Productions,Processes,Transforms,Rules,Items,Settings,Monitor,ItemStatus,Queues,QueueItems,ItemQueue,ItemLog,ItemMessages,Jobs,ItemJobs,LookupTables,LookupEntries,BusinessPartners,ItemTest";

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

/// <p>An item's host test (Story 20.6): <code>LIST</code> for the item <parameter>ITEMKEY</parameter> names (one row for each
/// settable field of each request class it takes), <code>TESTTARGET</code> (the composed fresh read of the test about to be
/// sent) and the write <code>SENDTEST</code>.</p>
Parameter ENDPOINTITEMTEST = "ItemTest";

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

/// <p>The pairs the ItemTest endpoint requires: the classic Interoperability menu's <code>%Ens_Portal:USE</code> and
/// <code>EnsPortal.TestingService</code>'s own resource (Story 20.6). The vendor's <code>SendTestRequest</code> checks no
/// privilege (measured), so these, and WRITE on the namespace's globals database for a send, are the whole gate.</p>
Parameter TESTPAIRS = "%Ens_Portal:USE,%Ens_TestingService:USE";

/// <p>The endpoint and type pairs that send no body and take their arguments through the query (AD-51 as amended by Story 12.3): the
/// lookup table export and import (Story 20.5), whose files and reviewed counts the port reads from its query, and the host test's
/// send (Story 20.6), whose request class and field values it reads from its query.</p>
Parameter COMPOSEDTYPES = "LookupTables/EXPORT,LookupTables/IMPORT,ItemTest/SENDTEST";

/// <p>The pair each item tab adds to the Productions endpoint's pairs (the classic configuration page's
/// <code>initSecurity</code>): the queue, the event log, the message headers and the jobs.</p>
Parameter ITEMQUEUEPAIR = "%Ens_Queues:READ";

Parameter ITEMLOGPAIR = "%Ens_EventLog:USE";

Parameter ITEMMESSAGEPAIR = "%Ens_MessageHeader:USE";

Parameter ITEMJOBPAIR = "%Ens_Jobs:READ";

/// <p>The pair a write adds: the vendor's own run resource, the classic
/// <code>EnsPortal.ProductionConfig</code> check (measured: start, stop and restart answer #940
/// without it).</p>
Parameter WRITEPAIRS = "%Ens_ProductionRun:USE";

/// <p>The pair an item write adds to the Productions endpoint's pairs: the classic
/// <code>EnsPortal.ProductionConfig</code> editor's resource at WRITE. The vendor's item writes check no
/// privilege of their own (measured), so the declared pairs are the whole gate. An item write does not
/// need <code>%Ens_ProductionRun:USE</code>.</p>
Parameter ITEMWRITEPAIRS = "%Ens_ProductionConfig:WRITE";

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

/// <p>The entity types and verbs the audit row of a lookup write names (<method>AuditRuntime</method>, Story 20.5).</p>
Parameter ENTITYLOOKUPTABLE = "lookup-table";

Parameter ENTITYLOOKUPENTRY = "lookup-entry";

Parameter VERBADD = "add";

Parameter VERBSET = "set";

Parameter VERBREMOVE = "remove";

Parameter VERBDELETE = "delete";

Parameter VERBIMPORT = "import";

Parameter VERBEXPORT = "export";

/// <p>The query key naming the item a <code>Settings</code> list reads: its one criterion. Its value is the item's
/// composite id <code>[Production, Name]</code> or the vendor's config name <code>Production||Name</code>.</p>
Parameter ITEMKEY = "item";

/// <p>The query key naming the queue a <code>QueueItems</code> list reads: its one criterion (Story 20.4).</p>
Parameter QUEUEKEY = "queue";

/// <p>The query key carrying the digest a queue abort was reviewed with (Story 20.23): the write refuses a queue whose
/// entries no longer give it.</p>
Parameter DIGESTKEY = "digest";

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

/// <p>Whether <var>pType</var> is one of the item writes this port carries (Story 20.3).</p>
ClassMethod IsItemWrite(pType As %String) As %Boolean
{
    Quit (pType = ..#TYPEENABLE) || (pType = ..#TYPEDISABLE) || (pType = ..#TYPEADD) || (pType = ..#TYPEREMOVE)
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

/// <p>Whether <var>pType</var> is the host test's send (Story 20.6): an action-style write over a port-composed read, needing WRITE on
/// the namespace's globals database and no routines database.</p>
ClassMethod IsTestWrite(pType As %String) As %Boolean
{
    Quit pType = ..#TYPESENDTEST
}

/// <p>Whether <var>pType</var> is any write this port carries, whichever family declares it.</p>
ClassMethod IsAnyWrite(pType As %String) As %Boolean
{
    Quit ..IsWrite(pType) || ..IsItemWrite(pType) || ..IsSettingWrite(pType) || ..IsRuntimeWrite(pType) || ..IsLookupWrite(pType) || ..IsTestWrite(pType)
}

/// <p>The endpoints Story 20.4 added, as a <class>%List</class>: the nine runtime reads. Each serves <code>LIST</code>; Queues,
/// QueueItems and Jobs also serve the typed reads and writes of Story 20.23 (<method>Serves</method>).</p>
ClassMethod RuntimeEndpoints() As %List
{
    Quit $ListBuild(..#ENDPOINTMONITOR, ..#ENDPOINTITEMSTATUS, ..#ENDPOINTQUEUES, ..#ENDPOINTQUEUEITEMS, ..#ENDPOINTITEMQUEUE, ..#ENDPOINTITEMLOG, ..#ENDPOINTITEMMESSAGES, ..#ENDPOINTJOBS, ..#ENDPOINTITEMJOBS)
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
/// own (queue, event log, message headers, jobs).</p>
ClassMethod Pairs(pEndpoint As %String, pType As %String = "") As %List
{
    If (pEndpoint = ..#ENDPOINTPRODUCTIONS) || (pEndpoint = ..#ENDPOINTITEMS) || (pEndpoint = ..#ENDPOINTSETTINGS) || (pEndpoint = ..#ENDPOINTITEMSTATUS) || (pEndpoint = ..#ENDPOINTBUSINESSPARTNERS) {
        Set tSpec = ..#PRODUCTIONPAIRS
    } ElseIf (pEndpoint = ..#ENDPOINTLOOKUPTABLES) || (pEndpoint = ..#ENDPOINTLOOKUPENTRIES) {
        Set tSpec = ..#LOOKUPPAIRS
    } ElseIf pEndpoint = ..#ENDPOINTITEMTEST {
        Set tSpec = ..#TESTPAIRS
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
    } ElseIf pEndpoint = ..#ENDPOINTITEMJOBS {
        Set tSpec = ..#PRODUCTIONPAIRS _ "," _ ..#ITEMJOBPAIR
    } ElseIf $ListFind(..Endpoints(), pEndpoint) {
        Set tSpec = ..#CODEPAIRS
    } Else {
        Quit ""
    }
    If ..IsWrite(pType) Set tSpec = tSpec _ "," _ ..#WRITEPAIRS
    If ..IsItemWrite(pType) || ..IsSettingWrite(pType) Set tSpec = tSpec _ "," _ ..#ITEMWRITEPAIRS
    If (pType = ..#TYPEABORTQUEUE) || (pType = ..#TYPEABORTMESSAGE) Set tSpec = tSpec _ "," _ ..#QUEUEWRITEPAIR
    If (pType = ..#TYPEABORTJOB) || (pType = ..#TYPESTOPJOB) Set tSpec = tSpec _ "," _ ..#JOBWRITEPAIR
    If pType = ..#TYPESUSPENDJOB Set tSpec = tSpec _ "," _ ..#SUSPENDPAIR
    If ..IsLookupWrite(pType) Set tSpec = tSpec _ "," _ ..#LOOKUPWRITEPAIR
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(tSpec)
}

/// <p>Whether endpoint <var>pEndpoint</var> serves request type <var>pType</var>: <code>LIST</code> on every endpoint; and,
/// beyond it, Productions the production reads and writes, Items and Settings theirs, and Queues (<code>QUEUE</code>,
/// <code>ABORTQUEUE</code>), QueueItems (<code>ENTRY</code>, <code>ABORTMESSAGE</code>) and Jobs (<code>JOB</code>,
/// <code>ABORTJOB</code>, <code>SUSPENDJOB</code>, <code>STOPJOB</code>).</p>
ClassMethod Serves(pEndpoint As %String, pType As %String) As %Boolean
{
    If '$ListFind(..Endpoints(), pEndpoint) Quit 0
    If pType = ..#TYPELIST Quit 1
    If pEndpoint = ..#ENDPOINTITEMS Quit (pType = ..#TYPEITEM) || ..IsItemWrite(pType)
    If pEndpoint = ..#ENDPOINTSETTINGS Quit (pType = ..#TYPESETTING) || ..IsSettingWrite(pType)
    If pEndpoint = ..#ENDPOINTQUEUES Quit (pType = ..#TYPEQUEUE) || (pType = ..#TYPEABORTQUEUE)
    If pEndpoint = ..#ENDPOINTQUEUEITEMS Quit (pType = ..#TYPEENTRY) || (pType = ..#TYPEABORTMESSAGE)
    If pEndpoint = ..#ENDPOINTJOBS Quit (pType = ..#TYPEJOB) || (pType = ..#TYPEABORTJOB) || (pType = ..#TYPESUSPENDJOB) || (pType = ..#TYPESTOPJOB)
    If pEndpoint = ..#ENDPOINTLOOKUPTABLES Quit (pType = ..#TYPELOOKUPTABLE) || (pType = ..#TYPEDELETETABLE) || (pType = ..#TYPEIMPORTTABLE) || (pType = ..#TYPEIMPORT) || (pType = ..#TYPEEXPORT)
    If pEndpoint = ..#ENDPOINTLOOKUPENTRIES Quit (pType = ..#TYPELOOKUPENTRY) || (pType = ..#TYPEADDENTRY) || (pType = ..#TYPESETENTRY) || (pType = ..#TYPEREMOVEENTRY)
    If pEndpoint = ..#ENDPOINTITEMTEST Quit (pType = ..#TYPETESTTARGET) || (pType = ..#TYPESENDTEST)
    If pEndpoint '= ..#ENDPOINTPRODUCTIONS Quit 0
    Quit (pType = ..#TYPESTATE) || ..IsWrite(pType)
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
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace is
/// unchanged on return.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
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
        If $ListFind(..RuntimeEndpoints(), pEndpoint) {
            Set tSC = ..InvokeRuntime(tNamespace, pEndpoint, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pEndpoint = ..#ENDPOINTLOOKUPTABLES) || (pEndpoint = ..#ENDPOINTLOOKUPENTRIES) {
            Set tSC = ..InvokeLookup(tNamespace, pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
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
    Set tWrite = ..IsAnyWrite(pType)
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
/// LastStartTime, LastStopTime}</code>, at most <var>pMax</var> of them when it is above zero. The
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
        Set tResultSet = ##class(%ResultSet).%New("Ens.Config.Production:ProductionStatus")
        Set tStatusSC = tResultSet.Execute()
        If $$$ISOK(tStatusSC) {
            While tResultSet.Next() {
                If (pMax > 0) && (tFound >= pMax) Quit
                Set tFound = tFound + 1
                Set tWord = ##class(Ens.Config.Production).ProductionStateToText(+tResultSet.GetData(5), 0)
                If $Extract(tWord, 1, 13) = "Unrecognized:" Set tWord = "Unknown"
                Set tFound(tFound) = $ListBuild(tResultSet.GetData(1), tWord, tResultSet.GetData(3), tResultSet.GetData(4))
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
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The classes of <var>pEndpoint</var>'s kind in <var>pNamespace</var>, at most <var>pMax</var> of
/// them when it is above zero: the subclasses of <code>Ens.BusinessProcess</code> less
/// <code>Ens.BusinessProcessBPL</code>, of <code>Ens.DataTransform</code> less
/// <code>Ens.DataTransformDTL</code>, and of <code>Ens.Rule.Definition</code>, through
/// <code>%Dictionary.ClassDefinition:SubclassOf</code>, which writes nothing. A row is
/// <code>{Name, Modified}</code>: the document name <code>&lt;class&gt;.cls</code> and the class's
/// <code>TimeChanged</code> as local <code>YYYY-MM-DD HH:MM:SS</code>.</p>
ClassMethod ListClasses(pNamespace As %String, pEndpoint As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set tCaught = ""
    Set tStatusSC = $$$OK
    Set tSuper = $Case(pEndpoint, ..#ENDPOINTPROCESSES: "Ens.BusinessProcess", ..#ENDPOINTTRANSFORMS: "Ens.DataTransform", : "Ens.Rule.Definition")
    Set tExcluded = $Case(pEndpoint, ..#ENDPOINTPROCESSES: "Ens.BusinessProcessBPL", ..#ENDPOINTTRANSFORMS: "Ens.DataTransformDTL", : "")
    Kill tFound
    Set tFound = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tResultSet = ##class(%ResultSet).%New("%Dictionary.ClassDefinition:SubclassOf")
        Set tStatusSC = tResultSet.Execute(tSuper)
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
                Set tFound(tFound) = $ListBuild(tName, tModified)
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
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
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

/// <p>Serve the Items endpoint (Story 20.3) after <method>Invoke</method>'s gate. A <code>LIST</code> names
/// its production under <parameter>PRODUCTIONKEY</parameter>; every other type names an item by the
/// composite id <code>[Production, Name]</code> under <parameter>IDKEY</parameter>, never by the vendor's
/// integer id, which a recompile renumbers.</p>
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
        Set tAction = $Select(..IsItemWrite(pType): pType, 1: $Get(pQuery(..#ACTIONKEY)))
        If (tAction '= "") && '..IsItemWrite(tAction) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If ..IsItemWrite(pType) {
            Set tSC = ..PerformItem(pNamespace, pType, tProduction, tName, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..ReadItem(pNamespace, tProduction, tName, tAction, .pResult, .pHttpStatus, .pFault)
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
/// <li>Add: <code>TAKEN</code> when the name is held.</li>
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
    If pType = ..#TYPEADD {
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
/// (<method>ItemRefusal</method>); for an add (AD-54) it inverts, so absence is the 404 the create
/// expects and a held name is <code>TAKEN</code>.</p>
ClassMethod ReadItem(pNamespace As %String, pProduction As %String, pName As %String, pAction As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    If ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMSOURCECONTROL, .pHttpStatus, .pFault)
    Set tSC = ..GatherItems(pNamespace, pProduction, pName, 0, .tExists, .tFound, .tCount, .tCaught)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item read failed", .pHttpStatus, .pFault)
    If pAction = ..#TYPEADD {
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
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The in-memory item of <var>pProduction</var> named exactly <var>pName</var>, or <code>""</code>.
/// Called while the production's namespace is switched; only vendor classes run.</p>
ClassMethod ItemObject(pProduction As Ens.Config.Production, pName As %String) As Ens.Config.Item [ Private ]
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
/// <li>An add's fields are validated (<method>AddViolations</method>): 422.</li>
/// <li>The production is opened at concurrency 4, so writers on one production wait on the vendor's row
/// lock; a lock not taken in time is 503 <code>PORT.UNAVAILABLE</code>.</li>
/// <li>The item's facts are read under that lock and judged by <method>ItemRefusal</method>: 409.</li>
/// <li>Enable and disable call <code>Ens.Director:EnableConfigItem</code> with no update; add inserts a new
/// <code>Ens.Config.Item</code> and saves the production; remove calls <code>RemoveItem</code> and saves
/// it. Add and remove record <code>%Ensemble/%Production/ModifyConfiguration</code> through
/// <code>Ens.Util.Auditing</code>, naming the operation and the item and never a value; enable and
/// disable carry the vendor's own event. The vendor answers an error status only when the audit call
/// raises (an event that is disabled is dropped without one); that status is logged once the namespace is
/// restored and never fails the write.</li>
/// <li>The production class is saved every time (<code>SaveToClass</code>), because the configuration
/// alone is reverted by the next compile of the class. A failure there, after the configuration saved, is
/// a logged 500.</li>
/// </ol>
/// <p>Every reference is dropped before the namespace is restored.</p>
ClassMethod PerformItem(pNamespace As %String, pType As %String, pProduction As %String, pName As %String, pBody As %DynamicObject, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pSettingTarget As %String = "", pSettingName As %String = "") As %Status [ Private ]
{
    Set pResult = ""
    If ..SourceControlled(pNamespace) Quit ..Conflict(##class(OcuPilot.Api.InteropError).#ITEMSOURCECONTROL, .pHttpStatus, .pFault)
    Set tSetting = ..IsSettingWrite(pType)
    If pType = ..#TYPESET {
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONITEMBODY, .pHttpStatus, .pFault)
        Set tViolationSC = ..SettingViolations(pNamespace, pProduction, pName, pSettingTarget, pSettingName, pBody, .tViolations)
        If $$$ISERR(tViolationSC) Quit ..Fail("the setting's value could not be judged", tViolationSC, .pHttpStatus, .pFault)
        If tViolations > 0 Quit ..Violations(.tViolations, .pHttpStatus, .pFault)
    }
    If pType = ..#TYPEADD {
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONITEMBODY, .pHttpStatus, .pFault)
        Set tViolationSC = ..AddViolations(pNamespace, pName, pBody, .tViolations)
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
            } Else {
                Set tFactsSC = ..GatherItems(pNamespace, pProduction, pName, 0, .tExists, .tFound, .tCount, .tGatherCaught)
                If $IsObject(tGatherCaught) Throw tGatherCaught
                Set tLine = $Get(tFound(1))
                If (pType '= ..#TYPEADD) && (tCount = 0) {
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
                If (tRefusal = "") && 'tAbsent {
                    Set tName = $Select(tLine = "": pName, 1: $List(tLine, 1))
                    Set tTarget = ""
                    If (pType = ..#TYPEENABLE) || (pType = ..#TYPEDISABLE) {
                        Set tVendorSC = ##class(Ens.Director).EnableConfigItem(pProduction _ "||" _ tName, (pType = ..#TYPEENABLE), 0)
                        If $$$ISOK(tVendorSC) Set tSaveSC = tProduction.SaveToClass(..ItemObject(tProduction, tName))
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
ClassMethod SettingStep(pNamespace As %String, pType As %String, pProduction As %String, pItem As %String, pTarget As %String, pName As %String, pBody As %DynamicObject, pOrigNS As %String, pLocked As Ens.Config.Production, Output pStep) [ Private ]
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

/// <p>Serve one of the nine runtime endpoints after <method>Invoke</method>'s gate. <code>LIST</code> answers an array of
/// rows, at most <parameter>MAXROWSKEY</parameter> of them when that is above zero, and writes nothing:
/// <code>Ens.Job:Enumerate</code>, whose <code>MarkDeadJobs</code> writes, is never called.</p>
/// <ul>
/// <li>Monitor, Queues and Jobs take no criterion; QueueItems takes <parameter>QUEUEKEY</parameter>; every other
/// endpoint takes the item under <parameter>ITEMKEY</parameter> (the composite id or <code>Production||Name</code>),
/// resolved as an item read resolves it: 400 when it is not one, 404 for an unknown production or item, 409
/// <code>INTEROP.ITEM.AMBIGUOUS</code> for a name the production holds more than once.</li>
/// <li>Queues, QueueItems and Jobs also serve a typed read (<parameter>TYPEQUEUE</parameter>, <parameter>TYPEENTRY</parameter>,
/// <parameter>TYPEJOB</parameter>) and the action writes of Story 20.23 (<method>InvokeTyped</method>).</li>
/// </ul>
ClassMethod InvokeRuntime(pNamespace As %String, pEndpoint As %String, pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Try {
        If pType '= ..#TYPELIST {
            Set tSC = ..InvokeTyped(pNamespace, pEndpoint, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
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
/// <code>Ens.Config.Item.QueueName()</code> and <var>pTarget</var> is <code>""</code>. Called while the
/// production's namespace is switched; only vendor classes run.</p>
ClassMethod ItemQueueName(pItem As Ens.Config.Item, Output pTarget As %String) As %String
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
/// first (AD-29). <var>pFound(n)</var> is the row as a <code>%List</code> of its columns. A fault is
/// <var>pCaught</var>, with the namespace restored.</p>
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

/// <p>The rows of the Messages tab's statement: the newest headers sourced by the item and the newest targeted at it,
/// newest first, as the classic configuration page's Messages tab reads them (<code>EnsPortal.ProductionConfig</code>). The
/// stamp is read as stored, as the Log statement's is.</p>
Parameter MESSAGESQL = "SELECT TOP ? ID, TimeCreated, %EXTERNAL(Status), SourceConfigName, TargetConfigName, MessageBodyClassName, SessionId FROM Ens.MessageHeader WHERE ID IN (SELECT TOP ? ID FROM Ens.MessageHeader WHERE SourceConfigName = ? ORDER BY ID DESC UNION SELECT TOP ? ID FROM Ens.MessageHeader WHERE TargetConfigName = ? ORDER BY ID DESC) ORDER BY ID DESC";

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
    Set tSC = ..SqlRows(pNamespace, ..#MESSAGESQL, .tFound, .tCaught, tTop, tTop, pItem, tTop, pItem)
    If $IsObject(tCaught) Quit ..Mapped(tCaught, "the item's messages failed", .pHttpStatus, .pFault)
    Set pRows = []
    For tI = 1:1:tFound {
        Set tLine = tFound(tI)
        Set tRow = {}
        Do tRow.%Set("Production", pProduction, "string")
        Do tRow.%Set("Item", pProduction _ "||" _ pItem, "string")
        Do tRow.%Set("ID", $List(tLine, 1) _ "", "string")
        Do tRow.%Set("TimeCreated", ..LocalStamp($List(tLine, 2)), "string")
        Do tRow.%Set("Status", $List(tLine, 3) _ "", "string")
        Do tRow.%Set("Source", $List(tLine, 4) _ "", "string")
        Do tRow.%Set("Target", $List(tLine, 5) _ "", "string")
        Do tRow.%Set("BodyClass", $List(tLine, 6) _ "", "string")
        Do tRow.%Set("SessionId", $List(tLine, 7) _ "", "string")
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
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
    Quit $ZConvert(##class(%xsd.hexBinary).LogicalToXSD($System.Encryption.SHAHash(256, $ZConvert(tText, "O", "UTF8"))), "L")
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
/// restored. No body is read.</p>
ClassMethod HeaderFacts(pNamespace As %String, pId As %String, Output pExists As %Boolean, Output pQueue As %String, Output pStatus As %String, Output pCaught) As %Status [ Private ]
{
    Set pExists = 0
    Set pQueue = ""
    Set pStatus = ""
    Set pCaught = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tHeader = ##class(Ens.MessageHeader).%OpenId(pId)
        If $IsObject(tHeader) {
            Set pExists = 1
            Set pQueue = tHeader.TargetQueueName
            Set pStatus = ##class(Ens.DataType.MessageStatus).LogicalToDisplay(tHeader.Status)
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

/// <p>Record OcuPilot's own <code>ConfigChange</code> row for one queue, job or lookup write, a lookup export or a host test, that read OK
/// (AD-15, Stories 20.23, 20.5 and 20.6), from whichever caller made it: the vendor records none. <var>pVerb</var> is one of the
/// <code>VERB</code> parameters, <var>pType</var> the entity type of the target and <var>pId</var> its id; <var>pEffects</var>
/// names the namespace and, as the action has them, the queue, the table, the counts or the host, and never a message's content
/// or an entry's value. It never fails the write.
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
    If (pEndpoint = ..#ENDPOINTITEMS) && ..IsItemWrite(pType) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTSETTINGS) && ..IsSettingWrite(pType) Quit "objectscript"
    If ..IsRuntimeWrite(pType) && ..Serves(pEndpoint, pType) Quit "objectscript"
    If (..IsLookupWrite(pType) || (pType = ..#TYPEEXPORT)) && ..Serves(pEndpoint, pType) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTITEMTEST) && ..IsTestWrite(pType) Quit "objectscript"
    If pEndpoint '= ..#ENDPOINTPRODUCTIONS Quit ""
    If ..IsWrite(pType) Quit "objectscript"
    Quit ""
}

/// <p><method>Perform</method>'s and <method>PerformItem</method>'s branches as a script (AD-59), in the
/// namespace <parameter>NAMESPACEKEY</parameter> names: <code>Ens.Director</code>'s
/// <code>StartProduction</code> of the one production, <code>StopProduction</code>,
/// <code>RestartProduction</code> and <code>UpdateProduction</code> with the production's own timeout capped
/// at <parameter>STOPSECONDS</parameter>, and <code>RecoverProduction</code>; an item's
/// <code>EnableConfigItem</code>, add and remove, each followed by the production class's
/// <code>SaveToClass</code>; and the queue and job actions (<method>RuntimeSnippet</method>). A read writes nothing and answers no step. Every value is rendered as a
/// string literal, so nothing the query carries runs as code, and every line closes any block it opens.
/// Whoever runs the script is checked by the vendor's own run resource, and a recover by the namespace's
/// database alone; an item write is checked by the databases alone.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tText = " Set $NAMESPACE = " _ ..Literal($Get(pQuery(..#NAMESPACEKEY)))
    If pEndpoint = ..#ENDPOINTITEMS {
        Set tText = tText _ ..ItemSnippet(pType, $Get(pQuery(..#IDKEY)), pBody)
    } ElseIf pEndpoint = ..#ENDPOINTSETTINGS {
        Set tText = tText _ ..SettingSnippet(pType, $Get(pQuery(..#IDKEY)), pBody)
    } ElseIf pEndpoint = ..#ENDPOINTITEMTEST {
        Set tText = tText _ ..TestSnippet($Get(pQuery(..#IDKEY)), .pQuery)
    } ElseIf ..IsRuntimeWrite(pType) {
        Set tText = tText _ ..RuntimeSnippet(pType, $Get(pQuery(..#IDKEY)), pContext)
    } ElseIf (pType = ..#TYPEIMPORT) || (pType = ..#TYPEEXPORT) {
        Set tText = tText _ ..TransferSnippet(pType, $Get(pQuery(..#IDKEY)), .pQuery)
    } ElseIf ..IsLookupWrite(pType) {
        Set tText = tText _ ..LookupSnippet(pType, $Get(pQuery(..#IDKEY)), pBody)
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
/// id <var>pId</var> names, carrying the add's body <var>pBody</var>. The last line drops the production, so a
/// terminal that runs the script does not keep its exclusive lock.</p>
ClassMethod ItemSnippet(pType As %String, pId As %String, pBody As %DynamicAbstractObject) As %String [ Private ]
{
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pId)
    Set tProduction = ..Literal($ListGet(tParts, 1))
    Set tName = ..Literal($ListGet(tParts, 2))
    Set tConfigName = ..Literal($ListGet(tParts, 1) _ "||" _ $ListGet(tParts, 2))
    Set tNL = $Char(10)
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
    } Else {
        Set tText = tText _ tNL _ " Do tProduction.RemoveItem(tProduction.FindItemByConfigName(" _ tName _ "))"
        Set tText = tText _ tNL _ " Set tSC = tProduction.%Save()"
        Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = tProduction.SaveToClass()"
    }
    ; The production was opened with its exclusive lock, which lasts while a reference to it does.
    Set tText = tText _ tNL _ " Kill tItem, tProduction"
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
                For tContact = "PrimaryContact", "AlternativeContact" {
                    Set tObject = $Select($IsObject(tPartner): $Property(tPartner, tContact), 1: "")
                    If $IsObject(tObject) {
                        Set tLine = tLine _ $ListBuild(tObject.Name, tObject.Title, tObject.Email, tObject.PhoneNumber, tObject.MobileNumber, tObject.Notes)
                    } Else {
                        Set tLine = tLine _ $ListBuild("", "", "", "", "", "")
                    }
                    Set tObject = ""
                }
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
    Set tNames = $ListBuild("Name", "Description", "PrimaryContact", "PrimaryTitle", "PrimaryEmail", "PrimaryPhone", "PrimaryMobile", "PrimaryNotes", "AlternativeContact", "AlternativeTitle", "AlternativeEmail", "AlternativePhone", "AlternativeMobile", "AlternativeNotes")
    Set pRows = []
    For tI = 1:1:tFound {
        Set tRow = {}
        For tJ = 1:1:$ListLength(tNames) {
            Do tRow.%Set($List(tNames, tJ), $List(tFound(tI), tJ) _ "", "string")
        }
        Do pRows.%Push(tRow)
    }
    Set pHttpStatus = 200
    Quit $$$OK
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
        If (tAction '= "") && '..IsTestWrite(tAction) {
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
    If '$Match(pHostClass, "^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") Quit
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
    If '$Match(pClass, "^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") Quit 0
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
    If '$Match(pClass, "^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") Quit
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
/// <code>Secret</code> (AD-35). A document's <code>content</code> is bounded by the longest text the screen sends.</p>
ClassMethod TestFieldRow(pProduction As %String, pItemName As %String, pLine As %List) As %DynamicObject [ Private ]
{
    Set tKind = $List(pLine, 2)
    Set tPath = $List(pLine, 3)
    Set tRow = {}
    Do tRow.%Set("Production", pProduction, "string")
    Do tRow.%Set("Item", pProduction _ "||" _ pItemName, "string")
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

/// <p>The text members of <var>pInput</var> (<method>ParseTestFields</method>) that are not empty, as canonical JSON text: one
/// object whose members are in name order. It is the value <code>Fields</code> reads and the fingerprint covers, so one request
/// reads one text. Pure.</p>
ClassMethod CanonicalFields(ByRef pInput) As %String [ Private ]
{
    Set tObject = {}
    Set tKey = ""
    For {
        Set tKey = $Order(pInput(tKey), 1, tValue)
        If tKey = "" Quit
        If tValue '= "" Do tObject.%Set(tKey, tValue, "string")
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
/// <code>ImportFromString</code> of its text, any other class a new instance with each field set, along its path, to its logical
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
        Set tImport = $$$OK
        Set tObject = $ClassMethod(pRequestClass, "ImportFromString", pPlan("content"), .tImport)
        If $$$ISERR(tImport) Quit tImport
        If '$IsObject(tObject) Quit $$$ERROR($$$GeneralError, "the text did not give a " _ pRequestClass)
    } Else {
        Set tObject = $ClassMethod(pRequestClass, "%New")
        If '$IsObject(tObject) Quit $$$ERROR($$$GeneralError, "a " _ pRequestClass _ " could not be created")
        Set tFailed = ""
        For tI = 1:1:+$Get(pPlan) {
            If tFailed '= "" Quit
            Set tRecord = pPlan(tI)
            Set tChain = $List(tRecord, 4)
            Set tCurrent = tObject
            For tJ = 1:1:$Length($List(tRecord, 1), ".") - 1 {
                Set tSegment = $Piece($List(tRecord, 1), ".", tJ)
                Set tNext = $Property(tCurrent, tSegment)
                If '$IsObject(tNext) {
                    Set tNext = $ClassMethod($List(tChain, tJ), "%New")
                    If '$IsObject(tNext) {
                        Set tFailed = "an embedded " _ $List(tChain, tJ) _ " could not be created"
                        Quit
                    }
                    Set $Property(tCurrent, tSegment) = tNext
                }
                Set tCurrent = tNext
            }
            If tFailed '= "" Quit
            Set $Property(tCurrent, $List(tRecord, 2)) = $List(tRecord, 6)
        }
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

/// <p>Wait, at most <method>TestWait</method> seconds, for the test session <var>pSession</var>'s answer, reading every
/// <parameter>TESTPOLL</parameter> seconds whether the vendor has recorded its <code>response</code> node, the last one it writes
/// for a finished session (after the top node reads <code>Done</code> or <code>Error</code>), as the classic dialog waits on it;
/// then gather what the vendor kept in <var>pAnswer</var>: <code>status</code> (<code>done</code>, <code>error</code> or
/// <code>waiting</code>), then for an error its <code>error</code> text, for a response <code>responseClass</code> and either its
/// text (<code>document</code>) or its fields (<code>field(n)</code>, <code>$ListBuild(path, value)</code>). A finished session's
/// node is killed, as the classic dialog kills it once it has drawn the answer; a session still waiting is left for the vendor's
/// own cleanup. Called while the production's namespace is switched, and inside the output capture.</p>
ClassMethod AwaitTestHere(pSession As %String, Output pAnswer) [ Private ]
{
    Kill pAnswer
    Set pAnswer("status") = "waiting"
    Set pAnswer("responseClass") = ""
    Set pAnswer("fields") = 0
    Set tDeadline = $ZHorolog + ..TestWait()
    Set tAnswered = 0
    For {
        If $Data($$$EnsRuntimeAppData(..#TESTSERVICE, pSession, "response")) Set tAnswered = 1 Quit
        If $ZHorolog >= tDeadline Quit
        Hang ..#TESTPOLL
    }
    Set tState = $Select(tAnswered: $Get($$$EnsRuntimeAppData(..#TESTSERVICE, pSession)), 1: "")
    If tState = "Error" {
        Set pAnswer("status") = "error"
        Set tError = $Get($$$EnsRuntimeAppData(..#TESTSERVICE, pSession, "error"))
        Set pAnswer("error") = $Select(tError = "": "", 1: $System.Status.GetErrorText(tError))
    } ElseIf tState = "Done" {
        Set pAnswer("status") = "done"
        Do ..CollectResponseHere($Get($$$EnsRuntimeAppData(..#TESTSERVICE, pSession, "response")), .pAnswer)
    }
    If (tState = "Done") || (tState = "Error") Kill $$$EnsRuntimeAppData(..#TESTSERVICE, pSession)
}

/// <p>Open the response <var>pSpec</var> names (<code>$ListBuild(class, id)</code>, the vendor's own record) and gather it into
/// <var>pAnswer</var> as <method>AwaitTestHere</method> describes. A response the namespace no longer holds, or that is not a
/// persistent class, gathers nothing. Called while the production's namespace is switched.</p>
ClassMethod CollectResponseHere(pSpec As %String, ByRef pAnswer) [ Private ]
{
    Set tClass = $Select(pSpec = "": "", 1: $ListGet(pSpec, 1))
    Set tId = $Select(pSpec = "": "", 1: $ListGet(pSpec, 2))
    If (tClass = "") || '$Match(tClass, "^%?[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)*$") Quit
    If '##class(%Dictionary.CompiledClass).%ExistsId(tClass) Quit
    If '$ClassMethod(tClass, "%Extends", "%Library.Persistent") Quit
    Set tObject = $ClassMethod(tClass, "%OpenId", tId)
    If '$IsObject(tObject) Quit
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
/// at most <parameter>TESTOUTPUTMAX</parameter> characters long. Nothing it wrote reaches the answer: the caller logs it.</p>
ClassMethod EndTestCapture(pCookie As %String) As %String [ Private ]
{
    Set tText = ""
    Try {
        Kill tLines
        Set tEndSC = $$EndCapture^%SYS.Capture(pCookie, .tLines)
        If $IsObject($Get(tLines)) {
            Set tIterator = tLines.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tLine) {
                If ($Length(tText) + $Length(tLine)) >= ..#TESTOUTPUTMAX Quit
                Set tText = tText _ tLine
            }
        }
    } Catch {
        Set tText = ""
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
    Set tCount = $Length(tText, $Char(10))
    For tI = 1:1:tCount {
        If pCut Quit
        Set tLine = $Piece(tText, $Char(10), tI)
        If (tI = tCount) && (tLine = "") Quit
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

/// <p>The lines <method>Snippet</method> adds for the host test of the item the composite id <var>pId</var> names (Story 20.6),
/// from the request class and the field values <var>pQuery</var> carries: the request created and each given field set along its
/// path to the logical value its class's <code>&lt;Property&gt;DisplayToLogical</code> makes of the typed one (the typed one where the
/// class has no such method, as the send takes it), a serial object
/// created where the path passes one, the request validated and saved, and the call of <code>EnsLib.Testing.Service</code>. A
/// virtual document is <code>ImportFromString</code> of its text. The class's fields are read in the namespace
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
    Kill tConvert
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = $Get(pQuery(..#NAMESPACEKEY))
        Do ..ClassFieldsHere(tClass, .tMeta)
        For tI = 1:1:tMeta {
            Set tConvert(tI) = ##class(%Dictionary.CompiledMethod).%ExistsId($List(tMeta(tI), 8) _ "||" _ $List(tMeta(tI), 3) _ "DisplayToLogical")
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Kill tMeta, tConvert
        Set tMeta = 0
    }
    Set tText = ""
    If $Get(tMeta(1)) '= "" && ($List(tMeta(1), 1) = "document") {
        Set tText = tNL _ " Set tRequest = $ClassMethod(" _ tClassLiteral _ ", ""ImportFromString"", " _ ..Literal($Get(tInput(..#DOCUMENTFIELD))) _ ", .tSC)"
        Set tText = tText _ tNL _ " If $System.Status.IsOK(tSC) Set tSC = tRequest.%Save()"
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

}
