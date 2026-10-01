/// <p>Test-only <class>OcuPilot.Test.MappingRecordPort</class> subclass for the admitted leg of
/// <class>OcuPilot.Test.NamespaceInteropGate</class>: it records and sends every call as its parent
/// does, and waits <parameter>BOUNDSECONDS</parameter> for a queued task instead of the shipped bound,
/// so an enable sent through it ends inside the call and is never answered as started. The bound stays
/// under the 180 seconds <method>OcuPilot.Test.MappingWriteGate.RunAs</method> waits for its child.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.NamespaceInteropRecordPort Extends OcuPilot.Test.MappingRecordPort
{

/// <p>How long a queued task is awaited, in seconds.</p>
Parameter BOUNDSECONDS = 150;

ClassMethod AsyncTimeout() As %Numeric
{
    Quit ..#BOUNDSECONDS
}

}
