/// <p>Pins Story 18.2's namespace refusals beside <class>OcuPilot.Test.NamespaceWrite</class> (AD-4,
/// AD-39, AD-55): an edit of a namespace deleted since the read is refused on both callers and the
/// upsert never re-creates it, a key outside the three is refused on both Save routes rather than
/// dropped, a create without its globals and routines databases is refused on each field on both
/// callers, and a vendor delete that answers 2xx and leaves the namespace is not believed.</p>
/// <p>Writes that should not happen go through <class>OcuPilot.Test.DeviceRecordPort</class>, which
/// records and sends them, so a removed refusal shows as a recorded write.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, the <code>USER</code> and
/// <code>IRISTEMP</code> databases, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because the class creates and deletes namespaces (<class>OcuPilot.Test.NamespaceWriteProbe</class>).
/// <method>OnBeforeAllTests</method> refuses anywhere it does not; every probe namespace is removed by
/// exact name before all, after each and after all, and a survivor fails the class.</p>
Class OcuPilot.Test.NamespaceRefusals Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_NAMESPACE_CONFIG";

Parameter PROBE = "OcuPilot.Test.NamespaceWriteProbe";

Parameter SAVE = "OcuPilot.Test.NamespaceSaveFixture";

Parameter CONFIRM = "OcuPilot.Test.NamespaceConfirm";

Parameter RECORD = "OcuPilot.Test.DeviceRecordPort";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.NamespaceCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.NamespaceUpdate";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.NamespaceRefusals creates and deletes namespaces on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnBeforeOneTest() As %Status
{
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    Do $ClassMethod(..#RECORD, "Clear")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotNamespaceWritePort
    Do $ClassMethod(..#RECORD, "Clear")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe namespace is removed by exact name")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

/// <p>Remove every probe namespace; a failing status when any survives or the configuration file no
/// longer validates or still names a probe namespace.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If '$ClassMethod(..#PROBE, "CpfValid", .tNamesProbe) || tNamesProbe Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the configuration file does not validate, or names a probe namespace, after OcuPilot.Test.NamespaceRefusals"))
    Quit tSC
}

/// <p>The vendor's <code>PUT</code> is an upsert. An edit of a namespace deleted since the read is
/// refused on both callers and the namespace is not re-created: the screen's fresh read answers 404
/// before anything is sent, and the agent's confirm finds the target changed.</p>
Method TestAnEditOfADeletedNamespaceIsRefusedAndNotRecreated()
{
    Set tGone = "OCUPROBE182VG"
    Set tSC = $ClassMethod(..#SAVE, "Update", tGone, {"Routines": "IRISTEMP"}, .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertStatusNotOK(tSC, "the screen's edit of an absent namespace is refused")
    Do $$$AssertEquals(tHttp, 404, "at 404")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tGone), 0, "and nothing is created")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tGone), "a namespace is created")
    Set tSC = ..Mint(..#UPDATETOOL, tGone, {"Name": (tGone), "Routines": "IRISTEMP"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "and the agent's edit of it is minted")
    If '$IsObject(tProposal) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", tGone), "then it is deleted")
    Do $$$AssertEquals(..Confirm(tProposal), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tGone), 0, "and the namespace is not re-created")
}

/// <p>A key outside the three is refused, never dropped: a create carrying one is refused 403 by the
/// prohibited set, an edit carrying one -- the name among them, since a namespace is never renamed --
/// is refused 400, nothing is sent, and the agent's schema refuses the same key.</p>
Method TestAKeyOutsideTheThreeIsRefusedOnBothSaves()
{
    Set tName = "OCUPROBE182XK"
    Set tSC = $ClassMethod(..#SAVE, "Create", tName, {"Name": (tName), "Globals": "USER", "Routines": "USER", "Library": "USER"}, .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertStatusNotOK(tSC, "a create carrying another key is refused")
    Do $$$AssertEquals(tHttp _ " " _ ..Code(.tFault), "403 " _ ##class(OcuPilot.Kernel.Proposal.Prohibited).#UNCOVEREDFIELD, "by the prohibited set")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and no namespace is created")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a namespace is created")
    For tBody = {"Library": "USER"}, {"Name": "OCUPROBE182XL"}, {"Routines": "IRISTEMP", "SysGlobals": "USER"} {
        Set tSC = $ClassMethod(..#SAVE, "Update", tName, tBody, .tHttp, .tFault, .tViolations, .tReadBack)
        Do $$$AssertEquals(tHttp _ " " _ ..Code(.tFault), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, tBody.%ToJSON() _ ": an edit carrying it is refused at 400")
    }
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "Routines"), "USER", "and the namespace is unchanged")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments($ClassMethod(..#UPDATETOOL, "InputSchema"), {"Name": (tName), "Library": "USER"}, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "the agent's schema refuses the same key")
}

/// <p>A create names its globals and routines databases: one that leaves them out, or sends them
/// empty, is refused on each field by the screen's Save, and the agent's mint is refused naming each;
/// nothing is sent and nothing is created.</p>
Method TestACreateWithoutItsDatabasesIsRefusedOnEachField()
{
    Set tName = "OCUPROBE182RQ"
    For tBody = {"Name": (tName)}, {"Name": (tName), "Globals": "", "Routines": ""} {
        Set tSC = $ClassMethod(..#SAVE, "Create", tName, tBody, .tHttp, .tFault, .tViolations, .tReadBack)
        Do $$$AssertEquals(..Fields(.tViolations), "Globals:NAMESPACE.GLOBALS.REQUIRED,Routines:NAMESPACE.ROUTINES.REQUIRED", tBody.%ToJSON() _ ": the screen's create is refused on both fields")
    }
    Set tSC = ..Mint(..#CREATETOOL, tName, {"Name": (tName), "Globals": "", "Routines": ""}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "'Globals'") && (tProblem [ "'Routines'"), "the agent's mint is refused naming each field (" _ tHttp _ " " _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and nothing is created")
}

/// <p>A vendor delete that answers 2xx while the namespace is still there is not a success: the port
/// re-reads it (<parameter>OcuPilot.Port.AdminPort.VERIFIEDDELETES</parameter>) and answers 500
/// <code>PORT.NOTAPPLIED</code>. <class>OcuPilot.Test.RoleDeletePort</class> answers the delete 200
/// without running it.</p>
Method TestAReportedDeleteThatLeftTheNamespaceIsNotApplied()
{
    Set tName = "OCUPROBE182VD"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a namespace is created")
    Kill tQuery
    Set tQuery("name") = tName
    Set tSC = ##class(OcuPilot.Test.RoleDeletePort).Invoke("Namespace.Namespace", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a delete whose namespace is still present is not a success")
    Do $$$AssertEquals(tHttp _ " " _ ..Code(.tFault), "500 " _ ##class(OcuPilot.Api.Error).#PORTNOTAPPLIED, "at 500, as PORT.NOTAPPLIED")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 1, "and the namespace is still there")
}

/// <p>Mint <var>pToolClass</var>'s proposal for <var>pName</var> from <var>pArgs</var> for this
/// process's user over a completed turn seeded for it; <var>pProposal</var> is <code>""</code> when
/// the mint refused, with its problem in <var>pProblem</var>.</p>
Method Mint(pToolClass As %String, pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pProblem As %String) As %Status
{
    Set pProposal = ""
    Set pHttp = 0
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(pToolClass, "DESCRIPTORCLASS"), $Parameter(pToolClass, "TOOLNAME"), $Username, "", tTurnKey, pArgs, ..#LIMITS, .tResult, .pHttp, .tFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pName, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
    If $IsObject($Get(tResult)) Set pProposal = tResult
    If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set pProblem = tFault.%Get("detail").%Get("problem")
    If '$IsObject(pProposal) Quit $$$ERROR($$$GeneralError, "the mint answered no proposal: " _ pHttp _ " " _ pProblem)
    Quit $$$OK
}

/// <p>Confirm <var>pProposal</var> through <parameter>CONFIRM</parameter> as this process's user,
/// answering <code>http code</code>.</p>
Method Confirm(pProposal As %DynamicObject) As %String
{
    If '$IsObject(pProposal) Quit "no proposal"
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", pProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Quit $Select($$$ISOK(tSC) && ($Get(tCode) = ""): 200, 1: +$Get(tHttp)) _ " " _ $Get(tCode)
}

/// <p>The code <var>pFault</var> carries, or <code>""</code>.</p>
ClassMethod Code(ByRef pFault) As %String
{
    If '$IsObject($Get(pFault)) Quit ""
    Quit pFault.%Get("code")
}

/// <p>The violation array <var>pViolations</var> as <code>field:code</code>, comma-separated.</p>
ClassMethod Fields(ByRef pViolations) As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(pViolations) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $List(pViolations(tI), 1) _ ":" _ $List(pViolations(tI), 2)
    }
    Quit tOut
}

}
