/// <p>ECP data servers' Change status (AD-51, AD-53, Story 18.20): set one data server to Not connected,
/// Disabled or Normal through the vendor's <code>ECP.DataServer</code> <code>SERVERACTION</code>, which
/// the vendor queues (AD-26). <class>OcuPilot.Port.EcpPort</class> builds <code>{Action}</code> from the
/// tool's one argument, <parameter>ARGUMENT</parameter>, carried in the port query
/// (<method>PortQuery</method>); the screen's status dialog sends it as its one value
/// (<parameter>SCREENVALUES</parameter>).</p>
/// <p><b>Its fresh read is the data server's <code>LIST</code> row</b>, whose <code>Status</code> is the
/// precondition. The mint refuses a status equal to the row's own and Normal while the license enables
/// no ECP, so no such proposal is stored; the port refuses both again at the write, on both callers.
/// Its card's one row is the merge's (<method>MergeUpdate</method>).</p>
/// <p><b>Its pairs</b> are the screen's and <parameter>POLLRESOURCE</parameter>, the
/// <code>AsyncResult</code> gate the port polls the queued change through (AD-8), then the classic
/// dialog's custom resource (AD-44). A change past the port's bound has started (AD-26). No vendor
/// event records it with auditing on (AD-15, AD-53).</p>
Class OcuPilot.Screen.Tool.EcpDataServerChangeStatus Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.ecpdataservers.changestatus";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EcpDataServerList";

Parameter DESCRIPTION = "Propose a new status for one ECP data server: notconnected, disabled or normal. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the server as the ECP data servers list reports it. Not connected and Disabled send an error to every application awaiting the server's replies and roll back its transactions; Normal connects this instance to it and needs a license that includes ECP. A status equal to the current one is refused.";

/// <p>The port that builds the action's body and sequences its checks (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.EcpPort";

/// <p>The data server's <code>LIST</code> row, found by its name (AD-51 as amended 2026-09-23).</p>
Parameter READTYPE = "LIST";

Parameter READROWKEY = "Name";

Parameter WRITETYPE = "SERVERACTION";

/// <p>No body of the tool's: the port builds <code>{Action}</code> (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>Declared: Not connected and Disabled error every pending reply and roll back the server's
/// transactions, which no later status undoes.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The row action the ECP data servers list's Change status carries out (AD-53).</p>
Parameter SCREENACTIONS = "changestatus";

/// <p>The status dialog sends its choice as this tool's one argument (AD-56 (ii)).</p>
Parameter SCREENVALUES = "changestatus=Status";

/// <p>The one argument: the status to set.</p>
Parameter ARGUMENT = "Status";

/// <p>What <parameter>READTYPE</parameter>'s row answers that the card and the precondition read.</p>
Parameter READANSWERS = "Status,RemoteAddress,RemotePort";

Parameter PRECONDITIONFIELD = "Status";

Parameter FINGERPRINTSUBJECT = "Status";

/// <p>The pair the port's poll of the queued change needs: the <code>AsyncResult</code> endpoint's own
/// <code>ResourcesOR()</code> (AD-8's endpoint clause, measured at Story 18.20's Task 0).</p>
Parameter POLLRESOURCE = "%Admin_Operate";

Parameter POLLPERMISSION = "USE";

/// <p>The classic dialog whose operation this tool performs beyond the list's own (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.ECPDataServer";

/// <p>The consequence code for Not connected and Disabled, which the client maps to the classic
/// warning.</p>
Parameter CONSEQUENCEDISCONNECT = "ECP.STATUS.DISCONNECT";

/// <p>The consequence code for Normal.</p>
Parameter CONSEQUENCECONNECT = "ECP.STATUS.CONNECT";

ClassMethod Endpoint() As %String
{
    Quit "ECP.DataServer"
}

/// <p><parameter>ARGUMENT</parameter> alone: the tool sends no body, so its field list is empty by
/// derivation (AD-3), and its one argument reaches the port through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#ARGUMENT)
}

/// <p>The identifying property described, and <parameter>ARGUMENT</parameter> added, required, as an
/// enum of the port's statuses (<method>OcuPilot.Port.EcpPort.Statuses</method>).</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The data server whose status changes, as this instance's ECP data servers list reports it. A server this instance does not define is refused.", "string")
    Set tEnum = []
    Set tStatuses = ##class(OcuPilot.Port.EcpPort).Statuses()
    For tI = 1:1:$ListLength(tStatuses) Do tEnum.%Push($List(tStatuses, tI), "string")
    Set tStatus = {"type": "string", "description": "The status to set: notconnected, disabled or normal. It must differ from the current one."}
    Do tStatus.%Set("enum", tEnum)
    Do tProperties.%Set(..#ARGUMENT, tStatus)
    Do tSchema.%Get("required").%Push(..#ARGUMENT)
    Quit tSchema
}

/// <p>The stored payload's <parameter>ARGUMENT</parameter> under the port's own query key (AD-52).
/// <var>pPayload</var> may also be the caller's arguments, which carry the same name.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#ARGUMENT) '= "string" Quit
    Set pQuery(##class(OcuPilot.Port.EcpPort).#STATUSQUERY) = pPayload.%Get(..#ARGUMENT)
}

/// <p>The dialog's choice as this tool's argument (AD-56 (ii)): one of the port's statuses, in lower
/// case; any other value is <var>pProblem</var>.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    Set tValue = ""
    If $IsObject(pValues) && (pValues.%GetTypeOf(..#ARGUMENT) = "string") Set tValue = $ZConvert(pValues.%Get(..#ARGUMENT), "L")
    If ##class(OcuPilot.Port.EcpPort).ActionFor(tValue) = "" {
        Set pProblem = ..StatusProblem()
        Quit $$$OK
    }
    Do pArgs.%Set(..#ARGUMENT, tValue, "string")
    Quit $$$OK
}

/// <p>The refusal of a status outside the port's three.</p>
ClassMethod StatusProblem() As %String
{
    Quit "'" _ ..#ARGUMENT _ "' is one of " _ $ListToString(##class(OcuPilot.Port.EcpPort).Statuses(), ", ")
}

/// <p>The card's one row, <code>Status: &lt;current&gt; &#8594; &lt;requested label&gt;</code>, over the
/// fresh <code>LIST</code> row <var>pFresh</var>, and the payload, the row with
/// <parameter>ARGUMENT</parameter> set to the requested status, which the fingerprint subject narrows
/// to it. A requested status equal to the row's own is <var>pProblem</var>
/// (<method>OcuPilot.Area.OsMgmt.EcpRules.StatusProblem</method>), at the mint and at the confirm's
/// re-merge, which then closes the proposal as target-changed.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ""
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tRequested = ""
        If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#ARGUMENT) = "string") Set tRequested = $ZConvert(pArgs.%Get(..#ARGUMENT), "L")
        Set tLabel = ##class(OcuPilot.Port.EcpPort).LabelFor(tRequested)
        If tLabel = "" {
            Set pProblem = ..StatusProblem()
            Quit
        }
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#ARGUMENT) '= "string") {
            Set pProblem = "this instance did not report that data server's status, and a server whose status is unknown is not one to change"
            Quit
        }
        Set tCurrent = pFresh.%Get(..#ARGUMENT)
        If tCurrent = tLabel {
            Set pProblem = ##class(OcuPilot.Area.OsMgmt.EcpRules).StatusProblem("same")
            Quit
        }
        Set pPayload = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%ToJSON())
        Do pPayload.%Set(..#ARGUMENT, tRequested, "string")
        Set tRow = {}
        Do tRow.%Set("field", ..#ARGUMENT, "string")
        Do tRow.%Set("before", tCurrent, "string")
        Do tRow.%Set("after", tLabel, "string")
        Do pDiff.%Push(tRow)
    } Catch ex {
        Set pPayload = ""
        Set pDiff = []
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Normal refused while this tool's port answers that the license enables no ECP
/// (<method>OcuPilot.Area.OsMgmt.EcpRules.StatusProblem</method>), so no such proposal is minted.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tRequested = ""
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#ARGUMENT) = "string") Set tRequested = $ZConvert(pArgs.%Get(..#ARGUMENT), "L")
    If (tRequested = ##class(OcuPilot.Port.EcpPort).#NORMALSTATUS) && '$ClassMethod(..#PORTCLASS, "NetworkEnabled") {
        Set pProblem = ##class(OcuPilot.Area.OsMgmt.EcpRules).StatusProblem("license")
    }
    Quit $$$OK
}

/// <p>No state row: the merge's row is the card's.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p><parameter>CONSEQUENCECONNECT</parameter> for Normal, and <parameter>CONSEQUENCEDISCONNECT</parameter>
/// for every other status.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Set tStatus = ""
    If $IsObject(pPayload) && (pPayload.%GetTypeOf(..#ARGUMENT) = "string") Set tStatus = $ZConvert(pPayload.%Get(..#ARGUMENT), "L")
    If tStatus = ##class(OcuPilot.Port.EcpPort).#NORMALSTATUS Quit ..#CONSEQUENCECONNECT
    Quit ..#CONSEQUENCEDISCONNECT
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>POLLRESOURCE</parameter>:<parameter>POLLPERMISSION</parameter>, then the custom resource
/// of the <parameter>CLASSICPAGES</parameter> dialog, each pair once (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#POLLRESOURCE, ..#POLLPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
