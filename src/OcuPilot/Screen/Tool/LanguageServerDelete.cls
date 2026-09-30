/// <p>External language servers' delete tool (AD-6, AD-8, AD-51, AD-53, Story 16.25): delete one
/// external language server's definition. Two callers reach it: the list's Delete row action through
/// <class>OcuPilot.Api.ScreenAction</class>, after its typed-name dialog, and the agent's proposal and
/// confirmation. It reads the server fresh through <class>OcuPilot.Port.LanguageServerPort</class>,
/// with its running state, and mints a proposal whose card names what is removed. It writes
/// nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor reads no body for <code>DELETE</code>, the tool
/// admits no settable field, and its query carries the name alone. Its fingerprint covers the
/// running state and the type, so a server started since the mint refuses the confirm.</p>
/// <p><b>A running server is refused</b> (<method>StateDiff</method>) unless it is <code>Remote</code>:
/// the vendor's delete of a running server answers 200 and leaves its process listening, which no
/// screen can then see or stop (measured on <code>ocupilot-ci</code>). A Python server's delete also
/// needs <code>%System_CallOut:USE</code>, which the port checks by name before the vendor call.</p>
Class OcuPilot.Screen.Tool.LanguageServerDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.languageservers.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LanguageServerList";

Parameter DESCRIPTION = "Propose deleting one external language server's definition from this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the server exactly as the external language servers list reports it; names are compared with their case. A running server is refused unless its type is Remote; stop it first.";

Parameter READTYPE = "GET";

/// <p>The vendor's own delete request type, which answers 404 for an absent server.</p>
Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted definition is gone, and OcuPilot keeps no copy to restore it from.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The row action the list's Delete carries out (AD-53).</p>
Parameter SCREENACTIONS = "delete";

/// <p>The port that completes the read with the running state and gates a Python delete
/// (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.LanguageServerPort";

/// <p>The top-level names <parameter>READTYPE</parameter> answers through the port: the vendor's
/// <code>ObjToJson</code> on this build, and the running state the port completes it with.</p>
Parameter READANSWERS = "BindToIPAddress,ConnectionTimeout,InitializationTimeout,LogFile,Port,Resource,Type,UseSharedMemory,SSLConfigurationServer,SSLConfigurationClient,VerifySSLHostName,Custom,CurrentlyRunning";

Parameter PRECONDITIONFIELD = "CurrentlyRunning";

Parameter FINGERPRINTSUBJECT = "CurrentlyRunning,Type";

/// <p>The rows the card lists: what the removed definition held.</p>
Parameter REMOVALROWS = "Type,Port";

/// <p>The pairs every language server write needs beyond the list's own
/// (<parameter>OcuPilot.Screen.Tool.LanguageServerCreate.MANAGERESOURCE</parameter>). The delete is
/// performed on the list's own classic page, so it declares no <code>CLASSICPAGES</code> (AD-44).</p>
Parameter MANAGERESOURCE = "%Admin_Manage";

Parameter MANAGEPERMISSION = "USE";

Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The refusal of a running server, the update's own sentence
/// (<parameter>OcuPilot.Screen.Tool.LanguageServerUpdate.RUNNINGREASON</parameter>), pinned equal to
/// <code>languageServerRefusalRunningEdit</code> by <file>ui/tools/self-protection.test.mjs</file>.</p>
Parameter RUNNINGREASON = "This server is running. Stop it before changing or deleting it.";

/// <p>The rules whose running test this tool shares with the edit.</p>
Parameter RULES = "OcuPilot.Area.OsMgmt.LanguageServerRules";

ClassMethod Endpoint() As %String
{
    Quit "LanguageServer"
}

ClassMethod IdArgument() As %String
{
    Quit "Name"
}

ClassMethod IdParam() As %String
{
    Quit "name"
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
    Do tProperties.%Get(..IdArgument()).%Set("description", "The external language server to delete, named exactly as this instance's own external language servers list reports it, case included. A server the list does not report is refused.", "string")
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs, then
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter> and
/// <parameter>MANAGERESOURCE</parameter>:<parameter>MANAGEPERMISSION</parameter>, each pair once
/// (AD-8).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    For tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION), $ListBuild(..#MANAGERESOURCE, ..#MANAGEPERMISSION) {
        If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    }
    Quit tPairs
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// <parameter>REMOVALROWS</parameter> name, carrying the value the instance holds and no after-state.
/// A running server that is not <code>Remote</code>, or a read that answered no boolean running state,
/// is <var>pProblem</var>: <parameter>RUNNINGREASON</parameter>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If $ClassMethod(..#RULES, "Running", pFresh) {
            Set pProblem = ..#RUNNINGREASON
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
