/// <p>Pins the SSL/TLS form's gate over the wire (AD-8): a real principal lacking one of
/// <class>OcuPilot.Screen.Descriptor.SslForm</class>'s two declared pairs is refused 403 on every
/// <code>/ssl</code> route -- the form read, the name look-up, Test connection, the edit and the
/// create -- with the missing pair in <code>detail.failedPair</code>, and nothing is created, changed
/// or tested: a probe configuration reads back unchanged and the create's name stays absent.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>SSLVARIABLE</parameter> reading
/// <code>1</code>, because it creates and deletes two users, two roles and one SSL/TLS configuration.
/// <method>OnBeforeAllTests</method> refuses anywhere either does not; every probe is removed by
/// exact name.</p>
Class OcuPilot.Test.SslWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's principals, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms its probe SSL/TLS configuration.</p>
Parameter SSLVARIABLE = "OCUPILOT_ALLOW_SSL_CONFIG";

/// <p>The probe configuration the edit and Test routes name, and the name the create route
/// sends.</p>
Parameter PROBE = "OcuPilotProbeSslWire";

Parameter NEWPROBE = "OcuPilotProbeSslWireNew";

/// <p>The description that marks a configuration as this class's own before it is deleted.</p>
Parameter PROBEMARKER = "OcuPilot SSL wire probe";

/// <p>The principal holding the install namespace's code read, <code>%DB_IRISSYS:R</code> and
/// <code>%Admin_Operate:U</code>, and not <code>%Admin_Secure</code>. The administrative resource
/// passes <method>OcuPilot.Api.Router.HoldsAdminResource</method>'s floor, so the refusal measured is
/// the form's own gate.</p>
Parameter NOSECUREUSER = "OcuPilotWireSslNoSecure";

Parameter NOSECUREROLE = "OcuPilotWireSslNoSecureRole";

/// <p>The principal holding the install namespace's code read and <code>%Admin_Secure:U</code>, and
/// not <code>%DB_IRISSYS</code>.</p>
Parameter NOSYSREADUSER = "OcuPilotWireSslNoSysRead";

Parameter NOSYSREADROLE = "OcuPilotWireSslNoSysReadRole";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SslWire creates and deletes users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#SSLVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SslWire creates and deletes an SSL/TLS configuration on this instance and runs on a throwaway container only. " _ ..#SSLVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotSsl" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ..EnsureProbe()
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipals()
}

/// <p>Remove the probe configurations, the principals and their roles; a failing status when any
/// survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = ..RemoveProbe(..#PROBE)
    Set tSC = $$$ADDSC(tSC, ..RemoveProbe(..#NEWPROBE))
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#NOSECUREUSER, ..#NOSYSREADUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
        }
        For tRole = ..#NOSECUREROLE, ..#NOSYSREADROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
        }
        If ##class(Security.Users).Exists(..#NOSECUREUSER) || ##class(Security.Users).Exists(..#NOSYSREADUSER) || ##class(Security.Roles).Exists(..#NOSECUREROLE) || ##class(Security.Roles).Exists(..#NOSYSREADROLE) {
            Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.SslWire left a throwaway principal on the instance"))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>AD-8 with real principals: each of the two callers lacking one declared pair is refused 403
/// <code>AUTH.NOPRIVILEGE</code> on every <code>/ssl</code> route, naming that pair, before anything
/// is read, tested or written; the probe reads back unchanged and the create's name stays
/// absent.</p>
/// <p>Mutation (Rule 19): delete the <code>Gate</code> call from
/// <method>OcuPilot.Area.Security.SslRules.HandleTest</method> -> the Test route passes the gate and
/// this goes red.</p>
Method TestACallerLackingAPairIsRefusedOnEveryRoute()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSegment = ##class(OcuPilot.Kernel.EntityId).Encode(..#PROBE)
    Set tBefore = ..Stored(..#PROBE)
    Do $$$AssertTrue(tBefore '= "", "the probe reads before the requests")
    Set tCreate = {"Name": (..#NEWPROBE), "Type": 0, "VerifyPeer": 0, "Enabled": true, "Description": (..#PROBEMARKER)}
    Set tRoutes = $ListBuild($ListBuild("GET", "/ssl/form?name=" _ ..#PROBE, ""))
    Set tRoutes = tRoutes _ $ListBuild($ListBuild("GET", "/ssl/name?name=" _ ..#NEWPROBE, ""))
    Set tRoutes = tRoutes _ $ListBuild($ListBuild("POST", "/ssl/" _ tSegment _ "/test", "{""Host"":""localhost"",""Port"":1}"))
    Set tRoutes = tRoutes _ $ListBuild($ListBuild("PUT", "/ssl/" _ tSegment, "{""Description"":""" _ ..#PROBEMARKER _ " changed""}"))
    Set tRoutes = tRoutes _ $ListBuild($ListBuild("POST", "/ssl", tCreate.%ToJSON()))
    For tCaller = $ListBuild(..#NOSECUREUSER, "%Admin_Secure:USE"), $ListBuild(..#NOSYSREADUSER, "%DB_IRISSYS:READ") {
        Set tUser = $List(tCaller, 1)
        For tI = 1:1:$ListLength(tRoutes) {
            Set tMethod = $List($List(tRoutes, tI), 1)
            Set tPath = tBase _ $List($List(tRoutes, tI), 2)
            Set tBody = $List($List(tRoutes, tI), 3)
            Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(tMethod, tPath, tUser, ..PreparedPassword, .tStatus, .tAnswer, .tHeaders, tBody, $Select(tBody = "": "", 1: "application/json"))
            Set tLabel = tUser _ " " _ tMethod _ " " _ tPath
            Do $$$AssertEquals(tStatus, 403, tLabel _ ": is refused")
            Set tRefusal = ""
            Try { Set tRefusal = ##class(%DynamicObject).%FromJSON(tAnswer) } Catch {}
            Set tSeen = $Select($IsObject(tRefusal): tRefusal.%Get("code") _ " " _ $Select($IsObject(tRefusal.%Get("detail")): tRefusal.%Get("detail").%Get("failedPair"), 1: ""), 1: "")
            Do $$$AssertEquals(tSeen, "AUTH.NOPRIVILEGE " _ $List(tCaller, 2), tLabel _ ": on the screen-privilege code naming " _ $List(tCaller, 2) _ ", read " _ tSeen)
        }
    }
    Do $$$AssertEquals(..Stored(..#PROBE), tBefore, "the probe reads back unchanged")
    Do $$$AssertEquals(..Stored(..#NEWPROBE), "", "and nothing was created")
}

/// <p>The configuration <var>pName</var>'s stored properties as one string, or <code>""</code> when
/// the instance does not hold it.</p>
ClassMethod Stored(pName As %String) As %String
{
    Set tOut = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        If ##class(Security.SSLConfigs).Exists(pName) {
            Set tSC = ##class(Security.SSLConfigs).Get(pName, .tProps)
            If $$$ISOK(tSC) {
                Kill tProps("PrivateKeyPassword")
                Set tKey = ""
                For {
                    Set tKey = $Order(tProps(tKey))
                    If tKey = "" Quit
                    Set tOut = tOut _ tKey _ "=" _ tProps(tKey) _ "|"
                }
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tOut
}

/// <p>Create the probe client configuration afresh: removed first when it is this class's own,
/// refused when a configuration of that name is anybody else's.</p>
ClassMethod EnsureProbe() As %Status
{
    Set tSC = ..RemoveProbe(..#PROBE)
    If $$$ISERR(tSC) Quit tSC
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProps("Type") = 0
        Set tProps("VerifyPeer") = 0
        Set tProps("Enabled") = 1
        Set tProps("Description") = ..#PROBEMARKER
        Set tSC = ##class(Security.SSLConfigs).Create(..#PROBE, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the configuration <var>pName</var> when its description says it is this class's own; one
/// of that name that is anybody else's is an error and is left alone.</p>
ClassMethod RemoveProbe(pName As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.SSLConfigs).Exists(pName, .tConfig) {
            If $Extract(tConfig.Description, 1, $Length(..#PROBEMARKER)) '= ..#PROBEMARKER {
                Set tSC = $$$ERROR($$$GeneralError, "the SSL/TLS configuration " _ pName _ " is not this class's own, so it was left alone")
            } Else {
                Set tConfig = ""
                Set tSC = ##class(Security.SSLConfigs).Delete(pName)
            }
        }
        Set tConfig = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the two throwaway roles and the accounts that hold them, then read the grants back:
/// <parameter>NOSECUREROLE</parameter> -- the install namespace's code read, the system database
/// read and <code>%Admin_Operate</code> -- and <parameter>NOSYSREADROLE</parameter> -- the code read and the secure resource.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCodeRead = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        For tCase = $ListBuild(..#NOSECUREROLE, ..#NOSECUREUSER, tCodeRead _ ",%DB_IRISSYS:R,%Admin_Operate:U"), $ListBuild(..#NOSYSREADROLE, ..#NOSYSREADUSER, tCodeRead _ ",%Admin_Secure:U") {
            Set tRole = $List(tCase, 1)
            Set tUser = $List(tCase, 2)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the SSL/TLS form's pairs less one (throwaway)", $List(tCase, 3), "")
            If $$$ISERR(tSC) Quit
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot SSL/TLS wire test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.SslWire; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#NOSECUREUSER, "%Admin_Secure", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(..#NOSECUREUSER, "%DB_IRISSYS", "READ") '= 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the principal without the secure resource did not read back as the system read alone")
            Quit
        }
        If ($SYSTEM.Security.CheckUserPermission(..#NOSYSREADUSER, "%Admin_Secure", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#NOSYSREADUSER, "%DB_IRISSYS", "READ") = 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the principal without the system read did not read back as the secure resource alone")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
