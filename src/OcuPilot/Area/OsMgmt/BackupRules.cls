/// <p>The backup screens' refusals (AD-29, AD-51, AD-55, Story 21.2): which write may not run against the target's
/// state, as one code from <class>OcuPilot.Api.BackupError</class>, before any vendor call. Two callers ask the
/// same question: the write tools' mint (<method>WriteProblem</method>), which phrases it for the person or the agent,
/// and <class>OcuPilot.Port.BackupPort</class>, which asks it again at the write for the confirm and for a screen's
/// action alike (<method>Code</method>).</p>
/// <p><b>The state is the port's own read</b> of the target (<code>GET</code>): a task's row with
/// <code>AnyRunning</code> and <code>WritesFrozen</code>, a database's <code>Listed</code>, the write state's <code>WriteState</code> and
/// <code>Clustered</code>. Nothing here reads the instance.</p>
Class OcuPilot.Area.OsMgmt.BackupRules Extends %RegisteredObject
{

/// <p>The write types this class judges.</p>
Parameter RUN = "RUN";

Parameter FREEZE = "FREEZE";

Parameter THAW = "THAW";

Parameter ADD = "ADD";

Parameter REMOVE = "REMOVE";

/// <p>The query key a freeze's suspend limit travels under.</p>
Parameter LIMITKEY = "limit";

/// <p>The write state a frozen instance reads as.</p>
Parameter FROZENSTATE = "Frozen";

/// <p>Whether <var>pLimit</var> is a whole number of seconds from 1 to the port's
/// <code>FREEZELIMITMAX</code>, written without a sign, a leading zero or a fraction.</p>
ClassMethod LimitHolds(pLimit As %String) As %Boolean
{
    If '$Match(pLimit, "^[1-9][0-9]{0,8}$") Quit 0
    Quit (+pLimit <= ##class(OcuPilot.Port.BackupPort).#FREEZELIMITMAX)
}

/// <p>The code of the refusal the write <var>pWriteType</var> meets against the state <var>pState</var>, with the
/// arguments <var>pQuery</var>, or <code>""</code> when it may run. A freeze is judged on its limit first, then on
/// the state: writes already frozen, then the instance that would ignore the limit (<code>Clustered</code>). A run is
/// refused while any task runs, then while writes are frozen.</p>
ClassMethod Code(pWriteType As %String, pState As %DynamicObject, ByRef pQuery) As %String
{
    If pWriteType = ..#FREEZE {
        If '..LimitHolds($Get(pQuery(..#LIMITKEY))) Quit ##class(OcuPilot.Api.BackupError).#FREEZELIMIT
        If ..Text(pState, "WriteState") = ..#FROZENSTATE Quit ##class(OcuPilot.Api.BackupError).#FROZEN
        If ..Flag(pState, "Clustered") Quit ##class(OcuPilot.Api.BackupError).#FREEZEUNBOUNDED
        Quit ""
    }
    If pWriteType = ..#THAW {
        If ..Text(pState, "WriteState") '= ..#FROZENSTATE Quit ##class(OcuPilot.Api.BackupError).#NOTFROZEN
        Quit ""
    }
    If pWriteType = ..#RUN {
        If ..Flag(pState, "AnyRunning") Quit ##class(OcuPilot.Api.BackupError).#RUNNING
        ; The vendor refuses a backup while writes are frozen (#7309, measured), so the run is refused before it.
        If ..Flag(pState, "WritesFrozen") Quit ##class(OcuPilot.Api.BackupError).#FROZEN
        Quit ""
    }
    If pWriteType = ..#ADD {
        If ..Flag(pState, "Listed") Quit ##class(OcuPilot.Api.BackupError).#LISTCONFLICT
        Quit ""
    }
    If pWriteType = ..#REMOVE {
        If '..Flag(pState, "Listed") Quit ##class(OcuPilot.Api.BackupError).#LISTCONFLICT
        Quit ""
    }
    Quit ""
}

/// <p>The agent's arguments refused by the write's rules against the target's state, before anything is stored
/// (AD-55): the target is read through the tool's own port and <method>Code</method> asks the question. A target the
/// port reports absent is its own refusal sentence; any other failed read is an error status.</p>
/// <p><var>pProblem</var> is the sentence, or <code>""</code> when the write may run.</p>
ClassMethod WriteProblem(pToolClass As %String, pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery($ClassMethod(pToolClass, "ReadIdParam")) = pIdValue
        Set tReadSC = $ClassMethod($ClassMethod(pToolClass, "PortClass"), "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .tState, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            If $IsObject($Get(tFault)) && (tFault.%Get("reason") '= "") && (tFault.%Get("code") '= ##class(OcuPilot.Api.Error).#INTERNAL) {
                Set pProblem = tFault.%Get("reason")
                Quit
            }
            Set tSC = tReadSC
            Quit
        }
        Kill tArgQuery
        Do $ClassMethod(pToolClass, "PortQuery", pArgs, .tArgQuery)
        Set tCode = ..Code($ClassMethod(pToolClass, "WriteType"), tState, .tArgQuery)
        If tCode '= "" Set pProblem = ##class(OcuPilot.Api.BackupError).ReasonFor(tCode)
    } Catch ex {
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><var>pObject</var>'s <var>pField</var> as text: absent, null, an object or an array as <code>""</code>.</p>
ClassMethod Text(pObject, pField As %String) As %String [ Private ]
{
    If '$IsObject(pObject) || 'pObject.%IsA("%Library.DynamicObject") Quit ""
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit pObject.%Get(pField) _ ""
}

/// <p>Whether <var>pObject</var>'s <var>pField</var> is true or 1.</p>
ClassMethod Flag(pObject, pField As %String) As %Boolean [ Private ]
{
    Set tText = ..Text(pObject, pField)
    Quit (tText = 1) || (tText = "true")
}

}
