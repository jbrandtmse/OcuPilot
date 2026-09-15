/// <p>A second transport stand-in, identical to <class>OcuPilot.Test.ProviderStub</class> except
/// for the identity it reports.</p>
/// <p>It exists so that AC1 has two adapter classes to tell apart. With one stub behind both probe
/// catalog rows, "the adapter comes from the row's <code>adapterClass</code> column" would pass
/// against a port that read no column at all -- the assertion would be satisfied by the only
/// answer there was. Two classes make the claim falsifiable: each row names one, and the test
/// asserts the call was served by the class its own row named.</p>
Class OcuPilot.Test.ProviderStubAlt Extends OcuPilot.Test.ProviderStub
{

Parameter STUBIDENTITY = "stubalt";

}
