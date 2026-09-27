/// <p>Fixture: <class>OcuPilot.Test.LedgerGateProbe</class> whose <method>GateTurns</method>, once
/// it has answered, appends one more entry to the conversation it gated -- the owner's turn
/// finishing between the route's gate and its read of the rows -- so
/// <method>OcuPilot.Api.Transcripts.HandleRead</method>'s answer for an entry the gate never saw
/// can be driven in process. The gate itself is the shipped code.</p>
Class OcuPilot.Test.LedgerAppendProbe Extends OcuPilot.Test.LedgerGateProbe
{

/// <p>The turn key the appended entry carries.</p>
Parameter LATETURNKEY = "probetranscriptlate";

ClassMethod GateTurns(pCaller As %String, pSubject As %String, pConvKey As %String, pTurnKeys As %List, Output pReleased As %Boolean, Output pFailedPair As %String, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ##super(pCaller, pSubject, pConvKey, pTurnKeys, .pReleased, .pFailedPair, .pFault)
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate(pConvKey, pSubject, 5, .tLoadSC, .tConflict)
    If $IsObject(tConvo) {
        Set tSteps = [{"seq": 1, "kind": "tool", "name": "tasks.schedule.read", "status": "ok", "summary": "late", "text": ""}]
        Do ##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, "late message", "completed", "late reply", "", 0, tSteps, 0, "OcuPilot.Kernel.Agent.Limits", ..#LATETURNKEY, "", "{""route"":""tasks/schedule""}", "")
    }
    Set tConvo = ""
    Quit tSC
}

}
