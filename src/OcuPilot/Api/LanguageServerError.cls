/// <p>The external language server editor's codes (AD-39, Story 16.25): every
/// <code>LANGUAGESERVER.*</code> code the editor's rules and Save answer, and the one sentence each
/// carries. They live beside <class>OcuPilot.Api.Error</class> rather than in it because that class
/// holds the compiler's limit of 1,000 parameters (ERROR #5290), as
/// <class>OcuPilot.Api.DatabaseError</class> does; <method>OcuPilot.Api.Error.ReasonForViolation</method>
/// answers these codes through <method>ReasonFor</method>, so every caller still asks the one writer.
/// <parameter>OcuPilot.Api.Error.LANGUAGESERVERSTART</parameter>, the refused start, stays in that class
/// and is no violation.</p>
Class OcuPilot.Api.LanguageServerError Extends %RegisteredObject
{

/// <p>Envelope code: a server's create or edit broke one or more of the rules
/// <class>OcuPilot.Area.OsMgmt.LanguageServerRules</class> applies before the port is touched.
/// Rendered on the <parameter>OcuPilot.Api.Error.VALIDATIONFAILED</parameter> slug with every
/// violation in <code>detail.violations</code>.</p>
Parameter VALIDATION = "LANGUAGESERVER.VALIDATION";

Parameter REASONVALIDATION = "The external language server was refused.";

/// <p>Envelope code: an edit of a server that is running, whose type is not <code>Remote</code>.
/// Rendered on the <parameter>OcuPilot.Api.Error.CONFLICT</parameter> slug with 409 before anything
/// is sent. The sentence is the write tools' <code>RUNNINGREASON</code>, published once in
/// EXPERIENCE.md's Fixed strings.</p>
Parameter RUNNING = "LANGUAGESERVER.RUNNING";

Parameter REASONRUNNING = "This server is running. Stop it before changing or deleting it.";

/// <p>Violation code: no server name was supplied.</p>
Parameter NAMEREQUIRED = "LANGUAGESERVER.NAME.REQUIRED";

Parameter REASONNAMEREQUIRED = "Name the server.";

/// <p>Violation code: a name longer than 50 characters, <code>Config.Gateways</code>'s own bound, or
/// one holding a control character.</p>
Parameter NAMESHAPE = "LANGUAGESERVER.NAME.SHAPE";

Parameter REASONNAMESHAPE = "A server name is 1 to 50 characters, none of them a control character.";

/// <p>Violation code: a server already carries that name, compared with its case.</p>
Parameter NAMETAKEN = "LANGUAGESERVER.NAME.TAKEN";

Parameter REASONNAMETAKEN = "A server with this name already exists.";

/// <p>Violation code: an edit or a form read names a server this instance does not define. Rendered
/// at 404.</p>
Parameter NAMEABSENT = "LANGUAGESERVER.NAME.ABSENT";

Parameter REASONNAMEABSENT = "This instance has no external language server with that name.";

/// <p>Violation code: a create with no type.</p>
Parameter TYPEREQUIRED = "LANGUAGESERVER.TYPE.REQUIRED";

Parameter REASONTYPEREQUIRED = "Choose the server's type.";

/// <p>Violation code: a type <code>Config.Gateways</code> does not define, spelled with its case.</p>
Parameter TYPEUNKNOWN = "LANGUAGESERVER.TYPE.UNKNOWN";

Parameter REASONTYPEUNKNOWN = "The type is one of Remote, Java, XSLT, JDBC, ODBC, ML, .NET, Python or R.";

/// <p>Violation code: a create with no port.</p>
Parameter PORTREQUIRED = "LANGUAGESERVER.PORT.REQUIRED";

Parameter REASONPORTREQUIRED = "Give the server's port.";

/// <p>Violation code: a port that is not a whole number from 1 to 65535.</p>
Parameter PORTRANGE = "LANGUAGESERVER.PORT.RANGE";

Parameter REASONPORTRANGE = "The port is a whole number from 1 to 65535.";

/// <p>Violation codes: a timeout that is not a whole number of seconds from 2 to 300
/// (<code>Config.Gateways</code>'s <code>MINVAL</code> and <code>MAXVAL</code>).</p>
Parameter CONNECTIONTIMEOUTRANGE = "LANGUAGESERVER.CONNECTIONTIMEOUT.RANGE";

Parameter INITIALIZATIONTIMEOUTRANGE = "LANGUAGESERVER.INITIALIZATIONTIMEOUT.RANGE";

Parameter REASONTIMEOUTRANGE = "A timeout is a whole number of seconds from 2 to 300.";

/// <p>Violation codes: a resource or TLS configuration name longer than 64 characters, the vendor's
/// own bound.</p>
Parameter RESOURCELENGTH = "LANGUAGESERVER.RESOURCE.LENGTH";

Parameter SSLCONFIGURATIONSERVERLENGTH = "LANGUAGESERVER.SSLCONFIGURATIONSERVER.LENGTH";

Parameter SSLCONFIGURATIONCLIENTLENGTH = "LANGUAGESERVER.SSLCONFIGURATIONCLIENT.LENGTH";

Parameter REASONLENGTH = "At most 64 characters.";

/// <p>Violation codes: a file location, top-level (<code>LogFile</code>) or a <code>Custom</code>
/// member, which no caller sets (AD-21). The sentence is the form's read-only caption.</p>
Parameter PATH = "LANGUAGESERVER.PATH";

Parameter CUSTOMPATH = "LANGUAGESERVER.CUSTOM.PATH";

Parameter REASONPATH = "File locations are set on the classic portal's External Language Server page.";

/// <p>Violation code: a <code>Custom</code> member the server's type does not take.</p>
Parameter CUSTOMUNKNOWN = "LANGUAGESERVER.CUSTOM.UNKNOWN";

Parameter REASONCUSTOMUNKNOWN = "This server's type has no such setting.";

/// <p>Violation code: a .NET version outside <code>Config.Gateways</code>'s
/// <code>VALIDNETVERSIONS</code>.</p>
Parameter DOTNETVERSIONUNKNOWN = "LANGUAGESERVER.DOTNETVERSION.UNKNOWN";

Parameter REASONDOTNETVERSIONUNKNOWN = "The .NET version is one of N8.0, N9.0 or N10.0.";

/// <p>Every field-level violation code this class declares, as a <class>%List</class>, so a test
/// holds <method>ReasonFor</method> to the vocabulary without re-spelling either.</p>
ClassMethod ViolationCodes() As %List
{
    Quit $ListBuild(..#NAMEREQUIRED, ..#NAMESHAPE, ..#NAMETAKEN, ..#NAMEABSENT, ..#TYPEREQUIRED, ..#TYPEUNKNOWN, ..#PORTREQUIRED, ..#PORTRANGE, ..#CONNECTIONTIMEOUTRANGE, ..#INITIALIZATIONTIMEOUTRANGE, ..#RESOURCELENGTH, ..#SSLCONFIGURATIONSERVERLENGTH, ..#SSLCONFIGURATIONCLIENTLENGTH, ..#PATH, ..#CUSTOMPATH, ..#CUSTOMUNKNOWN, ..#DOTNETVERSIONUNKNOWN)
}

/// <p>The sentence a <code>LANGUAGESERVER.*</code> code carries, or <code>""</code> for a code this
/// class does not declare -- <code>LANGUAGESERVER.START</code> among them.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    If pCode = ..#VALIDATION Quit ..#REASONVALIDATION
    If pCode = ..#RUNNING Quit ..#REASONRUNNING
    If pCode = ..#NAMEREQUIRED Quit ..#REASONNAMEREQUIRED
    If pCode = ..#NAMESHAPE Quit ..#REASONNAMESHAPE
    If pCode = ..#NAMETAKEN Quit ..#REASONNAMETAKEN
    If pCode = ..#NAMEABSENT Quit ..#REASONNAMEABSENT
    If pCode = ..#TYPEREQUIRED Quit ..#REASONTYPEREQUIRED
    If pCode = ..#TYPEUNKNOWN Quit ..#REASONTYPEUNKNOWN
    If pCode = ..#PORTREQUIRED Quit ..#REASONPORTREQUIRED
    If pCode = ..#PORTRANGE Quit ..#REASONPORTRANGE
    If (pCode = ..#CONNECTIONTIMEOUTRANGE) || (pCode = ..#INITIALIZATIONTIMEOUTRANGE) Quit ..#REASONTIMEOUTRANGE
    If (pCode = ..#RESOURCELENGTH) || (pCode = ..#SSLCONFIGURATIONSERVERLENGTH) || (pCode = ..#SSLCONFIGURATIONCLIENTLENGTH) Quit ..#REASONLENGTH
    If (pCode = ..#PATH) || (pCode = ..#CUSTOMPATH) Quit ..#REASONPATH
    If pCode = ..#CUSTOMUNKNOWN Quit ..#REASONCUSTOMUNKNOWN
    If pCode = ..#DOTNETVERSIONUNKNOWN Quit ..#REASONDOTNETVERSIONUNKNOWN
    Quit ""
}

}
