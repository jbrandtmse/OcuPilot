/// <p>Pins Story 18.14's pairs with least-privileged principals (AD-8, AD-29): a reader holding the
/// Namespaces screens' two pairs reads the three mapping lists and the form's choices; a writer
/// without <code>%DB_IRISSYS:WRITE</code> is refused naming it on a mapping create, edit and delete,
/// and a copier without <code>%Admin_Operate:USE</code> naming that on a copy of mappings, each on
/// both callers with zero port calls and nothing changed; a principal holding exactly the declared
/// pairs writes on both callers.</p>
/// <p>The Save, row action and confirm legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.MappingWriteGateProbe</class>), which reports what
/// <class>OcuPilot.Test.MappingRecordPort</class> was asked; the read legs run over the wire.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>NAMESPACEVARIABLE</parameter> reading
/// <code>1</code>, because the class creates and deletes three users, three roles, probe namespaces
/// and their mappings. <method>OnBeforeAllTests</method> refuses anywhere either does not; every probe
/// object is removed by exact name.</p>
Class OcuPilot.Test.MappingWriteGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the namespace and mapping writes, set there alone too.</p>
Parameter NAMESPACEVARIABLE = "OCUPILOT_ALLOW_NAMESPACE_CONFIG";

Parameter PROBE = "OcuPilot.Test.MappingProbe";

Parameter WRITE = "OcuPilot.Test.MappingWrite";

Parameter COPYTOOL = "OcuPilot.Screen.Tool.NamespaceCopyMappings";

Parameter NS = "OCUPROBE1814A";

Parameter SOURCE = "OCUPROBE1814B";

/// <p>The principal holding the install namespace's code read and the screens' two pairs.</p>
Parameter READERUSER = "OcuProbe1814GateReader";

/// <p>The principal holding those, <code>%DB_IRISSYS:WRITE</code> and not
/// <code>%Admin_Operate:USE</code>.</p>
Parameter COPIERUSER = "OcuProbe1814GateCopier";

/// <p>The principal holding exactly every pair the mapping and copy tools declare.</p>
Parameter FULLUSER = "OcuProbe1814GateFull";

/// <p>The throwaway principals' password, generated for the run.</p>
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
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#NAMESPACEVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.MappingWriteGate creates and deletes users, roles, namespaces and mappings on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#NAMESPACEVARIABLE _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set ..PreparedPassword = "OcuProbe1814Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipals()
}

Method OnBeforeOneTest() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Add", ..#NS)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Add", ..#SOURCE))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "AddMapping", "global", ..#SOURCE, "OcuProbe1814GC", "USER"))
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe namespace is removed by exact name, with its mappings")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

/// <p>Remove the probe namespaces, the principals and their roles; a failing status when any
/// survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Set tSC = $$$ADDSC(tSC, ..RemovePrincipals())
    Quit tSC
}

/// <p>A principal holding the screens' two pairs alone reads each mapping list for the install
/// namespace, every row carrying it, and the form's database choices over the wire.</p>
Method TestTheScreensPairsReadTheListsAndTheFormChoices()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tNamespace = $ZConvert($NAMESPACE, "U")
    For tKind = "global", "routine", "package" {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/osmgmt." _ tKind _ "mappings/read?maxRows=1000&namespace=" _ tNamespace, ..#READERUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tKind _ ": the list's read answers the reader: " _ $Extract(tBody, 1, 200))
        Set tRows = ""
        Try { Set tRows = ##class(%DynamicObject).%FromJSON(tBody).%Get("rows") } Catch {}
        Do $$$AssertTrue($IsObject(tRows) && (tRows.%Size() > 0) && (tRows.%Get(0).%Get("namespace") = tNamespace), tKind _ ": with the namespace's mappings, each carrying it")
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/mapping/" _ tKind _ "/form?namespace=" _ tNamespace, ..#READERUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
        Set tDatabases = ""
        Try { Set tDatabases = ##class(%DynamicObject).%FromJSON(tBody).%Get("databases") } Catch {}
        Do $$$AssertEquals(tStatus, 200, tKind _ ": the form's read answers the reader: " _ $Extract(tBody, 1, 200))
        Do $$$AssertTrue($IsObject(tDatabases) && (tDatabases.%ToJSON() [ """USER"""), tKind _ ": with the database choices")
    }
}

/// <p>Without <code>%DB_IRISSYS:WRITE</code>: the screen's create, edit and delete and the agent's
/// confirm of each are refused 403 naming the pair, the port is asked nothing, and nothing is created,
/// changed or deleted.</p>
/// <p>Mutation (Rule 19): drop <code>%DB_IRISSYS:WRITE</code> from
/// <method>OcuPilot.Screen.Tool.MappingCreate.PrivilegePairs</method> -> the create legs reach the
/// port and this goes red.</p>
Method TestAWriteWithoutTheWritePairIsRefusedBeforeAnyPortCall()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#NS, "OcuProbe1814GE", "USER"), "a mapping to edit is seeded")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#NS, "OcuProbe1814GD", "USER"), "and one to delete")
    Set tRun = ..Run(..#READERUSER, "OcuProbe1814GN", "OcuProbe1814GE", "OcuProbe1814GD")
    Set tLabels = $ListBuild("the screen's create", "the screen's edit", "the screen's delete", "the agent's create confirm", "the agent's edit confirm", "the agent's delete confirm")
    For tI = 1:1:$ListLength(tLabels) {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %DB_IRISSYS:WRITE calls=0 types=", $List(tLabels, tI) _ ": refused naming the write pair, the port asked nothing")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "global", ..#NS), "OcuProbe1814GD,OcuProbe1814GE", "nothing is created, and nothing is deleted")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "global", ..#NS, "OcuProbe1814GE", "Database"), "USER", "and the edited mapping is unchanged")
}

/// <p>Without <code>%Admin_Operate:USE</code>: the screen's copy and the agent's copy confirm are
/// refused 403 naming the poll's pair with no port call, and the destination is unchanged.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_Operate:USE</code> from
/// <method>OcuPilot.Screen.Tool.NamespaceCopyMappings.PrivilegePairs</method> -> the copy reaches the
/// port and this goes red.</p>
Method TestACopyWithoutThePollPairIsRefusedBeforeAnyPortCall()
{
    Set tSC = $ClassMethod(..#WRITE, "Mint", ..#COPYTOOL, {"Name": (..#NS), "SourceNamespace": (..#SOURCE)}, .tProposal, .tHttp, .tProblem, , ..#COPIERUSER)
    Do $$$AssertStatusOK(tSC, "the copy is minted for the principal " _ tProblem)
    If $$$ISERR(tSC) Quit
    Set tPlan = []
    Do tPlan.%Push({"kind": "action", "screen": "osmgmt.namespaces", "body": {"action": "copy-mappings", "id": (..#NS), "values": {"SourceNamespace": (..#SOURCE)}}})
    Do tPlan.%Push({"kind": "confirm", "proposalId": (tProposal.%Get("proposalId"))})
    Set tRun = ..RunAs(..#COPIERUSER, tPlan)
    Do $$$AssertEquals(##class(OcuPilot.Test.NamespaceWriteGate).Ran(tRun), ..#COPIERUSER _ " 1", "the child process ran as the principal")
    For tI = 1, 2 {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %Admin_Operate:USE calls=0 types=", $Select(tI = 1: "the screen's copy", 1: "the agent's copy confirm") _ ": refused naming the poll's pair, the port asked nothing")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "global", ..#NS), "", "and nothing is copied")
}

/// <p>A principal holding exactly the declared pairs: the screen's create, edit and delete and the
/// agent's confirm of each succeed, each reaching the port with its write, and a copy of mappings
/// succeeds on both callers through the queued copy; the instance holds what they wrote (AD-29). This
/// is also the floor under the refusal legs' zero.</p>
Method TestExactlyTheDeclaredPairsWriteOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#NS, "OcuProbe1814FE", "USER"), "a mapping to edit is seeded")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#NS, "OcuProbe1814FD", "USER"), "one to delete")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#NS, "OcuProbe1814FAE", "USER"), "and one of each for the agent")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "global", ..#NS, "OcuProbe1814FAD", "USER"), "")
    Set tRun = ..Run(..#FULLUSER, "OcuProbe1814FN", "OcuProbe1814FE", "OcuProbe1814FD", "OcuProbe1814FAN", "OcuProbe1814FAE", "OcuProbe1814FAD")
    For tCase = $ListBuild(1, 201, "PUT", "the screen's create"), $ListBuild(2, 200, "PUT", "the screen's edit"), $ListBuild(3, 200, "DELETE", "the screen's delete"), $ListBuild(4, 200, "PUT", "the agent's create confirm"), $ListBuild(5, 200, "PUT", "the agent's edit confirm"), $ListBuild(6, 200, "DELETE", "the agent's delete confirm") {
        Set tLeg = ..Leg(tRun, $List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http"), 1: ""), $List(tCase, 2), $List(tCase, 4) _ ": succeeds (" _ ..LegText(tRun, $List(tCase, 1)) _ ")")
        Do $$$AssertTrue($IsObject(tLeg) && $ListFind($ListFromString(tLeg.%Get("types")), $List(tCase, 3)), $List(tCase, 4) _ ": through the port's " _ $List(tCase, 3))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "global", ..#NS), "OcuProbe1814FAE,OcuProbe1814FAN,OcuProbe1814FE,OcuProbe1814FN", "both creates are on the instance and both deletes removed their mapping")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "global", ..#NS, "OcuProbe1814FE", "Database") _ " " _ $ClassMethod(..#PROBE, "Stored", "global", ..#NS, "OcuProbe1814FAE", "Database"), "IRISTEMP IRISTEMP", "both edits are applied")

    Set tDestination = "OCUPROBE1814C"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tDestination), "a destination for the agent's copy is created")
    Set tSC = $ClassMethod(..#WRITE, "Mint", ..#COPYTOOL, {"Name": (tDestination), "SourceNamespace": (..#SOURCE)}, .tProposal, .tHttp, .tProblem, , ..#FULLUSER)
    Do $$$AssertStatusOK(tSC, "the agent's copy is minted for the principal " _ tProblem)
    If $$$ISERR(tSC) Quit
    Set tPlan = []
    Do tPlan.%Push({"kind": "action", "screen": "osmgmt.namespaces", "body": {"action": "copy-mappings", "id": (..#NS), "values": {"SourceNamespace": (..#SOURCE)}}})
    Do tPlan.%Push({"kind": "confirm", "proposalId": (tProposal.%Get("proposalId"))})
    Set tRun = ..RunAs(..#FULLUSER, tPlan)
    For tI = 1, 2 {
        Set tLeg = ..Leg(tRun, tI)
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http"), 1: ""), 200, $Select(tI = 1: "the screen's copy", 1: "the agent's copy confirm") _ ": succeeds (" _ ..LegText(tRun, tI) _ ")")
        Do $$$AssertTrue($IsObject(tLeg) && $ListFind($ListFromString(tLeg.%Get("types")), "MAPPINGS"), $Select(tI = 1: "the screen's copy", 1: "the agent's copy confirm") _ ": through the queued copy")
    }
    Do $$$AssertTrue(("," _ $ClassMethod(..#PROBE, "Names", "global", ..#NS) _ ",") [ ",OcuProbe1814GC,", "the screen's copy brought the source's mapping")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Names", "global", tDestination), "OcuProbe1814GC", "and so did the agent's")
}

/// <p>Mint the agent's create of <var>pNew</var>, edit of <var>pAgentEdit</var> and delete of
/// <var>pAgentDelete</var> for <var>pUser</var>, then run as <var>pUser</var> the screen's create of
/// <var>pScreenNew</var>, edit of <var>pEdit</var> and delete of <var>pDelete</var> and the three
/// confirms, in that order, all global mappings of <parameter>NS</parameter>. With only the three
/// screen names, the agent's legs take the same targets.</p>
Method Run(pUser As %String, pScreenNew As %String, pEdit As %String, pDelete As %String, pNew As %String = "", pAgentEdit As %String = "", pAgentDelete As %String = "") As %DynamicObject
{
    If pNew = "" Set pNew = pScreenNew _ "A"
    If pAgentEdit = "" Set pAgentEdit = pEdit
    If pAgentDelete = "" Set pAgentDelete = pDelete
    Set tPlan = []
    Do tPlan.%Push({"kind": "create", "mappingKind": "global", "body": {"Namespace": (..#NS), "Name": (pScreenNew), "Database": "USER"}})
    Do tPlan.%Push({"kind": "update", "mappingKind": "global", "id": ($ClassMethod(..#PROBE, "Id", ..#NS, pEdit)), "body": {"Database": "IRISTEMP"}})
    Do tPlan.%Push({"kind": "action", "screen": "osmgmt.globalmappings", "body": {"action": "delete", "id": ($ClassMethod(..#PROBE, "Id", ..#NS, pDelete))}})
    For tCase = $ListBuild("Create", pNew, {"Namespace": (..#NS), "Name": (pNew), "Database": "USER"}.%ToJSON()), $ListBuild("Update", pAgentEdit, {"Namespace": (..#NS), "Name": (pAgentEdit), "Database": "IRISTEMP"}.%ToJSON()), $ListBuild("Delete", pAgentDelete, {"Namespace": (..#NS), "Name": (pAgentDelete)}.%ToJSON()) {
        Set tSC = $ClassMethod(..#WRITE, "Mint", ##class(OcuPilot.Area.OsMgmt.MappingRules).ToolClass("global", $List(tCase, 1)), ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tProposal, .tHttp, .tProblem, , pUser)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": minted for the principal " _ tProblem)
        Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    }
    Set tRun = ..RunAs(pUser, tPlan)
    Do $$$AssertEquals(##class(OcuPilot.Test.NamespaceWriteGate).Ran(tRun), pUser _ " 1", "the child process ran as the principal")
    Quit tRun
}

/// <p>Run <class>OcuPilot.Test.MappingWriteGateProbe</class> as <var>pUser</var> over
/// <var>pPlan</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>. Each copy the child's user left in the vendor's task store is deleted
/// through <method>OcuPilot.Port.AdminPort.ForgetTask</method>, as this process's user, unread.</p>
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.MappingWriteGateProbe).Run($Job, pUser, tPlan)::10
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
        Set tTasks = tOut.%Get("tasks")
        If $IsObject(tTasks) {
            Set tIterator = tTasks.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tGuid) { Do ##class(OcuPilot.Port.AdminPort).ForgetTask(tGuid) }
        }
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>Step <var>pIndex</var> (from 1) of the child's answer <var>pRun</var>.</p>
ClassMethod Leg(pRun As %DynamicObject, pIndex As %Integer) As %DynamicObject
{
    Quit ##class(OcuPilot.Test.NamespaceWriteGate).Leg(pRun, pIndex)
}

/// <p>Step <var>pIndex</var> as <code>http code failedPair calls=n types=t</code>.</p>
ClassMethod LegText(pRun As %DynamicObject, pIndex As %Integer) As %String
{
    Quit ##class(OcuPilot.Test.NamespaceWriteGate).LegText(pRun, pIndex)
}

/// <p>Create the three throwaway roles and the accounts that hold them, then read the grants back:
/// the install namespace's code read and the screens' two pairs; those, the system database's write
/// and no poll; and every declared pair.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tCode = ##class(OcuPilot.Test.ClassicPageGate).CodeRead()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        For tCase = $ListBuild(..#READERUSER, tCode _ ",%DB_IRISSYS:R,%Admin_Manage:U", 0, 0), $ListBuild(..#COPIERUSER, tCode _ ",%DB_IRISSYS:RW,%Admin_Manage:U", 1, 0), $ListBuild(..#FULLUSER, tCode _ ",%DB_IRISSYS:RW,%Admin_Manage:U,%Admin_Operate:U", 1, 1) {
            Set tUser = $List(tCase, 1)
            Set tRole = tUser _ "Role"
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the mapping write gate (throwaway)", $List(tCase, 2), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot mapping test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.MappingWriteGate; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
            If ($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Manage", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(tUser, "%DB_IRISSYS", "READ") '= 1) || (($SYSTEM.Security.CheckUserPermission(tUser, "%DB_IRISSYS", "WRITE") = 1) '= $List(tCase, 3)) || (($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Operate", "USE") = 1) '= $List(tCase, 4)) {
                Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal " _ tUser _ "'s grants did not read back as declared")
                Quit
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete the principals and their roles; an error when any survives.</p>
Method RemovePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#READERUSER, ..#COPIERUSER, ..#FULLUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.MappingWriteGate left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

}
