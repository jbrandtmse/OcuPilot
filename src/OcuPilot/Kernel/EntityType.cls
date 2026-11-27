/// <p>The closed entity-type vocabulary (AD-14). A screen descriptor selects its primary and
/// secondary entity types from this list and nothing else; a value that is not here fails the
/// build, in <file>scripts/check-objectscript.py</file> and again in
/// <file>ui/tools/screen-mirror.mjs</file>, rather than reaching two slices under two
/// spellings.</p>
/// <p>The kernel owns it, so a slice never invents a key. A later story that needs a value
/// adds it <b>here</b> and nowhere else; nothing derives a key from a class name, a route or a
/// display name.</p>
/// <p>The seed is the vocabulary the Release 1 screen lists imply
/// (<file>EXPERIENCE.md</file>'s side-bar screen lists, <file>epics.md</file>'s create and
/// import epic), one value per administered thing. The OAuth 2.0 family is five values: a
/// client configuration, a server definition, a resource server, an authorization server and a
/// server client. The admin API's sixth OAuth 2.0 endpoint,
/// <code>ResourceServerMapping</code>, relates two of those rather than administering a thing
/// of its own, so it has no key here; a story that needs one adds it.</p>
/// <p><code>auditing-configuration</code> is the instance's own auditing settings, which is a
/// configuration object rather than a thing with a name: it has exactly one instance and
/// <class>OcuPilot.Kernel.EntityRef</class>'s <code>singleton</code> id rule canonicalizes every
/// spelling of its id to that one. It is distinct from <code>audit-event</code>, which is one
/// <b>system</b> event of the event roster, and from <code>audit-user-event</code>, one event an
/// application registered; turning the instance's auditing on or off is not a change to any of
/// those rows. The two event types are separate so that a change event's type names the list that
/// shows the event, and a screen listens for its own type alone (DW-1529); a system event is one
/// whose Source begins with <code>%</code>, which is how the vendor splits the two lists.</p>
/// <p><code>agent-definition</code> and <code>agent-switch</code> are OcuPilot's own configuration
/// rather than the instance's, and they are values here for the same reason every other one is: the
/// Definitions list and the Switches screen publish AD-14's change event on them, and a key a slice
/// invented would be a second spelling. <code>agent-switch</code> covers the instance-wide switches
/// and the per-user holds together -- one screen administers both, and a hold is not a thing of its
/// own outside it. <code>agent-policy</code> is the governance policy (Story 14.2), which the
/// Governance policy screen administers and its audit row targets.</p>
/// <p><code>allowed-directory</code> is one root of the instance's directory allow-list, keyed by
/// the path exactly as the instance answers it; it needs no spelling rule of its own.</p>
/// <p>A write of the list targets the whole list, keyed by its purpose, <code>%GUIFileSelector</code>
/// (AD-13).</p>
/// <p><code>namespace</code> is one of the instance's namespaces, keyed by its name, which the
/// instance resolves without case (Story 18.2).</p>
/// <p><code>web-session</code> is one CSP session the instance holds, keyed by its session id as
/// the instance answers it. The id is mixed-case and compared exactly, so it needs no spelling rule
/// of its own.</p>
/// <p><code>background-task</code> is one row of the Background tasks list, keyed by its composite
/// id: the source, then the portal job's number or the admin API task's GUID, whose leading zeros
/// are significant. It is compared exactly, so it needs no spelling rule of its own.</p>
/// <p><code>global-mapping</code>, <code>routine-mapping</code> and <code>package-mapping</code> are
/// one mapping of a namespace, keyed by the composite <code>[namespace, Name]</code> (Story 18.14):
/// the namespace part resolves without case, and the mapping's name keeps its case.</p>
/// <p><code>database-configuration</code> is one database configuration name (Story 18.3), keyed by
/// that name, which the instance resolves without case. It is a second id space beside
/// <code>database</code>, which is keyed by the database's directory.</p>
/// <p><code>language-server</code> is one of the instance's external language servers, keyed by its
/// name, which the instance compares with its case (Story 16.10), so it needs no spelling rule of its
/// own.</p>
/// <p><code>journal-file</code> is one of the instance's journal files, keyed by its full name as the
/// instance's own journal file list spells it, kept exactly (AD-13, AD-21's eighth case);
/// <code>journal-file-database</code> is one database a journal file holds records for, keyed by its
/// system file number within that file (Story 18.5).</p>
/// <p><code>journal-settings</code> is the instance's journal configuration, one object whose every id
/// reads as the singleton (AD-13, Story 18.18).</p>
/// <p><code>journal-record</code> is one record of a journal file, keyed by its <code>Address</code>
/// within the file its list read, kept exactly; it names no write target (AD-13, Story 18.19).</p>
/// <p><code>license-key</code> is the instance's active license key, one object whose every id reads
/// as the singleton (AD-13, Story 18.6).</p>
/// <p><code>license-server</code> is one license server the instance defines, keyed by its name, which
/// the instance stores upper-cased and resolves in any case (AD-13, Story 18.6).</p>
/// <p><code>ecp-data-server</code> is one ECP data server this instance connects to, keyed by its name,
/// which the instance stores upper-cased and resolves in any case (AD-13, Story 18.20).</p>
/// <p><code>ecp-settings</code> is the instance's ECP settings, the singleton (AD-13, Story 18.21).</p>
/// <p><code>ecp-ssl-connection</code> is one ECP application server's SSL/TLS computer name, authorized
/// or pending, keyed by the certificate's distinguished name exactly as the instance stores it (AD-13,
/// Story 18.21).</p>
/// <p><code>encryption-key-file</code> is one encryption key file on the server, keyed by the composite of
/// the allowed directory and the relative name a caller names it by, kept exactly (AD-13, Story 18.7).</p>
/// <p><code>database-encryption-keys</code> is the instance's set of active database encryption keys, and
/// <code>data-element-encryption-keys</code> its set of active data-element encryption keys, each one
/// object whose every id reads as the singleton (AD-13, Story 18.22).</p>
/// <p><code>encryption-startup</code> is the instance's encryption startup settings, a singleton (AD-13,
/// Story 18.23).</p>
/// <p><code>authentication-options</code> is the instance's authentication and web session options, a
/// singleton (AD-13, Story 18.8).</p>
/// <p><code>superserver</code> is one superserver the instance listens on, keyed by the composite of its port and
/// bind address (AD-13, Story 18.25).</p>
/// <p><code>mft-connection</code> is one managed file transfer connection, keyed by its name, which the instance
/// matches exactly and so is kept exactly (AD-13, Story 18.26).</p>
/// <p><code>docdb-application</code> is one Doc DB application record (<code>Security.DocDBs</code>), keyed by the composite of its
/// namespace and name, which the instance resolves in any case (AD-13, Story 18.30).</p>
/// <p><code>routine-application</code> is one privileged routine application (<code>Security.Applications</code> of the
/// routine type), keyed by its name, which the instance resolves in any case (AD-13, Story 18.31).</p>
/// <p><code>docdb-database</code> is one document database of a namespace, keyed by its name, which the
/// instance resolves in any case (AD-13, Story 19.17).</p>
/// <p><code>sql-statement</code> is one SQL statement running on the instance, keyed by the vendor's
/// composite of its server, process and statement hash; it names no write target (AD-13, Story
/// 19.10).</p>
/// <p><code>screen-permission</code> is one screen's adjustable permission set, keyed by the screen's
/// <code>toolIdentifier</code>, kept exactly (AD-13, AD-64, Story 20.15). It is instance-scoped.</p>
/// <p><code>pct-class-access</code> is one web application's percent-class access entry, keyed by the composite of its
/// application, allow type and class (AD-13, Story 18.10).</p>
/// <p><code>production</code> is one interoperability production of a namespace, keyed by its production
/// class name, kept exactly (AD-13, AD-62, Story 20.2). It is namespace-scoped: the route's namespace
/// is the entity's scope.</p>
/// <p><code>production-item</code> is one item of a production, keyed by the composite
/// <code>[Production, Name]</code>, each part kept exactly (AD-13, AD-62, Story 20.3). It is
/// namespace-scoped, has no <code>IDRULES</code> row, and is never identified by the vendor's integer id,
/// which a recompile renumbers.</p>
/// <p><code>production-item-setting</code> is one setting of a production item, keyed by the composite
/// <code>[Production, Item, Target, Name]</code>, each part kept exactly (AD-13, AD-62, Story 20.22). It is
/// namespace-scoped and has no <code>IDRULES</code> row.</p>
/// <p><code>interop-queue</code> is one interoperability queue of a namespace, keyed by its name, kept exactly (AD-13,
/// Story 20.4). <code>interop-message</code> is one message header of a namespace, keyed by the header's id, kept exactly.
/// <code>interop-job</code> is one job of the running production, keyed by its pid, kept exactly. Each is
/// namespace-scoped and has no <code>IDRULES</code> row.</p>
/// <p><code>lookup-table</code> is one lookup table of a namespace, keyed by its name, kept exactly (AD-13, AD-62, Story 20.5).
/// <code>lookup-entry</code> is one entry of a lookup table, keyed by the composite <code>[Table, Key]</code>, each part kept
/// exactly. <code>business-partner</code> is one business partner of a namespace, keyed by its name, kept exactly. Each is
/// namespace-scoped and has no <code>IDRULES</code> row.</p>
/// <p><code>default-setting</code> is one system default setting of a namespace, keyed by the composite
/// <code>[Production, Item, HostClass, Setting]</code>, each part kept exactly (AD-13, AD-62, Story 24.15). It is namespace-scoped and has no
/// <code>IDRULES</code> row.</p>
/// <p><code>interop-credential</code> is one credential of a namespace, keyed by its name, kept exactly (AD-13, AD-62, Story 24.15). It is
/// namespace-scoped and has no <code>IDRULES</code> row.</p>
/// <p><code>interop-schedule</code> is one schedule spec of a namespace, keyed by its name, kept exactly (AD-13, AD-62, Story 24.15). It is
/// namespace-scoped and has no <code>IDRULES</code> row.</p>
/// <p><code>interop-purge</code> is a namespace's management data purge and <code>interop-purge-setting</code> one of its four purge data settings, keyed by
/// its name, kept exactly (AD-13, AD-62, Story 24.16). Both are namespace-scoped and have no <code>IDRULES</code> row.</p>
/// <p><code>interop-archive</code> is a namespace's local archive run and <code>interop-archive-setting</code> one of its archive settings, keyed by its name, kept exactly (AD-13, AD-62,
/// Story 24.16 Batch 4). Both are namespace-scoped and have no <code>IDRULES</code> row.</p>
/// <p><code>interop-managed-alert</code> is one managed alert of a namespace, keyed by its numeric id (AD-13, AD-62, Story 24.17 Batch 1). It is namespace-scoped and has no
/// <code>IDRULES</code> row.</p>
/// <p><code>interop-rule-log</code> is a namespace's business rule log and <code>interop-process-log</code> its business process log, each keyed by the namespace's name, kept exactly, as
/// <code>interop-purge</code> is (AD-13, AD-62, Story 24.17 Batch 2). Both are namespace-scoped and have no <code>IDRULES</code> row.</p>
/// <p><code>interop-workflow-user</code> is one workflow user of a namespace, keyed by its name, kept exactly (AD-13, AD-62, Story 24.17 Batch 3a). It is namespace-scoped and has no
/// <code>IDRULES</code> row.</p>
/// <p><code>interop-workflow-role</code> is one workflow role of a namespace, keyed by its name, and <code>interop-workflow-member</code> one member of a role, keyed by the composite
/// <code>[Role, User]</code>, each part kept exactly (AD-13, AD-62, Story 24.17 Batch 3b). Both are namespace-scoped and have no <code>IDRULES</code> row.</p>
/// <p><code>interop-workflow-task</code> is one workflow task of a namespace, keyed by its numeric task id (AD-13, AD-62, Story 24.17 Batch 4). It is namespace-scoped and has no
/// <code>IDRULES</code> row, and it is not the instance's <code>task</code>.</p>
/// <p><code>cube</code> is one analytics cube of a namespace, keyed by its logical name, kept exactly (AD-13, AD-65, Story 20.11), and
/// <code>term-list</code> is one term list, keyed by its name. <code>term-list-entry</code> is one entry of a term list, keyed by the
/// composite <code>[TermList, Key]</code>, each part kept exactly. <code>folder-item</code> is one pivot, dashboard or other folder
/// item, keyed by its full name, folder and extension included, kept exactly. <code>listing-group</code> is one listing group, keyed by its
/// name, and <code>listing-group-listing</code> is one listing of a group, keyed by the composite <code>[ListingGroup, Name]</code>, each part kept
/// exactly (Story 24.11). <code>quality-measure</code> is one quality measure, keyed by its name, <code>quality-measure-element</code> is one element of a measure's group, keyed by the composite
/// <code>[QualityMeasure, Group, Name]</code>, and <code>quality-measure-meta</code> is one documentation item of a measure, keyed by <code>[QualityMeasure, Name]</code>, each part kept exactly (Story 24.12). <code>analytics-setting</code> is one analytics setting, keyed by its name, <code>analytics-worklist</code> is one worklist option, keyed by the composite <code>[Page, Panel, Class]</code>,
/// <code>analytics-runtime-variable</code> is one run-time variable and <code>analytics-user-icon</code> one user-defined icon, each keyed by its name, kept exactly (Story 24.13). <code>dashboard-widget</code> is one widget of a dashboard, keyed by the composite <code>[Dashboard, Position]</code>, and <code>pmml-model</code> one PMML model, keyed by the composite <code>[Class, Model]</code> (Story 24.14), and <code>pmml-definition</code> is one class that defines PMML models, keyed by its name, kept exactly (Story 24.14 Batch 3). Each is namespace-scoped and has no <code>IDRULES</code> row.</p>
/// <p><code>backup-task</code> is one backup task of the instance, keyed by its name, kept exactly (AD-13, Story 21.2); the instance's database
/// writes, which a freeze and a thaw act on, are the literal <code>SYSTEM</code> under it. <code>backup-database</code> is one database on the
/// backup database list, keyed by its name without regard to case. Each is instance-scoped.</p>
/// <p><code>startup-setting</code>, <code>memory-setting</code> and <code>compatibility-setting</code> are one setting of the instance's startup,
/// memory and compatibility configuration, keyed by its name, kept exactly (AD-13, Story 21.3). Each is instance-scoped and has no
/// <code>IDRULES</code> row. <code>sql-setting</code>, <code>sql-shell-setting</code>, <code>tsql-setting</code> and
/// <code>isql-setting</code> are one setting of the instance's SQL configuration, the SQL Shell's defaults and the TSQL and ISQL
/// compatibility settings, under the same rules (Story 21.4).</p>
/// <p><code>mirror</code> is one mirror of the instance, keyed by its name, kept exactly (AD-13, Story 21.12). It is instance-scoped and has no
/// <code>IDRULES</code> row; only the kernel's prohibited set names it.</p>
/// <p><code>system-ddl-mapping</code> and <code>user-ddl-mapping</code> are one mapping of a DDL type name to a datatype class, keyed by its
/// name, kept exactly (AD-13, Story 21.13). Each is instance-scoped and has no <code>IDRULES</code> row.</p>
/// <p><code>nls-default</code> is one NLS configured default of the instance, keyed by its name, and <code>locale</code> is one locale
/// definition, keyed by its name, each kept exactly (AD-13, Story 21.14). Each is instance-scoped and has no <code>IDRULES</code> row.</p>
/// <p><code>system-security-setting</code> is one system-wide security parameter of the instance, keyed by its name, kept exactly (AD-13,
/// Story 21.10). It is instance-scoped and has no <code>IDRULES</code> row.</p>
/// <p><code>phone-provider</code> is one mobile phone provider of the instance, keyed by its name, which the instance matches exactly
/// and so is kept exactly (AD-13, Story 21.10). It is instance-scoped and has no <code>IDRULES</code> row.</p>
/// <p><code>security-recommendation</code> is one recommendation of the Security advisor, keyed by its type, its element and its code,
/// each kept exactly, an element of one space being a type's general row (AD-13, Story 21.19). It is instance-scoped and has no
/// <code>IDRULES</code> row.</p>
/// <p><code>task-mail-setting</code> is one Task Manager email setting of the instance, keyed by its name, kept exactly (AD-13, Story 21.19). It is
/// instance-scoped and has no <code>IDRULES</code> row.</p>
/// <p><code>system-alerts</code> is the instance's system alert state, the singleton (AD-13, Story 21.20).</p>
/// <p><code>page-resource</code> is the custom resource of one classic portal page, keyed by the page's normalized class name, kept exactly (AD-13,
/// Story 21.37). It is instance-scoped and has no <code>IDRULES</code> row.</p>
/// <p><code>global</code> is one global of a namespace, keyed by its name without <code>^</code>, and <code>global-node</code> is one node of a
/// global, keyed by its canonical reference without an environment, each kept exactly (AD-13, Story 21.5). Each is namespace-scoped and has no
/// <code>IDRULES</code> row.</p>
/// <p><code>statement-index-entry</code> is one statement in a namespace's statement index, keyed by its hash, kept exactly (AD-13, Story 21.6); the
/// id <code>*</code> names the whole index. <code>sql-statement</code> is a statement that is running. <code>cached-query</code> is one cached
/// query, keyed by its class, <code>%sqlcq.&lt;namespace&gt;.cls&lt;n&gt;</code>, a table's cached queries by <code>Schema.Table</code>, or the
/// namespace's by <code>*</code>, each kept exactly. Each is namespace-scoped and has no <code>IDRULES</code> row.</p>
/// <p><code>sql-table</code> is one SQL table of a namespace, keyed by <code>Schema.Table</code>, and <code>sql-index</code> is one of its indices,
/// keyed by the composite <code>[Table, Map]</code>, each part kept exactly (AD-13, Story 21.25). <code>sql-schema</code> is one SQL schema,
/// keyed by its name, kept exactly. Each is namespace-scoped and has no <code>IDRULES</code> row.</p>
/// <p><code>sql-runtime-stat</code> is one module of a statement's SQL runtime statistics, keyed by the composite <code>[Routine, Cursor, Module]</code>,
/// each part kept exactly; the id <code>*</code> names the namespace's statistics. <code>sql-runtime-stats-setting</code> is one row of the
/// instance-wide collection setting, keyed by its name (AD-13, Story 21.26). The first is namespace-scoped, the second instance-scoped, and neither
/// has an <code>IDRULES</code> row.</p>
/// <p><code>sql-index-analysis</code> is one row of the SQL index analyzer's reports, keyed by the composite <code>[Report, Counter]</code>, each part kept
/// exactly; the id <code>*</code> names the namespace's analysis, which its three writes act on. It is namespace-scoped and has no <code>IDRULES</code> row
/// (AD-13, Story 21.27).</p>
/// <p><code>sql-field</code> is one field of a SQL table, keyed by the composite <code>[Table, Field]</code>, each part kept exactly; it is
/// namespace-scoped and has no <code>IDRULES</code> row (AD-13, Story 21.31).</p>
Class OcuPilot.Kernel.EntityType Extends %RegisteredObject
{

/// <p>The vocabulary, comma-separated and in no significant order. Lower-case with hyphens,
/// the same spelling shape route and area keys use, so a key is never confused with a class
/// name.</p>
Parameter TYPES = "web-application,rest-service,user,role,resource,service,ssl-configuration,x509-credential,ldap-configuration,wallet-collection,wallet-secret,oauth2-client-configuration,oauth2-server-definition,oauth2-resource-server,oauth2-server,oauth2-server-client,audit-event,audit-user-event,auditing-configuration,task,task-history-entry,process,lock,database,device,audit-record,application-error,log-entry,agent-definition,agent-switch,agent-policy,allowed-directory,screen-permission,namespace,web-session,background-task,global-mapping,routine-mapping,package-mapping,database-configuration,language-server,class,routine,journal-file,journal-file-database,journal-settings,journal-record,license-key,license-server,ecp-data-server,ecp-settings,ecp-ssl-connection,encryption-key-file,database-encryption-keys,data-element-encryption-keys,encryption-startup,docdb-database,sql-statement,authentication-options,superserver,mft-connection,production,pct-class-access,docdb-application,routine-application,production-item,production-item-setting,interop-queue,interop-message,interop-job,lookup-table,lookup-entry,business-partner,cube,term-list,term-list-entry,folder-item,listing-group,listing-group-listing,quality-measure,quality-measure-element,quality-measure-meta,analytics-setting,analytics-worklist,analytics-runtime-variable,analytics-user-icon,dashboard-widget,pmml-model,pmml-definition,backup-task,backup-database,startup-setting,memory-setting,compatibility-setting,sql-setting,sql-shell-setting,tsql-setting,isql-setting,mirror,system-ddl-mapping,user-ddl-mapping,nls-default,locale,locale-property,global,global-node,system-security-setting,phone-provider,security-recommendation,task-mail-setting,system-alerts,page-resource,default-setting,interop-credential,interop-schedule,interop-purge,interop-purge-setting,statement-index-entry,cached-query,sql-table,sql-index,sql-schema,interop-archive,interop-archive-setting,sql-field,interop-managed-alert,sql-runtime-stat,sql-runtime-stats-setting,interop-rule-log,interop-process-log,interop-workflow-user,interop-workflow-role,interop-workflow-member,sql-index-analysis,interop-workflow-task,sql-saved-query";

/// <p>Whether <var>pType</var> is one of the declared values. An empty string is <b>not</b>
/// known: a screen with no entity type declares the empty string and its descriptor is
/// exempted from this check by the registry, which is the one place that distinction is
/// made.</p>
ClassMethod IsKnown(pType As %String) As %Boolean
{
    If pType = "" Quit 0
    Quit $ListFind(..List(), pType) > 0
}

/// <p>The vocabulary as a <class>%List</class>, in declaration order.</p>
ClassMethod List() As %List
{
    Set tList = ""
    Set tRaw = ..#TYPES
    For tI = 1:1:$Length(tRaw, ",") {
        Set tValue = $Piece(tRaw, ",", tI)
        If tValue '= "" Set tList = tList _ $ListBuild(tValue)
    }
    Quit tList
}

/// <p>How many values the vocabulary holds. Exists so a test can pin the size without
/// re-spelling the list, which would be a second copy of it.</p>
ClassMethod Count() As %Integer
{
    Quit $ListLength(..List())
}

}
