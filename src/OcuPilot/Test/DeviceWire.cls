/// <p>The device routes and tools against the instance itself, through the real port (AD-4, AD-8,
/// AD-12, AD-29, AD-39, AD-54, AD-55): the routes' envelopes, a create the list's own read then shows
/// and an edit, the vendor's upsert that would re-create a deleted device and the two callers that
/// refuse first (AC4), a <code>^</code> refused before it reaches the configuration file (AC3), every
/// device route refused to a real principal without <code>%Admin_Manage</code> (AC5), a save refused to
/// one holding the form's pairs without the system database write, and a device created, edited and
/// deleted by a real principal holding only those pairs and that write (AD-29).</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// <code>%Admin_Manage</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because the legs create and delete three users, three roles and devices.
/// <method>OnBeforeAllTests</method> refuses anywhere it does not; every probe is removed by exact
/// name.</p>
Class OcuPilot.Test.DeviceWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FORMPATH = "/device/form";

Parameter NAMEPATH = "/device/name";

Parameter CREATEPATH = "/device";

/// <p>The edit route; <method>EditPath</method> fills its one segment.</p>
Parameter EDITPATH = "/device/:id";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.DeviceUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.DeviceDelete";

Parameter PROBE = "OcuPilot.Test.DeviceProbe";

/// <p>The create suite, whose helpers this class shares.</p>
Parameter SHARED = "OcuPilot.Test.DeviceCreate";

/// <p>The purpose-built principal that holds everything the device screens need but
/// <code>%Admin_Manage</code>.</p>
Parameter NOMANAGEUSER = "OcuPilotWireDeviceNoManage";

Parameter NOMANAGEROLE = "OcuPilotWireDeviceNoManageRole";

/// <p>The purpose-built principal that holds the install namespace's code read and the form's
/// declared pairs, <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code>, and nothing
/// else: it reads the devices and cannot save one.</p>
Parameter READERUSER = "OcuPilotWireDeviceReader";

Parameter READERROLE = "OcuPilotWireDeviceReaderRole";

/// <p>The purpose-built principal that holds the form's declared pairs and the device tools' write
/// pair, <code>%DB_IRISSYS:WRITE</code>, and nothing else.</p>
Parameter MANAGEUSER = "OcuPilotWireDeviceWriter";

Parameter MANAGEROLE = "OcuPilotWireDeviceWriterRole";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DeviceWire creates and deletes users, roles and devices on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotDev" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipal()
}

/// <p>Remove the probe devices, the principals and their roles; a failing status when any survives
/// or the configuration file no longer validates.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If '$ClassMethod(..#PROBE, "CpfValid", .tNamesProbe) || tNamesProbe Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the configuration file does not validate, or names a probe device, after OcuPilot.Test.DeviceWire"))
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#NOMANAGEUSER, ..#READERUSER, ..#MANAGEUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
        }
        For tRole = ..#NOMANAGEROLE, ..#READERROLE, ..#MANAGEROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
        }
        If ##class(Security.Users).Exists(..#NOMANAGEUSER) || ##class(Security.Roles).Exists(..#NOMANAGEROLE) || ##class(Security.Users).Exists(..#READERUSER) || ##class(Security.Roles).Exists(..#READERROLE) || ##class(Security.Users).Exists(..#MANAGEUSER) || ##class(Security.Roles).Exists(..#MANAGEROLE) {
            Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.DeviceWire left a throwaway principal on the instance"))
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
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tSC, "every probe device is removed by exact name")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Quit $$$OK
}

/// <p>AD-12, AD-39: the form read, with a name and without, the name look-up, the create and the
/// edit each answer exactly one JSON envelope over a real HTTP request; the form read carries the
/// six types, the instance's subtypes and one rule per code; a create naming nothing is refused on
/// its own envelope code; and an edit or a form read of a name the instance does not hold is 404 on
/// its own.</p>
Method TestEachRouteAnswersOneJsonEnvelopeOverTheWire()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tName = ..Name("Route")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName, {"Alias": 9922, "Prompt": 2}), "a device is created")
    For tPath = tBase _ ..#FORMPATH, tBase _ ..#FORMPATH _ "?name=" _ tName, tBase _ ..#NAMEPATH _ "?name=" _ tName {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, tUser, tPassword, .tStatus, .tBody, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, tPath _ ": at 200")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tPath _ ": as application/json")
        Do $$$AssertEquals((tBody [ "}{"), 0, tPath _ ": exactly one envelope")
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?name=" _ tName, .tStatus, .tBody)
    Do $$$AssertTrue($IsObject($Get(tBody)), "the form read of a device answers an object")
    If '$IsObject($Get(tBody)) Quit
    Do $$$AssertEquals(tBody.%Get("rules").%Size(), $ListLength(##class(OcuPilot.Api.Error).DeviceViolationCodes()), "one rule per device code")
    Do $$$AssertEquals(tBody.%Get("typeValues").%ToJSON(), "[""TRM"",""SPL"",""MT"",""BT"",""IPC"",""OTH""]", "the six types, in the classic page's order")
    Do $$$AssertTrue(tBody.%Get("subTypes").%ToJSON() [ """P-DEC""", "the instance's subtypes, the classic default among them")
    Do $$$AssertEquals(tBody.%Get("requiredFields").%ToJSON(), "[""Name"",""PhysicalDevice"",""Type"",""SubType""]", "and the four fields a create requires")
    Do $$$AssertEquals(tBody.%Get("device").%ToJSON(), "{""Name"":""" _ tName _ """,""PhysicalDevice"":""/tmp/" _ tName _ ".txt"",""Type"":""OTH"",""SubType"":""P-DEC"",""OpenParameters"":"""",""Description"":"""",""Alias"":9922,""AlternateDevice"":"""",""Prompt"":2}", "the device as its nine fields, in the classic page's order, the alias and prompt as integers")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, tUser, tPassword, .tStatus, .tBody, .tHeaders, "{}", "application/json")
    Do $$$AssertEquals(tStatus, 422, "a create naming nothing is refused at 422")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).code, ##class(OcuPilot.Api.Error).#DEVICEVALIDATION, "with the create's own envelope code")

    Set tGone = ..Name("RouteGone")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ ..EditPath(tGone), tUser, tPassword, .tStatus, .tBody, .tHeaders, "{""Description"":""x""}", "application/json")
    Do $$$AssertEquals(tStatus, 404, "an edit of a name the instance does not hold is 404")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tBody).code, ##class(OcuPilot.Api.Error).#DEVICENAMEABSENT, "with the absent code")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?name=" _ tGone, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tBody)): tBody.%Get("code"), 1: ""), "404 " _ ##class(OcuPilot.Api.Error).#DEVICENAMEABSENT, "and so is the form read of one")
}

/// <p>AC2 over the wire: <code>POST /device</code> creates a device; the name look-up answers it
/// taken and a case variant free; the list's own read then shows it; <code>PUT</code> with one field
/// changes it and keeps the others; and a second create of the name is refused as taken.</p>
Method TestACreateShowsOnTheListAndAnEditUpdatesIt()
{
    Set tName = ..Name("Wire")
    Set tRequest = {"Name": (tName), "PhysicalDevice": "/tmp/p88wire.txt", "Type": "OTH", "SubType": "P-DEC", "Description": "first", "Alias": 9911, "Prompt": 1}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the create answers 201")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)) && (tBody.%GetTypeOf("readBack") = "object"): tBody.%Get("readBack").%Get("verdict") _ " " _ tBody.%Get("readBack").%Get("written").%ToJSON(), 1: ""), "matches []", "carrying the create's read-back, which holds what was sent (AD-58): " _ $Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: ""))
    If $IsObject($Get(tBody)) Do tBody.%Remove("readBack")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: ""), "{""name"":""" _ tName _ """}", "naming the device and nothing else beside it")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#NAMEPATH _ "?name=" _ tName, .tStatus, .tBody)
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%Get("taken") _ "|" _ tBody.%Get("reason"), 1: ""), "1|" _ ##class(OcuPilot.Api.Error).#REASONDEVICENAMETAKEN, "the look-up answers the name as taken, with the published sentence")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#NAMEPATH _ "?name=" _ ..Name("wire"), .tStatus, .tBody)
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%Get("taken"), 1: ""), 0, "and a name differing from it only in case as free")

    Do $$$AssertEquals(..ListRow(tName), "{""Name"":""" _ tName _ """,""PhysicalDevice"":""/tmp/p88wire.txt"",""Type"":""OTH"",""SubType"":""P-DEC"",""Description"":""first"",""Alias"":""9911""}", "the list's own read shows the new device")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..EditPath(tName), .tStatus, .tBody, "{""Description"":""second""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the edit answers 200")
    Do $$$AssertEquals(..ListRow(tName), "{""Name"":""" _ tName _ """,""PhysicalDevice"":""/tmp/p88wire.txt"",""Type"":""OTH"",""SubType"":""P-DEC"",""Description"":""second"",""Alias"":""9911""}", "and the list's read shows the change with every other field kept")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "Prompt"), 1, "the prompt the list does not show is kept too")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 422, "a second create of the name is refused")
    Do $$$AssertTrue($Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: "") [ ##class(OcuPilot.Api.Error).#DEVICENAMETAKEN, "as taken")
}

/// <p>AC4: the vendor's <code>PUT</code> is an upsert -- sent for a name deleted a moment earlier,
/// the raw port answers 201 and the device is back. Both callers refuse first: the screen's edit of
/// the deleted name answers 404 over the wire and the agent's confirm 409, and neither re-creates
/// it.</p>
Method TestTheUpsertWouldRecreateADeletedDeviceAndBothCallersRefuse()
{
    Set tName = ..Name("Gone")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a device is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", tName), "and deleted")
    Kill tQuery
    Set tQuery("name") = tName
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Device.Standard", "PUT", .tQuery, {"PhysicalDevice": "/tmp/p88gone.txt", "Type": "OTH", "SubType": "P-DEC"}, .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 201, "the raw port's PUT answers 201")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 1, "and re-creates the deleted device")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", tName), "which is deleted again")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..EditPath(tName), .tStatus, .tBody, {"Description": "back"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 404, "the screen's edit of the deleted name is refused at 404")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and does not re-create it")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "the device is created once more")
    Set tSC = $ClassMethod(..#SHARED, "MintWith", ..#UPDATETOOL, tName, {"Name": (tName), "Description": "back"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the agent's edit is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", tName), "and the device deleted after the mint")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp _ " " _ $Get(tCode), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and nothing is re-created")
}

/// <p>AC3 over the wire: a <code>^</code> in a create's description or name, and open parameters
/// the instance cannot parse, are refused on their field at 422, no device is created, and the
/// instance's configuration file still validates and names no probe device.</p>
/// <p>Mutation (Rule 19): drop the <code>^</code> test from
/// <method>OcuPilot.Area.OsMgmt.DeviceRules.Writable</method> -> the description is written raw
/// into the configuration file, which then fails to validate, and this goes red.</p>
Method TestACaretIsRefusedAndTheConfigurationFileStaysValid()
{
    Set tName = ..Name("Caret")
    For tCase = $ListBuild(tName, "Description", "a^b", "DEVICE.DESCRIPTION.SHAPE"), $ListBuild(..Name("Caret^x"), "Name", "", "DEVICE.NAME.SHAPE"), $ListBuild(tName, "OpenParameters", "(((", "DEVICE.OPENPARAMETERS.SHAPE") {
        Set tRequest = {"Name": ($List(tCase, 1)), "PhysicalDevice": "/tmp/p88caret.txt", "Type": "OTH", "SubType": "P-DEC"}
        If $List(tCase, 3) '= "" Do tRequest.%Set($List(tCase, 2), $List(tCase, 3), "string")
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
        Do $$$AssertEquals(tStatus, 422, $List(tCase, 4) _ ": refused at 422")
        Do $$$AssertEquals(..ViolationCode(tBody, $List(tCase, 2)), $List(tCase, 4), $List(tCase, 4) _ ": on its field")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", $List(tCase, 1)), 0, $List(tCase, 4) _ ": and no device is created")
    }
    Do $$$AssertTrue($ClassMethod(..#PROBE, "CpfValid", .tNamesProbe), "the configuration file validates")
    Do $$$AssertEquals(tNamesProbe, 0, "and names no probe device")
}

/// <p>AC5 with a real principal: a caller holding the install namespace's code, the system database
/// read and the secure resource but not <code>%Admin_Manage</code> is refused on every device route
/// with the screen-privilege code naming <code>%Admin_Manage:USE</code>, before anything is read or
/// written, and the navigation map lists the form denied on the same pair.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_Manage</code> from
/// <class>OcuPilot.Screen.Descriptor.DeviceForm</class>'s privileges -> the routes pass the gate and
/// this goes red.</p>
Method TestACallerWithoutTheManageResourceIsRefusedOnEveryRoute()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tName = ..Name("Denied")
    Set tRoutes = $ListBuild($ListBuild("GET", ..#FORMPATH), $ListBuild("GET", ..#FORMPATH _ "?name=" _ tName), $ListBuild("GET", ..#NAMEPATH _ "?name=" _ tName), $ListBuild("POST", ..#CREATEPATH), $ListBuild("PUT", ..EditPath(tName)))
    For tI = 1:1:$ListLength(tRoutes) {
        Set tMethod = $List($List(tRoutes, tI), 1)
        Set tPath = tBase _ $List($List(tRoutes, tI), 2)
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(tMethod, tPath, ..#NOMANAGEUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders, $Select(tMethod = "GET": "", 1: "{""Name"":""" _ tName _ """,""PhysicalDevice"":""/tmp/p88.txt"",""Type"":""OTH"",""SubType"":""P-DEC""}"), $Select(tMethod = "GET": "", 1: "application/json"))
        Do $$$AssertEquals(tStatus, 403, tMethod _ " " _ tPath _ ": is refused")
        Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tRefusal.code, "AUTH.NOPRIVILEGE", tMethod _ " " _ tPath _ ": on the screen-privilege code")
        Do $$$AssertEquals($Select($IsObject(tRefusal.detail): tRefusal.detail.failedPair, 1: ""), "%Admin_Manage:USE", tMethod _ " " _ tPath _ ": naming %Admin_Manage:USE")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and nothing was created")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/navigation", ..#NOMANAGEUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the navigation map answers the principal")
    Do $$$AssertTrue(tBody [ "{""route"":""os-management/devices/edit"",""labelKey"":""deviceFormLabel"",""sideBarPosition"":0,""allowed"":false,""failedPair"":""%Admin_Manage:USE""}", "and lists the form denied on the manage pair")
}

/// <p>AD-29: a real principal holding the form's declared pairs alone opens the form, and its Save is
/// refused naming <code>%DB_IRISSYS:WRITE</code> before anything is sent; nothing is created. The
/// agent's confirm of the same write is refused on the pair too
/// (<class>OcuPilot.Test.DeviceWriteGate</class>).</p>
/// <p>Mutation (Rule 19): drop the write pair from
/// <method>OcuPilot.Area.OsMgmt.DeviceSave.Gate</method> -> the Save reaches the vendor, whose save
/// is refused inside the system database, and this goes red on the 403.</p>
Method TestTheFormsPairsAloneReadButCannotSave()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tName = ..Name("Reader")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#FORMPATH, ..#READERUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the principal's form read answers 200")
    Set tRequest = {"Name": (tName), "PhysicalDevice": "/tmp/p88reader.txt", "Type": "OTH", "SubType": "P-DEC"}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, ..#READERUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 403, "its create is refused at 403: " _ $Extract(tBody, 1, 300))
    Set tRefusal = ""
    Try { Set tRefusal = ##class(%DynamicObject).%FromJSON(tBody) } Catch {}
    Do $$$AssertEquals($Select($IsObject(tRefusal) && $IsObject(tRefusal.detail): tRefusal.code _ " " _ tRefusal.detail.failedPair, 1: ""), "AUTH.NOPRIVILEGE %DB_IRISSYS:WRITE", "on the screen-privilege code, naming the system database write")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and nothing is created")
    Set tPairs = $ClassMethod("OcuPilot.Screen.Tool.DeviceCreate", "PrivilegePairs", "", .tResolved)
    Do $$$AssertTrue($ListFind(tPairs, $ListBuild("%DB_IRISSYS", "WRITE")), "the agent's create requires the same pair")
}

/// <p>AD-29: a real principal holding only the install namespace's code read, the form's declared
/// pairs and the device tools' write pair creates a device, reads and edits it on the screen's
/// routes, and deletes it through the agent's delete confirmed over the wire as that principal -- so
/// no write needs a pair the tools do not declare.</p>
/// <p>Mutation (Rule 19): give the principal <code>%DB_IRISSYS</code> read alone -> the create is
/// refused and this goes red.</p>
Method TestTheDeclaredPairsAloneCreateEditAndDeleteADevice()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tName = ..Name("Least")
    Set tRequest = {"Name": (tName), "PhysicalDevice": "/tmp/p88least.txt", "Type": "OTH", "SubType": "P-DEC"}
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, ..#MANAGEUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders, tRequest.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "the principal's create answers 201: " _ $Extract(tBody, 1, 300))
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#FORMPATH _ "?name=" _ tName, ..#MANAGEUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "its form read answers the principal")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ ..EditPath(tName), ..#MANAGEUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders, "{""Description"":""least""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "and its edit answers 200")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "Description"), "least", "which the instance applied")

    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#MANAGEUSER, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a completed turn is seeded for the principal")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(..#DELETETOOL, "DESCRIPTORCLASS"), $Parameter(..#DELETETOOL, "TOOLNAME"), ..#MANAGEUSER, "", tTurn, {"Name": (tName)}, "OcuPilot.Kernel.Agent.Limits", .tProposal, .tHttp, .tFault, $ClassMethod(..#DELETETOOL, "Endpoint"), $ClassMethod(..#DELETETOOL, "IdParam"), tName, $ClassMethod(..#DELETETOOL, "IdArgument"), $ClassMethod(..#DELETETOOL, "SettableFields"), ..#DELETETOOL)
    Do $$$AssertStatusOK(tSC, "the principal's delete is minted")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/proposal/" _ tProposal.%Get("proposalId") _ "/confirm", ..#MANAGEUSER, ..PreparedPassword, .tStatus, .tBody, .tHeaders, "", "application/json")
    Do $$$AssertEquals(tStatus, 200, "and confirmed over the wire as the principal: " _ $Extract(tBody, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "which deletes the device")
}

/// <p>The list's own read row for <var>pName</var>, as compact JSON, or <code>""</code>.</p>
ClassMethod ListRow(pName As %String) As %String
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/screens/osmgmt.devices/read?maxRows=1000", .tStatus, .tBody)
    Set tRow = ""
    If $IsObject($Get(tBody)) && (tBody.%GetTypeOf("rows") = "array") {
        Set tIterator = tBody.%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If $IsObject(tEntry) && (tEntry.%Get("Name") = pName) Set tRow = tEntry.%ToJSON()
        }
    }
    Quit tRow
}

/// <p>The code the 422 envelope <var>pBody</var> carries for <var>pField</var>, or <code>""</code>.</p>
ClassMethod ViolationCode(pBody, pField As %String) As %String
{
    Set tCode = ""
    Try {
        Set tBody = $Select($IsObject(pBody): pBody, 1: ##class(%DynamicObject).%FromJSON(pBody))
        Set tIterator = tBody.%Get("detail").%Get("violations").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.%Get("field") = pField Set tCode = tRow.%Get("code") Quit
        }
    } Catch {
        Set tCode = ""
    }
    Quit tCode
}

ClassMethod Name(pSuffix As %String) As %String
{
    Quit $ClassMethod(..#SHARED, "Name", pSuffix)
}

/// <p><parameter>EDITPATH</parameter> for <var>pName</var>, its segment encoded by the one shared
/// encoder (AD-13).</p>
ClassMethod EditPath(pName As %String) As %String
{
    Quit $Replace(..#EDITPATH, ":id", ##class(OcuPilot.Kernel.EntityId).Encode(pName))
}

/// <p>Create the three throwaway roles and the accounts that hold them, then read the grants back:
/// <parameter>NOMANAGEROLE</parameter> -- the install namespace's code read, the system database read
/// and the secure resource, and no manage resource; <parameter>READERROLE</parameter> -- the code
/// read and the form's two declared pairs; and <parameter>MANAGEROLE</parameter> -- those and the
/// system database write.</p>
Method EnsurePrincipal() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tSysDb = ##class(SYS.Database).%OpenId(tDatabase.Directory)
        If ##class(Security.Roles).Exists(..#NOMANAGEROLE) Do ##class(Security.Roles).Delete(..#NOMANAGEROLE)
        Set tSC = ##class(Security.Roles).Create(..#NOMANAGEROLE, "OcuPilot test: no manage resource (throwaway)", tSysDb.ResourceName _ ":R,%DB_IRISSYS:R,%Admin_Secure:U", "")
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#NOMANAGEUSER) Do ##class(Security.Users).Delete(..#NOMANAGEUSER)
        Set tSC = ##class(Security.Users).Create(..#NOMANAGEUSER, ..#NOMANAGEROLE, ..PreparedPassword, "OcuPilot device test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.DeviceWire; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#NOMANAGEUSER, "%Admin_Manage", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#NOMANAGEUSER, "%DB_IRISSYS", "READ") '= 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal's grants did not read back as the system read without the manage resource")
            Quit
        }
        If ##class(Security.Roles).Exists(..#MANAGEROLE) Do ##class(Security.Roles).Delete(..#MANAGEROLE)
        If ##class(Security.Roles).Exists(..#READERROLE) Do ##class(Security.Roles).Delete(..#READERROLE)
        Set tSC = ##class(Security.Roles).Create(..#READERROLE, "OcuPilot test: the device form's pairs alone (throwaway)", tSysDb.ResourceName _ ":R,%DB_IRISSYS:R,%Admin_Manage:U", "")
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#READERUSER) Do ##class(Security.Users).Delete(..#READERUSER)
        Set tSC = ##class(Security.Users).Create(..#READERUSER, ..#READERROLE, ..PreparedPassword, "OcuPilot device test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.DeviceWire; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#READERUSER, "%Admin_Manage", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#READERUSER, "%DB_IRISSYS", "WRITE") = 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the reader principal's grants did not read back as the form's pairs alone")
            Quit
        }
        If ##class(Security.Roles).Exists(..#MANAGEROLE) Do ##class(Security.Roles).Delete(..#MANAGEROLE)
        Set tSC = ##class(Security.Roles).Create(..#MANAGEROLE, "OcuPilot test: the device tools' pairs alone (throwaway)", tSysDb.ResourceName _ ":R,%DB_IRISSYS:RW,%Admin_Manage:U", "")
        If $$$ISERR(tSC) Quit
        If ##class(Security.Users).Exists(..#MANAGEUSER) Do ##class(Security.Users).Delete(..#MANAGEUSER)
        Set tSC = ##class(Security.Users).Create(..#MANAGEUSER, ..#MANAGEROLE, ..PreparedPassword, "OcuPilot device test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.DeviceWire; deleted in OnAfterAllTests")
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#MANAGEUSER, "%Admin_Manage", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#MANAGEUSER, "%DB_IRISSYS", "WRITE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#MANAGEUSER, "%Admin_Secure", "USE") = 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the writer principal's grants did not read back as the device tools' pairs alone")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
