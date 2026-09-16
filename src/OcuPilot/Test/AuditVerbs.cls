/// <p>The configuration write verbs <class>OcuPilot.Test.AuditRecord</class> does not read back --
/// delete, default, credential, hold and release -- read back from <class>%SYS.Audit</class>, with
/// the <code>effects</code> each names beyond its changed fields: what became of the credential
/// entry a deleted or repointed definition had created, the siblings a store disabled, and the key and fault of a test
/// that did not test the stored values (DW-404, DW-409, DW-411, DW-397).</p>
/// <p>Rows are found through <method>OcuPilot.Test.AuditRecord.RowFor</method> by target, verb and
/// event name. The definition and switch writes go over HTTP through the shipped routes; the
/// faulted test runs in process through <class>OcuPilot.Test.DefinitionsProbe</class> with its
/// port answering from <class>OcuPilot.Test.ProviderStub</class>, so no socket is opened.</p>
/// <p>Every definition, hold and credential entry this class writes is removed after each method,
/// with an assertion that none survives.</p>
/// <p><b>It runs OcuPilot's production install, so it runs on a throwaway container only</b>, and
/// <method>OnBeforeAllTests</method> refuses anywhere <parameter>ARMINGVARIABLE</parameter> does
/// not arm it.</p>
Class OcuPilot.Test.AuditVerbs Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

/// <p>The prefix every definition this class creates is named with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>The credential reference the credential legs share.</p>
Parameter AUDITCREDENTIAL = "OcuPilotProbeAuditCredential";

/// <p>The reference the repoint leg moves a definition to. No entry is written under it.</p>
Parameter AUDITOTHERCREDENTIAL = "OcuPilotProbeAuditRepointedCredential";

/// <p>A key shaped for the shipped <code>anthropic</code> row.</p>
Parameter PROBEKEY = "sk-ant-ocupilotauditprobe000000000";

/// <p>The endpoint the faulted test's definition stores (RFC 5737 TEST-NET-1).</p>
Parameter PUBLICENDPOINT = "https://192.0.2.1/v1/messages";

/// <p>The endpoint the faulted test names instead (RFC 5737 TEST-NET-2).</p>
Parameter OTHERENDPOINT = "https://198.51.100.7/v1/messages";

/// <p>The audit database's clock at the start of each method. The prefix must not begin with
/// "Test" (<file>.claude/rules/objectscript-testing.md</file>).</p>
Property PreparedSince As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedSince = ""
    Quit $$$OK
}

/// <p>Refuse to run at all unless this instance is armed for a production install.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditVerbs runs OcuPilot's PRODUCTION install on this instance -- a database, a resource, a role, three web applications, the audit registrations and the _SYSTEM unexpire -- and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was installed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>Install production so the audit roster is registered, and clear what a previous method left.</p>
Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
    Do ##class(OcuPilot.Test.ProviderPortProbe).SetSecretClass("OcuPilot.Test.SecretProbe")
    Do ##class(OcuPilot.Test.ProviderPortProbe).SetSslState("present")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue("probe-local-abcdefghijklmnop")
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#AUDITCREDENTIAL)
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#AUDITOTHERCREDENTIAL)
    Set ..PreparedSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Test.SwitchFixture).Reset(.tLeft)
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe definitions this class created are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no " _ ..#PROBEPREFIX _ " definition survives this class")
    Set tSwitchSC = ##class(OcuPilot.Test.SwitchFixture).Reset(.tLeft)
    Do $$$AssertStatusOK(tSwitchSC, "the holds this class wrote are removed")
    Do $$$AssertEquals(tLeft, 0, "and none survives this class")
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#AUDITCREDENTIAL)
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#AUDITOTHERCREDENTIAL)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#AUDITCREDENTIAL), 0, "and no credential entry does either")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#AUDITOTHERCREDENTIAL), 0, "under either reference")
    Quit $$$OK
}

/// <p>One request to the API as the suite's own credentials.</p>
ClassMethod Call(pMethod As %String, pPath As %String, pBody As %String, Output pStatus As %Integer, Output pBodyText As %String) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .tHeaders, pBody, "application/json")
}

/// <p>Send one request and assert it answered <var>pExpected</var>; the parsed body, or
/// <code>$$$NULLOREF</code>.</p>
Method Expect(pWhat As %String, pMethod As %String, pPath As %String, pBody As %String, pExpected As %Integer) As %DynamicObject
{
    Set tSC = ..Call(pMethod, pPath, pBody, .tStatus, .tText)
    Do $$$AssertStatusOK(tSC, pWhat _ ": the request completes")
    Do $$$AssertEquals(tStatus, pExpected, pWhat _ ": answered " _ pExpected _ " (" _ tText _ ")")
    If tStatus '= pExpected Quit $$$NULLOREF
    If tText = "" Quit {}
    Quit ##class(%DynamicObject).%FromJSON(tText)
}

/// <p>Create a definition over the wire from body text <var>pFields</var>, which names everything
/// but the name; its id, or <code>""</code>.</p>
Method Create(pSuffix As %String, pFields As %String) As %String
{
    Set tAnswer = ..Expect(pSuffix, "POST", "/agent/definitions", "{""name"":""" _ ..#PROBEPREFIX _ pSuffix _ """," _ pFields _ "}", 201)
    If '$IsObject(tAnswer) Quit ""
    Quit tAnswer.id
}

/// <p><b>Delete</b> (DW-404, DW-411) -- a deleted definition's row is read back, naming what became
/// of the credential entry it had created: <code>effects.credentialEntry</code> is
/// <code>removed</code>, and the entry is gone. A definition with no credential reference records
/// no effect at all.</p>
/// <p>Mutation: pass no effects from <method>OcuPilot.Api.Definitions.HandleDelete</method>'s
/// <method>LogChange</method> call -- the effect assertion goes red.</p>
Method TestADeleteIsRecordedWithWhatBecameOfItsCredentialEntry()
{
    Set tId = ..Create("AuditDelete", """provider"":""anthropic"",""credType"":""creds"",""credentialName"":""" _ ..#AUDITCREDENTIAL _ """")
    If tId = "" Quit
    Do ..Expect("store", "POST", "/agent/definitions/" _ tId _ "/credential", ##class(OcuPilot.Test.CredentialFixture).PayloadText(..#PROBEKEY), 200)
    Do ..Expect("delete", "DELETE", "/agent/definitions/" _ tId, "", 200)

    Set tData = ##class(OcuPilot.Test.AuditRecord).RowFor(..PreparedSince, 1, tId, "delete", .tRows)
    Do $$$AssertEquals(tRows, 1, "exactly one security-change row records the delete: " _ tRows)
    If tRows = 1 {
        Do $$$AssertTrue(tData [ """effects"":{""credentialEntry"":""removed""}", "naming the credential entry as removed: " _ tData)
        Do $$$AssertEquals(tData [ ..#AUDITCREDENTIAL, 0, "and carrying no credential reference")
        Do $$$AssertEquals(tData [ ..#PROBEKEY, 0, "and no key")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#AUDITCREDENTIAL), 0, "and the entry really is gone")

    Set tEnvId = ..Create("AuditDeleteEnv", """provider"":""anthropic"",""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY""")
    If tEnvId = "" Quit
    Do ..Expect("env delete", "DELETE", "/agent/definitions/" _ tEnvId, "", 200)
    Set tEnvData = ##class(OcuPilot.Test.AuditRecord).RowFor(..PreparedSince, 1, tEnvId, "delete", .tEnvRows)
    Do $$$AssertEquals(tEnvRows, 1, "the delete of a definition with no credential reference is recorded too: " _ tEnvRows)
    If tEnvRows = 1 Do $$$AssertEquals(tEnvData [ """effects""", 0, "with no effect to name: " _ tEnvData)
}

/// <p><b>Update, repointed</b> (DW-411) -- a definition repointed away from the credential entry it
/// created is read back naming what became of that entry: <code>effects.credentialEntry</code> is
/// <code>removed</code>, and the entry is gone.</p>
/// <p>Mutation: pass no effects from <method>OcuPilot.Api.Definitions.HandleUpdate</method>'s
/// <method>LogChange</method> call -- the effect assertion goes red.</p>
Method TestARepointIsRecordedWithWhatBecameOfItsCredentialEntry()
{
    Set tId = ..Create("AuditRepoint", """provider"":""anthropic"",""credType"":""creds"",""credentialName"":""" _ ..#AUDITCREDENTIAL _ """")
    If tId = "" Quit
    Do ..Expect("store", "POST", "/agent/definitions/" _ tId _ "/credential", ##class(OcuPilot.Test.CredentialFixture).PayloadText(..#PROBEKEY), 200)
    Do ..Expect("repoint", "PUT", "/agent/definitions/" _ tId, "{""credentialName"":""" _ ..#AUDITOTHERCREDENTIAL _ """}", 200)

    Set tData = ##class(OcuPilot.Test.AuditRecord).RowFor(..PreparedSince, 1, tId, "update", .tRows)
    Do $$$AssertEquals(tRows, 1, "exactly one security-change row records the repoint: " _ tRows)
    If tRows = 1 {
        Do $$$AssertTrue(tData [ """effects"":{""credentialEntry"":""removed""}", "naming the entry it left as removed: " _ tData)
        Do $$$AssertEquals((tData [ ..#AUDITCREDENTIAL) || (tData [ ..#AUDITOTHERCREDENTIAL), 0, "and carrying neither credential reference")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#AUDITCREDENTIAL), 0, "and the entry really is gone")
}

/// <p><b>Default</b> (DW-404) -- the default verb is read back as a <code>SecurityChange</code>:
/// the marker selects the endpoint and credential a turn uses (AD-42). The class removes every
/// other probe definition first, so on a throwaway the one created here already carries the marker
/// and the row is classified by its verb alone.</p>
/// <p>Mutation: drop the default-verb arm from
/// <method>OcuPilot.Api.Definitions.ClassifyChange</method> -- the row lands under
/// <code>ConfigChange</code> and this goes red.</p>
Method TestMovingTheDefaultIsRecordedAsASecurityChange()
{
    Set tId = ..Create("AuditDefault", """provider"":""anthropic"",""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY""")
    If tId = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tId, 1, 1), "the definition is enabled, so it may carry the marker")
    Do ..Expect("default", "POST", "/agent/definitions/" _ tId _ "/default", "", 200)

    Set tData = ##class(OcuPilot.Test.AuditRecord).RowFor(..PreparedSince, 1, tId, "default", .tRows)
    Do $$$AssertEquals(tRows, 1, "exactly one security-change row records the marker move: " _ tRows)
    If tRows = 1 Do $$$AssertTrue(tData [ """verb"":""default""", "naming the verb: " _ tData)
    Do ##class(OcuPilot.Test.AuditRecord).RowFor(..PreparedSince, 0, tId, "default", .tConfigRows)
    Do $$$AssertEquals(tConfigRows, 0, "and none under the configuration event name")
}

/// <p><b>Default, moved by another write</b> (DW-404) -- disabling the definition that carries the
/// marker moves it to an enabled peer, and that update is read back as a
/// <code>SecurityChange</code> naming the marker it lost.</p>
/// <p>Mutation: drop the change-set arm for <code>default</code> from
/// <method>OcuPilot.Api.Definitions.ClassifyChange</method> -- the update lands under
/// <code>ConfigChange</code> and this goes red.</p>
Method TestDisablingTheDefaultRecordsTheMarkerMoveAsASecurityChange()
{
    Set tFields = """provider"":""anthropic"",""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY"""
    Set tHeld = ..Create("AuditDefaultHeld", tFields)
    Set tPeer = ..Create("AuditDefaultPeer", tFields)
    If (tHeld = "") || (tPeer = "") Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tHeld, 1, 1), "the definition holding the marker is enabled")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tPeer, 1, 1), "and so is its peer")
    Do ..Expect("default", "POST", "/agent/definitions/" _ tHeld _ "/default", "", 200)
    Do ..Expect("disable", "PUT", "/agent/definitions/" _ tHeld, "{""enabled"":false}", 200)

    Set tData = ##class(OcuPilot.Test.AuditRecord).RowFor(..PreparedSince, 1, tHeld, "update", .tRows)
    Do $$$AssertEquals(tRows, 1, "exactly one security-change row records the disable: " _ tRows)
    If tRows = 1 Do $$$AssertTrue(tData [ """default"":{""old"":""1"",""new"":""0""}", "naming the marker the definition lost: " _ tData)
    Do ##class(OcuPilot.Test.AuditRecord).RowFor(..PreparedSince, 0, tHeld, "update", .tConfigRows)
    Do $$$AssertEquals(tConfigRows, 0, "and none under the configuration event name")
}

/// <p><b>Credential</b> (DW-404, DW-409) -- a store is read back as a security change, and names the
/// sibling definitions it disabled in <code>effects.disabledSiblings</code>, but not the definition
/// it was posted to.</p>
/// <p>Mutation: pass no effects from
/// <method>OcuPilot.Api.Definitions.HandleStoreCredential</method>'s success-path
/// <method>LogChange</method> call -- the sibling assertion goes red.</p>
Method TestACredentialStoreIsRecordedNamingTheSiblingsItDisabled()
{
    Set tFields = """provider"":""anthropic"",""credType"":""creds"",""credentialName"":""" _ ..#AUDITCREDENTIAL _ """"
    Set tPosted = ..Create("AuditStorePosted", tFields)
    Set tSibling = ..Create("AuditStoreSibling", tFields)
    If (tPosted = "") || (tSibling = "") Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).SetFlags(tSibling, 1, 1), "the sibling is enabled and verified")
    Do ..Expect("store", "POST", "/agent/definitions/" _ tPosted _ "/credential", ##class(OcuPilot.Test.CredentialFixture).PayloadText(..#PROBEKEY), 200)

    Set tData = ##class(OcuPilot.Test.AuditRecord).RowFor(..PreparedSince, 1, tPosted, "credential", .tRows)
    Do $$$AssertEquals(tRows, 1, "exactly one security-change row records the store: " _ tRows)
    If tRows '= 1 Quit
    Do $$$AssertTrue(tData [ ("""effects"":{""disabledSiblings"":[""" _ tSibling _ """]}"), "naming the sibling it disabled, and only that one: " _ tData)
    Do $$$AssertEquals(tData [ ..#PROBEKEY, 0, "and carrying no part of the key")
    Do $$$AssertEquals(tData [ ..#AUDITCREDENTIAL, 0, "and no credential reference")
}

/// <p><b>Hold and release</b> (DW-404) -- switching the agent off for one user, and back on, are
/// each read back as a security change against the switches' own target.</p>
Method TestAHoldAndItsReleaseAreEachRecorded()
{
    Set tUser = ##class(OcuPilot.Test.SwitchFixture).#PROBEPREFIX _ $Translate($System.Util.CreateGUID(), "-", "")
    Set tHold = ..Expect("hold", "POST", "/agent/switches/holds", "{""userName"":""" _ tUser _ """,""reason"":""audit probe""}", 201)
    If '$IsObject(tHold) Quit
    Set tEvent = ##class(OcuPilot.Kernel.Audit.Event).EventNameFor(1)
    Set tRows = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(..PreparedSince, tEvent, tUser, .tData, """verb"":""hold""")
    Do $$$AssertEquals(tRows, 1, "exactly one security-change row records the hold: " _ tRows)
    If tRows = 1 Do $$$AssertTrue(tData [ ("""type"":""" _ ##class(OcuPilot.Api.Switches).#ENTITYTYPE _ """"), "against the switches' own target: " _ tData)

    Do ..Expect("release", "DELETE", "/agent/switches/holds/" _ tHold.id, "", 200)
    Set tReleaseRows = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(..PreparedSince, tEvent, tUser, .tReleaseData, """verb"":""release""")
    Do $$$AssertEquals(tReleaseRows, 1, "and exactly one records the release: " _ tReleaseRows)
    If tReleaseRows = 1 Do $$$AssertTrue(tReleaseData [ ("""userName"":{""old"":""" _ tUser _ """,""new"":""""}"), "naming the user switched back on: " _ tReleaseData)
}

/// <p><b>Test, faulted</b> (DW-397) -- a Test connection of values the row does not hold whose call
/// faults is read back as a security change naming the key it carried and the code it met.</p>
/// <p>Mutation: remove the record from <method>OcuPilot.Api.Definitions.ConnectionOutcome</method>'s
/// fault branch -- no row is found and this goes red.</p>
Method TestAFaultedTestOfUnstoredValuesIsRecorded()
{
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = ..#PROBEPREFIX _ "AuditFaulted"
    Set tRow.Provider = ##class(OcuPilot.Test.CatalogProbe).#LOCALKEY
    Set tRow.Model = "probe-local-model-1"
    Set tRow.EndpointUrl = ..#PUBLICENDPOINT
    Set tRow.CredType = "env"
    Set tRow.EnvVarName = "OCUPILOT_PROBE_LOCAL_KEY"
    Set tRow.MaxTokens = 4000
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
    Do $$$AssertStatusOK(tSC, "a stored definition is created")
    If $$$ISERR(tSC) Quit
    Set tId = tRow.%Id()
    Set tRow = ""

    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(401, "{""type"":""error"",""error"":{""type"":""authentication_error"",""message"":""invalid x-api-key""}}")
    Set tEdit = {"endpointUrl": (..#OTHERENDPOINT)}
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentConnection).Outcome(tId, tEdit, .tAnswer, .tStatus, .tFault), "a test against another endpoint runs")
    Do $$$AssertTrue($IsObject(tFault), "and faults")

    Set tData = ##class(OcuPilot.Test.AuditRecord).RowFor(..PreparedSince, 1, tId, "test", .tRows)
    Do $$$AssertEquals(tRows, 1, "exactly one security-change row records the faulted test: " _ tRows)
    If tRows '= 1 Quit
    Do $$$AssertTrue(tData [ """effects"":{""keySource"":""none"",""faultCode"":""PROVIDER.REFUSED""}", "naming the key it carried and the code it met: " _ tData)
    Do $$$AssertTrue(tData [ ("""endpointUrl"":{""old"":""" _ ..#PUBLICENDPOINT _ """,""new"":""" _ ..#OTHERENDPOINT _ """}"), "and the endpoint it went to")
}

}
