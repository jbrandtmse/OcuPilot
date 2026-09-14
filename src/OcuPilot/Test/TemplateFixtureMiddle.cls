/// <p>Stand-in endpoint that defines <method>PutRequestBodySchema</method> and
/// <method>PutAndPostSchema</method> itself: the port must resolve
/// <code>PutRequestBodySchema</code> (AD-3).</p>
Class OcuPilot.Test.TemplateFixtureMiddle Extends OcuPilot.Test.TemplateFixtureLate
{

/// <p>Earlier in AD-3's order than <method>PutAndPostSchema</method>.</p>
Method PutRequestBodySchema() As %DynamicObject
{
    Quit {"marker": "PutRequestBodySchema", "apiVersion": (..ApiVersion)}
}

/// <p>Later in AD-3's order than <method>PutRequestBodySchema</method>.</p>
Method PutAndPostSchema() As %DynamicObject
{
    Quit {"marker": "PutAndPostSchema", "apiVersion": (..ApiVersion)}
}

}
