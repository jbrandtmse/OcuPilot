/// <p>Pins the service form's routes over the wire (AD-4, AD-8, AD-10, AD-12, AD-39, AD-55): the form
/// read (<code>GET /services/form?name=</code>) and the Save (<code>PUT /services/:id</code>) through
/// the Matrix's rows -- an added address whose other fields read back, the three rules, an undeclared
/// key and an absent service -- the serving service's Save refused before any write while its
/// address change is permitted, and a least-privileged principal holding exactly the form's pairs
/// saving.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the test principal
/// holding <code>%All</code>, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>PRINCIPALSVARIABLE</parameter> reading <code>1</code>: it writes
/// <code>%Service_CallIn</code>, disabled, restoring the snapshot it took, and creates one throwaway
/// principal. The serving service is only read: its Save legs go through
/// <class>OcuPilot.Test.ServiceSaveHeldFixture</class>, whose port never sends a <code>PUT</code>.
/// <method>OnBeforeAllTests</method> refuses anywhere either variable does not read 1.</p>
Class OcuPilot.Test.ServiceEdit Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's service writes.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SERVICE_CONFIG";

/// <p>The environment variable that arms its throwaway principal.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ServiceLdapProbe";

Parameter HELDSAVE = "OcuPilot.Test.ServiceSaveHeldFixture";

Parameter HELDPORT = "OcuPilot.Test.HeldPutPort";

Parameter EDITPATH = "/services/:id";

Parameter LEASTUSER = "OcuPilotWire99Service";

Parameter LEASTROLE = "OcuPilotWire99ServiceRole";

/// <p>The service's read as it stood before the class ran, restored after every test.</p>
Property SnapshotJson As %String(MAXLEN = "");

/// <p>The throwaway principal's password, generated for the run.</p>
Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..SnapshotJson = ""
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ServiceEdit writes %Service_CallIn on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ServiceEdit creates and deletes a user and a role on this instance and runs on a throwaway container only. " _ ..#PRINCIPALSVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Snapshot", .tSnapshot)
    If $$$ISERR(tSC) Quit tSC
    Set ..SnapshotJson = tSnapshot
    Set ..PreparedPassword = "OcuPilotSvc" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $ClassMethod(..#PROBE, "EnsurePrincipal", ..#LEASTUSER, ..#LEASTROLE, "%Admin_Secure:U,%DB_IRISSYS:R", ..PreparedPassword)
}

Method OnAfterOneTest() As %Status
{
    Quit $ClassMethod(..#PROBE, "Restore", ..SnapshotJson)
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Restore", ..SnapshotJson)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemovePrincipal", ..#LEASTUSER, ..#LEASTROLE))
}

/// <p>The form read answers the change tool's fresh read with the name, and whether the service is
/// the one OcuPilot is served through, in any spelling of its name; an absent name is 404
/// <code>SERVICE.ABSENT</code>.</p>
Method TestTheFormReadAnswersOneService()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/services/form?name=%25Service_CallIn", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the form read answers")
    If $IsObject($Get(tAnswer)) {
        Set tService = tAnswer.%Get("service")
        Do $$$AssertTrue($IsObject(tService), "with the service")
        If $IsObject(tService) Do $$$AssertEquals(tService.%Get("Name") _ " " _ tService.%GetTypeOf("AutheEnabled") _ " " _ tService.%GetTypeOf("ClientSystems") _ " " _ tService.%GetTypeOf("Enabled"), "%Service_CallIn number array boolean", "carrying the vendor's fields in its types")
        Do $$$AssertEquals(tAnswer.%Get("servesOcuPilot"), 0, "which does not serve OcuPilot")
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/services/form?name=%25service_webgateway", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("servesOcuPilot"), 1: ""), "200 1", "the gateway service serves OcuPilot, in any case")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/services/form?name=OcuPilotNoSuchService99", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "404 SERVICE.ABSENT", "an absent service is 404")
}

/// <p>Matrix "Add an address", AD-4: the Save adds one address, answers 200, and the service reads
/// back with that address and its authentication methods and enablement unchanged; the Services list's
/// own read shows it.</p>
Method TestAnAddedAddressKeepsEveryOtherField()
{
    Set tBefore = ##class(%DynamicObject).%FromJSON(..SnapshotJson)
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path("%Service_CallIn"), .tStatus, .tAnswer, "{""ClientSystems"":[""10.0.0.1""]}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the Save answers: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Set tSC = $ClassMethod(..#PROBE, "Read", "%Service_CallIn", .tAfter)
    Do $$$AssertStatusOK(tSC, "the service reads back")
    If '$IsObject($Get(tAfter)) Quit
    Do $$$AssertEquals(tAfter.%Get("ClientSystems").%ToJSON(), "[""10.0.0.1""]", "with the address")
    Do $$$AssertEquals(tAfter.%Get("AutheEnabled") _ " " _ tAfter.%Get("Enabled"), tBefore.%Get("AutheEnabled") _ " " _ tBefore.%Get("Enabled"), "and its methods and enablement as they were")
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Service", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tShown = ""
    If $IsObject($Get(tRows)) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If $IsObject(tRow) && (tRow.%Get("Name") = "%Service_CallIn") Set tShown = tRow.%Get("AllowedConnections").%ToJSON()
        }
    }
    Do $$$AssertEquals(tShown, "[""10.0.0.1""]", "and the list's allowed addresses show it")
}

/// <p>AD-39, AD-55: each rule refuses the Save as one 422 <code>SERVICE.VALIDATION</code> envelope on
/// <code>ClientSystems</code> or <code>AutheEnabled</code> with its published sentence; an undeclared
/// key is 400 and an absent service 404 <code>SERVICE.ABSENT</code>; nothing is written by any of
/// them.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Permissions.ServiceRules.EntryShaped</method>
/// accept a semicolon -- the semicolon leg goes red.</p>
Method TestTheRulesRefuseTheSave()
{
    For tCase = $ListBuild("{""ClientSystems"":[""a;b""]}", "ClientSystems", "SERVICE.ADDRESS.SHAPE"), $ListBuild("{""ClientSystems"":[""10.0.0.1|OcuPilotNoSuchRole99""]}", "ClientSystems", "SERVICE.ADDRESS.ROLE"), $ListBuild("{""AutheEnabled"":262192}", "AutheEnabled", "SERVICE.AUTHE.UNSUPPORTED") {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path("%Service_CallIn"), .tStatus, .tAnswer, $List(tCase, 1), "application/json")
        Set tRow = ""
        If $IsObject($Get(tAnswer)) && (tAnswer.%GetTypeOf("detail") = "object") Set tRow = tAnswer.%Get("detail").%Get("violations").%Get(0)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "422 SERVICE.VALIDATION", $List(tCase, 1) _ " is refused")
        Do $$$AssertEquals($Select($IsObject(tRow): tRow.%Get("field") _ " " _ tRow.%Get("code") _ " " _ tRow.%Get("reason"), 1: ""), $List(tCase, 2) _ " " _ $List(tCase, 3) _ " " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase, 3)), "on its field with the published sentence")
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path("%Service_CallIn"), .tStatus, .tAnswer, "{""Description"":""changed""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "400 PORT.FIELD.UNEXPECTED", "the description is never settable")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path("OcuPilotNoSuchService99"), .tStatus, .tAnswer, "{""Enabled"":false}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "404 SERVICE.ABSENT", "an absent service is 404")
    Set tSC = $ClassMethod(..#PROBE, "Read", "%Service_CallIn", .tAfter)
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%ToJSON(), 1: ""), ..SnapshotJson, "and the service reads back as it was")
}

/// <p>AD-10 as amended, AC5: the Save that turns the serving service off is refused 403
/// <code>PROHIBITED.SERVINGSERVICE</code> with the published sentence before any <code>PUT</code>,
/// while an address change on it is permitted and reaches the port -- a held port, which records the
/// <code>PUT</code> and never sends it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.ServingServiceDisabled</method>
/// answer 0 -- the disable reaches the held port and this goes red.</p>
Method TestTheServingServiceSaveIsRefusedBeforeAnyWrite()
{
    Set tServing = $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SERVINGSERVICENAME")
    Do $ClassMethod(..#HELDPORT, "Clear")
    Set tSC = $ClassMethod(..#HELDSAVE, "Update", tServing, {"Enabled": false}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "403 PROHIBITED.SERVINGSERVICE", "turning it off is refused")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.reason, 1: ""), $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SERVINGSERVICEREASON"), "with the published sentence")
    Do $$$AssertEquals($ClassMethod(..#HELDPORT, "WriteCount"), 0, "before any PUT")
    Set tSC = $ClassMethod(..#HELDSAVE, "Update", tServing, {"ClientSystems": ["10.0.0.1"]}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(+$Get(tViolations) _ " " _ $ClassMethod(..#HELDPORT, "WriteCount") _ " " _ $ClassMethod(..#HELDPORT, "LastType"), "0 1 PUT", "an address change is permitted and reaches the held port, which sends nothing")
    Set tBody = ##class(%DynamicObject).%FromJSON($ClassMethod(..#HELDPORT, "LastWriteBody"))
    Do $$$AssertEquals(tBody.%Get("Enabled"), 1, "carrying the service's own enablement")
    Do $ClassMethod(..#HELDPORT, "Clear")
}

/// <p>AD-8 with a real principal: holding exactly the form's two pairs, it reads the form and saves an
/// address; holding the pairs less <code>%Admin_Secure:USE</code>, the admin API alone would refuse
/// it, so the declared set is what the Save needs.</p>
Method TestALeastPrivilegedPrincipalSaves()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/services/form?name=%25Service_CallIn", ..#LEASTUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the least-privileged principal reads the form")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Set tRead = ""
    Try { Set tRead = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
    Do $$$AssertTrue($IsObject(tRead) && (tRead.%GetTypeOf("service") = "object"), "one envelope carrying the service")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ ..Path("%Service_CallIn"), ..#LEASTUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders, "{""ClientSystems"":[""10.0.0.2""]}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "and saves: " _ $Get(tText))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "answering application/json")
    Set tSaved = ""
    Try { Set tSaved = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
    Do $$$AssertTrue($IsObject(tSaved) && (tSaved.%Get("name") '= ""), "one envelope naming what it saved")
    Set tSC = $ClassMethod(..#PROBE, "Read", "%Service_CallIn", .tAfter)
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("ClientSystems").%ToJSON(), 1: ""), "[""10.0.0.2""]", "and the address reads back")
}

/// <p>The Save's path for service <var>pName</var>, the id encoded once for the wire (AD-13).</p>
ClassMethod Path(pName As %String) As %String
{
    Quit $Replace(..#EDITPATH, ":id", ##class(OcuPilot.Kernel.EntityId).Encode(pName))
}

}
