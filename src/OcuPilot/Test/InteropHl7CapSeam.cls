/// <p><class>OcuPilot.Test.InteropHl7Seam</class> with the HL7 schema list's cap lowered to fifteen, the fourteen standard schemas and one probe, so a test pins the cap and one over without
/// storing two thousand schemas (Story 24.18 Batch 1). A parameter overridden here is compiled into this class's own copy of each method, so this class is recompiled with the port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.InteropHl7CapSeam Extends OcuPilot.Test.InteropHl7Seam
{

Parameter HL7SCHEMASMAX As INTEGER = 15;

}
