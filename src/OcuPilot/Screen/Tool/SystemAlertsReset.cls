/// <p>System alerts' Reset (Story 21.20, AD-6, AD-51, AD-52, AD-53, AD-58): set the instance's alert count to 0
/// and its system state to OK, through the harvested alerts body behind
/// <class>OcuPilot.Port.MonitorPort</class>. The agent reaches it through a proposal the user confirms; System
/// alerts reaches it through its <code>reset</code> row action. <code>alerts.log</code> is never truncated.</p>
/// <p>Its target is the literal <parameter>FIXEDID</parameter>, the instance's alert state, as
/// <class>OcuPilot.Screen.Tool.BackupFreeze</class>'s is its write state; any other id is refused for the agent.
/// <b>It is action-style</b> (AD-51): no settable field and no body. Its card moves the alert count to 0 and the
/// state text to OK, and its fingerprint covers the state, the count and the last alert, so a confirm after the
/// alerts moved is refused. It is not destructive: it clears a counter and keeps every log line.</p>
Class OcuPilot.Screen.Tool.SystemAlertsReset Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.systemalerts.reset";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SystemAlertsList";

Parameter DESCRIPTION = "Propose resetting the system alerts: the alert count goes to 0 and the system state to OK, and alerts.log keeps every entry. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal 'SYSTEM' as the target.";

Parameter SCREENACTIONS = "reset";

/// <p>The port every alert write reaches its target through (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.MonitorPort";

/// <p>The port endpoint this tool reads and writes.</p>
Parameter ENDPOINTNAME = "Alerts";

/// <p>The port's single-object read.</p>
Parameter READTYPE = "GET";

Parameter WRITETYPE = "RESET";

/// <p>No body: the port sends its own fixed one to the harvested body (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>The one id every caller names the target by.</p>
Parameter FIXEDID = "SYSTEM";

Parameter READANSWERS = "State,StateText,AlertCount,LastAlert";

Parameter PRECONDITIONFIELD = "AlertCount";

/// <p>Everything the card lists is covered, so that no card row is read as a change of its own (AD-51).</p>
Parameter FINGERPRINTSUBJECT = "State,StateText,AlertCount,LastAlert";

/// <p>The pair the write itself names, beyond the screen's own
/// (<parameter>OcuPilot.Port.MonitorPort.WRITEPAIRS</parameter>).</p>
Parameter WRITERESOURCE = "%Admin_Manage";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit ..#ENDPOINTNAME
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The identifying property described: the one literal id.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "Send the literal 'SYSTEM': a reset acts on all of the instance's system alerts. Any other value is refused.", "string")
    Quit tSchema
}

/// <p>The agent's arguments refused before anything is stored (AD-55): an id other than
/// <parameter>FIXEDID</parameter>.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If pIdValue '= ..#FIXEDID Set pProblem = "'" _ ..IdArgument() _ "' must be the literal '" _ ..#FIXEDID _ "': this acts on all of the instance's system alerts"
    Quit $$$OK
}

/// <p>What the caller must hold: the screen's own pairs, then
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter> where the set lacks it (AD-8).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit tPairs
}

/// <p>The two rows this proposal's card shows, from the fresh read <var>pFresh</var>: <code>AlertCount</code>
/// moving to 0 and <code>StateText</code> moving to OK. A read that answers no <code>AlertCount</code> is
/// <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) = "unassigned") {
            Set pProblem = "this instance did not report its alert count, and an alert state it cannot read is not one to reset"
            Quit
        }
        Set tCount = {}
        Do tCount.%Set("field", "AlertCount", "string")
        Do tCount.%Set("before", pFresh.%Get("AlertCount") _ "", "string")
        Do tCount.%Set("after", "0", "string")
        Do pRows.%Push(tCount)
        Set tState = {}
        Do tState.%Set("field", "StateText", "string")
        Do tState.%Set("before", pFresh.%Get("StateText") _ "", "string")
        Do tState.%Set("after", "OK", "string")
        Do pRows.%Push(tState)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
