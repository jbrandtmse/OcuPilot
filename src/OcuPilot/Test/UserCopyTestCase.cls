/// <p>What <class>OcuPilot.Test.UserCopy</class> and <class>OcuPilot.Test.UserCopyConfirm</class> share: the
/// probe source, target, principals and roles, the arming check, the teardown, and the helpers that create and
/// remove accounts, send a request as a principal and mint a copy. It declares no test of its own.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// <code>%Admin_Secure</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because a class
/// that extends it creates and deletes accounts and roles with the <code>OcuProbe1829</code> prefix.
/// <method>OnBeforeAllTests</method> refuses anywhere it does not. Every account and role is removed by its own
/// test's teardown or by <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.UserCopyTestCase Extends %UnitTest.TestCase [ Abstract ]
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The source account every copy in this class takes.</p>
Parameter SOURCE = "OcuProbe1829Src";

/// <p>The copy's target, which each test creates and removes.</p>
Parameter TARGET = "OcuProbe1829Dst";

/// <p>The escalation role the source holds, and the one the copy must carry.</p>
Parameter ESCROLE = "%Operator";

/// <p>The probe principals: one holding exactly the copy's pairs, one holding the code-database reads and no
/// <code>%Admin_Secure</code>. Their roles are named the same way.</p>
Parameter PRINCIPAL = "OcuProbe1829Copier";

Parameter NOGATE = "OcuProbe1829NoGate";

Parameter PRINCIPALROLE = "OcuProbe1829CopierRole";

Parameter NOGATEROLE = "OcuProbe1829NoGateRole";

/// <p>A principal that passes the API floor (it holds one administrative resource, <code>%Admin_Manage:U</code>) but
/// not the user form's <code>%Admin_Secure:USE</code>, so the form's own route gate is what refuses it.</p>
Parameter FLOORPRINCIPAL = "OcuProbe1829Floor";

Parameter FLOORROLE = "OcuProbe1829FloorRole";

/// <p>A role that grants <code>%Admin_Operate:U</code>, held by a source first as a role and then as its escalation role.</p>
Parameter ADMINROLE = "OcuProbe1829AdminRole";

/// <p>The two roles the source holds for the case-and-order leg, in the order the leg's payload reverses.</p>
Parameter SOURCEROLES = "%Developer,%Operator";

/// <p>The probe marker written as each probe role's and account's comment or description.</p>
Parameter MARKER = "OcuPilot.Test.UserCopy probe";

/// <p>The directory-service and delegated sources the copy refuses, created with the vendor's flags.</p>
Parameter LDAPSOURCE = "OcuProbe1829Ldap";

Parameter DELEGATEDSOURCE = "OcuProbe1829Dlg";

Parameter LDAPFLAG = 2;

Parameter DELEGATEDFLAG = 4;

/// <p>A password the instance's policy accepts (the throwaway's pattern is the vendor's default).</p>
Parameter GOODPASSWORD = "Ocu-Probe-1829xyz!";

/// <p>The limits class the proposal mint is given (<class>OcuPilot.Kernel.Agent.Limits</class>).</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, $ClassName() _ " creates and deletes accounts on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Do ..RemoveProbes()
    Set tSC = ..MakeSource()
    If $$$ISERR(tSC) Quit tSC
    Quit ..MakePrincipals()
}

Method OnAfterAllTests() As %Status
{
    Quit ..RemoveProbes()
}

/// <p>Remove the target and the flagged sources, put the source's roles and escalation role back, and remove any
/// proposal the test seeded, whatever the test did. Each restoring step's status is kept and asserted.</p>
Method OnAfterOneTest() As %Status
{
    Set tGrantsSC = ..RemoveSqlGrants()
    Do ..RemoveAccount(..#TARGET)
    Do ..RemoveAccount(..#LDAPSOURCE)
    Do ..RemoveAccount(..#DELEGATEDSOURCE)
    Set tEscalationSC = ..SetSourceEscalation(..#ESCROLE)
    Set tRolesSC = ..SetSourceRoles("%Developer")
    Set tSeededSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tGrantsSC, "the SQL privileges of the copy and the source are removed")
    Do $$$AssertStatusOK(tEscalationSC, "the source's escalation role is put back")
    Do $$$AssertStatusOK(tRolesSC, "the source's roles are put back")
    Do $$$AssertStatusOK(tSeededSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>Revoke every SQL privilege the source and the copy target hold in <parameter>NAMESPACE</parameter> (the standard
/// and admin privileges, through the vendor's own calls), then delete any privilege row of either grantee that is
/// left, as <class>OcuPilot.Test.SqlPrivilegeProbe</class>'s sweep does for its own grantees. Idempotent: a revoke of an
/// absent grant is not an error, so the returned status reports the sweep and any fault that escaped it.</p>
ClassMethod RemoveSqlGrants() As %Status
{
    Set tSC = $$$OK
    Set tTable = $Parameter("OcuPilot.Test.SqlPrivilegeProbe", "TABLE")
    For tGrantee = ..#SOURCE, ..#TARGET {
        Do ##class(OcuPilot.Test.SqlPrivilegeProbe).Revoke(tGrantee, "TABLE", tTable, "SELECT", "USER")
        Do ##class(OcuPilot.Test.SqlPrivilegeProbe).RevokeAdmin("USER", tGrantee)
    }
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tGrantee = ..#SOURCE, ..#TARGET {
            Set tRows = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM Security.SQLPrivileges WHERE Grantee %STARTSWITH ? OR Grantee %STARTSWITH ?", tGrantee, $ZConvert(tGrantee, "L"))
            While tRows.%Next() {
                Set tDeleteSC = ##class(Security.SQLPrivileges).%DeleteId(tRows.%GetData(1))
                Set tSC = $$$ADDSC(tSC, tDeleteSC)
            }
        }
        Do $SYSTEM.Monitor.Clear()
    } Catch ex {
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>How many privilege rows the instance still holds for the source or the copy target, in any namespace.</p>
ClassMethod SqlGrantsLeft() As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRows = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Security.SQLPrivileges WHERE Grantee %STARTSWITH ? OR Grantee %STARTSWITH ? OR Grantee %STARTSWITH ? OR Grantee %STARTSWITH ?", ..#SOURCE, $ZConvert(..#SOURCE, "L"), ..#TARGET, $ZConvert(..#TARGET, "L"))
        If tRows.%Next() Set tCount = tRows.%GetData(1)
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p>Whether the instance holds an account named <var>pName</var>, read in <code>%SYS</code> by AD-16's save
/// and restore.</p>
ClassMethod Exists(pName As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).Get(pName, .tProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit $$$ISOK(tSC)
}

/// <p>The value of setting <var>pKey</var> on account <var>pName</var> as the instance holds it, read in
/// <code>%SYS</code>, or <code>""</code> when the account is absent.</p>
ClassMethod Setting(pName As %String, pKey As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tValue = ""
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        If $$$ISOK(##class(Security.Users).Get(pName, .tProps)) Set tValue = $Get(tProps(pKey)) _ ""
    } Catch ex {
    }
    Set $NAMESPACE = tOrigNS
    Quit tValue
}

/// <p>The copy's request body as JSON text.</p>
ClassMethod Body(pName As %String, pPassword As %String, pFrom As %String) As %String
{
    Set tFrom = $Select(pFrom = "": ..#SOURCE, 1: pFrom)
    Quit "{""Name"":""" _ pName _ """,""CopyFrom"":""" _ tFrom _ """,""FullName"":"""",""Password"":""" _ pPassword _ """}"
}

/// <p>The first violation's <code>reason</code> in an answer's <code>detail</code>, given as a JSON text or an object,
/// or <code>""</code> when the answer carries none.</p>
ClassMethod ViolationReasonOf(pBody As %String) As %String
{
    Set tObj = pBody
    If '$IsObject(tObj) {
        Try {
            Set tObj = ##class(%DynamicAbstractObject).%FromJSON(pBody)
        } Catch ex {
            Set tObj = ""
        }
    }
    If '$IsObject(tObj) Quit ""
    If '$IsObject(tObj.%Get("detail")) Quit ""
    Quit tObj.%Get("detail").%Get("violations").%Get(0).%Get("reason")
}

/// <p>Whether <var>pText</var> contains <var>pWord</var>.</p>
ClassMethod Mentions(pText As %String, pWord As %String) As %Boolean
{
    Quit $IsObject(pText) && (pText.%ToJSON() [ pWord) || ('$IsObject(pText) && (pText [ pWord))
}

/// <p>One request as the probe principal <var>pUser</var>, with its password, over the absolute request the
/// browser makes. <var>pRaw</var> is the answer's text.</p>
ClassMethod AsPrincipal(pUser As %String, pMethod As %String, pSuffix As %String, pBody As %String, Output pStatus As %Integer, Output pRaw As %String) As %Status
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, tBase _ pSuffix, pUser, ..#GOODPASSWORD, .pStatus, .pRaw, .tHeaders, pBody, "application/json")
}

/// <p>Mint a copy of <var>pTarget</var> as <var>pUser</var>, on a turn seeded for that user, through the shipped
/// mint. The password is a secret the confirm supplies, so it is not an argument.</p>
ClassMethod MintAs(pUser As %String, pTarget As %String, Output pKey As %String, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pKey = ""
    Set pHttp = 0
    Set pFault = ""
    Set tTool = "OcuPilot.Screen.Tool.UserCopy"
    Set tToolName = "permissions.users.copy"
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tArgs = {"Name": (pTarget), "CopyFrom": (..#SOURCE), "FullName": ""}
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(tTool, "DESCRIPTORCLASS"), tToolName, pUser, "", tTurnKey, tArgs, ..#LIMITS, .tProposal, .pHttp, .pFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), pTarget, $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), tTool)
    If $$$ISOK(tSC) Set pKey = tProposal.%Get("proposalId")
    Quit tSC
}

/// <p>Set the source's escalation roles to <var>pRoles</var> (an empty string removes them), in
/// <code>%SYS</code>.</p>
ClassMethod SetSourceEscalation(pRoles As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tProps("EscalationRoles") = pRoles
        Set tSC = ##class(Security.Users).Modify(..#SOURCE, .tProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Set the source's roles to <var>pRoles</var>, a comma list, in <code>%SYS</code>.</p>
ClassMethod SetSourceRoles(pRoles As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tProps("Roles") = pRoles
        Set tSC = ##class(Security.Users).Modify(..#SOURCE, .tProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create the copy's source account: the roles <code>%Developer</code>, the escalation role
/// <parameter>ESCROLE</parameter> and a setting the copy must carry. In <code>%SYS</code>, by AD-16's save and restore.</p>
ClassMethod MakeSource() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).Create(..#SOURCE, "%Developer", ..#GOODPASSWORD, "Probe Source", "", "", "", 0, 1, ..#MARKER)
        If $$$ISOK(tSC) {
            Kill tProps
            Set tProps("EscalationRoles") = ..#ESCROLE
            Set tProps("AccountNeverExpires") = 1
            Set tSC = ##class(Security.Users).Modify(..#SOURCE, .tProps)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create a directory-service or delegated source account, <var>pFlags</var> being the vendor's flag, in
/// <code>%SYS</code>.</p>
ClassMethod MakeFlaggedSource(pName As %String, pFlags As %Integer) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).Create(pName, "%Developer", ..#GOODPASSWORD, "Probe flagged source", "", "", "", 0, 1, ..#MARKER, pFlags)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create the three probe principals and the four roles that serve them, in <code>%SYS</code>: the copier,
/// which holds exactly <code>%Admin_Secure:U</code>, <code>%DB_IRISSYS:R</code> and <code>%DB_HSCUSTOM:R</code>;
/// the principal that holds the code-database reads without <code>%Admin_Secure</code>; the floor-only principal,
/// which holds one administrative resource and neither of the form's pairs; and the administrative role a source
/// holds in the privilege leg.</p>
ClassMethod MakePrincipals() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Roles).Create(..#PRINCIPALROLE, ..#MARKER, "%Admin_Secure:U,%DB_IRISSYS:R,%DB_HSCUSTOM:R", "")
        If $$$ISOK(tSC) Set tSC = ##class(Security.Roles).Create(..#NOGATEROLE, ..#MARKER, "%DB_IRISSYS:R,%DB_HSCUSTOM:R", "")
        If $$$ISOK(tSC) Set tSC = ##class(Security.Roles).Create(..#FLOORROLE, ..#MARKER, "%Admin_Manage:U,%DB_IRISSYS:R,%DB_HSCUSTOM:R", "")
        If $$$ISOK(tSC) Set tSC = ##class(Security.Roles).Create(..#ADMINROLE, ..#MARKER, "%Admin_Operate:U", "")
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(..#PRINCIPAL, ..#PRINCIPALROLE, ..#GOODPASSWORD, "Probe copier", "", "", "", 0, 1, ..#MARKER)
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(..#NOGATE, ..#NOGATEROLE, ..#GOODPASSWORD, "Probe no gate", "", "", "", 0, 1, ..#MARKER)
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(..#FLOORPRINCIPAL, ..#FLOORROLE, ..#GOODPASSWORD, "Probe floor only", "", "", "", 0, 1, ..#MARKER)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove one account the test created, in <code>%SYS</code>; an absent account is not an error.</p>
ClassMethod RemoveAccount(pName As %String)
{
    If '..Exists(pName) Quit
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Do ##class(Security.Users).Delete(pName)
    } Catch ex {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>Remove the probe accounts and roles this class creates, in <code>%SYS</code>: the accounts first, so no role
/// is still held when it is deleted.</p>
ClassMethod RemoveProbes() As %Status
{
    Do ..RemoveAccount(..#TARGET)
    Do ..RemoveAccount(..#LDAPSOURCE)
    Do ..RemoveAccount(..#DELEGATEDSOURCE)
    Do ..RemoveAccount(..#PRINCIPAL)
    Do ..RemoveAccount(..#NOGATE)
    Do ..RemoveAccount(..#FLOORPRINCIPAL)
    Do ..RemoveAccount(..#SOURCE)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tRole = ..#PRINCIPALROLE, ..#NOGATEROLE, ..#FLOORROLE, ..#ADMINROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
        }
    } Catch ex {
    }
    Set $NAMESPACE = tOrigNS
    Quit $$$OK
}

}
