/// <p>Test-only stand-in for <class>Ens.Config.Credentials</class>, shaped only as far as
/// <method>OcuPilot.Kernel.Secret.Ladder.Credential</method> reads it: a class-level
/// <method>%ExistsId</method> and <method>%OpenId</method> -- the same two names
/// <method>Credential</method> dispatches to by string, so this class answers the identical call
/// shape -- an instance carrying a <property>Password</property>, and a <method>%DeleteId</method>
/// that always refuses, for <method>OcuPilot.Kernel.Secret.Ladder.Clear</method>'s refused-delete
/// branch.</p>
/// <p><b>It exists to drive <method>Credential</method>'s <code>$Char(0)</code> normalization
/// directly.</b> Forcing a real <class>Ens.Config.Credentials</class> row's <code>Password</code>
/// to read back as the sentinel means writing to that column outside its own
/// <method>PasswordSet</method>/<method>PasswordGet</method> pair, which this suite does not do to
/// the vendor's table. This stand-in answers whatever value a test sets, sentinel included, with no
/// vendor mechanism in the way.</p>
/// <p>State lives in a process-private global, the same reason
/// <class>OcuPilot.Test.SecretProbe</class>'s does.</p>
Class OcuPilot.Test.FakeCredentialRow Extends %RegisteredObject
{

/// <p>The value <method>%OpenId</method> hands back on <property>Password</property>.</p>
Property Password As %String;

/// <p>Whether entry <var>pId</var> has been given a value by <method>SetPassword</method>.</p>
ClassMethod %ExistsId(pId As %String) As %Boolean
{
    Quit $Data(^||OcuPilotFakeCredRow(pId))
}

/// <p>An instance carrying whatever <method>SetPassword</method> last recorded for
/// <var>pId</var>, or <code>""</code> when nothing was recorded.</p>
ClassMethod %OpenId(pId As %String) As OcuPilot.Test.FakeCredentialRow
{
    Set tObj = ..%New()
    Set tObj.Password = $Get(^||OcuPilotFakeCredRow(pId))
    Quit tObj
}

/// <p>Refuse to delete entry <var>pId</var>, whatever it holds, and leave it in place.</p>
ClassMethod %DeleteId(pId As %String) As %Status
{
    Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.FakeCredentialRow refuses every delete")
}

/// <p>Record <var>pValue</var> as entry <var>pId</var>'s password -- <code>$Char(0)</code>
/// included, which is exactly the sentinel a real SQL-updated empty column reads back as.</p>
ClassMethod SetPassword(pId As %String, pValue As %String)
{
    Set ^||OcuPilotFakeCredRow(pId) = pValue
}

/// <p>Forget every entry.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotFakeCredRow
}

}
