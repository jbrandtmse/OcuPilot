/// <p>The real principals Story 19.12's classes and browser spec sign in as (AD-8, AD-21): the
/// developer principal, holding role <code>%Developer</code> plus a purpose-built role granting
/// READ on the install namespace's code database; the principal below the floor, holding that
/// role alone; and an administrator without <code>%All</code>, holding it and
/// <parameter>DASHBOARDROLE</parameter>. That READ is every API caller's prerequisite: without it
/// <code>%CSP.REST.AccessCheck</code> answers a bare 403 before any OcuPilot code runs.</p>
/// <p>A grant is believed only once it is read back, through
/// <class>OcuPilot.Kernel.Shell.Effective</class> (<method>Composed</method>,
/// <method>Holds</method>): <code>Security.Users.Create</code> accepts a role name that does not
/// exist.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>, and <method>EnsurePrincipal</method> refuses
/// unless <parameter>ARMINGVARIABLE</parameter> reads 1, so the principals exist only on a throwaway
/// <file>scripts/ci-throwaway.sh</file> built. <method>RemovePrincipals</method> deletes all three
/// and both roles.</p>
Class OcuPilot.Test.DeveloperFloorFixture Extends %RegisteredObject
{

/// <p>The environment variable that arms this fixture, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The developer principal.</p>
Parameter DEVELOPERUSER = "OcuPilotProbeDeveloper";

/// <p>The principal holding only the code database's READ.</p>
Parameter NEITHERUSER = "OcuPilotProbeDeveloperNeither";

/// <p>The administrator without <code>%All</code>.</p>
Parameter ADMINISTRATORUSER = "OcuPilotProbeDeveloperAdmin";

/// <p>The purpose-built role granting READ on the install namespace's code database.</p>
Parameter CODEROLE = "OcuPilotProbeDeveloperCode";

/// <p>The purpose-built role <parameter>ADMINISTRATORUSER</parameter> holds beside
/// <parameter>CODEROLE</parameter>: <parameter>DASHBOARDGRANTS</parameter>.</p>
Parameter DASHBOARDROLE = "OcuPilotProbeDeveloperDashboard";

/// <p>What <parameter>DASHBOARDROLE</parameter> grants: the system database's READ, which the
/// dashboard sample needs, and one administrative resource, which clears the floor.</p>
Parameter DASHBOARDGRANTS = "%DB_IRISSYS:R,%Admin_Operate:U";

/// <p>The vendor role the developer principal holds beside <parameter>CODEROLE</parameter>.</p>
Parameter DEVELOPERROLE = "%Developer";

/// <p>The REST application's path from the origin root.</p>
Parameter APIBASE = "/api/ocupilot";

/// <p>Whether <parameter>ARMINGVARIABLE</parameter> arms this instance.</p>
ClassMethod Armed() As %Boolean
{
    Quit ($System.Util.GetEnviron(..#ARMINGVARIABLE) = 1)
}

/// <p>A fresh password for a probe principal, never written to source.</p>
ClassMethod NewPassword() As %String
{
    Quit "OcuPilotDev" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
}

/// <p>The resource guarding the install namespace's routines database, or <code>""</code> when it
/// cannot be read.</p>
ClassMethod CodeResource() As %String
{
    Set tNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Set tResource = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tNsObj = ##class(Config.Namespaces).Open(tNs)
        Set tResource = ##class(SYS.Database).%OpenId(##class(Config.Databases).Open(tNsObj.Routines).Directory).ResourceName
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tResource = ""
    }
    Quit tResource
}

/// <p>Create <var>pUser</var> with <var>pPassword</var>, replacing any account of that name:
/// <parameter>DEVELOPERUSER</parameter> holding <parameter>DEVELOPERROLE</parameter> and
/// <parameter>CODEROLE</parameter>; when <var>pKind</var> is <code>neither</code>,
/// <parameter>NEITHERUSER</parameter> holding <parameter>CODEROLE</parameter> alone; when it is
/// <code>administrator</code>, <parameter>ADMINISTRATORUSER</parameter> holding
/// <parameter>CODEROLE</parameter> and <parameter>DASHBOARDROLE</parameter>. Each role is created
/// or reset to its grants and nothing else. Refuses, creating nothing, unless
/// <method>Armed</method>.</p>
ClassMethod EnsurePrincipal(pPassword As %String, pKind As %String = "", Output pUser As %String) As %Status
{
    Set pUser = ""
    If '..Armed() Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DeveloperFloorFixture creates IRIS users and roles and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    If '$ListFind($ListBuild("", "neither", "administrator"), pKind) Quit $$$ERROR($$$GeneralError, "unknown principal kind: " _ pKind)
    Set tCode = ..CodeResource()
    If tCode = "" Quit $$$ERROR($$$GeneralError, "the install namespace's code database resource could not be read")
    Set tUser = $Case(pKind, "neither": ..#NEITHERUSER, "administrator": ..#ADMINISTRATORUSER, : ..#DEVELOPERUSER)
    Set tRoles = $Case(pKind, "neither": ..#CODEROLE, "administrator": ..#CODEROLE _ "," _ ..#DASHBOARDROLE, : ..#DEVELOPERROLE _ "," _ ..#CODEROLE)
    Set tSC = ..ResetRole(..#CODEROLE, tCode _ ":R")
    If $$$ISOK(tSC) && (pKind = "administrator") Set tSC = ..ResetRole(..#DASHBOARDROLE, ..#DASHBOARDGRANTS)
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(tUser, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(tUser)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Users).Create(tUser, tRoles, pPassword, "OcuPilot developer floor test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.DeveloperFloorFixture")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    If $$$ISOK(tSC) Set pUser = tUser
    Quit tSC
}

/// <p>Create <var>pRole</var> granting exactly <var>pResources</var>, or reset it to them.</p>
ClassMethod ResetRole(pRole As %String, pResources As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Roles).Exists(pRole, .tR, .tRS) {
            Set tProps("Resources") = pResources
            Set tProps("GrantedRoles") = ""
            Set tSC = ##class(Security.Roles).Modify(pRole, .tProps)
        } Else {
            Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot test: developer floor principal role (throwaway)", pResources, "")
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete the three principals and both roles, and answer what survives, <code>""</code> when
/// nothing does.</p>
ClassMethod RemovePrincipals() As %String
{
    Set tLeft = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#DEVELOPERUSER, ..#NEITHERUSER, ..#ADMINISTRATORUSER {
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ " user " _ tUser
        }
        For tRole = ..#CODEROLE, ..#DASHBOARDROLE {
            If ##class(Security.Roles).Exists(tRole, .tR, .tRS) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Roles).Exists(tRole, .tR2, .tRS2) Set tLeft = tLeft _ " role " _ tRole
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tLeft = tLeft _ " (" _ ex.DisplayString() _ ")"
    }
    Set $NAMESPACE = tOrigNS
    Quit tLeft
}

/// <p>What <var>pUser</var>'s roles hold, composed as the instance composes it
/// (<method>OcuPilot.Kernel.Shell.Effective.Compose</method>): the roles are read back from the
/// account itself, then each role's grants and the public permissions through
/// <method>OcuPilot.Kernel.Shell.Effective.Read</method>. <b>Caller contract:</b> the caller holds
/// the Roles and Resources screens' pairs, as the suite's own account does.</p>
ClassMethod Composed(pUser As %String, Output pComposed As %DynamicObject) As %Status
{
    Set pComposed = ""
    Set tRoles = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tSC = ##class(Security.Users).Get(pUser, .tProps)
        Set tRoles = $Get(tProps("Roles"))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    Set tRoots = []
    For tI = 1:1:$Length(tRoles, ",") {
        If $Piece(tRoles, ",", tI) '= "" Do tRoots.%Push($Piece(tRoles, ",", tI))
    }
    Set tSC = ##class(OcuPilot.Kernel.Shell.Effective).Read(tRoots, .tRows, .tPublic, .tUnchecked)
    If $$$ISERR(tSC) Quit tSC
    If tUnchecked '= "" Quit $$$ERROR($$$GeneralError, "the grants of " _ pUser _ " could not be read: " _ tUnchecked)
    Set pComposed = ##class(OcuPilot.Kernel.Shell.Effective).Compose(tRoots, tRows, tPublic)
    Quit $$$OK
}

/// <p>Whether <var>pComposed</var>, a <method>Composed</method> answer, holds
/// <var>pPermission</var> (<code>USE</code>, <code>READ</code> or <code>WRITE</code>) on
/// <var>pResource</var>.</p>
ClassMethod Holds(pComposed As %DynamicObject, pResource As %String, pPermission As %String) As %Boolean
{
    If '$IsObject(pComposed) Quit 0
    Quit ''##class(OcuPilot.Kernel.Shell.Effective).Holds(pComposed, pResource, $Extract($ZConvert(pPermission, "U"))).%Get("held")
}

/// <p>Whether <var>pComposed</var>, a <method>Composed</method> answer, holds any member of
/// <parameter>OcuPilot.Screen.Gate.ADMINRESOURCES</parameter> at <code>USE</code>: a principal
/// meant to clear the floor through <code>%Development</code> alone must answer 0.</p>
ClassMethod HoldsAdministrative(pComposed As %DynamicObject) As %Boolean
{
    Set tList = ##class(OcuPilot.Screen.Gate).#ADMINRESOURCES
    Set tHolds = 0
    For tI = 1:1:$Length(tList, ",") {
        If ..Holds(pComposed, $Piece(tList, ",", tI), "USE") Set tHolds = 1
    }
    Quit tHolds
}

/// <p>One request as <var>pUser</var> to <var>pPath</var> under <parameter>APIBASE</parameter>.</p>
ClassMethod Call(pMethod As %String, pPath As %String, pUser As %String, pPassword As %String, Output pStatus As %Integer, Output pText As %String, Output pHeaders, pBody As %String = "") As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, ..#APIBASE _ pPath, pUser, pPassword, .pStatus, .pText, .pHeaders, pBody, "application/json")
}

}
