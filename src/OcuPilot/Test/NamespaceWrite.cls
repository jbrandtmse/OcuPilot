/// <p>Pins Story 18.2's namespace writes on both callers of each tool (AD-53, AD-55): the screen's
/// Save (<class>OcuPilot.Test.NamespaceSaveFixture</class>) and row action
/// (<class>OcuPilot.Test.NamespaceActionFixture</class>), and the agent's mint and confirm
/// (<class>OcuPilot.Test.NamespaceConfirm</class>) -- one method per row of the spec's matrix, the
/// removal's impact (AD-8) and the install-namespace refusal (AD-10).</p>
/// <p>A write that should happen goes through <class>OcuPilot.Test.DeviceRecordPort</class>, which
/// records and sends it; the own-namespace legs write through
/// <class>OcuPilot.Test.AcceptPort</class>, which reads the instance and sends no write, so a
/// removed predicate shows as an accepted write and never as a deleted or repointed namespace.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the <code>USER</code>
/// and <code>IRISTEMP</code> databases, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because the class creates and deletes namespaces, web applications and a global
/// mapping (<class>OcuPilot.Test.NamespaceWriteProbe</class>) and sets the governance policy.
/// <method>OnBeforeAllTests</method> refuses anywhere it does not; every probe object is removed by
/// exact name before all, after each and after all, and a survivor fails the class.</p>
Class OcuPilot.Test.NamespaceWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_NAMESPACE_CONFIG";

Parameter PROBE = "OcuPilot.Test.NamespaceWriteProbe";

Parameter SAVE = "OcuPilot.Test.NamespaceSaveFixture";

Parameter ACTION = "OcuPilot.Test.NamespaceActionFixture";

Parameter CONFIRM = "OcuPilot.Test.NamespaceConfirm";

Parameter RECORD = "OcuPilot.Test.DeviceRecordPort";

Parameter ACCEPT = "OcuPilot.Test.AcceptPort";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.NamespaceCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.NamespaceUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.NamespaceDelete";

Parameter SCREEN = "osmgmt.namespaces";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter DELETEKEY = "osmgmt.namespaces.delete";

Parameter OWNCODE = "PROHIBITED.OCUPILOTNAMESPACE";

/// <p>The Save routes, relative to the API base.</p>
Parameter CREATEPATH = "/namespace";

Parameter EDITPATH = "/namespace/:id";

/// <p>The governance policy as it stood before the class ran, restored after each test.</p>
Property PreparedPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.NamespaceWrite creates and deletes namespaces, web applications and a mapping on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotNamespaceWritePort
    Do $ClassMethod(..#ACCEPT, "ReadThrough", 0)
    Do $ClassMethod(..#ACCEPT, "Clear")
    Do $ClassMethod(..#RECORD, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe namespace and application is removed by exact name")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

/// <p>Remove every probe object; a failing status when any survives or the configuration file no
/// longer validates or still names a probe namespace.</p>
Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
    If '$ClassMethod(..#PROBE, "CpfValid", .tNamesProbe) || tNamesProbe Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the configuration file does not validate, or names a probe namespace, after OcuPilot.Test.NamespaceWrite"))
    Quit tSC
}

/// <p>Create: <code>OCUPROBE182*</code> over <code>USER</code> answers 201 on both callers, the row
/// reads <code>TempGlobals</code> <code>IRISTEMP</code>, and no web application or mapping is
/// created with it.</p>
Method TestACreateRoundTripsOnBothCallers()
{
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    Set tName = "OCUPROBE182SC"
    Set tSC = ..Save("create", tName, {"Name": (tName), "Globals": "USER", "Routines": "USER"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "201 ", "the screen's create answers 201")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType") _ " " _ $ClassMethod(..#RECORD, "LastWriteBody"), "PUT {""Globals"":""USER"",""Routines"":""USER""}", "through the vendor's PUT, carrying the two fields")

    Set tAgent = "OCUPROBE182AC"
    Set tSC = ..Mint(..#CREATETOOL, tAgent, {"Name": (tAgent), "Globals": "user", "Routines": "USER"}, .tProposal, .tHttp)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted")
    Do $$$AssertEquals(..Confirm(tProposal), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastWriteBody"), "{""Globals"":""USER"",""Routines"":""USER""}", "sending each database in the list's own spelling")
    For tOne = tName, tAgent {
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tOne, "TempGlobals"), "IRISTEMP", tOne _ " is present and reads TempGlobals IRISTEMP")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "ApplicationsOf", tOne), "", tOne _ ": no web application is created with it")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "MappingCount", tOne), 0, tOne _ ": and no mapping")
    }
}

/// <p>The two Save routes over the wire, as the suite's account: <code>POST</code> creates and
/// answers 201 <code>{name, readBack}</code> as JSON, <code>PUT</code> edits and answers 200, and a
/// refused body answers 422 carrying each violation.</p>
Method TestTheSaveRoutesAnswerOverTheWire()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tName = "OCUPROBE182WR"
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, tUser, tPassword, .tStatus, .tBody, .tHeaders, {"Name": (tName), "Globals": "USER", "Routines": "USER"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the create answers 201: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("name") _ "|" _ tAnswer.%GetTypeOf("readBack"), 1: ""), tName _ "|object", "naming the namespace and its read-back")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ $Replace(..#EDITPATH, ":id", tName), tUser, tPassword, .tStatus, .tBody, .tHeaders, {"Routines": "IRISTEMP"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 200, "the edit answers 200: " _ $Extract(tBody, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "Routines"), "IRISTEMP", "and the instance holds it")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ $Replace(..#EDITPATH, ":id", tName), tUser, tPassword, .tStatus, .tBody, .tHeaders, {"Globals": "NOSUCHDB"}.%ToJSON(), "application/json")
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
    Do $$$AssertEquals(tStatus, 422, "a database the instance does not list is refused")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code") _ " " _ tAnswer.detail.violations.%Get(0).code, 1: ""), "NAMESPACE.VALIDATION NAMESPACE.GLOBALS.ABSENT", "on its field")
}

/// <p>Create, name taken: an existing name in another case is refused on Name at the Save and at
/// the mint, and no <code>PUT</code> is sent.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Screen.Tool.NamespaceCreate.CREATES</parameter> ->
/// the mint merges over the present namespace, the upsert is minted, and this goes red.</p>
Method TestATakenNameIsRefusedInAnyCase()
{
    Set tName = "OCUPROBE182TK"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a probe namespace is created")
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    ; The body differs from what the namespace holds, so an upsert read as an edit would have a
    ; change to propose.
    Set tBody = {"Name": "ocuprobe182tk", "Globals": "USER", "Routines": "IRISTEMP"}
    Set tSC = ..Save("create", "ocuprobe182tk", tBody, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Name:NAMESPACE.NAME.TAKEN", "the screen's create is refused on Name")
    Set tSC = ..Mint(..#CREATETOOL, "ocuprobe182tk", tBody, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tHttp = 400) && (tProblem [ "already present"), "the agent's create is refused at the mint as a name the instance holds (" _ tHttp _ " " _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "Routines"), "USER", "and the namespace is unchanged")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and no PUT is sent")
}

/// <p>Bad name: the corpus the instance refuses (a dot, a leading digit, a space, a <code>$</code>,
/// 65 characters) is refused on Name by the rules on both callers with no vendor write, and the
/// instance refuses every one of them itself; the names it accepts (<code>_</code>, <code>-</code>,
/// a leading <code>%</code>, lower case, 64 characters) pass the rules and the instance alike.</p>
Method TestTheNameRuleIsTheInstancesOwn()
{
    Set tLong = "OCUPROBE182" _ $Translate($Justify("", 54), " ", "X")
    Set tBad = $ListBuild("OCUPROBE182.X", "1OCUPROBE182", "OCUPROBE182 X", "OCUPROBE182$X", tLong)
    Set tGood = $ListBuild("OCUPROBE182_U", "OCUPROBE182-H", "%OCUPROBE182P", "ocuprobe182lc", $Extract(tLong, 1, 64))
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    For tI = 1:1:$ListLength(tBad) {
        Set tName = $List(tBad, tI)
        Do $ClassMethod(..#RECORD, "Clear")
        Set tSC = ..Save("create", tName, {"Name": (tName), "Globals": "USER", "Routines": "USER"}, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tFields _ " calls=" _ $ClassMethod(..#RECORD, "CallCount"), "422 Name:NAMESPACE.NAME.SHAPE calls=0", tName _ ": the screen refuses it on Name before any vendor call")
        Set tSC = ..Mint(..#CREATETOOL, tName, {"Name": (tName), "Globals": "USER", "Routines": "USER"}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "'Name'"), tName _ ": the mint refuses it on Name (" _ tProblem _ ")")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Attempt", tName, .tAnswer), tName _ ": the instance is asked")
        Do $$$AssertTrue((tAnswer < 200) || (tAnswer > 299), tName _ ": and refuses it too (" _ tAnswer _ ")")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, tName _ ": nothing is created")
    }
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "no vendor write was sent by the screen's Save")
    For tI = 1:1:$ListLength(tGood) {
        Set tName = $List(tGood, tI)
        Kill tViolations
        Do ##class(OcuPilot.Area.OsMgmt.NamespaceRules).NameViolation(tName, .tViolations)
        Do $$$AssertEquals(+$Get(tViolations), 0, tName _ ": the rule accepts it")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Attempt", tName, .tAnswer), tName _ ": the instance is asked")
        Do $$$AssertEquals(tAnswer, 201, tName _ ": and creates it")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", tName), tName _ ": which is removed")
    }
}

/// <p>Unknown database: a database field naming no database the instance lists is refused on that
/// field on both callers, and no <code>PUT</code> is sent.</p>
Method TestAnUnknownDatabaseIsRefusedOnItsField()
{
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    Set tName = "OCUPROBE182UD"
    Set tSC = ..Save("create", tName, {"Name": (tName), "Globals": "NOSUCHDB", "Routines": "USER", "TempGlobals": "NOSUCHDB"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Globals:NAMESPACE.GLOBALS.ABSENT,TempGlobals:NAMESPACE.TEMPGLOBALS.ABSENT", "the screen refuses each field naming no database")
    Set tSC = ..Mint(..#CREATETOOL, tName, {"Name": (tName), "Globals": "NOSUCHDB", "Routines": "USER"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "'Globals'"), "the mint refuses it on Globals (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "no PUT is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and nothing is created")
}

/// <p>Edit: a changed routines database sends the complete
/// <code>{Globals, Routines, TempGlobals}</code> on both callers, and the agent's diff shows the one
/// row (AD-4).</p>
Method TestAnEditSendsTheCompleteSet()
{
    Set tName = "OCUPROBE182ED"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a probe namespace is created")
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    Set tSC = ..Save("update", tName, {"Routines": "IRISTEMP"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "200 ", "the screen's edit answers 200")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastWriteBody"), "{""Globals"":""USER"",""Routines"":""IRISTEMP"",""TempGlobals"":""IRISTEMP""}", "sending the complete set with the one field changed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "Routines"), "IRISTEMP", "which the instance holds")

    Set tSC = ..Mint(..#UPDATETOOL, tName, {"Name": (tName), "Routines": "USER"}, .tProposal, .tHttp)
    Do $$$AssertStatusOK(tSC, "the agent's edit is minted")
    If '$IsObject(tProposal) Quit
    Do $$$AssertEquals(tProposal.changed.%Size() _ " " _ tProposal.changed.%Get(0).field, "1 Routines", "its diff shows the one row")
    Do $$$AssertEquals(..Confirm(tProposal), "200 ", "and it is confirmed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastWriteBody"), "{""Globals"":""USER"",""Routines"":""USER"",""TempGlobals"":""IRISTEMP""}", "sending the complete set")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "Routines"), "USER", "which the instance holds")
}

/// <p>Delete with bound applications: on both callers the namespace, its mapping and both of its
/// web applications are gone afterwards and <code>USER</code> and <code>IRISTEMP</code> remain; the
/// delete's query carries <code>name</code> alone. The agent's key is enabled for its leg.</p>
Method TestADeleteTakesItsApplicationsAndMappingAndLeavesItsDatabases()
{
    Do $$$AssertStatusOK(..EnableDelete(), "the agent's delete key is enabled")
    For tCase = $ListBuild("OCUPROBE182DS", "screen"), $ListBuild("OCUPROBE182DA", "agent") {
        Set tName = $List(tCase, 1)
        Set tApps = ..Seed(tName)
        Do $$$AssertEquals($ClassMethod(..#PROBE, "ApplicationsOf", tName), tApps, tName _ ": two applications are bound")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "MappingCount", tName), 1, tName _ ": and one global mapping")
        Set ^||OcuPilotNamespaceWritePort = ..#RECORD
        Do $ClassMethod(..#RECORD, "Clear")
        If $List(tCase, 2) = "screen" {
            Do $$$AssertEquals(..Act("delete", tName), "200 ", tName _ ": the screen's delete answers 200")
        } Else {
            Set tSC = ..Mint(..#DELETETOOL, tName, {"Name": (tName)}, .tProposal, .tHttp)
            Do $$$AssertStatusOK(tSC, tName _ ": the agent's delete is minted")
            Do $$$AssertEquals(..Confirm(tProposal), "200 ", tName _ ": and confirmed")
        }
        Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType") _ " " _ $ClassMethod(..#RECORD, "LastQueryKeys"), "DELETE name", tName _ ": the delete's query carries the name alone")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, tName _ ": the namespace is gone")
        For tI = 1:1:$Length(tApps, ",") {
            Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsApplication", $Piece(tApps, ",", tI)), 0, tName _ ": " _ $Piece(tApps, ",", tI) _ " is gone with it")
        }
        Do $$$AssertEquals($ClassMethod(..#PROBE, "MappingCount", tName), 0, tName _ ": and so is its mapping")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsDatabase", "USER") _ $ClassMethod(..#PROBE, "HoldsDatabase", "IRISTEMP"), "11", tName _ ": USER and IRISTEMP remain")
    }
}

/// <p>The removal's impact (AD-8), from <method>OcuPilot.Kernel.Proposal.Impact.Of</method>, from the
/// dialog's route and on the agent's proposal row: both bound applications, deleted with it, and
/// the two databases, which stay.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Impact.KindOf</method> omits
/// <code>namespace-delete</code> -> no impact is answered and this goes red.</p>
Method TestTheImpactNamesTheApplicationsAndTheDatabasesThatStay()
{
    Set tName = "OCUPROBE182IM"
    Set tApps = ..Seed(tName)
    Set tExpected = "namespace-delete||2|" _ tApps _ "||2|IRISTEMP,USER|"
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("namespace", "instance", tName, .tRef)
    Set tFresh = $ClassMethod(..#PROBE, "Read", tName)
    Set tImpact = ##class(OcuPilot.Kernel.Proposal.Impact).Of("osmgmt.namespaces.delete", tRef, $Select($IsObject(tFresh): tFresh.%ToJSON(), 1: ""), "{}", "[]")
    Do $$$AssertEquals(..Said(tImpact), tExpected, "Impact.Of names both applications and the databases that stay")
    Do $$$AssertEquals(..Said(..RouteImpact(tName, .tStatus)), tExpected, "and so does the dialog's route (" _ tStatus _ ")")
    Set tSC = ..Mint(..#DELETETOOL, tName, {"Name": (tName)}, .tProposal, .tHttp, , .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurnKey, $Username, .tRows)
    Set tRow = $Select($IsObject($Get(tRows)) && (tRows.%Size() = 1): tRows.%Get(0), 1: "")
    Do $$$AssertEquals(..Said($Select($IsObject(tRow): tRow.%Get("impact"), 1: "")), tExpected, "and so does the agent's proposal row")
}

/// <p>Governance (AD-22): at the baseline the agent's delete is refused
/// <code>GOVERNANCE.DISABLED</code> and changes nothing, while the screen's own delete proceeds.</p>
Method TestAtTheBaselineTheAgentsDeleteIsDisabledAndTheScreensProceeds()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    Set tName = "OCUPROBE182GB"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a probe namespace is created")
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    Set tSC = ..Mint(..#DELETETOOL, tName, {"Name": (tName)}, .tProposal, .tHttp)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted")
    Do $$$AssertEquals(..Confirm(tProposal), "403 " _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "its confirm is refused as disabled by policy")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 1, "and the namespace is still there")
    Do $$$AssertEquals(..Act("delete", tName), "200 ", "the screen's delete proceeds")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and removes it")
}

/// <p>Own namespace (AD-10): for the namespace this process runs in and for <code>%SYS</code>, a
/// delete and a <code>Globals</code> or <code>Routines</code> change are refused
/// <code>PROHIBITED.OCUPILOTNAMESPACE</code> on both callers with no write sent, and a
/// <code>TempGlobals</code>-only change is permitted and reaches the port; the dialog's route answers
/// the refusal. Every write goes to <class>OcuPilot.Test.AcceptPort</class>, which sends none.</p>
/// <p>Mutation (Rule 19): remove the <parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTNAMESPACE</parameter>
/// arm -> each refused leg is an accepted write recorded by the port, and this goes red.</p>
Method TestTheInstallNamespaceAndSysAreRefused()
{
    Do $$$AssertEquals($ZConvert($NAMESPACE, "U"), ..InstallNamespace(), "this process runs where OcuPilot's API application runs, so its first target is the install namespace")
    Do $$$AssertStatusOK(..EnableDelete(), "the agent's delete key is enabled, so only the prohibited set stands in the way")
    Set ^||OcuPilotNamespaceWritePort = ..#ACCEPT
    Do $ClassMethod(..#ACCEPT, "ReadThrough", 1)
    For tTarget = $NAMESPACE, "%SYS" {
        Set tHeld = $ClassMethod(..#PROBE, "Read", tTarget)
        Do $$$AssertTrue($IsObject(tHeld), tTarget _ " is read")
        If '$IsObject(tHeld) Continue
        Set tOther = $Select($ZConvert(tHeld.TempGlobals, "U") = "USER": "IRISTEMP", 1: "USER")
        For tCase = $ListBuild("delete", ""), $ListBuild("update", "Globals"), $ListBuild("update", "Routines") {
            Set tLabel = tTarget _ " " _ $List(tCase, 1) _ " " _ $List(tCase, 2)
            Do $ClassMethod(..#ACCEPT, "Clear")
            If $List(tCase, 1) = "delete" {
                Do $$$AssertEquals(..Act("delete", tTarget), "403 " _ ..#OWNCODE, tLabel _ ": the screen's row action is refused")
                Set tSC = ..Mint(..#DELETETOOL, tTarget, {"Name": (tTarget)}, .tProposal, .tHttp)
            } Else {
                Set tBody = {}
                Do tBody.%Set($List(tCase, 2), "USER", "string")
                Set tSC = ..Save("update", tTarget, tBody, .tHttp, .tCode, .tFields)
                Do $$$AssertEquals(tHttp _ " " _ tCode, "403 " _ ..#OWNCODE, tLabel _ ": the screen's Save is refused")
                Do tBody.%Set("Name", tTarget, "string")
                Set tSC = ..Mint(..#UPDATETOOL, tTarget, tBody, .tProposal, .tHttp)
            }
            Do $$$AssertStatusOK(tSC, tLabel _ ": the agent's proposal is minted")
            Do $$$AssertEquals(..Confirm(tProposal), "403 " _ ..#OWNCODE, tLabel _ ": and its confirm is refused")
            Do $$$AssertEquals(..Writes(), "", tLabel _ ": no write reached the port")
        }
        Do $ClassMethod(..#ACCEPT, "Clear")
        Set tSC = ..Save("update", tTarget, {"TempGlobals": (tOther)}, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tCode _ " " _ ..Writes(), "200  PUT", tTarget _ ": a TempGlobals-only Save is permitted")
        Do $ClassMethod(..#ACCEPT, "Clear")
        Set tSC = ..Mint(..#UPDATETOOL, tTarget, {"Name": (tTarget), "TempGlobals": (tOther)}, .tProposal, .tHttp)
        Do $$$AssertEquals(..Confirm(tProposal) _ " " _ ..Writes(), "200  PUT", tTarget _ ": and so is the agent's")
        Set tImpact = ..RouteImpact(tTarget, .tStatus)
        Set tRefused = $Select($IsObject(tImpact) && $IsObject(tImpact.refused): tImpact.refused.code _ "|" _ tImpact.refused.reason, 1: "")
        Do $$$AssertEquals(tRefused, ..#OWNCODE _ "|" _ ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(..#OWNCODE), tTarget _ ": the delete dialog's advisory states the refusal")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tTarget, "Globals"), tHeld.Globals, tTarget _ ": is unchanged")
    }
}

/// <p>The screen's Save of <var>pKind</var> (<code>create</code> or <code>update</code>) for
/// <var>pName</var> with <var>pBody</var>: <var>pHttp</var> the status it would answer,
/// <var>pCode</var> the refusal's code, and <var>pFields</var> its violations as
/// <code>field:code</code>, comma-separated.</p>
Method Save(pKind As %String, pName As %String, pBody As %DynamicObject, Output pHttp As %Integer, Output pCode As %String, Output pFields As %String) As %Status
{
    Set pCode = ""
    Set pFields = ""
    If pKind = "create" {
        Set tSC = $ClassMethod(..#SAVE, "Create", pName, pBody, .tHttp, .tFault, .tViolations, .tReadBack)
        Set pHttp = 201
    } Else {
        Set tSC = $ClassMethod(..#SAVE, "Update", pName, pBody, .tHttp, .tFault, .tViolations, .tReadBack)
        Set pHttp = 200
    }
    If $Get(tViolations) > 0 {
        Set pHttp = 422
        For tI = 1:1:tViolations {
            Set pFields = pFields _ $Select(pFields = "": "", 1: ",") _ $List(tViolations(tI), 1) _ ":" _ $List(tViolations(tI), 2)
        }
        Quit $$$OK
    }
    If $$$ISERR(tSC) {
        Set pHttp = +$Get(tHttp)
        Set pCode = $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: $System.Status.GetErrorText(tSC))
    }
    Quit $$$OK
}

/// <p>Mint <var>pToolClass</var>'s proposal for <var>pName</var> from <var>pArgs</var> for this
/// process's user over a completed turn seeded for it; <var>pProposal</var> is <code>""</code> when
/// the mint refused, with its problem in <var>pProblem</var>.</p>
Method Mint(pToolClass As %String, pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pProblem As %String, Output pTurnKey As %String) As %Status
{
    Set pProposal = ""
    Set pHttp = 0
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(pToolClass, "DESCRIPTORCLASS"), $Parameter(pToolClass, "TOOLNAME"), $Username, "", pTurnKey, pArgs, ..#LIMITS, .tResult, .pHttp, .tFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pName, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
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

/// <p>Send the screen's row action <var>pAction</var> for <var>pId</var>, answering
/// <code>http code</code>.</p>
Method Act(pAction As %String, pId As %String) As %String
{
    Set tBody = {}
    Do tBody.%Set("action", pAction, "string")
    Do tBody.%Set("id", pId, "string")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .tAnswer, .tStatus)
    Set tCode = ""
    Try { Set tCode = ##class(%DynamicObject).%FromJSON(tAnswer).%Get("code") } Catch {}
    Quit tStatus _ " " _ tCode
}

/// <p>The dialog's impact for deleting <var>pName</var>, read over the wire as the suite's account,
/// or <code>""</code>; <var>pStatus</var> is the route's status.</p>
Method RouteImpact(pName As %String, Output pStatus As %Integer) As %DynamicObject
{
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/" _ ..#SCREEN _ "/impact?action=delete&id=" _ $ZConvert(pName, "O", "URL")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders)
    Set tImpact = ""
    Try { Set tImpact = ##class(%DynamicObject).%FromJSON(tRaw).%Get("impact") } Catch {}
    Quit tImpact
}

/// <p>The namespace OcuPilot's own API application is configured to run in, upper-cased, or
/// <code>""</code> when it cannot be read.</p>
ClassMethod InstallNamespace() As %String
{
    Set tName = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        If $$$ISOK(##class(Security.Applications).Get("/api/ocupilot", .tProperties)) Set tName = $ZConvert($Get(tProperties("NameSpace")), "U")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tName = ""
    }
    Quit tName
}

/// <p><var>pImpact</var> as <code>kind|refused|part...</code>, each part
/// <code>count|names|unchecked</code>.</p>
ClassMethod Said(pImpact As %DynamicObject) As %String
{
    If '$IsObject(pImpact) Quit "(no impact)"
    Set tOut = pImpact.%Get("kind") _ "|" _ $Select($IsObject(pImpact.%Get("refused")): pImpact.refused.code, 1: "")
    Set tIterator = pImpact.%Get("parts").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tPart) {
        Set tNames = ""
        Set tNameIterator = tPart.%Get("names").%GetIterator()
        While tNameIterator.%GetNext(.tNameIndex, .tName) {
            Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tName
        }
        Set tOut = tOut _ "|" _ tPart.%Get("count") _ "|" _ tNames _ "|" _ tPart.%Get("unchecked")
    }
    Quit tOut
}

/// <p>Create the probe namespace <var>pName</var> over <code>USER</code>, two web applications bound
/// to it and one global mapping in it, answering the two applications' paths, sorted and
/// comma-separated.</p>
Method Seed(pName As %String) As %String
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", pName), pName _ " is created")
    Set tApps = ""
    For tSuffix = "a", "b" {
        Set tPath = "/csp/" _ $ZConvert(pName, "L") _ tSuffix
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddApplication", tPath, pName), tPath _ " is bound to it")
        Set tApps = tApps _ $Select(tApps = "": "", 1: ",") _ tPath
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", pName, "OcuProbe182Map"), "a global mapping is seeded in it")
    Quit tApps
}

/// <p>Enable the agent's namespace delete key, over the snapshot this class took.</p>
Method EnableDelete() As %Status
{
    Kill tSettings
    Set tSettings(..#DELETEKEY) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>The write request types <parameter>ACCEPT</parameter> was asked for since it was cleared,
/// comma-separated.</p>
Method Writes() As %String
{
    Set tWrites = ""
    Set tTypes = $ClassMethod(..#ACCEPT, "CallTypes")
    For tI = 1:1:$Length(tTypes, ",") {
        Set tType = $Piece(tTypes, ",", tI)
        If (tType = "PUT") || (tType = "DELETE") Set tWrites = tWrites _ $Select(tWrites = "": "", 1: ",") _ tType
    }
    Quit tWrites
}

}
