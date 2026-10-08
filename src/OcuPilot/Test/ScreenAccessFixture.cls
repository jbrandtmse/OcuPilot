/// <p>The two real principals Story 20.15's wire classes sign in as (AD-8, AD-64), built from
/// <class>OcuPilot.Test.DeveloperFloorFixture</class>'s helpers: Dev, who holds <code>%Developer</code> --
/// so <code>%Development:USE</code> -- and READ on the install namespace's code database; and Op, who holds
/// <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code> and not <code>%Development:USE</code>.
/// A grant is believed only once it is read back.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>, and <method>Prepare</method> refuses unless
/// <parameter>ARMINGVARIABLE</parameter> reads 1, so the principals exist only on a throwaway
/// <file>scripts/ci-throwaway.sh</file> built. <method>RemovePrincipals</method> deletes them and their
/// roles, and <method>ResetAll</method> removes every adjustment.</p>
Class OcuPilot.Test.ScreenAccessFixture Extends %RegisteredObject
{

/// <p>The environment variable that arms this fixture, and the one value that arms it: <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FLOOR = "OcuPilot.Test.DeveloperFloorFixture";

/// <p>Whether <parameter>ARMINGVARIABLE</parameter> arms this instance.</p>
ClassMethod Armed() As %Boolean
{
    Quit ($System.Util.GetEnviron(..#ARMINGVARIABLE) = 1)
}

/// <p>Create Dev and Op with <var>pPassword</var> and read their grants back. An error status names
/// what could not be established; nothing is created unless <method>Armed</method>.</p>
ClassMethod Prepare(pPassword As %String) As %Status
{
    If '..Armed() Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ScreenAccessFixture creates IRIS users and roles and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh.")
    Set tSC = $ClassMethod(..#FLOOR, "EnsurePrincipal", pPassword, "", .tDev)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FLOOR, "EnsurePrincipal", pPassword, "administrator", .tOp)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#FLOOR, "Composed", tDev, .tDevGrants)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FLOOR, "Composed", tOp, .tOpGrants)
    If $$$ISERR(tSC) Quit tSC
    Set tDevOk = $ClassMethod(..#FLOOR, "Holds", tDevGrants, "%Development", "USE") && '$ClassMethod(..#FLOOR, "Holds", tDevGrants, "%Admin_Operate", "USE")
    Set tOpOk = $ClassMethod(..#FLOOR, "Holds", tOpGrants, "%Admin_Operate", "USE") && $ClassMethod(..#FLOOR, "Holds", tOpGrants, "%DB_IRISSYS", "READ") && '$ClassMethod(..#FLOOR, "Holds", tOpGrants, "%Development", "USE")
    If 'tDevOk || 'tOpOk Quit $$$ERROR($$$GeneralError, "the principals' grants did not read back: Dev " _ tDevOk _ ", Op " _ tOpOk)
    Quit $$$OK
}

/// <p>Dev's account name.</p>
ClassMethod Dev() As %String
{
    Quit $Parameter(..#FLOOR, "DEVELOPERUSER")
}

/// <p>Op's account name.</p>
ClassMethod Op() As %String
{
    Quit $Parameter(..#FLOOR, "ADMINISTRATORUSER")
}

/// <p>One request as <var>pUser</var> to <var>pPath</var> under the REST application's path.</p>
ClassMethod Call(pMethod As %String, pPath As %String, pUser As %String, pPassword As %String, Output pStatus As %Integer, Output pText As %String, pBody As %String = "") As %Status
{
    Quit $ClassMethod(..#FLOOR, "Call", pMethod, pPath, pUser, pPassword, .pStatus, .pText, .tHeaders, pBody)
}

/// <p>Delete both principals and their roles and answer what survives, <code>""</code> when nothing
/// does.</p>
ClassMethod RemovePrincipals() As %String
{
    Quit $ClassMethod(..#FLOOR, "RemovePrincipals")
}

/// <p>Remove every screen's adjustment, so each requires its declared set.</p>
ClassMethod ResetAll() As %Status
{
    Quit ##class(OcuPilot.Kernel.State.Access).DeleteAllGuarded()
}

}
