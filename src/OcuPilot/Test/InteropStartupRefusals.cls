/// <p>Pins Story 24.3's refusals before the vendor (AD-39, AD-51, AD-62): a value the production already holds is 409
/// <code>INTEROP.STARTUP.SAME</code>, a value outside its shape is 422 naming the rule, a priority beside "no auto-start" is
/// <code>NOPRIORITY</code>, a priority or group change by a caller who cannot read every interoperability namespace is 403
/// <code>ALLNAMESPACES</code> (turning auto-start on or off at the priority the read answered is admitted) and a namespace whose database
/// is read-only is 409 <code>READONLY</code>. <code>SAME</code>, the shape rules and <code>NOPRIORITY</code> are attempted from the person's
/// row action, the agent's mint and the port; <code>ALLNAMESPACES</code> and <code>READONLY</code> from the port through
/// <class>OcuPilot.Test.InteropStartupSeam</class>, whose switch reaches no HTTP request (<class>OcuPilot.Test.InteropStartupWire</class> drives
/// <code>ALLNAMESPACES</code> over the routes). Each answers its code and published sentence with the vendor's startup state, read through
/// its own calls, as it was before and the vendor's own calls never made.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, an interoperability-enabled <code>USER</code> namespace and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it compiles the probe productions in <code>USER</code>. It shares
/// <class>OcuPilot.Test.InteropStartupControl</class>'s helpers and puts the startup settings back after each test. One class per run.</p>
Class OcuPilot.Test.InteropStartupRefusals Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter CONTROL = "OcuPilot.Test.InteropStartupControl";

Parameter PROBE = "OcuPilot.Test.ProductionProbe";

Parameter SEAM = "OcuPilot.Test.InteropStartupSeam";

Parameter ERROR = "OcuPilot.Api.InteropError";

Parameter PRODUCTION = "OcuPilotProbe.Interop.Production";

Property PreparedStartup As %List;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedStartup = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropStartupRefusals compiles probe productions in USER and sets its startup settings on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedStartup = $ClassMethod(..#PROBE, "SaveStartup")
    If ..PreparedStartup = "" Quit $$$ERROR($$$GeneralError, "USER's startup settings could not be read")
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "Create")
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Do $$$AssertEquals($ListToString($ClassMethod(..#PROBE, "SaveStartup")), $ListToString(..PreparedStartup), "USER's startup settings read as they did before the class ran")
    Do $$$AssertTrue($ClassMethod(..#PROBE, "Gone"), "and the probe holds nothing")
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Restore")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Restore")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreStartup", ..PreparedStartup), "USER's startup settings are put back")
    Do $$$AssertEquals($ListToString($ClassMethod(..#PROBE, "SaveStartup")), $ListToString(..PreparedStartup), "and read as they did before the test")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The code and sentence of <var>pCode</var>, <var>pName</var> the <code>InteropError</code> parameter's name.</p>
ClassMethod Published(pName As %String, Output pReason As %String) As %String
{
    Set pReason = $Parameter(..#ERROR, "REASON" _ pName)
    Quit $Parameter(..#ERROR, pName)
}

/// <p>The agent's mint of <var>pTool</var> for <var>pArgs</var>: <code>&lt;http&gt; &lt;code&gt;</code> of its refusal, <code>minted</code> when it
/// was not refused; the fault's problem sentence, or else its reason, in <var>pReason</var>.</p>
ClassMethod MintVerdict(pTool As %String, pArgs As %DynamicObject, Output pReason As %String) As %String
{
    Set pReason = ""
    Set tSC = $ClassMethod(..#CONTROL, "Mint", pTool, pArgs, .tProposal, .tFault, .tTurn)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    If $IsObject($Get(tProposal)) Quit "minted"
    If '$IsObject($Get(tFault)) Quit "refused"
    Set pReason = $Select($IsObject(tFault.%Get("detail")) && (tFault.detail.%Get("problem") '= ""): tFault.detail.%Get("problem"), 1: tFault.%Get("reason"))
    Quit tFault.%Get("code")
}

/// <p>The port's startup write <var>pType</var> through the seam for <var>pBody</var>: <code>&lt;http&gt; &lt;code&gt;</code>, the reason in
/// <var>pReason</var>.</p>
ClassMethod PortWrite(pType As %String, pBody As %DynamicObject, Output pReason As %String, Output pRow) As %String
{
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = ..#PRODUCTION
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Productions", pType, .tQuery, pBody, .pRow, .tHttp, .tFault)
    Set pReason = $Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: "")
    Quit tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
}

/// <p>AC3: a value the production already holds is refused <code>SAME</code> with its sentence from the row action, the agent's mint and
/// the port, with the vendor's state unchanged and no vendor call made: stopping auto-start for a production that does not start with the
/// instance, turning it on at the priority it holds or with none, and a shutdown group equal to the one it holds.</p>
Method TestAValueTheProductionAlreadyHoldsIsRefusedBeforeTheVendor()
{
    Set tCode = ..Published("STARTUPSAME", .tReason)
    Set tControl = ..#CONTROL
    Set tP = ..#PRODUCTION
    ; P does not start with the instance and holds group 3.
    Do $$$AssertStatusOK($ClassMethod(tControl, "Seed", "", 0, 3), "no production starts with the instance and the probe is in group 3")
    Set tBefore = $ClassMethod(tControl, "Vendor")
    Do $ClassMethod(..#SEAM, "Arm", 1, 0)
    Do $$$AssertEquals($ClassMethod(tControl, "ActOn", "autostart", tP, {"AutoStart": "0"}, .tAnswer) _ "|" _ $Select($IsObject(tAnswer): tAnswer.reason, 1: ""), "409 " _ tCode _ "|" _ tReason, "the row action: stopping auto-start for a production that does not start with the instance")
    Do $$$AssertEquals($ClassMethod(tControl, "ActOn", "shutdowngroup", tP, {"ShutdownGroup": "3"}, .tAnswer) _ "|" _ $Select($IsObject(tAnswer): tAnswer.reason, 1: ""), "409 " _ tCode _ "|" _ tReason, "the row action: the group it holds")
    Do $$$AssertEquals(..MintVerdict("InteropProductionAutoStart", {"Name": (tP), "AutoStart": "0"}, .tWhy) _ "|" _ tWhy, "INTEROP.STARTUP.SAME|" _ tReason, "the agent: stopping auto-start for a production that does not start with the instance")
    Do $$$AssertEquals(..MintVerdict("InteropProductionShutdownGroup", {"Name": (tP), "ShutdownGroup": "3"}, .tWhy) _ "|" _ tWhy, "INTEROP.STARTUP.SAME|" _ tReason, "the agent: the group it holds")
    Do $$$AssertEquals(..PortWrite("AUTOSTART", {"AutoStart": "0"}, .tWhy) _ "|" _ tWhy, "409 " _ tCode _ "|" _ tReason, "the port: stopping auto-start")
    Do $$$AssertEquals(..PortWrite("SHUTDOWNGROUP", {"ShutdownGroup": "3"}, .tWhy) _ "|" _ tWhy, "409 " _ tCode _ "|" _ tReason, "the port: the group it holds")
    ; P starts with the instance at priority 4 and holds the default group.
    Do $ClassMethod(..#SEAM, "Restore")
    Do $$$AssertStatusOK($ClassMethod(tControl, "Seed", tP, 4, 2), "the probe starts with the instance at priority 4")
    Set tBefore = $ClassMethod(tControl, "Vendor")
    Do $ClassMethod(..#SEAM, "Arm", 1, 0)
    Do $$$AssertEquals($ClassMethod(tControl, "ActOn", "autostart", tP, {"AutoStart": "1", "StartupPriority": "4"}, .tAnswer) _ "|" _ $Select($IsObject(tAnswer): tAnswer.reason, 1: ""), "409 " _ tCode _ "|" _ tReason, "the row action: on at the priority it holds")
    Do $$$AssertEquals($ClassMethod(tControl, "ActOn", "autostart", tP, {"AutoStart": "1"}, .tAnswer) _ "|" _ $Select($IsObject(tAnswer): tAnswer.reason, 1: ""), "409 " _ tCode _ "|" _ tReason, "the row action: on with no priority")
    Do $$$AssertEquals($ClassMethod(tControl, "ActOn", "shutdowngroup", tP, {"ShutdownGroup": "2"}, .tAnswer) _ "|" _ $Select($IsObject(tAnswer): tAnswer.reason, 1: ""), "409 " _ tCode _ "|" _ tReason, "the row action: the default group it holds")
    Do $$$AssertEquals(..MintVerdict("InteropProductionAutoStart", {"Name": (tP), "AutoStart": "1", "StartupPriority": "4"}, .tWhy) _ "|" _ tWhy, "INTEROP.STARTUP.SAME|" _ tReason, "the agent: on at the priority it holds")
    Do $$$AssertEquals(..PortWrite("AUTOSTART", {"AutoStart": "1", "StartupPriority": "4"}, .tWhy) _ "|" _ tWhy, "409 " _ tCode _ "|" _ tReason, "the port: on at the priority it holds")
    Do $$$AssertEquals(..PortWrite("AUTOSTART", {"AutoStart": "1"}, .tWhy) _ "|" _ tWhy, "409 " _ tCode _ "|" _ tReason, "the port: on with no priority")
    Do $$$AssertEquals(..PortWrite("SHUTDOWNGROUP", {"ShutdownGroup": "2"}, .tWhy) _ "|" _ tWhy, "409 " _ tCode _ "|" _ tReason, "the port: the default group")
    Do $$$AssertEquals($ClassMethod(tControl, "Vendor"), tBefore, "the vendor's startup state is as it was")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "and no vendor call was made")
}

/// <p>AC3: a priority or group outside its shape is 422 naming the rule from the port and the row action, and the agent's mint refuses it
/// naming the field and the published sentence; a priority beside "no auto-start" is <code>NOPRIORITY</code>. The vendor is never called.</p>
Method TestAValueOutsideItsShapeIsRefusedNamingTheRule()
{
    Set tControl = ..#CONTROL
    Set tP = ..#PRODUCTION
    Do $$$AssertStatusOK($ClassMethod(tControl, "Seed", tP, 4, 2), "the probe starts with the instance at priority 4")
    Set tBefore = $ClassMethod(tControl, "Vendor")
    Do $ClassMethod(..#SEAM, "Arm", 1, 0)
    For tValue = "1.5", "-", "1234567890", "" {
        Set tLabel = "priority '" _ tValue _ "': "
        Set tPublished = ..Published("STARTUPPRIORITY", .tReason)
        Do $$$AssertEquals(..PortWrite("AUTOSTART", {"AutoStart": "1", "StartupPriority": (tValue)}, .tWhy) _ "|" _ tWhy, "422 " _ tPublished _ "|" _ tReason, tLabel _ "the port")
        If tValue '= "" {
            Do $$$AssertEquals($ClassMethod(tControl, "ActOn", "autostart", tP, {"AutoStart": "1", "StartupPriority": (tValue)}, .tAnswer), "422 " _ tPublished, tLabel _ "the row action")
        }
        Set tVerdict = ..MintVerdict("InteropProductionAutoStart", {"Name": (tP), "AutoStart": "1", "StartupPriority": (tValue)}, .tWhy)
        Do $$$AssertTrue((tVerdict = "TOOL.ARGUMENTS") && (tWhy [ "StartupPriority") && (tWhy [ tReason), tLabel _ "the agent: " _ tVerdict _ " " _ tWhy)
    }
    Set tPublished = ..Published("STARTUPGROUP", .tReason)
    Do $$$AssertEquals(..PortWrite("SHUTDOWNGROUP", {"ShutdownGroup": "abc"}, .tWhy) _ "|" _ tWhy, "422 " _ tPublished _ "|" _ tReason, "group 'abc': the port")
    Do $$$AssertEquals($ClassMethod(tControl, "ActOn", "shutdowngroup", tP, {"ShutdownGroup": "abc"}, .tAnswer), "422 " _ tPublished, "group 'abc': the row action")
    Set tVerdict = ..MintVerdict("InteropProductionShutdownGroup", {"Name": (tP), "ShutdownGroup": "abc"}, .tWhy)
    Do $$$AssertTrue((tVerdict = "TOOL.ARGUMENTS") && (tWhy [ "ShutdownGroup") && (tWhy [ tReason), "group 'abc': the agent: " _ tVerdict _ " " _ tWhy)
    Set tPublished = ..Published("STARTUPNOPRIORITY", .tReason)
    Do $$$AssertEquals(..PortWrite("AUTOSTART", {"AutoStart": "0", "StartupPriority": "3"}, .tWhy) _ "|" _ tWhy, "422 " _ tPublished _ "|" _ tReason, "a priority beside auto-start 0: the port")
    Do $$$AssertEquals($ClassMethod(tControl, "ActOn", "autostart", tP, {"AutoStart": "0", "StartupPriority": "3"}, .tAnswer), "422 " _ tPublished, "a priority beside auto-start 0: the row action")
    Set tVerdict = ..MintVerdict("InteropProductionAutoStart", {"Name": (tP), "AutoStart": "0", "StartupPriority": "3"}, .tWhy)
    Do $$$AssertTrue(((tVerdict = "TOOL.ARGUMENTS") && (tWhy [ tReason)) || (tVerdict = tPublished), "a priority beside auto-start 0: the agent: " _ tVerdict _ " " _ tWhy)
    Do $$$AssertEquals($ClassMethod(tControl, "Vendor"), tBefore, "the vendor's startup state is as it was")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "and no vendor call was made")
}

/// <p>AC3: a priority or group change by a caller who cannot read every interoperability namespace's settings is 403 <code>ALLNAMESPACES</code>
/// from the port before any vendor call; turning auto-start on at the priority the read answered, and off, is admitted. A namespace
/// whose default database is read-only is 409 <code>READONLY</code> before any vendor call.</p>
Method TestAChangeNeedsEveryNamespacesSettingsAndAWritableDatabase()
{
    Set tControl = ..#CONTROL
    Set tP = ..#PRODUCTION
    Set tAll = ..Published("STARTUPALLNAMESPACES", .tReasonAll)
    Set tReadOnly = ..Published("STARTUPREADONLY", .tReasonRO)
    Do $$$AssertStatusOK($ClassMethod(tControl, "Seed", tP, 4, 2), "the probe starts with the instance at priority 4")
    Set tBefore = $ClassMethod(tControl, "Vendor")
    Do $ClassMethod(..#SEAM, "Arm", 0, 0)
    Do $$$AssertEquals(..PortWrite("SHUTDOWNGROUP", {"ShutdownGroup": "3"}, .tWhy) _ "|" _ tWhy, "403 " _ tAll _ "|" _ tReasonAll, "a group change: the port")
    Do $$$AssertEquals(..PortWrite("AUTOSTART", {"AutoStart": "1", "StartupPriority": "7"}, .tWhy) _ "|" _ tWhy, "403 " _ tAll _ "|" _ tReasonAll, "a priority change: the port")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "no vendor call was made")
    Do $$$AssertEquals($ClassMethod(tControl, "Vendor"), tBefore, "and the vendor's state is as it was")
    Do $$$AssertEquals(..PortWrite("AUTOSTART", {"AutoStart": "0"}, .tWhy), "200 ", "turning auto-start off is admitted: " _ tWhy)
    Do $$$AssertEquals(..PortWrite("AUTOSTART", {"AutoStart": "1", "StartupPriority": "0"}, .tWhy), "200 ", "turning it on at the priority the read answered is admitted: " _ tWhy)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "SetAutoStart(,);SetAutoStart(" _ tP _ ",0)", "and each made its one vendor call")
    Do $$$AssertEquals($ClassMethod(tControl, "Vendor"), tP _ "|0|2|2|0", "leaving the production at priority 0")
    Do $ClassMethod(..#SEAM, "Arm", 1, 1)
    Do $$$AssertEquals(..PortWrite("SHUTDOWNGROUP", {"ShutdownGroup": "3"}, .tWhy) _ "|" _ tWhy, "409 " _ tReadOnly _ "|" _ tReasonRO, "a read-only database: a group change")
    Do $$$AssertEquals(..PortWrite("AUTOSTART", {"AutoStart": "0"}, .tWhy) _ "|" _ tWhy, "409 " _ tReadOnly _ "|" _ tReasonRO, "a read-only database: auto-start off")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "and no vendor call was made")
    Do $$$AssertEquals($ClassMethod(tControl, "Vendor"), tP _ "|0|2|2|0", "the state is as the two admitted writes left it")
}

/// <p>A production the namespace does not hold reads absent from every caller: the row action and the port answer 404.</p>
Method TestAnUnknownProductionIsNotFound()
{
    Do $ClassMethod(..#SEAM, "Arm", 1, 0)
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "ActOn", "autostart", "OcuPilotProbe.No.Such", {"AutoStart": "1", "StartupPriority": "1"}, .tAnswer), "404 PORT.NOTFOUND", "the row action")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("id") = "OcuPilotProbe.No.Such"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Productions", "SHUTDOWNGROUP", .tQuery, {"ShutdownGroup": "3"}, .tRow, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 404, "the port")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), "", "and no vendor call was made")
}

}
