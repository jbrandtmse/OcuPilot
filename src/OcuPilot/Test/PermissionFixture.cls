/// <p>The probe principals <class>OcuPilot.Test.PermissionCheck</class> and
/// <class>OcuPilot.Test.EffectiveUser</class> each create and remove (Story 16.3): a chained account,
/// an <code>%All</code> account, a caller holding the security pairs without
/// <code>%Admin_Manage</code>, and a least-privileged caller, with their roles, two resources and a
/// web application, every name beginning <parameter>PREFIX</parameter>. It arms nothing itself; each
/// caller refuses to run unless its own arming variable reads 1.</p>
Class OcuPilot.Test.PermissionFixture Extends %RegisteredObject
{

/// <p>Every probe object's name begins with this.</p>
Parameter PREFIX = "OcuPermCheck";

/// <p>A resource no one holds publicly, which role B grants at Read and Use and the escalation role
/// at Write, and which guards the web application.</p>
Parameter RESOURCE = "OcuPermCheckRes";

/// <p>A resource every account holds at Read, publicly.</p>
Parameter PUBLICRESOURCE = "OcuPermCheckPub";

/// <p>Role A grants role B, which grants the resource and <code>%DB_USER</code> at Read.</p>
Parameter ROLEA = "OcuPermCheckA";

Parameter ROLEB = "OcuPermCheckB";

/// <p>The chained account's escalation role, which grants what it must not be counted for.</p>
Parameter ROLEESCALATION = "OcuPermCheckE";

/// <p>A role that grants <code>%All</code>.</p>
Parameter ROLEALL = "OcuPermCheckR";

/// <p>The security pairs and the code database, without <code>%Admin_Manage</code>.</p>
Parameter ROLESECURE = "OcuPermCheckSec";

/// <p>An administrative resource and the code database, without <code>%Admin_Secure</code>.</p>
Parameter ROLELOW = "OcuPermCheckLow";

/// <p>The chained account: role A, escalation role E.</p>
Parameter USERCHAINED = "OcuPermCheckU";

/// <p>The account holding every privilege through role R.</p>
Parameter USERALL = "OcuPermCheckV";

Parameter USERSECURE = "OcuPermCheckSecU";

Parameter USERLOW = "OcuPermCheckLowU";

Parameter PASSWORD = "OcuPermCheck-Probe-9x";

Parameter APP = "/csp/ocupermcheck";

/// <p>Names the instance holds no object by.</p>
Parameter NOUSER = "OcuPermCheckNoSuchUser";

Parameter NOROLE = "OcuPermCheckNoSuchRole";

Parameter NORESOURCE = "OcuPermCheckNoSuchRes";

/// <p>Create every probe object; on a failure, remove what was made.</p>
ClassMethod CreateAll() As %Status
{
    Do ..RemoveAll()
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tCode = ..CodeDatabaseResource()
        If tCode = "" {
            Set tSC = $$$ERROR($$$GeneralError, "the install namespace's code database resource could not be read")
            Quit
        }
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Resources).Create(..#RESOURCE, "OcuPilot permission check probe", "", "")
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(Security.Resources).Create(..#PUBLICRESOURCE, "OcuPilot permission check probe", "R", "")
        If $$$ISERR(tSC) Quit
        For tRole = $ListBuild(..#ROLEB, ..#RESOURCE _ ":RU,%DB_USER:R", ""), $ListBuild(..#ROLEA, "", ..#ROLEB), $ListBuild(..#ROLEESCALATION, ..#RESOURCE _ ":W,%Admin_Secure:U", ""), $ListBuild(..#ROLEALL, "", "%All"), $ListBuild(..#ROLESECURE, "%Admin_Secure:U,%DB_IRISSYS:R," _ tCode _ ":R", ""), $ListBuild(..#ROLELOW, "%Admin_Operate:U,%DB_IRISSYS:R," _ tCode _ ":R", "") {
            Set tSC = ##class(Security.Roles).Create($List(tRole, 1), "OcuPilot permission check probe", $List(tRole, 2), $List(tRole, 3))
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        Kill tProps
        Set tProps("NameSpace") = "USER"
        Set tProps("Enabled") = 0
        Set tProps("AutheEnabled") = 32
        Set tProps("Resource") = ..#RESOURCE
        Set tProps("Description") = "OcuPilot permission check probe"
        Set tSC = ##class(Security.Applications).Create(..#APP, .tProps)
        If $$$ISERR(tSC) Quit
        For tUser = $ListBuild(..#USERCHAINED, ..#ROLEA), $ListBuild(..#USERALL, ..#ROLEALL), $ListBuild(..#USERSECURE, ..#ROLESECURE), $ListBuild(..#USERLOW, ..#ROLELOW) {
            Set tSC = ##class(Security.Users).Create($List(tUser, 1), $List(tUser, 2), ..#PASSWORD, "OcuPilot permission check probe")
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        Kill tProps
        Set tProps("EscalationRoles") = ..#ROLEESCALATION
        Set tSC = ##class(Security.Users).Modify(..#USERCHAINED, .tProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    If $$$ISERR(tSC) Do ..RemoveAll()
    Quit tSC
}

/// <p>Delete every probe object this class names, where it exists.</p>
ClassMethod RemoveAll()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#USERCHAINED, ..#USERALL, ..#USERSECURE, ..#USERLOW {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
        }
        If ##class(Security.Applications).Exists(..#APP) Do ##class(Security.Applications).Delete(..#APP)
        For tRole = ..#ROLEA, ..#ROLEB, ..#ROLEESCALATION, ..#ROLEALL, ..#ROLESECURE, ..#ROLELOW {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
        }
        For tResource = ..#RESOURCE, ..#PUBLICRESOURCE {
            If ##class(Security.Resources).Exists(tResource) Do ##class(Security.Resources).Delete(tResource)
        }
    } Catch ex {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>Which probe objects the instance still holds, <code>""</code> when none.</p>
ClassMethod Left() As %String
{
    Set tLeft = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tQuery = "SELECT Name FROM Security.Users WHERE Name %STARTSWITH ?", "SELECT Name FROM Security.Roles WHERE Name %STARTSWITH ?", "SELECT Name FROM Security.Resources WHERE Name %STARTSWITH ?" {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, tQuery, ..#PREFIX)
            While tRS.%Next() {
                Set tLeft = tLeft _ " " _ tRS.%Get("Name")
            }
        }
        If ##class(Security.Applications).Exists(..#APP) Set tLeft = tLeft _ " " _ ..#APP
    } Catch ex {
        Set tLeft = tLeft _ " (" _ ex.DisplayString() _ ")"
    }
    Set $NAMESPACE = tOrigNS
    Quit tLeft
}

/// <p>The resource guarding the install namespace's code database, whose read a principal needs to
/// reach OcuPilot's dispatch class at all (AD-9, AD-21).</p>
ClassMethod CodeDatabaseResource() As %String
{
    Set tResource = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set $NAMESPACE = "%SYS"
        Set tNsObj = ##class(Config.Namespaces).Open(tNs)
        Set tResource = ##class(SYS.Database).%OpenId(##class(Config.Databases).Open(tNsObj.Routines).Directory).ResourceName
    } Catch ex {
        Set tResource = ""
    }
    Set $NAMESPACE = tOrigNS
    Quit tResource
}

}
