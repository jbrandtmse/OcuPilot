/// <p><class>OcuPilot.Test.InteropArchiveSeam</class> with the namespace's message cap lowered to <parameter>ARCHIVEMAXMESSAGES</parameter> three and the error list's cap to two, so a test
/// reads each cap at its boundary without storing ten thousand messages (Story 24.16 Batch 4).</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropArchiveCapSeam Extends OcuPilot.Test.InteropArchiveSeam
{

Parameter ARCHIVEMAXMESSAGES As INTEGER = 3;

Parameter ARCHIVEERRORSMAX As INTEGER = 2;

}
