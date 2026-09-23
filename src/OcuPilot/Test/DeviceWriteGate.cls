/// <p>AD-8's one named case: the device tools' <code>%DB_IRISSYS:WRITE</code>, declared beyond the
/// Devices screens' read-only pairs. A real principal holding only those pairs
/// (<code>%Admin_Manage:USE</code>, <code>%DB_IRISSYS:READ</code>) is refused 403
/// <code>AUTH.NOPRIVILEGE</code> naming the write pair on the screen's create and edit and on the
/// agent's confirm of each device tool, and the port is asked nothing, reads included; one that also
/// holds the write pair writes on both callers; and the Devices list still opens for a principal
/// without it.</p>
/// <p>The Save and confirm legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.DeviceWriteGateProbe</class>), which reports what
/// <class>OcuPilot.Test.DeviceRecordPort</class> was asked; the list leg runs over the wire.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and
/// deletes two users, two roles and devices. <method>OnBeforeAllTests</method> refuses anywhere it
/// does not; every probe device is removed by exact name.</p>
Class OcuPilot.Test.DeviceWriteGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.DeviceProbe";

/// <p>The create suite, whose helpers this class shares.</p>
Parameter SHARED = "OcuPilot.Test.DeviceCreate";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.DeviceCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.DeviceUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.DeviceDelete";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The purpose-built principal holding the install namespace's code read and the Devices
/// screens' declared pairs, and nothing else.</p>
Parameter READERUSER = "OcuPilotDeviceGateReader";

Parameter READERROLE = "OcuPilotDeviceGateReaderRole";

/// <p>The purpose-built principal holding those and the device tools' write pair.</p>
Parameter WRITERUSER = "OcuPilotDeviceGateWriter";

Parameter WRITERROLE = "OcuPilotDeviceGateWriterRole";

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
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DeviceWriteGate creates and deletes users, roles and devices on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotGate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipals()
}

/// <p>Remove the probe devices, the principals and their roles; a failing status when any survives
/// or the configuration file no longer validates.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If '$ClassMethod(..#PROBE, "CpfValid", .tNamesProbe) || tNamesProbe Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the configuration file does not validate, or names a probe device, after OcuPilot.Test.DeviceWriteGate"))
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#READERUSER, ..#WRITERUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
        }
        For tRole = ..#READERROLE, ..#WRITERROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
        }
        If ##class(Security.Users).Exists(..#READERUSER) || ##class(Security.Users).Exists(..#WRITERUSER) || ##class(Security.Roles).Exists(..#READERROLE) || ##class(Security.Roles).Exists(..#WRITERROLE) {
            Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.DeviceWriteGate left a throwaway principal on the instance"))
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
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe device is removed by exact name")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>A principal holding the screens' declared pairs alone: the screen's create and edit and the
/// agent's confirm of a create, an edit and a delete are each refused 403 on the screen-privilege
/// code naming <code>%DB_IRISSYS:WRITE</code>, and the port is asked nothing -- not even the edit's
/// fresh read or the confirm's re-read. Nothing is created, changed or deleted. A create whose name
/// breaks the name's own rule is refused on the pair too: the create's rules and the prohibited set
/// read through the tools' port, which the recording port does not see, so the refusal coming before
/// the name's rule is what shows the pair is checked before any of them.</p>
/// <p>Mutations (Rule 19): drop the write pair from
/// <method>OcuPilot.Area.OsMgmt.DeviceSave.Gate</method> -> the two screen legs reach the port and
/// go red; run the name's rule before the gate in
/// <method>OcuPilot.Area.OsMgmt.DeviceSave.HandleCreate</method> -> the bad-name leg answers 422 and
/// goes red; drop the write pair from a device tool's <method>PrivilegePairs</method> -> that tool's
/// confirm leg reaches the port and goes red.</p>
Method TestTheScreensPairsAloneAreRefusedTheWriteBeforeAnyPortCall()
{
    Set tEdit = ..Name("GateEdit")
    Set tNew = ..Name("GateNew")
    Set tBad = ..Name("Gate^Bad")
    Set tAgentNew = ..Name("GateAgentNew")
    Set tAgentDel = ..Name("GateAgentDel")
    For tName = tEdit, tAgentDel {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName, {"Description": "kept"}), tName _ ": a device is created")
    }
    Set tPlan = []
    Do tPlan.%Push({"kind": "create", "name": (tNew), "body": (..CreateBody(tNew))})
    Do tPlan.%Push({"kind": "create", "name": (tBad), "body": (..CreateBody(tBad))})
    Do tPlan.%Push({"kind": "update", "name": (tEdit), "body": {"Description": "changed"}})
    For tCase = $ListBuild(..#CREATETOOL, tAgentNew, ..CreateBody(tAgentNew).%ToJSON()), $ListBuild(..#UPDATETOOL, tEdit, {"Name": (tEdit), "Description": "changed"}.%ToJSON()), $ListBuild(..#DELETETOOL, tAgentDel, {"Name": (tAgentDel)}.%ToJSON()) {
        Set tSC = ..MintFor(..#READERUSER, $List(tCase, 1), $List(tCase, 2), $List(tCase, 3), .tProposal)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": minted for the principal")
        If $$$ISERR(tSC) Return
        Do tPlan.%Push({"kind": "confirm", "proposalId": (tProposal.%Get("proposalId"))})
    }
    Set tRun = ..RunAs(..#READERUSER, tPlan)
    Do $$$AssertEquals($Select(tRun.%IsDefined("error"): tRun.%Get("error"), 1: tRun.%Get("username") _ " " _ tRun.%Get("loggedIn")), ..#READERUSER _ " 1", "the child process ran as the principal")
    Set tLabels = $ListBuild("the screen's create", "the screen's create of a name its rule refuses", "the screen's edit", "the agent's create confirm", "the agent's edit confirm", "the agent's delete confirm")
    For tI = 1:1:$ListLength(tLabels) {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %DB_IRISSYS:WRITE calls=0 types=", $List(tLabels, tI) _ ": refused naming the write pair, the port asked nothing")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tNew) + $ClassMethod(..#PROBE, "Holds", tAgentNew), 0, "no device is created")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tEdit, "Description"), "kept", "the edited device is unchanged")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tAgentDel), 1, "and the one the delete names is still there")
}

/// <p>A principal that also holds <code>%DB_IRISSYS:WRITE</code>: the screen's create and edit and
/// the agent's confirm of a create, an edit and a delete each succeed, each reaching the port with its
/// write, and the instance holds what they wrote. This is also the floor under the refusal leg's
/// zero: the child's record does see the port's calls.</p>
/// <p>Mutation (Rule 19): point the device tools' <parameter>WRITERESOURCE</parameter> at a pair the
/// principal does not hold -> both callers refuse it and this goes red.</p>
Method TestTheWritePairAddedLetsBothCallersWrite()
{
    Set tNew = ..Name("GateNew")
    Set tEdit = ..Name("GateEdit")
    Set tAgentNew = ..Name("GateAgentNew")
    Set tAgentEdit = ..Name("GateAgentEdit")
    Set tAgentDel = ..Name("GateAgentDel")
    For tName = tEdit, tAgentEdit, tAgentDel {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName, {"Description": "before"}), tName _ ": a device is created")
    }
    Set tPlan = []
    Do tPlan.%Push({"kind": "create", "name": (tNew), "body": (..CreateBody(tNew))})
    Do tPlan.%Push({"kind": "update", "name": (tEdit), "body": {"Description": "screen"}})
    For tCase = $ListBuild(..#CREATETOOL, tAgentNew, ..CreateBody(tAgentNew).%ToJSON()), $ListBuild(..#UPDATETOOL, tAgentEdit, {"Name": (tAgentEdit), "Description": "agent"}.%ToJSON()), $ListBuild(..#DELETETOOL, tAgentDel, {"Name": (tAgentDel)}.%ToJSON()) {
        Set tSC = ..MintFor(..#WRITERUSER, $List(tCase, 1), $List(tCase, 2), $List(tCase, 3), .tProposal)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": minted for the principal")
        If $$$ISERR(tSC) Return
        Do tPlan.%Push({"kind": "confirm", "proposalId": (tProposal.%Get("proposalId"))})
    }
    Set tRun = ..RunAs(..#WRITERUSER, tPlan)
    Do $$$AssertEquals($Select(tRun.%IsDefined("error"): tRun.%Get("error"), 1: tRun.%Get("username") _ " " _ tRun.%Get("loggedIn")), ..#WRITERUSER _ " 1", "the child process ran as the principal")
    For tCase = $ListBuild(1, 201, "PUT", "the screen's create"), $ListBuild(2, 200, "PUT", "the screen's edit"), $ListBuild(3, 200, "PUT", "the agent's create confirm"), $ListBuild(4, 200, "PUT", "the agent's edit confirm"), $ListBuild(5, 200, "DELETE", "the agent's delete confirm") {
        Set tLeg = ..Leg(tRun, $List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http"), 1: ""), $List(tCase, 2), $List(tCase, 4) _ ": succeeds (" _ ..LegText(tRun, $List(tCase, 1)) _ ")")
        Do $$$AssertTrue($IsObject(tLeg) && $ListFind($ListFromString(tLeg.%Get("types")), $List(tCase, 3)), $List(tCase, 4) _ ": through the port's " _ $List(tCase, 3))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tNew) _ $ClassMethod(..#PROBE, "Holds", tAgentNew), "11", "both creates are on the instance")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tEdit, "Description") _ " " _ $ClassMethod(..#PROBE, "Stored", tAgentEdit, "Description"), "screen agent", "both edits are applied")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tAgentDel), 0, "and the delete removed its device")
}

/// <p>The screens' own pair set stays read-only: the principal without the write pair reads the
/// Devices list and its form, and the navigation map lists the list allowed.</p>
/// <p>Mutation (Rule 19): add <code>%DB_IRISSYS:WRITE</code> to
/// <class>OcuPilot.Screen.Descriptor.DeviceList</class>'s privileges -> the list read is refused and
/// this goes red.</p>
Method TestTheDevicesListStillOpensWithoutTheWritePair()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/osmgmt.devices/read?maxRows=1000", ..#READERUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the Devices list's read answers the principal: " _ $Extract(tBody, 1, 200))
    Set tRows = ""
    Try { Set tRows = ##class(%DynamicObject).%FromJSON(tBody).%Get("rows") } Catch {}
    Do $$$AssertTrue($IsObject(tRows) && (tRows.%Size() > 0), "with the instance's devices")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/device/form", ..#READERUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "and the form's read")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/navigation", ..#READERUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the navigation map answers the principal")
    Do $$$AssertTrue(tBody [ """route"":""os-management/devices"",""labelKey"":""deviceListLabel"",""sideBarPosition"":5,""allowed"":true", "and lists the Devices list allowed")
}

/// <p>A create's body for <var>pName</var>: the three fields the vendor's create requires.</p>
ClassMethod CreateBody(pName As %String) As %DynamicObject
{
    Quit {"Name": (pName), "PhysicalDevice": "/tmp/p88gate.txt", "Type": "OTH", "SubType": "P-DEC"}
}

/// <p>Mint <var>pToolClass</var>'s proposal for <var>pName</var> from the JSON arguments
/// <var>pArgsJson</var> on behalf of <var>pUser</var>, over a completed turn seeded for that
/// user.</p>
Method MintFor(pUser As %String, pToolClass As %String, pName As %String, pArgsJson As %String, Output pProposal As %DynamicObject) As %Status
{
    Set pProposal = ""
    Set tArgs = ##class(%DynamicObject).%FromJSON(pArgsJson)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurn)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(pToolClass, "DESCRIPTORCLASS"), $Parameter(pToolClass, "TOOLNAME"), pUser, "", tTurn, tArgs, ..#LIMITS, .pProposal, .tHttp, .tFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pName, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(pProposal) Quit $$$ERROR($$$GeneralError, "the mint answered no proposal: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: $Get(tHttp)))
    Quit $$$OK
}

/// <p>Run <class>OcuPilot.Test.DeviceWriteGateProbe</class> as <var>pUser</var> over <var>pPlan</var> in a child
/// process and answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.DeviceWriteGateProbe).Run($Job, pUser, tPlan)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 120)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 120 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>Step <var>pIndex</var> (from 1) of the child's answer <var>pRun</var>, or <code>""</code>.</p>
ClassMethod Leg(pRun As %DynamicObject, pIndex As %Integer) As %DynamicObject
{
    If '$IsObject(pRun) || (pRun.%GetTypeOf("steps") '= "array") Quit ""
    Quit pRun.%Get("steps").%Get(pIndex - 1)
}

/// <p>Step <var>pIndex</var> as <code>http code failedPair calls=n types=t</code>, for one-line
/// comparisons.</p>
ClassMethod LegText(pRun As %DynamicObject, pIndex As %Integer) As %String
{
    Set tLeg = ..Leg(pRun, pIndex)
    If '$IsObject(tLeg) Quit "absent"
    Quit tLeg.%Get("http") _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair") _ " calls=" _ tLeg.%Get("calls") _ " types=" _ tLeg.%Get("types")
}

ClassMethod Name(pSuffix As %String) As %String
{
    Quit $ClassMethod(..#SHARED, "Name", pSuffix)
}

/// <p>Create the two throwaway roles and the accounts that hold them, then read the grants back:
/// <parameter>READERROLE</parameter> -- the install namespace's code read and the screens' two
/// declared pairs; <parameter>WRITERROLE</parameter> -- those and the system database write.</p>
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
        For tCase = $ListBuild(..#READERUSER, ..#READERROLE, tCode _ ",%DB_IRISSYS:R,%Admin_Manage:U", 0), $ListBuild(..#WRITERUSER, ..#WRITERROLE, tCode _ ",%DB_IRISSYS:RW,%Admin_Manage:U", 1) {
            Set tUser = $List(tCase, 1)
            Set tRole = $List(tCase, 2)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the device write gate (throwaway)", $List(tCase, 3), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot device test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.DeviceWriteGate; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
            If ($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Manage", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(tUser, "%DB_IRISSYS", "READ") '= 1) || (($SYSTEM.Security.CheckUserPermission(tUser, "%DB_IRISSYS", "WRITE") = 1) '= $List(tCase, 4)) || ($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Secure", "USE") = 1) {
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
