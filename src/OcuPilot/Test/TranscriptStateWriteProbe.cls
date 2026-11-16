/// <p>The child process <class>OcuPilot.Test.TranscriptOwnerWrite</class> starts to call the turn,
/// step, navigation, conversation and entry stores as a <b>real principal</b> (AD-8, AD-9). It adds
/// the steps those stores need to <class>OcuPilot.Test.OwnerStateWriteProbe</class>; any step it does not
/// name is the parent's.</p>
/// <p>A step names the turn it writes as <code>"$reserved"</code> to mean the key the last
/// <code>Turn.GuardedReserve</code> of this process answered, and a step number as <code>"$announce"</code>,
/// <code>"$model"</code> or <code>"$tool"</code> to mean the sequence the last
/// <code>Step.GuardedAppend</code> with that <code>as</code> answered.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.TranscriptStateWriteProbe Extends OcuPilot.Test.OwnerStateWriteProbe
{

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>Whether <var>pKind</var> is a step this class or a parent class runs.</p>
ClassMethod Handles(pKind As %String) As %Boolean
{
    If $ListFind(..TranscriptKinds(), pKind) Quit 1
    Quit ##super(pKind)
}

/// <p>The steps this class adds, as <code>Store.Method</code>. <code>Turn.ForgedProgress</code> opens the
/// turn <code>key</code> names, sets its <code>UserName</code> to <code>heldUser</code> in memory and holds
/// it across <code>GuardedProgress</code>; <code>Turn.ForgedSave</code> saves it through
/// <code>Base.GuardedSave</code>. <code>Turn.SlotHeld</code> answers <code>held</code>: it asks the process that started the run, which
/// answers through <method>OcuPilot.Test.TranscriptOwnerWrite.RunAsWatched</method>, whether any process holds
/// <code>user</code>'s turn slot lock. <code>Convo.AppendEntry</code> appends through the conversation
/// <code>Convo.LoadOrCreate</code> last held (<code>hold</code>), or through the one
/// <code>Convo.GuardedOpenId</code> opens by <code>id</code>.</p>
ClassMethod TranscriptKinds() As %List
{
    Quit $ListBuild("Turn.GuardedBegin", "Turn.GuardedProgress", "Turn.GuardedAddDropped", "Turn.GuardedFinish", "Turn.GuardedRenew", "Turn.GuardedRequestStop", "Turn.GuardedReconcile", "Turn.GuardedForgetStarts", "Turn.GuardedSweepStarts", "Turn.GuardedSweep", "Turn.GuardedDelete", "Turn.ForgedProgress", "Turn.ForgedSave", "Turn.SlotHeld", "Step.GuardedAppend", "Step.GuardedUpdate", "Step.GuardedSnapshotText", "Step.GuardedFinishTool", "Step.GuardedDeleteForTurn", "Nav.GuardedRequest", "Nav.GuardedSettle", "Nav.GuardedDeleteForTurn", "Convo.LoadOrCreate", "Convo.AppendEntry", "Convo.GuardedDelete", "Convo.GuardedPurgeEmpty", "Entry.GuardedAppend", "Entry.GuardedDeleteForConvo", "Entry.GuardedPurge")
}

/// <p>Run one step of the plan, answered as the parent answers one.</p>
ClassMethod Step(pStep As %DynamicObject) As %DynamicObject
{
    Set tKind = pStep.%Get("kind")
    If '$ListFind(..TranscriptKinds(), tKind) {
        Set tLeg = ##super(pStep)
        If (tKind = "Turn.GuardedReserve") && tLeg.%Get("ok") Set ^||OcuPilotProbe("reserved") = tLeg.%Get("key")
        Quit tLeg
    }
    Set tLeg = {}
    Set tSC = $$$OK
    Try {
        Set tTurn = "OcuPilot.Kernel.State.Turn"
        Set tStep = "OcuPilot.Kernel.State.Step"
        Set tNav = "OcuPilot.Kernel.State.Nav"
        Set tConvo = "OcuPilot.Kernel.State.Convo"
        Set tEntry = "OcuPilot.Kernel.State.Entry"
        Set tKey = ..Value(pStep, "key")
        Set tUser = pStep.%Get("user")
        Set tLimits = ..#LIMITS
        If tKind = "Turn.GuardedBegin" {
            Set tSC = $ClassMethod(tTurn, "GuardedBegin", tKey, tUser, tLimits, .tBegun, .tStarted)
            Do tLeg.%Set("begun", +$Get(tBegun), "number")
        } ElseIf tKind = "Turn.GuardedProgress" {
            Set tSC = $ClassMethod(tTurn, "GuardedProgress", tKey, 7, 11, 13)
        } ElseIf tKind = "Turn.GuardedAddDropped" {
            Set tSC = $ClassMethod(tTurn, "GuardedAddDropped", tKey, .tDropped)
        } ElseIf tKind = "Turn.GuardedFinish" {
            Set tSC = $ClassMethod(tTurn, "GuardedFinish", tKey, tUser, "completed", "", "", "a reply", 0, tLimits)
        } ElseIf tKind = "Turn.GuardedRenew" {
            Set tSC = $ClassMethod(tTurn, "GuardedRenew", tKey)
        } ElseIf tKind = "Turn.GuardedRequestStop" {
            Set tSC = $ClassMethod(tTurn, "GuardedRequestStop", tKey, tUser, .tFound)
            Do tLeg.%Set("found", +$Get(tFound), "number")
        } ElseIf tKind = "Turn.GuardedReconcile" {
            Set tSC = $ClassMethod(tTurn, "GuardedReconcile", tUser, "lost", tLimits)
        } ElseIf tKind = "Turn.GuardedForgetStarts" {
            Set tSC = $ClassMethod(tTurn, "GuardedForgetStarts", tUser)
        } ElseIf tKind = "Turn.GuardedSweepStarts" {
            Set tSC = $ClassMethod(tTurn, "GuardedSweepStarts", tLimits)
        } ElseIf tKind = "Turn.GuardedSweep" {
            Set tSC = $ClassMethod(tTurn, "GuardedSweep", tLimits)
        } ElseIf tKind = "Turn.GuardedDelete" {
            Set tSC = $ClassMethod(tTurn, "GuardedDelete", tKey)
        } ElseIf (tKind = "Turn.ForgedProgress") || (tKind = "Turn.ForgedSave") {
            Set tSC = $ClassMethod(tTurn, "GuardedOpenId", pStep.%Get("id"), .tRow)
            If $$$ISOK(tSC) {
                Set tRow.UserName = pStep.%Get("heldUser")
                If tKind = "Turn.ForgedSave" {
                    Set tSC = ..SaveThroughBase(tRow, 1)
                } Else {
                    Set tSC = $ClassMethod(tTurn, "GuardedProgress", tKey, 7, 11, 13)
                }
            }
            Set tRow = ""
        } ElseIf tKind = "Turn.SlotHeld" {
            Do tLeg.%Set("held", ''..Ask("slot", tUser), "boolean")
        } ElseIf tKind = "Step.GuardedAppend" {
            Set tSC = $ClassMethod(tStep, "GuardedAppend", tKey, pStep.%Get("stepKind"), "probe.step", pStep.%Get("status"), "", "", "", tLimits, .tSeq, .tStored, "tasks/schedule")
            Do tLeg.%Set("seq", +$Get(tSeq), "number")
            If $$$ISOK(tSC) && (pStep.%Get("as") '= "") Set ^||OcuPilotProbe(pStep.%Get("as")) = tSeq
        } ElseIf tKind = "Step.GuardedUpdate" {
            Set tSC = $ClassMethod(tStep, "GuardedUpdate", tKey, ..Value(pStep, "seq"), "ok", "updated", "", "", tLimits)
        } ElseIf tKind = "Step.GuardedSnapshotText" {
            Set tSC = $ClassMethod(tStep, "GuardedSnapshotText", tKey, ..Value(pStep, "seq"), "a snapshot", tLimits)
        } ElseIf tKind = "Step.GuardedFinishTool" {
            Set tSC = $ClassMethod(tStep, "GuardedFinishTool", tKey, ..Value(pStep, "seq"), "probe.step", "ok", "", tLimits)
        } ElseIf tKind = "Step.GuardedDeleteForTurn" {
            Set tSC = $ClassMethod(tStep, "GuardedDeleteForTurn", tKey)
        } ElseIf tKind = "Nav.GuardedRequest" {
            Set tSC = $ClassMethod(tNav, "GuardedRequest", tKey, ..Value(pStep, "seq"), "tasks/schedule", "")
        } ElseIf tKind = "Nav.GuardedSettle" {
            Set tSC = $ClassMethod(tNav, "GuardedSettle", tKey, ..Value(pStep, "seq"), "opened", "", .tClaimed)
            Do tLeg.%Set("claimed", +$Get(tClaimed), "number")
        } ElseIf tKind = "Nav.GuardedDeleteForTurn" {
            Set tSC = $ClassMethod(tNav, "GuardedDeleteForTurn", tKey)
        } ElseIf tKind = "Convo.LoadOrCreate" {
            Set tConvoRow = $ClassMethod(tConvo, "LoadOrCreate", ..Value(pStep, "convKey"), tUser, 5, .tSC, .tConflict)
            If $IsObject(tConvoRow) {
                Do tLeg.%Set("convKey", tConvoRow.ConvKey, "string")
                Set ^||OcuPilotProbe("conv") = tConvoRow.ConvKey
                If pStep.%Get("hold") Set %OcuPilotTranscriptConvo = tConvoRow
            }
            Set tConvoRow = ""
        } ElseIf tKind = "Convo.AppendEntry" {
            If pStep.%Get("id") '= "" {
                Set tSC = $ClassMethod(tConvo, "GuardedOpenId", pStep.%Get("id"), .tHeld)
            } Else {
                Set tHeld = $Get(%OcuPilotTranscriptConvo)
            }
            If $$$ISOK(tSC) Set tSC = $ClassMethod(tConvo, "AppendEntry", tHeld, "a message", "completed", "a reply", "", 0, [], 0, tLimits, tKey)
            Set tHeld = ""
            Set %OcuPilotTranscriptConvo = ""
        } ElseIf tKind = "Convo.GuardedDelete" {
            Set %OcuPilotTranscriptConvo = ""
            Set tSC = $ClassMethod(tConvo, "GuardedDelete", ..Value(pStep, "convKey"))
        } ElseIf tKind = "Convo.GuardedPurgeEmpty" {
            Set tSC = $ClassMethod(tConvo, "GuardedPurgeEmpty", pStep.%Get("iso"), .tRemoved)
            Do tLeg.%Set("removed", +$Get(tRemoved), "number")
        } ElseIf tKind = "Entry.GuardedAppend" {
            Set tSC = $ClassMethod(tEntry, "GuardedAppend", ..Value(pStep, "convKey"), "a message", "completed", "a reply", "", 0, "[]", 0, tLimits)
        } ElseIf tKind = "Entry.GuardedDeleteForConvo" {
            Set tSC = $ClassMethod(tEntry, "GuardedDeleteForConvo", ..Value(pStep, "convKey"))
        } ElseIf tKind = "Entry.GuardedPurge" {
            Set tCutoffs = pStep.%Get("cutoff")
            Set tSC = $ClassMethod(tEntry, "GuardedPurge", .tCutoffs, .tRemoved)
            Do tLeg.%Set("removed", +$Get(tRemoved), "number")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Do tLeg.%Set("kind", tKind, "string")
    Do tLeg.%Set("ok", ''$$$ISOK(tSC), "boolean")
    Do tLeg.%Set("code", $Select($$$ISOK(tSC): "", 1: $Piece($System.Status.GetErrorCodes(tSC), ",", 1)), "string")
    Do tLeg.%Set("text", $Select($$$ISOK(tSC): "", 1: $System.Status.GetErrorText(tSC)), "string")
    Quit tLeg
}

}
