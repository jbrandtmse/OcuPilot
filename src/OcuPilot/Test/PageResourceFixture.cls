/// <p>The three real principals Story 21.37's write classes sign in as (AD-8, AD-29, AD-44), built from
/// <class>OcuPilot.Test.DeveloperFloorFixture</class>'s helpers: Least, who holds exactly <code>%Admin_Secure:USE</code>,
/// <code>%DB_IRISSYS:READ</code> and READ on the install namespace's code database; NoSecure, who holds the code database,
/// <code>%Admin_Operate:USE</code> (the API admits an account with no administrative privilege no further) and <code>%DB_IRISSYS:READ</code>; and
/// NoIris, who holds the code database and <code>%Admin_Secure:USE</code> only. A grant is believed only once it is read back.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>, and <method>Prepare</method> refuses unless <parameter>ARMINGVARIABLE</parameter> reads 1, so
/// the principals exist only on a throwaway <file>scripts/ci-throwaway.sh</file> built. <method>RemovePrincipals</method> deletes them and their
/// roles.</p>
Class OcuPilot.Test.PageResourceFixture Extends %RegisteredObject
{

/// <p>The environment variable that arms this fixture, and the one value that arms it: <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FLOOR = "OcuPilot.Test.DeveloperFloorFixture";

/// <p>The accounts and their roles, in the order <method>Prepare</method> creates them.</p>
Parameter LEASTUSER = "OcuProbe2137Least";

Parameter NOSECUREUSER = "OcuProbe2137NoSecure";

Parameter NOIRISUSER = "OcuProbe2137NoIris";

Parameter ROLESUFFIX = "Role";

/// <p>Whether <parameter>ARMINGVARIABLE</parameter> arms this instance.</p>
ClassMethod Armed() As %Boolean
{
    Quit ($System.Util.GetEnviron(..#ARMINGVARIABLE) = 1)
}

/// <p>Create the three principals with <var>pPassword</var> and read their grants back. An error status names what could not be established; nothing
/// is created unless <method>Armed</method>.</p>
ClassMethod Prepare(pPassword As %String) As %Status
{
    If '..Armed() Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PageResourceFixture creates IRIS users and roles and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh.")
    Set tCode = $ClassMethod(..#FLOOR, "CodeResource")
    If tCode = "" Quit $$$ERROR($$$GeneralError, "the install namespace's code database resource could not be read")
    Set tSC = ..EnsureUser(..#LEASTUSER, tCode _ ":R,%Admin_Secure:U,%DB_IRISSYS:R", pPassword)
    If $$$ISOK(tSC) Set tSC = ..EnsureUser(..#NOSECUREUSER, tCode _ ":R,%Admin_Operate:U,%DB_IRISSYS:R", pPassword)
    If $$$ISOK(tSC) Set tSC = ..EnsureUser(..#NOIRISUSER, tCode _ ":R,%Admin_Secure:U", pPassword)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#FLOOR, "Composed", ..#LEASTUSER, .tLeast)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FLOOR, "Composed", ..#NOSECUREUSER, .tNoSecure)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FLOOR, "Composed", ..#NOIRISUSER, .tNoIris)
    If $$$ISERR(tSC) Quit tSC
    Set tLeastOk = $ClassMethod(..#FLOOR, "Holds", tLeast, "%Admin_Secure", "USE") && $ClassMethod(..#FLOOR, "Holds", tLeast, "%DB_IRISSYS", "READ") && $ClassMethod(..#FLOOR, "Holds", tLeast, tCode, "READ") && '$ClassMethod(..#FLOOR, "Holds", tLeast, "%DB_IRISSYS", "WRITE") && '$ClassMethod(..#FLOOR, "Holds", tLeast, "%Development", "USE")
    Set tNoSecureOk = $ClassMethod(..#FLOOR, "Holds", tNoSecure, "%DB_IRISSYS", "READ") && '$ClassMethod(..#FLOOR, "Holds", tNoSecure, "%Admin_Secure", "USE")
    Set tNoIrisOk = $ClassMethod(..#FLOOR, "Holds", tNoIris, "%Admin_Secure", "USE") && '$ClassMethod(..#FLOOR, "Holds", tNoIris, "%DB_IRISSYS", "READ")
    If 'tLeastOk || 'tNoSecureOk || 'tNoIrisOk Quit $$$ERROR($$$GeneralError, "the principals' grants did not read back: Least " _ tLeastOk _ ", NoSecure " _ tNoSecureOk _ ", NoIris " _ tNoIrisOk)
    Quit $$$OK
}

/// <p>Create <var>pUser</var>, replacing any account of that name, holding the role of the same name and <parameter>ROLESUFFIX</parameter>, reset to
/// exactly <var>pResources</var>. Refuses unless <method>Armed</method>.</p>
ClassMethod EnsureUser(pUser As %String, pResources As %String, pPassword As %String) As %Status
{
    If '..Armed() Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PageResourceFixture creates IRIS users and roles and runs on a throwaway container only.")
    Set tRole = pUser _ ..#ROLESUFFIX
    Set tSC = $ClassMethod(..#FLOOR, "ResetRole", tRole, pResources)
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(pUser, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(pUser)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Users).Create(pUser, tRole, pPassword, "OcuPilot page resources test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.PageResourceFixture")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>One request as <var>pUser</var> to <var>pPath</var> under the REST application's path.</p>
ClassMethod Call(pMethod As %String, pPath As %String, pUser As %String, pPassword As %String, Output pStatus As %Integer, Output pText As %String, pBody As %String = "") As %Status
{
    Quit $ClassMethod(..#FLOOR, "Call", pMethod, pPath, pUser, pPassword, .pStatus, .pText, .tHeaders, pBody)
}

/// <p>Delete the three principals and their roles and answer what survives, <code>""</code> when nothing does.</p>
ClassMethod RemovePrincipals() As %String
{
    Set tLeft = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#LEASTUSER, ..#NOSECUREUSER, ..#NOIRISUSER {
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ " user " _ tUser
            Set tRole = tUser _ ..#ROLESUFFIX
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole, .tR2, .tRS2) Set tLeft = tLeft _ " role " _ tRole
        }
    } Catch ex {
        Set tLeft = tLeft _ " (" _ ex.DisplayString() _ ")"
    }
    Set $NAMESPACE = tOrigNS
    Quit tLeft
}

}
