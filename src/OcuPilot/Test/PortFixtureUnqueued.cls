/// <p><class>OcuPilot.Test.PortFixture</class> without Story 18.4's six queued disk operations in its
/// <parameter>QUEUEDWRITES</parameter>, so <class>OcuPilot.Test.AdminPortAsync</class> drives the three
/// whose own <code>Run()</code> queues a task (<parameter>OcuPilot.Port.AdminPort.SELFQUEUEDTYPES</parameter>)
/// into the port's refusal of a mutating request that would queue (AD-35).</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.PortFixtureUnqueued Extends OcuPilot.Test.PortFixture
{

Parameter QUEUEDWRITES = "Security.Audit.Record/COPY,Security.Audit.Record/PURGE,Namespace.Namespace/MAPPINGS";

}
