/// <p>The single source of the provider vocabulary and its canonical defaults. <b>This is the
/// only place in shipped code that spells a provider key, a default model, a model suggestion or
/// a canonical endpoint</b>; every other shipped class asks it. Test classes spell the shipped
/// row's values, because pinning a table means writing down what it holds.</p>
/// <p>The harvest map records what happens otherwise: model lists hardcoded in one method and
/// duplicated against a defaults class, both of them stale and partly fictional. One table means
/// a new model is a row edit and a new provider family is one adapter plus one row, not a branch
/// added in several places.</p>
/// <p><b>Release 1 ships exactly one row, <code>anthropic</code></b> -- the only Release 1
/// provider. The other families arrive at build step 7, which is why the columns a second family
/// needs (<code>endpointRequired</code>, <code>keyPrefix</code>) are already here and why
/// <method>Table</method> is overridable: a rule that reads a column no shipped row exercises is
/// unfalsifiable, so <class>OcuPilot.Test.CatalogProbe</class> supplies a second row and
/// <class>OcuPilot.Test.AgentRules</class> drives the rule through it.</p>
Class OcuPilot.Kernel.Provider.Catalog Extends %RegisteredObject
{

/// <p>One row per provider key.</p>
/// <ul>
/// <li><code>key</code> -- the value stored in a definition's <code>Provider</code>, and the
/// closed vocabulary rule 2 tests membership in.</li>
/// <li><code>label</code> -- the display name a later story renders.</li>
/// <li><code>defaultModel</code> / <code>modelSuggestions</code> -- the canonical model and the
/// list a form offers. Suggestions, not a closed set: a model released after this build must be
/// usable without a code change.</li>
/// <li><code>defaultEndpoint</code> -- the canonical endpoint, applied when a create omits
/// one.</li>
/// <li><code>endpointRequired</code> -- whether a definition on this provider must carry an
/// endpoint. Rule 8 reads this column rather than a provider name, so a family that needs one is
/// a row rather than a branch.</li>
/// <li><code>canonicalMaxTokens</code> / <code>canonicalTemperature</code> -- the tuning applied
/// when a create omits them.</li>
/// <li><code>defaultEnvVarName</code> / <code>defaultCredentialName</code> -- the two credential
/// references a form offers. The credential name is OcuPilot's own, never the harvested one.</li>
/// <li><code>keyPrefix</code> -- the shape a key for this provider starts with. Stored for Story
/// 3.2's adapter; nothing here reads a key.</li>
/// </ul>
XData Providers
{
{"providers":[
  {"key":"anthropic","label":"Anthropic","defaultModel":"claude-opus-5","modelSuggestions":["claude-opus-5","claude-sonnet-5","claude-haiku-4-5-20251001","claude-fable-5-1"],"defaultEndpoint":"https://api.anthropic.com/v1/messages","endpointRequired":false,"canonicalMaxTokens":32000,"canonicalTemperature":0,"defaultEnvVarName":"ANTHROPIC_API_KEY","defaultCredentialName":"OcuPilotAnthropic","keyPrefix":"sk-ant-"}
]}
}

/// <p>The table as a <class>%DynamicObject</class> carrying a <code>providers</code> array.</p>
/// <p><b>Overridable</b>, and the only seam any other method here reads the table through, so a
/// subclass that answers a different table changes what <method>Keys</method>,
/// <method>Row</method> and <method>IsKnown</method> all say. Production never overrides it.</p>
ClassMethod Table(Output pObject As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pObject = ""
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Kernel.Provider.Catalog", "Providers", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the provider table XData block 'Providers' is missing")
            Quit
        }
        Do tXData.Data.Rewind()
        Set pObject = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
        If '$IsObject(pObject) || '$IsObject(pObject.providers) {
            Set pObject = ""
            Set tSC = $$$ERROR($$$GeneralError, "the provider table XData block carries no providers array")
        }
    } Catch ex {
        Set pObject = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every provider key the table declares, in declaration order, as a
/// <class>%List</class>.</p>
ClassMethod Keys() As %List
{
    Set tKeys = ""
    Try {
        Set tSC = ..Table(.tTable)
        If $$$ISERR(tSC) || '$IsObject(tTable) Quit
        Set tIterator = tTable.providers.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tKeys = tKeys _ $ListBuild(tRow.key)
        }
    } Catch ex {
        Set tKeys = ""
    }
    Quit tKeys
}

/// <p>The row for <var>pKey</var>. Returns 1 with <var>pRow</var> set when the key is declared,
/// and 0 with <var>pRow</var> <code>""</code> when it is not -- an unknown key is an ordinary
/// answer here, because rule 2 is what turns it into a refusal.</p>
/// <p><b>The first match wins and the scan ends there</b>, so a table that declared a key twice
/// resolves to the row a reader sees first rather than to the last one.</p>
ClassMethod Row(pKey As %String, Output pRow As %DynamicObject) As %Boolean
{
    Set pRow = ""
    Set tFound = 0
    Try {
        If pKey = "" Quit
        Set tSC = ..Table(.tTable)
        If $$$ISERR(tSC) || '$IsObject(tTable) Quit
        Set tIterator = tTable.providers.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tCandidate) {
            If tCandidate.key = pKey {
                Set pRow = tCandidate
                Set tFound = 1
                Quit
            }
        }
    } Catch ex {
        Set pRow = ""
        Set tFound = 0
    }
    Quit tFound
}

/// <p>Whether <var>pKey</var> is a declared provider key.</p>
ClassMethod IsKnown(pKey As %String) As %Boolean
{
    Quit ..Row(pKey, .tRow)
}

}
