/// <p>Stand-in endpoint that defines <method>PutAndPostSchema</method> and <method>Schema</method>
/// itself and inherits <method>PutRequestBodySchema</method>: the port must resolve
/// <code>PutAndPostSchema</code>, since an inherited template does not count (AD-3).</p>
Class OcuPilot.Test.TemplateFixtureLate Extends OcuPilot.Test.TemplateFixture
{

/// <p>Earlier in AD-3's order than <method>Schema</method>.</p>
Method PutAndPostSchema() As %DynamicObject
{
    Quit {"marker": "PutAndPostSchema", "apiVersion": (..ApiVersion)}
}

/// <p>Last in AD-3's order.</p>
Method Schema() As %DynamicObject
{
    Quit {"marker": "Schema", "apiVersion": (..ApiVersion)}
}

}
