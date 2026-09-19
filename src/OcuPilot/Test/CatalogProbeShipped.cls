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
ClassMethod Table(Output pObject As %DynamicObject) As %Status
{
    Set tSC = ##super(.pObject)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = pObject.providers.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.key = ..#OPENAIKEYSHIPPED Do tRow.%Set("adapterClass", ..#OPENAISTUB)
        If tRow.key = ..#GEMINIKEYSHIPPED Do tRow.%Set("adapterClass", ..#GEMINISTUB)
    }
    Quit tSC
}

}
