/// <p>DW-414 -- AD-37's bounded deletion on the <b>repoint</b> path: a definition that stops naming
/// an OcuPilot-created credential entry leaves the entry in place while another definition still
/// names it, and takes it with it when it is the last one that did.</p>
/// <p>The delete path is already covered. The repoint path was driven by a PUT that asserted only
/// where the ownership mark ended up, so deleting the clause in
/// <method>OcuPilot.Api.Definitions.HandleUpdate</method> that calls
/// <method>ClearOwnedCredential</method> on a changed reference left the suite green with the
/// entry surviving every definition that ever named it.</p>
/// <p>Needs an instance the credentials rung is available on: every definition here declares
/// <code>credType</code> as <code>creds</code>, which needs the interoperability feature and an
/// interoperability-enabled namespace (<class>OcuPilot.Test.SecretLicense</class> pins that
/// predicate). Without them every create answers other than 201 and every assertion below fails
/// at that line.</p>
/// <p>Driven over HTTP through the shipped <code>/api/ocupilot</code> routes as the suite's own
/// account. Self-cleaning: every definition is named with <parameter>PROBEPREFIX</parameter> and
/// every entry with one of this class's own references, and both are removed before and after each
/// method with an assertion that none survives. No arming variable applies -- nothing here touches
/// a principal, a log or the install.</p>
Class OcuPilot.Test.CredentialRepoint Extends %UnitTest.TestCase
{

/// <p>The prefix every definition this class creates is named with.</p>
Parameter PROBEPREFIX = "OcuPilotProbeAgent";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>The reference the entry under test is stored behind.</p>
Parameter OWNEDCREDENTIAL = "OcuPilotProbeRepointCredential";

/// <p>The reference a definition is repointed at. Nothing is ever stored behind it, so a
/// repoint creating an entry would be visible.</p>
Parameter OTHERCREDENTIAL = "OcuPilotProbeRepointTarget";

/// <p>A key of the shape the shipped <code>anthropic</code> row requires.</p>
Parameter PROBEKEY = "sk-ant-ocupilotrepointprobe0000000";

Method OnBeforeOneTest() As %Status
{
    Do ..RemoveEntries()
    Quit ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe definitions this class created are removed")
    Do $$$AssertEquals(tRemaining, 0, "and no " _ ..#PROBEPREFIX _ " definition survives this class")
    Do ..RemoveEntries()
    For tName = ..#OWNEDCREDENTIAL, ..#OTHERCREDENTIAL {
        Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(tName), 0, "no credential entry " _ tName _ " survives this class")
    }
    Quit $$$OK
}

/// <p>Remove every credential entry this class names.</p>
ClassMethod RemoveEntries()
{
    For tName = ..#OWNEDCREDENTIAL, ..#OTHERCREDENTIAL {
        Do ##class(OcuPilot.Test.CredentialFixture).Remove(tName)
    }
}

/// <p>One request to the definitions surface as the suite's own credentials.</p>
ClassMethod Call(pMethod As %String, pSuffix As %String, pBody As %String, Output pStatus As %Integer, Output pBodyText As %String) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ "/agent/definitions" _ pSuffix, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBodyText, .tHeaders, pBody, "application/json")
}

/// <p>Create a definition on the credentials rung naming <var>pReference</var>, over the wire;
/// its id, or <code>""</code>.</p>
Method Create(pSuffix As %String, pReference As %String) As %String
{
    Set tSC = ..Call("POST", "", "{""name"":""" _ ..#PROBEPREFIX _ pSuffix _ """,""provider"":""anthropic"",""credType"":""creds"",""credentialName"":""" _ pReference _ """}", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, pSuffix _ ": the create request completes")
    Do $$$AssertEquals(tStatus, 201, pSuffix _ ": the definition is created (" _ tBody _ ")")
    If tStatus '= 201 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tBody).id
}

/// <p>Store <parameter>PROBEKEY</parameter> behind definition <var>pId</var>'s reference, which is
/// what makes the entry one OcuPilot created and may therefore remove.</p>
Method Store(pId As %String, pWhat As %String)
{
    Set tSC = ..Call("POST", "/" _ pId _ "/credential", ##class(OcuPilot.Test.CredentialFixture).PayloadText(..#PROBEKEY), .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, pWhat _ ": the store request completes")
    Do $$$AssertEquals(tStatus, 200, pWhat _ ": the store is accepted (" _ tBody _ ")")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#OWNEDCREDENTIAL), 1, pWhat _ ": and the entry exists")
}

/// <p>Repoint definition <var>pId</var> at <parameter>OTHERCREDENTIAL</parameter>, asserting the
/// edit was accepted.</p>
Method Repoint(pId As %String, pWhat As %String)
{
    Set tSC = ..Call("PUT", "/" _ pId, "{""credentialName"":""" _ ..#OTHERCREDENTIAL _ """}", .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, pWhat _ ": the repoint request completes")
    Do $$$AssertEquals(tStatus, 200, pWhat _ ": and is accepted (" _ tBody _ ")")
}

/// <p>DW-414 -- an entry two definitions name survives one of them being repointed away. The
/// deletion AD-37 permits is bounded by whether any definition still names the reference, and a
/// repoint is not a licence to ignore that bound.</p>
/// <p>Mutation: remove the survivor test from
/// <method>OcuPilot.Api.Definitions.ClearOwnedCredential</method> so it deletes whenever the
/// caller owned the entry, and recompile the package -> this goes red, the entry gone while a
/// definition still names it.</p>
Method TestAnEntryTwoDefinitionsNameSurvivesOneBeingRepointedAway()
{
    Set tOwner = ..Create("RepointOwner", ..#OWNEDCREDENTIAL)
    Set tOther = ..Create("RepointSurvivor", ..#OWNEDCREDENTIAL)
    If (tOwner = "") || (tOther = "") Quit
    Do ..Store(tOwner, "the owner")

    Do ..Repoint(tOwner, "the owner")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#OWNEDCREDENTIAL), 1, "the entry survives, because a definition still names it")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#OTHERCREDENTIAL), 0, "and repointing at a reference creates no entry behind it")
}

/// <p>DW-414 -- repointing the <b>last</b> definition that names an OcuPilot-created entry removes
/// it, exactly as deleting that definition would. An entry that outlives every definition naming
/// it is the residue AD-37's bounded deletion exists to prevent.</p>
/// <p>Mutation: delete the changed-reference clause in
/// <method>OcuPilot.Api.Definitions.HandleUpdate</method> that calls
/// <method>ClearOwnedCredential</method>, and recompile the package -> this goes red, the entry
/// surviving with nothing naming it.</p>
Method TestRepointingTheLastDefinitionNamingAnEntryRemovesIt()
{
    Set tOwner = ..Create("RepointLastOwner", ..#OWNEDCREDENTIAL)
    Set tOther = ..Create("RepointLastHeir", ..#OWNEDCREDENTIAL)
    If (tOwner = "") || (tOther = "") Quit
    Do ..Store(tOwner, "the owner")

    Do ..Repoint(tOwner, "the owner")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#OWNEDCREDENTIAL), 1, "the entry is still there while the second definition names it")

    Do ..Repoint(tOther, "the last definition naming it")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#OWNEDCREDENTIAL), 0, "and is removed once nothing names it")
    Do $$$AssertEquals(##class(OcuPilot.Test.CredentialFixture).Exists(..#OTHERCREDENTIAL), 0, "with no entry created behind the reference either was repointed at")
}

}
