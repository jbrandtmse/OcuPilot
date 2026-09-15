/// <p>Stand-in endpoint defining two body-template methods, reached through
/// <method>OcuPilot.Test.PortFixture.SetEndpointClass</method>, so the port's resolution order
/// (AD-3) is pinned against a class where the order decides the answer. Each method returns a
/// marker naming itself and the API version the endpoint was constructed at.</p>
/// <p>It extends no vendor class (AD-27); the port constructs and calls it through dynamic
/// dispatch.</p>
Class OcuPilot.Test.TemplateFixture Extends %RegisteredObject
{

/// <p>The vendor's get type number, which the port constructs a template endpoint with.</p>
Parameter TYPEGET As INTEGER = 1;

Property Type As %Integer;

Property ApiVersion As %Integer;

Method %OnNew(pType As %Integer = -1, pApiVersion As %Integer = 1) As %Status
{
    Set ..Type = pType
    Set ..ApiVersion = pApiVersion
    Quit $$$OK
}

/// <p>Earlier in AD-3's order than <method>Schema</method>.</p>
Method PutRequestBodySchema() As %DynamicObject
{
    Quit {"marker": "PutRequestBodySchema", "apiVersion": (..ApiVersion)}
}

/// <p>Last in AD-3's order.</p>
Method Schema() As %DynamicObject
{
    Quit {"marker": "Schema", "apiVersion": (..ApiVersion)}
}

}
