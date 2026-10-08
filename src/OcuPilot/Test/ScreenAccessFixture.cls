/// <p>The three real principals Story 20.15's wire classes sign in as (AD-8, AD-64), built from
/// <class>OcuPilot.Test.DeveloperFloorFixture</class>'s helpers: Dev, who holds <code>%Developer</code> --
/// so <code>%Development:USE</code> -- and READ on the install namespace's code database; Sec, who holds
/// <code>%Admin_Secure:USE</code> and that READ and not <code>%Development:USE</code>; and Op, who holds
/// <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code> and neither adjuster pair.
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

/// <p>Sec's account name.</p>
Parameter SECURITYUSER = "OcuPilotProbeAccessSec";

/// <p>Sec's role: READ on the install namespace's code database and <code>%Admin_Secure:USE</code>.</p>
Parameter SECURITYROLE = "OcuPilotProbeAccessSecRole";

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
    If $$$ISOK(tSC) Set tSC = ..EnsureSecurity(pPassword)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#FLOOR, "Composed", tDev, .tDevGrants)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FLOOR, "Composed", tOp, .tOpGrants)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FLOOR, "Composed", ..Sec(), .tSecGrants)
    If $$$ISERR(tSC) Quit tSC
    Set tDevOk = $ClassMethod(..#FLOOR, "Holds", tDevGrants, "%Development", "USE") && '$ClassMethod(..#FLOOR, "Holds", tDevGrants, "%Admin_Operate", "USE")
    Set tOpOk = $ClassMethod(..#FLOOR, "Holds", tOpGrants, "%Admin_Operate", "USE") && $ClassMethod(..#FLOOR, "Holds", tOpGrants, "%DB_IRISSYS", "READ") && '$ClassMethod(..#FLOOR, "Holds", tOpGrants, "%Development", "USE")
    Set tSecOk = $ClassMethod(..#FLOOR, "Holds", tSecGrants, "%Admin_Secure", "USE") && '$ClassMethod(..#FLOOR, "Holds", tSecGrants, "%Development", "USE") && $ClassMethod(..#FLOOR, "Holds", tSecGrants, $ClassMethod(..#FLOOR, "CodeResource"), "READ")
    If 'tDevOk || 'tOpOk || 'tSecOk Quit $$$ERROR($$$GeneralError, "the principals' grants did not read back: Dev " _ tDevOk _ ", Op " _ tOpOk _ ", Sec " _ tSecOk)
    Quit $$$OK
}

/// <p>Create Sec, replacing any account of that name, with <parameter>SECURITYROLE</parameter> reset to its
/// two grants. Refuses unless <method>Armed</method>.</p>
ClassMethod EnsureSecurity(pPassword As %String) As %Status
{
    If '..Armed() Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ScreenAccessFixture creates IRIS users and roles and runs on a throwaway container only.")
    Set tCode = $ClassMethod(..#FLOOR, "CodeResource")
    If tCode = "" Quit $$$ERROR($$$GeneralError, "the install namespace's code database resource could not be read")
    Set tSC = $ClassMethod(..#FLOOR, "ResetRole", ..#SECURITYROLE, tCode _ ":R,%Admin_Secure:U")
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#SECURITYUSER, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(..#SECURITYUSER)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Users).Create(..#SECURITYUSER, ..#SECURITYROLE, pPassword, "OcuPilot screen permissions test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.ScreenAccessFixture")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Sec's account name.</p>
ClassMethod Sec() As %String
{
    Quit ..#SECURITYUSER
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

/// <p>Delete all three principals and their roles and answer what survives, <code>""</code> when nothing
/// does.</p>
ClassMethod RemovePrincipals() As %String
{
    Set tLeft = $ClassMethod(..#FLOOR, "RemovePrincipals")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(..#SECURITYUSER, .tU, .tUS) Do ##class(Security.Users).Delete(..#SECURITYUSER)
        If ##class(Security.Users).Exists(..#SECURITYUSER, .tU2, .tUS2) Set tLeft = tLeft _ " user " _ ..#SECURITYUSER
        If ##class(Security.Roles).Exists(..#SECURITYROLE, .tR, .tRS) Do ##class(Security.Roles).Delete(..#SECURITYROLE)
        If ##class(Security.Roles).Exists(..#SECURITYROLE, .tR2, .tRS2) Set tLeft = tLeft _ " role " _ ..#SECURITYROLE
    } Catch ex {
        Set tLeft = tLeft _ " (" _ ex.DisplayString() _ ")"
    }
    Set $NAMESPACE = tOrigNS
    Quit tLeft
}

/// <p>Remove every screen's adjustment, so each requires its declared set.</p>
ClassMethod ResetAll() As %Status
{
    Quit ##class(OcuPilot.Kernel.State.Access).DeleteAllGuarded()
}

}
