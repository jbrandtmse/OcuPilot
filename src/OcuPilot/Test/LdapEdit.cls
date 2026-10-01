/// <p>Pins the LDAP and Kerberos editor's routes over the wire (AD-4, AD-8, AD-12, AD-39, AD-55): the
/// form read (<code>GET /ldap/form?name=</code>, and <code>?new=1</code>) with the instance's Kerberos
/// answer, the name check (<code>GET /ldap/name</code>), the group examples (<code>GET
/// /ldap/examples</code>), and the Save (<code>PUT /ldap/:id</code>) through the Matrix's rows -- a
/// two-field save whose every other key reads back, the enable bit set with every other flag kept,
/// a Kerberos-only save filled with the classic page's values, the rules, an undeclared key, a bare
/// name refused by the form read and the Save, a stored dotless name admitted, the last retrieved
/// attribute kept, and an absent name that is refused rather than
/// created by the vendor's upsert; the list and its read
/// tool reading Enabled from the flags (DW-1639); and a least-privileged principal holding exactly
/// the form's pairs reading and saving.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the test principal
/// holding <code>%All</code>, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>PRINCIPALSVARIABLE</parameter> reading <code>1</code>: it creates and deletes
/// <code>ocup99*</code> LDAP configurations (<class>OcuPilot.Test.ServiceLdapProbe</class>), each by
/// exact name, and one throwaway principal. <method>OnBeforeAllTests</method> refuses anywhere either
/// variable does not read 1.</p>
Class OcuPilot.Test.LdapEdit Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's LDAP writes.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SERVICE_CONFIG";

/// <p>The environment variable that arms its throwaway principal.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.ServiceLdapProbe";

Parameter EDITPATH = "/ldap/:id";

Parameter LEASTUSER = "OcuPilotWire99Ldap";

Parameter LEASTROLE = "OcuPilotWire99LdapRole";

/// <p>The probe configuration every test edits, created before each and removed after.</p>
Parameter NAME = "ocup99ldap.invalid";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LdapEdit creates, writes and deletes LDAP configurations on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LdapEdit creates and deletes a user and a role on this instance and runs on a throwaway container only. " _ ..#PRINCIPALSVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll")
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = "OcuPilotLdap" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $ClassMethod(..#PROBE, "EnsurePrincipal", ..#LEASTUSER, ..#LEASTROLE, "%Admin_Secure:U,%DB_IRISSYS:R", ..PreparedPassword)
}

Method OnBeforeOneTest() As %Status
{
    Quit $ClassMethod(..#PROBE, "CreateLdap", ..#NAME)
}

Method OnAfterOneTest() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll")
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemovePrincipal", ..#LEASTUSER, ..#LEASTROLE))
}

/// <p>The form read answers the change tool's fresh read with the name, in any case of the name, and
/// carries no search password; an absent name is 404 <code>LDAP.ABSENT</code>.</p>
Method TestTheFormReadAnswersOneConfiguration()
{
    For tName = ..#NAME, $ZConvert(..#NAME, "U") {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/ldap/form?name=" _ tName, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus, 200, tName _ ": the form read answers")
        Set tLdap = $Select($IsObject($Get(tAnswer)): tAnswer.%Get("ldap"), 1: "")
        Do $$$AssertTrue($IsObject(tLdap), tName _ ": with the configuration")
        If '$IsObject(tLdap) Continue
        Do $$$AssertEquals(tLdap.%Get("LDAPFlags") _ " " _ tLdap.%Get("LDAPHostNames").%ToJSON(), "8 [""ocup99.invalid""]", tName _ ": carrying its stored values")
        Do $$$AssertEquals(tLdap.%GetTypeOf("LDAPFlags"), "number", tName _ ": its flags a number, which the enable bit is set on")
        Do $$$AssertEquals(tLdap.%GetTypeOf("LDAPSearchPassword"), "unassigned", tName _ ": and no search password")
        Do $$$AssertEquals(##class(OcuPilot.Test.OAuthServerProbe).Keys(tAnswer), "kerberos,ldap", tName _ ": beside whether Kerberos is on")
        Do $$$AssertEquals(tAnswer.%GetTypeOf("kerberos") _ " " _ tAnswer.%Get("kerberos"), "boolean " _ ..KerberosOn(), tName _ ": which is the instance's own Security.System answer")
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/ldap/form?name=ocup99nosuch.invalid", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "404 LDAP.ABSENT", "an absent configuration is 404")
}

/// <p>Matrix "LDAP two-field save", AD-4: a Save changing the description and the host names answers
/// 200, those two change, and the other twenty-eight keys of the vendor's read come back as they
/// were.</p>
/// <p>Mutation (Rule 19): merge <code>LDAPHostNames</code> by concatenation in the tool's merge --
/// the host leg goes red.</p>
Method TestATwoFieldSaveKeepsEveryOtherField()
{
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NAME, .tBefore, "Security.LDAP")
    Do $$$AssertStatusOK(tSC, "the probe reads")
    If '$IsObject($Get(tBefore)) Quit
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#NAME), .tStatus, .tAnswer, "{""Description"":""two fields"",""LDAPHostNames"":[""h1.invalid"",""h2.invalid:636""]}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the Save answers: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NAME, .tAfter, "Security.LDAP")
    If '$IsObject($Get(tAfter)) Quit
    Do $$$AssertEquals(tAfter.%Get("Description") _ " " _ tAfter.%Get("LDAPHostNames").%ToJSON(), "two fields [""h1.invalid"",""h2.invalid:636""]", "the two fields change")
    Do $$$AssertEquals(##class(OcuPilot.Test.LdapUpdate).Others(tBefore, tAfter, $ListBuild("Description", "LDAPHostNames")), "", "and every other key reads back as it was")
}

/// <p>AC3, AD-4: the Save sends the vendor's complete read with the change applied -- all thirty
/// keys, the never-settable certificate file among them -- through a held port that records the
/// <code>PUT</code> and never sends it, because the vendor keeps an omitted key and a read-back
/// cannot tell a narrowed body from a complete one.</p>
/// <p>Mutation (Rule 19): send the changed fields instead of the merged payload in
/// <method>OcuPilot.Area.Security.LdapSave.Update</method> -- this goes red.</p>
Method TestTheSaveSendsTheCompleteBody()
{
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NAME, .tBefore, "Security.LDAP")
    Do $$$AssertStatusOK(tSC, "the probe reads")
    If '$IsObject($Get(tBefore)) Quit
    Do ##class(OcuPilot.Test.HeldPutPort).Clear()
    Set tSC = ##class(OcuPilot.Test.LdapSaveHeldFixture).Update(..#NAME, {"Description": "held"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(+$Get(tViolations) _ " " _ ##class(OcuPilot.Test.HeldPutPort).WriteCount() _ " " _ ##class(OcuPilot.Test.HeldPutPort).LastType(), "0 1 PUT", "the Save reaches the held port once")
    Set tBody = ##class(%DynamicObject).%FromJSON(##class(OcuPilot.Test.HeldPutPort).LastWriteBody())
    Set tKeys = 0
    Set tIterator = tBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys + 1
    }
    Do $$$AssertEquals(tKeys, 30, "carrying all thirty keys")
    Do $$$AssertEquals(tBody.%Get("Description"), "held", "with the change applied")
    Do $$$AssertEquals(tBody.%GetTypeOf("LDAPCACertFile"), tBefore.%GetTypeOf("LDAPCACertFile"), "and the certificate file sent back as read")
    Do $$$AssertEquals(..Others(tBefore, tBody), "", "and every other key as the instance holds it")
    Do ##class(OcuPilot.Test.HeldPutPort).Clear()
}

/// <p>Matrix "LDAP enable": the Save the form sends for "LDAP enabled" -- the opened flags (8) with
/// bit 64 added -- stores exactly that, so every other bit is kept.</p>
/// <p>Mutation (Rule 19): remove <code>LDAPFlags</code> from the changed set in
/// <method>OcuPilot.Area.Security.LdapSave.Update</method> after its rules pass -- this goes red
/// alone.</p>
Method TestEnablingSetsOneBitAndKeepsTheRest()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#NAME), .tStatus, .tAnswer, "{""LDAPFlags"":72}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the Save answers")
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NAME, .tAfter, "Security.LDAP")
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("LDAPFlags"), 1: ""), 72, "8 with 64 added reads back")
}

/// <p>AD-39, AD-55: each rule refuses the Save as one 422 <code>LDAP.VALIDATION</code> envelope on its
/// field with its published sentence, an emptied host list on an LDAP configuration among them;
/// <code>LDAPCACertFile</code> is 400 undeclared; an absent name is 404 <code>LDAP.ABSENT</code> and
/// is not created, although the vendor's <code>PUT</code> would create it; nothing is written by any
/// of them.</p>
/// <p>Mutations (Rule 19): drop the <code>LDAPFlags</code> range check from
/// <method>OcuPilot.Area.Security.LdapRules.Validate</method> -- the flags leg goes red; skip
/// <code>LDAP.HOST.REQUIRED</code> there -- the host leg goes red.</p>
Method TestTheRulesRefuseTheSave()
{
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NAME, .tBefore, "Security.LDAP")
    Set tLong = ""
    For tI = 1:1:129 Set tLong = tLong _ "d"
    For tCase = $ListBuild("{""LDAPFlags"":300}", "LDAPFlags", "LDAP.FLAGS.VALUE"), $ListBuild("{""LDAPHostNames"":[""a b""]}", "LDAPHostNames", "LDAP.HOST.SHAPE"), $ListBuild("{""LDAPHostNames"":[]}", "LDAPHostNames", "LDAP.HOST.REQUIRED"), $ListBuild("{""LDAPBaseDN"":""""}", "LDAPBaseDN", "LDAP.FIELD.REQUIRED"), $ListBuild("{""Description"":""" _ tLong _ """}", "Description", "LDAP.DESCRIPTION.LENGTH") {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#NAME), .tStatus, .tAnswer, $List(tCase, 1), "application/json")
        Set tRow = ""
        If $IsObject($Get(tAnswer)) && (tAnswer.%GetTypeOf("detail") = "object") Set tRow = tAnswer.%Get("detail").%Get("violations").%Get(0)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "422 LDAP.VALIDATION", $List(tCase, 3) _ " is refused")
        Do $$$AssertEquals($Select($IsObject(tRow): tRow.%Get("field") _ " " _ tRow.%Get("code") _ " " _ tRow.%Get("reason"), 1: ""), $List(tCase, 2) _ " " _ $List(tCase, 3) _ " " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase, 3)), "on its field with the published sentence")
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#NAME), .tStatus, .tAnswer, "{""LDAPCACertFile"":""/tmp/x.pem""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "400 PORT.FIELD.UNEXPECTED", "the certificate file is never settable (AD-21)")
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NAME, .tAfter, "Security.LDAP")
    If $IsObject($Get(tBefore)) && $IsObject($Get(tAfter)) Do $$$AssertEquals(##class(OcuPilot.Test.LdapUpdate).Others(tBefore, tAfter, ""), "", "and the configuration reads back as it was")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path("ocup99ldapnew.invalid"), .tStatus, .tAnswer, "{""Description"":""created?""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "404 LDAP.ABSENT", "an absent name is 404")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapExists", "ocup99ldapnew.invalid"), 0, "and nothing is created")
}

/// <p>AD-13: a name the instance would store differently and does not hold -- a bare name, which it
/// extends with <code>.com</code> -- is refused 422 on <code>Name</code> by <code>LDAP.NAME.FORM</code>
/// at the form read and at the Save, and the Save creates nothing.</p>
Method TestAShortNameIsRefusedByTheFormAndTheSave()
{
    Set tShort = "OcuP99Ldap"
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/ldap/form?name=" _ tShort, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..FirstViolation($Get(tAnswer)), "422 Name LDAP.NAME.FORM", "the form read refuses a bare name")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(tShort), .tStatus, .tAnswer, "{""Description"":""short""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..FirstViolation($Get(tAnswer)), "422 Name LDAP.NAME.FORM", "and so does the Save")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapExists", "ocup99ldap.com"), 0, "which creates nothing")
}

/// <p>AD-13: a Kerberos-only configuration created as the classic page creates one keeps its dotless
/// name, which <code>FormatName</code> would store differently. The editor admits that stored name as
/// it stands, in any case: the form read opens it, a Save writes it under the same name, Test
/// authentication runs against it and the list's Delete removes it. A create of that name is still
/// refused <code>LDAP.NAME.FORM</code>, and so is a dotless name the instance does not hold, at the
/// form read, the Save and the test.</p>
/// <p>Mutations (Rule 19): <method>OcuPilot.Area.Security.LdapRules.Stored</method> answers 0 -- the
/// stored legs go red; <method>OcuPilot.Area.Security.LdapSave.Create</method> admits a stored name
/// -- the create leg goes red.</p>
Method TestAStoredDotlessNameIsAdmitted()
{
    Set tName = "ocup99KRB"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateLdap", tName, 128, "UNKNOWNHOST"), "a Kerberos-only configuration is created with a dotless name")
    Do $$$AssertEquals($ListFind($ListFromString(##class(OcuPilot.Test.LdapCreate).Residue()), tName) _ " " _ ..Formatted(tName), "1 ocup99krb.com", "which the instance keeps as typed, though FormatName would not")
    For tSpelling = tName, $ZConvert(tName, "L") {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/ldap/form?name=" _ tSpelling, .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)) && (tAnswer.%GetTypeOf("ldap") = "object"): tAnswer.ldap.%Get("LDAPFlags"), 1: ""), "200 128", tSpelling _ ": the form read opens it")
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(tName), .tStatus, .tAnswer, "{""Description"":""stored""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "a Save answers: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Set tSC = $ClassMethod(..#PROBE, "Read", tName, .tAfter, "Security.LDAP")
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("Description"), 1: "") _ " " _ $ListFind($ListFromString(##class(OcuPilot.Test.LdapCreate).Residue()), tName), "stored 1", "and writes it under the same name")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..Path(tName) _ "/test", .tStatus, .tAnswer, "{""Username"":""ocup99nobody"",""Password"":""ocup99""}", "application/json")
    Set tLines = $Select($IsObject($Get(tAnswer)) && (tAnswer.%GetTypeOf("lines") = "array"): tAnswer.lines.%ToJSON(), 1: "")
    Do $$$AssertTrue((tStatus = 200) && (tLines [ tName), "Test authentication runs against it: " _ tStatus _ " " _ tLines)
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/ldap", .tStatus, .tAnswer, {"Name": (tName), "LDAPFlags": 128}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..FirstViolation($Get(tAnswer)), "422 Name LDAP.NAME.FORM", "a create of that name is refused")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", $Parameter("OcuPilot.Test.LdapCreate", "ACTIONPATH"), .tStatus, .tAnswer, {"action": "delete", "id": (tName)}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#PROBE, "LdapExists", tName), "200 0", "the list's Delete removes it: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Set tNew = "ocup99NEW"
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/ldap/form?name=" _ tNew, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ ..FirstViolation($Get(tAnswer)), "422 Name LDAP.NAME.FORM", "the form read refuses a dotless name the instance does not hold")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(tNew), .tStatus, .tAnswer, "{""Description"":""new""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..FirstViolation($Get(tAnswer)), "422 Name LDAP.NAME.FORM", "and so does the Save")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..Path(tNew) _ "/test", .tStatus, .tAnswer, "{""Username"":""ocup99nobody"",""Password"":""ocup99""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..FirstViolation($Get(tAnswer)), "422 Name LDAP.NAME.FORM", "and the test")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LdapExists", tNew), 0, "which creates nothing")
}

/// <p>AD-39: a Save that would leave the configuration retrieving no attribute -- an empty list,
/// which the vendor's <code>PUT</code> ignores, or one empty name, which it fails on -- is refused 422
/// on <code>LDAPAttributes</code> by <code>LDAP.ATTRIBUTES.LASTONE</code> with its sentence before
/// anything is written: neither the attributes nor a description sent beside them change.</p>
/// <p>Mutation (Rule 19): drop that rule from
/// <method>OcuPilot.Area.Security.LdapRules.Validate</method> -- both legs go red.</p>
Method TestTheLastAttributeIsNotRemoved()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#NAME), .tStatus, .tAnswer, "{""LDAPAttributes"":[""cn"",""uid""]}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "two attributes are saved")
    For tBody = "{""LDAPAttributes"":[],""Description"":""dropped""}", "{""LDAPAttributes"":[""""],""Description"":""dropped""}" {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#NAME), .tStatus, .tAnswer, tBody, "application/json")
        Set tRow = ""
        If $IsObject($Get(tAnswer)) && (tAnswer.%GetTypeOf("detail") = "object") Set tRow = tAnswer.detail.violations.%Get(0)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tRow): tRow.field _ " " _ tRow.code _ " " _ tRow.reason, 1: ""), "422 LDAPAttributes LDAP.ATTRIBUTES.LASTONE " _ ##class(OcuPilot.Api.LdapError).#REASONATTRIBUTESLASTONE, tBody _ " is refused on the attributes by its sentence")
    }
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NAME, .tAfter, "Security.LDAP")
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("LDAPAttributes").%ToJSON() _ " " _ tAfter.%Get("Description"), 1: ""), "[""cn"",""uid""] OcuPilot probe", "and nothing is written")
}

/// <p>AD-8 with a real principal: holding exactly the form's two pairs, it reads the form, a new
/// form, the name check and the examples, and saves a description.</p>
Method TestALeastPrivilegedPrincipalSaves()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/ldap/form?name=" _ ..#NAME, ..#LEASTUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the least-privileged principal reads the form")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Set tRead = ""
    Try { Set tRead = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
    Do $$$AssertTrue($IsObject(tRead) && (tRead.%GetTypeOf("ldap") = "object"), "one envelope carrying the ldap")
    For tPath = "/ldap/form?new=1", "/ldap/name?name=" _ ..#NAME, "/ldap/examples?OrganizationId=intersystems&GroupId=Group&InstanceId=Instance&RoleId=Role&EscalationRoleId=EscalationRole&NamespaceId=Namespace&RoutineId=Routine&DelimiterId=-&UniversalGroup=0&LDAPGroupId=&LDAPInstanceId=" {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ tPath, ..#LEASTUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders)
        Do $$$AssertEquals(tStatus, 200, "and reads " _ $Piece(tPath, "?", 1) _ ": " _ $Extract($Get(tText), 1, 200))
    }
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ ..Path(..#NAME), ..#LEASTUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders, "{""Description"":""least""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "and saves: " _ $Get(tText))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "answering application/json")
    Set tSaved = ""
    Try { Set tSaved = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
    Do $$$AssertTrue($IsObject(tSaved) && (tSaved.%Get("name") '= ""), "one envelope naming what it saved")
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NAME, .tAfter, "Security.LDAP")
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("Description"), 1: ""), "least", "and the description reads back")
}

/// <p>A new configuration's form read (<code>?new=1</code>) answers an empty name and a new
/// <class>Security.LDAPConfigs</class> object's values, read here in <code>%SYS</code>, with the
/// Kerberos-only bit cleared, the hosts an empty list and no search password, beside the instance's
/// Kerberos answer.</p>
Method TestANewFormReadAnswersANewConfigurationsValues()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/ldap/form?new=1", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the new form read answers")
    Set tLdap = $Select($IsObject($Get(tAnswer)): tAnswer.%Get("ldap"), 1: "")
    If '$IsObject(tLdap) Quit
    Set tExpected = ..NewValues()
    Do $$$AssertEquals(tLdap.%Get("Name") _ "|" _ tLdap.%Get("LDAPHostNames").%ToJSON() _ "|" _ tLdap.%GetTypeOf("LDAPSearchPassword"), "|[]|unassigned", "an empty name, no host and no search password")
    For tField = "LDAPFlags", "LDAPClientTimeout", "LDAPServerTimeout", "LDAPUniqueDNIdentifier", "GroupId", "DelimiterId", "LDAPAttributeMail" {
        Do $$$AssertEquals(tLdap.%Get(tField), tExpected.%Get(tField), tField _ " is a new object's own")
    }
    Do $$$AssertEquals($ZBoolean(+tLdap.%Get("LDAPFlags"), 128, 1), 0, "with the Kerberos-only bit cleared")
    Do $$$AssertEquals(tAnswer.%Get("kerberos"), ..KerberosOn(), "beside the instance's Kerberos answer")
}

/// <p>The name check answers the name the instance stores and the base DN it derives
/// (<code>Security.LDAPConfigs.FormatName</code>, read here in <code>%SYS</code>), and whether it is
/// taken; an empty name and one the vendor refuses are each 422 on <code>Name</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.LdapRules.Canonical</method> answers its
/// input -- the <code>corp</code> leg goes red.</p>
Method TestTheNameCheckAnswersTheStoredForm()
{
    For tCase = $ListBuild("Corp.Example.COM", "corp.example.com", "DC=corp,DC=example,DC=com", 0), $ListBuild("corp", "corp.com", "DC=corp,DC=com", 0), $ListBuild($ZConvert(..#NAME, "U"), ..#NAME, "DC=ocup99ldap,DC=invalid", 1) {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/ldap/name?name=" _ $ZConvert($List(tCase, 1), "O", "URL"), .tStatus, .tAnswer)
        Do $$$AssertEquals(tStatus, 200, $List(tCase, 1) _ ": the name check answers")
        If '$IsObject($Get(tAnswer)) Continue
        Do $$$AssertEquals(tAnswer.%Get("canonical") _ "|" _ tAnswer.%Get("baseDN") _ "|" _ tAnswer.%Get("taken"), $List(tCase, 2) _ "|" _ $List(tCase, 3) _ "|" _ $List(tCase, 4), $List(tCase, 1) _ ": the stored name, its base DN and whether it is taken")
        Do $$$AssertEquals(..Formatted($List(tCase, 1)), $List(tCase, 2), $List(tCase, 1) _ ": which is the vendor's own FormatName")
    }
    For tCase = $ListBuild("", "LDAP.FIELD.REQUIRED"), $ListBuild("a..b", "LDAP.NAME.FORM") {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/ldap/name?name=" _ $List(tCase, 1), .tStatus, .tAnswer)
        Set tRow = ..FirstViolation($Get(tAnswer))
        Do $$$AssertEquals(tStatus _ " " _ tRow, "422 Name " _ $List(tCase, 2), "'" _ $List(tCase, 1) _ "' is refused on Name")
    }
}

/// <p>The group examples are the instance's own: each of the three answers equals
/// <code>Security.LDAPConfigs.FormatExample</code>'s for its mode over the same inputs, read here in
/// <code>%SYS</code>.</p>
Method TestTheExamplesAreTheInstancesOwn()
{
    Set tQuery = "OrganizationId=intersystems&GroupId=Group&InstanceId=Instance&RoleId=Role&EscalationRoleId=EscalationRole&NamespaceId=Namespace&RoutineId=Routine&DelimiterId=-&UniversalGroup=1&LDAPGroupId=GID&LDAPInstanceId=IID"
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/ldap/examples?" _ tQuery, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the examples answer")
    If '$IsObject($Get(tAnswer)) Quit
    For tMode = 1:1:3 {
        Set tKey = $Case(tMode, 1: "universal", 2: "group", : "instance")
        Set tExpected = ..Example(tMode, "intersystems", "Group", "Instance", "Role", "EscalationRole", "Namespace", "Routine", "-", 1, "GID", "IID")
        Do $$$AssertTrue(tExpected '= "", tKey _ ": the vendor answers text")
        Do $$$AssertEquals(tAnswer.%Get(tKey), tExpected, tKey _ ": the instance's own text for mode " _ tMode)
    }
}

/// <p>Matrix "Kerberos only": a Save that unticks LDAP configuration -- the flags gain 128 and lose 64
/// -- with an empty host list and search user stores the classic page's <code>UNKNOWNHOST</code> and
/// <code>UNKNOWNUSER</code>; 64 sent with 128 is refused 422 <code>LDAP.FLAGS.KERBEROS</code> and
/// nothing is written.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.LdapRules.KerberosFilled</method> answers its
/// arguments unchanged -- the fill leg goes red.</p>
Method TestAKerberosOnlySaveFillsTheClassicValues()
{
    Set tName = "ocup99kerberos.invalid"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateLdap", tName, 72), "an enabled probe is created")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(tName), .tStatus, .tAnswer, "{""LDAPFlags"":192}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..FirstViolation($Get(tAnswer)), "422 LDAPFlags LDAP.FLAGS.KERBEROS", "64 with 128 is refused on the flags")
    Set tSC = $ClassMethod(..#PROBE, "Read", tName, .tHeld, "Security.LDAP")
    Do $$$AssertEquals($Select($IsObject($Get(tHeld)): tHeld.%Get("LDAPFlags"), 1: ""), 72, "and nothing is written")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(tName), .tStatus, .tAnswer, "{""LDAPFlags"":136,""LDAPHostNames"":[],""LDAPSearchUsername"":""""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the Kerberos-only Save answers: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Set tSC = $ClassMethod(..#PROBE, "Read", tName, .tAfter, "Security.LDAP")
    If '$IsObject($Get(tAfter)) Quit
    Do $$$AssertEquals(tAfter.%Get("LDAPFlags") _ " " _ tAfter.%Get("LDAPHostNames").%ToJSON() _ " " _ tAfter.%Get("LDAPSearchUsername"), "136 [""UNKNOWNHOST""] UNKNOWNUSER", "128 is set, 64 cleared, and the empty host and user are the classic page's values")
}

/// <p>DW-1639, AC9: the list's screen read and its read tool answer <code>Enabled</code> true for a
/// configuration whose flags carry 64 (72) and false for one whose do not (8), though the vendor's
/// LIST answers false for both.</p>
/// <p>Mutation (Rule 19): the <code>bit64</code> rule in <method>OcuPilot.Screen.Read.Derive</method>
/// answers false -- the enabled leg goes red.</p>
Method TestTheListReadsEnabledFromTheFlags()
{
    Set tEnabled = "ocup99enabled.invalid"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "CreateLdap", tEnabled, 72), "an enabled probe is created beside the disabled one")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/screens/security.ldap/read?maxRows=1000", .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the list's read answers")
    Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View("OcuPilot.Screen.Descriptor.LdapConfigList", {}, 1000, .tView)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(tSC, "and so does its read tool")
    For tRows = $Select($IsObject($Get(tAnswer)): tAnswer.rows, 1: ""), $Select($IsObject($Get(tView)): tView.rows, 1: "") {
        If '$IsObject(tRows) Continue
        Set tOn = ##class(OcuPilot.Test.SecurityLists).RowWhere(tRows, "Name", tEnabled)
        Set tOff = ##class(OcuPilot.Test.SecurityLists).RowWhere(tRows, "Name", ..#NAME)
        Do $$$AssertEquals($Select($IsObject(tOn): tOn.%Get("Enabled") _ " " _ tOn.%Get("LDAPFlags"), 1: "absent"), "1 72", "the enabled configuration reads Enabled true")
        Do $$$AssertEquals($Select($IsObject(tOff): tOff.%Get("Enabled") _ " " _ tOff.%Get("LDAPFlags"), 1: "absent"), "0 8", "and the other reads false")
    }
}

/// <p>AC1: the form's <code>kerberos</code> is <code>AutheEnabled</code> bit 128 in both directions,
/// over a corpus holding the throwaway's own mask (Kerberos on) and that mask with the bit cleared.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.LdapRules.KerberosIn</method> answers 1 --
/// the off legs go red.</p>
Method TestTheKerberosAnswerIsBit128()
{
    For tCase = $ListBuild(33556471, 1), $ListBuild(33556343, 0), $ListBuild(128, 1), $ListBuild(2048, 0), $ListBuild("", 0) {
        Do $$$AssertEquals(##class(OcuPilot.Area.Security.LdapRules).KerberosIn($List(tCase, 1)), $List(tCase, 2), "AutheEnabled " _ $List(tCase, 1) _ " reads Kerberos " _ $List(tCase, 2))
    }
}

/// <p>AD-58: <code>LDAPAttributes</code> reads back by its members whatever their order: the instance
/// stores the list sorted, and a Save sending it in another order reads back matching.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.ReadBack.Same</method> ignores the
/// <code>unordered</code> mode -- the verdict reads differs and this goes red.</p>
Method TestTheAttributesReadBackInAnyOrder()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#NAME), .tStatus, .tAnswer, "{""LDAPAttributes"":[""mail"",""cn""]}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)) && (tAnswer.%GetTypeOf("readBack") = "object"): tAnswer.%Get("readBack").%Get("verdict"), 1: ""), "200 matches", "a Save of two attributes out of order reads back matching")
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NAME, .tAfter, "Security.LDAP")
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("LDAPAttributes").%ToJSON(), 1: ""), "[""cn"",""mail""]", "where the instance stores them sorted")
}

/// <p>Whether the instance's Kerberos authentication is on: <class>Security.System</class>'s
/// <code>AutheEnabled</code> bit 128, read in <code>%SYS</code>.</p>
ClassMethod KerberosOn() As %Boolean
{
    Set tOn = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tOn = ''$ZBoolean(+##class(Security.System).%OpenId("SYSTEM").AutheEnabled, 128, 1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tOn
}

/// <p>A new <class>Security.LDAPConfigs</class> object's values for a few fields, read in
/// <code>%SYS</code>; <code>LDAPFlags</code> with its Kerberos-only bit cleared.</p>
ClassMethod NewValues() As %DynamicObject
{
    Set tValues = {}
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tConfig = ##class(Security.LDAPConfigs).%New()
        For tField = "LDAPClientTimeout", "LDAPServerTimeout", "LDAPUniqueDNIdentifier", "GroupId", "DelimiterId", "LDAPAttributeMail" {
            Do tValues.%Set(tField, $Property(tConfig, tField))
        }
        Do tValues.%Set("LDAPFlags", $ZBoolean(+tConfig.LDAPFlags, 128, 2))
        Set tConfig = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tValues
}

/// <p><code>Security.LDAPConfigs.FormatName</code>'s stored form of <var>pName</var>, read in
/// <code>%SYS</code>, or <code>""</code>.</p>
ClassMethod Formatted(pName As %String) As %String
{
    Set tNew = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If $$$ISERR(##class(Security.LDAPConfigs).FormatName(pName, .tNew, .tBase)) Set tNew = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tNew
}

/// <p><code>Security.LDAPConfigs.FormatExample</code>'s text for mode <var>pMode</var> over the group
/// inputs, read in <code>%SYS</code>, or <code>""</code>.</p>
ClassMethod Example(pMode As %Integer, pOrg As %String, pGroup As %String, pInstance As %String, pRole As %String, pEscalation As %String, pNamespace As %String, pRoutine As %String, pDelimiter As %String, pUniversal As %Boolean, pGroupId As %String, pInstanceId As %String) As %String
{
    Set tText = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If $$$ISERR(##class(Security.LDAPConfigs).FormatExample(pMode, pOrg, pGroup, pInstance, pRole, pEscalation, pNamespace, pRoutine, pDelimiter, pUniversal, pGroupId, pInstanceId, .tText)) Set tText = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit $Get(tText)
}

/// <p>The first violation of an answer <var>pAnswer</var> as <code>field code</code>, or
/// <code>""</code>.</p>
ClassMethod FirstViolation(pAnswer) As %String
{
    If '$IsObject(pAnswer) || (pAnswer.%GetTypeOf("detail") '= "object") Quit ""
    Set tRow = pAnswer.%Get("detail").%Get("violations").%Get(0)
    If '$IsObject(tRow) Quit ""
    Quit tRow.%Get("field") _ " " _ tRow.%Get("code")
}

/// <p>The keys of <var>pBefore</var> other than <code>Description</code> whose value <var>pAfter</var>
/// does not carry.</p>
ClassMethod Others(pBefore As %DynamicObject, pAfter As %DynamicObject) As %String
{
    Quit ##class(OcuPilot.Test.LdapUpdate).Others(pBefore, pAfter, $ListBuild("Description"))
}

/// <p>The Save's path for configuration <var>pName</var>, the id encoded once for the wire
/// (AD-13).</p>
ClassMethod Path(pName As %String) As %String
{
    Quit $Replace(..#EDITPATH, ":id", ##class(OcuPilot.Kernel.EntityId).Encode(pName))
}

}
