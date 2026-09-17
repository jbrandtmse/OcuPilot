/// <p>AC2 and AC6 -- what an accepted configuration write actually records, read back from the
/// IRIS audit database rather than from the emitter's own state.</p>
/// <p><b>Every assertion here reads <class>%SYS.Audit</class>.</b> A change record is emitted
/// inside the web worker's process, where a process-private capture cannot reach it, and the audit
/// row is the thing AC2 is about; the console line has its own coverage in
/// <class>OcuPilot.Test.AgentWire</class> and <class>OcuPilot.Test.SwitchState</class>. Reads go
/// through <method>OcuPilot.Test.AuditEvent.RowsCarrying</method>, which reads the master map
/// under <code>%NOINDEX</code> bounded by <code>UTCTimeStamp</code> -- the audit indexes lag about
/// 60 seconds and a row younger than the last pass is invisible to a query that reads them
/// (DW-85).</p>
/// <p><b>The write paths are the shipped ones.</b> The create, the three edits and the switch write
/// are driven over HTTP through the real <code>/api/ocupilot</code> application, which is what
/// makes AC6 an assertion from the consumer's side. Test connection is driven <b>in process</b>
/// through <class>OcuPilot.Test.DefinitionsProbe</class>, whose port seam answers from a stub, so
/// no socket is opened to any provider -- the same arrangement
/// <class>OcuPilot.Test.AgentConnection</class> uses, and for the same reason.</p>
/// <p>Every definition this class creates is named with <parameter>PROBEPREFIX</parameter> and
/// removed in <method>OnAfterOneTest</method>, which then asserts none survives; the switch row
/// and any hold go the same way.</p>
/// <p><b>It runs OcuPilot's production install, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>, <code>ocupilot-ci</code>), and
/// <method>OnBeforeAllTests</method> refuses anywhere <parameter>ARMINGVARIABLE</parameter> does
/// not arm it.</p>
Class OcuPilot.Test.AuditRecord Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it, so the install this class
/// runs happens on the container that script builds and nowhere else.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

/// <p>Refuse to run at all unless this instance is armed for a production install.</p>
/// <p><b>A doc comment does not keep a class that installs from installing.</b> Test classes are
/// selected by package, so pointing the runner at a container someone cares about would run
/// OcuPilot's production install on it. Failing here is the honest outcome: nothing is installed
/// and the reason is named.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuditRecord runs OcuPilot's PRODUCTION install on this instance -- a database, a resource, a role, three web applications, the audit registrations and the _SYSTEM unexpire -- and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was installed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>The prefix every definition this class creates is named with, so
/// <class>OcuPilot.Test.AgentFixture</class>'s teardown finds them all.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>A documentation-reserved endpoint (RFC 5737 TEST-NET-1): it classifies as an ordinary public
/// address without a name lookup, and nothing ever connects to it.</p>
Parameter PUBLICENDPOINT = "https://192.0.2.1/v1/messages";

/// <p>A second reserved literal (RFC 5737 TEST-NET-2), for the legs that edit the endpoint.</p>
Parameter OTHERENDPOINT = "https://198.51.100.7/v1/messages";

/// <p>A credential of the shape <class>OcuPilot.Test.CatalogProbe</class>'s local row requires.</p>
Parameter PROBEKEY = "probe-local-abcdefghijklmnop";

/// <p>A well-formed provider reply, for the Test-connection legs.</p>
Parameter OKBODY = "{""content"":[{""type"":""text"",""text"":""probe-reply-marker ok""}],""stop_reason"":""end_turn"",""usage"":{""input_tokens"":1,""output_tokens"":2}}";

/// <p>The credential reference a definition starts with on the <code>creds</code> leg.</p>
Parameter FIRSTCREDENTIAL = "OcuPilotProbeCredentialOne";

/// <p>The one it is edited to.</p>
Parameter SECONDCREDENTIAL = "OcuPilotProbeCredentialTwo";

/// <p>The audit database's own clock, read at the start of each method so a read can be bounded to
/// the rows that method wrote. The prefix must not begin with "Test"
/// (<file>.claude/rules/objectscript-testing.md</file>).</p>
Property PreparedSince As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedSince = ""
    Quit $$$OK
}

/// <p>Install production so the audit-event roster is registered -- a row cannot be read back from
/// a triple nothing registered -- and clear whatever a previous method left behind.</p>
Method OnBeforeOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Install.Installer).Install("")
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
    Do ##class(OcuPilot.Test.ProviderPortProbe).SetSecretClass("OcuPilot.Test.SecretProbe")
    Do ##class(OcuPilot.Test.ProviderPortProbe).SetSslState("present")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Set ..PreparedSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Test.SwitchFixture).Reset(.tLeft)
}

/// <p>Remove every definition, switch row and hold this class wrote, and assert none survives.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProviderPortProbe).Reset()
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe definitions this class created are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no " _ ..#PROBEPREFIX _ " definition survives this class")
    Set tSwitchSC = ##class(OcuPilot.Test.SwitchFixture).Reset(.tLeft)
    Do $$$AssertStatusOK(tSwitchSC, "the switch row and holds this class wrote are removed")
    Do $$$AssertEquals(tLeft, 0, "and none survives this class")
    Quit $$$OK
}

/// <p>One request to the API as the suite's own credentials.</p>
ClassMethod Call(pMethod As %String, pPath As %String, pBody As %String, Output pStatus As %Integer, Output pBodyText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .pHeaders, pBody, "application/json")
}

/// <p>The audit row this class's writes are found by: the target triple's own id, which is unique
/// per definition, spelled as it appears in the row's <code>EventData</code>.</p>
ClassMethod IdMarker(pId As %String) As %String
{
    Quit """id"":""" _ pId _ """"
}

/// <p>The verb a row records, spelled as it appears in the row's <code>EventData</code>.</p>
ClassMethod VerbMarker(pVerb As %String) As %String
{
    Quit """verb"":""" _ pVerb _ """"
}

/// <p>The data of the one row under the event <var>pSecurityChange</var> selects that names
/// target <var>pId</var> and verb <var>pVerb</var> -- or <code>""</code>, with the count in
/// <var>pRows</var>, when there is not exactly one.</p>
/// <p><b>Identified by target and verb, not by time.</b> Two writes a few milliseconds apart both
/// fall on or after a bound taken between them, because <code>$ZTimeStamp</code>'s resolution is
/// coarser than that; the event name, the target id and the verb together name one write, and
/// <var>pSince</var> only keeps the scan short.</p>
ClassMethod RowFor(pSince As %String, pSecurityChange As %Boolean, pId As %String, pVerb As %String, Output pRows As %Integer) As %String
{
    Set tEvent = ##class(OcuPilot.Kernel.Audit.Event).EventNameFor(pSecurityChange)
    Set pRows = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, tEvent, ..IdMarker(pId), .tData, ..VerbMarker(pVerb))
    If pRows '= 1 Quit ""
    Quit tData
}

/// <p>The data of the one row under the event <var>pSecurityChange</var> selects carrying
/// <var>pMarker</var>, for a target with no id of its own.</p>
ClassMethod RowCarrying(pSince As %String, pSecurityChange As %Boolean, pMarker As %String, Output pRows As %Integer) As %String
{
    Set tEvent = ##class(OcuPilot.Kernel.Audit.Event).EventNameFor(pSecurityChange)
    Set pRows = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(pSince, tEvent, pMarker, .tData)
    If pRows '= 1 Quit ""
    Quit tData
}

/// <p>Create one definition over the wire and answer its id, or <code>""</code>.</p>
Method CreateOverTheWire(pSuffix As %String, pBody As %String) As %String
{
    Set tSC = ..Call("POST", "/agent/definitions", pBody, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, pSuffix _ ": the create request completes")
    Do $$$AssertEquals(tStatus, 201, pSuffix _ ": the definition is created (" _ tBody _ ")")
    If tStatus '= 201 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tBody).id
}

/// <p>AC2 -- <b>a create records the fields it created, defaults included</b> (DW-331). Diffing a
/// create against a <code>%New()</code> row dropped every field the create left at its class
/// default, so the record of the write that set the read-only flag, the retention window and the
/// two bounds did not name them.</p>
/// <p><code>maxTokens</code> appears <b>in clear</b>, which is DW-329's own row: an unanchored
/// credential-name matcher masked a bound the operator set in the record of the change that set
/// it.</p>
/// <p>Mutation (Rule 19): restore <method>OcuPilot.Api.Definitions.HandleCreate</method>'s
/// <code>%New()</code> before-row -- the five default-field assertions go red. Restore
/// <method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method>'s substring match -- the
/// <code>maxTokens</code>-in-clear assertion goes red reading <code>[redacted]</code>.</p>
Method TestACreateRecordsTheFieldsItCreatedAtTheirDefaults()
{
    Set tId = ..CreateOverTheWire("create", "{""name"":""" _ ..#PROBEPREFIX _ "AuditCreate"",""provider"":""anthropic"",""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY""}")
    If tId = "" Quit

    ; A create sets the provider, the endpoint and the credential reference, so it is classified a
    ; security change by the same rule an edit of any of them is (AD-42).
    Set tData = ..RowFor(..PreparedSince, 1, tId, "create", .tRows)
    Do $$$AssertEquals(tRows, 1, "exactly one audit row records the create of this definition: " _ tRows)
    If tRows '= 1 Quit
    Do $$$AssertTrue(tData [ """verb"":""create""", "naming the verb: " _ tData)
    ; The authenticated caller of the REQUEST, which is not this process's own identity: the suite
    ; runs in a session started from the instance's own process tree and the write was made over
    ; HTTP as the configured test principal.
    Do $$$AssertTrue(tData [ ("""actor"":""" _ ##class(OcuPilot.Test.Http).GetTestUsername() _ """"), "and the actor, which is the authenticated caller of the request rather than this process's identity")
    Do $$$AssertTrue(tData [ """type"":""agent-definition""", "and the target's entity type")
    Do $$$AssertTrue(tData [ ("""scope"":""" _ ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE _ """"), "and the instance scope")

    ; The five fields the body never named and the class's own InitialExpressions supplied. Each
    ; carries an empty "old", which is what "a create has no before-state" looks like in the record.
    For tField = "markedLocal", "temperature", "maxIterationsPerTurn", "readOnly", "retentionDays" {
        Do $$$AssertTrue(tData [ ("""" _ tField _ """:{""old"":"""","), "the record carries " _ tField _ ", created at its default, with an empty old value: " _ tData)
    }
    Do $$$AssertTrue(tData [ """maxTokens"":{""old"":"""",""new"":""32000""}", "and maxTokens in clear, not redacted (DW-329): " _ tData)
    Do $$$AssertTrue(tData [ ("""name"":{""old"":"""",""new"":""" _ ..#PROBEPREFIX _ "AuditCreate""}"), "and the name the body did carry")
}

/// <p>AC2, AC6 -- <b>an endpoint edit is recorded as a security change naming both addresses</b>
/// (AD-42), driven through <method>OcuPilot.Api.Definitions.HandleUpdate</method> over HTTP and
/// asserted from the audit database.</p>
/// <p>Mutation (Rule 19): remove the <method>OcuPilot.Api.Definitions.RecordAudit</method> call
/// from <method>LogChange</method> -- no row is found and this goes red while the console line
/// every other test reads is untouched.</p>
Method TestAnEndpointEditIsRecordedAsASecurityChangeWithBothAddresses()
{
    Set tId = ..CreateOverTheWire("endpoint", "{""name"":""" _ ..#PROBEPREFIX _ "AuditEndpoint"",""provider"":""anthropic"",""endpointUrl"":""" _ ..#PUBLICENDPOINT _ """,""credType"":""env"",""envVarName"":""ANTHROPIC_API_KEY""}")
    If tId = "" Quit

    Set tSC = ..Call("PUT", "/agent/definitions/" _ tId, "{""endpointUrl"":""" _ ..#OTHERENDPOINT _ """}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the update request completes")
    Do $$$AssertEquals(tStatus, 200, "the edit is accepted (" _ tBody _ ")")
    If tStatus '= 200 Quit

    Set tData = ..RowFor(..PreparedSince, 1, tId, "update", .tRows)
    Do $$$AssertEquals(tRows, 1, "exactly one security-change row was written for the edit: " _ tRows)
    If tRows '= 1 Quit
    Do $$$AssertTrue(tData [ """verb"":""update""", "naming the verb: " _ tData)
    Do $$$AssertTrue(tData [ """securityChange"":true", "classified as a security change (AD-42)")
    Do $$$AssertTrue(tData [ ("""endpointUrl"":{""old"":""" _ ..#PUBLICENDPOINT _ """,""new"":""" _ ..#OTHERENDPOINT _ """}"), "carrying the old endpoint and the new one: " _ tData)
    Do $$$AssertEquals(..RowFor(..PreparedSince, 0, tId, "update", .tConfigRows), "", "and nothing under the configuration event name")
    Do $$$AssertEquals(tConfigRows, 0, "which is zero rows, not an unreadable count")
}

/// <p>AC2 -- <b><code>maxTokens</code> is recorded in clear and a credential reference redacted on
/// both halves</b>, the two sides of the anchored credential-name rule (DW-329, AD-35). Both edits
/// go through <method>OcuPilot.Api.Definitions.HandleUpdate</method> over HTTP.</p>
/// <p>Mutation (Rule 19): drop <code>credentialname</code> from
/// <parameter>OcuPilot.Kernel.Audit.Log.CREDENTIALEXACTNAMES</parameter> -- the redaction
/// assertions go red and both stored names reach the row.</p>
Method TestATuningEditIsInClearAndACredentialReferenceIsRedacted()
{
    Set tId = ..CreateOverTheWire("tuning", "{""name"":""" _ ..#PROBEPREFIX _ "AuditTuning"",""provider"":""anthropic"",""credType"":""creds"",""credentialName"":""" _ ..#FIRSTCREDENTIAL _ """}")
    If tId = "" Quit

    Set tSC = ..Call("PUT", "/agent/definitions/" _ tId, "{""maxTokens"":4000}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the tuning edit completes")
    Do $$$AssertEquals(tStatus, 200, "and is accepted (" _ tBody _ ")")
    If tStatus '= 200 Quit
    Set tTuningData = ..RowFor(..PreparedSince, 0, tId, "update", .tTuningRows)
    Do $$$AssertEquals(tTuningRows, 1, "the tuning edit wrote exactly one configuration-change row: " _ tTuningRows)
    If tTuningRows = 1 {
        Do $$$AssertTrue(tTuningData [ """maxTokens"":{""old"":""32000"",""new"":""4000""}", "carrying both bounds in clear: " _ tTuningData)
    }

    Set tCredSC = ..Call("PUT", "/agent/definitions/" _ tId, "{""credentialName"":""" _ ..#SECONDCREDENTIAL _ """}", .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tCredSC, "the credential-reference edit completes")
    Do $$$AssertEquals(tStatus2, 200, "and is accepted (" _ tBody2 _ ")")
    If tStatus2 '= 200 Quit
    Set tCredData = ..RowFor(..PreparedSince, 1, tId, "update", .tCredRows)
    Do $$$AssertEquals(tCredRows, 1, "the credential-reference edit wrote exactly one security-change row: " _ tCredRows)
    If tCredRows '= 1 Quit
    Do $$$AssertTrue(tCredData [ """credentialName"":""[redacted]""", "with the credential reference masked by name, both halves gone: " _ tCredData)
    Do $$$AssertEquals(tCredData [ ..#FIRSTCREDENTIAL, 0, "so the old reference does not reach the audit row")
    Do $$$AssertEquals(tCredData [ ..#SECONDCREDENTIAL, 0, "and neither does the new one")
}

/// <p>AC2, AC6 -- <b>a switch write is recorded against the switches' own target</b>
/// (<code>agent-switch</code>/<code>instance</code>/<code>instance</code>), driven through
/// <method>OcuPilot.Api.Switches.HandleUpdate</method> over HTTP.</p>
/// <p>Mutation (Rule 19): remove the <method>OcuPilot.Api.Switches.RecordAudit</method> call from
/// that class's <method>LogChange</method> -- the switch row is not found while the definition
/// rows the methods above assert are still written, which is what shows the two consumers are
/// wired separately.</p>
Method TestASwitchWriteIsRecordedAgainstTheSwitchTarget()
{
    Set tMarker = "OcuPilotProbeSwitch" _ $Translate($System.Util.CreateGUID(), "-", "")
    Set tSC = ..Call("PUT", "/agent/switches", "{""killSwitch"":true,""killSwitchReason"":""" _ tMarker _ """}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the switch write completes")
    Do $$$AssertEquals(tStatus, 200, "and is accepted (" _ tBody _ ")")
    If tStatus '= 200 Quit

    Set tData = ..RowCarrying(..PreparedSince, 1, tMarker, .tRows)
    Do $$$AssertEquals(tRows, 1, "exactly one security-change row carries this run's own reason: " _ tRows)
    If tRows '= 1 Quit
    Do $$$AssertTrue(tData [ """verb"":""switches""", "naming the verb: " _ tData)
    Do $$$AssertTrue(tData [ ("""type"":""" _ ##class(OcuPilot.Api.Switches).#ENTITYTYPE _ """"), "against the agent-switch entity type")
    Do $$$AssertTrue(tData [ ("""scope"":""" _ ##class(OcuPilot.Kernel.Scope).#SCOPEINSTANCE _ """"), "the instance scope")
    Do $$$AssertTrue(tData [ ("""id"":""" _ ##class(OcuPilot.Api.Switches).#ENTITYID _ """"), "and the instance id (AD-13)")
    Do $$$AssertTrue(tData [ """killSwitch"":{""old"":""0"",""new"":""1""}", "carrying the flag that moved: " _ tData)
}

/// <p>Story 4.4 -- <code>contextRowCap</code> is a security field
/// (<method>OcuPilot.Api.Switches.Fields</method>): a write at either edge of its valid range, 1
/// and 1,000, is accepted and lands as a security-change audit row naming the field's old and new
/// values, driven through <method>OcuPilot.Api.Switches.HandleUpdate</method> over HTTP.</p>
/// <p>Mutation (QA): narrow the lower bound in
/// <method>OcuPilot.Kernel.SwitchRules.ValidateSwitches</method> from <code>&lt; 1</code> to
/// <code>&lt; 2</code> -- the boundary value 1 is refused where 200 (accepted) is expected, and
/// this goes red.</p>
Method TestAContextRowCapWriteAtItsBoundariesIsRecordedAsASecurityChange()
{
    Set tSC = ..Call("PUT", "/agent/switches", "{""contextRowCap"":1}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the low-boundary write completes")
    Do $$$AssertEquals(tStatus, 200, "1 is accepted: " _ tBody)
    If tStatus '= 200 Quit

    Set tData = ..RowCarrying(..PreparedSince, 1, """contextRowCap"":{""old"":""200"",""new"":""1""}", .tRows)
    Do $$$AssertEquals(tRows, 1, "exactly one security-change row carries the low-boundary write: " _ tRows)
    If tRows '= 1 Quit
    Do $$$AssertTrue(tData [ """verb"":""switches""", "naming the verb: " _ tData)

    Set tSC2 = ..Call("PUT", "/agent/switches", "{""contextRowCap"":1000}", .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC2, "the high-boundary write completes")
    Do $$$AssertEquals(tStatus2, 200, "1,000 is accepted: " _ tBody2)
    If tStatus2 '= 200 Quit

    Set tData2 = ..RowCarrying(..PreparedSince, 1, """contextRowCap"":{""old"":""1"",""new"":""1000""}", .tRows2)
    Do $$$AssertEquals(tRows2, 1, "exactly one security-change row carries the high-boundary write: " _ tRows2)
}

/// <p>AC2 -- <b>a Test connection is recorded whether or not it wrote the row</b> (DW-358), and the
/// classification follows what was tested: the stored values are an ordinary configuration change
/// recording the verification flag, and values the row does not hold are a security change naming
/// both endpoints, because a call left the instance for an address nobody audited (AD-42).</p>
/// <p>Driven in process through <class>OcuPilot.Test.DefinitionsProbe</class>, whose port answers
/// from <class>OcuPilot.Test.ProviderStub</class>, so no socket is opened.</p>
/// <p>Mutation (Rule 19): restore
/// <method>OcuPilot.Api.Definitions.ConnectionOutcome</method>'s <code>If tTestedAsStored</code>
/// guard around the record -- the unsaved-test leg finds no row and goes red.</p>
Method TestATestConnectionIsRecordedWhetherOrNotItWroteTheRow()
{
    Set tStoredId = ..ProbeDefinition("AuditTestStored")
    Set tEditedId = ..ProbeDefinition("AuditTestEdited")
    If (tStoredId = "") || (tEditedId = "") Quit

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Set tStoredSC = ..Outcome(tStoredId, "", .tStoredAnswer, .tStoredStatus, .tStoredFault)
    Do $$$AssertStatusOK(tStoredSC, "a test of the stored values runs")
    Do $$$AssertTrue('$IsObject(tStoredFault), "and answers no fault")
    If '$IsObject(tStoredAnswer) Quit
    Do $$$AssertEquals(tStoredAnswer.testedAsStored, 1, "the values tested were the stored ones")
    Set tStoredData = ..RowFor(..PreparedSince, 0, tStoredId, "test", .tStoredRows)
    Do $$$AssertEquals(tStoredRows, 1, "and exactly one configuration-change row records it: " _ tStoredRows)
    If tStoredRows = 1 {
        Do $$$AssertTrue(tStoredData [ """verb"":""test""", "naming the test verb: " _ tStoredData)
        Do $$$AssertTrue(tStoredData [ """connectionVerified"":{""old"":""0"",""new"":""1""}", "and the flag it set")
    }

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..#OKBODY)
    Set tEdit = {"endpointUrl": (..#OTHERENDPOINT)}
    Set tEditedSC = ..Outcome(tEditedId, tEdit, .tEditedAnswer, .tEditedStatus, .tEditedFault)
    Do $$$AssertStatusOK(tEditedSC, "a test of an edited endpoint runs")
    Do $$$AssertTrue('$IsObject(tEditedFault), "and answers no fault either")
    If '$IsObject(tEditedAnswer) Quit
    Do $$$AssertEquals(tEditedAnswer.testedAsStored, 0, "the values tested were not the stored ones")
    Do $$$AssertEquals(tEditedAnswer.connectionVerified, 0, "so nothing was written to the row")
    Set tEditedData = ..RowFor(..PreparedSince, 1, tEditedId, "test", .tEditedRows)
    Do $$$AssertEquals(tEditedRows, 1, "and exactly one SECURITY-change row records it anyway: " _ tEditedRows)
    If tEditedRows '= 1 Quit
    Do $$$AssertTrue(tEditedData [ """verb"":""test""", "naming the test verb: " _ tEditedData)
    Do $$$AssertTrue(tEditedData [ ("""endpointUrl"":{""old"":""" _ ..#PUBLICENDPOINT _ """,""new"":""" _ ..#OTHERENDPOINT _ """}"), "and naming the stored endpoint and the tested one")
    Do $$$AssertEquals(tEditedData [ """maxTokens"":{""old"":""4000"",""new"":""32""}", 0, "and not the test's own budget, which the definition never carried: " _ tEditedData)
}

/// <p>One stored definition on <class>OcuPilot.Test.CatalogProbe</class>'s local-allowed row, whose
/// <code>adapterClass</code> is the transport stub, and its id -- or <code>""</code>.</p>
Method ProbeDefinition(pSuffix As %String) As %String
{
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = ..#PROBEPREFIX _ pSuffix
    Set tRow.Provider = ##class(OcuPilot.Test.CatalogProbe).#LOCALKEY
    Set tRow.Model = "probe-local-model-1"
    Set tRow.EndpointUrl = ..#PUBLICENDPOINT
    Set tRow.CredType = "env"
    Set tRow.EnvVarName = "OCUPILOT_PROBE_LOCAL_KEY"
    Set tRow.MaxTokens = 4000
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
    Do $$$AssertStatusOK(tSC, pSuffix _ ": a stored definition is created")
    If $$$ISERR(tSC) Quit ""
    Set tId = tRow.%Id()
    Set tRow = ""
    Quit tId
}

/// <p>One test outcome through <class>OcuPilot.Test.DefinitionsProbe</class>, from the inputs
/// <method>OcuPilot.Api.Definitions.HandleTest</method> hands
/// <method>OcuPilot.Api.Definitions.ConnectionOutcome</method>.</p>
ClassMethod Outcome(pId As %String, pBody As %DynamicObject, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Test.AgentConnection).Outcome(pId, pBody, .pAnswer, .pHttpStatus, .pFault)
}

}
