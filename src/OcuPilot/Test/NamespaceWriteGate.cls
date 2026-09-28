/// <p>Pins Story 18.2's pairs with least-privileged principals (AD-8, AD-29): a reader holding the
/// Namespaces screens' two pairs reads the list, the form's database choices and the name check; a
/// writer without <code>%DB_IRISSYS:WRITE</code> is refused naming it on create, edit and delete, and
/// a deleter without <code>%Admin_Secure:USE</code> naming that, each on both callers with zero port
/// calls and the target still present; a principal holding exactly the declared pairs writes on both
/// callers.</p>
/// <p>The Save, delete and confirm legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.NamespaceWriteGateProbe</class>), which reports what
/// <class>OcuPilot.Test.DeviceRecordPort</class> was asked; the read legs run over the wire.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>NAMESPACEVARIABLE</parameter> reading
/// <code>1</code>, because the class creates and deletes three users, three roles, probe namespaces
/// and their web applications and sets the governance policy. <method>OnBeforeAllTests</method>
/// refuses anywhere either does not; every probe object is removed by exact name.</p>
Class OcuPilot.Test.NamespaceWriteGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the namespace writes, set there alone too.</p>
Parameter NAMESPACEVARIABLE = "OCUPILOT_ALLOW_NAMESPACE_CONFIG";

Parameter PROBE = "OcuPilot.Test.NamespaceWriteProbe";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.NamespaceCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.NamespaceUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.NamespaceDelete";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter DELETEKEY = "osmgmt.namespaces.delete";

/// <p>The principal holding the install namespace's code read and the screens' two pairs.</p>
Parameter READERUSER = "OcuPilotNsGateReader";

Parameter READERROLE = "OcuPilotNsGateReaderRole";

/// <p>The principal holding those and <code>%DB_IRISSYS:WRITE</code>, and not
/// <code>%Admin_Secure:USE</code>.</p>
Parameter WRITERUSER = "OcuPilotNsGateWriter";

Parameter WRITERROLE = "OcuPilotNsGateWriterRole";

/// <p>The principal holding exactly the declared pairs: those and <code>%Admin_Secure:USE</code>.</p>
Parameter FULLUSER = "OcuPilotNsGateFull";

Parameter FULLROLE = "OcuPilotNsGateFullRole";

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
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.NamespaceWriteGate creates and deletes users, roles and namespaces on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#NAMESPACEVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.NamespaceWriteGate creates and deletes namespaces on this instance and runs on a throwaway container only. " _ ..#NAMESPACEVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotNsGate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipals()
}

/// <p>Remove the probe namespaces, the principals and their roles, and restore the policy; a failing
/// status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#READERUSER, ..#WRITERUSER, ..#FULLUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.NamespaceWriteGate left the principal " _ tUser))
        }
        For tRole = ..#READERROLE, ..#WRITERROLE, ..#FULLROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.NamespaceWriteGate left the role " _ tRole))
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
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe namespace is removed by exact name")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

/// <p>A principal holding the screens' two pairs alone reads the Namespaces list, the form's
/// database choices and the name check over the wire, and the navigation map lists the list
/// allowed.</p>
Method TestTheScreensPairsReadTheListTheFormAndTheName()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/osmgmt.namespaces/read?maxRows=1000", ..#READERUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the Namespaces list's read answers the reader: " _ $Extract(tBody, 1, 200))
    Set tRows = ""
    Try { Set tRows = ##class(%DynamicObject).%FromJSON(tBody).%Get("rows") } Catch {}
    Do $$$AssertTrue($IsObject(tRows) && (tRows.%Size() > 0), "with the instance's namespaces")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/namespace/form", ..#READERUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set tDatabases = ""
    Try { Set tDatabases = ##class(%DynamicObject).%FromJSON(tBody).%Get("databases") } Catch {}
    Do $$$AssertEquals(tStatus, 200, "the form's read answers the reader: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertTrue($IsObject(tDatabases) && (tDatabases.%ToJSON() [ """USER"""), "with the database choices")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/namespace/name?name=user", ..#READERUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the name check answers the reader")
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("name") _ "|" _ tAnswer.%Get("reason"), 1: ""), "user|" _ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#NAMESPACENAMETAKEN), "naming the name and the taken sentence")
    Do $$$AssertTrue(tBody [ """taken"":true", "and finds USER taken in any case")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/navigation", ..#READERUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertTrue(tBody [ """route"":""os-management/namespaces"",""labelKey"":""namespaceListLabel"",""sideBarPosition"":6,""allowed"":true", "the navigation map lists the Namespaces list allowed")
}

/// <p>Without <code>%DB_IRISSYS:WRITE</code>: the screen's create, edit and delete and the agent's
/// confirm of each are refused 403 naming the pair, the port is asked nothing, and nothing is created,
/// changed or deleted.</p>
/// <p>Mutation (Rule 19): drop <code>%DB_IRISSYS:WRITE</code> from
/// <method>OcuPilot.Screen.Tool.NamespaceCreate.PrivilegePairs</method> -> the create legs reach the
/// port and this goes red.</p>
Method TestAWriteWithoutTheWritePairIsRefusedBeforeAnyPortCall()
{
    Do $$$AssertStatusOK(..EnableDelete(), "the agent's delete key is enabled")
    Set tEdit = "OCUPROBE182GE"
    Set tDelete = "OCUPROBE182GD"
    For tName = tEdit, tDelete {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), tName _ " is created")
    }
    Set tNew = "OCUPROBE182GN"
    Set tRun = ..Run(..#READERUSER, tNew, tEdit, tDelete)
    Set tLabels = $ListBuild("the screen's create", "the screen's edit", "the screen's delete", "the agent's create confirm", "the agent's edit confirm", "the agent's delete confirm")
    For tI = 1:1:$ListLength(tLabels) {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %DB_IRISSYS:WRITE calls=0 types=", $List(tLabels, tI) _ ": refused naming the write pair, the port asked nothing")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tNew), 0, "no namespace is created")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tEdit, "Routines"), "USER", "the edited namespace is unchanged")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tDelete), 1, "and the deleted one is still there")
}

/// <p>With the write pair and without <code>%Admin_Secure:USE</code>: the screen's delete and the
/// agent's delete confirm are refused 403 naming <code>%Admin_Secure:USE</code> with no port call, and
/// the namespace and its web application still exist.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_Secure:USE</code> from
/// <method>OcuPilot.Screen.Tool.NamespaceDelete.PrivilegePairs</method> -> the delete reaches the port
/// and this goes red.</p>
Method TestADeleteWithoutTheApplicationPairIsRefusedBeforeAnyPortCall()
{
    Do $$$AssertStatusOK(..EnableDelete(), "the agent's delete key is enabled")
    Set tName = "OCUPROBE182GS"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), tName _ " is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddApplication", "/csp/ocuprobe182gs", tName), "with a bound web application")
    Set tSC = ..MintFor(..#WRITERUSER, ..#DELETETOOL, tName, {"Name": (tName)}, .tProposal)
    Do $$$AssertStatusOK(tSC, "the delete is minted for the principal")
    If $$$ISERR(tSC) Quit
    Set tPlan = []
    Do tPlan.%Push({"kind": "delete", "name": (tName)})
    Do tPlan.%Push({"kind": "confirm", "proposalId": (tProposal.%Get("proposalId"))})
    Set tRun = ..RunAs(..#WRITERUSER, tPlan)
    Do $$$AssertEquals(..Ran(tRun), ..#WRITERUSER _ " 1", "the child process ran as the principal")
    For tI = 1, 2 {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %Admin_Secure:USE calls=0 types=", $Select(tI = 1: "the screen's delete", 1: "the agent's delete confirm") _ ": refused naming the application pair, the port asked nothing")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 1, "the namespace still exists")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsApplication", "/csp/ocuprobe182gs"), 1, "and so does its web application")
}

/// <p>A principal holding exactly the declared pairs: the screen's create, edit and delete and the
/// agent's confirm of each succeed, each reaching the port with its write, and the instance holds
/// what they wrote (AD-29). This is also the floor under the refusal legs' zero.</p>
Method TestExactlyTheDeclaredPairsWriteOnBothCallers()
{
    Do $$$AssertStatusOK(..EnableDelete(), "the agent's delete key is enabled")
    Set tEdit = "OCUPROBE182FE"
    Set tDelete = "OCUPROBE182FD"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tEdit), tEdit _ " is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tDelete), tDelete _ " is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddApplication", "/csp/ocuprobe182fd", tDelete), "with a bound web application")
    Set tAgentEdit = "OCUPROBE182FAE"
    Set tAgentDelete = "OCUPROBE182FAD"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tAgentEdit), tAgentEdit _ " is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tAgentDelete), tAgentDelete _ " is created")
    Set tRun = ..Run(..#FULLUSER, "OCUPROBE182FN", tEdit, tDelete, "OCUPROBE182FAN", tAgentEdit, tAgentDelete)
    For tCase = $ListBuild(1, 201, "PUT", "the screen's create"), $ListBuild(2, 200, "PUT", "the screen's edit"), $ListBuild(3, 200, "DELETE", "the screen's delete"), $ListBuild(4, 200, "PUT", "the agent's create confirm"), $ListBuild(5, 200, "PUT", "the agent's edit confirm"), $ListBuild(6, 200, "DELETE", "the agent's delete confirm") {
        Set tLeg = ..Leg(tRun, $List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http"), 1: ""), $List(tCase, 2), $List(tCase, 4) _ ": succeeds (" _ ..LegText(tRun, $List(tCase, 1)) _ ")")
        Do $$$AssertTrue($IsObject(tLeg) && $ListFind($ListFromString(tLeg.%Get("types")), $List(tCase, 3)), $List(tCase, 4) _ ": through the port's " _ $List(tCase, 3))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBE182FN") _ $ClassMethod(..#PROBE, "Holds", "OCUPROBE182FAN"), "11", "both creates are on the instance")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tEdit, "Routines") _ " " _ $ClassMethod(..#PROBE, "Stored", tAgentEdit, "Routines"), "IRISTEMP IRISTEMP", "both edits are applied")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tDelete) _ $ClassMethod(..#PROBE, "Holds", tAgentDelete), "00", "both deletes removed their namespace")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsApplication", "/csp/ocuprobe182fd"), 0, "and the screen's delete took its web application with it")
}

/// <p>Mint the agent's create of <var>pNew</var>, edit of <var>pAgentEdit</var> and delete of
/// <var>pAgentDelete</var> for <var>pUser</var>, then run as <var>pUser</var> the screen's create of
/// <var>pScreenNew</var>, edit of <var>pEdit</var> and delete of <var>pDelete</var> and the three
/// confirms, in that order. With only the three screen names, the agent's legs take the same
/// targets.</p>
Method Run(pUser As %String, pScreenNew As %String, pEdit As %String, pDelete As %String, pNew As %String = "", pAgentEdit As %String = "", pAgentDelete As %String = "") As %DynamicObject
{
    If pNew = "" Set pNew = pScreenNew _ "A"
    If pAgentEdit = "" Set pAgentEdit = pEdit
    If pAgentDelete = "" Set pAgentDelete = pDelete
    Set tPlan = []
    Do tPlan.%Push({"kind": "create", "name": (pScreenNew), "body": {"Name": (pScreenNew), "Globals": "USER", "Routines": "USER"}})
    Do tPlan.%Push({"kind": "update", "name": (pEdit), "body": {"Routines": "IRISTEMP"}})
    Do tPlan.%Push({"kind": "delete", "name": (pDelete)})
    For tCase = $ListBuild(..#CREATETOOL, pNew, {"Name": (pNew), "Globals": "USER", "Routines": "USER"}.%ToJSON()), $ListBuild(..#UPDATETOOL, pAgentEdit, {"Name": (pAgentEdit), "Routines": "IRISTEMP"}.%ToJSON()), $ListBuild(..#DELETETOOL, pAgentDelete, {"Name": (pAgentDelete)}.%ToJSON()) {
        Set tSC = ..MintFor(pUser, $List(tCase, 1), $List(tCase, 2), ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tProposal)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": minted for the principal")
        Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    }
    Set tRun = ..RunAs(pUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), pUser _ " 1", "the child process ran as the principal")
    Quit tRun
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

/// <p>Run <class>OcuPilot.Test.NamespaceWriteGateProbe</class> as <var>pUser</var> over
/// <var>pPlan</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.NamespaceWriteGateProbe).Run($Job, pUser, tPlan)::10
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

/// <p>Enable the agent's namespace delete key, over the snapshot this class took.</p>
Method EnableDelete() As %Status
{
    Kill tSettings
    Set tSettings(..#DELETEKEY) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>Create the three throwaway roles and the accounts that hold them, then read the grants back:
/// the install namespace's code read and the screens' two pairs; those and the system database
/// write; and those and <code>%Admin_Secure:USE</code>.</p>
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
        For tCase = $ListBuild(..#READERUSER, ..#READERROLE, tCode _ ",%DB_IRISSYS:R,%Admin_Manage:U", 0, 0), $ListBuild(..#WRITERUSER, ..#WRITERROLE, tCode _ ",%DB_IRISSYS:RW,%Admin_Manage:U", 1, 0), $ListBuild(..#FULLUSER, ..#FULLROLE, tCode _ ",%DB_IRISSYS:RW,%Admin_Manage:U,%Admin_Secure:U", 1, 1) {
            Set tUser = $List(tCase, 1)
            Set tRole = $List(tCase, 2)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the namespace write gate (throwaway)", $List(tCase, 3), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot namespace test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.NamespaceWriteGate; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
            If ($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Manage", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(tUser, "%DB_IRISSYS", "READ") '= 1) || (($SYSTEM.Security.CheckUserPermission(tUser, "%DB_IRISSYS", "WRITE") = 1) '= $List(tCase, 4)) || (($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Secure", "USE") = 1) '= $List(tCase, 5)) {
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

}
