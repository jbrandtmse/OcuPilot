/// <p>Allowed directories' add, change and remove (AD-21's tenth case, AD-51, AD-52, AD-53, Story 18.42): one
/// action-style write of an entry of the instance's directory allow-list, the purpose
/// <code>%GUIFileSelector</code>, through <class>OcuPilot.Port.AllowListPort</class>. <code>Action</code> names the
/// change, <code>Directory</code> the entry and <code>NewDirectory</code> a change's replacement; the port composes the
/// vendor's calls and sends no body.</p>
/// <p><b>It is unadvertised and the agent's never</b> (<parameter>ADVERTISED</parameter> 0, AD-53's fourth named case):
/// the list is the fence around every server path the product reads or writes, so the provider's tool list, the dispatch
/// lookup, the screen context's tools and the discovery tool never carry it, and
/// <class>OcuPilot.Kernel.Proposal.Prohibited</class> refuses any write of the target through a tool the agent can
/// reach. Its one caller is <code>POST /allowed-directories</code>
/// (<class>OcuPilot.Area.Security.AllowedDirectorySave</class>), which asks its governance key, shipped disabled, so it
/// declares no <parameter>OcuPilot.Screen.Tool.Write.SCREENACTIONS</parameter>.</p>
/// <p><b>The fresh read is the port's <code>GET</code></b>, composed from the change at every caller
/// (<parameter>READSVALUES</parameter>, <method>PortQuery</method>): a change the matrix refuses is refused with its
/// <code>ALLOWLIST.*</code> code before anything is sent, and the read answers the roots the change would leave in
/// <code>Result</code>, which <method>StateDiff</method> shows against <code>Roots</code>. After the write that same
/// read refuses with <code>LISTED</code> or <code>NOTLISTED</code>, which <method>PreconditionCodes</method> names, so
/// its read-back says nothing was sent.</p>
/// <p><b>It is destructive</b>: narrowing the list takes a directory away from every path field. The caller holds the
/// screen's own pairs (<method>PrivilegePairs</method>); the port's gate repeats them.</p>
Class OcuPilot.Screen.Tool.AllowedDirectoryUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.alloweddirectories.update";

Parameter DESCRIPTION = "Add, change or remove an allowed directory. Only a person edits the list, from the Allowed directories screen; the agent never does.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AllowedDirectoryList";

/// <p>Reached by the screen's route alone (AD-53).</p>
Parameter ADVERTISED As BOOLEAN = 0;

/// <p>The port that reads the list, composes the vendor's calls and judges the change (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.AllowListPort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

/// <p>No body: the port composes the calls (<parameter>OcuPilot.Port.AllowListPort.COMPOSEDTYPES</parameter>).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The fresh read is composed from the write's own values (<method>PortQuery</method>).</p>
Parameter READSVALUES As BOOLEAN = 1;

Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The label the one row of the change carries.</p>
Parameter STATEFIELD = "Roots";

/// <p>What the fresh read answers that the subject names: the list's flag, what it stores, what it allows and what the
/// change would leave.</p>
Parameter READANSWERS = "Purpose,Restricted,Paths,Roots,Action,Directory,NewDirectory,Result";

Parameter PRECONDITIONFIELD = "Paths";

Parameter FINGERPRINTSUBJECT = "Restricted,Paths";

Parameter READBACKFIELDS = "Roots";

/// <p>The pair the write names: the allow-list's own, which the screen declares (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_FileSystemAccess";

Parameter WRITEPERMISSION = "USE";

/// <p>The value names, in the order the schema lists them.</p>
Parameter ACTIONARGUMENT = "Action";

Parameter DIRECTORYARGUMENT = "Directory";

Parameter NEWDIRECTORYARGUMENT = "NewDirectory";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AllowListPort).#ENDPOINT
}

/// <p>The target is the one allow-list, named by its purpose (AD-13).</p>
ClassMethod IdArgument() As %String
{
    Quit "Purpose"
}

ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.AllowListPort).#PURPOSEKEY
}

/// <p>The refusals the port's composed read answers with once the change has run (AD-51).</p>
ClassMethod PreconditionCodes() As %List
{
    Quit ##class(OcuPilot.Port.AllowListPort).PreconditionCodes()
}

/// <p>The arguments the write sets.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#ACTIONARGUMENT, ..#DIRECTORYARGUMENT, ..#NEWDIRECTORYARGUMENT)
}

/// <p>The identifying property described and the three values added: the action, required, the directory, required,
/// and a change's replacement.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The target is the instance's one allow-list, so send the literal '" _ ##class(OcuPilot.Port.PathPort).#PURPOSE _ "'.", "string")
    Do tProperties.%Set(..#ACTIONARGUMENT, {"type": "string", "enum": ["add", "change", "remove"], "description": "What to do with the entry: add it, change it to another directory, or remove it."})
    Do tProperties.%Set(..#DIRECTORYARGUMENT, {"type": "string", "description": "The directory: an absolute path on the server. For a change, the entry to replace."})
    Do tProperties.%Set(..#NEWDIRECTORYARGUMENT, {"type": "string", "description": "The directory a change replaces the entry with. Only a change names it."})
    Do tSchema.%Get("required").%Push(..#ACTIONARGUMENT)
    Do tSchema.%Get("required").%Push(..#DIRECTORYARGUMENT)
    Quit tSchema
}

/// <p>The change under the port's query keys, from the call's arguments, a route's values or the stored payload, so the
/// read and the write name one change.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    For tName = ..#ACTIONARGUMENT, ..#DIRECTORYARGUMENT, ..#NEWDIRECTORYARGUMENT {
        If (pPayload.%GetTypeOf(tName) = "string") && (pPayload.%Get(tName) '= "") Set pQuery(tName) = pPayload.%Get(tName)
    }
}

/// <p>The card's one row, <code>Roots: &lt;allowed now&gt; &#8594; &lt;allowed after the change&gt;</code>, from the
/// composed read <var>pFresh</var>. A read that answered neither list is <var>pProblem</var>, since a fence nobody read
/// is not one to change.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Roots") '= "array") || (pFresh.%GetTypeOf("Result") '= "array") {
            Set pProblem = "this instance did not report its allowed directories"
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", ..Joined(pFresh.%Get("Roots")), "string")
        Do tRow.%Set("after", ..Joined(pFresh.%Get("Result")), "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The strings of <var>pArray</var> joined with a comma and a space.</p>
ClassMethod Joined(pArray As %DynamicArray) As %String
{
    Set tText = ""
    If '$IsObject(pArray) Quit tText
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        Set tText = tText _ $Select(tText = "": "", 1: ", ") _ tValue
    }
    Quit tText
}

/// <p>The screen's own pairs (AD-8). The write names no pair beyond them: the list's own,
/// <parameter>WRITERESOURCE</parameter>, is one of them.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
}

}
