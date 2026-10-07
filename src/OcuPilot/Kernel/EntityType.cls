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
/// <p><code>docdb-database</code> is one document database of a namespace, keyed by its name, which the
/// instance resolves in any case (AD-13, Story 19.17).</p>
/// <p><code>sql-statement</code> is one SQL statement running on the instance, keyed by the vendor's
/// composite of its server, process and statement hash; it names no write target (AD-13, Story
/// 19.10).</p>
/// <p><code>production</code> is one interoperability production of a namespace, keyed by its production
/// class name, kept exactly (AD-13, AD-62, Story 20.2). It is namespace-scoped: the route's namespace
/// is the entity's scope.</p>
Class OcuPilot.Kernel.EntityType Extends %RegisteredObject
{

/// <p>The vocabulary, comma-separated and in no significant order. Lower-case with hyphens,
/// the same spelling shape route and area keys use, so a key is never confused with a class
/// name.</p>
Parameter TYPES = "web-application,rest-service,user,role,resource,service,ssl-configuration,x509-credential,ldap-configuration,wallet-collection,wallet-secret,oauth2-client-configuration,oauth2-server-definition,oauth2-resource-server,oauth2-server,oauth2-server-client,audit-event,audit-user-event,auditing-configuration,task,task-history-entry,process,lock,database,device,audit-record,application-error,log-entry,agent-definition,agent-switch,agent-policy,allowed-directory,namespace,web-session,background-task,global-mapping,routine-mapping,package-mapping,database-configuration,language-server,class,routine,journal-file,journal-file-database,journal-settings,journal-record,license-key,license-server,ecp-data-server,ecp-settings,ecp-ssl-connection,encryption-key-file,database-encryption-keys,data-element-encryption-keys,encryption-startup,docdb-database,sql-statement,authentication-options,superserver,production";

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
