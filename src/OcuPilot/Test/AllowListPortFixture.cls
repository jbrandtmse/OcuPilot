/// <p>A seam subclass of <class>OcuPilot.Port.AllowListPort</class>: every <code>FSAccess</code> call and every read of the
/// roots goes through <class>OcuPilot.Test.PathPortFixture</class>, which counts the calls, logs them in order and answers a
/// scripted status for an endpoint and type, and denies the pairs it is told to (AD-29).</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and declares no arming variable. A test that
/// drives it changes the instance's own allow-list, so only a class armed by <code>OCUPILOT_ALLOW_PRINCIPALS</code> calls
/// it, and it restores what <method>OcuPilot.Test.PathPortFixture.Snapshot</method> recorded.</p>
Class OcuPilot.Test.AllowListPortFixture Extends OcuPilot.Port.AllowListPort
{

/// <p>The class every test of the allow-list write counts its calls through.</p>
Parameter SEAM = "OcuPilot.Test.PathPortFixture";

ClassMethod AdminPortClass() As %String
{
    Quit ..#SEAM
}

ClassMethod PathPortClass() As %String
{
    Quit ..#SEAM
}

}
