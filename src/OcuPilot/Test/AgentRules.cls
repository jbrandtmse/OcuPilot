/// <p>AC2 and AC3 -- the eleven harvested rules and the two OcuPilot's own that
/// <class>OcuPilot.Kernel.AgentRules</class> applies, one failing case for each of the fourteen
/// violation codes they report between them, plus the accumulation the acceptance criterion is
/// actually about and the XOR credential invariant in both directions.</p>
/// <p><b>A rule with no failing case is not enforced, it is merely written</b>, so every rule here
/// has one -- including rule 8, whose shipped catalog row does not require an endpoint at the
/// one-provider Release 1 floor and which is therefore driven through
/// <class>OcuPilot.Test.AgentRulesProbe</class> against a second row that does.</p>
/// <p><b>The sound control matters as much as the refusals.</b> Without
/// <method>TestASoundSubmissionYieldsNoViolations</method>, a validator that refused everything
/// would pass every other method in this class.</p>
/// <p>Creates one definition, for the duplicate-name rule, and removes it in
/// <method>OnAfterOneTest</method>, which then asserts no <code>OcuPilotProbeAgent</code> row
/// survives -- instance state a test leaves behind becomes the next story's mystery.</p>
Class OcuPilot.Test.AgentRules Extends %UnitTest.TestCase
{

/// <p>The prefix every definition this class creates is named with, so teardown can assert the
/// residue is gone by name rather than by remembering ids.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>Remove every definition this class created and assert none survives.</p>
Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe definitions this class created are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no " _ ..#PROBEPREFIX _ " definition survives this class")
    Quit $$$OK
}

/// <p>A submission every rule accepts: the shape each method below breaks exactly one field
/// of.</p>
ClassMethod SoundValues(pName As %String, Output pValues)
{
    Kill pValues
    Set pValues("name") = pName
    Set pValues("provider") = "anthropic"
    Set pValues("model") = "claude-opus-5"
    Set pValues("endpointUrl") = "https://api.anthropic.com/v1/messages"
    Set pValues("credType") = "env"
    Set pValues("envVarName") = "ANTHROPIC_API_KEY"
    Set pValues("credentialName") = ""
    Set pValues("maxTokens") = 32000
    Set pValues("temperature") = 0
    Set pValues("maxIterationsPerTurn") = 10
    Set pValues("systemPromptOverride") = ""
    Set pValues("readOnly") = 1
    Set pValues("retentionDays") = 30
    Set pValues("enabled") = 0
    Set pValues("connectionVerified") = 0
}

/// <p>Validate <var>pValues</var> and assert the outcome is exactly one violation, on
/// <var>pField</var>, carrying <var>pCode</var>. A single-violation assertion rather than a
/// "contains" one, so a method that broke a second rule by accident is caught here rather than
/// read as coverage of the rule it names.</p>
Method AssertOneViolation(ByRef pValues, pField As %String, pCode As %String, pWhat As %String)
{
    Set tCount = ##class(OcuPilot.Kernel.AgentRules).Validate(.pValues, "", .tViolations)
    Do $$$AssertEquals(tCount, 1, pWhat _ ": exactly one violation (" _ ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.tViolations).%ToJSON() _ ")")
    If tCount '= 1 Quit
    Do $$$AssertEquals($List(tViolations(1), 1), pField, pWhat _ ": on the field " _ pField)
    Do $$$AssertEquals($List(tViolations(1), 2), pCode, pWhat _ ": with the code " _ pCode)
}

/// <p>The control: a sound submission is accepted. Every refusal below means something only
/// because this one passes.</p>
Method TestASoundSubmissionYieldsNoViolations()
{
    Do ..SoundValues(..#PROBEPREFIX _ "Sound", .tValues)
    Do ##class(OcuPilot.Kernel.AgentRules).Normalize(.tValues)
    Set tCount = ##class(OcuPilot.Kernel.AgentRules).Validate(.tValues, "", .tViolations)
    Do $$$AssertEquals(tCount, 0, "a sound submission yields no violations (" _ ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.tViolations).%ToJSON() _ ")")
}

/// <p>Rule 1 -- a definition needs a name of one to sixty-four characters.</p>
Method TestAnEmptyOrOverlongNameIsRefused()
{
    Do ..SoundValues("", .tValues)
    Do ..AssertOneViolation(.tValues, "name", ##class(OcuPilot.Api.Error).#AGENTNAMEREQUIRED, "an empty name")

    Do ..SoundValues("Overlong", .tOverlong)
    Set tOverlong("name") = $Translate($Justify("", 65), " ", "n")
    Do ..AssertOneViolation(.tOverlong, "name", ##class(OcuPilot.Api.Error).#AGENTNAMEREQUIRED, "a sixty-five character name")
}

/// <p>Rule 1 -- a name another definition already holds is refused, and the same name on the
/// definition that holds it is not: an edit that leaves the name alone is not a duplicate of
/// itself.</p>
/// <p>Matched the way the unique index matches, which is case-insensitively, so a name differing
/// only in case is refused here rather than at the save.</p>
Method TestADuplicateNameIsRefusedButNotAgainstItself()
{
    Set tName = ..#PROBEPREFIX _ "Dup"
    Set tSC = ##class(OcuPilot.Test.AgentFixture).CreateDefinition(tName, 0, 0, .tRow)
    Do $$$AssertStatusOK(tSC, "a definition to collide with is created")
    If $$$ISERR(tSC) Quit
    Set tId = tRow.%Id()

    Do ..SoundValues(tName, .tValues)
    Do ..AssertOneViolation(.tValues, "name", ##class(OcuPilot.Api.Error).#AGENTNAMEDUPLICATE, "a name another definition holds")

    Do ..SoundValues($ZConvert(tName, "U"), .tCased)
    Do ..AssertOneViolation(.tCased, "name", ##class(OcuPilot.Api.Error).#AGENTNAMEDUPLICATE, "the same name in another case, which the unique index would refuse too")

    Do ..SoundValues(tName, .tOwn)
    Set tCount = ##class(OcuPilot.Kernel.AgentRules).Validate(.tOwn, tId, .tViolations)
    Do $$$AssertEquals(tCount, 0, "the definition that holds the name is not a duplicate of itself")
}

/// <p>Rule 2 -- the provider must be a key the catalog declares. At this floor that set is exactly
/// <code>anthropic</code>.</p>
Method TestAnUnknownProviderIsRefused()
{
    Do ..SoundValues(..#PROBEPREFIX _ "Prov", .tValues)
    Set tValues("provider") = "openai"
    Do ..AssertOneViolation(.tValues, "provider", ##class(OcuPilot.Api.Error).#AGENTPROVIDERUNKNOWN, "a provider the catalog does not declare")

    Do $$$AssertEquals($ListToString(##class(OcuPilot.Kernel.Provider.Catalog).Keys()), "anthropic", "the Release 1 catalog declares exactly one provider")
}

/// <p>The shipped <code>anthropic</code> row's shape, pinned in full. <code>defaultModel</code>
/// and <code>defaultEndpoint</code> already move an assertion elsewhere
/// (<class>OcuPilot.Test.AgentWire</class>'s create leg), but <code>modelSuggestions</code> has no
/// consumer yet -- Story 3.5's form is what reads it -- and would drift unnoticed until then.</p>
/// <p>Mutation: drop <code>claude-fable-5-1</code> from the row's <code>modelSuggestions</code>
/// array in <class>OcuPilot.Kernel.Provider.Catalog</class>'s <code>Providers</code> XData -- this
/// goes red on the suggestion list alone, every other assertion here staying green.</p>
Method TestTheShippedProviderRowIsPinned()
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Catalog).Row("anthropic", .tRow), 1, "the shipped anthropic row is readable")
    If '$IsObject(tRow) Quit
    Do $$$AssertEquals(tRow.label, "Anthropic", "the label")
    Do $$$AssertEquals(tRow.defaultModel, "claude-opus-5", "the default model")
    Do $$$AssertEquals(tRow.modelSuggestions.%ToJSON(), "[""claude-opus-5"",""claude-sonnet-5"",""claude-haiku-4-5"",""claude-fable-5-1""]", "the suggestion list: the current Claude family, most capable first")
    Do $$$AssertEquals(tRow.defaultEndpoint, "https://api.anthropic.com/v1/messages", "the default endpoint")
    Do $$$AssertEquals(+tRow.endpointRequired, 0, "Release 1's one provider does not require an endpoint")
    Do $$$AssertEquals(+tRow.canonicalMaxTokens, 32000, "the canonical maximum tokens")
    Do $$$AssertEquals(+tRow.canonicalTemperature, 0, "the canonical temperature")
    Do $$$AssertEquals(tRow.defaultEnvVarName, "ANTHROPIC_API_KEY", "the default environment variable name")
    Do $$$AssertEquals(tRow.defaultCredentialName, "OcuPilotAnthropic", "the default credential name is OcuPilot's own, never the harvested original's")
    Do $$$AssertEquals(tRow.keyPrefix, "sk-ant-", "the key prefix")
    Do $$$AssertEquals(tRow.adapterClass, "OcuPilot.Kernel.Provider.Anthropic", "the adapter class the port dispatches through, which is the column rather than a branch")
    Do $$$AssertEquals(+tRow.allowsLocal, 0, "Release 1's one provider does not allow a local address, so the escape is closed in production")
    Do $$$AssertEquals(tRow.authVersion, "2023-06-01", "and the API version its adapter sends")
}

/// <p>Rule 3 -- the maximum token count is a whole number from 1 to 32000. Digits alone: without
/// that, <code>"12abc"</code> would reach the range test as 12, because ObjectScript's unary
/// <code>+</code> reads a numeric prefix and discards the rest.</p>
Method TestMaxTokensOutsideItsRangeIsRefused()
{
    For tBad = 0, 32001, "12abc", "" {
        Do ..SoundValues(..#PROBEPREFIX _ "Tok", .tValues)
        Set tValues("maxTokens") = tBad
        Do ..AssertOneViolation(.tValues, "maxTokens", ##class(OcuPilot.Api.Error).#AGENTMAXTOKENSRANGE, "maxTokens " _ tBad)
    }
}

/// <p>Rule 4 -- the temperature is a number from 0 to 2, fractions included.</p>
Method TestTemperatureOutsideItsRangeIsRefused()
{
    For tBad = 3, "-1", "hot" {
        Do ..SoundValues(..#PROBEPREFIX _ "Temp", .tValues)
        Set tValues("temperature") = tBad
        Do ..AssertOneViolation(.tValues, "temperature", ##class(OcuPilot.Api.Error).#AGENTTEMPERATURERANGE, "temperature " _ tBad)
    }
    ; Both spellings of the same value: ObjectScript canonicalizes 0.7 to .7, and a JSON 0.7 read
    ; out of a %DynamicObject arrives that way, so a pattern requiring a digit before the point
    ; would refuse a temperature every provider accepts.
    For tGood = 0.7, "0.7", ".7", 2, 0 {
        Do ..SoundValues(..#PROBEPREFIX _ "Temp", .tFraction)
        Set tFraction("temperature") = tGood
        Do $$$AssertEquals(##class(OcuPilot.Kernel.AgentRules).Validate(.tFraction, "", .tViolations), 0, "temperature " _ tGood _ " is inside the range and accepted")
    }
}

/// <p>Rule 5 -- the credential type is one of the two declared.</p>
Method TestAnUnknownCredentialTypeIsRefused()
{
    Do ..SoundValues(..#PROBEPREFIX _ "Cred", .tValues)
    Set tValues("credType") = "wallet"
    Do ..AssertOneViolation(.tValues, "credType", ##class(OcuPilot.Api.Error).#AGENTCREDTYPEUNKNOWN, "a credential type outside the two declared")
}

/// <p>Rules 6 and 7 -- each credential type requires its own reference.</p>
Method TestEachCredentialTypeRequiresItsOwnReference()
{
    Do ..SoundValues(..#PROBEPREFIX _ "Env", .tEnv)
    Set tEnv("envVarName") = ""
    Do ..AssertOneViolation(.tEnv, "envVarName", ##class(OcuPilot.Api.Error).#AGENTENVVARREQUIRED, "credType env with no environment variable")

    Do ..SoundValues(..#PROBEPREFIX _ "Creds", .tCreds)
    Set tCreds("credType") = "creds"
    Set tCreds("envVarName") = ""
    Set tCreds("credentialName") = ""
    Do ..AssertOneViolation(.tCreds, "credentialName", ##class(OcuPilot.Api.Error).#AGENTCREDNAMEREQUIRED, "credType creds with no credential")
}

/// <p>AC3 -- the XOR invariant <b>normalizes; it does not reject</b>, in both directions: a body
/// carrying both references keeps the one its credential type selects and the other is cleared to
/// <code>""</code>, with no violation either way.</p>
/// <p>Mutation: delete the line in <method>OcuPilot.Kernel.AgentRules.Normalize</method> that
/// clears the unselected credential name -- the first half goes red, because
/// <code>credentialName</code> survives a <code>credType</code> of <code>env</code>.</p>
Method TestTheCredentialInvariantNormalizesInBothDirections()
{
    Do ..SoundValues(..#PROBEPREFIX _ "Xor1", .tEnv)
    Set tEnv("envVarName") = "ANTHROPIC_API_KEY"
    Set tEnv("credentialName") = "OcuPilotAnthropic"
    Do ##class(OcuPilot.Kernel.AgentRules).Normalize(.tEnv)
    Do $$$AssertEquals(tEnv("envVarName"), "ANTHROPIC_API_KEY", "credType env keeps the environment variable")
    Do $$$AssertEquals(tEnv("credentialName"), "", "and clears the credential name")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.AgentRules).Validate(.tEnv, "", .tV1), 0, "sending both is not an error -- one is cleared")

    Do ..SoundValues(..#PROBEPREFIX _ "Xor2", .tCreds)
    Set tCreds("credType") = "creds"
    Set tCreds("envVarName") = "ANTHROPIC_API_KEY"
    Set tCreds("credentialName") = "OcuPilotAnthropic"
    Do ##class(OcuPilot.Kernel.AgentRules).Normalize(.tCreds)
    Do $$$AssertEquals(tCreds("credentialName"), "OcuPilotAnthropic", "credType creds keeps the credential name")
    Do $$$AssertEquals(tCreds("envVarName"), "", "and clears the environment variable")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.AgentRules).Validate(.tCreds, "", .tV2), 0, "and is likewise not an error")
}

/// <p>AC3's second half -- normalization runs <b>before</b> validation, so a body that selects the
/// environment rung, leaves it empty and supplies a credential name instead is told what is
/// actually missing rather than silently accepting a credential the ladder would never read.</p>
Method TestNormalizationExposesTheGapItCreates()
{
    Do ..SoundValues(..#PROBEPREFIX _ "Gap", .tValues)
    Set tValues("envVarName") = ""
    Set tValues("credentialName") = "OcuPilotAnthropic"
    Do ##class(OcuPilot.Kernel.AgentRules).Normalize(.tValues)
    Do $$$AssertEquals(tValues("credentialName"), "", "the unselected credential name is cleared first")
    Do ..AssertOneViolation(.tValues, "envVarName", ##class(OcuPilot.Api.Error).#AGENTENVVARREQUIRED, "and the gap that leaves is then reported")
}

/// <p>Rule 8 -- a provider whose catalog row says an endpoint is required must have one, and the
/// rule reads <b>the row's column</b> rather than a provider name, so build step 7 adds a row
/// rather than a branch.</p>
/// <p><b>Driven through <class>OcuPilot.Test.AgentRulesProbe</class></b>, because Release 1 ships
/// one provider row and that row does not require an endpoint. Left unexercised the rule would be
/// unfalsifiable: it would read as coverage while never having run.</p>
Method TestAProviderRowThatRequiresAnEndpointRefusesAnEmptyOne()
{
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Provider.Catalog).Row("anthropic", .tShipped), 1, "the shipped provider row is readable")
    Do $$$AssertEquals(+tShipped.endpointRequired, 0, "and does not require an endpoint, which is why this rule needs the probe catalog")

    Do ..SoundValues(..#PROBEPREFIX _ "Ep", .tValues)
    Set tValues("provider") = ##class(OcuPilot.Test.CatalogProbe).#PROBEKEY
    Set tValues("endpointUrl") = ""
    Set tCount = ##class(OcuPilot.Test.AgentRulesProbe).Validate(.tValues, "", .tViolations)
    Do $$$AssertEquals(tCount, 1, "exactly one violation (" _ ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.tViolations).%ToJSON() _ ")")
    If tCount '= 1 Quit
    Do $$$AssertEquals($List(tViolations(1), 1), "endpointUrl", "on the endpoint field")
    Do $$$AssertEquals($List(tViolations(1), 2), ##class(OcuPilot.Api.Error).#AGENTENDPOINTREQUIRED, "with the endpoint-required code")

    Set tValues("endpointUrl") = "https://probe.example.com/v1"
    Do $$$AssertEquals(##class(OcuPilot.Test.AgentRulesProbe).Validate(.tValues, "", .tOk), 0, "and supplying one satisfies the rule")
}

/// <p>AD-42's scheme clause, OcuPilot's own rather than harvested: an endpoint that is not
/// absolute HTTPS is refused. The local exception, the marked-local flag and the resolved-address
/// check are Story 3.2's; at this floor HTTPS is the only accepted scheme.</p>
/// <p><b>The scheme is case-insensitive</b>, as RFC 3986 defines it, so the accepted set below
/// carries the same endpoint in three spellings: a refusal of <code>HTTPS://</code> would turn a
/// valid endpoint away.</p>
/// <p><b>An authority carrying userinfo is refused</b> even though it is well-formed. It is the
/// one field on the definition that could hold a credential, and the full projection returns it
/// and the change record writes it into the console log OcuPilot displays (AD-35).</p>
/// <p>Mutation: restore <code>[^/?#\s]+</code> as
/// <method>OcuPilot.Kernel.AgentRules.IsAbsoluteHttps</method>'s authority class -- the two
/// userinfo spellings above are accepted and this goes red.</p>
Method TestAnEndpointThatIsNotAbsoluteHttpsIsRefused()
{
    For tBad = "http://host/v1", "ftp://host/v1", "/v1/messages", "https://", "api.anthropic.com/v1", "https://user:sk-ant-secret@host/v1", "https://user@host/v1" {
        Do ..SoundValues(..#PROBEPREFIX _ "Sch", .tValues)
        Set tValues("endpointUrl") = tBad
        Do ..AssertOneViolation(.tValues, "endpointUrl", ##class(OcuPilot.Api.Error).#AGENTENDPOINTSCHEME, "endpoint " _ tBad)
    }

    For tGood = "https://api.anthropic.com/v1/messages", "HTTPS://api.anthropic.com/v1/messages", "HttpS://api.anthropic.com/v1/messages", "https://api.example.com?api-version=1", "https://api.example.com" {
        Do ..SoundValues(..#PROBEPREFIX _ "Sch", .tCased)
        Set tCased("endpointUrl") = tGood
        Do $$$AssertEquals(##class(OcuPilot.Kernel.AgentRules).Validate(.tCased, "", .tOk), 0, "endpoint " _ tGood _ " is accepted, the scheme being case-insensitive")
    }
}

/// <p>Rule 9 -- the system-prompt override is at most 8192 characters.</p>
Method TestAnOverlongSystemPromptIsRefused()
{
    Do ..SoundValues(..#PROBEPREFIX _ "Prompt", .tValues)
    Set tValues("systemPromptOverride") = $Translate($Justify("", 8193), " ", "p")
    Do ..AssertOneViolation(.tValues, "systemPromptOverride", ##class(OcuPilot.Api.Error).#AGENTSYSTEMPROMPTLENGTH, "an 8193-character system prompt")

    Set tValues("systemPromptOverride") = $Translate($Justify("", 8192), " ", "p")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.AgentRules).Validate(.tValues, "", .tOk), 0, "and exactly 8192 characters is accepted")
}

/// <p>Rule 10 -- the retention period is a whole number of days from 1 to 365.</p>
Method TestRetentionOutsideItsRangeIsRefused()
{
    For tBad = 0, 366, "30days", "" {
        Do ..SoundValues(..#PROBEPREFIX _ "Ret", .tValues)
        Set tValues("retentionDays") = tBad
        Do ..AssertOneViolation(.tValues, "retentionDays", ##class(OcuPilot.Api.Error).#AGENTRETENTIONRANGE, "retentionDays " _ tBad)
    }
}

/// <p>Rule 11 -- the per-turn iteration ceiling is a whole number from 1 to 100.</p>
Method TestIterationsOutsideItsRangeIsRefused()
{
    For tBad = 0, 101, "ten" {
        Do ..SoundValues(..#PROBEPREFIX _ "Iter", .tValues)
        Set tValues("maxIterationsPerTurn") = tBad
        Do ..AssertOneViolation(.tValues, "maxIterationsPerTurn", ##class(OcuPilot.Api.Error).#AGENTITERATIONSRANGE, "maxIterationsPerTurn " _ tBad)
    }
}

/// <p>AC5's refusal half, OcuPilot's own rather than harvested: a definition cannot be enabled
/// while Test connection has not succeeded against it. Story 3.4 is the only thing that clears
/// this, which is that story's reason to exist.</p>
Method TestEnablingAnUnverifiedDefinitionIsRefused()
{
    Do ..SoundValues(..#PROBEPREFIX _ "Enable", .tValues)
    Set tValues("enabled") = 1
    Do ..AssertOneViolation(.tValues, "enabled", ##class(OcuPilot.Api.Error).#AGENTENABLEUNVERIFIED, "enabling an unverified definition")

    Set tValues("connectionVerified") = 1
    Do $$$AssertEquals(##class(OcuPilot.Kernel.AgentRules).Validate(.tValues, "", .tOk), 0, "and a verified one may be enabled")
}

/// <p>AC2 -- <b>the accumulation, which is what the acceptance criterion is actually about.</b>
/// A submission that breaks four rules at once yields one answer carrying four
/// <code>{field, code}</code> entries, in declared rule order -- never one error at a time, and
/// never a violation without a field.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.AgentRules.Validate</method> quit after appending the
/// first violation -- this goes red with "expected 4 violations, found 1".</p>
Method TestFourBrokenRulesYieldFourViolationsInDeclaredOrder()
{
    Do ..SoundValues(..#PROBEPREFIX _ "Four", .tValues)
    Set tValues("provider") = "openai"
    Set tValues("maxTokens") = 99000
    Set tValues("temperature") = 3
    Set tValues("credType") = "env"
    Set tValues("envVarName") = ""
    Set tValues("credentialName") = "OcuPilotAnthropic"
    Do ##class(OcuPilot.Kernel.AgentRules).Normalize(.tValues)
    Set tCount = ##class(OcuPilot.Kernel.AgentRules).Validate(.tValues, "", .tViolations)
    Do $$$AssertEquals(tCount, 4, "four broken rules yield four violations, not one")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.tViolations).%ToJSON(), ##class(OcuPilot.Test.AgentWire).ViolationsText($ListBuild($ListBuild("provider", "AGENT.PROVIDER.UNKNOWN"), $ListBuild("maxTokens", "AGENT.MAXTOKENS.RANGE"), $ListBuild("temperature", "AGENT.TEMPERATURE.RANGE"), $ListBuild("envVarName", "AGENT.ENVVAR.REQUIRED"))), "in declared rule order, each naming its field")

    Set tBlank = 0
    For tI = 1:1:tCount {
        If $List(tViolations(tI), 1) = "" Set tBlank = tBlank + 1
    }
    Do $$$AssertEquals(tBlank, 0, "and no violation is reported without a field")
}

}
