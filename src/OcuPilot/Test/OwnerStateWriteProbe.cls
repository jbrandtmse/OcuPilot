/// <p>The child process <class>OcuPilot.Test.StoreOwnerWrite</class> starts to call the agent
/// definition, proposal, ledger, turn and background run stores as a <b>real principal</b> (AD-8, AD-9). It adds the steps
/// those stores need to <class>OcuPilot.Test.AdminStateWriteProbe</class>, which logs in and runs a
/// plan; any step it does not name is the parent's.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.OwnerStateWriteProbe Extends OcuPilot.Test.AdminStateWriteProbe
{

/// <p>Whether <var>pKind</var> is a step this class or the parent class runs.</p>
ClassMethod Handles(pKind As %String) As %Boolean
{
    If $ListFind(..Kinds(), pKind) Quit 1
    Quit ##super(pKind)
}

/// <p>The steps this class adds, as <code>Store.Method</code>. <code>Agent.BaseSave</code>,
/// <code>Agent.BaseSaveIfCurrent</code> and <code>Propose.EditSave</code> open a row with the public
/// <code>GuardedOpenId</code>, change it and save it through <code>Base</code>'s public saves;
/// <code>Agent.GuardedClearVerification</code> with <code>holdEditedRow</code> first changes the
/// opened row's instructions in memory and holds it across the call;
/// <code>Ledger.ForgedOverflow</code> opens ledger row <code>id</code>, sets its
/// <code>UserName</code> to <code>heldUser</code> in memory and holds it across
/// <code>GuardedCountOverflow</code> for <code>user</code>; <code>Ledger.ForgedSave</code> opens it the
/// same way and saves it through <code>Base.GuardedSave</code>; <code>Turn.GuardedAbandonForUser</code>,
/// <code>Turn.GuardedReserve</code> and <code>SqlRun.GuardedReserve</code> are the open paths the
/// stores keep for every caller; <code>Read.Agent</code> answers the definitions the principal
/// reads.</p>
ClassMethod Kinds() As %List
{
    Quit $ListBuild("Agent.GuardedCreate", "Agent.GuardedUpdate", "Agent.GuardedDeleteId", "Agent.SetDefaultGuarded", "Agent.GuardedSetVerification", "Agent.GuardedMarkCredentialCreated", "Agent.GuardedRebalanceDefault", "Agent.GuardedClearVerification", "Agent.BaseSave", "Agent.BaseSaveIfCurrent", "Propose.GuardedMint", "Propose.EditSave", "Propose.GuardedClose", "Propose.GuardedClaimAndClose", "Propose.GuardedDeleteForUser", "Propose.GuardedRecordReadBack", "Propose.GuardedCloseLiveForConvo", "Propose.GuardedCloseLiveForUser", "Propose.GuardedExpireStale", "Propose.GuardedRebuildTargetKeys", "Propose.GuardedDeleteForTurn", "Ledger.GuardedAppend", "Ledger.GuardedFinalize", "Ledger.GuardedCountOverflow", "Ledger.GuardedDeleteForTurn", "Ledger.GuardedDeleteForUser", "Ledger.GuardedPurgeBefore", "Ledger.ForgedOverflow", "Ledger.ForgedSave", "Turn.GuardedAbandonForUser", "Turn.GuardedReserve", "SqlRun.GuardedReserve", "Read.Agent")
}

/// <p>Run one step of the plan: the guarded call its <code>kind</code> names, with the arguments the
/// step carries, answered as <code>{kind, ok, code, text}</code> plus what the kind adds.</p>
ClassMethod Step(pStep As %DynamicObject) As %DynamicObject
{
    Set tKind = pStep.%Get("kind")
    If '$ListFind(..Kinds(), tKind) Quit ##super(pStep)
    Set tLeg = {}
    Set tSC = $$$OK
    Try {
        Kill tValues
        Set tAgent = "OcuPilot.Kernel.State.Agent"
        Set tPropose = "OcuPilot.Kernel.State.Propose"
        Set tLedger = "OcuPilot.Kernel.State.Ledger"
        If tKind = "Agent.GuardedCreate" {
            Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
            Set tRow.Name = pStep.%Get("name")
            Set tRow.Provider = "openai"
            Set tRow.Model = "probe-model-1"
            Set tRow.CredType = "env"
            Set tRow.EnvVarName = "OCUPILOT_PROBE_LOCAL_KEY"
            Set tRow.SystemPromptOverride = pStep.%Get("instructions")
            Set tRow.Enabled = 1
            Set tRow.ConnectionVerified = 1
            Set tSC = $ClassMethod(tAgent, "GuardedCreate", tRow)
            Set tRow = ""
        } ElseIf tKind = "Agent.GuardedUpdate" {
            Set tSC = $ClassMethod(tAgent, "GuardedOpenId", pStep.%Get("id"), .tRow)
            If $$$ISOK(tSC) {
                Do $ClassMethod(tAgent, "SnapshotSecurityFields", tRow, .tSnapshot)
                Set tRow.SystemPromptOverride = pStep.%Get("instructions")
                Set tSC = $ClassMethod(tAgent, "GuardedUpdate", tRow, .tSnapshot)
            }
            Set tRow = ""
        } ElseIf tKind = "Agent.GuardedDeleteId" {
            Set tSC = $ClassMethod(tAgent, "GuardedDeleteId", pStep.%Get("id"))
        } ElseIf tKind = "Agent.SetDefaultGuarded" {
            Set tSC = $ClassMethod(tAgent, "SetDefaultGuarded", pStep.%Get("id"))
        } ElseIf tKind = "Agent.GuardedSetVerification" {
            Set tSC = $ClassMethod(tAgent, "GuardedSetVerification", pStep.%Get("id"))
        } ElseIf tKind = "Agent.GuardedMarkCredentialCreated" {
            Set tSC = $ClassMethod(tAgent, "GuardedMarkCredentialCreated", pStep.%Get("id"))
        } ElseIf tKind = "Agent.GuardedRebalanceDefault" {
            Set tSC = $ClassMethod(tAgent, "GuardedRebalanceDefault")
        } ElseIf tKind = "Agent.GuardedClearVerification" {
            If pStep.%Get("holdEditedRow") {
                Set tSC = $ClassMethod(tAgent, "GuardedOpenId", pStep.%Get("id"), .tRow)
                If $$$ISOK(tSC) Set tRow.SystemPromptOverride = pStep.%Get("instructions")
            }
            If $$$ISOK(tSC) Set tSC = $ClassMethod(tAgent, "GuardedClearVerification", pStep.%Get("id"))
            Set tRow = ""
        } ElseIf (tKind = "Agent.BaseSave") || (tKind = "Agent.BaseSaveIfCurrent") {
            Set tSC = $ClassMethod(tAgent, "GuardedOpenId", pStep.%Get("id"), .tRow)
            If $$$ISOK(tSC) {
                Set tRow.SystemPromptOverride = pStep.%Get("instructions")
                Set tSC = ..SaveThroughBase(tRow, tKind = "Agent.BaseSave")
            }
            Set tRow = ""
        } ElseIf tKind = "Propose.GuardedMint" {
            Set tValues("user") = pStep.%Get("user")
            Set tValues("convKey") = pStep.%Get("convKey")
            Set tValues("turnKey") = pStep.%Get("turnKey")
            Set tValues("toolName") = "webapp.list.update"
            Set tValues("targetRef") = pStep.%Get("target")
            Set tValues("fingerprint") = "0"
            Set tValues("arguments") = "{}"
            Set tValues("payload") = "{}"
            Set tValues("diff") = "[]"
            Set tValues("unchangedCount") = 0
            Set tSC = $ClassMethod(tPropose, "GuardedMint", .tValues, "OcuPilot.Kernel.Agent.Limits", .tKey, .tToken, .tExpiresAt)
            Do tLeg.%Set("key", $Get(tKey), "string")
        } ElseIf tKind = "Propose.EditSave" {
            Set tSC = $ClassMethod(tPropose, "GuardedOpenId", pStep.%Get("id"), .tRow)
            If $$$ISOK(tSC) {
                Set tRow.Arguments = ..StreamOf(pStep.%Get("arguments"))
                Set tRow.Payload = ..StreamOf(pStep.%Get("payload"))
                Set tRow.Diff = ..StreamOf(pStep.%Get("diff"))
                Set tRow.Fingerprint = pStep.%Get("fingerprint")
                Set tSC = ..SaveThroughBase(tRow, pStep.%Get("via") = "save")
            }
            Set tRow = ""
        } ElseIf tKind = "Propose.GuardedClose" {
            Set tSC = $ClassMethod(tPropose, "GuardedClose", pStep.%Get("key"), pStep.%Get("user"), pStep.%Get("reason"), .tClosed)
            Do tLeg.%Set("closed", +$Get(tClosed), "number")
        } ElseIf tKind = "Propose.GuardedClaimAndClose" {
            Set tSC = $ClassMethod(tPropose, "GuardedClaimAndClose", pStep.%Get("key"), pStep.%Get("version"), pStep.%Get("target"), .tWon, .tTerminal)
            Do tLeg.%Set("won", +$Get(tWon), "number")
        } ElseIf tKind = "Propose.GuardedDeleteForTurn" {
            Set tSC = $ClassMethod(tPropose, "GuardedDeleteForTurn", pStep.%Get("turnKey"))
        } ElseIf tKind = "Propose.GuardedDeleteForUser" {
            Set tSC = $ClassMethod(tPropose, "GuardedDeleteForUser", pStep.%Get("user"))
        } ElseIf tKind = "Propose.GuardedRecordReadBack" {
            Set tSC = $ClassMethod(tPropose, "GuardedRecordReadBack", pStep.%Get("key"), {"verdict": "ok"})
        } ElseIf tKind = "Propose.GuardedCloseLiveForConvo" {
            Set tSC = $ClassMethod(tPropose, "GuardedCloseLiveForConvo", pStep.%Get("convKey"), pStep.%Get("user"), pStep.%Get("reason"), .tCount)
            Do tLeg.%Set("count", +$Get(tCount), "number")
        } ElseIf tKind = "Propose.GuardedCloseLiveForUser" {
            Set tSC = $ClassMethod(tPropose, "GuardedCloseLiveForUser", pStep.%Get("user"), pStep.%Get("reason"), .tCount)
            Do tLeg.%Set("count", +$Get(tCount), "number")
        } ElseIf tKind = "Propose.GuardedExpireStale" {
            Set tSC = $ClassMethod(tPropose, "GuardedExpireStale", pStep.%Get("user"))
        } ElseIf tKind = "Propose.GuardedRebuildTargetKeys" {
            Set tSC = $ClassMethod(tPropose, "GuardedRebuildTargetKeys", .tChanged)
        } ElseIf tKind = "Ledger.GuardedCountOverflow" {
            Set tSC = $ClassMethod(tLedger, "GuardedCountOverflow", pStep.%Get("turnKey"), pStep.%Get("user"), "", .tDropped)
            Do tLeg.%Set("dropped", +$Get(tDropped), "number")
        } ElseIf tKind = "Ledger.GuardedDeleteForTurn" {
            Set tSC = $ClassMethod(tLedger, "GuardedDeleteForTurn", pStep.%Get("turnKey"))
        } ElseIf tKind = "Ledger.GuardedPurgeBefore" {
            Set tSC = $ClassMethod(tLedger, "GuardedPurgeBefore", pStep.%Get("iso"), .tRemoved)
        } ElseIf tKind = "Ledger.ForgedOverflow" {
            Set tSC = $ClassMethod(tLedger, "GuardedOpenId", pStep.%Get("id"), .tRow)
            If $$$ISOK(tSC) {
                Set tRow.UserName = pStep.%Get("heldUser")
                Set tSC = $ClassMethod(tLedger, "GuardedCountOverflow", pStep.%Get("turnKey"), pStep.%Get("user"), "", .tDropped)
            }
            Set tRow = ""
        } ElseIf tKind = "Ledger.ForgedSave" {
            Set tSC = $ClassMethod(tLedger, "GuardedOpenId", pStep.%Get("id"), .tRow)
            If $$$ISOK(tSC) {
                Set tRow.UserName = pStep.%Get("heldUser")
                Set tSC = ..SaveThroughBase(tRow, 1)
            }
            Set tRow = ""
        } ElseIf tKind = "Turn.GuardedAbandonForUser" {
            Set tSC = $ClassMethod("OcuPilot.Kernel.State.Turn", "GuardedAbandonForUser", pStep.%Get("user"), .tCount)
            Do tLeg.%Set("count", +$Get(tCount), "number")
        } ElseIf tKind = "Turn.GuardedReserve" {
            Set tSC = $ClassMethod("OcuPilot.Kernel.State.Turn", "GuardedReserve", pStep.%Get("user"), "1", "lost", "OcuPilot.Kernel.Agent.Limits", .tKey, .tBusy, .tSweepStatus)
            Do tLeg.%Set("key", $Get(tKey), "string")
            Do tLeg.%Set("busy", ''$Get(tBusy), "boolean")
            Do tLeg.%Set("sweepOk", ''$$$ISOK($Get(tSweepStatus, $$$OK)), "boolean")
        } ElseIf tKind = "SqlRun.GuardedReserve" {
            Set tSC = $ClassMethod("OcuPilot.Kernel.State.SqlRun", "GuardedReserve", pStep.%Get("user"), $NAMESPACE, 10, "OcuPilot.Kernel.Agent.Limits", .tKey, .tBusyKey, .tFull, .tSweepStatus)
            Do tLeg.%Set("key", $Get(tKey), "string")
            Do tLeg.%Set("sweepOk", ''$$$ISOK($Get(tSweepStatus, $$$OK)), "boolean")
        } ElseIf tKind = "Ledger.GuardedAppend" {
            Set tSC = $ClassMethod(tLedger, "GuardedAppend", pStep.%Get("turnKey"), pStep.%Get("user"), "probe", "tool", "probe.forged", "", "", "", 0, "ok", "", 0, 0, "", "OcuPilot.Kernel.Agent.Limits", .tSeq, .tStored, 0, "", .tLedgerKey)
            Do tLeg.%Set("key", $Get(tLedgerKey), "string")
        } ElseIf tKind = "Ledger.GuardedFinalize" {
            Set tSC = $ClassMethod(tLedger, "GuardedFinalize", pStep.%Get("key"), "forged", "forged", "", "", 0, "", 0, "", "")
        } ElseIf tKind = "Ledger.GuardedDeleteForUser" {
            Set tSC = $ClassMethod(tLedger, "GuardedDeleteForUser", pStep.%Get("user"))
        } ElseIf tKind = "Read.Agent" {
            Set tSC = $ClassMethod(tAgent, "GuardedList", .tIds)
            Set tState = ""
            For tI = 1:1:+$Get(tIds) {
                If $$$ISERR($ClassMethod(tAgent, "GuardedOpenId", tIds(tI), .tRow)) Continue
                Set tState = tState _ "{" _ tRow.%Id() _ ":" _ tRow.Name _ "|" _ tRow.SystemPromptOverride _ "|e" _ tRow.Enabled _ "|v" _ tRow.ConnectionVerified _ "|m" _ tRow.DefaultMark _ "|c" _ tRow.CredentialCreated _ "|r" _ tRow.RowVersion _ "}"
                Set tRow = ""
            }
            Do tLeg.%Set("state", tState, "string")
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

/// <p>Save <var>pRow</var> through <code>Base</code>'s public save: the unconditional one when
/// <var>pPlain</var> is 1, the one conditional on the version the row carries otherwise.</p>
ClassMethod SaveThroughBase(pRow As OcuPilot.Kernel.State.Base, pPlain As %Boolean) As %Status
{
    If pPlain Quit ##class(OcuPilot.Kernel.State.Base).GuardedSave(pRow)
    Quit ##class(OcuPilot.Kernel.State.Base).GuardedSaveIfCurrent(pRow, pRow.RowVersion)
}

/// <p>A new character stream holding <var>pText</var>.</p>
ClassMethod StreamOf(pText As %String) As %Stream.GlobalCharacter
{
    Set tStream = ##class(%Stream.GlobalCharacter).%New()
    Do tStream.Write(pText)
    Quit tStream
}

}
