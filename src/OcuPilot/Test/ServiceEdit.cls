/// <p>Pins the service editor's routes over the wire (AD-4, AD-8, AD-10, AD-12, AD-39, AD-55): the form
/// read (<code>GET /services/form?name=</code>) with the groups each service has, and the Save
/// (<code>PUT /services/:id</code>) through the Matrix's rows -- an address added and removed whose
/// other fields read back, a role given to an address, the vendor's own <code>address:role</code>
/// spelling read and kept, a method added that keeps the bits the form did not offer, the rules, an
/// undeclared key and an absent service -- the serving service's Save refused before any write while
/// its address change is permitted, and a least-privileged principal holding exactly the form's pairs
/// saving.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the test principal
/// holding <code>%All</code>, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>PRINCIPALSVARIABLE</parameter> reading <code>1</code>: it writes
/// <code>%Service_CallIn</code>, <code>%Service_CacheDirect</code> and <code>%Service_ECP</code>, each
/// disabled, restoring the snapshot it took of each after every test and asserting each reads back as
/// it, and creates one throwaway principal. The serving service is only read: its Save legs go
/// through <class>OcuPilot.Test.ServiceSaveHeldFixture</class>, whose port never sends a
/// <code>PUT</code>. <method>OnBeforeAllTests</method> refuses anywhere either variable does not read
/// 1.</p>
Class OcuPilot.Test.ServiceEdit Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's service writes.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SERVICE_CONFIG";

/// <p>The environment variable that arms its throwaway principal.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ServiceLdapProbe";

Parameter RULES = "OcuPilot.Area.Permissions.ServiceRules";

Parameter HELDSAVE = "OcuPilot.Test.ServiceSaveHeldFixture";

Parameter HELDPORT = "OcuPilot.Test.HeldPutPort";

Parameter EDITPATH = "/services/:id";

Parameter LEASTUSER = "OcuPilotWire99Service";

Parameter LEASTROLE = "OcuPilotWire99ServiceRole";

/// <p>The service that checks no address, for the refusals.</p>
Parameter CALLIN = "%Service_CallIn";

/// <p>The service that checks addresses and methods and gives no roles.</p>
Parameter CACHEDIRECT = "%Service_CacheDirect";

/// <p>The service that gives an address roles and has no methods.</p>
Parameter ECP = "%Service_ECP";

/// <p>Each written service's read as it stood before the class ran, keyed by name, restored after
/// every test.</p>
Property Snapshots [ MultiDimensional ];

/// <p>The throwaway principal's password, generated for the run.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ServiceEdit writes %Service_CallIn, %Service_CacheDirect and %Service_ECP on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ServiceEdit creates and deletes a user and a role on this instance and runs on a throwaway container only. " _ ..#PRINCIPALSVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    For tName = ..#CALLIN, ..#CACHEDIRECT, ..#ECP {
        Set tSC = $ClassMethod(..#PROBE, "SnapshotOf", tName, .tSnapshot)
        If $$$ISERR(tSC) Quit
        Set ..Snapshots(tName) = tSnapshot
    }
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = "OcuPilotSvc" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $ClassMethod(..#PROBE, "EnsurePrincipal", ..#LEASTUSER, ..#LEASTROLE, "%Admin_Secure:U,%DB_IRISSYS:R", ..PreparedPassword)
}

/// <p>AC11: every written service is put back as its snapshot, and reads back as it, whether the test
/// passed or failed.</p>
/// <p>Mutation (Rule 19): skip the <code>RestoreAll</code> call here -- the residue assertion goes
/// red.</p>
Method OnAfterOneTest() As %Status
{
    Set tSC = ..RestoreAll()
    For tName = ..#CALLIN, ..#CACHEDIRECT, ..#ECP {
        Set tReadSC = $ClassMethod(..#PROBE, "Read", tName, .tAfter)
        Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%ToJSON(), 1: ""), $Get(..Snapshots(tName)), tName _ " reads back as its snapshot after the test")
    }
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ..RestoreAll()
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemovePrincipal", ..#LEASTUSER, ..#LEASTROLE))
}

/// <p>The form read answers the change tool's fresh read with the name, and whether the service is
/// the one OcuPilot is served through, in any spelling of its name; an absent name is 404
/// <code>SERVICE.ABSENT</code>.</p>
Method TestTheFormReadAnswersOneService()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..FormPath(..#CALLIN), .tStatus, .tAnswer)
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

/// <p>AC1: the form read names the groups each service has, as the classic Edit Service dialog draws
/// them: the methods <code>%Service_CacheDirect</code>, <code>%Service_CallIn</code> and the serving
/// service offer -- the bits their <code>AutheEnabledCapabilities</code> and the instance's
/// <code>AutheEnabled</code> both carry, computed here from the instance -- each labelled, and none for
/// <code>%Service_ECP</code>; addresses on CacheDirect, ECP and the serving service; and roles, with
/// the instance's role options, on ECP alone, each marked with the kernel's verdict. The classic
/// order and two labels are checked against literals, not against the rules' own table. It reads and
/// writes nothing.</p>
/// <p>Mutation (Rule 19): answer the negation of the kernel's verdict in
/// <method>OcuPilot.Area.Permissions.ServiceRules.RoleOptions</method> -- the privileged-mark leg goes
/// red. Swap the message keys of bits 64 and 32 in
/// <parameter>OcuPilot.Area.Permissions.ServiceRules.AUTHEMETHODS</parameter> -- the label leg goes
/// red.</p>
Method TestTheFormReadNamesEachServicesGroups()
{
    For tCase = $ListBuild(..#CACHEDIRECT, 1, 0), $ListBuild(..#ECP, 1, 1), $ListBuild(..#CALLIN, 0, 0), $ListBuild($Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SERVINGSERVICENAME"), 1, 0) {
        Set tName = $List(tCase, 1)
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..FormPath(tName), .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus, 200, tName _ ": the form read answers")
        If '$IsObject($Get(tAnswer)) Continue
        Set tBits = ""
        Set tLabelled = 1
        Set tIterator = tAnswer.%Get("authenticationMethods").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tMethod) {
            Set tBits = tBits _ $ListBuild(tMethod.%Get("bit"))
            If tMethod.%Get("label") = "" Set tLabelled = 0
            Set tLabels(tName, tMethod.%Get("bit")) = tMethod.%Get("label")
        }
        Set tIterator = tAnswer.%Get("roles").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRole) {
            Set tMarks(tName, tRole.%Get("name")) = tRole.%Get("privileged")
        }
        Do $$$AssertEquals($ListToString(tBits), $ListToString(..OfferedBits(tName)), tName _ ": its methods are the ones the instance offers it, in the classic order")
        Do $$$AssertTrue(tLabelled, tName _ ": each with the instance's own label")
        Do $$$AssertEquals(tAnswer.%Get("clientSystems") _ " " _ tAnswer.%Get("clientRoles"), $List(tCase, 2) _ " " _ $List(tCase, 3), tName _ ": addresses and roles as its capabilities say")
        Do $$$AssertEquals(tAnswer.%Get("roles").%Size() > 0, $List(tCase, 3), tName _ ": role options only where it gives roles")
    }
    Do $$$AssertTrue($ListLength(..OfferedBits(..#CACHEDIRECT)) > 0, "the instance offers CacheDirect at least one method, so the method leg above tested something")
    Set tOrder = ""
    Set tMethods = $Parameter(..#RULES, "AUTHEMETHODS")
    For tI = 1:1:$Length(tMethods, ",") Set tOrder = tOrder _ $Select(tI = 1: "", 1: ",") _ $Piece($Piece(tMethods, ",", tI), ":", 1)
    Do $$$AssertEquals(tOrder, "64,16,131072,32,128,4,2,1,512,256,8,8192,2048,2097152,1048576,33554432,67108864", "the methods follow the classic dialog's AuthList order")
    Do $$$AssertEquals($Get(tLabels(..#CACHEDIRECT, 64)) _ " / " _ $Get(tLabels(..#CACHEDIRECT, 32)), ..Message("AutheUnauthenticatedStr") _ " / " _ ..Message("AutheCacheStr"), "bit 64 reads the instance's Unauthenticated label and bit 32 its Password label")
    Do $$$AssertEquals($Get(tMarks(..#ECP, "%All"), "<absent>") _ " " _ $Get(tMarks(..#ECP, "%Operator"), "<absent>"), "1 0", "ECP's role options carry the kernel's verdict: %All privileged, %Operator not")
}

/// <p>The instance's own message <var>pKey</var> from the domain the classic dialog's method labels
/// come from, read in <code>%SYS</code>.</p>
ClassMethod Message(pKey As %String) As %String
{
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tText = $$FormatMessage^%occMessages("", "%SECURITY.Services", pKey)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tText
}

/// <p>Matrix "Add, then delete, an address", AD-4, AC2: the Save adds one address on
/// <code>%Service_CacheDirect</code> and answers 200, the service reads back with it and its methods
/// and enablement unchanged, and the Services list's own read shows it; a second Save removes it, and
/// the list reads it empty, which the list draws "Unrestricted".</p>
/// <p>Mutation (Rule 19): remove <code>ClientSystems</code> from the changed set in
/// <method>OcuPilot.Area.Permissions.ServiceSave.Update</method> after its rules pass -- the add leg
/// goes red.</p>
Method TestAnAddressIsAddedAndRemovedKeepingEveryOtherField()
{
    Set tBefore = ##class(%DynamicObject).%FromJSON(..Snapshots(..#CACHEDIRECT))
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#CACHEDIRECT), .tStatus, .tAnswer, "{""ClientSystems"":[""10.0.0.1""]}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the Save answers: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#CACHEDIRECT, .tAfter)
    Do $$$AssertStatusOK(tSC, "the service reads back")
    If '$IsObject($Get(tAfter)) Quit
    Do $$$AssertEquals(tAfter.%Get("ClientSystems").%ToJSON(), "[""10.0.0.1""]", "with the address")
    Do $$$AssertEquals(tAfter.%Get("AutheEnabled") _ " " _ tAfter.%Get("Enabled"), tBefore.%Get("AutheEnabled") _ " " _ tBefore.%Get("Enabled"), "and its methods and enablement as they were")
    Do $$$AssertEquals(..Listed(..#CACHEDIRECT), "[""10.0.0.1""]", "and the list's allowed addresses show it")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#CACHEDIRECT), .tStatus, .tAnswer, "{""ClientSystems"":[]}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the Save that removes it answers")
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#CACHEDIRECT, .tAfter)
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("ClientSystems").%ToJSON() _ " " _ tAfter.%Get("AutheEnabled"), 1: ""), "[] " _ tBefore.%Get("AutheEnabled"), "the service holds no address and its methods as they were")
    Do $$$AssertEquals(..Listed(..#CACHEDIRECT), "[]", "and the list reads it empty")
}

/// <p>Matrix "Classic spelling", AC3: an entry the vendor's own editor wrote as
/// <code>10.0.0.6:%Manager</code> reads in the form as address <code>10.0.0.6</code> with role
/// <code>%Manager</code>, and a Save that adds another entry sends it back unchanged.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Permissions.ServiceRules.EntryParts</method>
/// ignore <code>:</code> -- the parse leg goes red.</p>
Method TestAClassicSpellingIsReadAndKeptVerbatim()
{
    Do $$$AssertStatusOK(..Seed(..#ECP, "ClientSystems", ["10.0.0.6:%Manager"]), "ECP holds an entry in the classic spelling")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..FormPath(..#ECP), .tStatus, .tAnswer)
    Set tRow = $Select($IsObject($Get(tAnswer)): tAnswer.%Get("connections").%Get(0), 1: "")
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.%Get("entry") _ " " _ tRow.%Get("address") _ " " _ tRow.%Get("roles").%ToJSON(), 1: ""), "10.0.0.6:%Manager 10.0.0.6 [""%Manager""]", "the form reads its address and its role")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#ECP), .tStatus, .tAnswer, "{""ClientSystems"":[""10.0.0.6:%Manager"",""10.0.0.7""]}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "a Save adding another entry answers: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#ECP, .tAfter)
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("ClientSystems").%ToJSON(), 1: ""), "[""10.0.0.6:%Manager"",""10.0.0.7""]", "and the classic entry is sent back as read")
}

/// <p>Matrix "Give an address a role", AC3: on <code>%Service_ECP</code>, which holds
/// <code>10.0.0.5</code>, a Save giving it <code>%Operator</code> is stored
/// <code>10.0.0.5|%Operator</code>, and the form reads it back with that role.</p>
Method TestARoleIsGivenToAnAddress()
{
    Do $$$AssertStatusOK(..Seed(..#ECP, "ClientSystems", ["10.0.0.5"]), "ECP holds one address")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#ECP), .tStatus, .tAnswer, "{""ClientSystems"":[""10.0.0.5|%Operator""]}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the role Save answers: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#ECP, .tAfter)
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("ClientSystems").%ToJSON(), 1: ""), "[""10.0.0.5|%Operator""]", "the instance holds the address with its role")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..FormPath(..#ECP), .tStatus, .tAnswer)
    Set tRow = $Select($IsObject($Get(tAnswer)): tAnswer.%Get("connections").%Get(0), 1: "")
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.%Get("address") _ " " _ tRow.%Get("roles").%ToJSON(), 1: ""), "10.0.0.5 [""%Operator""]", "and the editor reads it back with that role")
}

/// <p>Matrix "Methods", AC4: <code>%Service_CacheDirect</code> holds a method its capabilities carry
/// and the instance does not offer; a Save that adds Unauthenticated (64) over the mask it read is
/// stored with 64 and keeps that bit.</p>
Method TestAMethodSaveKeepsTheBitsNotOffered()
{
    Set tHidden = ..HiddenBit(..#CACHEDIRECT)
    Do $$$AssertTrue(tHidden > 0, "CacheDirect supports a method the instance does not offer")
    If tHidden = 0 Quit
    Set tBase = ##class(%DynamicObject).%FromJSON(..Snapshots(..#CACHEDIRECT)).%Get("AutheEnabled")
    Set tHeld = $ZBoolean(+tBase, tHidden, 7)
    Do $$$AssertStatusOK(..Seed(..#CACHEDIRECT, "AutheEnabled", tHeld), "CacheDirect holds " _ tHeld)
    Set tSent = $ZBoolean(tHeld, 64, 7)
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#CACHEDIRECT), .tStatus, .tAnswer, "{""AutheEnabled"":" _ tSent _ "}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the method Save answers: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#CACHEDIRECT, .tAfter)
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("AutheEnabled"), 1: ""), tSent, "the stored mask gains 64 and keeps bit " _ tHidden)
}

/// <p>AD-39, AD-55: each of Story 9.9's rules refuses the Save as one 422
/// <code>SERVICE.VALIDATION</code> envelope on <code>ClientSystems</code> or <code>AutheEnabled</code>
/// with its published sentence; an undeclared key is 400 and an absent service 404
/// <code>SERVICE.ABSENT</code>; nothing is written by any of them.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Permissions.ServiceRules.EntryShaped</method>
/// accept a semicolon -- the semicolon leg goes red.</p>
/// <p>Mutation (Rule 19, Matrix "Absent"): disable the 404 branch in
/// <method>OcuPilot.Area.Permissions.ServiceSave.HandleUpdate</method> -- the absent leg goes red
/// alone.</p>
Method TestTheRulesRefuseTheSave()
{
    For tCase = $ListBuild("{""ClientSystems"":[""a;b""]}", "ClientSystems", "SERVICE.ADDRESS.SHAPE"), $ListBuild("{""ClientSystems"":[""10.0.0.1|OcuPilotNoSuchRole99""]}", "ClientSystems", "SERVICE.ADDRESS.ROLE"), $ListBuild("{""AutheEnabled"":262192}", "AutheEnabled", "SERVICE.AUTHE.UNSUPPORTED") {
        Do ..AssertRefused(..#CALLIN, $List(tCase, 1), $List(tCase, 2), $List(tCase, 3))
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#CALLIN), .tStatus, .tAnswer, "{""Description"":""changed""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "400 PORT.FIELD.UNEXPECTED", "the description is never settable")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path("OcuPilotNoSuchService99"), .tStatus, .tAnswer, "{""Enabled"":false}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "404 SERVICE.ABSENT", "an absent service is 404")
    Do $$$AssertEquals(..Moved(), "", "and every service reads back as it was")
}

/// <p>AC7: an added address the vendor's check refuses (on <code>%Service_CacheDirect</code>), an
/// address on a service that checks none (<code>%Service_CallIn</code>) and a role on a service that
/// gives none (<code>%Service_CacheDirect</code>) are each one 422 <code>SERVICE.VALIDATION</code> on
/// <code>ClientSystems</code> with the published sentence, and nothing is written. An entry the
/// service already holds is never judged, so an address added beside one the rules would refuse if it
/// were new is saved, and the held entry is kept as read.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Permissions.ServiceRules.Validate</method> skip
/// the <code>ADDRESSUNSUPPORTED</code> rule -- the <code>%Service_CallIn</code> leg goes red. Judge held
/// entries too in <method>OcuPilot.Area.Permissions.ServiceRules.AddedViolations</method> -- the
/// held-entry leg goes red.</p>
Method TestTheAddressRulesRefuseTheSave()
{
    Set tError = "OcuPilot.Api.ServiceError"
    Do ..AssertRefused(..#CACHEDIRECT, "{""ClientSystems"":[""999.1.1.1""]}", "ClientSystems", $Parameter(tError, "ADDRESSINVALID"))
    Do ..AssertRefused(..#CALLIN, "{""ClientSystems"":[""10.0.0.1""]}", "ClientSystems", $Parameter(tError, "ADDRESSUNSUPPORTED"))
    Do ..AssertRefused(..#CACHEDIRECT, "{""ClientSystems"":[""10.0.0.5|%Operator""]}", "ClientSystems", $Parameter(tError, "ADDRESSROLEUNSUPPORTED"))
    Do $$$AssertEquals(..Moved(), "", "and every service reads back as it was")
    Do $$$AssertStatusOK(..Seed(..#CACHEDIRECT, "ClientSystems", ["10.0.0.5|%Operator"]), "CacheDirect holds an entry with a role it never gives")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#CACHEDIRECT), .tStatus, .tAnswer, "{""ClientSystems"":[""10.0.0.5|%Operator"",""10.0.0.1""]}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "an address added beside the held entry is saved: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#CACHEDIRECT, .tAfter)
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("ClientSystems").%ToJSON(), 1: ""), "[""10.0.0.5|%Operator"",""10.0.0.1""]", "and the held entry is kept as read")
}

/// <p>AD-10 as amended, AC5: the Save that turns the serving service off is refused 403
/// <code>PROHIBITED.SERVINGSERVICE</code> with the published sentence before any <code>PUT</code>,
/// while an address change on it is permitted and reaches the port -- a held port, which records the
/// <code>PUT</code> and never sends it. The held Save is first shown to hold its <code>PUT</code> on
/// <code>%Service_CacheDirect</code>; if it does not, the serving service is never touched.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.ServingServiceDisabled</method>
/// answer 0 -- the disable reaches the held port and this goes red. Send
/// <method>OcuPilot.Area.Permissions.ServiceSave.Update</method>'s write through the tool's own
/// port instead of <method>OcuPilot.Area.Permissions.ServiceSave.PortClass</method> -- the probe
/// service is written, the canary goes red, and the serving service's legs do not run.</p>
Method TestTheServingServiceSaveIsRefusedBeforeAnyWrite()
{
    Set tServing = $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SERVINGSERVICENAME")
    Do $ClassMethod(..#HELDPORT, "Clear")
    Set tSC = $ClassMethod(..#HELDSAVE, "Update", ..#CACHEDIRECT, {"ClientSystems": ["10.0.0.3"]}, .tHttp, .tFault, .tViolations)
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#CACHEDIRECT, .tCanary)
    Set tHeld = ($ClassMethod(..#HELDPORT, "WriteCount") = 1) && $IsObject($Get(tCanary)) && (tCanary.%ToJSON() = ..Snapshots(..#CACHEDIRECT))
    Do $$$AssertTrue(tHeld, "the held Save holds its PUT on the probe service, so no leg below can write the serving service")
    If 'tHeld Quit
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

/// <p>AD-8 with a real principal: holding exactly the form's two pairs, it reads the form, with
/// <code>%Service_ECP</code>'s role options among it, and saves an address on
/// <code>%Service_CacheDirect</code>, which the vendor's address check judges in that principal's
/// process. A caller without the pairs is refused in
/// <method>OcuPilot.Test.WireSecurityRead.TestTheReducedFormsRefuseACallerWithoutTheirPairs</method>.</p>
Method TestALeastPrivilegedPrincipalSaves()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..FormPath(..#CACHEDIRECT), ..#LEASTUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the least-privileged principal reads the form: " _ $Get(tText))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Set tRead = ""
    Try { Set tRead = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
    Do $$$AssertTrue($IsObject(tRead) && (tRead.%GetTypeOf("service") = "object") && (tRead.%Get("authenticationMethods").%Size() > 0), "one envelope carrying the service and its methods")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..FormPath(..#ECP), ..#LEASTUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders)
    Set tRead = ""
    Try { Set tRead = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
    Do $$$AssertTrue((tStatus = 200) && $IsObject(tRead) && (tRead.%Get("roles").%Size() > 0), "and ECP's form with its role options: " _ $Get(tStatus) _ " " _ $Extract($Get(tText), 1, 200))
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ ..Path(..#CACHEDIRECT), ..#LEASTUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders, "{""ClientSystems"":[""10.0.0.2""]}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "and saves: " _ $Get(tText))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "answering application/json")
    Set tSaved = ""
    Try { Set tSaved = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
    Do $$$AssertTrue($IsObject(tSaved) && (tSaved.%Get("name") '= ""), "one envelope naming what it saved")
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#CACHEDIRECT, .tAfter)
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("ClientSystems").%ToJSON(), 1: ""), "[""10.0.0.2""]", "and the address reads back")
}

/// <p>Assert the Save to <var>pName</var> of <var>pBody</var> is one 422
/// <code>SERVICE.VALIDATION</code> whose first violation is <var>pField</var>, <var>pCode</var> and its
/// published sentence.</p>
Method AssertRefused(pName As %String, pBody As %String, pField As %String, pCode As %String)
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(pName), .tStatus, .tAnswer, pBody, "application/json")
    Set tRow = ""
    If $IsObject($Get(tAnswer)) && (tAnswer.%GetTypeOf("detail") = "object") Set tRow = tAnswer.%Get("detail").%Get("violations").%Get(0)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "422 SERVICE.VALIDATION", pName _ " " _ pBody _ " is refused")
    Do $$$AssertEquals($Select($IsObject(tRow): tRow.%Get("field") _ " " _ tRow.%Get("code") _ " " _ tRow.%Get("reason"), 1: ""), pField _ " " _ pCode _ " " _ ##class(OcuPilot.Api.Error).ReasonForViolation(pCode), "on its field with the published sentence")
}

/// <p>Put every written service back as its snapshot.</p>
Method RestoreAll() As %Status
{
    Set tSC = $$$OK
    For tName = ..#CALLIN, ..#CACHEDIRECT, ..#ECP {
        Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RestoreOf", tName, $Get(..Snapshots(tName))))
    }
    Quit tSC
}

/// <p>The names of the written services that no longer read back as their snapshot, space-separated,
/// or <code>""</code>.</p>
Method Moved() As %String
{
    Set tMoved = ""
    For tName = ..#CALLIN, ..#CACHEDIRECT, ..#ECP {
        Set tSC = $ClassMethod(..#PROBE, "Read", tName, .tAfter)
        If '$IsObject($Get(tAfter)) || (tAfter.%ToJSON() '= $Get(..Snapshots(tName))) Set tMoved = tMoved _ $Select(tMoved = "": "", 1: " ") _ tName
    }
    Quit tMoved
}

/// <p>Write one field <var>pField</var> of service <var>pName</var> as <var>pValue</var>, over its
/// snapshot, through the probe's own restore, which refuses any service but the three and any
/// enabled one.</p>
Method Seed(pName As %String, pField As %String, pValue) As %Status
{
    Set tSeeded = ##class(%DynamicObject).%FromJSON(..Snapshots(pName))
    If $IsObject(pValue) {
        Do tSeeded.%Set(pField, pValue)
    } Else {
        Do tSeeded.%Set(pField, pValue, "number")
    }
    Quit $ClassMethod(..#PROBE, "RestoreOf", pName, tSeeded.%ToJSON())
}

/// <p>The bits the classic dialog would offer for service <var>pName</var>, in its order, computed
/// from the instance: its <code>Capabilities</code> carry the methods group, and each bit of the
/// rules' <parameter>OcuPilot.Area.Permissions.ServiceRules.AUTHEMETHODS</parameter> that both its
/// <code>AutheEnabledCapabilities</code> and the instance's <code>AutheEnabled</code> carry.</p>
ClassMethod OfferedBits(pName As %String) As %List
{
    Set tBits = ""
    Do ..Masks(pName, .tCapabilities, .tAutheCapabilities, .tSystem)
    If '$ZBoolean(tCapabilities, 4, 1) Quit tBits
    Set tMethods = $Parameter(..#RULES, "AUTHEMETHODS")
    For tI = 1:1:$Length(tMethods, ",") {
        Set tBit = +$Piece($Piece(tMethods, ",", tI), ":", 1)
        If $ZBoolean(tAutheCapabilities, tBit, 1) && $ZBoolean(tSystem, tBit, 1) Set tBits = tBits _ $ListBuild(tBit)
    }
    Quit tBits
}

/// <p>A single bit service <var>pName</var>'s <code>AutheEnabledCapabilities</code> carries and the
/// instance's <code>AutheEnabled</code> does not, or 0.</p>
ClassMethod HiddenBit(pName As %String) As %Integer
{
    Do ..Masks(pName, .tCapabilities, .tAutheCapabilities, .tSystem)
    For tPower = 0:1:30 {
        Set tBit = 2 ** tPower
        If $ZBoolean(tAutheCapabilities, tBit, 1) && '$ZBoolean(tSystem, tBit, 1) Quit
        Set tBit = 0
    }
    Quit tBit
}

/// <p>Service <var>pName</var>'s <code>Capabilities</code> and <code>AutheEnabledCapabilities</code>
/// and the instance's <code>AutheEnabled</code>, read in <code>%SYS</code>.</p>
ClassMethod Masks(pName As %String, Output pCapabilities As %Integer, Output pAutheCapabilities As %Integer, Output pSystem As %Integer)
{
    Set (pCapabilities, pAutheCapabilities, pSystem) = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProperties
        If $$$ISOK(##class(Security.Services).Get(pName, .tProperties)) {
            Set pCapabilities = +$Get(tProperties("Capabilities"))
            Set pAutheCapabilities = +$Get(tProperties("AutheEnabledCapabilities"))
        }
        Set tSystem = ##class(Security.System).%OpenId("SYSTEM")
        If $IsObject(tSystem) Set pSystem = +tSystem.AutheEnabled
        Set tSystem = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>What the Services list's own read shows as service <var>pName</var>'s allowed addresses, as
/// JSON, or <code>""</code>.</p>
ClassMethod Listed(pName As %String) As %String
{
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.Service", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tShown = ""
    If $IsObject($Get(tRows)) {
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If $IsObject(tRow) && (tRow.%Get("Name") = pName) Set tShown = tRow.%Get("AllowedConnections").%ToJSON()
        }
    }
    Quit tShown
}

/// <p>The form read's path for service <var>pName</var>.</p>
ClassMethod FormPath(pName As %String) As %String
{
    Quit "/services/form?name=" _ $Replace(pName, "%", "%25")
}

/// <p>The Save's path for service <var>pName</var>, the id encoded once for the wire (AD-13).</p>
ClassMethod Path(pName As %String) As %String
{
    Quit $Replace(..#EDITPATH, ":id", ##class(OcuPilot.Kernel.EntityId).Encode(pName))
}

}
