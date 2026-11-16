/// <p>The child process <class>OcuPilot.Test.AdminStateWrite</class> starts to call OcuPilot's guarded
/// stores as a <b>real principal</b> (AD-8, AD-9). It logs in as that principal and runs each step of
/// a plan in this process, so the calls meet the same privilege check a terminal process holding that
/// login would meet. It runs in its own process so the login never touches the test's own identity,
/// which holds <code>%All</code>; the process ends when <method>Run</method> returns.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AdminStateWriteProbe Extends %RegisteredObject
{

/// <p>Log in as <var>pUsername</var>, run the JSON array <var>pPlan</var>, and signal
/// <code>{loggedIn, username, roles, holdsAdmin, holdsDevelopment, steps}</code> to process <var>pParent</var>, or
/// <code>{error}</code> when something raised. A step is <code>{kind, ...}</code> and its answer is
/// <code>{kind, ok, code, text}</code> plus what the kind adds (<method>Handles</method> lists the
/// kinds).</p>
ClassMethod Run(pParent As %Integer, pUsername As %String, pPlan As %String)
{
    Set tOut = {}
    Try {
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $Username)
        Do tOut.%Set("roles", $Roles)
        Do tOut.%Set("holdsAdmin", ''$System.Security.Check($Parameter("OcuPilot.Kernel.State.Base", "ADMINRESOURCE"), "USE"), "boolean")
        Do tOut.%Set("holdsDevelopment", ''$System.Security.Check("%Development", "USE"), "boolean")
        Set tSteps = []
        Set tIterator = ##class(%DynamicArray).%FromJSON(pPlan).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tStep) {
            Do tSteps.%Push(..Step(tStep))
        }
        Do tOut.%Set("steps", tSteps)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Whether <var>pKind</var> is a step <method>Step</method> runs.</p>
ClassMethod Handles(pKind As %String) As %Boolean
{
    Quit $ListFind($ListBuild("Switch.SetGuarded", "Switch.DeleteGuarded", "Hold.GuardedCreate", "Hold.GuardedDeleteId", "Hold.DeleteAllGuarded", "Egress.SetGuarded", "Egress.DeleteGuarded", "Policy.GuardedApply", "Policy.DeleteAllGuarded", "Base.GuardedSave", "Base.GuardedSaveIfCurrent", "Event.RecordMarking", "Sql.UpdateSwitch", "Pref.GuardedSetValue", "Read.Switch", "Read.Holds", "Read.Egress", "Read.Policy"), pKind) > 0
}

/// <p>Run one step of the plan: the guarded call its <code>kind</code> names, with the arguments
/// the step carries. <code>Base.GuardedSave</code> and <code>Base.GuardedSaveIfCurrent</code> open the
/// switch row <code>id</code> names with the public <code>GuardedOpenId</code>, change it, and save
/// it through the public save; <code>Pref.GuardedSetValue</code> writes a per-user row, a store that is not administrator-owned; <code>Sql.UpdateSwitch</code> is the control, a direct
/// <code>UPDATE</code> that answers its <code>sqlcode</code>; the <code>Read.*</code> kinds answer what
/// the principal reads from a store in <code>state</code>.</p>
ClassMethod Step(pStep As %DynamicObject) As %DynamicObject
{
    Set tLeg = {}
    Set tKind = pStep.%Get("kind")
    Set tSC = $$$OK
    Try {
        Kill tValues, tSettings
        If tKind = "Switch.SetGuarded" {
            Set tValues("killSwitch") = pStep.%Get("killSwitch")
            Set tValues("killSwitchReason") = pStep.%Get("reason")
            Set tSC = ##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tValues)
        } ElseIf tKind = "Switch.DeleteGuarded" {
            Set tSC = ##class(OcuPilot.Kernel.State.Switch).DeleteGuarded()
        } ElseIf tKind = "Hold.GuardedCreate" {
            Set tSC = ##class(OcuPilot.Kernel.State.Hold).GuardedCreate(pStep.%Get("user"), pStep.%Get("reason"), .tId)
            Do tLeg.%Set("id", $Get(tId), "string")
        } ElseIf tKind = "Hold.GuardedDeleteId" {
            Set tSC = ##class(OcuPilot.Kernel.State.Hold).GuardedDeleteId(pStep.%Get("id"))
        } ElseIf tKind = "Hold.DeleteAllGuarded" {
            Set tSC = ##class(OcuPilot.Kernel.State.Hold).DeleteAllGuarded()
        } ElseIf tKind = "Egress.SetGuarded" {
            Set tValues("proxyServer") = pStep.%Get("proxyServer")
            Set tValues("proxyPort") = pStep.%Get("proxyPort")
            Set tSC = ##class(OcuPilot.Kernel.State.Egress).SetGuarded(.tValues)
        } ElseIf tKind = "Egress.DeleteGuarded" {
            Set tSC = ##class(OcuPilot.Kernel.State.Egress).DeleteGuarded()
        } ElseIf tKind = "Policy.GuardedApply" {
            Set tSettings(pStep.%Get("key")) = pStep.%Get("value")
            Set tSC = ##class(OcuPilot.Kernel.State.Policy).GuardedApply(pStep.%Get("preset"), .tSettings, pStep.%Get("version"))
        } ElseIf tKind = "Policy.DeleteAllGuarded" {
            Set tSC = ##class(OcuPilot.Kernel.State.Policy).DeleteAllGuarded()
        } ElseIf (tKind = "Base.GuardedSave") || (tKind = "Base.GuardedSaveIfCurrent") {
            Set tSC = ##class(OcuPilot.Kernel.State.Switch).GuardedOpenId(pStep.%Get("id"), .tRow)
            If $$$ISOK(tSC) {
                Set tRow.KillSwitch = 1
                Set tRow.KillSwitchReason = "saved through " _ tKind
                If tKind = "Base.GuardedSave" {
                    Set tSC = ##class(OcuPilot.Kernel.State.Base).GuardedSave(tRow)
                } Else {
                    Set tSC = ##class(OcuPilot.Kernel.State.Base).GuardedSaveIfCurrent(tRow, tRow.RowVersion)
                }
            }
            Set tRow = ""
        } ElseIf tKind = "Event.RecordMarking" {
            Set tSC = ##class(OcuPilot.Kernel.Audit.Event).RecordMarking(pStep.%Get("marked"))
        } ElseIf tKind = "Sql.UpdateSwitch" {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.SwitchState SET KillSwitch = 1")
            Do tLeg.%Set("sqlcode", +tRS.%SQLCODE, "number")
        } ElseIf tKind = "Pref.GuardedSetValue" {
            Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedSetValue(pStep.%Get("user"), pStep.%Get("prefKind"), pStep.%Get("name"), pStep.%Get("value"))
        } ElseIf tKind = "Read.Switch" {
            Set tSC = ##class(OcuPilot.Kernel.State.Switch).Resolve(.tValues)
            If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Kernel.State.Switch).GuardedVersion(.tVersion)
            Do tLeg.%Set("state", tValues("killSwitch") _ "|" _ tValues("killSwitchReason") _ "|" _ tValues("enforcedReadOnly") _ "|" _ tValues("writesMarked") _ "|v" _ $Get(tVersion), "string")
        } ElseIf tKind = "Read.Holds" {
            Set tSC = ##class(OcuPilot.Kernel.State.Hold).GuardedList(.tIds)
            Set tState = ""
            For tI = 1:1:+$Get(tIds) {
                Set tState = tState _ $Select(tState = "": "", 1: ",") _ tIds(tI)
            }
            Do tLeg.%Set("state", "ids " _ tState, "string")
        } ElseIf tKind = "Read.Egress" {
            Set tSC = ##class(OcuPilot.Kernel.State.Egress).Resolve(.tValues)
            If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Kernel.State.Egress).GuardedVersion(.tVersion)
            Do tLeg.%Set("state", tValues("proxyServer") _ "|" _ tValues("proxyPort") _ "|v" _ $Get(tVersion), "string")
        } ElseIf tKind = "Read.Policy" {
            Set tSC = ##class(OcuPilot.Kernel.State.Policy).GuardedAll(.tValues, .tVersion)
            Set tState = ""
            Set tName = ""
            For {
                Set tName = $Order(tValues(tName), 1, tValue)
                If tName = "" Quit
                Set tState = tState _ tName _ "=" _ tValue _ ";"
            }
            Do tLeg.%Set("state", tState _ "v" _ $Get(tVersion), "string")
        } Else {
            Set tSC = $$$ERROR($$$GeneralError, "the probe runs no step of kind " _ tKind)
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
