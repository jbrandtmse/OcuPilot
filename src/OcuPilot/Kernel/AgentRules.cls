/// <p>The rules that keep an agent definition honest: the eleven harvested input rules plus the
/// two OcuPilot's own acceptance criteria force, applied in one pass that <b>accumulates every
/// violation</b> rather than stopping at the first.</p>
/// <p>One round trip is the requirement, not a nicety: an operator filling in a form is told
/// everything that is wrong with it at once. So no method here quits early on a violation, and
/// <class>OcuPilot.Test.AgentRules</class> pins that with a body breaking four rules at once.</p>
/// <p>Each violation is <code>{field, code}</code> -- the field it lands on and a stable machine
/// code declared in <class>OcuPilot.Api.Error</class>, never a sentence. EXPERIENCE.md's Fixed
/// strings table publishes no copy for any validation rule; what it publishes is the mechanism,
/// "server rules land on the field they name", with the wording left to the field. A sentence
/// returned from here would ship as product copy no gate verifies, so Story 3.5 adds the table
/// rows and the client keys together.</p>
/// <p><b>Not under <package>OcuPilot.Kernel.State</package></b>: that package may not name
/// <class>OcuPilot.Api.Error</class>, and this class needs its code vocabulary. It sits beside
/// <class>OcuPilot.Kernel.Fault</class>, which makes the same reference for the same reason.</p>
/// <p><b>Values travel as a ByRef array</b> subscripted by the client-facing field name --
/// <code>name</code>, <code>provider</code>, <code>model</code>, <code>endpointUrl</code>,
/// <code>credType</code>, <code>envVarName</code>, <code>credentialName</code>,
/// <code>maxTokens</code>, <code>temperature</code>, <code>maxIterationsPerTurn</code>,
/// <code>systemPromptOverride</code>, <code>readOnly</code>, <code>retentionDays</code>,
/// <code>enabled</code>, <code>connectionVerified</code> -- so a violation names the key the
/// caller sent and the same array can be handed to the state class.</p>
Class OcuPilot.Kernel.AgentRules Extends %RegisteredObject
{

/// <p>Credential type: the secret comes from an environment variable.</p>
Parameter CREDTYPEENV = "env";

/// <p>Credential type: the secret comes from a credential entry. That rung additionally needs an
/// interoperability-enabled namespace, which is Story 3.3's concern -- this story stores the
/// choice and tests no namespace.</p>
Parameter CREDTYPECREDS = "creds";

/// <p>The longest name a definition may carry, matching the property's own
/// <code>MAXLEN</code>.</p>
Parameter MAXNAMELENGTH As %Integer = 64;

/// <p>The longest system-prompt override a definition may carry (harvested rule 9).</p>
Parameter MAXPROMPTLENGTH As %Integer = 8192;

/// <p>Apply the XOR credential invariant: whichever of <code>envVarName</code> /
/// <code>credentialName</code> the credential type did not select is cleared to <code>""</code>,
/// so the ladder Story 3.3 builds is deterministic.</p>
/// <p><b>This normalizes; it does not reject.</b> Sending both is never an error -- one is
/// cleared. An unrecognized credential type clears neither, because there is nothing to select
/// with and rule 5 is what refuses it.</p>
/// <p><b>The order is load-bearing.</b> Normalization runs before validation, so
/// <code>credType</code> <code>env</code> with an empty <code>envVarName</code> and a populated
/// <code>credentialName</code> clears the credential name first and then reports
/// <code>AGENT.ENVVAR.REQUIRED</code>, rather than silently accepting a credential the ladder
/// would never read.</p>
ClassMethod Normalize(ByRef pValues)
{
    Set tCredType = $Get(pValues("credType"))
    If tCredType = ..#CREDTYPEENV {
        Set pValues("credentialName") = ""
    } ElseIf tCredType = ..#CREDTYPECREDS {
        Set pValues("envVarName") = ""
    }
}

/// <p>Every violation <var>pValues</var> commits, appended to <var>pViolations</var> in declared
/// rule order as <code>pViolations(n) = $ListBuild(field, code)</code>; returns how many.</p>
/// <p><var>pExistingId</var> is the definition being edited, so the duplicate-name rule does not
/// report a definition as a duplicate of itself; <code>""</code> on a create.</p>
/// <p>The rules, in the order they are reported, numbered as the eleven harvested rules the whole
/// tree numbers them by -- so two checks carry rule 1, and the two OcuPilot's own carry the
/// decision that forced them instead of a number:</p>
/// <ul>
/// <li><b>Rule 1</b> -- <code>name</code> present and at most
/// <parameter>MAXNAMELENGTH</parameter>.</li>
/// <li><b>Rule 1</b> -- <code>name</code> held by no other definition.</li>
/// <li><b>Rule 2</b> -- <code>provider</code> a key
/// <class>OcuPilot.Kernel.Provider.Catalog</class> declares.</li>
/// <li><b>Rule 3</b> -- <code>maxTokens</code> a whole number 1-32000.</li>
/// <li><b>Rule 4</b> -- <code>temperature</code> a number 0-2.</li>
/// <li><b>Rule 5</b> -- <code>credType</code> one of the two declared.</li>
/// <li><b>Rule 6</b> -- <code>env</code> implies a non-empty <code>envVarName</code>, after
/// normalization.</li>
/// <li><b>Rule 7</b> -- <code>creds</code> implies a non-empty <code>credentialName</code>, after
/// normalization.</li>
/// <li><b>Rule 8</b> -- a provider whose catalog row says <code>endpointRequired</code> implies a
/// non-empty <code>endpointUrl</code> -- <b>provider-name-free</b>, so a family that needs one is
/// a catalog row rather than a branch here.</li>
/// <li><b>AD-42</b> -- <code>endpointUrl</code>, when present, is absolute HTTPS.
/// <b>OcuPilot's own</b> rather than harvested; AD-42's local exception is Story 3.2's, and at
/// this floor HTTPS is the only accepted scheme.</li>
/// <li><b>Rule 9</b> -- <code>systemPromptOverride</code> at most
/// <parameter>MAXPROMPTLENGTH</parameter>.</li>
/// <li><b>Rule 10</b> -- <code>retentionDays</code> digits only, 1-365.</li>
/// <li><b>Rule 11</b> -- <code>maxIterationsPerTurn</code> a whole number 1-100.</li>
/// <li><b>AC5</b> -- <code>enabled</code> may not be turned on while the definition is
/// unverified. <b>OcuPilot's own</b> -- and Story 3.4's reason to exist, since Test connection is
/// the only thing that clears it.</li>
/// </ul>
ClassMethod Validate(ByRef pValues, pExistingId As %String = "", Output pViolations) As %Integer
{
    Kill pViolations
    Set tName = $Get(pValues("name"))
    If (tName = "") || ($Length(tName) > ..#MAXNAMELENGTH) {
        Do ..Add(.pViolations, "name", ##class(OcuPilot.Api.Error).#AGENTNAMEREQUIRED)
    } ElseIf ..NameTaken(tName, pExistingId) {
        Do ..Add(.pViolations, "name", ##class(OcuPilot.Api.Error).#AGENTNAMEDUPLICATE)
    }

    If '..ProviderKnown($Get(pValues("provider"))) {
        Do ..Add(.pViolations, "provider", ##class(OcuPilot.Api.Error).#AGENTPROVIDERUNKNOWN)
    }

    If '..IsWholeNumberInRange($Get(pValues("maxTokens")), 1, 32000) {
        Do ..Add(.pViolations, "maxTokens", ##class(OcuPilot.Api.Error).#AGENTMAXTOKENSRANGE)
    }

    If '..IsNumberInRange($Get(pValues("temperature")), 0, 2) {
        Do ..Add(.pViolations, "temperature", ##class(OcuPilot.Api.Error).#AGENTTEMPERATURERANGE)
    }

    Set tCredType = $Get(pValues("credType"))
    If (tCredType '= ..#CREDTYPEENV) && (tCredType '= ..#CREDTYPECREDS) {
        Do ..Add(.pViolations, "credType", ##class(OcuPilot.Api.Error).#AGENTCREDTYPEUNKNOWN)
    }
    If (tCredType = ..#CREDTYPEENV) && ($Get(pValues("envVarName")) = "") {
        Do ..Add(.pViolations, "envVarName", ##class(OcuPilot.Api.Error).#AGENTENVVARREQUIRED)
    }
    If (tCredType = ..#CREDTYPECREDS) && ($Get(pValues("credentialName")) = "") {
        Do ..Add(.pViolations, "credentialName", ##class(OcuPilot.Api.Error).#AGENTCREDNAMEREQUIRED)
    }

    Set tEndpoint = $Get(pValues("endpointUrl"))
    If (tEndpoint = "") && ..EndpointRequired($Get(pValues("provider"))) {
        Do ..Add(.pViolations, "endpointUrl", ##class(OcuPilot.Api.Error).#AGENTENDPOINTREQUIRED)
    }
    If (tEndpoint '= "") && '..IsAbsoluteHttps(tEndpoint) {
        Do ..Add(.pViolations, "endpointUrl", ##class(OcuPilot.Api.Error).#AGENTENDPOINTSCHEME)
    }

    If $Length($Get(pValues("systemPromptOverride"))) > ..#MAXPROMPTLENGTH {
        Do ..Add(.pViolations, "systemPromptOverride", ##class(OcuPilot.Api.Error).#AGENTSYSTEMPROMPTLENGTH)
    }

    If '..IsWholeNumberInRange($Get(pValues("retentionDays")), 1, 365) {
        Do ..Add(.pViolations, "retentionDays", ##class(OcuPilot.Api.Error).#AGENTRETENTIONRANGE)
    }

    If '..IsWholeNumberInRange($Get(pValues("maxIterationsPerTurn")), 1, 100) {
        Do ..Add(.pViolations, "maxIterationsPerTurn", ##class(OcuPilot.Api.Error).#AGENTITERATIONSRANGE)
    }

    If +$Get(pValues("enabled")) && '+$Get(pValues("connectionVerified")) {
        Do ..Add(.pViolations, "enabled", ##class(OcuPilot.Api.Error).#AGENTENABLEUNVERIFIED)
    }

    Quit +$Get(pViolations)
}

/// <p>Append one <code>{field, code}</code> violation.</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

/// <p>Whether another definition already holds <var>pName</var>. <var>pExistingId</var> is
/// excluded, so an edit that leaves the name alone is not a duplicate of itself.</p>
/// <p>A read failure answers <b>no</b>: the unique index refuses the save regardless, so the
/// caller gets <code>#5808</code> rather than a wrongly-reported duplicate.</p>
ClassMethod NameTaken(pName As %String, pExistingId As %String) As %Boolean
{
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedByName(pName, .tId)
    If $$$ISERR(tSC) Quit 0
    If tId = "" Quit 0
    Quit tId '= pExistingId
}

/// <p>The catalog class this validator reads its vocabulary from. <b>Overridable</b> so a test
/// can drive rule 8 against a second provider row at a floor whose shipped table holds one;
/// production never overrides it.</p>
ClassMethod CatalogClass() As %String
{
    Quit "OcuPilot.Kernel.Provider.Catalog"
}

/// <p>Whether <var>pProvider</var> is a key the catalog declares.</p>
ClassMethod ProviderKnown(pProvider As %String) As %Boolean
{
    Quit $ClassMethod(..CatalogClass(), "IsKnown", pProvider)
}

/// <p>Whether <var>pProvider</var>'s catalog row requires an endpoint. An unknown provider
/// requires none -- rule 2 already refuses it, and reporting a second violation for the same
/// mistake would name a field the caller never got wrong.</p>
ClassMethod EndpointRequired(pProvider As %String) As %Boolean
{
    If '$ClassMethod(..CatalogClass(), "Row", pProvider, .tRow) Quit 0
    Quit +tRow.endpointRequired
}

/// <p>Whether <var>pValue</var> is an absolute <code>https://</code> URL with a host.</p>
/// <p>Matched on the scheme rather than parsed: at this floor the only question is whether the
/// value is absolute and encrypted. Story 3.2 adds AD-42's remaining endpoint rules -- the local
/// exception, the marked-local flag and the resolved-address check -- and this stays the
/// scheme half of them.</p>
/// <p><b>The scheme is matched case-insensitively</b>, because a URI scheme is: RFC 3986 defines
/// it as case-insensitive and <code>HTTPS://host/v1</code> is the same encrypted endpoint as
/// <code>https://host/v1</code>. Spelled as character classes rather than folded, so the stored
/// value is the one the operator sent.</p>
ClassMethod IsAbsoluteHttps(pValue As %String) As %Boolean
{
    Quit $Match(pValue, "^[Hh][Tt][Tt][Pp][Ss]://[^/?#\s]+(/[^\s]*)?$")
}

/// <p>Whether <var>pValue</var> is a whole number, written in digits alone, between
/// <var>pLow</var> and <var>pHigh</var> inclusive.</p>
/// <p>Digits alone, deliberately: harvested rule 10 states the <code>^[0-9]+$</code> shape
/// outright, and it is the right shape for all three counters. Without it <code>"12abc"</code>
/// reaches the range test as <code>12</code>, because ObjectScript's unary <code>+</code> reads
/// a numeric prefix and discards the rest.</p>
ClassMethod IsWholeNumberInRange(pValue As %String, pLow As %Integer, pHigh As %Integer) As %Boolean
{
    If '$Match(pValue, "^[0-9]+$") Quit 0
    If +pValue < pLow Quit 0
    If +pValue > pHigh Quit 0
    Quit 1
}

/// <p>Whether <var>pValue</var> is a number, possibly fractional, between <var>pLow</var> and
/// <var>pHigh</var> inclusive. Temperature is the one tunable that is not a whole number.</p>
/// <p><b>The leading zero is optional, and that is not cosmetic.</b> ObjectScript canonicalizes
/// <code>0.7</code> to <code>.7</code>, and a JSON <code>0.7</code> read out of a
/// <class>%DynamicObject</class> arrives in that form -- so a pattern requiring a digit before the
/// point refuses a temperature every provider accepts. Caught by
/// <class>OcuPilot.Test.AgentRules</class>, which asserts both spellings.</p>
ClassMethod IsNumberInRange(pValue As %String, pLow As %Numeric, pHigh As %Numeric) As %Boolean
{
    If '$Match(pValue, "^([0-9]+(\.[0-9]+)?|\.[0-9]+)$") Quit 0
    If +pValue < pLow Quit 0
    If +pValue > pHigh Quit 0
    Quit 1
}

/// <p>The violations as the <code>%DynamicArray</code> the envelope's <code>detail</code>
/// carries: one <code>{field, code}</code> object per entry, in the order they were
/// reported.</p>
ClassMethod ViolationsJson(ByRef pViolations) As %DynamicArray
{
    Set tArray = []
    For tI = 1:1:+$Get(pViolations) {
        Set tEntry = {}
        Do tEntry.%Set("field", $List(pViolations(tI), 1))
        Do tEntry.%Set("code", $List(pViolations(tI), 2), "string")
        Do tArray.%Push(tEntry)
    }
    Quit tArray
}

}
