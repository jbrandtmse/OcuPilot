/// <p>Pins the LDAP configuration form's routes over the wire (AD-4, AD-8, AD-12, AD-39, AD-55): the
/// form read (<code>GET /ldap/form?name=</code>) and the Save (<code>PUT /ldap/:id</code>) through the
/// Matrix's rows -- a two-field save whose every other key reads back, the enable bit set with every
/// other flag kept, the four rules, an undeclared key, and an absent name that is refused rather
/// than created by the vendor's upsert -- and a least-privileged principal holding exactly the form's
/// pairs saving.</p>
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
Method TestEnablingSetsOneBitAndKeepsTheRest()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#NAME), .tStatus, .tAnswer, "{""LDAPFlags"":72}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "the Save answers")
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NAME, .tAfter, "Security.LDAP")
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("LDAPFlags"), 1: ""), 72, "8 with 64 added reads back")
}

/// <p>AD-39, AD-55: each rule refuses the Save as one 422 <code>LDAP.VALIDATION</code> envelope on its
/// field with its published sentence; <code>LDAPCACertFile</code> is 400 undeclared; an absent name
/// is 404 <code>LDAP.ABSENT</code> and is not created, although the vendor's <code>PUT</code> would
/// create it; nothing is written by any of them.</p>
/// <p>Mutation (Rule 19): drop the <code>LDAPFlags</code> range check from
/// <method>OcuPilot.Area.Security.LdapRules.Validate</method> -- the flags leg goes red.</p>
Method TestTheRulesRefuseTheSave()
{
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NAME, .tBefore, "Security.LDAP")
    Set tLong = ""
    For tI = 1:1:129 Set tLong = tLong _ "d"
    For tCase = $ListBuild("{""LDAPFlags"":300}", "LDAPFlags", "LDAP.FLAGS.VALUE"), $ListBuild("{""LDAPHostNames"":[""a b""]}", "LDAPHostNames", "LDAP.HOST.SHAPE"), $ListBuild("{""LDAPBaseDN"":""""}", "LDAPBaseDN", "LDAP.FIELD.REQUIRED"), $ListBuild("{""Description"":""" _ tLong _ """}", "Description", "LDAP.DESCRIPTION.LENGTH") {
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

/// <p>AD-8 with a real principal: holding exactly the form's two pairs, it reads the form and saves a
/// description.</p>
Method TestALeastPrivilegedPrincipalSaves()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/ldap/form?name=" _ ..#NAME, ..#LEASTUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the least-privileged principal reads the form")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Set tRead = ""
    Try { Set tRead = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
    Do $$$AssertTrue($IsObject(tRead) && (tRead.%GetTypeOf("ldap") = "object"), "one envelope carrying the ldap")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ ..Path(..#NAME), ..#LEASTUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders, "{""Description"":""least""}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "and saves: " _ $Get(tText))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "answering application/json")
    Set tSaved = ""
    Try { Set tSaved = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
    Do $$$AssertTrue($IsObject(tSaved) && (tSaved.%Get("name") '= ""), "one envelope naming what it saved")
    Set tSC = $ClassMethod(..#PROBE, "Read", ..#NAME, .tAfter, "Security.LDAP")
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%Get("Description"), 1: ""), "least", "and the description reads back")
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
