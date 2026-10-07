/// <p>Test-only helper for Story 18.8's authentication options suites: the instance's authentication state as
/// one JSON object (<method>Facts</method>), restored exactly (<method>Restore</method>), and the probe
/// principals the gate suite signs in as. It holds no assertions.</p>
/// <p>The facts read in <code>%SYS</code> by explicit save and restore: the raw system <code>AutheEnabled</code>,
/// the cookie and two-factor settings, the SMTP server, user and from address, whether an SMTP password is
/// stored (its length only), the JWT issuer and algorithm, a SHA-256 prefix of each key set (never the keys),
/// the monitor state, and the <code>AutheEnabled</code> of OcuPilot's three applications and
/// <code>%Service_WebGateway</code>. A restore writes only the values that differ, so an unchanged
/// <code>JWTSigAlg</code> is never sent and the key sets are never replaced.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AuthOptionsProbe Extends %RegisteredObject
{

Parameter APPLICATIONS = "/ocupilot,/api/ocupilot,/api/ocupilot/readiness";

Parameter SERVICE = "%Service_WebGateway";

/// <p>The probe principals, each <code>user:role</code>: the holder of Security's two pairs, the one without
/// Security's resource and the one without the system database's read.</p>
Parameter PRINCIPALS = "OcuProbe188H:OcuProbe188HR,OcuProbe188O:OcuProbe188OR,OcuProbe188N:OcuProbe188NR";

/// <p>The authentication state, as <code>{raw, LoginCookieTimeout, TwoFactorTimeout, SMTPServer,
/// SMTPUsername, TwoFactorFrom, smtpPasswordLength, JWTIssuer, JWTSigAlg, publicKeys, privateKeys,
/// monitor, applications{path: mask}, service}</code>.</p>
ClassMethod Facts() As %DynamicObject
{
    Set tOut = {}
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.System).Get("SYSTEM", .tProps)
        If $$$ISERR(tSC) {
            Do tOut.%Set("error", $System.Status.GetErrorText(tSC), "string")
        } Else {
            Do tOut.%Set("raw", +tProps("AutheEnabled"), "number")
            For tName = "LoginCookieTimeout", "TwoFactorTimeout" Do tOut.%Set(tName, +tProps(tName), "number")
            For tName = "SMTPServer", "SMTPUsername", "TwoFactorFrom", "JWTIssuer", "JWTSigAlg" Do tOut.%Set(tName, tProps(tName), "string")
            Do tOut.%Set("smtpPasswordLength", $Length(tProps("SMTPPassword")), "number")
            Do tOut.%Set("publicKeys", $Extract($System.Encryption.Base64Encode($System.Encryption.SHAHash(256, tProps("PublicJWKS"))), 1, 12), "string")
            Do tOut.%Set("privateKeys", $Extract($System.Encryption.Base64Encode($System.Encryption.SHAHash(256, tProps("PrivateJWKS"))), 1, 12), "string")
            Do tOut.%Set("monitor", $SYSTEM.Monitor.State(), "number")
            Set tApps = {}
            For tI = 1:1:$Length(..#APPLICATIONS, ",") {
                Set tPath = $Piece(..#APPLICATIONS, ",", tI)
                If $$$ISOK(##class(Security.Applications).Get(tPath, .tApp)) Do tApps.%Set(tPath, +tApp("AutheEnabled"), "number")
            }
            Do tOut.%Set("applications", tApps)
            If $$$ISOK(##class(Security.Services).Get(..#SERVICE, .tService)) Do tOut.%Set("service", +tService("AutheEnabled"), "number")
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do tOut.%Set("error", ex.DisplayString(), "string")
    }
    Quit tOut
}

/// <p>Write back every value of <var>pFacts</var> the instance now holds differently, and clear a stored SMTP
/// password the facts held none of.</p>
ClassMethod Restore(pFacts As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.System).Get("SYSTEM", .tProps)
        If $$$ISERR(tSC) Quit
        Kill tWrite
        Set tWrite("AutheEnabled") = pFacts.%Get("raw")
        If +tProps("AutheEnabled") = +pFacts.%Get("raw") Kill tWrite("AutheEnabled")
        For tName = "LoginCookieTimeout", "TwoFactorTimeout", "SMTPServer", "SMTPUsername", "TwoFactorFrom", "JWTIssuer", "JWTSigAlg" {
            If (tProps(tName) _ "") '= (pFacts.%Get(tName) _ "") Set tWrite(tName) = pFacts.%Get(tName)
        }
        If ($Length(tProps("SMTPPassword")) > 0) && (pFacts.%Get("smtpPasswordLength") = 0) Set tWrite("SMTPPassword") = ""
        If $Data(tWrite) Set tSC = ##class(Security.System).Modify("SYSTEM", .tWrite)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the probe role <var>pRole</var> granting <var>pResources</var> (the
/// <class>Security.Roles</class> form, comma-separated) plus read on the install namespace's routines
/// database, and the probe account <var>pUser</var> holding it alone with password <var>pPassword</var>,
/// replacing either when it exists. Only a name <parameter>PRINCIPALS</parameter> lists is created.</p>
ClassMethod SeedPrincipal(pUser As %String, pRole As %String, pResources As %String, pPassword As %String) As %Status
{
    If '$ListFind(..Users(), pUser) || '$ListFind(..Roles(), pRole) Quit $$$ERROR($$$GeneralError, "only a principal " _ ..#PRINCIPALS _ " lists is created")
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set $NAMESPACE = "%SYS"
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCode = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        Set tNamespace = ""
        Set tDatabase = ""
        If ##class(Security.Users).Exists(pUser) Do ##class(Security.Users).Delete(pUser)
        If ##class(Security.Roles).Exists(pRole) Do ##class(Security.Roles).Delete(pRole)
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot Story 18.8 probe (throwaway)", tCode _ $Select(pResources = "": "", 1: "," _ pResources), "")
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(pUser, pRole, pPassword, "OcuPilot Story 18.8 probe (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.AuthOptionsProbe")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete every principal <parameter>PRINCIPALS</parameter> lists, by exact name.</p>
ClassMethod RemoveAll() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tUsers = ..Users()
        For tI = 1:1:$ListLength(tUsers) {
            If ##class(Security.Users).Exists($List(tUsers, tI)) Set tSC = $$$ADDSC(tSC, ##class(Security.Users).Delete($List(tUsers, tI)))
        }
        Set tRoles = ..Roles()
        For tI = 1:1:$ListLength(tRoles) {
            If ##class(Security.Roles).Exists($List(tRoles, tI)) Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete($List(tRoles, tI)))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>How many principals <parameter>PRINCIPALS</parameter> lists the instance still holds.</p>
ClassMethod Remaining() As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set tLeft = 0
    Try {
        Set $NAMESPACE = "%SYS"
        Set tUsers = ..Users()
        For tI = 1:1:$ListLength(tUsers) Set tLeft = tLeft + ##class(Security.Users).Exists($List(tUsers, tI))
        Set tRoles = ..Roles()
        For tI = 1:1:$ListLength(tRoles) Set tLeft = tLeft + ##class(Security.Roles).Exists($List(tRoles, tI))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tLeft = -1
    }
    Quit tLeft
}

/// <p>The users <parameter>PRINCIPALS</parameter> lists.</p>
ClassMethod Users() As %List
{
    Set tOut = ""
    For tI = 1:1:$Length(..#PRINCIPALS, ",") Set tOut = tOut _ $ListBuild($Piece($Piece(..#PRINCIPALS, ",", tI), ":", 1))
    Quit tOut
}

/// <p>The roles <parameter>PRINCIPALS</parameter> lists.</p>
ClassMethod Roles() As %List
{
    Set tOut = ""
    For tI = 1:1:$Length(..#PRINCIPALS, ",") Set tOut = tOut _ $ListBuild($Piece($Piece(..#PRINCIPALS, ",", tI), ":", 2))
    Quit tOut
}

}
