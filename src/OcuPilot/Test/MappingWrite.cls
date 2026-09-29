/// <p>Pins Story 18.14's mapping writes on both callers of each tool (AD-53, AD-55): the screen's Save
/// (<class>OcuPilot.Test.MappingSaveFixture</class>) and row action
/// (<class>OcuPilot.Test.MappingActionFixture</class>), and the agent's mint and confirm
/// (<class>OcuPilot.Test.NamespaceConfirm</class>) -- one method per row of the spec's matrix, the
/// system-global effect and OcuPilot's own mappings (AD-10).</p>
/// <p>A write that should happen goes through <class>OcuPilot.Test.MappingRecordPort</class>, which
/// records and sends it; the install-namespace legs write through
/// <class>OcuPilot.Test.MappingAcceptPort</class>, which reads the instance and sends no write, so a
/// removed predicate shows as an accepted write and never as a moved mapping. The <code>%ALL</code>
/// legs ask the prohibited set directly (<class>OcuPilot.Test.MappingAllTargetFixture</class>).</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving in the namespace it
/// runs these tests in, the <code>USER</code> and <code>IRISTEMP</code> databases, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes
/// namespaces and mappings (<class>OcuPilot.Test.MappingProbe</class>).
/// <method>OnBeforeAllTests</method> refuses anywhere it does not; every probe namespace is removed by
/// exact name, with its mappings, before all, after each and after all, and a survivor fails the
/// class.</p>
Class OcuPilot.Test.MappingWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_NAMESPACE_CONFIG";

Parameter PROBE = "OcuPilot.Test.MappingProbe";

Parameter SAVE = "OcuPilot.Test.MappingSaveFixture";

Parameter ACTION = "OcuPilot.Test.MappingActionFixture";

Parameter CONFIRM = "OcuPilot.Test.NamespaceConfirm";

Parameter RECORD = "OcuPilot.Test.MappingRecordPort";

Parameter ACCEPT = "OcuPilot.Test.MappingAcceptPort";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter OWNCODE = "PROHIBITED.OCUPILOTMAPPING";

Parameter EFFECT = "MAPPING.SYSTEMGLOBAL";

/// <p>The probe namespace every leg writes in.</p>
Parameter NS = "OCUPROBE1814A";

/// <p>The mapping routes, relative to the API base, as the router declares them.</p>
Parameter CREATEPATH = "/mapping/:kind";

Parameter EDITPATH = "/mapping/:kind/:id";

Parameter FORMPATH = "/mapping/:kind/form";

Parameter NAMEPATH = "/mapping/:kind/name";

/// <p>The governance policy as it stood before the class ran, restored after each test.</p>
Property PreparedPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.MappingWrite creates and deletes namespaces and mappings on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnBeforeOneTest() As %Status
{
    Quit $ClassMethod(..#PROBE, "Add", ..#NS)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotNamespaceWritePort
    Do $ClassMethod(..#ACCEPT, "Clear")
    Do $ClassMethod(..#RECORD, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe namespace is removed by exact name, with its mappings")
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
    If '$ClassMethod(..#PROBE, "CpfValid", .tNamesProbe) || tNamesProbe Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the configuration file does not validate, or names a probe namespace, after OcuPilot.Test.MappingWrite"))
    Quit tSC
}

/// <p>Create: a global, a routine and a package mapping answer 201 on the screen's Save and are
/// confirmed on the agent's, each through the vendor's <code>PUT</code> with its database in the list's
/// own spelling, and the instance holds each one.</p>
Method TestACreateRoundTripsOnBothCallers()
{
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    For tKind = "global", "routine", "package" {
        Set tScreen = "OcuProbe1814S" _ $ZConvert($Extract(tKind), "U")
        Set tSC = ..Save(tKind, "create", ..#NS, tScreen, {"Database": "user"}, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "201 ", tKind _ ": the screen's create answers 201")
        Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType") _ " " _ $ClassMethod(..#RECORD, "LastWriteBody"), "PUT {""Database"":""USER""}", tKind _ ": through the vendor's PUT, the database in the list's spelling")
        Set tAgent = "OcuProbe1814A" _ $ZConvert($Extract(tKind), "U")
        Set tSC = ..Mint(..Tool(tKind, "Create"), {"Namespace": (..#NS), "Name": (tAgent), "Database": "USER"}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, tKind _ ": the agent's create is minted " _ tProblem)
        Do $$$AssertEquals(..Confirm(tProposal), "200 ", tKind _ ": and confirmed")
        For tOne = tScreen, tAgent {
            Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tKind, ..#NS, tOne, "Database"), "USER", tKind _ " " _ tOne _ ": the instance holds it")
        }
    }
}

/// <p>The mapping routes over the wire, as the suite's account: <code>POST /mapping/:kind</code>
/// creates and answers 201 <code>{id, namespace, name, readBack}</code> as JSON, <code>GET
/// /mapping/:kind/name</code> answers the name taken, <code>GET /mapping/:kind/form</code> answers
/// the stored mapping with the form's databases, <code>PUT /mapping/:kind/:id</code> edits by the
/// encoded composite id and answers 200, a refused body answers 422 carrying each violation, and an
/// unknown kind answers 404.</p>
Method TestTheSaveRoutesAnswerOverTheWire()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tName = "OcuProbe1814W"
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ $Replace(..#CREATEPATH, ":kind", "global"), tUser, tPassword, .tStatus, .tBody, .tHeaders, {"Namespace": (..#NS), "Name": (tName), "Database": "USER"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the create answers 201: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("id") _ "|" _ tAnswer.%Get("namespace") _ "|" _ tAnswer.%Get("name") _ "|" _ tAnswer.%GetTypeOf("readBack"), 1: ""), $ClassMethod(..#PROBE, "Id", ..#NS, tName) _ "|" _ ..#NS _ "|" _ tName _ "|object", "naming the composite id, the namespace, the name and its read-back")

    Set tQuery = "?namespace=" _ ..#NS _ "&name=" _ tName
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ $Replace(..#NAMEPATH, ":kind", "global") _ tQuery, tUser, tPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the name check answers 200: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("name") _ "|" _ tAnswer.%Get("taken"), 1: ""), tName _ "|1", "and says the name is taken")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ $Replace(..#FORMPATH, ":kind", "global") _ tQuery, tUser, tPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the form read answers 200: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("namespace") _ "|" _ tAnswer.%GetTypeOf("databases") _ "|" _ $Select($IsObject(tAnswer.%Get("mapping")): tAnswer.%Get("mapping").%Get("Database"), 1: ""), 1: ""), ..#NS _ "|array|USER", "carrying the namespace, the databases to choose from and the stored mapping")

    Set tPath = tBase _ $Replace($Replace(..#EDITPATH, ":kind", "global"), ":id", ##class(OcuPilot.Kernel.EntityId).Encode($ClassMethod(..#PROBE, "Id", $ZConvert(..#NS, "L"), tName)))
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tPath, tUser, tPassword, .tStatus, .tBody, .tHeaders, {"Database": "IRISTEMP"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 200, "the edit by the encoded composite id answers 200: " _ $Extract(tBody, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "global", ..#NS, tName, "Database"), "IRISTEMP", "and the instance holds it")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tPath, tUser, tPassword, .tStatus, .tBody, .tHeaders, {"Database": "NOSUCHDB"}.%ToJSON(), "application/json")
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
    Do $$$AssertEquals(tStatus, 422, "a database the instance does not list is refused")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code") _ " " _ tAnswer.detail.violations.%Get(0).code, 1: ""), "MAPPING.VALIDATION MAPPING.DATABASE.ABSENT", "on its field")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ $Replace(..#CREATEPATH, ":kind", "nosuchkind"), tUser, tPassword, .tStatus, .tBody, .tHeaders, {"Namespace": (..#NS), "Name": (tName), "Database": "USER"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 404, "a kind outside global, routine and package answers 404")
}

/// <p>Taken: a name the namespace already maps is refused on Name at the Save and at the mint, and no
/// <code>PUT</code> is sent.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Screen.Tool.MappingCreate.CREATES</parameter> -> the
/// mint merges over the present mapping, the upsert is minted, and this goes red.</p>
Method TestATakenNameIsRefused()
{
    Set tName = "OcuProbe1814TK"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#NS, tName), "a probe mapping is seeded")
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    ; The database differs from what the mapping holds, so an upsert read as an edit would have a
    ; change to propose.
    Set tSC = ..Save("global", "create", ..#NS, tName, {"Database": "IRISTEMP"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Name:MAPPING.NAME.TAKEN", "the screen's create is refused on Name")
    Set tSC = ..Mint(..Tool("global", "Create"), {"Namespace": (..#NS), "Name": (tName), "Database": "IRISTEMP"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tHttp = 400) && (tProblem [ "already present"), "the agent's create is refused at the mint as a mapping the namespace holds (" _ tHttp _ " " _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "global", ..#NS, tName, "Database"), "USER", "and the mapping is unchanged")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "and no PUT is sent")
}

/// <p>Unknown database and the routine suffix: <code>NOSUCHDB</code> is refused on Database and
/// <code>OcuProbe1814R_mac</code> on Name, on both callers, before any write.</p>
Method TestAnUnknownDatabaseAndALowerCaseSuffixAreRefusedOnTheirFields()
{
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    Set tSC = ..Save("global", "create", ..#NS, "OcuProbe1814UD", {"Database": "NOSUCHDB", "LockDatabase": "NOSUCHDB"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Database:MAPPING.DATABASE.ABSENT,LockDatabase:MAPPING.LOCKDATABASE.ABSENT", "the screen refuses each field naming no database")
    Set tSC = ..Mint(..Tool("global", "Create"), {"Namespace": (..#NS), "Name": "OcuProbe1814UD", "Database": "NOSUCHDB"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "'Database'"), "the mint refuses it on Database (" _ tProblem _ ")")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = ..Save("routine", "create", ..#NS, "OcuProbe1814R_mac", {"Database": "USER"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields _ " calls=" _ $ClassMethod(..#RECORD, "CallCount"), "422 Name:MAPPING.NAME.SHAPE calls=0", "a lower-case routine suffix is refused on Name before any port call")
    Set tSC = ..Mint(..Tool("routine", "Create"), {"Namespace": (..#NS), "Name": "OcuProbe1814R_mac", "Database": "USER"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "'Name'"), "and at the mint (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "WriteCount"), 0, "no PUT is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "routine", ..#NS) _ "|" _ $ClassMethod(..#PROBE, "Names", "global", ..#NS), "|", "and nothing is created")
}

/// <p>Edit: a changed database sends the complete template set on both callers, and the agent's diff
/// shows the one row (AD-4).</p>
Method TestAnEditSendsTheCompleteSet()
{
    Set tName = "OcuProbe1814ED"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#NS, tName), "a probe mapping is seeded")
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    Set tSC = ..Save("global", "update", ..#NS, tName, {"Database": "IRISTEMP"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "200 ", "the screen's edit answers 200")
    Set tSent = ""
    Try { Set tSent = ##class(%DynamicObject).%FromJSON($ClassMethod(..#RECORD, "LastWriteBody")) } Catch {}
    Do $$$AssertEquals($Select($IsObject(tSent): tSent.%Get("Database") _ "|" _ tSent.%IsDefined("LockDatabase") _ "|" _ tSent.%IsDefined("Collation"), 1: ""), "IRISTEMP|1|1", "sending the complete template set with the one field changed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "global", ..#NS, tName, "Database"), "IRISTEMP", "which the instance holds")

    Set tSC = ..Mint(..Tool("global", "Update"), {"Namespace": (..#NS), "Name": (tName), "Database": "USER"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's edit is minted " _ tProblem)
    If '$IsObject(tProposal) Quit
    Do $$$AssertEquals(tProposal.changed.%Size() _ " " _ tProposal.changed.%Get(0).field, "1 Database", "its diff shows the one row")
    Do $$$AssertEquals(..Confirm(tProposal), "200 ", "and it is confirmed")
    Set tSent = ""
    Try { Set tSent = ##class(%DynamicObject).%FromJSON($ClassMethod(..#RECORD, "LastWriteBody")) } Catch {}
    Do $$$AssertEquals($Select($IsObject(tSent): tSent.%Get("Database") _ "|" _ tSent.%IsDefined("LockDatabase") _ "|" _ tSent.%IsDefined("Collation"), 1: ""), "USER|1|1", "sending the complete set")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "global", ..#NS, tName, "Database"), "USER", "which the instance holds")
}

/// <p>Delete: on both callers, the vendor's bodyless <code>DELETE</code> answers 200 and the mapping
/// is absent afterwards; the screen's global delete runs through the row action's own route, and a
/// routine and a package delete through the shipped port.</p>
Method TestADeleteRemovesTheMappingOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#NS, "OcuProbe1814DS"), "a global mapping is seeded for the screen")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#NS, "OcuProbe1814DA"), "and one for the agent")
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    Do $$$AssertEquals(..Act("osmgmt.globalmappings", "delete", $ClassMethod(..#PROBE, "Id", ..#NS, "OcuProbe1814DS")), "200 ", "the screen's delete answers 200")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "LastType") _ " " _ $ClassMethod(..#RECORD, "LastWriteBody"), "DELETE ", "through the vendor's DELETE, with no body")
    Set tSC = ..Mint(..Tool("global", "Delete"), {"Namespace": (..#NS), "Name": "OcuProbe1814DA"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted " _ tProblem)
    Do $$$AssertEquals($Select($IsObject(tProposal): tProposal.%Get("target").%Get("type") _ " " _ tProposal.%Get("target").%Get("id"), 1: ""), "global-mapping " _ $ClassMethod(..#PROBE, "Id", $ZConvert(..#NS, "L"), "OcuProbe1814DA"), "addressed by the composite id, its namespace part folded")
    Do $$$AssertEquals(..Confirm(tProposal), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "global", ..#NS), "", "both global mappings are gone")
    For tKind = "routine", "package" {
        Set tName = "OcuProbe1814D" _ $ZConvert($Extract(tKind), "U")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", tKind, ..#NS, tName), tKind _ ": a mapping is seeded")
        Do $$$AssertEquals(..Act("osmgmt." _ tKind _ "mappings", "delete", $ClassMethod(..#PROBE, "Id", ..#NS, tName)), "200 ", tKind _ ": the screen's delete answers 200")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", tKind, ..#NS), "", tKind _ ": and the mapping is gone")
    }
}

/// <p>A global mapping whose name begins with <code>%</code>, with and without a subscript range, is
/// permitted on both callers; the agent's proposal is minted destructive with the system-global
/// consequence, for a create and for an edit. A routine or package create and a delete carry no such
/// effect.</p>
/// <p>Mutation (Rule 19): remove the <code>global-mapping</code> arm of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.WeakensByEffect</method> -> the create cards are not
/// destructive and this goes red.</p>
Method TestASystemGlobalMappingIsPermittedAtTheStrongestConfirmation()
{
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    For tName = "%OcuProbe1814", "%OcuProbe1814S(""a""):(""m"")" {
        Set tSC = ..Mint(..Tool("global", "Create"), {"Namespace": (..#NS), "Name": (tName), "Database": "USER"}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, tName _ ": the agent's create is minted " _ tProblem)
        Do $$$AssertEquals(..Marked(tProposal), "1|" _ ..#EFFECT, tName _ ": destructive, carrying the system-global consequence")
        Do $$$AssertEquals(..Confirm(tProposal), "200 ", tName _ ": and it is confirmed")
    }
    Set tSC = ..Save("global", "create", ..#NS, "%OcuProbe1814V", {"Database": "USER"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "201 ", "the screen's create of a system global answers 201")
    Set tSC = ..Mint(..Tool("global", "Update"), {"Namespace": (..#NS), "Name": "%OcuProbe1814", "Database": "IRISTEMP"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals(..Marked(tProposal), "1|" _ ..#EFFECT, "an edit of a system global's mapping carries it too")
    Set tSC = ..Mint(..Tool("global", "Delete"), {"Namespace": (..#NS), "Name": "%OcuProbe1814"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals(..Marked(tProposal), "1|", "a delete is destructive and carries no system-global effect")
    Set tSC = ..Mint(..Tool("routine", "Create"), {"Namespace": (..#NS), "Name": "%OcuProbe1814R", "Database": "USER"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals(..Marked(tProposal), "0|", "a routine create carries none")
    Set tSC = ..Mint(..Tool("package", "Create"), {"Namespace": (..#NS), "Name": "%OcuProbe1814P", "Database": "USER"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals(..Marked(tProposal), "0|", "nor does a package create")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "global", ..#NS), "%OcuProbe1814,%OcuProbe1814S,%OcuProbe1814S(""a""):(""m""),%OcuProbe1814V", "the instance holds the system-global mappings, the subscript's base mapping among them")
}

/// <p>OcuPilot's own mappings (AD-10): in the namespace this process runs in, a create of a name
/// beginning with OcuPilot in any case, and an edit and a delete of OcuPilot's own
/// <code>OcuPilot*</code> global mapping, are refused <code>PROHIBITED.OCUPILOTMAPPING</code> on both
/// callers with no write reaching the port; the same name in a probe namespace is permitted. Every
/// write goes to <class>OcuPilot.Test.MappingAcceptPort</class>, which sends none.</p>
/// <p>Mutation (Rule 19): remove the <code>IsOwnMapping</code> arms of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Mapping</method> and <method>OcuPilot.Kernel.Proposal.Prohibited.Created</method>
/// -> each refused leg is an accepted write recorded by the port, and this goes red.</p>
Method TestOcuPilotsOwnMappingsAreRefusedInTheInstallNamespace()
{
    Set tOwnNs = $ZConvert($NAMESPACE, "U")
    Do $$$AssertEquals(tOwnNs, ##class(OcuPilot.Test.NamespaceWrite).InstallNamespace(), "this process runs where OcuPilot's API application runs")
    Set tOwn = "OcuPilot*"
    Do $$$AssertTrue($ClassMethod(..#PROBE, "HoldsMapping", "global", tOwnNs, tOwn), "OcuPilot's own global mapping is present")
    Set tHeld = $ClassMethod(..#PROBE, "Stored", "global", tOwnNs, tOwn, "Database")
    Set ^||OcuPilotNamespaceWritePort = ..#ACCEPT
    For tName = "OcuPilotProbe1814", "OCUPILOTPROBE1814U", "ocupilotprobe1814l" {
        Do $ClassMethod(..#ACCEPT, "Clear")
        Set tSC = ..Save("global", "create", tOwnNs, tName, {"Database": "USER"}, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tCode, "403 " _ ..#OWNCODE, tName _ ": the screen's create is refused")
        Set tSC = ..Mint(..Tool("global", "Create"), {"Namespace": (tOwnNs), "Name": (tName), "Database": "USER"}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, tName _ ": the agent's create is minted " _ tProblem)
        Do $$$AssertEquals(..Confirm(tProposal), "403 " _ ..#OWNCODE, tName _ ": and its confirm is refused")
        Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", tName _ ": no write reached the port")
    }
    For tKind = "routine", "package" {
        Do $ClassMethod(..#ACCEPT, "Clear")
        Set tSC = ..Save(tKind, "create", tOwnNs, "OcuPilotProbe1814", {"Database": "USER"}, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tCode _ " " _ $ClassMethod(..#ACCEPT, "Writes"), "403 " _ ..#OWNCODE _ " ", tKind _ ": a create is refused with no write")
    }
    Do $ClassMethod(..#ACCEPT, "Clear")
    Set tOther = $Select(tHeld = "USER": "IRISTEMP", 1: "USER")
    Set tSC = ..Save("global", "update", tOwnNs, tOwn, {"Database": (tOther)}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "403 " _ ..#OWNCODE, "the screen's edit of OcuPilot's own mapping is refused")
    Set tSC = ..Mint(..Tool("global", "Update"), {"Namespace": (tOwnNs), "Name": (tOwn), "Database": (tOther)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's edit is minted " _ tProblem)
    Do $$$AssertEquals(..Confirm(tProposal), "403 " _ ..#OWNCODE, "and its confirm is refused")
    Do $$$AssertEquals(..Act("osmgmt.globalmappings", "delete", $ClassMethod(..#PROBE, "Id", tOwnNs, tOwn)), "403 " _ ..#OWNCODE, "the screen's delete is refused")
    Set tSC = ..Mint(..Tool("global", "Delete"), {"Namespace": (tOwnNs), "Name": (tOwn)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted " _ tProblem)
    Do $$$AssertEquals(..Confirm(tProposal), "403 " _ ..#OWNCODE, "and its confirm is refused")
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", "no write reached the port")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "global", tOwnNs, tOwn, "Database"), tHeld, "and OcuPilot's own mapping is unchanged")

    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    Set tSC = ..Save("global", "create", ..#NS, "OcuPilotProbe1814", {"Database": "USER"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "201 ", "the same name in a probe namespace is permitted")
}

/// <p>OcuPilot's own mappings in <code>%ALL</code> (AD-10): the prohibited set, asked directly about
/// a create, an edit and a delete of a <code>%ALL</code> mapping whose name begins with OcuPilot in
/// any case, refuses each <code>PROHIBITED.OCUPILOTMAPPING</code>, and permits the same writes to a
/// probe name there.</p>
Method TestOcuPilotsOwnMappingsAreRefusedInAll()
{
    For tCase = $ListBuild("Create", "OcuPilotProbe1814", 1), $ListBuild("Update", "ocupilotProbe1814", 1), $ListBuild("Delete", "OCUPILOTPROBE1814", 1), $ListBuild("Create", "OcuProbe1814All", 0), $ListBuild("Update", "OcuProbe1814All", 0), $ListBuild("Delete", "OcuProbe1814All", 0) {
        Set tTool = ..Tool("global", $List(tCase, 1))
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("global-mapping", "instance", $ClassMethod(..#PROBE, "Id", "%ALL", $List(tCase, 2)), .tRef)
        Set tPayload = $Select($List(tCase, 1) = "Delete": {"Database": "USER", "LockDatabase": "", "Collation": 5}, 1: {"Database": "IRISTEMP"})
        Set tDiff = $Select($List(tCase, 1) = "Delete": [], 1: [{"field": "Database", "before": "USER", "after": "IRISTEMP"}])
        Set tSC = ##class(OcuPilot.Test.MappingAllTargetFixture).Prohibits($Parameter(tTool, "TOOLNAME"), tRef, tPayload.%ToJSON(), tDiff.%ToJSON(), .tProhibits, .tCode)
        Do $$$AssertStatusOK(tSC, $ListToString(tCase, " ") _ ": the set answers")
        Do $$$AssertEquals(tProhibits _ " " _ tCode, $Select($List(tCase, 3): "1 " _ ..#OWNCODE, 1: "0 "), $ListToString(tCase, " ") _ ": " _ $Select($List(tCase, 3): "refused", 1: "permitted"))
    }
}

/// <p>By overlap, not by prefix (AD-10 as amended, DW-1803): in the namespace this process runs in, a
/// mapping whose pattern or range covers OcuPilot's own names -- <code>O*</code>, <code>Ocu*</code>,
/// <code>*</code>, a range spanning them, a range open at its upper end (<code>O:</code>,
/// <code>:</code>), a routine pattern with a type suffix, and a pattern, name range or subscript
/// range that begins with the stem itself -- is refused
/// <code>PROHIBITED.OCUPILOTMAPPING</code> on the screen's Save and at the agent's confirm with no
/// write reaching <class>OcuPilot.Test.MappingAcceptPort</class>, while <code>Q*</code>,
/// <code>Zz*</code>, the range <code>A:B</code> and the plain name <code>Ocu</code> there reach it; in
/// <code>%ALL</code> the set refuses the same patterns and permits <code>Q*</code>; and in a probe
/// namespace the patterns the instance accepts are created on both callers.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Prohibited.CoversOwnName</method> tests
/// only whether the name begins with a stem -> each pattern and range leg that does not begin with
/// the stem reaches the port and this goes red.</p>
Method TestAMappingWhosePatternCoversOcuPilotsNamesIsRefused()
{
    Set tOwnNs = $ZConvert($NAMESPACE, "U")
    Set ^||OcuPilotNamespaceWritePort = ..#ACCEPT
    For tCase = $ListBuild("global", "O*"), $ListBuild("global", "Ocu*"), $ListBuild("global", "*"), $ListBuild("global", "A:Z"), $ListBuild("global", "Oa:Od"), $ListBuild("routine", "O*"), $ListBuild("routine", "Ocu*_INT"), $ListBuild("routine", "N:P"), $ListBuild("routine", "O:"), $ListBuild("global", ":"), $ListBuild("global", "OcuPilotState*"), $ListBuild("global", "OcuPilotA:OcuPilotZ"), $ListBuild("global", "OcuPilotState(""a""):(""z"")") {
        Set tKind = $List(tCase, 1)
        Set tName = $List(tCase, 2)
        Do $ClassMethod(..#ACCEPT, "Clear")
        Set tSC = ..Save(tKind, "create", tOwnNs, tName, {"Database": "USER"}, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tCode, "403 " _ ..#OWNCODE, tKind _ " " _ tName _ ": the screen's create is refused")
        Set tSC = ..Mint(..Tool(tKind, "Create"), {"Namespace": (tOwnNs), "Name": (tName), "Database": "USER"}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, tKind _ " " _ tName _ ": the agent's create is minted " _ tProblem)
        Do $$$AssertEquals(..Confirm(tProposal), "403 " _ ..#OWNCODE, tKind _ " " _ tName _ ": and its confirm is refused")
        Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", tKind _ " " _ tName _ ": no write reached the port")
    }
    For tName = "Q*", "Zz*", "A:B", "Ocu" {
        Do $ClassMethod(..#ACCEPT, "Clear")
        Set tSC = ..Save("global", "create", tOwnNs, tName, {"Database": "USER"}, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields _ " " _ $ClassMethod(..#ACCEPT, "Writes"), "201  PUT", tName _ ": the screen's create is permitted and reaches the port")
        Do $ClassMethod(..#ACCEPT, "Clear")
        Set tSC = ..Mint(..Tool("global", "Create"), {"Namespace": (tOwnNs), "Name": (tName), "Database": "USER"}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals(..Confirm(tProposal) _ $ClassMethod(..#ACCEPT, "Writes"), "200 PUT", tName _ ": so is the agent's")
    }
    For tCase = $ListBuild("O*", 1), $ListBuild("*", 1), $ListBuild("A:Z", 1), $ListBuild("Q*", 0) {
        Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("global-mapping", "instance", $ClassMethod(..#PROBE, "Id", "%ALL", $List(tCase, 1)), .tRef)
        Set tSC = ##class(OcuPilot.Test.MappingAllTargetFixture).Prohibits($Parameter(..Tool("global", "Create"), "TOOLNAME"), tRef, {"Database": "USER"}.%ToJSON(), "[]", .tProhibits, .tCode)
        Do $$$AssertStatusOK(tSC, "%ALL " _ $List(tCase, 1) _ ": the set answers")
        Do $$$AssertEquals(tProhibits _ " " _ tCode, $Select($List(tCase, 2): "1 " _ ..#OWNCODE, 1: "0 "), "%ALL " _ $List(tCase, 1) _ ": " _ $Select($List(tCase, 2): "refused", 1: "permitted"))
    }
    Set ^||OcuPilotNamespaceWritePort = ..#RECORD
    For tCase = $ListBuild("global", "O*"), $ListBuild("routine", "N:P") {
        Set tSC = ..Save($List(tCase, 1), "create", ..#NS, $List(tCase, 2), {"Database": "USER"}, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "201 ", $ListToString(tCase, " ") _ ": the screen creates it in a probe namespace")
    }
    For tCase = $ListBuild("global", "Oa:Od"), $ListBuild("routine", "Ocu*_INT") {
        Set tSC = ..Mint(..Tool($List(tCase, 1), "Create"), {"Namespace": (..#NS), "Name": ($List(tCase, 2)), "Database": "USER"}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals(..Confirm(tProposal), "200 ", $ListToString(tCase, " ") _ ": and so does the agent " _ tProblem)
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "global", ..#NS) _ "|" _ $ClassMethod(..#PROBE, "Names", "routine", ..#NS), "O*,Oa:Od|N:P,Ocu*_INT", "which the probe namespace holds")
}

/// <p>The screen's Save of kind <var>pKind</var> and verb <var>pVerb</var> (<code>create</code> or
/// <code>update</code>) for mapping <var>pName</var> of <var>pNamespace</var> with <var>pBody</var>:
/// <var>pHttp</var> the status it would answer, <var>pCode</var> the refusal's code, and
/// <var>pFields</var> its violations as <code>field:code</code>, comma-separated.</p>
ClassMethod Save(pKind As %String, pVerb As %String, pNamespace As %String, pName As %String, pBody As %DynamicObject, Output pHttp As %Integer, Output pCode As %String, Output pFields As %String) As %Status
{
    Set pCode = ""
    Set pFields = ""
    If pVerb = "create" {
        Set tSC = $ClassMethod(..#SAVE, "Create", pKind, pNamespace, pName, pBody, .tHttp, .tFault, .tViolations, .tReadBack)
        Set pHttp = 201
    } Else {
        Set tSC = $ClassMethod(..#SAVE, "Update", pKind, pNamespace, pName, pBody, .tHttp, .tFault, .tViolations, .tReadBack)
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

/// <p>Mint <var>pToolClass</var>'s proposal from <var>pArgs</var> through the tool's own mint class,
/// for this process's user over a completed turn seeded for it; <var>pProposal</var> is
/// <code>""</code> when the mint refused, with its problem in <var>pProblem</var>.</p>
ClassMethod Mint(pToolClass As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pProblem As %String, Output pTurnKey As %String, pUser As %String = {$Username}) As %Status
{
    Set pProposal = ""
    Set pHttp = 0
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .pTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod($ClassMethod(pToolClass, "MintClass"), "Mint", $Parameter(pToolClass, "DESCRIPTORCLASS"), $Parameter(pToolClass, "TOOLNAME"), pUser, "", pTurnKey, pArgs, "OcuPilot.Kernel.Agent.Limits", .tResult, .pHttp, .tFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pArgs.%Get($ClassMethod(pToolClass, "IdArgument")), $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
    If $IsObject($Get(tResult)) Set pProposal = tResult
    If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set pProblem = tFault.%Get("detail").%Get("problem")
    If '$IsObject(pProposal) Quit $$$ERROR($$$GeneralError, "the mint answered no proposal: " _ pHttp _ " " _ pProblem)
    Quit $$$OK
}

/// <p>Confirm <var>pProposal</var> through <parameter>CONFIRM</parameter> as this process's user,
/// answering <code>http code</code>.</p>
ClassMethod Confirm(pProposal As %DynamicObject) As %String
{
    If '$IsObject(pProposal) Quit "no proposal"
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", pProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Quit $Select($$$ISOK(tSC) && ($Get(tCode) = ""): 200, 1: +$Get(tHttp)) _ " " _ $Get(tCode)
}

/// <p>Send screen <var>pScreen</var>'s row action <var>pAction</var> for row <var>pId</var> through
/// <parameter>ACTION</parameter>, answering <code>http code</code>.</p>
ClassMethod Act(pScreen As %String, pAction As %String, pId As %String, pValues As %DynamicObject = "") As %String
{
    Set tBody = {}
    Do tBody.%Set("action", pAction, "string")
    Do tBody.%Set("id", pId, "string")
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", pScreen, tBody, .tAnswer, .tStatus)
    Set tCode = ""
    Try { Set tCode = ##class(%DynamicObject).%FromJSON(tAnswer).%Get("code") } Catch {}
    Quit tStatus _ " " _ tCode
}

/// <p>The stored proposal <var>pProposal</var>'s <code>destructive|consequence</code>, or
/// <code>no proposal</code>.</p>
ClassMethod Marked(pProposal As %DynamicObject) As %String
{
    If '$IsObject(pProposal) Quit "no proposal"
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposal.%Get("proposalId"), .tFound, .tValues)
    Quit +$Get(tValues("destructive")) _ "|" _ $Get(tValues("consequence"))
}

/// <p>The kind <var>pKind</var>'s <var>pVerb</var> tool class.</p>
ClassMethod Tool(pKind As %String, pVerb As %String) As %String
{
    Quit ##class(OcuPilot.Area.OsMgmt.MappingRules).ToolClass(pKind, pVerb)
}

}
