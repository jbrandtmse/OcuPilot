/// <p><class>OcuPilot.Test.InteropItemSeam</class> with <parameter>OcuPilot.Port.InteropPort.ABORTMAX</parameter> lowered to one, so a
/// queue of two waiting messages exceeds what an abort of the queue enumerates (Story 20.23) without a test queueing ten thousand.
/// Nothing else differs from the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropCapSeam Extends OcuPilot.Test.InteropItemSeam
{

/// <p>The most entries a queue read enumerates and an abort of the queue takes.</p>
Parameter ABORTMAX = 1;

}
