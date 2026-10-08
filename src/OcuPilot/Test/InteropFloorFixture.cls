/// <p>The real principals Story 20.14's classes and browser spec sign in as (AD-8, AD-21): one
/// holding <code>%Ens_Portal:USE</code> through a purpose-built role (kind <code>portal</code>), and
/// one each holding the stock <code>%EnsRole_Monitor</code>, <code>%EnsRole_Operator</code> or
/// <code>%EnsRole_Administrator</code>. Each also holds a purpose-built role granting READ on the
/// install namespace's code database, which every API caller needs: without it
/// <code>%CSP.REST.AccessCheck</code> answers a bare 403 before any OcuPilot code runs. None holds an
/// <code>%Admin_*</code> resource or <code>%Development:USE</code>.</p>
/// <p>A grant is believed only once it is read back, through <method>Composed</method>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>, and <method>EnsurePrincipal</method> refuses
/// unless <parameter>ARMINGVARIABLE</parameter> reads 1, so the principals exist only on a throwaway
/// <file>scripts/ci-throwaway.sh</file> built. <method>RemovePrincipals</method> deletes all four
/// and both roles. Every helper that is not specific to these principals delegates to
/// <class>OcuPilot.Test.DeveloperFloorFixture</class>.</p>
Class OcuPilot.Test.InteropFloorFixture Extends %RegisteredObject
{

/// <p>The environment variable that arms this fixture, and the one value that arms it:
/// <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The class the delegated helpers belong to.</p>
Parameter BASEFIXTURE = "OcuPilot.Test.DeveloperFloorFixture";

/// <p>The principal holding <code>%Ens_Portal:USE</code> alone beyond the code database's READ.</p>
Parameter PORTALUSER = "OcuPilotProbeInteropPortalUser";

/// <p>The principal holding <code>%EnsRole_Monitor</code>.</p>
Parameter MONITORUSER = "OcuPilotProbeInteropMonitorUser";

/// <p>The principal holding <code>%EnsRole_Operator</code>.</p>
Parameter OPERATORUSER = "OcuPilotProbeInteropOperatorUser";

/// <p>The principal holding <code>%EnsRole_Administrator</code>.</p>
Parameter ADMINISTRATORUSER = "OcuPilotProbeInteropAdminUser";

/// <p>The purpose-built role every principal holds: READ on the install namespace's code database.</p>
Parameter CODEROLE = "OcuPilotProbeInteropCodeRole";

/// <p>The purpose-built role the <code>portal</code> principal holds beside
/// <parameter>CODEROLE</parameter>: <parameter>PORTALGRANTS</parameter>.</p>
Parameter PORTALROLE = "OcuPilotProbeInteropPortalRole";

/// <p>What <parameter>PORTALROLE</parameter> grants.</p>
Parameter PORTALGRANTS = "%Ens_Portal:U";

/// <p>The kinds <method>EnsurePrincipal</method> makes, in roster order.</p>
Parameter KINDS = "portal,monitor,operator,administrator";

/// <p>Whether <parameter>ARMINGVARIABLE</parameter> arms this instance.</p>
ClassMethod Armed() As %Boolean
{
    Quit ($System.Util.GetEnviron(..#ARMINGVARIABLE) = 1)
}

/// <p>The user name of kind <var>pKind</var>, or <code>""</code> for an unknown kind.</p>
ClassMethod UserOf(pKind As %String) As %String
{
    Quit $Case(pKind, "portal": ..#PORTALUSER, "monitor": ..#MONITORUSER, "operator": ..#OPERATORUSER, "administrator": ..#ADMINISTRATORUSER, : "")
}

/// <p>The roles of kind <var>pKind</var>, comma-separated.</p>
ClassMethod RolesOf(pKind As %String) As %String
{
    Quit $Case(pKind, "portal": ..#CODEROLE _ "," _ ..#PORTALROLE, "monitor": ..#CODEROLE _ ",%EnsRole_Monitor", "operator": ..#CODEROLE _ ",%EnsRole_Operator", "administrator": ..#CODEROLE _ ",%EnsRole_Administrator", : "")
}

/// <p>Create the principal of kind <var>pKind</var> with <var>pPassword</var>, replacing any
/// account of that name, and answer its name in <var>pUser</var>. The code role is created or reset
/// to its one grant, and so is <parameter>PORTALROLE</parameter> for <code>portal</code>. Refuses,
/// creating nothing, unless <method>Armed</method>.</p>
ClassMethod EnsurePrincipal(pPassword As %String, pKind As %String, Output pUser As %String) As %Status
{
    Set pUser = ""
    If '..Armed() Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropFloorFixture creates IRIS users and roles and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    Set tUser = ..UserOf(pKind)
    If tUser = "" Quit $$$ERROR($$$GeneralError, "unknown principal kind: " _ pKind)
    Set tCode = $ClassMethod(..#BASEFIXTURE, "CodeResource")
    If tCode = "" Quit $$$ERROR($$$GeneralError, "the install namespace's code database resource could not be read")
    Set tSC = $ClassMethod(..#BASEFIXTURE, "ResetRole", ..#CODEROLE, tCode _ ":R")
    If $$$ISOK(tSC) && (pKind = "portal") Set tSC = $ClassMethod(..#BASEFIXTURE, "ResetRole", ..#PORTALROLE, ..#PORTALGRANTS)
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(tUser, .tU, .tUS) {
            Set tSC = ##class(Security.Users).Delete(tUser)
            If $$$ISERR(tSC) Quit
        }
        Set tSC = ##class(Security.Users).Create(tUser, ..RolesOf(pKind), pPassword, "OcuPilot interoperability floor test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.InteropFloorFixture")
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    If $$$ISOK(tSC) Set pUser = tUser
    Quit tSC
}

/// <p>Delete the four principals and both roles, and answer what survives, <code>""</code> when
/// nothing does. The stock roles are never touched.</p>
ClassMethod RemovePrincipals() As %String
{
    Set tLeft = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#KINDS, ",") {
            Set tUser = ..UserOf($Piece(..#KINDS, ",", tI))
            If ##class(Security.Users).Exists(tUser, .tU, .tUS) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Users).Exists(tUser, .tU2, .tUS2) Set tLeft = tLeft _ " user " _ tUser
        }
        For tRole = ..#CODEROLE, ..#PORTALROLE {
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

/// <p>A fresh password for a probe principal, never written to source.</p>
ClassMethod NewPassword() As %String
{
    Quit $ClassMethod(..#BASEFIXTURE, "NewPassword")
}

/// <p>What <var>pUser</var>'s roles hold, composed as the instance composes it
/// (<method>OcuPilot.Test.DeveloperFloorFixture.Composed</method>).</p>
ClassMethod Composed(pUser As %String, Output pComposed As %DynamicObject) As %Status
{
    Quit $ClassMethod(..#BASEFIXTURE, "Composed", pUser, .pComposed)
}

/// <p>Whether <var>pComposed</var> holds <var>pPermission</var> on <var>pResource</var>.</p>
ClassMethod Holds(pComposed As %DynamicObject, pResource As %String, pPermission As %String) As %Boolean
{
    Quit ''$ClassMethod(..#BASEFIXTURE, "Holds", pComposed, pResource, pPermission)
}

/// <p>Whether <var>pComposed</var> holds any <code>%Admin_*</code> floor member at <code>USE</code>.</p>
ClassMethod HoldsAdministrative(pComposed As %DynamicObject) As %Boolean
{
    Quit ''$ClassMethod(..#BASEFIXTURE, "HoldsAdministrative", pComposed)
}

/// <p>One request as <var>pUser</var> to <var>pPath</var> under the REST application.</p>
ClassMethod Call(pMethod As %String, pPath As %String, pUser As %String, pPassword As %String, Output pStatus As %Integer, Output pText As %String, Output pHeaders, pBody As %String = "") As %Status
{
    Quit $ClassMethod(..#BASEFIXTURE, "Call", pMethod, pPath, pUser, pPassword, .pStatus, .pText, .pHeaders, pBody)
}

}
