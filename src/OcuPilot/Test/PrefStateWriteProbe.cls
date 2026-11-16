/// <p>The child process <class>OcuPilot.Test.PrefOwnerWrite</class> and
/// <class>OcuPilot.Test.ReserveSweepWrite</class> start to call the preference, sharing, background run, turn
/// reserve and abandon writers as a <b>real principal</b> (AD-8, AD-9). It adds the steps those stores need to
/// <class>OcuPilot.Test.OwnerStateWriteProbe</class>; any step it does not name is the parent's.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.PrefStateWriteProbe Extends OcuPilot.Test.OwnerStateWriteProbe
{

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>Whether <var>pKind</var> is a step this class or a parent class runs.</p>
ClassMethod Handles(pKind As %String) As %Boolean
{
    If $ListFind(..PrefKinds(), pKind) Quit 1
    Quit ##super(pKind)
}

/// <p>The steps this class adds, as <code>Store.Method</code>. <code>Pref.BaseSave</code> and
/// <code>Pref.BaseSaveIfCurrent</code> open preference row <code>id</code> with the public
/// <code>GuardedOpenId</code>, change its value and save it through <code>Base</code>'s public saves.
/// <code>Pref.ForgedSetValue</code>, <code>Sharing.ForgedSetForUser</code> and <code>SqlRun.ForgedCancel</code>
/// open row <code>id</code>, set its <code>UserName</code> to <code>heldUser</code> in memory and hold it across
/// the store's writer for <code>user</code>. <code>Turn.ReserveWith</code> and <code>SqlRun.ReserveWith</code> reserve
/// with the limits class <code>limits</code>, first holding the other user's row <code>id</code> opened with the public
/// <code>GuardedOpenId</code> and changed in memory when <code>heldField</code> is set (<code>EndedAt</code>, or
/// <code>Namespace</code> for a run). <code>Turn.HeldAbandon</code> holds turn row <code>id</code> with its
/// <code>TurnKey</code> set to <code>heldKey</code> across <code>Turn.GuardedAbandonForUser</code>.</p>
ClassMethod PrefKinds() As %List
{
    Quit $ListBuild("Pref.GuardedAdd", "Pref.GuardedRemove", "Pref.GuardedClear", "Pref.GuardedTouch", "Pref.GuardedTrim", "Pref.DeleteAllGuarded", "Pref.GuardedDeleteForUser", "Pref.BaseSave", "Pref.BaseSaveIfCurrent", "Pref.ForgedSetValue", "Sharing.GuardedSetForUser", "Sharing.DeleteAllGuarded", "Sharing.GuardedDeleteForUser", "Sharing.ForgedSetForUser", "SqlRun.GuardedBegin", "SqlRun.GuardedFinish", "SqlRun.GuardedCancel", "SqlRun.GuardedSweep", "SqlRun.GuardedForgetUser", "SqlRun.ForgedCancel", "SqlRun.ReserveWith", "Turn.ReserveWith", "Turn.HeldAbandon")
}

/// <p>Run one step of the plan, answered as the parent answers one.</p>
ClassMethod Step(pStep As %DynamicObject) As %DynamicObject
{
    Set tKind = pStep.%Get("kind")
    If '$ListFind(..PrefKinds(), tKind) Quit ##super(pStep)
    Set tLeg = {}
    Set tSC = $$$OK
    Try {
        Set tPref = "OcuPilot.Kernel.State.Pref"
        Set tSharing = "OcuPilot.Kernel.State.Sharing"
        Set tRun = "OcuPilot.Kernel.State.SqlRun"
        Set tTurn = "OcuPilot.Kernel.State.Turn"
        Set tUser = pStep.%Get("user")
        If tKind = "Pref.GuardedAdd" {
            Set tSC = $ClassMethod(tPref, "GuardedAdd", tUser, pStep.%Get("prefKind"), pStep.%Get("name"), 20, .tAtLimit)
            Do tLeg.%Set("atLimit", +$Get(tAtLimit), "number")
        } ElseIf tKind = "Pref.GuardedRemove" {
            Set tSC = $ClassMethod(tPref, "GuardedRemove", tUser, pStep.%Get("prefKind"), pStep.%Get("name"))
        } ElseIf tKind = "Pref.GuardedClear" {
            Set tSC = $ClassMethod(tPref, "GuardedClear", tUser, pStep.%Get("prefKind"))
        } ElseIf tKind = "Pref.GuardedTouch" {
            Set tSC = $ClassMethod(tPref, "GuardedTouch", tUser, pStep.%Get("prefKind"), pStep.%Get("name"))
        } ElseIf tKind = "Pref.GuardedTrim" {
            Set tSC = $ClassMethod(tPref, "GuardedTrim", tUser, pStep.%Get("prefKind"), pStep.%Get("keep"))
        } ElseIf tKind = "Pref.DeleteAllGuarded" {
            Set tSC = $ClassMethod(tPref, "DeleteAllGuarded")
        } ElseIf tKind = "Pref.GuardedDeleteForUser" {
            Set tSC = $ClassMethod(tPref, "GuardedDeleteForUser", tUser)
        } ElseIf (tKind = "Pref.BaseSave") || (tKind = "Pref.BaseSaveIfCurrent") {
            Set tSC = $ClassMethod(tPref, "GuardedOpenId", pStep.%Get("id"), .tRow)
            If $$$ISOK(tSC) {
                Set tRow.Value = pStep.%Get("value")
                Set tSC = ..SaveThroughBase(tRow, tKind = "Pref.BaseSave")
            }
            Set tRow = ""
        } ElseIf tKind = "Pref.ForgedSetValue" {
            Set tSC = $ClassMethod(tPref, "GuardedOpenId", pStep.%Get("id"), .tRow)
            If $$$ISOK(tSC) {
                Set tRow.UserName = pStep.%Get("heldUser")
                Set tSC = $ClassMethod(tPref, "GuardedSetValue", tUser, pStep.%Get("prefKind"), pStep.%Get("name"), pStep.%Get("value"))
            }
            Set tRow = ""
        } ElseIf tKind = "Sharing.GuardedSetForUser" {
            Set tSC = $ClassMethod(tSharing, "GuardedSetForUser", tUser, pStep.%Get("share"))
        } ElseIf tKind = "Sharing.DeleteAllGuarded" {
            Set tSC = $ClassMethod(tSharing, "DeleteAllGuarded")
        } ElseIf tKind = "Sharing.GuardedDeleteForUser" {
            Set tSC = $ClassMethod(tSharing, "GuardedDeleteForUser", tUser)
        } ElseIf tKind = "Sharing.ForgedSetForUser" {
            Set tSC = $ClassMethod(tSharing, "GuardedOpenId", pStep.%Get("id"), .tRow)
            If $$$ISOK(tSC) {
                Set tRow.UserName = pStep.%Get("heldUser")
                Set tSC = $ClassMethod(tSharing, "GuardedSetForUser", tUser, pStep.%Get("share"))
            }
            Set tRow = ""
        } ElseIf tKind = "SqlRun.GuardedBegin" {
            Set tSC = $ClassMethod(tRun, "GuardedBegin", pStep.%Get("key"), tUser, .tBegun, .tCancel)
            Do tLeg.%Set("begun", +$Get(tBegun), "number")
        } ElseIf tKind = "SqlRun.GuardedFinish" {
            Set tSC = $ClassMethod(tRun, "GuardedFinish", pStep.%Get("key"), "failed", "")
        } ElseIf tKind = "SqlRun.GuardedCancel" {
            Set tSC = $ClassMethod(tRun, "GuardedCancel", pStep.%Get("key"), tUser, .tFound, .tJobId, .tLive, pStep.%Get("runKind"))
            Do tLeg.%Set("found", +$Get(tFound), "number")
        } ElseIf tKind = "SqlRun.GuardedSweep" {
            Set tSC = $ClassMethod(tRun, "GuardedSweep", ..#LIMITS)
        } ElseIf tKind = "SqlRun.GuardedForgetUser" {
            Set tSC = $ClassMethod(tRun, "GuardedForgetUser", tUser)
        } ElseIf tKind = "SqlRun.ForgedCancel" {
            Set tSC = $ClassMethod(tRun, "GuardedOpenId", pStep.%Get("id"), .tRow)
            If $$$ISOK(tSC) {
                Set tRow.UserName = pStep.%Get("heldUser")
                Set tSC = $ClassMethod(tRun, "GuardedCancel", pStep.%Get("key"), tUser, .tFound, .tJobId, .tLive, pStep.%Get("runKind"))
            }
            Set tRow = ""
        } ElseIf tKind = "SqlRun.ReserveWith" {
            If pStep.%Get("id") '= "" {
                Set tSC = $ClassMethod(tRun, "GuardedOpenId", pStep.%Get("id"), .tRow)
                If $$$ISOK(tSC) {
                    If pStep.%Get("heldField") = "EndedAt" Set tRow.EndedAt = pStep.%Get("heldValue")
                    If pStep.%Get("heldField") = "Namespace" Set tRow.Namespace = pStep.%Get("heldValue")
                }
            }
            If $$$ISOK(tSC) Set tSC = $ClassMethod(tRun, "GuardedReserve", tUser, $NAMESPACE, 10, pStep.%Get("limits"), .tKey, .tBusyKey, .tFull, .tSweepStatus)
            Set tRow = ""
            Do tLeg.%Set("key", $Get(tKey), "string")
            Do tLeg.%Set("sweepOk", ''$$$ISOK($Get(tSweepStatus, $$$OK)), "boolean")
        } ElseIf tKind = "Turn.ReserveWith" {
            If pStep.%Get("id") '= "" {
                Set tSC = $ClassMethod(tTurn, "GuardedOpenId", pStep.%Get("id"), .tRow)
                If $$$ISOK(tSC) && (pStep.%Get("heldField") = "EndedAt") Set tRow.EndedAt = pStep.%Get("heldValue")
            }
            If $$$ISOK(tSC) Set tSC = $ClassMethod(tTurn, "GuardedReserve", tUser, "1", "lost", pStep.%Get("limits"), .tKey, .tBusy, .tSweepStatus)
            Set tRow = ""
            Do tLeg.%Set("key", $Get(tKey), "string")
            Do tLeg.%Set("sweepOk", ''$$$ISOK($Get(tSweepStatus, $$$OK)), "boolean")
        } ElseIf tKind = "Turn.HeldAbandon" {
            Set tSC = $ClassMethod(tTurn, "GuardedOpenId", pStep.%Get("id"), .tRow)
            If $$$ISOK(tSC) {
                Set tRow.TurnKey = pStep.%Get("heldKey")
                Set tSC = $ClassMethod(tTurn, "GuardedAbandonForUser", tUser, .tCount)
                Do tLeg.%Set("count", +$Get(tCount), "number")
            }
            Set tRow = ""
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
