/// <p>The Story 9.9 probes: a snapshot and restore of <parameter>SERVICE</parameter>, the one service
/// the service tests write, and the <code>ocup99*</code> LDAP configurations the LDAP tests create and
/// delete through <class>Security.LDAPConfigs</class> in <code>%SYS</code> (AD-16). A configuration's
/// name is a lower-case domain: the vendor stores a name given with <code>LDAPFlags</code> lower-cased
/// with <code>.com</code> appended, and refuses a <code>Modify</code> of one that is not domain-shaped
/// (ERROR #908, measured), so every probe name is <code>ocup99&lt;word&gt;.invalid</code>.</p>
/// <p><b>Every write here refuses unless <parameter>ARMINGVARIABLE</parameter> reads 1</b>, so a
/// runner pointed at an instance someone cares about writes nothing through this class, and a
/// service write also refuses when <parameter>SERVICE</parameter> is enabled there. A configuration
/// is deleted only after its exact name is read back and starts <parameter>PREFIX</parameter>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ServiceLdapProbe Extends %RegisteredObject
{

/// <p>The environment variable that arms every write here, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SERVICE_CONFIG";

/// <p>The environment variable that arms the throwaway principals <method>EnsurePrincipal</method>
/// creates.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The prefix every throwaway principal's and role's name carries.</p>
Parameter PRINCIPALPREFIX = "OcuPilotWire99";

/// <p>The only service a test writes: disabled on every instance this suite runs on.</p>
Parameter SERVICE = "%Service_CallIn";

/// <p>The prefix every probe LDAP configuration's name carries.</p>
Parameter PREFIX = "ocup99";

/// <p>An error status unless the arming variable reads 1.</p>
ClassMethod Armed() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ServiceLdapProbe writes a service and LDAP configurations and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written.")
    }
    Quit $$$OK
}

/// <p><parameter>SERVICE</parameter>'s vendor read, as JSON, in <var>pSnapshot</var>. An enabled
/// service is refused: the tests write only a disabled one.</p>
ClassMethod Snapshot(Output pSnapshot As %String) As %Status
{
    Set pSnapshot = ""
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Read(..#SERVICE, .tFresh)
    If $$$ISERR(tSC) Quit tSC
    If tFresh.%Get("Enabled") {
        Quit $$$ERROR($$$GeneralError, ..#SERVICE _ " is enabled on this instance, so the service tests write nothing to it.")
    }
    Set pSnapshot = tFresh.%ToJSON()
    Quit $$$OK
}

/// <p>Put <parameter>SERVICE</parameter> back as <var>pSnapshot</var> held it: its
/// <code>AutheEnabled</code>, <code>ClientSystems</code> and <code>Enabled</code>, through the
/// vendor's own <code>PUT</code>.</p>
ClassMethod Restore(pSnapshot As %String) As %Status
{
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    If pSnapshot = "" Quit $$$OK
    Set tHeld = ##class(%DynamicObject).%FromJSON(pSnapshot)
    Set tBody = {}
    Do tBody.%Set("AutheEnabled", tHeld.%Get("AutheEnabled"), "number")
    Do tBody.%Set("ClientSystems", tHeld.%Get("ClientSystems"))
    Do tBody.%Set("Enabled", tHeld.%Get("Enabled"), "boolean")
    Kill tQuery
    Set tQuery("name") = ..#SERVICE
    Quit ##class(OcuPilot.Port.AdminPort).Invoke("Security.Service", "PUT", .tQuery, tBody, .tAnswer, .tHttp, .tFault)
}

/// <p>Service or configuration <var>pName</var>'s vendor read, in <var>pFresh</var>.</p>
ClassMethod Read(pName As %String, Output pFresh As %DynamicObject, pEndpoint As %String = "Security.Service") As %Status
{
    Set pFresh = ""
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(pEndpoint, "GET", .tQuery, "", .pFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(pFresh) Quit $$$ERROR($$$GeneralError, pName _ " answered no object")
    Quit $$$OK
}

/// <p>Create the probe LDAP configuration <var>pName</var>, a lower-case domain starting
/// <parameter>PREFIX</parameter>: disabled and not Active Directory (<code>LDAPFlags</code> 8, use
/// groups), host <code>ocup99.invalid</code>, with a description, and every required setting the
/// vendor's own default or a probe value.</p>
ClassMethod CreateLdap(pName As %String) As %Status
{
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    If $Extract(pName, 1, $Length(..#PREFIX)) '= ..#PREFIX Quit $$$ERROR($$$GeneralError, "a probe configuration's name starts " _ ..#PREFIX)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.LDAPConfigs).Exists(pName) Do ##class(Security.LDAPConfigs).Delete(pName)
        Kill tProperties
        Set tProperties("Description") = "OcuPilot probe"
        Set tProperties("LDAPFlags") = 8
        Set tProperties("LDAPHostNames") = "ocup99.invalid"
        Set tProperties("LDAPBaseDN") = "DC=ocup99,DC=invalid"
        Set tProperties("LDAPBaseDNForGroups") = "DC=ocup99,DC=invalid"
        Set tProperties("LDAPSearchUsername") = "CN=ocup99,DC=ocup99,DC=invalid"
        Set tSC = ##class(Security.LDAPConfigs).Create(pName, .tProperties)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the probe LDAP configuration <var>pName</var>, once its exact name reads back and
/// starts <parameter>PREFIX</parameter>. An absent one is nothing to do.</p>
ClassMethod RemoveLdap(pName As %String) As %Status
{
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.LDAPConfigs).Exists(pName, .tConfig) {
            Set tExact = tConfig.Name
            Set tConfig = ""
            If $Extract(tExact, 1, $Length(..#PREFIX)) = ..#PREFIX Set tSC = ##class(Security.LDAPConfigs).Delete(tExact)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete every LDAP configuration whose name starts <parameter>PREFIX</parameter>.</p>
ClassMethod RemoveAll() As %Status
{
    Set tSC = ..Armed()
    If $$$ISERR(tSC) Quit tSC
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Security.LDAPConfigs:List")
        Set tSC = tRS.Execute("*")
        If $$$ISOK(tSC) {
            While tRS.Next() {
                Set tName = tRS.GetData(1)
                If $Extract(tName, 1, $Length(..#PREFIX)) = ..#PREFIX Set tNames = tNames _ $ListBuild(tName)
            }
        }
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$ListLength(tNames) {
        Set tSC = ..RemoveLdap($List(tNames, tI))
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>Whether an LDAP configuration named <var>pName</var> exists, read in <code>%SYS</code>.</p>
ClassMethod LdapExists(pName As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(Security.LDAPConfigs).Exists(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tExists
}

/// <p>Create the throwaway principal <var>pUser</var> with password <var>pPassword</var>, holding one
/// role <var>pRole</var> that grants the install namespace's code read and <var>pResources</var>
/// (<code>resource:permission</code>, comma-separated) and nothing else. Both names start
/// <parameter>PRINCIPALPREFIX</parameter>.</p>
ClassMethod EnsurePrincipal(pUser As %String, pRole As %String, pResources As %String, pPassword As %String) As %Status
{
    If $System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1 Quit $$$ERROR($$$GeneralError, ..#PRINCIPALSVARIABLE _ " does not read 1 here, so no principal was created.")
    If ($Extract(pUser, 1, $Length(..#PRINCIPALPREFIX)) '= ..#PRINCIPALPREFIX) || ($Extract(pRole, 1, $Length(..#PRINCIPALPREFIX)) '= ..#PRINCIPALPREFIX) Quit $$$ERROR($$$GeneralError, "a throwaway principal's name starts " _ ..#PRINCIPALPREFIX)
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set $NAMESPACE = "%SYS"
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCodeRead = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        If ##class(Security.Roles).Exists(pRole) Do ##class(Security.Roles).Delete(pRole)
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot test: a reduced editor's pairs (throwaway)", tCodeRead _ "," _ pResources, "")
        If $$$ISOK(tSC) {
            If ##class(Security.Users).Exists(pUser) Do ##class(Security.Users).Delete(pUser)
            Set tSC = ##class(Security.Users).Create(pUser, pRole, pPassword, "OcuPilot reduced editor test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.ServiceLdapProbe; deleted by RemovePrincipal")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the throwaway principal <var>pUser</var> and its role <var>pRole</var>, each only when
/// its name starts <parameter>PRINCIPALPREFIX</parameter>; an error status when either survives.</p>
ClassMethod RemovePrincipal(pUser As %String, pRole As %String) As %Status
{
    If $System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1 Quit $$$ERROR($$$GeneralError, ..#PRINCIPALSVARIABLE _ " does not read 1 here, so nothing was deleted.")
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ($Extract(pUser, 1, $Length(..#PRINCIPALPREFIX)) = ..#PRINCIPALPREFIX) && ##class(Security.Users).Exists(pUser) Do ##class(Security.Users).Delete(pUser)
        If ($Extract(pRole, 1, $Length(..#PRINCIPALPREFIX)) = ..#PRINCIPALPREFIX) && ##class(Security.Roles).Exists(pRole) Do ##class(Security.Roles).Delete(pRole)
        If ##class(Security.Users).Exists(pUser) || ##class(Security.Roles).Exists(pRole) Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal " _ pUser _ " or its role survived")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
