/// <p><class>OcuPilot.Test.EndpointFixture</class> that also declares the vendor's
/// <code>HISTORY</code> request type, so a Task history read reaches the fixture's
/// <code>list</code> mode and its recorded query.</p>
Class OcuPilot.Test.CriteriaDefault.Endpoint Extends OcuPilot.Test.EndpointFixture
{

/// <p>The vendor's history type number, as <class>OcuPilot.Test.ReadSource.Endpoint</class> declares it.</p>
Parameter TYPEHISTORY As INTEGER = 10;

}
