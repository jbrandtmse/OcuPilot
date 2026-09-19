/// <p>Test-only <class>OcuPilot.Test.CatalogProbe</class> subclass whose two <b>shipped</b>
/// non-canonical rows -- <code>openai</code> and <code>gemini</code> -- answer the stubs that
/// extend those families' own adapters instead of the adapters themselves. Every other column of
/// both rows, and every row <class>OcuPilot.Test.CatalogProbe</class> adds, is unchanged.</p>
/// <p>It exists because a call on a shipped row must reach the shipped endpoint's own model, body
/// and headers without opening a socket: swapping the adapter class for a subclass that replaces
/// only the transport leaves the row -- its endpoint, its model, its key prefix, its tuning -- the
/// one a turn would use.</p>
/// <p>Switched in with <method>OcuPilot.Test.ProviderPortProbe.SetCatalogClass</method>.</p>
Class OcuPilot.Test.CatalogProbeShipped Extends OcuPilot.Test.CatalogProbe
{

/// <p>The shipped provider key this class re-adapts to <parameter>OPENAISTUB</parameter>.</p>
Parameter OPENAIKEYSHIPPED = "openai";

/// <p>The shipped provider key this class re-adapts to <parameter>GEMINISTUB</parameter>.</p>
Parameter GEMINIKEYSHIPPED = "gemini";

/// <p>The stub the <parameter>OPENAIKEYSHIPPED</parameter> row answers.</p>
Parameter OPENAISTUB = "OcuPilot.Test.OpenAIStub";

/// <p>The stub the <parameter>GEMINIKEYSHIPPED</parameter> row answers.</p>
Parameter GEMINISTUB = "OcuPilot.Test.GeminiStub";

/// <p>The inherited table with the two shipped non-canonical rows' <code>adapterClass</code>
/// column, and only that column, answering the stubs. Every other column of every row -- shipped
/// or added by <class>OcuPilot.Test.CatalogProbe</class> -- is untouched, which is what makes an
/// assertion over this table an assertion about the shipped row.</p>
/// <p><b>It fails closed on the two rows it re-adapts.</b> Each of those keys must match exactly
/// one row: a key renamed in the shipped XData, or declared twice, leaves this class answering an
/// error <class>%Status</class> and no table at all, so
/// <method>OcuPilot.Kernel.Provider.Catalog.Row</method> resolves nothing and the port refuses the
/// call. Answering the table with a row it could not re-adapt would leave that row naming the
/// shipped adapter, and the next call on it would carry the probe credential to the vendor -- a
/// drift that must not resolve in the direction of making the call.</p>
/// <p><b>It re-adapts no other row, and says nothing about one.</b> The <code>anthropic</code> row
/// still names its shipped adapter here, as it does under
/// <class>OcuPilot.Test.CatalogProbe</class>; a test that drives that family switches in
/// <class>OcuPilot.Test.CatalogAnthropicStub</class> instead, and no test drives it through this
/// catalog.</p>
ClassMethod Table(Output pObject As %DynamicObject) As %Status
{
    Set tSC = ##super(.pObject)
    If $$$ISERR(tSC) Quit tSC
    Set tOpenAiRows = 0
    Set tGeminiRows = 0
    Set tIterator = pObject.providers.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.key = ..#OPENAIKEYSHIPPED {
            Do tRow.%Set("adapterClass", ..#OPENAISTUB)
            Set tOpenAiRows = tOpenAiRows + 1
        }
        If tRow.key = ..#GEMINIKEYSHIPPED {
            Do tRow.%Set("adapterClass", ..#GEMINISTUB)
            Set tGeminiRows = tGeminiRows + 1
        }
    }
    If (tOpenAiRows = 1) && (tGeminiRows = 1) Quit tSC
    Set pObject = ""
    Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.CatalogProbeShipped re-adapts exactly one " _ ..#OPENAIKEYSHIPPED _ " row and one " _ ..#GEMINIKEYSHIPPED _ " row; this table carried " _ tOpenAiRows _ " and " _ tGeminiRows _ ", so a row it did not re-adapt still names a shipped adapter. No table is answered.")
}

}
