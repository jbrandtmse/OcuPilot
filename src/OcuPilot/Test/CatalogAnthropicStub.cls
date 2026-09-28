/// <p>Test-only <class>OcuPilot.Test.CatalogProbe</class> subclass whose <b>anthropic</b> row
/// answers the transport stub instead of the real <class>OcuPilot.Kernel.Provider.Anthropic</class>
/// adapter. <method>OcuPilot.Kernel.AgentRules.Validate</method> reads the real, unsubclassed
/// <class>OcuPilot.Kernel.Provider.Catalog</class> and cannot be pointed at a fixture, so this class
/// re-adapts the shipped <code>anthropic</code> row rather than adding a key
/// <method>OcuPilot.Kernel.AgentRules.Validate</method> would refuse. Every other column of the row,
/// and every row <class>OcuPilot.Test.CatalogProbe</class> adds, is unchanged.</p>
/// <p>A definition naming <code>anthropic</code> passes
/// <method>OcuPilot.Kernel.AgentRules.Validate</method>, and a definition dispatched
/// through <class>OcuPilot.Test.ProviderPortProbe</class> with this catalog switched in (its
/// <method>OcuPilot.Test.ProviderPortProbe.SetCatalogClass</method>) is one whose call still opens
/// no socket -- so <method>OcuPilot.Api.Definitions.HandleTest</method>, the literal shipped
/// method, can be driven all the way to its 200 through real device capture
/// (<class>OcuPilot.Test.Dispatch</class>) rather than through <method>Outcome</method>'s own
/// reimplemented arrangement.</p>
Class OcuPilot.Test.CatalogAnthropicStub Extends OcuPilot.Test.CatalogProbe
{

/// <p>The real provider key this class re-adapts.</p>
Parameter ANTHROPICKEY = "anthropic";

/// <p>The stub adapter the <parameter>ANTHROPICKEY</parameter> row answers instead of the real
/// one.</p>
Parameter STUBADAPTER = "OcuPilot.Test.ProviderStub";

ClassMethod Table(Output pObject As %DynamicObject) As %Status
{
    Set tSC = ##super(.pObject)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = pObject.providers.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.key = ..#ANTHROPICKEY {
            Do tRow.%Set("adapterClass", ..#STUBADAPTER)
            Quit
        }
    }
    Quit tSC
}

}
