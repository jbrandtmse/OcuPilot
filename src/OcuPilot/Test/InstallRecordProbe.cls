/// <p>The child process <class>OcuPilot.Test.InstallRecordWrite</class> starts to call the install-owned
/// stores (application provenance, install stamps, version rows, demo inventory) and the screen-access
/// store as a <b>real principal</b> (AD-9). It adds those stores' steps to
/// <class>OcuPilot.Test.OwnerStateWriteProbe</class>; any step it does not name is the parent's.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InstallRecordProbe Extends OcuPilot.Test.OwnerStateWriteProbe
{

/// <p>The profile every row this probe creates names.</p>
Parameter FORGEDPROFILE = "probeforged";

/// <p>Whether <var>pKind</var> is a step this class or a parent class runs.</p>
ClassMethod Handles(pKind As %String) As %Boolean
{
    If $ListFind(..InstallKinds(), pKind) Quit 1
    Quit ##super(pKind)
}

/// <p>The steps this class adds, as <code>Store.Method</code>. <code>Base.SaveNew</code> builds a row of
/// the step's <code>store</code> and saves it through <code>Base</code>'s public save named by
/// <code>via</code> (<code>save</code> or <code>current</code>); <code>Base.SaveOpened</code> opens row
/// <code>id</code> of that store with the public <code>GuardedOpenId</code>, changes one property and saves it
/// the same way; <code>Access.HeldRename</code> opens the screen-access row <code>id</code>, changes its
/// <code>Screen</code> in memory to <code>heldScreen</code> and holds it across <code>GuardedPut</code>;
/// <code>Access.GuardedPut</code> sends <code>by</code> as the changer, or the principal's own name when it
/// reads <code>self</code>.</p>
ClassMethod InstallKinds() As %List
{
    Quit $ListBuild("WebApp.GuardedRecord", "WebApp.GuardedMarkGatewayReported", "WebApp.DeleteByPath", "Stamp.DeleteByProfile", "Stamp.GuardedSweep", "Version.DeleteByProfile", "Demo.DeleteByProfile", "Access.GuardedPut", "Access.GuardedRemove", "Access.DeleteAllGuarded", "Access.HeldRename", "Base.SaveNew", "Base.SaveOpened")
}

/// <p>Run one step of the plan: the guarded call its <code>kind</code> names, answered as
/// <code>{kind, ok, code, text}</code>.</p>
ClassMethod Step(pStep As %DynamicObject) As %DynamicObject
{
    Set tKind = pStep.%Get("kind")
    If '$ListFind(..InstallKinds(), tKind) Quit ##super(pStep)
    Set tLeg = {}
    Set tSC = $$$OK
    Try {
        Set tPackage = "OcuPilot.Kernel.State."
        If tKind = "WebApp.GuardedRecord" {
            Set tSC = $ClassMethod(tPackage _ "WebApp", "GuardedRecord", pStep.%Get("profile"), pStep.%Get("path"), pStep.%Get("origin"))
        } ElseIf tKind = "WebApp.GuardedMarkGatewayReported" {
            Set tSC = $ClassMethod(tPackage _ "WebApp", "GuardedMarkGatewayReported", pStep.%Get("path"))
        } ElseIf tKind = "WebApp.DeleteByPath" {
            Set tSC = $ClassMethod(tPackage _ "WebApp", "DeleteByPath", pStep.%Get("path"))
        } ElseIf tKind = "Stamp.DeleteByProfile" {
            Set tSC = $ClassMethod(tPackage _ "Stamp", "DeleteByProfile", pStep.%Get("profile"))
        } ElseIf tKind = "Stamp.GuardedSweep" {
            Set tSC = $ClassMethod(tPackage _ "Stamp", "GuardedSweep")
        } ElseIf tKind = "Version.DeleteByProfile" {
            Set tSC = $ClassMethod(tPackage _ "Version", "DeleteByProfile", pStep.%Get("profile"))
        } ElseIf tKind = "Demo.DeleteByProfile" {
            Set tSC = $ClassMethod(tPackage _ "Demo", "DeleteByProfile", pStep.%Get("profile"))
        } ElseIf tKind = "Access.GuardedPut" {
            Set tBy = $Select(pStep.%Get("by") = "self": $Username, 1: pStep.%Get("by"))
            Set tSC = $ClassMethod(tPackage _ "Access", "GuardedPut", pStep.%Get("screen"), pStep.%Get("pairs"), +pStep.%Get("version"), tBy)
        } ElseIf tKind = "Access.GuardedRemove" {
            Set tSC = $ClassMethod(tPackage _ "Access", "GuardedRemove", pStep.%Get("screen"), +pStep.%Get("version"))
        } ElseIf tKind = "Access.DeleteAllGuarded" {
            Set tSC = $ClassMethod(tPackage _ "Access", "DeleteAllGuarded")
        } ElseIf tKind = "Access.HeldRename" {
            Set tSC = $ClassMethod(tPackage _ "Access", "GuardedOpenId", pStep.%Get("id"), .tRow)
            If $$$ISOK(tSC) {
                Set tRow.Screen = pStep.%Get("heldScreen")
                Set tSC = $ClassMethod(tPackage _ "Access", "GuardedPut", pStep.%Get("screen"), pStep.%Get("pairs"), +pStep.%Get("version"), $Username)
            }
            Set tRow = ""
        } ElseIf tKind = "Base.SaveNew" {
            Set tRow = ..NewRow(pStep.%Get("store"), pStep.%Get("via"))
            Set tSC = ..SaveThroughBase(tRow, pStep.%Get("via") = "save")
            Set tRow = ""
        } ElseIf tKind = "Base.SaveOpened" {
            Set tClass = tPackage _ pStep.%Get("store")
            Set tSC = $ClassMethod(tClass, "GuardedOpenId", pStep.%Get("id"), .tRow)
            If $$$ISOK(tSC) {
                Do ..Edit(tRow, pStep.%Get("store"))
                Set tSC = ..SaveThroughBase(tRow, pStep.%Get("via") = "save")
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

/// <p>A new row of the store <var>pStore</var> naming <parameter>FORGEDPROFILE</parameter>, its key made unique
/// by <var>pVia</var>.</p>
ClassMethod NewRow(pStore As %String, pVia As %String) As OcuPilot.Kernel.State.Base
{
    Set tRow = $ClassMethod("OcuPilot.Kernel.State." _ pStore, "%New")
    If pStore = "WebApp" {
        Set tRow.Profile = ..#FORGEDPROFILE
        Set tRow.Path = "/probeforged/" _ pVia
        Set tRow.Origin = "created"
    } ElseIf pStore = "Stamp" {
        Set tRow.Profile = ..#FORGEDPROFILE
        Set tRow.Timestamp = "1990-01-01T00:00:00Z"
        Set tRow.GrantOutcome = "forged"
    } ElseIf pStore = "Version" {
        Set tRow.Profile = ..#FORGEDPROFILE
        Set tRow.Phase = "installed"
        Set tRow.SchemaVersion = 99
    } ElseIf pStore = "Demo" {
        Set tRow.Profile = ..#FORGEDPROFILE
        Set tRow.Kind = "webapp"
        Set tRow.Name = "/probeforged/" _ pVia
        Set tRow.Scope = "instance"
    } Else {
        Set tRow.Screen = "probe.forged." _ pVia
        Set tRow.Pairs = "%Development:USE"
        Set tRow.ChangedBy = "forged"
    }
    Quit tRow
}

/// <p>Change one property of the opened row <var>pRow</var> of the store <var>pStore</var>.</p>
ClassMethod Edit(pRow As OcuPilot.Kernel.State.Base, pStore As %String)
{
    If pStore = "WebApp" {
        Set pRow.Origin = "forged"
    } ElseIf pStore = "Stamp" {
        Set pRow.GrantOutcome = "forged"
    } ElseIf pStore = "Version" {
        Set pRow.Phase = "failed"
    } ElseIf pStore = "Demo" {
        Set pRow.Name = "forged"
    } Else {
        Set pRow.Pairs = "%DB_IRISSYS:READ"
    }
}

}
