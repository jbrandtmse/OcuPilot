/// <p>Pins Story 24.15's schedule spec refusals end to end against probe schedule specs in <code>USER</code> (AD-6, AD-8, AD-39, AD-54, AD-62): each
/// refusal row of the plan's matrix is refused by its own code with its published sentence, from the person's Save and Edit, the agent's mint and the
/// port, and nothing is written -- a name the namespace holds in any letter case, a schedule spec that is not there, a name the vendor cannot store, a
/// spec the vendor's validator refuses (the empty one included), a description over the vendor's limit and a namespace under source control. No line the
/// port logs carries a spec or a name. The gate runs as real principals in a child process: a caller without <code>%Ens_ProductionConfig:WRITE</code>,
/// one without the read pair and one who cannot read or write the database, each refused before any value is judged, the remove included. It also pins the
/// signature of the vendor's validator the port calls.</p>
/// <p><b>What it needs from the environment:</b> interoperability-enabled <code>USER</code> and <code>HSCUSTOM</code> namespaces, the HTTP test account
/// and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates and deletes users and roles named <code>OcuP2415S*</code>. It
/// removes every schedule spec, principal and role it creates.</p>
Class OcuPilot.Test.InteropScheduleRefusals Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropScheduleFixture";

Parameter CLEARER = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropScheduleControl";

Parameter GENERATOR = "OcuPilot.Test.InteropLookupGate";

Parameter SEAM = "OcuPilot.Test.InteropScheduleSeam";

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter ERROR = "OcuPilot.Api.InteropError";

Parameter NAME = "OcuProbe2415SA";

Parameter SPEC = "START:*-*-*T08:00:00,STOP:*-*-*T17:00:00";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>, separated by <code>;</code>.</p>
Parameter PRINCIPALS = "OcuP2415SExact:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:RW,%DB_USER:RW;OcuP2415SNoWrite:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:R,%DB_USER:RW;OcuP2415SNoRead:%Development:U,%Ens_Portal:U,%DB_USER:RW;OcuP2415SNoUser:%Development:U,%Ens_Portal:U,%Ens_ProductionConfig:RW";

/// <p>The legs a probe runs, in order, <code>&lt;name&gt;|&lt;type&gt;|&lt;schedule spec&gt;</code>. The held schedule spec is the one the set and the remove name;
/// <code>addBad</code> carries a spec the vendor refuses, so a caller the gate admits is refused it and one it does not is refused the gate first.</p>
Parameter LEGS = "list|LIST|,add|ADDSCHEDULE|OcuProbe2415SG,addBad|ADDSCHEDULE|OcuProbe2415SB,set|SETSCHEDULE|OcuProbe2415SH,remove|REMOVESCHEDULE|OcuProbe2415SH,removeMissing|REMOVESCHEDULE|OcuProbe2415SMissing";

Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropScheduleRefusals creates and deletes users and roles and writes probe schedule specs on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuP2415Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $ClassMethod(..#CLEARER, "Clear")
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#CLEARER, "Clear")
    Quit $$$ADDSC(tSC, $ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS))
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "ClearLog")
    Quit $ClassMethod(..#CLEARER, "Clear")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Disarm")
    Do $ClassMethod(..#SEAM, "ClearLog")
    Do $$$AssertStatusOK($ClassMethod(..#CLEARER, "Clear"), "the probe schedule specs are removed")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleCount") + $ClassMethod(..#FIXTURE, "ScheduleCount", "OcuProbe2415S", "HSCUSTOM"), 0, "and none survives in either namespace")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>The published sentence of the code <var>pName</var> names (a parameter of <class>OcuPilot.Api.InteropError</class>).</p>
ClassMethod Reason(pName As %String) As %String
{
    Quit $Parameter(..#ERROR, "REASON" _ pName)
}

/// <p>The code of <var>pFault</var>, or <code>""</code>.</p>
ClassMethod CodeOf(pFault) As %String
{
    Quit $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>The port class <var>pClass</var>'s call of the type <var>pType</var> on <var>pName</var> in <var>pNamespace</var> as <code>status code</code>, the
/// envelope in <var>pFault</var> and the answer in <var>pRow</var>. <var>pAction</var>, when given, composes a read for that write.</p>
ClassMethod Verdict(pType As %String, pName As %String, pBody As %DynamicObject = "", Output pFault, Output pRow, pNamespace As %String = "USER", pClass As %String = {..#PORT}, pAction As %String = "") As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("id") = pName
    If pAction '= "" Set tQuery("action") = pAction
    Set tSC = $ClassMethod(pClass, "Invoke", "Schedules", pType, .tQuery, pBody, .pRow, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ ..CodeOf(.pFault)
}

/// <p>Hold every pair a schedule spec write through the seam needs, answer source control as <var>pSourceControlled</var> says, and forget what the
/// seam logged.</p>
ClassMethod ArmSeam(pSourceControlled As %Boolean = 0)
{
    For tPair = $ListBuild("%Ens_Portal", "USE"), $ListBuild("%Ens_ProductionConfig", "READ"), $ListBuild("%Ens_ProductionConfig", "WRITE"), $ListBuild("%DB_USER", "READ"), $ListBuild("%DB_USER", "WRITE") {
        Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tPair, 1), $List(tPair, 2))
    }
    Do $ClassMethod(..#SEAM, "Arm", "", pSourceControlled)
    Do $ClassMethod(..#SEAM, "ClearLog")
}

/// <p>The agent's mint of <var>pTool</var> for the schedule spec <var>pName</var> with <var>pSet</var> beside it: the code of its refusal,
/// <code>minted</code> when it was not refused; the sentence in <var>pReason</var>.</p>
ClassMethod MintVerdict(pTool As %String, pName As %String, pSet As %DynamicObject, Output pReason As %String) As %String
{
    Set pReason = ""
    Set tSC = $ClassMethod(..#CONTROL, "Mint", pTool, $ClassMethod(..#CONTROL, "ArgsFor", pName, pSet), .tProposal, .tFault, .tTurn)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    If $IsObject($Get(tProposal)) Quit "minted"
    If '$IsObject($Get(tFault)) Quit "refused"
    Set pReason = $Select($IsObject(tFault.%Get("detail")) && (tFault.detail.%Get("problem") '= ""): tFault.detail.%Get("problem"), 1: tFault.%Get("reason"))
    Quit tFault.%Get("code")
}

/// <p>AC2: an add of a name the namespace holds, exactly or in another letter case, is <code>INTEROP.SCHEDULE.TAKEN</code> from the person's Save, the
/// agent's mint and the port, and an edit or a remove of a name it does not hold exactly is 404; the held schedule spec is untouched.</p>
/// <p>Mutation (Rule 19): make the add's case-folded taken test in <method>OcuPilot.Port.InteropPort.ScheduleWriteToken</method> compare exactly -- the
/// other-case legs go red.</p>
Method TestAHeldNameIsTakenInAnyCaseAndAMissingOneIsNotFound()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutSchedule", ..#NAME, ..#SPEC, "held"), "the probe schedule spec is held")
    For tName = ..#NAME, $ZConvert(..#NAME, "L") {
        Do $ClassMethod(..#CONTROL, "Save", $ClassMethod(..#CONTROL, "SaveBody", tName, ..#SPEC), .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code _ " " _ tAnswer.reason, 1: ""), "INTEROP.SCHEDULE.TAKEN " _ ..Reason("SCHEDULETAKEN"), "the Save of '" _ tName _ "' is refused with the published sentence")
        Do $$$AssertEquals(..MintVerdict("InteropScheduleAdd", tName, {"ScheduleSpec": (..#SPEC)}, .tReason), "INTEROP.SCHEDULE.TAKEN", "the agent's add of '" _ tName _ "' is refused at the mint")
        Do $$$AssertEquals(tReason, ..Reason("SCHEDULETAKEN"), "with the published sentence")
        Do $$$AssertEquals(..Verdict("ADDSCHEDULE", tName, {"ScheduleSpec": (..#SPEC)}), "409 INTEROP.SCHEDULE.TAKEN", "the port refuses the add of '" _ tName _ "'")
    }
    Do $$$AssertEquals($ClassMethod(tFixture, "ScheduleText", ..#NAME), ..#SPEC _ "|held|0", "the held schedule spec is untouched")
    Do $$$AssertEquals($ClassMethod(tFixture, "ScheduleCount"), 1, "and nothing else was written")
    Set tMissing = "OcuProbe2415SMissing"
    Do $$$AssertEquals(..Verdict("SETSCHEDULE", tMissing, {"Description": "x"}), "404 PORT.NOTFOUND", "a set of a name that is not held is 404")
    Do $$$AssertEquals(..Verdict("REMOVESCHEDULE", tMissing), "404 PORT.NOTFOUND", "and a remove")
    Do $$$AssertEquals(..Verdict("SETSCHEDULE", $ZConvert(..#NAME, "L"), {"Description": "x"}), "404 PORT.NOTFOUND", "a set by the name in another letter case is 404, since the vendor opens a name exactly")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "edit", tMissing, {"Description": "x"}, .tAnswer), "404 PORT.NOTFOUND", "the person's Edit of a missing name is 404 too")
    Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "remove", tMissing, "", .tAnswer), "404 PORT.NOTFOUND", "and so is the person's Remove")
    Do $$$AssertEquals($ClassMethod(tFixture, "ScheduleCount"), 1, "and nothing was written")
}

/// <p>AC2: a name that is empty, over fifty characters or holds a control character is <code>INTEROP.SCHEDULE.NAME</code> (422) from the Save, the mint
/// and the port, with the published sentence, and nothing is written; a remove of a name the port does not write finds none.</p>
/// <p>Mutation (Rule 19): drop the control character test from <method>OcuPilot.Port.InteropPort.ScheduleNameOK</method> -- the control character row
/// goes red.</p>
Method TestANameThePortDoesNotWriteIsRefusedBeforeAnythingIsStored()
{
    Set tLong = ..#NAME _ $Translate($Justify("", 37), " ", "z")
    Do $$$AssertEquals($Length(tLong), 51, "the long name is one past the limit")
    For tCase = $ListBuild("long", tLong), $ListBuild("control", ..#NAME _ $Char(9) _ "x"), $ListBuild("bell", ..#NAME _ $Char(7)), $ListBuild("empty", "") {
        Set tName = $List(tCase, 2)
        Do $ClassMethod(..#CONTROL, "Save", $ClassMethod(..#CONTROL, "SaveBody", tName, ..#SPEC), .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code, 1: ""), "INTEROP.SCHEDULE.NAME", $List(tCase, 1) _ ": the Save is refused")
        Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%ToJSON() [ ..Reason("SCHEDULENAME")), $List(tCase, 1) _ ": with the published sentence")
        If tName = "" Continue
        Do $$$AssertEquals(..Verdict("ADDSCHEDULE", tName, {"ScheduleSpec": (..#SPEC)}), "422 INTEROP.SCHEDULE.NAME", $List(tCase, 1) _ ": the port refuses the add")
        Do $$$AssertEquals(..MintVerdict("InteropScheduleAdd", tName, {"ScheduleSpec": (..#SPEC)}, .tReason), "TOOL.ARGUMENTS", $List(tCase, 1) _ ": the agent's add is refused at the mint")
        Do $$$AssertTrue(tReason [ ..Reason("SCHEDULENAME"), $List(tCase, 1) _ ": naming the published sentence: " _ tReason)
    }
    Do $$$AssertEquals(..Verdict("REMOVESCHEDULE", tLong), "404 PORT.NOTFOUND", "a remove of a name the port does not write finds none")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleCount"), 0, "and nothing was written")
}

/// <p>AC2: a spec the vendor's validator refuses, the empty one included, is <code>INTEROP.SCHEDULE.SPEC</code> (422) from the Save, the person's Edit, the
/// mint and the port, with the published sentence, and nothing is written; a spec it accepts is. No line the port logged carries the spec or the name, and a
/// refusal by the validator was logged by its error code alone.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ScheduleSpecAccepted</method> answer 1 -- the spec rows go red. Make it log the
/// validator's own text -- the no-spec-in-a-log leg goes red.</p>
Method TestASpecTheVendorRefusesIsRefusedAndNoLineCarriesIt()
{
    Set tFixture = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutSchedule", ..#NAME _ "H", ..#SPEC, "held"), "a schedule spec is held to edit")
    For tCase = $ListBuild("an hour of 25", "START:*-*-*T25:00:00"), $ListBuild("an unknown action", "FOO:*-*-*T08:00:00"), $ListBuild("the empty spec", ""), $ListBuild("a part with no time", "START") {
        Set tSpec = $List(tCase, 2)
        Set tLabel = $List(tCase, 1)
        Do ..ArmSeam()
        Do $ClassMethod(..#CONTROL, "Save", $ClassMethod(..#CONTROL, "SaveBody", ..#NAME, tSpec), .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code, 1: ""), "INTEROP.SCHEDULE.SPEC", tLabel _ ": the Save is refused")
        Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%ToJSON() [ ..Reason("SCHEDULESPEC")), tLabel _ ": with the published sentence")
        Do $$$AssertEquals(..Verdict("ADDSCHEDULE", ..#NAME, {"ScheduleSpec": (tSpec)}, .tFault, .tRow, "USER", tSeam), "422 INTEROP.SCHEDULE.SPEC", tLabel _ ": the port refuses the add")
        Do $$$AssertEquals(..Verdict("SETSCHEDULE", ..#NAME _ "H", {"ScheduleSpec": (tSpec)}, .tFault, .tRow, "USER", tSeam), "422 INTEROP.SCHEDULE.SPEC", tLabel _ ": and the edit")
        Set tLogged = $ClassMethod(tSeam, "LoggedText")
        Do $$$AssertTrue($Select(tSpec = "": 1, 1: tLogged '[ tSpec), tLabel _ ": no line the port logged carries the spec: " _ tLogged)
        Do $$$AssertTrue(tLogged '[ ..#NAME, tLabel _ ": or the name")
        If tSpec '= "" Do $$$AssertTrue($ClassMethod(tSeam, "Logged") > 0, tLabel _ ": and the vendor's refusal was logged, by its code alone: " _ tLogged)
        Do $$$AssertEquals(..MintVerdict("InteropScheduleAdd", ..#NAME, {"ScheduleSpec": (tSpec)}, .tReason), "TOOL.ARGUMENTS", tLabel _ ": the agent's add is refused at the mint")
        Do $$$AssertTrue(tReason [ ..Reason("SCHEDULESPEC"), tLabel _ ": naming the published sentence: " _ tReason)
        Do $$$AssertEquals(..MintVerdict("InteropScheduleUpdate", ..#NAME _ "H", {"ScheduleSpec": (tSpec)}, .tReason), "TOOL.ARGUMENTS", tLabel _ ": and the update")
        Do $$$AssertEquals($ClassMethod(..#CONTROL, "Act", "edit", ..#NAME _ "H", {"ScheduleSpec": (tSpec)}, .tAnswer), "422 INTEROP.SCHEDULE.SPEC", tLabel _ ": and the person's Edit")
    }
    Do $$$AssertEquals($ClassMethod(tFixture, "ScheduleText", ..#NAME _ "H"), ..#SPEC _ "|held|0", "the held schedule spec is as it was")
    Do $$$AssertEquals($ClassMethod(tFixture, "ScheduleCount"), 1, "and nothing else was written")
    Do ..ArmSeam()
    Do $$$AssertEquals(..Verdict("ADDSCHEDULE", ..#NAME, {"ScheduleSpec": (..#SPEC)}, .tFault, .tRow, "USER", tSeam), "200 ", "a spec the vendor accepts is added")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 0, "without a line logged")
}

/// <p>AC2: a description of 257 characters is <code>INTEROP.SCHEDULE.DESCRIPTION</code> (422) from the Save, the mint and the port, and one of 256 is
/// accepted; nothing is written by a refusal.</p>
/// <p>Mutation (Rule 19): change <parameter>OcuPilot.Port.InteropPort.SCHEDULEDESCRIPTIONMAX</parameter> to 300 -- the 257-character rows go red.</p>
Method TestADescriptionOverTheLimitIsRefused()
{
    Set tLong = $Translate($Justify("", 257), " ", "d")
    Set tEdge = $Extract(tLong, 1, 256)
    Do $ClassMethod(..#CONTROL, "Save", $ClassMethod(..#CONTROL, "SaveBody", ..#NAME, ..#SPEC, tLong), .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.code, 1: ""), "INTEROP.SCHEDULE.DESCRIPTION", "the Save of 257 characters is refused")
    Do $$$AssertTrue($IsObject(tAnswer) && (tAnswer.%ToJSON() [ ..Reason("SCHEDULEDESCRIPTION")), "with the published sentence")
    Do $$$AssertEquals(..Verdict("ADDSCHEDULE", ..#NAME, {"ScheduleSpec": (..#SPEC), "Description": (tLong)}), "422 INTEROP.SCHEDULE.DESCRIPTION", "the port refuses the add")
    Do $$$AssertEquals(..MintVerdict("InteropScheduleAdd", ..#NAME, {"ScheduleSpec": (..#SPEC), "Description": (tLong)}, .tReason), "TOOL.ARGUMENTS", "the agent's add is refused at the mint")
    Do $$$AssertTrue(tReason [ ..Reason("SCHEDULEDESCRIPTION"), "naming the published sentence: " _ tReason)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleCount"), 0, "and nothing was written")
    Do $$$AssertEquals(..Verdict("ADDSCHEDULE", ..#NAME, {"ScheduleSpec": (..#SPEC), "Description": (tEdge)}), "200 ", "a description of 256 characters is accepted")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", ..#NAME), ..#SPEC _ "|" _ tEdge _ "|0", "and stored as sent")
}

/// <p>AC2: a namespace under source control refuses every schedule spec write by <code>SOURCECONTROL</code> before the vendor is called, the composed
/// reads of a write included, while the list stays readable. Driven through the port both callers reach, through a seam that answers the namespace's
/// source control state.</p>
/// <p>Mutation (Rule 19): drop the <code>SourceControlled</code> refusal from <method>OcuPilot.Port.InteropPort.ScheduleWriteRefusal</method> -- the write
/// rows go red.</p>
Method TestASourceControlledNamespaceRefusesEveryWrite()
{
    Set tFixture = ..#FIXTURE
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutSchedule", ..#NAME, ..#SPEC, "held"), "the probe schedule spec is held")
    Do ..ArmSeam(1)
    Kill tList
    Set tList("namespace") = "USER"
    Set tSC = $ClassMethod(tSeam, "Invoke", "Schedules", "LIST", .tList, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the list is readable under source control")
    For tWrite = $ListBuild("ADDSCHEDULE", "OcuProbe2415SFresh", {"ScheduleSpec": (..#SPEC)}), $ListBuild("SETSCHEDULE", ..#NAME, {"Description": "x"}), $ListBuild("REMOVESCHEDULE", ..#NAME, "") {
        Set tVerdict = ..Verdict($List(tWrite, 1), $List(tWrite, 2), $List(tWrite, 3), .tFault, .tRow, "USER", tSeam)
        Do $$$AssertEquals(tVerdict, "409 INTEROP.SCHEDULE.SOURCECONTROL", $List(tWrite, 1) _ " is refused for source control")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.reason, 1: ""), ..Reason("SCHEDULESOURCECONTROL"), "with the published sentence")
    }
    For tAction = "ADDSCHEDULE", "SETSCHEDULE", "REMOVESCHEDULE" {
        Set tVerdict = ..Verdict("SCHEDULE", ..#NAME, "", .tFault, .tRow, "USER", tSeam, tAction)
        Do $$$AssertEquals(tVerdict, "409 INTEROP.SCHEDULE.SOURCECONTROL", "the read composed for " _ tAction _ " is refused too")
    }
    Do $$$AssertEquals($ClassMethod(tFixture, "ScheduleText", ..#NAME), ..#SPEC _ "|held|0", "nothing was written")
    Do $$$AssertEquals($ClassMethod(tFixture, "ScheduleCount"), 1, "and nothing was added")
    Do $$$AssertEquals($ClassMethod(tSeam, "Logged"), 0, "and nothing was logged as a fault")
}

/// <p>AC2: the gate, as real principals in a child process, refuses before any vendor call and before any value is judged, and writes nothing: a caller
/// without <code>%Ens_ProductionConfig:WRITE</code> is refused 403 naming that pair on each write, the remove included, and reads the list; one without
/// the read pair is refused every leg naming it; one who cannot write the database is refused each write naming it and one who cannot read it the list.
/// A caller the gate admits is refused the spec the vendor refuses, and the others are refused the gate first; so too a remove of a name not held,
/// which is 404 only for the caller the gate admits.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Port.InteropPort.SCHEDULEWRITEPAIR</parameter> from the write pairs -- the
/// <code>OcuP2415SNoWrite</code> caller's write legs go red.</p>
Method TestTheGateRefusesEachPrincipalBeforeAnyVendorCall()
{
    Set tSC = $ClassMethod(..#GENERATOR, "CreatePrincipals", ..#PRINCIPALS, ..PreparedPassword, "the schedule spec gate")
    Do $$$AssertStatusOK(tSC, "the principals are created")
    If $$$ISERR(tSC) Quit
    Set tDeny = ##class(OcuPilot.Kernel.Denial).Code()
    Set tOk = "200||"
    Set tBad = "422|INTEROP.SCHEDULE.SPEC|"
    Set tWrite = "403|" _ tDeny _ "|%Ens_ProductionConfig:WRITE"
    Set tRead = "403|" _ tDeny _ "|%Ens_ProductionConfig:READ"
    Set tUserWrite = "403|" _ tDeny _ "|%DB_USER:WRITE"
    Set tUserRead = "403|" _ tDeny _ "|%DB_USER:READ"
    Set tExpected("OcuP2415SExact") = $ListBuild(tOk, tOk, tBad, tOk, tOk, "404|PORT.NOTFOUND|")
    Set tExpected("OcuP2415SNoWrite") = $ListBuild(tOk, tWrite, tWrite, tWrite, tWrite, tWrite)
    Set tExpected("OcuP2415SNoRead") = $ListBuild(tRead, tRead, tRead, tRead, tRead, tRead)
    Set tExpected("OcuP2415SNoUser") = $ListBuild(tUserRead, tUserWrite, tUserWrite, tUserWrite, tUserWrite, tUserWrite)
    Set tUser = ""
    For {
        Set tUser = $Order(tExpected(tUser))
        If tUser = "" Quit
        Do $$$AssertStatusOK($ClassMethod(..#CLEARER, "Clear"), tUser _ ": the probe schedule specs are cleared")
        Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "PutSchedule", "OcuProbe2415SH", ..#SPEC, "held"), tUser _ ": the held schedule spec is arranged")
        Set tOut = ..ProbeAs(tUser)
        Do $$$AssertTrue('$IsObject(tOut) || (tOut.%Get("error") = ""), tUser _ ": the probe ran: " _ $Select($IsObject(tOut): tOut.%Get("error"), 1: tOut))
        If '$IsObject(tOut) || (tOut.%Get("error") '= "") Continue
        Do $$$AssertTrue(tOut.loggedIn, tUser _ ": the principal logged in")
        Set tHeldGone = 0
        Set tAdded = 0
        For tI = 1:1:$Length(..#LEGS, ",") {
            Set tLegName = $Piece($Piece(..#LEGS, ",", tI), "|", 1)
            Set tLeg = tOut.%Get(tLegName)
            Set tGot = $Select($IsObject(tLeg): tLeg.http _ "|" _ tLeg.%Get("code") _ "|" _ tLeg.%Get("failedPair"), 1: "no answer")
            Do $$$AssertEquals(tGot, $List(tExpected(tUser), tI), tUser _ ": the " _ tLegName _ " leg is answered as declared")
            If (tLegName = "add") && (tGot = tOk) Set tAdded = 1
            If (tLegName = "remove") && (tGot = tOk) Set tHeldGone = 1
        }
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", "OcuProbe2415SG"), $Select(tAdded: ..#SPEC _ "|added|0", 1: "<absent>"), tUser _ ": only an admitted add was stored")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", "OcuProbe2415SB"), "<absent>", tUser _ ": and the add of a spec the vendor refuses was stored for none")
        If 'tHeldGone Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", "OcuProbe2415SH"), ..#SPEC _ "|held|0", tUser _ ": a refused remove, and a refused set, left the held schedule spec as it was")
        If tHeldGone Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleText", "OcuProbe2415SH"), "<absent>", tUser _ ": an admitted remove took it")
    }
    Do $$$AssertStatusOK($ClassMethod(..#GENERATOR, "DeletePrincipals", ..#PRINCIPALS), "the principals are removed")
}

/// <p>Run <method>Probe</method> as <var>pUser</var> in a child process and answer what it signalled, or an object carrying <code>error</code>.</p>
Method ProbeAs(pUser As %String) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.InteropScheduleRefusals).Probe($Job, pUser)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 180)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 180 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>The child process <method>ProbeAs</method> starts: log in as <var>pUsername</var>, run each of <parameter>LEGS</parameter> through
/// <class>OcuPilot.Port.InteropPort</class>, and signal <code>{loggedIn, username, "&lt;leg&gt;": {http, code, failedPair}}</code> to process
/// <var>pParent</var>, or <code>{error}</code> when something raised.</p>
ClassMethod Probe(pParent As %Integer, pUsername As %String)
{
    Set tOut = {}
    Try {
        If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
            Do tOut.%Set("error", ..#ARMINGVARIABLE _ " does not read 1 in the probe process")
            Quit
        }
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $USERNAME)
        For tI = 1:1:$Length(..#LEGS, ",") {
            Set tSpec = $Piece(..#LEGS, ",", tI)
            Set tName = $Piece(tSpec, "|", 1)
            Set tType = $Piece(tSpec, "|", 2)
            Kill tQuery
            Set tQuery("namespace") = "USER"
            Set tBody = ""
            If tType '= "LIST" {
                Set tQuery("id") = $Piece(tSpec, "|", 3)
                If tName = "add" Set tBody = {"ScheduleSpec": "START:*-*-*T08:00:00,STOP:*-*-*T17:00:00", "Description": "added"}
                If tName = "addBad" Set tBody = {"ScheduleSpec": "FOO:*-*-*T08:00:00"}
                If tName = "set" Set tBody = {"Description": "set"}
            }
            Set tHttp = 0
            Set tFault = ""
            Kill tResult
            Set tSC = ##class(OcuPilot.Port.InteropPort).Invoke("Schedules", tType, .tQuery, tBody, .tResult, .tHttp, .tFault)
            Set tLeg = {}
            Do tLeg.%Set("http", +tHttp, "number")
            If $IsObject(tFault) {
                Do tLeg.%Set("code", tFault.%Get("code"))
                If $IsObject(tFault.%Get("detail")) Do tLeg.%Set("failedPair", tFault.detail.%Get("failedPair"))
            }
            Do tOut.%Set(tName, tLeg)
        }
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Task 2: the vendor's <code>ValidateScheduleSpec</code>, which the port calls, is what the port declares it is: a class method marked
/// <code>Internal</code> whose compiled formal spec and return type, read from the instance, equal
/// <parameter>OcuPilot.Port.InteropPort.SCHEDULEVALIDATORFORMAL</parameter> and <parameter>SCHEDULEVALIDATORRETURN</parameter>; and the port's call
/// answers what the validator answers, a valid spec accepted and a refused one not, without writing an event log row. A vendor change to the method turns
/// this red.</p>
/// <p>Mutation (Rule 19): change <parameter>OcuPilot.Port.InteropPort.SCHEDULEVALIDATORFORMAL</parameter> to carry one more argument, or
/// <parameter>SCHEDULEVALIDATORRETURN</parameter> to <code>%Library.Boolean</code> -- this goes red.</p>
Method TestTheValidatorsSignatureIsWhatThePortCalls()
{
    Set tMethod = ##class(%Dictionary.CompiledMethod).%OpenId("Ens.ScheduleHandler||" _ $Parameter(..#PORT, "SCHEDULEVALIDATOR"))
    Do $$$AssertTrue($IsObject(tMethod), "the vendor's validator is compiled on this instance")
    If '$IsObject(tMethod) Quit
    Do $$$AssertEquals(tMethod.ClassMethod _ "|" _ tMethod.Internal, "1|1", "it is a class method marked Internal")
    Do $$$AssertEquals(tMethod.FormalSpec, $Parameter(..#PORT, "SCHEDULEVALIDATORFORMAL"), "its formal spec is the one the port calls: the spec, the errors by reference and the length")
    Do $$$AssertEquals(tMethod.ReturnType, $Parameter(..#PORT, "SCHEDULEVALIDATORRETURN"), "and it answers a status")
    Set tRows = ..LogRows()
    Do $$$AssertTrue(tRows >= 0, "the event log is readable")
    Do $$$AssertEquals($ClassMethod(..#PORT, "ScheduleSpecAccepted", ..#SPEC), 1, "the port's call accepts a spec the validator accepts")
    Do $$$AssertEquals($ClassMethod(..#PORT, "ScheduleSpecAccepted", "START:*-*-*T25:00:00"), 0, "and refuses one it refuses")
    Do $$$AssertEquals($ClassMethod(..#PORT, "ScheduleSpecAccepted", ""), 0, "and the empty one")
    Do $$$AssertEquals(..LogRows(), tRows, "and it wrote no event log row")
}

/// <p>How many rows the current namespace's event log holds, or -1.</p>
ClassMethod LogRows() As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM Ens_Util.Log")
    Quit $Select((tRS.%SQLCODE = 0) && tRS.%Next(): tRS.%Get("N"), 1: -1)
}

/// <p>AC2: a vendor status reaches the log as its error codes alone: the text it carries, which echoes the spec, the name or the description, is dropped,
/// and a lock the vendor could not take and a privilege refusal are kept as they came, so they are still answered as they are everywhere.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ScheduleVendorStatus</method> answer the status it was given -- the marker leg goes
/// red.</p>
Method TestAVendorStatusReachesTheLogAsItsCodesAlone()
{
    Set tMarker = "OcuMarkerText2415"
    Set tClean = $ClassMethod(..#PORT, "ScheduleVendorStatus", $System.Status.Error(5001, tMarker))
    Do $$$AssertStatusNotOK(tClean, "the status is still an error")
    Set tText = $System.Status.GetErrorText(tClean)
    Do $$$AssertTrue(tText '[ tMarker, "its text is not carried: " _ tText)
    Do $$$AssertTrue(tText [ "5001", "its error code is: " _ tText)
    Set tProtect = $System.Status.Error(5001, "<PROTECT> " _ tMarker)
    Do $$$AssertEquals($ClassMethod(..#PORT, "ScheduleVendorStatus", tProtect), tProtect, "a privilege refusal is kept as it came")
    Set tLock = $System.Status.Error($Parameter(..#PORT, "CODEPRIVILEGE"), tMarker)
    Do $$$AssertEquals($ClassMethod(..#PORT, "ScheduleVendorStatus", tLock), tLock, "and so is the vendor's privilege code")
}

}
