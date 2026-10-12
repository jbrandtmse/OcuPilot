/// <p>Test-only helper for <class>OcuPilot.Test.CompileWithoutInterop</class>: the probe namespace
/// <code>OCUPROBE2028N</code> over its own database <code>OCUPROBE2028D</code> (resource
/// <code>%DB_OCUPROBE2028D</code>, directory <code>&lt;mgr&gt;ocuprobe2028d/</code>), created without
/// interoperability, and its removal by exact name.</p>
/// <p>It adds nothing to <class>OcuPilot.Test.RemoteDatabaseProbe</class> but the names it works
/// under. <parameter>SERVERNAME</parameter> and <parameter>MAPPINGNAME</parameter> are declared
/// because the base needs them, and neither object is ever created.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.CompileWithoutInteropProbe Extends OcuPilot.Test.RemoteDatabaseProbe
{

Parameter PREFIX = "OCUPROBE2028";

Parameter DIRPREFIX = "ocuprobe2028";

Parameter RESOURCEPREFIX = "%DB_OCUPROBE2028";

Parameter LOCALNAME = "OCUPROBE2028D";

Parameter NAMESPACENAME = "OCUPROBE2028N";

Parameter SERVERNAME = "OCUPROBE2028SRV";

Parameter MAPPINGNAME = "OcuProbe2028*";

}
