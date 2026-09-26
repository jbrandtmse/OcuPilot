/// <p>A stream sink for adapter-level tests: it records every text it is handed, in order, under
/// <code>^||OcuPilotStreamSinkProbe</code>, or raises on every hand-over when
/// <property>Raise</property> is set. It writes nothing to the instance.</p>
Class OcuPilot.Test.StreamSinkProbe Extends OcuPilot.Kernel.Provider.StreamSink
{

/// <p>When set, <method>Publish</method> raises instead of recording.</p>
Property Raise As %Boolean [ InitialExpression = 0 ];

/// <p>Forget every recorded text.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotStreamSinkProbe
}

/// <p>How many texts were handed over.</p>
ClassMethod Count() As %Integer
{
    Quit +$Get(^||OcuPilotStreamSinkProbe)
}

/// <p>The <var>pIndex</var>th text handed over.</p>
ClassMethod Text(pIndex As %Integer) As %String
{
    Quit $Get(^||OcuPilotStreamSinkProbe(pIndex))
}

/// <p>Record <var>pText</var>, or raise when <property>Raise</property> is set.</p>
Method Publish(pText As %String)
{
    Set ^||OcuPilotStreamSinkProbe($Increment(^||OcuPilotStreamSinkProbe)) = pText
    If ..Raise Throw ##class(%Exception.General).%New("probe", "5001", , "the probe sink raised")
}

}
