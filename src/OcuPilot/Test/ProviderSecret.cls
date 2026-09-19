/// <p><b>AC6, the credential-never-leaks proof.</b> A canary credential is driven through ten
/// forced provider failures -- eight on the environment rung, one on the credentials rung, out of
/// a real credential entry resolved by the shipped ladder, and one as a key a Test connection body
/// carries. Four of the eight drive the canonical family; the other four are a refusal and a
/// mid-flight raise on each of the two families whose adapters write their own authentication
/// header -- and the two logs OcuPilot itself
/// renders, the console log and the application error log, are read afterwards and asserted to carry
/// no part of it, alongside every returned <code>reason</code>, <code>code</code> and
/// <code>detail</code>.</p>
/// <p><b>It forces a real <code>^ERRORS</code> entry, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>, <code>ocupilot-ci</code>).
/// <method>OnBeforeAllTests</method> refuses anywhere <parameter>ARMINGVARIABLE</parameter> does
/// not arm it, and <method>OcuPilot.Test.ProviderStub.ArmErrorLog</method> refuses on its own
/// besides. An application error cannot be un-logged: the delete is Epic 5's.</p>
/// <p><b>The forced entry is what makes the assertion non-vacuous.</b> Comparing two runs that both
/// wrote nothing proves nothing; an entry is written, from two frames of the adapter's own call
/// stack, and the test asserts on its captured variable table. <code>^%ETN</code> records every
/// local at every live stack level (AD-48), which is the mechanism this whole design is built
/// against: the key lives on the adapter's <code>[ Internal ]</code> property, and an object's
/// properties are not in that table.</p>
/// <p><b>The canary is fabricated and has no value.</b> It is shaped like a real key so it passes
/// the shape gate and reaches every point a real one would, and it is unmistakable in a grep. No
/// real credential is used, and no provider is called.</p>
Class OcuPilot.Test.ProviderSecret Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ERROR_SEED";

/// <p>The fabricated credential. Shaped like an Anthropic key so it passes the catalog row's
/// prefix gate, and carrying a word that appears nowhere else in this instance.</p>
Parameter CANARY = "sk-ant-ocupilotleakcanary0000000000";

/// <p>The substring the assertions actually search for -- the canary's distinctive middle, so a
/// grep matches a truncated or re-encoded copy of the value as well as a verbatim one.</p>
Parameter CANARYMARK = "ocupilotleakcanary";

/// <p>The credential entry leg five puts the canary into, and removes again.</p>
Parameter CREDSNAME = "OcuPilotProbeCanaryCredential";

/// <p>The port the failures are driven through.</p>
Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

/// <p>The catalog the last two legs switch in: it re-adapts the two shipped non-canonical rows to
/// stubs that replace the transport alone, so those families' own <code>ApplyAuth</code> runs and
/// no socket is opened.</p>
Parameter SHIPPEDCATALOG = "OcuPilot.Test.CatalogProbeShipped";

/// <p>The two shipped provider keys those legs drive, comma-separated, each with the stub its row
/// answers under <parameter>SHIPPEDCATALOG</parameter>.</p>
Parameter SHIPPEDFAMILIES = "openai:OcuPilot.Test.OpenAIStub,gemini:OcuPilot.Test.GeminiStub";

/// <p>The refusal body those legs answer with. Both families read
/// <code>error.message</code>, and none of it is credential material.</p>
Parameter VENDORERRORBODY = "{""error"":{""code"":401,""status"":""UNAUTHENTICATED"",""message"":""the vendor's own words""}}";

/// <p>How many forced entries one refusal leg on a new family must write: the stub's
/// <method>ApplyAuth</method> leg and the transport's own, one attempt each, because a 401 is not
/// retryable. <b>Asserted exactly</b>, so removing either leg reddens rather than leaving the other
/// to satisfy a "grew" test.</p>
Parameter REFUSALENTRIES As %Integer = 2;

/// <p>How many one mid-flight raise must write: the <method>ApplyAuth</method> leg alone, the
/// transport having raised before reaching its own, and never retried.</p>
Parameter RAISEENTRIES As %Integer = 1;

/// <p>The log port the two logs are read through -- the same readers the screens use, so what this
/// class searches is what a user would see.</p>
Parameter LOGPORT = "OcuPilot.Port.LogSourcePort";

/// <p>The bytes read per console-log page. Well inside the port's own cap.</p>
Parameter PAGEBYTES As %Integer = 262144;

/// <p>The most console-log pages read after the run, so an unexpectedly busy log cannot loop.</p>
Parameter MAXPAGES As %Integer = 64;

/// <p>Refuse to run at all unless this instance is armed for an application-error write.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ProviderSecret forces an application error into this instance's own ^ERRORS and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $$$OK
}

/// <p>Leave no switch set, and no credential entry, for the next class.</p>
Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do ##class(OcuPilot.Test.ProviderStub).ResetErrorLog()
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#CREDSNAME)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#CREDSNAME), 0, "no credential entry this class created survives it")
    ; Leg five puts the canary into a real entry, so its removal has to be asserted where the
    ; vendor actually keeps the value as well: the row's delete trigger clears
    ; ^Ens.SecondaryData.Password through a step that needs a production-enabled namespace, and
    ; the entry reading absent says nothing about the node.
    Do $$$AssertEquals($Get(^Ens.SecondaryData.Password(..#CREDSNAME)), "", "and the canary is not left in the vendor's own secondary password store either")
    Quit $$$OK
}

/// <p>The definition the canary travels on: the catalog row whose key prefix is the shipped
/// Anthropic row's, so the canary passes the shape gate, and whose adapter is the stub, so no
/// socket is opened.</p>
/// <p><var>pCredentialName</var>, when it is given, moves the definition onto the
/// <code>creds</code> rung instead -- the reference named, the environment variable cleared, which
/// is the XOR invariant a stored definition already satisfies.</p>
/// <p><var>pUseRowEndpoint</var> leaves the endpoint empty, so the call goes to the provider row's
/// own canonical endpoint as a create would resolve it
/// (<method>OcuPilot.Port.ProviderPort.EndpointOf</method>).</p>
ClassMethod Definition(Output pValues, pProvider As %String = "", pCredentialName As %String = "", pUseRowEndpoint As %Boolean = 0)
{
    Kill pValues
    Set pValues("provider") = $Select(pProvider = "": ##class(OcuPilot.Test.CatalogProbe).#CANARYKEY, 1: pProvider)
    Set pValues("model") = "probe-canary-model-1"
    Set pValues("endpointUrl") = $Select(pUseRowEndpoint: "", 1: "https://api.anthropic.com/v1/messages")
    Set pValues("markedLocal") = 0
    Set pValues("credType") = $Select(pCredentialName = "": "env", 1: "creds")
    Set pValues("envVarName") = $Select(pCredentialName = "": "OCUPILOT_PROBE_CANARY_KEY", 1: "")
    Set pValues("credentialName") = pCredentialName
    Set pValues("maxTokens") = 4000
    Set pValues("temperature") = 0
}

/// <p>Drive one turn through the port and assert that everything it handed back is canary-free.
/// <var>pKeyBody</var>, when it is an object, is a request body whose <code>apiKey</code> the call
/// carries instead of any resolved key.</p>
Method DriveAndAssert(pWhat As %String, pProvider As %String = "", pCredentialName As %String = "", pKeyBody As %DynamicObject = "", pUseRowEndpoint As %Boolean = 0)
{
    Do ..Definition(.tValues, pProvider, pCredentialName, pUseRowEndpoint)
    If $IsObject(pKeyBody) {
        Set tValues("keySource") = ##class(OcuPilot.Kernel.Provider.Base).#KEYSOURCEBODY
        Set tValues("keyBody") = pKeyBody
        Set tValues("keyField") = "apiKey"
    }
    Set tMessages = 1
    Set tMessages(1, "role") = "user"
    Set tMessages(1, "content") = "probe"
    Set tSC = $ClassMethod(..#PORT, "InvokeDraft", .tValues, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault)
    Do $$$AssertStatusOK(tSC, pWhat _ ": the port returns $$$OK")
    Do $$$AssertTrue($IsObject(tFault), pWhat _ ": with a fault to inspect")
    If '$IsObject(tFault) Quit
    Do $$$AssertEquals(tFault.%ToJSON() [ ..#CANARYMARK, 0, pWhat _ ": and the whole envelope -- reason, code and detail -- carries no credential material: " _ tFault.%ToJSON())
    Do $$$AssertEquals($System.Status.GetErrorText(tSC) [ ..#CANARYMARK, 0, pWhat _ ": nor does the status")
}

/// <p>AC6 -- the canary reaches neither the console log nor the application error log, and neither
/// does any returned reason, code or detail.</p>
/// <p>Mutation: bind the resolved key to a local in
/// <method>OcuPilot.Kernel.Provider.Base.Invoke</method> -- every forced entry captures it and the
/// variable-table assertion goes red at each one (verified on a throwaway). Mutation: interpolate
/// the key into the <code>PROVIDER.KEYSHAPE</code> reason -- the envelope assertion goes red.
/// Mutation: bind the body's member to a local in <method>OcuPilot.Kernel.Provider.Base.Invoke</method>'s
/// body branch -- leg six's forced entry captures it and the variable-table assertion goes red.</p>
/// <p><b>The frames this covers are named in
/// <class>OcuPilot.Test.ProviderStub</class>'s own header</b>, along with the one frame no forced
/// entry can reach; read that before adding a mutation here, because a mutation outside those
/// frames leaves this class green and would be recorded as coverage it does not have. <b>The same
/// exclusion holds for the two new families</b>: their stubs' <method>ApplyAuth</method> overrides
/// delegate first, so <method>OcuPilot.Kernel.Provider.OpenAI.ApplyAuth</method> and
/// <method>OcuPilot.Kernel.Provider.Gemini.ApplyAuth</method> have returned before either entry is
/// raised, and a local held in one of them is not reachable from any forced entry here.</p>
Method TestNoCredentialMaterialReachesTheLogsOrTheEnvelope()
{
    Set tMarked = ..MarkConsoleLog(.tOffset, .tIdentity)
    Do $$$AssertTrue(tMarked, "the console log is readable, so there is a mark to measure appended bytes from")
    Set tDate = $ZDate($Horolog, 1)
    Set tErrorsBefore = ..ErrorCount(tDate)

    Do $ClassMethod(..#PORT, "Reset")
    Do ##class(OcuPilot.Test.ProviderStub).ResetErrorLog()
    Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretProbe")
    Do $ClassMethod(..#PORT, "SetSslState", "present")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#CANARY)
    ; Armed once: the arming and the record it accumulates survive the stub resets between the
    ; legs below, which clear only the queued script and the per-call recording.
    Do ##class(OcuPilot.Test.ProviderStub).ArmErrorLog(.tArmed)
    Do $$$AssertTrue(tArmed, "the stub is armed to force a real application-error entry")
    If 'tArmed Quit

    ; Leg one: the provider refuses. The raw body reaches the log and the message reaches the
    ; envelope, so this is the leg where vendor text and OcuPilot's own text are both in play.
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(401, "{""type"":""error"",""error"":{""type"":""authentication_error"",""message"":""invalid x-api-key""}}")
    Do ..DriveAndAssert("a provider refusal")

    ; Leg two: every attempt answers a retryable status, so the attempt bound is exhausted and each
    ; attempt logs.
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(429, "{""type"":""error"",""error"":{""message"":""slow down""}}", 0)
    Do ..DriveAndAssert("an exhausted attempt bound")

    ; Leg three: the transport raises mid-flight, which is the path with an exception in it.
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.ProviderStub).QueueThrow()
    Do ..DriveAndAssert("a transport that raised mid-flight")

    ; Leg four: the shape gate refuses, which is the one refusal whose reason is about the key --
    ; so it is driven on a row whose prefix the canary does not match, with the canary itself still
    ; in play. Substituting some other value here instead would refuse a value the run does not
    ; care about, and the assertion that the refusal carries no credential material would be made
    ; about a credential that was never there.
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ..DriveAndAssert("a credential of the wrong shape", ##class(OcuPilot.Test.CatalogProbe).#LOCALKEY)

    ; Leg five: the same canary on the CREDENTIALS rung, resolved by the shipped ladder out of a
    ; real credential entry rather than by the environment probe. Without it AC6's proof would cover
    ; only the rung Story 3.2 shipped, while the rung this story added -- whose read crosses a
    ; vendor frame -- would be claimed rather than measured.
    Do ..DriveTheCredentialsRung()

    ; Leg six: the canary as a key a Test connection body carries, with nothing resolvable behind the
    ; definition's own reference, so the only copy in play is the body's.
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Test.SecretProbe).SetValue("")
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(401, "{""type"":""error"",""error"":{""type"":""authentication_error"",""message"":""invalid x-api-key""}}")
    Do ..DriveAndAssert("a provider refusal of a body key", "", "", ##class(OcuPilot.Test.CredentialFixture).Payload(..#CANARY))

    ; Legs seven and eight: the two families whose adapters write their own authentication
    ; header, so the sweep covers every ApplyAuth this instance ships rather than the canonical
    ; one alone.
    Do ..DriveTheNewFamilies()

    Set tEntries = ##class(OcuPilot.Test.ProviderStub).ErrorLogCount()
    Do $$$AssertTrue(tEntries > 0, "the run forced at least one real application-error entry, so the assertion below reads a row rather than nothing: " _ tEntries)

    Set tAppended = ..ConsoleLogSince(tOffset, tIdentity, .tLines)
    Do $$$AssertTrue(tLines > 0, "the run appended lines to the console log, so the search below reads text rather than nothing: " _ tLines _ " line(s)")
    Do $$$AssertEquals(tAppended [ ..#CANARYMARK, 0, "and no line OcuPilot wrote to the console log carries credential material")

    Set tErrorsAfter = ..ErrorCount(tDate)
    Do $$$AssertTrue(tErrorsAfter > tErrorsBefore, "the application error log grew, from " _ tErrorsBefore _ " to " _ tErrorsAfter)
    Set tChecked = ..AssertErrorEntriesAreClean(tDate)
    Do $$$AssertTrue(tChecked > 0, "and every entry the run recorded was read back in full: " _ tChecked)
}

/// <p>Legs seven and eight: drive a provider refusal on each family whose adapter writes its own
/// authentication header, over the catalog that re-adapts both shipped rows to stubs replacing the
/// transport alone. The forced entry is then raised from a stack in which that family's adapter is
/// the one serving the call, which is what extends AD-48's proof beyond the canonical family.</p>
/// <p>Each leg asserts <b>which class served it</b> and <b>that it wrote a forced entry of its
/// own</b>: a row that failed to resolve, or an endpoint host this instance cannot resolve, writes
/// no entry at all and would otherwise read as a further repetition of the environment rung's leg,
/// which the earlier legs' cumulative count cannot distinguish. The endpoint is each row's own
/// canonical one, so these legs resolve the two shipped hosts; nothing is connected to.</p>
/// <p>Each family is driven twice, because the two forced-entry legs fire on different failures: a
/// refusal reaches the transport's leg, and a mid-flight raise reaches only the stub's
/// <method>ApplyAuth</method> leg, the transport having raised before its own.</p>
/// <p>Mutation: point <parameter>OcuPilot.Test.CatalogProbeShipped.OPENAISTUB</parameter> at
/// <class>OcuPilot.Test.ProviderStub</class>, the canonical family's stub -- red on the
/// <code>openai</code> leg's served-by assertion. Mutation: have
/// <method>OcuPilot.Kernel.Provider.Gemini.RequestUrl</method> append the credential as the
/// <code>?key=</code> query parameter the wider vendor API also accepts -- that leg's forced
/// entries capture <method>OcuPilot.Kernel.Provider.Base.Attempts</method>'s URL local and the
/// variable-table assertion goes red, on that leg alone.</p>
Method DriveTheNewFamilies()
{
    Do $ClassMethod(..#PORT, "SetCatalogClass", ..#SHIPPEDCATALOG)
    For tI = 1:1:$Length(..#SHIPPEDFAMILIES, ",") {
        Set tFamily = $Piece(..#SHIPPEDFAMILIES, ",", tI)
        Set tProvider = $Piece(tFamily, ":", 1)
        Set tIdentity = $Parameter($Piece(tFamily, ":", 2), "STUBIDENTITY")
        Do $$$AssertNotEquals(tIdentity, "", "the " _ tProvider _ " row's stub declares an identity, so the served-by assertions below compare two values rather than two empty strings")
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#CANARY)
        Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(401, ..#VENDORERRORBODY)
        Set tBefore = ##class(OcuPilot.Test.ProviderStub).ErrorLogCount()
        Do ..DriveAndAssert("a provider refusal on the " _ tProvider _ " family", tProvider, "", "", 1)
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).ServedBy(), tIdentity, "the " _ tProvider _ " refusal was served by that family's own adapter, so its forced entries carry that family's stack")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).ErrorLogCount() - tBefore, ..#REFUSALENTRIES, "and that leg wrote both its forced entries -- its ApplyAuth leg and the transport's -- rather than resting on an earlier leg's: " _ tBefore _ " -> " _ ##class(OcuPilot.Test.ProviderStub).ErrorLogCount())
        Do ##class(OcuPilot.Test.ProviderStub).Reset()
        Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#CANARY)
        Do ##class(OcuPilot.Test.ProviderStub).QueueThrow()
        Set tBefore = ##class(OcuPilot.Test.ProviderStub).ErrorLogCount()
        Do ..DriveAndAssert("a transport that raised mid-flight on the " _ tProvider _ " family", tProvider, "", "", 1)
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).ServedBy(), tIdentity, "the " _ tProvider _ " mid-flight raise was served by that family's own adapter")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).ErrorLogCount() - tBefore, ..#RAISEENTRIES, "and its ApplyAuth leg wrote its entry although the transport raised before reaching its own: " _ tBefore _ " -> " _ ##class(OcuPilot.Test.ProviderStub).ErrorLogCount())
    }
    Do $ClassMethod(..#PORT, "SetCatalogClass", "")
}

/// <p>Leg five: put the canary into a real credential entry, drive a provider refusal through the
/// <b>shipped</b> ladder's <code>creds</code> rung, and remove the entry again.</p>
/// <p>The port's credential seam is set to <code>""</code> for the duration, which falls through to
/// <parameter>OcuPilot.Port.ProviderPort.SECRETCLASS</parameter>, and restored afterwards -- so the
/// resolution measured here is production's, vendor frame and all. Where the rung is not reachable
/// the leg is skipped, and the skip says so.</p>
/// <p><b>The canary is never bound to a local here.</b> It travels parameter to
/// <class>%DynamicObject</class> member to the row's property; the OREF a local does hold
/// stringifies to <code>n@%Library.DynamicObject</code>, which is what an <code>^%ETN</code> entry
/// would record of it.</p>
/// <p>Mutation: bind the resolved key to a local in
/// <method>OcuPilot.Kernel.Provider.Base.Invoke</method> on the <code>creds</code> path alone
/// (<code>If $Get(pValues("credType")) = "creds" Set tLeaked = ..ApiKey</code>) -- the
/// variable-table assertion goes red on this leg's forced entries and on no other, which is what
/// makes this leg load-bearing rather than a fifth repetition of the environment rung's.</p>
/// <p><b>A local inside <method>OcuPilot.Kernel.Secret.Ladder.Credential</method> is not a
/// falsifier</b>: that frame has unwound before the stub forces the entry, and <code>^%ETN</code>
/// captures only live stack levels. Measured on a throwaway -- the mutation ran green. The window
/// this leg actually measures is every frame still live at the moment of the failure.</p>
Method DriveTheCredentialsRung()
{
    If '##class(OcuPilot.Kernel.Secret.Ladder).CredentialsRungAvailable() {
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Secret.Ladder).Resolve("creds", "", ..#CREDSNAME), "", "the credentials rung is not reachable from " _ $Namespace _ ", so the credentials-rung leg is skipped and nothing was written")
        Quit
    }
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#CREDSNAME)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Secret.Ladder).Store(..#CREDSNAME, ##class(OcuPilot.Test.CredentialFixture).Payload(..#CANARY), "apiKey"), "the canary is put into a real credential entry")
    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do $ClassMethod(..#PORT, "SetSecretClass", "")
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(401, "{""type"":""error"",""error"":{""type"":""authentication_error"",""message"":""invalid x-api-key""}}")
    Do ..DriveAndAssert("a provider refusal on the credentials rung", "", ..#CREDSNAME)
    Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretProbe")
    Do ##class(OcuPilot.Test.CredentialFixture).Remove(..#CREDSNAME)
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#CREDSNAME), 0, "and the entry is removed again")
}

/// <p>The console log's current end, as the offset and identity a later page is asked for. Answers
/// 0 when the log could not be read at all.</p>
ClassMethod MarkConsoleLog(Output pOffset As %Integer, Output pIdentity As %String) As %Boolean
{
    Set pOffset = 0
    Set pIdentity = ""
    Set tSC = $ClassMethod(..#LOGPORT, "Page", "messages", "", "", "", .tResult, .tStatus, .tFault)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit 0
    Set pOffset = tResult.offset
    Set pIdentity = tResult.identity
    Quit 1
}

/// <p>Everything the console log has gained since the mark, as one string, with the number of lines
/// in <var>pLines</var>.</p>
/// <p>Read through <class>OcuPilot.Port.LogSourcePort</class>'s own pager rather than off the disk,
/// so what this searches is exactly what OcuPilot's own log screen would show (AD-46) -- which is
/// the loop AC6 exists to break.</p>
ClassMethod ConsoleLogSince(pOffset As %Integer, pIdentity As %String, Output pLines As %Integer) As %String
{
    Set pLines = 0
    Set tText = ""
    Set tOffset = pOffset
    For tPage = 1:1:..#MAXPAGES {
        Set tSC = $ClassMethod(..#LOGPORT, "Page", "messages", tOffset, ..#PAGEBYTES, pIdentity, .tResult, .tStatus, .tFault)
        If $$$ISERR(tSC) || (tStatus '= 200) Quit
        Set tIterator = tResult.lines.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tLine) {
            Set pLines = pLines + 1
            Set tText = tText _ tLine _ $Char(10)
        }
        If 'tResult.truncated Quit
        If tResult.offset = tOffset Quit
        Set tOffset = tResult.offset
    }
    Quit tText
}

/// <p>How many application errors this namespace holds for <var>pDate</var>, or <code>0</code> when
/// the level cannot be read.</p>
ClassMethod ErrorCount(pDate As %String) As %Integer
{
    Set tSC = $ClassMethod(..#LOGPORT, "Errors", "list", $Namespace, pDate, "", "", .tResult, .tStatus, .tFault)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit 0
    Quit tResult.rows.%Size()
}

/// <p>Read every entry <method>OcuPilot.Test.ProviderStub.ForceErrorLog</method> recorded, in full
/// -- its logged expressions, its stack and <b>every local variable at every stack level</b> -- and
/// assert none of it carries credential material. Answers how many entries were actually read, so
/// an assertion over nothing is visible as such.</p>
Method AssertErrorEntriesAreClean(pDate As %String) As %Integer
{
    Set tChecked = 0
    For tI = 1:1:##class(OcuPilot.Test.ProviderStub).ErrorLogCount() {
        Set tEntry = ##class(OcuPilot.Test.ProviderStub).ErrorLogEntry(tI)
        If '$ListValid(tEntry) || ($ListLength(tEntry) < 2) Continue
        Set tSC = $ClassMethod(..#LOGPORT, "Errors", "detail", $Namespace, $ZDate($List(tEntry, 1), 1), $List(tEntry, 2), "", .tResult, .tStatus, .tFault)
        Do $$$AssertEquals(tStatus, 200, "entry #" _ $List(tEntry, 2) _ " reads back at the detail level")
        If tStatus '= 200 Continue
        Set tChecked = tChecked + 1
        Do $$$AssertTrue(tResult.variables.%Size() > 0, "entry #" _ $List(tEntry, 2) _ " captured a variable table to search: " _ tResult.variables.%Size() _ " row(s)")
        Do $$$AssertEquals(tResult.variables.%ToJSON() [ ..#CANARYMARK, 0, "and no local at any stack level in entry #" _ $List(tEntry, 2) _ " carries credential material")
        Do $$$AssertEquals(tResult.expressions.%ToJSON() [ ..#CANARYMARK, 0, "nor any logged expression in entry #" _ $List(tEntry, 2))
        Do $$$AssertEquals(tResult.stack.%ToJSON() [ ..#CANARYMARK, 0, "nor any stack frame in entry #" _ $List(tEntry, 2))
    }
    Quit tChecked
}

}
