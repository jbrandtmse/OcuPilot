/// <p>The response stub <class>OcuPilot.Port.HarvestPort</class> runs a harvested body behind
/// (AD-23). It records what the body rendered and writes nothing: <property>Renders</property>
/// counts the calls to <method>OcuPilot.Port.Harvest.Handler.RenderResponseBody</method>, and the
/// other three properties keep the first call's arguments for the port to turn into OcuPilot's
/// envelope.</p>
/// <p>Only <class>OcuPilot.Port.HarvestPort</class> constructs it.</p>
Class OcuPilot.Port.Harvest.Response Extends %CSP.Response
{

/// <p>How many times the body rendered.</p>
Property Renders As %Integer [ InitialExpression = 0 ];

/// <p>The first render's status.</p>
Property RenderStatus As %Status [ InitialExpression = 1 ];

/// <p>The first render's message part, or <code>""</code> when it passed none.</p>
Property MsgPart As %DynamicAbstractObject;

/// <p>The first render's result part, or <code>""</code> when it passed none.</p>
Property ResPart As %DynamicAbstractObject;

}
