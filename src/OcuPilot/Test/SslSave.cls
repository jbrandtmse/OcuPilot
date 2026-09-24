/// <p>Pins Story 9.5's SSL/TLS Save (AC1, AC3, AC5, AC9, AD-4, AD-10, AD-21, AD-39, AD-54, AD-55):
/// <code>POST /ssl</code>, <code>PUT /ssl/:id</code> and the form read over real requests; a two-field
/// Save that sends the complete set and leaves every other field as it was; the rules that refuse
/// what the vendor refuses only with a 500, before anything is sent; a vendor refusal mapped to its
/// field; the undeclared keys; and OcuPilot's own provider configuration refused a change to its four
/// installer-owned fields and its delete, on both callers, while its other fields pass.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// <code>%Admin_Secure</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because it creates and deletes SSL/TLS configurations by exact name.
/// <method>OnBeforeAllTests</method> refuses anywhere it does not. Every leg over OcuPilot's own
/// configuration goes through a port that holds or records its write, so none can change it.</p>
Class OcuPilot.Test.SslSave Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SSL_CONFIG";

Parameter SAVE = "OcuPilot.Test.SslSaveFixture";

/// <p>The Save whose port records a <code>PUT</code> and never sends it.</p>
Parameter HELDSAVE = "OcuPilot.Test.SslSaveHeldFixture";

Parameter PORT = "OcuPilot.Test.DeviceRecordPort";

Parameter HELDPORT = "OcuPilot.Test.HeldPutPort";

Parameter RULES = "OcuPilot.Area.Security.SslRules";

Parameter SET = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter SETFIXTURE = "OcuPilot.Test.ProhibitedFixture";

Parameter FORMPATH = "/ssl/form";

Parameter NAMEPATH = "/ssl/name";

Parameter CREATEPATH = "/ssl";

/// <p>The edit and test routes; <method>RoutePath</method> fills their one segment.</p>
Parameter EDITPATH = "/ssl/:id";

Parameter TESTPATH = "/ssl/:id/test";

/// <p>The client configuration every edit leg changes, and the one the create leg makes.</p>
Parameter PROBE = "OcuPilotProbeSslSave";

Parameter NEWPROBE = "OcuPilotProbeSslSaveNew";

/// <p>The description every probe carries, which is how each is recognised as this class's own
/// before it is deleted.</p>
Parameter PROBEMARKER = "OcuPilot SSL save probe";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SslSave creates and deletes SSL/TLS configurations on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit ..EnsureProbe()
}

Method OnAfterAllTests() As %Status
{
    Quit ..RemoveProbes()
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit ..EnsureProbe()
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>AD-12, AD-39: each SSL/TLS route answers exactly one JSON envelope over a real request -- the
/// form read and the name look-up at 200, a create naming nothing and a test naming no port at 422
/// on <code>SSL.VALIDATION</code>, and an edit of a configuration the instance does not hold at 404.
/// The name look-up answers the probe taken with <code>SSL.NAME.TAKEN</code>'s sentence and an absent
/// name free with none. Nothing is created, changed or tested.</p>
/// <p>Mutation (Rule 19): answer <code>taken</code> 0 in
/// <method>OcuPilot.Area.Security.SslRules.HandleName</method> -> the taken leg goes red.</p>
Method TestEachRouteAnswersOneJsonEnvelopeOverTheWire()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tCases = $ListBuild($ListBuild("GET", ..#FORMPATH, "", 200, ""))
    Set tCases = tCases _ $ListBuild($ListBuild("GET", ..#NAMEPATH _ "?name=" _ ..#PROBE, "", 200, ""))
    Set tCases = tCases _ $ListBuild($ListBuild("POST", ..#CREATEPATH, "{}", 422, ##class(OcuPilot.Api.Error).#SSLVALIDATION))
    Set tCases = tCases _ $ListBuild($ListBuild("POST", ..RoutePath(..#TESTPATH, ..#PROBE), "{""Host"":""localhost"",""Port"":0}", 422, ##class(OcuPilot.Api.Error).#SSLVALIDATION))
    Set tCases = tCases _ $ListBuild($ListBuild("PUT", ..RoutePath(..#EDITPATH, "OcuPilotProbeSslSaveGone"), "{""Description"":""x""}", 404, ##class(OcuPilot.Api.Error).#SSLNAMEABSENT))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tMethod = $List(tCase, 1)
        Set tPath = tBase _ $List(tCase, 2)
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(tMethod, tPath, tUser, tPassword, .tStatus, .tBody, .tHeaders, $List(tCase, 3), $Select($List(tCase, 3) '= "": "application/json", 1: ""))
        Do $$$AssertStatusOK(tSC, tMethod _ " " _ tPath _ ": the request completes")
        Do $$$AssertEquals(tStatus, $List(tCase, 4), tMethod _ " " _ tPath _ ": at " _ $List(tCase, 4))
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tMethod _ " " _ tPath _ ": as application/json")
        Do $$$AssertEquals((tBody [ "}{"), 0, tMethod _ " " _ tPath _ ": exactly one envelope")
        Set tParsed = ##class(%DynamicObject).%FromJSON(tBody)
        If $List(tCase, 5) '= "" Do $$$AssertEquals(tParsed.%Get("code"), $List(tCase, 5), tMethod _ " " _ tPath _ ": on its own envelope code")
    }
    For tCase = $ListBuild(..#PROBE, 1, ##class(OcuPilot.Api.Error).#REASONSSLNAMETAKEN), $ListBuild("OcuPilotProbeSslSaveGone", 0, "") {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#NAMEPATH _ "?name=" _ $List(tCase, 1), .tStatus, .tAnswer)
        Set tSeen = $Select($IsObject($Get(tAnswer)): tAnswer.%GetTypeOf("taken") _ " " _ +tAnswer.%Get("taken") _ " " _ tAnswer.%Get("reason"), 1: "")
        Do $$$AssertEquals(tStatus _ " " _ tSeen, "200 boolean " _ $List(tCase, 2) _ " " _ $List(tCase, 3), "the name look-up answers " _ $List(tCase, 1) _ " as " _ $Select($List(tCase, 2): "taken, with the published sentence", 1: "free, with no sentence"))
    }
}

/// <p>AC5, AD-12, AD-54: a client created over a real request answers 201 <code>{name}</code> and
/// reads back as created; the same name again, a malformed one and a create missing a field the
/// vendor requires are each 422 on the field. The form read answers the vendor <code>GET</code>'s
/// twenty-one keys exactly, never a password, and whether the configuration is OcuPilot's own; a
/// configuration the instance does not hold is 404 <code>SSL.NAME.ABSENT</code> on the read and the
/// Save.</p>
/// <p>Mutation (Rule 19): build the form read's <code>configuration</code> from
/// <class>Security.SSLConfigs</class>' <code>Get</code> -- the exact-key-set assertion goes red on
/// <code>PrivateKeyPassword</code> and the other keys it answers.</p>
Method TestTheCreateAndTheFormReadAnswerOverTheWire()
{
    Set tBody = {"Name": (..#NEWPROBE), "Type": 0, "VerifyPeer": 1, "Enabled": true, "CAFile": "%OSCertificateStore", "Description": (..#PROBEMARKER)}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/ssl", .tStatus, .tAnswer, tBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""), "201 {""name"":""" _ ..#NEWPROBE _ """}", "a client is created")
    Kill tProps
    Do $$$AssertStatusOK(..Stored(..#NEWPROBE, .tProps), "and the instance holds it")
    Do $$$AssertEquals($Get(tProps("Type")) _ " " _ $Get(tProps("VerifyPeer")) _ " " _ $Get(tProps("CAFile")), "0 1 %OSCertificateStore", "as a client that verifies its peer against the operating system's store")

    For tCase = $ListBuild(..#NEWPROBE, "Name", "SSLNAMETAKEN"), $ListBuild("Probe/Slash", "Name", "SSLNAMESHAPE") {
        Do tBody.%Set("Name", $List(tCase, 1), "string")
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/ssl", .tStatus, .tAnswer, tBody.%ToJSON(), "application/json")
        Do $$$AssertEquals(tStatus _ " " _ ..FirstViolation(tAnswer), "422 " _ $List(tCase, 2) _ " " _ $Parameter("OcuPilot.Api.Error", $List(tCase, 3)), $List(tCase, 1) _ " is refused on its field")
    }
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/ssl", .tStatus, .tAnswer, "{""Name"":""OcuPilotProbeSslSaveNoType"",""VerifyPeer"":0,""Enabled"":true}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..FirstViolation(tAnswer), "422 Type " _ ##class(OcuPilot.Api.Error).#SSLFIELDREQUIRED, "a create with no type is refused on it")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?name=" _ ..#PROBE, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the form read of the probe answers")
    Set tConfiguration = $Select($IsObject($Get(tAnswer)): tAnswer.%Get("configuration"), 1: "")
    Do $$$AssertEquals(..Keys(tConfiguration), ..Sorted($Parameter(..#RULES, "CONFIGURATIONFIELDS")), "carrying exactly the vendor GET's twenty-one keys")
    Do $$$AssertEquals(tAnswer.%Get("ocupilot"), 0, "and saying it is not OcuPilot's own")
    Do $$$AssertEquals(tAnswer.%Get("defaults").%Get("TLSMinVersion"), 16, "beside the vendor's own defaults")
    Do $$$AssertEquals(tAnswer.%Get("requiredFields").%ToJSON(), "[""Name"",""Type"",""VerifyPeer"",""Enabled""]", "the four fields a create requires")
    Do $$$AssertEquals(tAnswer.%Get("rules").%Size(), $ListLength(##class(OcuPilot.Api.Error).SslViolationCodes()) - 1, "one rule per field code, SSL.FIELD.REQUIRED naming no one field")
    Do $$$AssertEquals(tAnswer.%Get("rules").%Get(0).%Get("field") _ " " _ tAnswer.%Get("rules").%Get(0).%Get("code"), "Name " _ ##class(OcuPilot.Api.Error).#SSLNAMEREQUIRED, "the name's first rule the one an empty create name shows")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH _ "?name=" _ ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("ocupilot"), 1: ""), "200 1", "OcuPilot's own provider configuration reads as its own")

    For tPath = "/ssl/OcuPilotProbeSslSaveGone", ..#FORMPATH _ "?name=OcuPilotProbeSslSaveGone" {
        Set tMethod = $Select(tPath [ "form": "GET", 1: "PUT")
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest(tMethod, tPath, .tStatus, .tAnswer, $Select(tMethod = "PUT": "{""Description"":""x""}", 1: ""), $Select(tMethod = "PUT": "application/json", 1: ""))
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject($Get(tAnswer)): tAnswer.%Get("code"), 1: ""), "404 " _ ##class(OcuPilot.Api.Error).#SSLNAMEABSENT, tMethod _ " of an absent configuration is 404 on its own code")
    }
}

/// <p>AC5, AD-4: a Save of <code>Description</code> and <code>TLSMinVersion</code> sends the
/// complete twenty-one-key set, the ciphers, OCSP and verification depth exactly as the fresh read
/// answered them, and afterwards those read back unchanged while the two read back as saved.</p>
/// <p>Mutation (Rule 19): merge over <code>{Name}</code> instead of the fresh read in
/// <method>OcuPilot.Area.Security.SslSave.Update</method> -- the key-count and survival legs go
/// red.</p>
Method TestATwoFieldSaveSendsTheCompleteSetAndTheRestSurvives()
{
    Do $$$AssertStatusOK(..Fresh(..#PROBE, .tBefore), "the probe reads fresh")
    If '$IsObject($Get(tBefore)) Quit
    Set tSC = $ClassMethod(..#SAVE, "Update", ..#PROBE, {"Description": (..#PROBEMARKER _ " saved"), "TLSMinVersion": 8}, .tHttp, .tFault, .tViolations)
    Do $$$AssertStatusOK(tSC, "the two-field Save succeeds: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals(+$Get(tViolations), 0, "with no violation")
    Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount") _ " " _ $ClassMethod(..#PORT, "LastType"), "1 PUT", "one PUT was sent")
    Set tSent = ##class(%DynamicObject).%FromJSON($ClassMethod(..#PORT, "LastWriteBody"))
    Do $$$AssertEquals(..Keys(tSent), ..Sorted($Parameter(..#RULES, "CONFIGURATIONFIELDS")), "carrying the complete set")
    Do $$$AssertStatusOK(..Fresh(..#PROBE, .tAfter), "the probe reads back")
    If '$IsObject($Get(tAfter)) Quit
    For tKey = "CipherList", "Ciphersuites", "OCSP", "OCSPTimeout", "VerifyDepth", "VerifyPeer", "CAFile" {
        Set tWas = ..Rendered(tBefore, tKey)
        Do $$$AssertEquals(..Rendered(tSent, tKey), tWas, tKey _ " was sent as the fresh read held it")
        Do $$$AssertEquals(..Rendered(tAfter, tKey), tWas, tKey _ " survives the Save")
    }
    Do $$$AssertEquals(tAfter.%Get("Description") _ " " _ tAfter.%Get("TLSMinVersion"), ..#PROBEMARKER _ " saved 8", "and the two read back as saved")
}

/// <p>The rules refuse what the vendor refuses only with a 500, each on its field, before anything is
/// sent: a server type over no files, peer verification over no trusted certificates, a trusted
/// certificates location, the TLS versions out of order, a Diffie-Hellman size, a cipher entry, a
/// verification depth, OCSP, an over-long description, and a password over no key file or too long.
/// Over the wire the same refusal is one 422.</p>
/// <p>Mutation (Rule 19): drop the <code>CAFile</code> location rule from
/// <method>OcuPilot.Area.Security.SslRules.Validate</method> -- the path leg sends a PUT and goes
/// red.</p>
Method TestTheRulesRefuseBeforeAnythingIsSent()
{
    Set tLong = $Translate($Justify("", 257), " ", "d")
    Set tCases = ""
    Set tCases = tCases _ $ListBuild($ListBuild("{""Type"":1}", "Type", "SSLTYPESERVERFILES"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""CAFile"":""""}", "CAFile", "SSLVERIFYPEERCAREQUIRED"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""CAFile"":""/tmp/x.pem""}", "CAFile", "SSLCAFILEPATH"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""TLSMinVersion"":32,""TLSMaxVersion"":16}", "TLSMaxVersion", "SSLTLSMAXVERSIONORDER"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""TLSMinVersion"":2}", "TLSMinVersion", "SSLTLSMINVERSIONVALUE"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""DiffieHellmanBits"":333}", "DiffieHellmanBits", "SSLDIFFIEHELLMANBITSVALUE"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""Ciphersuites"":[""a b""]}", "Ciphersuites", "SSLCIPHERSUITESSHAPE"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""CipherList"":[""ALL:!aNULL""]}", "CipherList", "SSLCIPHERLISTSHAPE"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""VerifyDepth"":-1}", "VerifyDepth", "SSLVERIFYDEPTHSHAPE"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""VerifyPeer"":3}", "VerifyPeer", "SSLVERIFYPEERVALUE"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""OCSP"":2}", "OCSP", "SSLOCSPVALUE"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""Description"":""" _ tLong _ """}", "Description", "SSLDESCRIPTIONLENGTH"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""PrivateKeyPassword"":""probe""}", "PrivateKeyPassword", "SSLPRIVATEKEYPASSWORDKEYFILE"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""PrivateKeyPassword"":""" _ $Translate($Justify("", 256), " ", "p") _ """}", "PrivateKeyPassword", "SSLPRIVATEKEYPASSWORDLENGTH"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""TLSMaxVersion"":2}", "TLSMaxVersion", "SSLTLSMAXVERSIONVALUE"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""Type"":2}", "Type", "SSLTYPEVALUE"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""Enabled"":""yes""}", "Enabled", "SSLENABLEDSHAPE"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""OCSPTimeout"":-1}", "OCSPTimeout", "SSLOCSPTIMEOUTSHAPE"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""CipherList"":[""" _ $Translate($Justify("", 4097), " ", "C") _ """]}", "CipherList", "SSLCIPHERLISTLENGTH"))
    Set tCases = tCases _ $ListBuild($ListBuild("{""Ciphersuites"":[""" _ $Translate($Justify("", 129), " ", "S") _ """]}", "Ciphersuites", "SSLCIPHERSUITESLENGTH"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Do $ClassMethod(..#PORT, "Clear")
        Set tSC = $ClassMethod(..#SAVE, "Update", ..#PROBE, ##class(%DynamicObject).%FromJSON($List(tCase, 1)), .tHttp, .tFault, .tViolations)
        Set tGot = $Select(+$Get(tViolations) > 0: $List(tViolations(1), 1) _ " " _ $List(tViolations(1), 2), 1: "")
        Do $$$AssertEquals(tGot, $List(tCase, 2) _ " " _ $Parameter("OcuPilot.Api.Error", $List(tCase, 3)), $Extract($List(tCase, 1), 1, 50) _ " is refused on its field")
        Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount"), 0, $Extract($List(tCase, 1), 1, 50) _ ": and nothing is sent")
    }
    Set tSC = $ClassMethod(..#SAVE, "Create", ..#NEWPROBE, {"Type": 1, "VerifyPeer": 0, "Enabled": true}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals($Select(+$Get(tViolations) > 0: $List(tViolations(1), 1) _ " " _ $List(tViolations(1), 2), 1: ""), "Type " _ ##class(OcuPilot.Api.Error).#SSLTYPESERVERFILES, "a server create is refused: a create is always a client")
    Set tSC = $ClassMethod(..#SAVE, "Create", "", {"Type": 0, "VerifyPeer": 0, "Enabled": true}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals($Select(+$Get(tViolations) > 0: $List(tViolations(1), 1) _ " " _ $List(tViolations(1), 2), 1: ""), "Name " _ ##class(OcuPilot.Api.Error).#SSLNAMEREQUIRED, "a create with no name is refused on it")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#PROBE), .tStatus, .tAnswer, "{""CAFile"":""/tmp/x.pem""}", "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ..FirstViolation(tAnswer), "422 CAFile " _ ##class(OcuPilot.Api.Error).#SSLCAFILEPATH, "over the wire a location is 422 on CAFile")
}

/// <p>AD-39: a value only the vendor can judge -- an unknown TLS 1.3 cipher suite, a TLS 1.2 list that
/// selects nothing -- is refused on its field in OcuPilot's own sentence, and the configuration
/// reads back unchanged.</p>
/// <p>Mutation (Rule 19): drop the <code>746</code> entry from
/// <parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter> -- the Save answers an internal error
/// and the cipher-suite leg goes red.</p>
Method TestAVendorRefusalLandsOnItsFieldAndChangesNothing()
{
    Do $$$AssertStatusOK(..Fresh(..#PROBE, .tBefore), "the probe reads fresh")
    For tCase = $ListBuild("Ciphersuites", "[""BOGUS""]", "SSLCIPHERSUITESUNKNOWN"), $ListBuild("CipherList", "[""!ALL""]", "SSLCIPHERLISTEXPANDSEMPTY") {
        Set tField = $List(tCase, 1)
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", ..Path(..#PROBE), .tStatus, .tAnswer, "{""" _ tField _ """:" _ $List(tCase, 2) _ "}", "application/json")
        Do $$$AssertEquals(tStatus _ " " _ ..FirstViolation(tAnswer), "422 " _ tField _ " " _ $Parameter("OcuPilot.Api.Error", $List(tCase, 3)), tField _ " is refused on its field")
        Do $$$AssertEquals($Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON() [ "BOGUS", 1: 1), 0, tField _ ": in OcuPilot's own sentence, quoting nothing sent")
        Do $$$AssertStatusOK(..Fresh(..#PROBE, .tAfter), tField _ ": the probe reads back")
        Do $$$AssertEquals(..Rendered(tAfter, tField), ..Rendered(tBefore, tField), tField _ ": unchanged")
    }
}

/// <p>AD-56 (ii): a Save carrying a key outside the tool's settable fields -- a file location, the
/// private key type, <code>AuthorizeCN</code> or the name -- is 400 <code>PORT.FIELD.UNEXPECTED</code>
/// naming each, and nothing is sent; a create carrying a password is refused the same.</p>
Method TestUndeclaredKeysAreRefused()
{
    Set tSC = $ClassMethod(..#SAVE, "Update", ..#PROBE, {"CertificateFile": "/tmp/x.pem", "PrivateKeyType": 3, "AuthorizeCN": true, "Name": "Renamed"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, "the keys are refused")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.detail.violations.%Size(), 1: 0), 4, "each named")
    Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount"), 0, "and nothing is sent")
    Set tSC = $ClassMethod(..#SAVE, "Create", ..#NEWPROBE, {"Name": (..#NEWPROBE), "Type": 0, "VerifyPeer": 0, "Enabled": true, "PrivateKeyPassword": "probe"}, .tHttp, .tFault, .tViolations)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, "a create's password is refused too")
    Do $$$AssertEquals($ClassMethod(..#PORT, "WriteCount"), 0, "and nothing is sent")
}

/// <p>AC3, AD-10 as amended 2026-09-24: on OcuPilot's own provider configuration a Save turning its
/// peer verification off or disabling it is 403 <code>PROHIBITED.OCUPILOTSSL</code> with the
/// published sentence and nothing is sent, while its description or minimum TLS version passes the
/// set and reaches the held port; the set refuses a change to its type or trusted certificates the
/// same; and it is left exactly as it was.</p>
/// <p>Mutation (Rule 19): delete the change arm of <method>OcuPilot.Kernel.Proposal.Prohibited.Ssl</method>
/// -- the refused legs reach the held port and go red.</p>
Method TestOcuPilotsOwnConfigurationRefusesItsFourFields()
{
    Set tOwn = ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG
    Do $$$AssertStatusOK(..Fresh(tOwn, .tBefore), "OcuPilot's own configuration reads fresh")
    If '$IsObject($Get(tBefore)) Quit
    For tBody = "{""VerifyPeer"":0}", "{""Enabled"":false}" {
        Do $ClassMethod(..#HELDPORT, "Clear")
        Set tSC = $ClassMethod(..#HELDSAVE, "Update", tOwn, ##class(%DynamicObject).%FromJSON(tBody), .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "403 " _ $Parameter(..#SET, "OCUPILOTSSL"), tBody _ " is refused as OcuPilot's own")
        Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.reason, 1: ""), $Parameter(..#SET, "OCUPILOTSSLREASON"), tBody _ ": with the published sentence")
        Do $$$AssertEquals($ClassMethod(..#HELDPORT, "WriteCount"), 0, tBody _ ": and nothing reaches the port")
    }
    For tBody = "{""Description"":""probe""}", "{""TLSMinVersion"":8}" {
        Do $ClassMethod(..#HELDPORT, "Clear")
        Set tSC = $ClassMethod(..#HELDSAVE, "Update", tOwn, ##class(%DynamicObject).%FromJSON(tBody), .tHttp, .tFault, .tViolations)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), $Parameter(..#HELDPORT, "HELDSTATUS") _ " " _ ##class(OcuPilot.Api.Error).#PORTUNAVAILABLE, tBody _ " passes the set and reaches the held port")
    }
    For tField = "Type", "CAFile" {
        Set tPayload = ##class(%DynamicObject).%FromJSON(tBefore.%ToJSON())
        If tField = "Type" Do tPayload.%Set("Type", 1, "number")
        If tField = "CAFile" Do tPayload.%Set("CAFile", "", "string")
        Set tSC = $ClassMethod(..#SETFIXTURE, "Ask", tBefore.%ToJSON(), tPayload.%ToJSON(), ##class(OcuPilot.Test.ProhibitedFixture).Diff(tField), tOwn, "ssl-configuration", .tProhibits, .tCode, "security.ssl.update")
        Do $$$AssertEquals(tCode, $Parameter(..#SET, "OCUPILOTSSL"), "a change to its " _ tField _ " is refused as OcuPilot's own")
    }
    Do $$$AssertStatusOK(..Fresh(tOwn, .tAfter), "it reads back")
    Do $$$AssertEquals($Select($IsObject($Get(tAfter)): tAfter.%ToJSON(), 1: ""), tBefore.%ToJSON(), "exactly as it was")
}

/// <p>AC9, AD-10, AD-53: deleting OcuPilot's own provider configuration is refused
/// <code>PROHIBITED.OCUPILOTSSL</code> on both callers -- the list's Delete through the screen-action
/// route and the agent's confirmed <code>security.ssl.delete</code> -- and nothing is sent, while a
/// probe's Delete through the same route is applied. Both run over
/// <class>OcuPilot.Test.ProposalFixture</class>'s port, so no delete reaches the instance.</p>
/// <p>Mutation (Rule 19): drop the delete from <method>OcuPilot.Kernel.Proposal.Prohibited.Ssl</method>
/// -- both callers' legs record a write and go red.</p>
Method TestOcuPilotsOwnConfigurationsDeleteIsRefusedOnBothCallers()
{
    Set tOwn = ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG
    Do $$$AssertStatusOK(..Fresh(tOwn, .tFresh), "OcuPilot's own configuration reads fresh")
    If '$IsObject($Get(tFresh)) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tFresh.%ToJSON())
    Set tSC = ##class(OcuPilot.Test.SslActionFixture).Act("security.ssl", {"action": "delete", "id": (tOwn)}, .tAnswer, .tStatus)
    Set tEnvelope = $Select(tAnswer '= "": ##class(%DynamicObject).%FromJSON(tAnswer), 1: {})
    Do $$$AssertEquals(tStatus _ " " _ tEnvelope.%Get("code"), "403 " _ $Parameter(..#SET, "OCUPILOTSSL"), "the list's Delete is refused as OcuPilot's own")
    Do $$$AssertEquals(tEnvelope.%Get("reason"), $Parameter(..#SET, "OCUPILOTSSLREASON"), "with the published sentence")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and nothing is written")

    Set tTool = "OcuPilot.Screen.Tool.SslDelete"
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Set tSC = ##class(OcuPilot.Test.ProposalMint).Mint("OcuPilot.Screen.Descriptor.SslConfigList", $Parameter(tTool, "TOOLNAME"), $Username, "", tTurnKey, {"Name": (tOwn)}, "OcuPilot.Kernel.Agent.Limits", .tProposal, .tHttp, .tFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), tOwn, $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), tTool)
    Do $$$AssertStatusOK(tSC, "the agent's delete is proposed")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals(+$Get(tValues("destructive")), 1, "as a destructive write")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tSC = ##class(OcuPilot.Test.ConfirmFixture).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "403 " _ $Parameter(..#SET, "OCUPILOTSSL"), "and its confirm is refused as OcuPilot's own")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "with no write")

    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do $$$AssertStatusOK(..Fresh(..#PROBE, .tProbe), "the probe reads fresh")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(tProbe.%ToJSON())
    Set tSC = ##class(OcuPilot.Test.SslActionFixture).Act("security.ssl", {"action": "delete", "id": (..#PROBE)}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "while a probe's Delete through the same route is applied")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "DELETE", "as the vendor's bodyless DELETE")
}

/// <p>The first violation of <var>pAnswer</var>, as <code>field code</code>, or <code>""</code>.</p>
ClassMethod FirstViolation(pAnswer) As %String
{
    If '$IsObject($Get(pAnswer)) || (pAnswer.%GetTypeOf("detail") '= "object") Quit ""
    Set tRow = pAnswer.detail.violations.%Get(0)
    If '$IsObject(tRow) Quit ""
    Quit tRow.field _ " " _ tRow.code
}

/// <p><var>pRoute</var> with its <code>:id</code> segment filled by <var>pName</var>, encoded
/// (AD-13).</p>
ClassMethod RoutePath(pRoute As %String, pName As %String) As %String
{
    Quit $Replace(pRoute, ":id", ##class(OcuPilot.Kernel.EntityId).Encode(pName))
}

/// <p>The edit route for <var>pName</var>, one encoded segment (AD-13).</p>
ClassMethod Path(pName As %String) As %String
{
    Quit "/ssl/" _ ##class(OcuPilot.Kernel.EntityId).Encode(pName)
}

/// <p>The configuration <var>pName</var> as the vendor's own <code>GET</code> answers it now.</p>
ClassMethod Fresh(pName As %String, Output pFresh As %DynamicObject) As %Status
{
    Set pFresh = ""
    Kill tQuery
    Set tQuery("name") = pName
    Quit ##class(OcuPilot.Port.AdminPort).Invoke("Security.SSLConfig", "GET", .tQuery, "", .pFresh, .tHttp, .tFault)
}

/// <p>The configuration <var>pName</var> as <class>Security.SSLConfigs</class> stores it, in
/// <var>pProps</var>, the private key password dropped.</p>
ClassMethod Stored(pName As %String, Output pProps) As %Status
{
    Kill pProps
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.SSLConfigs).Get(pName, .pProps)
        Kill pProps("PrivateKeyPassword")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The top-level member names of <var>pObject</var>, sorted and comma-separated.</p>
ClassMethod Keys(pObject As %DynamicObject) As %String
{
    If '$IsObject(pObject) Quit ""
    Kill tNames
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tNames(tKey) = ""
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tNames(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

/// <p><var>pList</var>, a comma-separated list, sorted and comma-separated.</p>
ClassMethod Sorted(pList As %String) As %String
{
    Kill tNames
    For tI = 1:1:$Length(pList, ",") Set tNames($Piece(pList, ",", tI)) = ""
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tNames(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

/// <p><var>pObject</var>'s member <var>pKey</var> as the diff renders it.</p>
ClassMethod Rendered(pObject As %DynamicObject, pKey As %String) As %String
{
    If '$IsObject(pObject) Quit ""
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Display(pObject.%Get(pKey), pObject.%GetTypeOf(pKey))
}

/// <p>Create the edit probe afresh -- a client verifying its peer against the operating system's
/// store, with its own ciphers, depth and OCSP timeout -- and remove the create probe; each is
/// removed first when it is this class's own, and refused when a configuration of that name is
/// anybody else's.</p>
Method EnsureProbe() As %Status
{
    Set tSC = ..RemoveProbes()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProps("Type") = 0
        Set tProps("VerifyPeer") = 1
        Set tProps("CAFile") = "%OSCertificateStore"
        Set tProps("Enabled") = 1
        Set tProps("Description") = ..#PROBEMARKER
        Set tProps("CipherList") = "ALL:!aNULL:!eNULL"
        Set tProps("VerifyDepth") = 5
        Set tProps("OCSPTimeout") = 3
        Set tSC = ##class(Security.SSLConfigs).Create(..#PROBE, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the probes whose description says they are this class's own; a configuration of one of
/// those names that is anybody else's is an error and is left alone.</p>
Method RemoveProbes() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tName = ..#PROBE, ..#NEWPROBE {
            If '##class(Security.SSLConfigs).Exists(tName, .tConfig) Continue
            If $Extract(tConfig.Description, 1, $Length(..#PROBEMARKER)) '= ..#PROBEMARKER {
                Set tSC = $$$ERROR($$$GeneralError, "the SSL/TLS configuration " _ tName _ " is not this class's own, so it was left alone")
                Quit
            }
            Set tConfig = ""
            Set tSC = ##class(Security.SSLConfigs).Delete(tName)
            If $$$ISERR(tSC) Quit
        }
        Set tConfig = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
