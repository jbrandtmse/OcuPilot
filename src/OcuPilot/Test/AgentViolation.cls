/// <p>Story 3.5's server half, in three concerns: the violation shape AD-39 now fixes
/// (<code>{field, code, reason}</code>), the credential-name length rule DW-344 asked for, and the
/// provider catalog route the Definition form cascades from.</p>
/// <p>Every definition this class creates is named with <parameter>PROBEPREFIX</parameter> and
/// removed in <method>OnAfterOneTest</method>, which then asserts none survives -- the discipline
/// <class>OcuPilot.Test.AgentWire</class> established, so a run on the development instance leaves
/// it as it found it.</p>
Class OcuPilot.Test.AgentViolation Extends %UnitTest.TestCase
{

/// <p>The prefix every definition this class creates is named with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe definitions this class created are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no " _ ..#PROBEPREFIX _ " definition survives this class")
    Quit $$$OK
}

/// <p>One request to the agent surface as the suite's own credentials.</p>
ClassMethod Call(pMethod As %String, pSuffix As %String, pBody As %String, Output pStatus As %Integer, Output pBodyText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ pSuffix, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .pHeaders, pBody, "application/json")
}

/// <p><b>Every field-level violation code carries a published sentence</b> (AD-39), and an
/// undeclared code carries none.</p>
/// <p>This is the assertion that makes "the refusal copy is written once on the server" checkable:
/// a code added to the vocabulary with no sentence behind it reaches a form as a blank line under
/// the field, which looks exactly like a field with nothing wrong with it.</p>
/// <p>Mutation: delete one <code>REASON...</code> parameter's arm from
/// <method>OcuPilot.Api.Error.ReasonForViolation</method> -- this goes red naming that code.</p>
Method TestEveryViolationCodeHasAPublishedSentence()
{
    Set tCodes = ##class(OcuPilot.Api.Error).ViolationCodes()
    Do $$$AssertEquals($ListLength(tCodes), 29, "the vocabulary holds twenty-nine field-level codes; adding one is a deliberate edit in OcuPilot.Api.Error")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " carries a sentence")
        Do $$$AssertTrue($Length(tReason) > 10, tCode _ "'s sentence says something: '" _ tReason _ "'")
        Do $$$AssertTrue(tReason '[ "!", tCode _ "'s sentence carries no exclamation mark (Voice and Tone)")
    }
    Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation("AGENT.NO.SUCH.CODE"), "", "and a code the vocabulary does not hold carries none, which is how a caller tells 'no sentence' from 'an empty one'")
}

/// <p><b>The vocabulary is every <code>AGENT*</code> code the class declares</b>, less the four
/// that are envelope-level and the four restraint codes
/// <method>OcuPilot.Kernel.Restraint.Verdict</method> answers with, and
/// <method>OcuPilot.Api.Error.ViolationCodes</method> holds exactly that set.</p>
/// <p>Without this, the sentence check above is a roster checking itself: its population is
/// <method>ViolationCodes</method>, so a field-level code declared as a parameter and emitted by a
/// rule but never added to that hand-written list is in neither the population nor the resolver,
/// and every assertion passes while the form renders a blank line under the field it names. The
/// codes are read from the writer's own parameter list here, the way
/// <method>OcuPilot.Test.Envelope.TestEveryDeclaredCodeMatchesTheFormat</method> reads them.</p>
/// <p>Mutation: add a <code>Parameter AGENTPROBERANGE = "AGENT.PROBE.RANGE"</code> to
/// <class>OcuPilot.Api.Error</class> and nothing else -- this goes red naming it, where the
/// sentence check above stays green.</p>
Method TestViolationCodesHoldsEveryDeclaredFieldLevelCode()
{
    ; The AGENT codes that do not land on a field: four that ride on the envelope, and the four
    ; restraint codes, whose sentences live in ReasonForRestraint and are asserted by
    ; OcuPilot.Test.Restraint. Named here, because "which codes are field-level" is the one fact
    ; this check cannot derive.
    Set tEnvelope = $ListBuild("AGENTVALIDATION", "AGENTNOTFOUND", "AGENTBADBODY", "AGENTHOLDNOTFOUND", "AGENTREADONLYENFORCED", "AGENTREADONLYDEFINITION", "AGENTKILLSWITCHGLOBAL", "AGENTKILLSWITCHUSER")
    Set tDeclared = ##class(OcuPilot.Api.Error).ViolationCodes()
    Set tFound = 0
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.CompiledParameter WHERE parent = ?", "OcuPilot.Api.Error")
    While tRS.%Next() {
        Set tName = tRS.%Get("Name")
        If $Extract(tName, 1, 5) '= "AGENT" Continue
        If $ListFind(tEnvelope, tName) Continue
        Set tCode = $Parameter("OcuPilot.Api.Error", tName)
        Set tFound = tFound + 1
        Do $$$AssertTrue($ListFind(tDeclared, tCode) > 0, "field-level code '" _ tName _ "' = '" _ tCode _ "' is in ViolationCodes(), so the sentence check reaches it")
    }
    ; A sweep that found nothing would pass every row above having tested nothing.
    Do $$$AssertTrue(tFound >= 29, "the sweep read the declared parameters rather than an empty roster (found " _ tFound _ ")")
    Do $$$AssertEquals($ListLength(tDeclared), tFound, "and ViolationCodes() holds no code the class does not declare")
}

/// <p><b>The violation the wire carries is <code>{field, code, reason}</code>, in that order</b>,
/// and the reason is the published sentence for that code.</p>
/// <p>Asserted over HTTP rather than on <method>OcuPilot.Kernel.AgentRules.ViolationsJson</method>
/// alone, because the claim is about what a form receives from the shipped router.</p>
/// <p>Mutation: drop the <code>reason</code> key from
/// <method>OcuPilot.Kernel.AgentRules.ViolationsJson</method> -- this goes red on the key roster
/// and on the sentence.</p>
Method TestARefusedCreateCarriesTheFieldTheCodeAndTheSentence()
{
    Set tSC = ..Call("POST", "/agent/definitions", "{""name"":""""}", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the create request completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused as a validation failure: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "with a JSON content type: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.code, "AGENT.VALIDATION", "under the one envelope code every field-level refusal arrives with")
    Do $$$AssertTrue($IsObject(tAnswer.detail), "and a detail object")
    If '$IsObject(tAnswer.detail) Quit
    Set tFirst = tAnswer.detail.violations.%Get(0)
    Do $$$AssertTrue($IsObject(tFirst), "carrying at least one violation: " _ tAnswer.detail.violations.%ToJSON())
    If '$IsObject(tFirst) Quit
    Set tKeys = ""
    Set tIterator = tFirst.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Do $$$AssertEquals(tKeys, "field,code,reason", "the three keys AD-39 fixes, in that order")
    Do $$$AssertEquals(tFirst.field, "name", "the field the refusal lands on")
    Do $$$AssertEquals(tFirst.code, "AGENT.NAME.REQUIRED", "the stable machine code a tool result renders")
    Do $$$AssertEquals(tFirst.reason, ##class(OcuPilot.Api.Error).#REASONAGENTNAMEREQUIRED, "and the published sentence a screen renders on that field")
}

/// <p><b>DW-344</b> -- a <code>credentialName</code> longer than the credential store accepts is
/// refused 422 on its own field, before any store is attempted, where it used to reach the store
/// and fail there with a 500 naming nothing.</p>
/// <p>The violation's sentence states the bound, which the rule appends from the one place the
/// number is declared.</p>
/// <p>Mutation: remove the length arm from
/// <method>OcuPilot.Kernel.AgentRules.Validate</method> -- this goes red, the create answering 201
/// or the store answering 500 instead of 422.</p>
Method TestAnOverLongCredentialNameIsRefusedOnItsOwnField()
{
    Set tLimit = ##class(OcuPilot.Kernel.AgentRules).#MAXCREDENTIALNAMELENGTH
    Set tName = ..#PROBEPREFIX _ "Long"
    Set tCredential = ""
    For tI = 1:1:(tLimit + 1) Set tCredential = tCredential _ "a"
    Do $$$AssertEquals($Length(tCredential), tLimit + 1, "the credential name is one character past the bound")

    Set tBodyText = "{""name"":""" _ tName _ """,""provider"":""anthropic"",""credType"":""creds"",""credentialName"":""" _ tCredential _ """}"
    Set tSC = ..Call("POST", "/agent/definitions", tBodyText, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the create request completes")
    Do $$$AssertEquals(tStatus, 422, "and is refused rather than reaching the credential store: " _ tBody)
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentWire).ViolationsOf(tBody), ##class(OcuPilot.Test.AgentWire).ViolationsText($ListBuild($ListBuild("credentialName", "AGENT.CREDNAME.LENGTH", ##class(OcuPilot.Api.Error).#REASONAGENTCREDNAMELENGTH _ ": use " _ tLimit _ " characters or fewer."))), "with one violation on credentialName whose sentence states the bound")
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentFixture).ProbeCount(), 0, "and the refused create wrote nothing")
}

/// <p>A <code>credentialName</code> of exactly the bound is accepted, so the rule refuses "longer
/// than" rather than "as long as".</p>
Method TestACredentialNameOfExactlyTheBoundIsAccepted()
{
    Set tLimit = ##class(OcuPilot.Kernel.AgentRules).#MAXCREDENTIALNAMELENGTH
    Set tName = ..#PROBEPREFIX _ "Exact"
    Set tCredential = ""
    For tI = 1:1:tLimit Set tCredential = tCredential _ "b"
    Set tBodyText = "{""name"":""" _ tName _ """,""provider"":""anthropic"",""credType"":""creds"",""credentialName"":""" _ tCredential _ """}"
    Set tSC = ..Call("POST", "/agent/definitions", tBodyText, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the create request completes")
    Do $$$AssertEquals(tStatus, 201, "and a name of exactly the bound is accepted: " _ tBody)
}

/// <p><b>The declared bound is the vendor property's own</b>, read from
/// <class>%Dictionary.CompiledProperty</class> rather than recalled.</p>
/// <p><code>Ens.Config.Credentials.SystemName</code> is <code>%String</code> with no
/// <code>MAXLEN</code> override, so <class>%Library.String</class>'s default applies. Reading it
/// back here is what makes a vendor limit that moves a red test rather than a silent drift
/// (DW-344).</p>
/// <p>Skipped with a named reason on an instance with no interoperability classes, where the
/// property does not exist to read.</p>
Method TestTheCredentialNameBoundIsTheVendorPropertysOwn()
{
    Set tProperty = ##class(%Dictionary.CompiledProperty).%OpenId("Ens.Config.Credentials||SystemName")
    If '$IsObject(tProperty) {
        Do $$$AssertTrue(1, "skipped: this instance carries no Ens.Config.Credentials, so the vendor property cannot be read")
        Quit
    }
    Set tMaxLen = ""
    Set tParameters = tProperty.Parameters
    If $IsObject(tParameters) Set tMaxLen = tParameters.GetAt("MAXLEN")
    If tMaxLen = "" Set tMaxLen = $Parameter("%Library.String", "MAXLEN")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.AgentRules).#MAXCREDENTIALNAMELENGTH, +tMaxLen, "the declared bound is the credential entry's own SystemName length, measured rather than recalled")
}

/// <p><b>The provider catalog route</b> -- status, content type and body shape, over HTTP
/// (Conventions, Tests).</p>
/// <p>It serves every column the Definition form cascades from, plus the derived
/// <code>keyShapeReason</code>, and <b>not</b> the two columns that are the table's own
/// machinery: <code>adapterClass</code> names a class on this instance and
/// <code>authVersion</code> is a wire detail of the call OcuPilot makes.</p>
/// <p>Mutation: add <code>adapterClass</code> to
/// <method>OcuPilot.Api.Definitions.ProviderColumns</method> -- this goes red on the key
/// roster.</p>
Method TestTheProviderCatalogRouteServesTheCascadeColumns()
{
    Set tSC = ..Call("GET", "/agent/providers", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the providers request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers 200: " _ tBody)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "with a JSON content type: " _ $Get(tHeaders("CONTENT-TYPE")))
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue($IsObject(tAnswer.providers), "carrying a providers array")
    If '$IsObject(tAnswer.providers) Quit
    Do $$$AssertEquals(tAnswer.providers.%Size(), $ListLength(##class(OcuPilot.Kernel.Provider.Catalog).Keys()), "one row per catalog key")
    Set tRow = tAnswer.providers.%Get(0)
    Do $$$AssertTrue($IsObject(tRow), "the first row is an object")
    If '$IsObject(tRow) Quit
    Set tKeys = ""
    Set tIterator = tRow.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Do $$$AssertEquals(tKeys, "key,label,defaultModel,modelSuggestions,defaultEndpoint,endpointRequired,canonicalMaxTokens,canonicalTemperature,defaultEnvVarName,defaultCredentialName,keyPrefix,allowsLocal,keyShapeReason", "the twelve cascade columns and the derived sentence, and neither adapterClass nor authVersion")
    Do $$$AssertEquals(tRow.key, "anthropic", "the shipped row")
    Do $$$AssertEquals(tRow.%GetTypeOf("endpointRequired"), "boolean", "a flag arrives as a JSON boolean")
    Do $$$AssertEquals(tRow.%GetTypeOf("canonicalMaxTokens"), "number", "and a count as a JSON number")
    Do $$$AssertTrue($IsObject(tRow.modelSuggestions), "the model suggestions arrive as an array")
    Do $$$AssertTrue(tRow.keyShapeReason [ tRow.keyPrefix, "and the key-shape sentence states the row's own prefix: " _ tRow.keyShapeReason)
}

/// <p>The providers route is declared in the shipped router, and its response carries no value
/// that could be a key (AD-35). <code>keyPrefix</code> is a table entry, which is why the refusal
/// may state it.</p>
Method TestTheProvidersRouteIsDeclaredAndCarriesNoSecret()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Api.Router", "UrlMap", , .tOpenSC)
    Do $$$AssertTrue($IsObject(tXData), "the router's UrlMap is readable")
    If '$IsObject(tXData) Quit
    Do tXData.Data.Rewind()
    Set tMap = tXData.Data.Read(32000)
    Do $$$AssertTrue(tMap [ "<Route Url=""/agent/providers"" Method=""GET"" Call=""AgentProviders""/>", "the router declares the providers route")

    Set tSC = ..Call("GET", "/agent/providers", "", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the providers request completes")
    Do $$$AssertTrue(tBody '[ "adapterClass", "and the body names no adapter class: " _ tBody)
    Do $$$AssertTrue(tBody '[ "authVersion", "and no wire version")
}

}
