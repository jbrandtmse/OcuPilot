/// <p>Stand-in endpoint that defines <method>RequestBodySchema</method> and
/// <method>PutRequestBodySchema</method> itself: the port must resolve
/// <code>RequestBodySchema</code> (AD-3).</p>
Class OcuPilot.Test.TemplateFixtureEarly Extends OcuPilot.Test.TemplateFixtureMiddle
{

/// <p>First in AD-3's order.</p>
Method RequestBodySchema() As %DynamicObject
{
    Quit {"marker": "RequestBodySchema", "apiVersion": (..ApiVersion)}
}

/// <p>Later in AD-3's order than <method>RequestBodySchema</method>.</p>
Method PutRequestBodySchema() As %DynamicObject
{
    Quit {"marker": "PutRequestBodySchema", "apiVersion": (..ApiVersion)}
}

}
