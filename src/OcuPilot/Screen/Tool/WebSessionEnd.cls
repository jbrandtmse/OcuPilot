/// <p>The Web sessions list's end tool (AD-6, AD-51, AD-53): end one CSP session. Two callers reach
/// it: the list's End session row action through <class>OcuPilot.Api.ScreenAction</class>, and the
/// agent's proposal and confirmation. Both read the session fresh through the vendor's own
/// <code>WebSession</code> <code>LIST</code>, filtered to the one row whose <code>ID</code> equals
/// the id exactly, case included (<parameter>READROWKEYEXACT</parameter>): the endpoint has no
/// <code>GET</code>, and a session id is a mixed-case random string, so a case-folded compare could
/// find a different session.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>DELETE</code> takes the id as its query
/// and reads no body, so the tool admits no settable field and its field list is empty by
/// derivation (AD-3).</p>
/// <p><b>Its fingerprint covers the session's own state</b>: this session, for this user and this
/// application, in this preserve mode, served by this process. <code>Timeout</code> is left out
/// because every request the session serves moves it. <code>Application</code> is the
/// precondition, the field the kernel's own-session arm reads
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.IsOcuPilotSession</method>).</p>
/// <p><b>The write declares <code>%DB_IRISSYS:WRITE</code> beyond the list's pairs</b> (AD-8): the
/// vendor ends a session through <code>$$DeleteSession^%SYS.cspServer</code>, which refuses a caller
/// without it, so a caller without it is refused by name before any port call.</p>
/// <p>The vendor only marks the session; <class>OcuPilot.Port.AdminPort</class> waits for the
/// instance's own daemon to remove it before the write is reported made
/// (<parameter>OcuPilot.Port.AdminPort.AWAITEDDELETES</parameter>). A session the instance does not
/// hold is refused at the mint.</p>
Class OcuPilot.Screen.Tool.WebSessionEnd Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "webapp.sessions.end";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WebSessionList";

Parameter DESCRIPTION = "Propose ending one web session on this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Ending a session discards what its application kept for it, and its next request starts a new session. Name the session by its ID exactly as the web sessions list reports it, case included. A session OcuPilot is itself running in is refused.";

/// <p>The screen's own End session row action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "end";

/// <p>The fresh read: the vendor's session list, filtered to the row whose <code>ID</code> is the
/// id. The kernel sends the id as a query parameter too, which the vendor's list ignores.</p>
Parameter READTYPE = "LIST";

Parameter READROWKEY = "ID";

/// <p>A session id is compared exactly: two ids differing only in case are two sessions.</p>
Parameter READROWKEYEXACT As BOOLEAN = 1;

/// <p>What this tool's own list row answers, read off the vendor's <code>LIST</code> on this
/// build.</p>
Parameter READANSWERS = "ID,Username,Preserve,Application,Timeout,LicenseId,SesProcessId,AllowEndSession";

/// <p>The vendor's own delete request type, which answers 404 for an unknown id.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: an ended session is gone, and what its application kept for it with it.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter PRECONDITIONFIELD = "Application";

Parameter FINGERPRINTSUBJECT = "Username,Application,Preserve,SesProcessId";

/// <p>The rows the card lists as removed: the session as the fresh read describes it.</p>
Parameter REMOVALROWS = "Username,Application,SesProcessId,Timeout";

/// <p>The pair the write needs beyond the list's own (AD-8).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

ClassMethod Endpoint() As %String
{
    Quit "WebSession"
}

/// <p>The list's row key.</p>
ClassMethod IdArgument() As %String
{
    Quit "ID"
}

/// <p>The vendor's own query parameter for the session to end.</p>
ClassMethod IdParam() As %String
{
    Quit "id"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property's description replaced.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The session to end, by its ID copied exactly as this instance's own web sessions list reports it, case included: two IDs that differ only in case are two different sessions. A session the list does not report is refused.", "string")
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>The removal rows this proposal's card shows, from the fresh list row <var>pFresh</var>: one
/// per <parameter>REMOVALROWS</parameter> name, carrying the value the instance holds and no
/// after-state. A row that answered no <parameter>PRECONDITIONFIELD</parameter> is
/// <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "unassigned") {
            Set pProblem = "this instance did not report which application that session belongs to, and a session whose application is unknown is not one to end"
            Quit
        }
        Set tNames = $ListFromString(..#REMOVALROWS)
        For tI = 1:1:$ListLength(tNames) {
            Set tField = $List(tNames, tI)
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField)), "string")
            Do tRow.%Set("after", "", "string")
            Do tRow.%Set("removed", 1, "boolean")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
