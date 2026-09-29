/// <p>Pins Story 18.3's pairs with least-privileged principals (AD-8, AD-29): a reader holding the Local
/// databases screens' two pairs reads the list, the form and the step check; each extra pair a
/// database tool declares, when missing, is refused 403 naming it on both callers with zero port calls
/// and nothing left on disk or in the configuration; and a principal holding exactly the declared
/// pairs creates, edits both groups (setting <code>MountRequired</code>, a resource and a new volume
/// directory) and deletes on both callers.</p>
/// <p>The Save, delete and confirm legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.DatabaseWriteGateProbe</class>), which reports what
/// <class>OcuPilot.Test.DatabaseRecordPort</class> was asked; the read legs run over the wire.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the manager directory
/// among the allowed directories, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>DATABASEVARIABLE</parameter> reading <code>1</code>, because the class creates and
/// deletes six users, six roles and probe databases (<class>OcuPilot.Test.DatabaseWriteProbe</class>)
/// and sets the governance policy. <method>OnBeforeAllTests</method> refuses anywhere either does not;
/// every probe object is removed by exact name.</p>
Class OcuPilot.Test.DatabaseWriteGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the database writes, set there alone too.</p>
Parameter DATABASEVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter PROBE = "OcuPilot.Test.DatabaseWriteProbe";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.LocalDatabaseCreate";

Parameter MOUNTTOOL = "OcuPilot.Screen.Tool.LocalDatabaseUpdateMount";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.LocalDatabaseUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.LocalDatabaseDelete";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter DELETEKEY = "osmgmt.localdatabases.delete";

/// <p>The probe resource an edit's resource change names.</p>
Parameter PROBERESOURCE = "%DB_OCUPROBE183RX";

/// <p>The principals, each <code>user:role:pairs</code> beyond the install namespace's code read, the
/// screens' <code>%Admin_Manage:U</code> and <code>%DB_IRISSYS:R</code>: the reader holds nothing more;
/// each of the next four lacks exactly one extra pair; the last holds exactly the declared set.</p>
Parameter PRINCIPALS = "OcuProbe183GateReader:OcuProbe183GateReaderRole:,OcuProbe183GateNoWrite:OcuProbe183GateNoWriteRole:%Admin_Secure:U;%Admin_FileSystemAccess:U;%Admin_Operate:U,OcuProbe183GateNoSecure:OcuProbe183GateNoSecureRole:%DB_IRISSYS:W;%Admin_FileSystemAccess:U;%Admin_Operate:U,OcuProbe183GateNoFiles:OcuProbe183GateNoFilesRole:%DB_IRISSYS:W;%Admin_Secure:U;%Admin_Operate:U,OcuProbe183GateNoOperate:OcuProbe183GateNoOperateRole:%DB_IRISSYS:W;%Admin_Secure:U;%Admin_FileSystemAccess:U,OcuProbe183GateFull:OcuProbe183GateFullRole:%DB_IRISSYS:W;%Admin_Secure:U;%Admin_FileSystemAccess:U;%Admin_Operate:U";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#DATABASEVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DatabaseWriteGate creates and deletes users, roles and databases on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#DATABASEVARIABLE _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set ..PreparedPassword = "OcuProbe183Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipals()
}

/// <p>Remove the probe databases, the principals and their roles, and restore the policy; a failing
/// status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ",") {
            Set tEntry = $Piece(..#PRINCIPALS, ",", tI)
            Set tUser = $Piece(tEntry, ":", 1)
            Set tRole = $Piece(tEntry, ":", 2)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tRole) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.DatabaseWriteGate left the principal " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe database object is removed by exact name")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

/// <p>A principal holding the screens' two pairs alone reads the Local databases list, the form (told
/// which pair the resource choice needs) and the step check over the wire.</p>
Method TestTheScreensPairsReadTheListTheFormAndTheCheck()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ..User(1)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/osmgmt.localdatabases/read?maxRows=1000", tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the list's read answers the reader: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue(tBody [ """Name"":""IRISSYS""", "with the instance's databases")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/database/form?name=USER", tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
    Do $$$AssertEquals(tStatus, 200, "the form's read answers the reader: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("resourcesRefused") _ "|" _ tAnswer.%GetTypeOf("resources") _ "|" _ tAnswer.%GetTypeOf("file"), 1: ""), "%Admin_Secure:USE|unassigned|object", "naming the pair the resource choice needs, with the file read")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/database/check", tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, {"step": "size", "values": {"Size": 2}}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus _ " " _ tBody, "200 {""violations"":[]}", "and the step check answers the reader")
}

/// <p>Each extra pair, missing: the create without <code>%DB_IRISSYS:WRITE</code>,
/// <code>%Admin_Secure:USE</code> or <code>%Admin_FileSystemAccess:USE</code>, and the delete without
/// the first, are refused 403 naming it on both callers with the port asked nothing, and no directory,
/// file, configuration or resource is left.</p>
/// <p>Mutation (Rule 19): drop <code>%DB_IRISSYS:WRITE</code> from
/// <method>OcuPilot.Screen.Tool.LocalDatabaseCreate.PrivilegePairs</method> -> the create legs reach
/// the port and this goes red.</p>
Method TestEachMissingPairIsRefusedBeforeAnyPortCall()
{
    Do $$$AssertStatusOK(..EnableDelete(), "the agent's delete key is enabled")
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "OCUPROBE183GD"), "a probe database to delete is created")
    For tCase = $ListBuild(2, "%DB_IRISSYS:WRITE", "OCUPROBE183GW"), $ListBuild(3, "%Admin_Secure:USE", "OCUPROBE183GS"), $ListBuild(4, "%Admin_FileSystemAccess:USE", "OCUPROBE183GF") {
        Set tUser = ..User($List(tCase, 1))
        Set tName = $List(tCase, 3)
        Set tBody = {"root": (tRoot)}
        Do tBody.%Set("Name", tName, "string")
        Do tBody.%Set("path", $ZConvert(tName, "L"), "string")
        Set tPlan = []
        Do tPlan.%Push({"kind": "create", "name": (tName), "body": (tBody)})
        Set tSC = ..MintFor(tUser, ..#CREATETOOL, tName _ "A", {"Name": (tName _ "A"), "root": (tRoot), "path": ($ZConvert(tName, "L") _ "a")}, .tProposal)
        Do $$$AssertStatusOK(tSC, tUser _ ": the agent's create is minted for the principal")
        Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
        Set tRun = ..RunAs(tUser, tPlan)
        Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
        For tI = 1, 2 {
            Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE " _ $List(tCase, 2) _ " calls=0 types=", tUser _ ": " _ $Select(tI = 1: "the screen's create", 1: "the agent's create confirm") _ " is refused naming " _ $List(tCase, 2))
        }
        For tOne = tName, tName _ "A" {
            Set tDirectory = $ClassMethod(..#PROBE, "DirectoryFor", $Extract(tOne, 12, *))
            Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tOne) _ $ClassMethod(..#PROBE, "HoldsDirectory", tDirectory) _ $ClassMethod(..#PROBE, "HoldsResource", "%DB_" _ tOne), "000", tOne _ ": no configuration, directory or resource is left")
        }
    }
    Set tUser = ..User(2)
    Set tSC = ..MintFor(tUser, ..#DELETETOOL, "OCUPROBE183GD", {"Name": "OCUPROBE183GD", "DeleteFile": true}, .tProposal)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted for the principal without the write pair")
    Set tPlan = []
    Do tPlan.%Push({"kind": "delete", "name": "OCUPROBE183GD"})
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    Set tRun = ..RunAs(tUser, tPlan)
    For tI = 1, 2 {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %DB_IRISSYS:WRITE calls=0 types=", $Select(tI = 1: "the screen's delete", 1: "the agent's delete confirm") _ " is refused naming the write pair")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBE183GD") _ $ClassMethod(..#PROBE, "HoldsFile", $ClassMethod(..#PROBE, "DirectoryFor", "gd")), "11", "and the database is still there")
}

/// <p>Each argument pair, missing: the mounting edit setting <code>MountRequired</code> without
/// <code>%Admin_Operate:USE</code>, the file edit changing the resource without
/// <code>%Admin_Secure:USE</code>, and naming a new volume directory without
/// <code>%Admin_FileSystemAccess:USE</code>, are refused 403 naming it on both callers with no port
/// call, and the database is unchanged.</p>
Method TestEachMissingArgumentPairIsRefusedBeforeAnyPortCall()
{
    Set tName = "OCUPROBE183GA"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a probe database is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddResource", ..#PROBERESOURCE), "and a probe resource")
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    For tCase = $ListBuild(5, "%Admin_Operate:USE", ..#MOUNTTOOL, "configuration", {"MountRequired": true}.%ToJSON()), $ListBuild(3, "%Admin_Secure:USE", ..#UPDATETOOL, "file", {"ResourceName": (..#PROBERESOURCE)}.%ToJSON()), $ListBuild(4, "%Admin_FileSystemAccess:USE", ..#UPDATETOOL, "file", {"volumeRoot": (tRoot), "volumePath": "ocuprobe183ga-vol"}.%ToJSON()) {
        Set tUser = ..User($List(tCase, 1))
        Set tGroup = {}
        Do tGroup.%Set($List(tCase, 4), ##class(%DynamicObject).%FromJSON($List(tCase, 5)))
        Set tArgs = ##class(%DynamicObject).%FromJSON($List(tCase, 5))
        Do tArgs.%Set("Name", tName, "string")
        Set tSC = ..MintFor(tUser, $List(tCase, 3), tName, tArgs, .tProposal)
        Do $$$AssertStatusOK(tSC, tUser _ ": the agent's edit is minted for the principal")
        Set tPlan = []
        Do tPlan.%Push({"kind": "update", "name": (tName), "body": (tGroup)})
        Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
        Set tRun = ..RunAs(tUser, tPlan)
        Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
        For tI = 1, 2 {
            Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE " _ $List(tCase, 2) _ " calls=0 types=", tUser _ ": " _ $Select(tI = 1: "the screen's edit", 1: "the agent's edit confirm") _ " is refused naming " _ $List(tCase, 2))
        }
    }
    Set tDirectory = $ClassMethod(..#PROBE, "DirectoryFor", "ga")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "MountRequired") _ " " _ $ClassMethod(..#PROBE, "StoredFile", tDirectory, "ResourceName") _ " " _ $ClassMethod(..#PROBE, "HoldsDirectory", $ClassMethod(..#PROBE, "DirectoryFor", "ga-vol")), "false %DB_OCUPROBE183GA 0", "and the database is unchanged")
}

/// <p>A principal holding exactly the declared pairs: the screen's create, both edit groups (setting
/// <code>MountRequired</code>, the resource and a new volume directory) and delete, and the agent's
/// confirm of each, succeed through the port and the instance holds what they wrote (AD-29). This is
/// also the floor under the refusal legs' zero.</p>
Method TestExactlyTheDeclaredPairsWriteOnBothCallers()
{
    Do $$$AssertStatusOK(..EnableDelete(), "the agent's delete key is enabled")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddResource", ..#PROBERESOURCE), "a probe resource exists")
    Set tUser = ..User(6)
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "OCUPROBE183FE"), "a probe database to edit is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "OCUPROBE183FD"), "and one to delete")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "OCUPROBE183AE"), "and the agent's to edit the mounting of")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "OCUPROBE183AF"), "and the agent's to edit the file of, a second target, since a confirm cancels its target's sibling proposals (AD-34)")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "OCUPROBE183AD"), "and the agent's to delete")
    Set tEdit = {"configuration": {"MountRequired": true}, "file": {"ResourceName": (..#PROBERESOURCE), "volumePath": "ocuprobe183fe-vol"}}
    Do tEdit.file.%Set("volumeRoot", tRoot, "string")
    Set tPlan = []
    Do tPlan.%Push({"kind": "create", "name": "OCUPROBE183FN", "body": {"Name": "OCUPROBE183FN", "root": (tRoot), "path": "ocuprobe183fn"}})
    Do tPlan.%Push({"kind": "update", "name": "OCUPROBE183FE", "body": (tEdit)})
    Do tPlan.%Push({"kind": "delete", "name": "OCUPROBE183FD"})
    For tCase = $ListBuild(..#CREATETOOL, "OCUPROBE183AN", {"Name": "OCUPROBE183AN", "root": (tRoot), "path": "ocuprobe183an"}.%ToJSON()), $ListBuild(..#MOUNTTOOL, "OCUPROBE183AE", {"Name": "OCUPROBE183AE", "MountRequired": true}.%ToJSON()), $ListBuild(..#UPDATETOOL, "OCUPROBE183AF", {"Name": "OCUPROBE183AF", "ResourceName": (..#PROBERESOURCE), "volumeRoot": (tRoot), "volumePath": "ocuprobe183af-vol"}.%ToJSON()), $ListBuild(..#DELETETOOL, "OCUPROBE183AD", {"Name": "OCUPROBE183AD", "DeleteFile": true}.%ToJSON()) {
        Set tSC = ..MintFor(tUser, $List(tCase, 1), $List(tCase, 2), ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tProposal)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": minted for the principal")
        Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    }
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as the principal")
    For tCase = $ListBuild(1, 201, "Database.SysCRUD/POST", "the screen's create"), $ListBuild(2, 200, "Database.SysCRUD/PUT", "the screen's edit"), $ListBuild(3, 200, "Database.ConfigCRUD/DELETE", "the screen's delete"), $ListBuild(4, 200, "Database.SysCRUD/POST", "the agent's create confirm"), $ListBuild(5, 200, "Database.ConfigCRUD/PUT", "the agent's mounting confirm"), $ListBuild(6, 200, "Database.SysCRUD/PUT", "the agent's file confirm"), $ListBuild(7, 200, "Database.ConfigCRUD/DELETE", "the agent's delete confirm") {
        Set tLeg = ..Leg(tRun, $List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http"), 1: ""), $List(tCase, 2), $List(tCase, 4) _ " succeeds (" _ ..LegText(tRun, $List(tCase, 1)) _ ")")
        Do $$$AssertTrue($IsObject(tLeg) && $ListFind($ListFromString(tLeg.%Get("types")), $List(tCase, 3)), $List(tCase, 4) _ " reaches the port's " _ $List(tCase, 3))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBE183FN") _ $ClassMethod(..#PROBE, "Holds", "OCUPROBE183AN"), "11", "both creates are on the instance")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OCUPROBE183FE", "MountRequired") _ " " _ $ClassMethod(..#PROBE, "StoredFile", $ClassMethod(..#PROBE, "DirectoryFor", "fe"), "ResourceName") _ " " _ $ClassMethod(..#PROBE, "HoldsDirectory", $ClassMethod(..#PROBE, "DirectoryFor", "fe-vol")), "true " _ ..#PROBERESOURCE _ " 1", "the screen's two groups are applied")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OCUPROBE183AE", "MountRequired"), "true", "the agent's mounting edit is applied")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredFile", $ClassMethod(..#PROBE, "DirectoryFor", "af"), "ResourceName") _ " " _ $ClassMethod(..#PROBE, "HoldsDirectory", $ClassMethod(..#PROBE, "DirectoryFor", "af-vol")), ..#PROBERESOURCE _ " 1", "and its file edit")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBE183FD") _ $ClassMethod(..#PROBE, "Holds", "OCUPROBE183AD"), "00", "both deletes removed their configuration")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsFile", $ClassMethod(..#PROBE, "DirectoryFor", "fd")) _ $ClassMethod(..#PROBE, "HoldsFile", $ClassMethod(..#PROBE, "DirectoryFor", "ad")), "00", "and their files")
}

/// <p>The principal of entry <var>pIndex</var> of <parameter>PRINCIPALS</parameter>.</p>
ClassMethod User(pIndex As %Integer) As %String
{
    Quit $Piece($Piece(..#PRINCIPALS, ",", pIndex), ":", 1)
}

/// <p>Mint <var>pToolClass</var>'s proposal for <var>pName</var> from <var>pArgs</var> on behalf of
/// <var>pUser</var>, over a completed turn seeded for that user.</p>
Method MintFor(pUser As %String, pToolClass As %String, pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject) As %Status
{
    Set pProposal = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurn)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(pToolClass, "DESCRIPTORCLASS"), $Parameter(pToolClass, "TOOLNAME"), pUser, "", tTurn, pArgs, ..#LIMITS, .pProposal, .tHttp, .tFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pName, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(pProposal) Quit $$$ERROR($$$GeneralError, "the mint answered no proposal: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: $Get(tHttp)))
    Quit $$$OK
}

/// <p>Run <class>OcuPilot.Test.DatabaseWriteGateProbe</class> as <var>pUser</var> over
/// <var>pPlan</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.DatabaseWriteGateProbe).Run($Job, pUser, tPlan)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 300)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 300 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>Who the child ran as, <code>username loggedIn</code>, or its error.</p>
ClassMethod Ran(pRun As %DynamicObject) As %String
{
    If '$IsObject(pRun) Quit "no answer"
    If pRun.%IsDefined("error") Quit pRun.%Get("error")
    Quit pRun.%Get("username") _ " " _ pRun.%Get("loggedIn")
}

/// <p>Step <var>pIndex</var> (from 1) of the child's answer <var>pRun</var>, or <code>""</code>.</p>
ClassMethod Leg(pRun As %DynamicObject, pIndex As %Integer) As %DynamicObject
{
    If '$IsObject(pRun) || (pRun.%GetTypeOf("steps") '= "array") Quit ""
    Quit pRun.%Get("steps").%Get(pIndex - 1)
}

/// <p>Step <var>pIndex</var> as <code>http code failedPair calls=n types=t</code>.</p>
ClassMethod LegText(pRun As %DynamicObject, pIndex As %Integer) As %String
{
    Set tLeg = ..Leg(pRun, pIndex)
    If '$IsObject(tLeg) Quit "absent"
    Quit tLeg.%Get("http") _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair") _ " calls=" _ tLeg.%Get("calls") _ " types=" _ tLeg.%Get("types")
}

/// <p>Enable the agent's database delete key, over the snapshot this class took.</p>
Method EnableDelete() As %Status
{
    Kill tSettings
    Set tSettings(..#DELETEKEY) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>Create the six throwaway roles and the accounts that hold them, then read each principal's
/// extra pairs back: the install namespace's code read and the screens' two pairs, plus the entry's
/// own.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCode = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        For tI = 1:1:$Length(..#PRINCIPALS, ",") {
            Set tEntry = $Piece(..#PRINCIPALS, ",", tI)
            Set tUser = $Piece(tEntry, ":", 1)
            Set tRole = $Piece(tEntry, ":", 2)
            Set tExtra = $Translate($Piece(tEntry, ":", 3, *), ";", ",")
            Set tWrites = (tExtra [ "%DB_IRISSYS:W")
            Set tOthers = ""
            For tJ = 1:1:$Length(tExtra, ",") {
                Set tOne = $Piece(tExtra, ",", tJ)
                If (tOne '= "") && (tOne '= "%DB_IRISSYS:W") Set tOthers = tOthers _ "," _ tOne
            }
            Set tGrants = tCode _ ",%DB_IRISSYS:" _ $Select(tWrites: "RW", 1: "R") _ ",%Admin_Manage:U" _ tOthers
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the database write gate (throwaway)", tGrants, "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot database test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.DatabaseWriteGate; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
            For tPair = "%Admin_Manage:USE", "%DB_IRISSYS:READ", "%DB_IRISSYS:WRITE", "%Admin_Secure:USE", "%Admin_FileSystemAccess:USE", "%Admin_Operate:USE" {
                Set tResource = $Piece(tPair, ":", 1)
                Set tPermission = $Piece(tPair, ":", 2)
                Set tWanted = (tI = 6) || (tPair = "%Admin_Manage:USE") || (tPair = "%DB_IRISSYS:READ") || ((tExtra '= "") && ((tExtra [ (tResource _ ":" _ $Extract(tPermission))) && ((tPermission '= "WRITE") || (tExtra [ "%DB_IRISSYS:W"))))
                If ($SYSTEM.Security.CheckUserPermission(tUser, tResource, tPermission) = 1) '= tWanted {
                    Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal " _ tUser _ "'s grant " _ tPair _ " did not read back as declared")
                    Quit
                }
            }
            If $$$ISERR(tSC) Quit
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
