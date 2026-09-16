/// <p>Shared instance-state helper for the credential-ladder suite: build the request body a store
/// carries, ask whether this instance holds a credential entry, and remove one.</p>
/// <p><b>Nothing else removes a credential entry</b> -- no install step, no uninstall, no purge task
/// -- so each test class owns its own cleanup and the residue check is an assertion rather than a
/// hope.</p>
/// <p><b>The entry class is named through
/// <parameter>OcuPilot.Kernel.Secret.Ladder.CREDSCLASS</parameter> and reached by
/// <code>$ClassMethod</code></b>, never by <code>##class</code>, for the reason the shipped ladder
/// does it: CI's <code>images</code> leg compiles this file on an edition that may not carry the
/// class at all. Every method answers as "no such entry" where the rung is unreachable, which is the
/// same reading every caller here needs.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests, so
/// the suite's own classes are the only things the runner enumerates.</p>
Class OcuPilot.Test.CredentialFixture Extends %RegisteredObject
{

/// <p>The body member a credential store reads, as
/// <parameter>OcuPilot.Api.Definitions.KEYFIELD</parameter> declares it.</p>
Parameter KEYFIELD = "apiKey";

/// <p>One request body carrying <var>pKey</var>, which is the shape
/// <method>OcuPilot.Api.Definitions.HandleStoreCredential</method> hands the ladder.</p>
ClassMethod Payload(pKey As %String) As %DynamicObject
{
    Set tBody = {}
    Do tBody.%Set(..#KEYFIELD, pKey)
    Quit tBody
}

/// <p>The same body as request text.</p>
ClassMethod PayloadText(pKey As %String) As %String
{
    Quit "{""" _ ..#KEYFIELD _ """:""" _ pKey _ """}"
}

/// <p>Whether this instance holds the credential entry <var>pName</var>. Answers 0 where the
/// credentials rung is unreachable.</p>
ClassMethod Exists(pName As %String) As %Boolean
{
    Set tExists = 0
    Try {
        If '##class(OcuPilot.Kernel.Secret.Ladder).CredentialsRungAvailable() Quit
        Set tExists = ''$ClassMethod(##class(OcuPilot.Kernel.Secret.Ladder).#CREDSCLASS, "%ExistsId", pName)
    } Catch ex {
        Set tExists = 0
    }
    Quit tExists
}

/// <p>Remove the credential entry <var>pName</var> if this instance holds one. Asserts nothing --
/// each class's teardown is what refuses to let one survive.</p>
ClassMethod Remove(pName As %String)
{
    Try {
        If '..Exists(pName) Quit
        Do $ClassMethod(##class(OcuPilot.Kernel.Secret.Ladder).#CREDSCLASS, "%DeleteId", pName)
    } Catch ex {
    }
}

}
