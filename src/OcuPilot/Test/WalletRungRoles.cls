/// <p>Pins the wallet credential rung in the process the product runs it in (AD-8, AD-9, AD-42; Story 18.41's C3 and
/// integration criterion). Test connection makes its provider call in a child job that inherits the person's roles
/// (<class>OcuPilot.Kernel.Provider.TestCall</class>), so the rung's checks read the person's own grants there.</p>
/// <p>A real, least-privileged person sends <code>POST /agent/definitions/:id/test</code> through the REST gateway on a
/// stored <code>wallet</code> definition of the armed <code>turnprobe</code> row. The person's role holds read on the
/// install database, <code>%Admin_Operate:USE</code> and <code>OcuPilotAdmin:USE</code> and nothing of the wallet, or the
/// same plus the probe collection's use resource. The adapter behind the row records what its request carried and never
/// the key (<class>OcuPilot.Test.TurnProvider</class>), and no socket is opened.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>PROVIDERVARIABLE</parameter> reading <code>1</code>, because the
/// class creates and deletes an IRIS user and role, a resource and a wallet collection. Every probe object is removed by
/// exact name after each test.</p>
Class OcuPilot.Test.WalletRungRoles Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the person, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the <code>turnprobe</code> row.</p>
Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter PROBE = "OcuPilot.Test.WalletRungProbe";

Parameter APIBASE = "/api/ocupilot";

/// <p>The model tag the <code>turnprobe</code> row's script and records are selected by.</p>
Parameter TAG = "walletrung-roles";

/// <p>The probe definition's name, under the prefix <class>OcuPilot.Test.AgentFixture</class> removes by.</p>
Parameter NAME = "OcuPilotProbeAgentWalletRoles1841";

/// <p>The person and the one role the person holds.</p>
Parameter PERSON = "OCUPROBE1841PERSON";

Parameter ROLE = "OCUPROBE1841PERSONROLE";

/// <p>The stored value of the probe secret: key-shaped for the <code>turnprobe</code> row, fabricated.</p>
Parameter CANARY = "sk-ant-ocupilotwalletrolescanary18410000";

/// <p>The distinctive middle of <parameter>CANARY</parameter>, which the assertions search for.</p>
Parameter CANARYMARK = "ocupilotwalletroles";

/// <p>The person's password, generated for the run.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.WalletRungRoles creates and deletes an IRIS user and role, a resource and a wallet collection on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.WalletRungRoles calls the turnprobe provider row, on a throwaway container only. " _ ..#PROVIDERVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = "OcuProbe1841Roles" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>Each test runs over a freshly created resource, collection and key-value secret.</p>
Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAG)
    Set tSC = $ClassMethod(..#PROBE, "EnsureResource")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "EnsureCollection")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "AddKeyValue", $Parameter(..#PROBE, "DEFAULTSECRET"), {"Secret": (..#CANARY), "Usage": 15})
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "AddKeyValue", $Parameter(..#PROBE, "CONTROLSECRET"), {"Secret": "control", "Usage": 15})
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAG)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tDefinitions), "every probe definition is removed")
    Do $$$AssertEquals(tDefinitions, 0, "and none survives")
    Do $$$AssertEquals(..RemovePerson(), "", "the person and the role are removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every wallet object is removed by exact name")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Do ..RemovePerson()
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>A person who is refused: the rung's checks in Test connection's child see the person's grants, so a person holding
/// the route's pairs and neither the probe collection's use resource nor <code>%Admin_Wallet:USE</code> is refused
/// <code>WALLETRUNG.USE</code> naming the use resource, answered 403 with the published sentence. Nothing reaches the
/// provider's adapter, the stored definition stays enabled and verified, and the refusal writes no
/// <code>AccessDenied</code> row naming the secret. The positive control is the person's own direct vendor call on
/// another probe secret, made after it: once its row is readable, the refusal's would be.</p>
/// <p>Mutation (Rule 19): drop the use-resource check from <method>OcuPilot.Kernel.Secret.Ladder.Wallet</method> -- the
/// child reads the secret as a person the wallet refuses, the call answers another code, a row is written and this goes
/// red.</p>
Method TestAPersonWithoutThePairIsRefusedInTheTestConnectionChild()
{
    Do $$$AssertStatusOK(..SeedPerson(0), "the person is created")
    Do ..AssertGrants(0)
    Set tId = ..StoredDefinition()
    If tId = "" Quit
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("reached"))
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Hang 1
    Set tSC = ..Call(1, "POST", "/agent/definitions/" _ tId _ "/test", "", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 403, "the test is refused 403: " _ tText)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tText)
    Set tPair = $Parameter(..#PROBE, "USERESOURCE") _ ":USE"
    Do $$$AssertEquals(tAnswer.code, ##class(OcuPilot.Api.WalletRungError).#USE, "with the use refusal's code")
    Do $$$AssertEquals(tAnswer.reason, ##class(OcuPilot.Api.WalletRungError).ReasonFor(##class(OcuPilot.Api.WalletRungError).#USE, tPair), "and its published sentence")
    Do $$$AssertTrue($IsObject(tAnswer.detail) && (tAnswer.detail.failedPair = tPair), "naming the collection's use resource as the pair")
    Do $$$AssertEquals(tText [ ..#CANARYMARK, 0, "and carrying no part of the secret")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 0, "nothing reached the provider's adapter")
    Do $$$AssertEquals(..EnabledAndVerified(tId), 11, "the definition is still enabled and verified")
    Do $$$AssertEquals(..DirectCallRefused(), 1, "the person's direct vendor call on the control secret is refused")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "DeniedRows", tSince, $Parameter(..#PROBE, "CONTROLSECRET"), 1), 1, "and writes the one AccessDenied row naming it, so the audit store has caught up")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "DeniedRows", tSince, $Parameter(..#PROBE, "DEFAULTSECRET")), 0, "and the refused test wrote none naming its secret")
}

/// <p>The same person with the collection's use resource added -- and still without <code>%Admin_Wallet:USE</code> --
/// gets through: the child reads the secret as the person, the provider's adapter receives one request whose key header
/// is the stored value, in the child that ran as the person, and the definition reads verified.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Secret.Ladder.Wallet</method> answer <code>""</code> -- the test is
/// refused for its credential, no request is sent and this goes red. Append a character to the value it returns -- the
/// call succeeds and the key header no longer matches the stored value, so this goes red on that alone.</p>
Method TestAPersonWithTheUseResourceReachesTheAdapterWithTheStoredKey()
{
    Do $$$AssertStatusOK(..SeedPerson(1), "the person is created")
    Do ..AssertGrants(1)
    Set tId = ..StoredDefinition()
    If tId = "" Quit
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("reached"))
    Set tSC = ..Call(1, "POST", "/agent/definitions/" _ tId _ "/test", "", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 200, "the test answers 200: " _ tText)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tAnswer.reply, "reached", "with the adapter's reply")
    Do $$$AssertEquals(tAnswer.connectionVerified, 1, "and the definition verified")
    Do $$$AssertEquals(tText [ ..#CANARYMARK, 0, "the answer carries no part of the secret")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 1, "the adapter received one request")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "keySha"), ##class(OcuPilot.Test.TurnProvider).Sha(..#CANARY), "whose key header is the stored value")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "user"), ..#PERSON, "in the child that ran as the person")
    Set tRoles = $ZConvert(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "roles"), "U")
    Do $$$AssertTrue(tRoles [ ..#ROLE, "carrying the person's own role: " _ tRoles)
    Do $$$AssertTrue(tRoles '[ "%ALL", "and never %All: " _ tRoles)
    Do $$$AssertEquals(..EnabledAndVerified(tId), 11, "the definition is enabled and verified")
}

/// <p>Create the person over the role that holds the route's pairs, and the probe collection's use resource when
/// <var>pUseResource</var> is 1. An existing person and role of those names are replaced.</p>
Method SeedPerson(pUseResource As %Boolean) As %Status
{
    Set tResources = "%Admin_Operate:U," _ ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE _ ":U"
    If pUseResource Set tResources = tResources _ "," _ $Parameter(..#PROBE, "USERESOURCE") _ ":U"
    Quit $ClassMethod(..#PROBE, "SeedPrincipal", ..#PERSON, ..#ROLE, tResources, ..PreparedPassword)
}

/// <p>Assert what the person holds as the instance reads it: the route's two pairs, never <code>%Admin_Wallet:USE</code>,
/// and the probe collection's use resource only when <var>pUseResource</var> is 1.</p>
Method AssertGrants(pUseResource As %Boolean)
{
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PERSON, "%Admin_Operate", "USE"), 1, "the person holds %Admin_Operate:USE")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PERSON, ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE, "USE"), 1, "and the OcuPilot administrative resource")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PERSON, "%Admin_Wallet", "USE"), 0, "but not %Admin_Wallet:USE")
    Do $$$AssertEquals($SYSTEM.Security.CheckUserPermission(..#PERSON, $Parameter(..#PROBE, "USERESOURCE"), "USE"), pUseResource, "and the probe collection's use resource only when it was granted")
}

/// <p>One request to the definitions surface as the person when <var>pAsPerson</var> is 1, otherwise as the suite's own
/// account.</p>
Method Call(pAsPerson As %Boolean, pMethod As %String, pSuffix As %String, pBody As %String, Output pStatus As %Integer, Output pText As %String) As %Status
{
    Set tUser = $Select(pAsPerson: ..#PERSON, 1: ##class(OcuPilot.Test.Http).GetTestUsername())
    Set tPassword = $Select(pAsPerson: ..PreparedPassword, 1: ##class(OcuPilot.Test.Http).GetTestPassword())
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ pSuffix, tUser, tPassword, .pStatus, .pText, .tHeaders, pBody, "application/json", , 60)
}

/// <p>Create the probe definition over the wire on the <code>wallet</code> rung naming the probe secret, as the suite's own
/// account, and set it enabled and verified; its id, or <code>""</code>.</p>
Method StoredDefinition() As %String
{
    Set tBody = {"name": (..#NAME), "provider": "turnprobe", "model": (..#TAG), "credType": "wallet", "credentialName": ($Parameter(..#PROBE, "DEFAULTSECRET"))}
    Set tSC = ..Call(0, "POST", "/agent/definitions", tBody.%ToJSON(), .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 201, "the wallet definition is created: " _ tText)
    If tStatus '= 201 Quit ""
    Set tId = ##class(%DynamicObject).%FromJSON(tText).id
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tId, 1, 1), "and set enabled and verified")
    Quit tId
}

/// <p>The stored definition's <code>Enabled</code> and <code>ConnectionVerified</code> flags as two digits, or what could
/// not be read.</p>
Method EnabledAndVerified(pId As %String) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(pId, .tRow)
    If $$$ISERR(tSC) || '$IsObject($Get(tRow)) Quit "unreadable"
    Set tFlags = tRow.Enabled _ tRow.ConnectionVerified
    Set tRow = ""
    Quit tFlags
}

/// <p>Ask the wallet directly, as the person and in a child process the test starts, whether the control secret exists:
/// a vendor call a person without the pair is refused. 1 when the child answered that it could not open the secret, and
/// 0 when it answered anything else, an error included.</p>
Method DirectCallRefused() As %Boolean
{
    Set tRefused = 0
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = [{"kind": "exists", "name": ($Parameter(..#PROBE, "CONTROLSECRET"))}].%ToJSON()
        Job ##class(OcuPilot.Test.WalletRungProbe).Run($Job, ..#PERSON, tPlan)::10
        If '$Test Quit
        Set tMessage = $System.Event.WaitMsg("", 120)
        If $ListGet(tMessage, 1) '= 1 Quit
        Set tRun = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
        If tRun.%IsDefined("error") || (tRun.%GetTypeOf("steps") '= "array") Quit
        Set tRefused = (tRun.steps.%Get(0).%GetTypeOf("opened") = "boolean") && 'tRun.steps.%Get(0).opened
    } Catch ex {
        Set tRefused = 0
    }
    Quit tRefused
}

/// <p>Delete the person and the role, and answer what survives, <code>""</code> when nothing does.</p>
ClassMethod RemovePerson() As %String
{
    Set tLeft = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#PERSON) Do ##class(Security.Users).Delete(..#PERSON)
        If ##class(Security.Roles).Exists(..#ROLE) Do ##class(Security.Roles).Delete(..#ROLE)
        If ##class(Security.Users).Exists(..#PERSON) Set tLeft = tLeft _ " user " _ ..#PERSON
        If ##class(Security.Roles).Exists(..#ROLE) Set tLeft = tLeft _ " role " _ ..#ROLE
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tLeft = tLeft _ " (" _ ex.DisplayString() _ ")"
    }
    Quit tLeft
}

}
