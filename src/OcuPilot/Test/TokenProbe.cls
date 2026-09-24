/// <p>The fixture <class>OcuPilot.Test.TokenRevoke</class> and <file>ui/browser/token-revoke.browser-spec.mjs</file>
/// revoke against: two probe accounts, a least-privileged principal and four
/// <code>OAuth2.Server.AccessToken</code> rows in <code>%SYS</code> -- two issued to
/// <parameter>HOLDER</parameter>, one to its lower-cased spelling <parameter>RECASED</parameter> and
/// one to <parameter>OTHER</parameter>.</p>
/// <p><b>The token rows stand in for issuance.</b> A throwaway runs no authorization server, so the
/// rows are saved directly, each keyed by an authorization code under <parameter>PREFIX</parameter>.
/// No row carries an access token, a hash or a refresh token.</p>
/// <p><b>Throwaway only, enforced</b>: <method>Create</method> refuses unless
/// <parameter>ARMINGVARIABLE</parameter> reads <code>1</code>, which only
/// <file>scripts/ci-throwaway.sh</file> sets. <method>Remove</method> deletes every object by its
/// exact name, and an account or role that does not carry <parameter>MARKER</parameter> is left
/// alone.</p>
Class OcuPilot.Test.TokenProbe Extends %RegisteredObject
{

/// <p>The environment variable that arms <method>Create</method>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The authorization-code prefix every probe token row is keyed under.</p>
Parameter PREFIX = "OcuPilotTestRevoke";

/// <p>The account holding two tokens, the spelling one more token was issued under, and the account
/// holding one.</p>
Parameter HOLDER = "OcuPilotTestRevoke";

Parameter RECASED = "ocupilottestrevoke";

Parameter OTHER = "OcuPilotTestRevokeOther";

/// <p>The principal holding the Users list's two pairs and the install namespace's code read, and
/// not <code>%Admin_OAuth2_Registration:USE</code>; and its role.</p>
Parameter PRINCIPAL = "OcuPilotTestRevokePrincipal";

Parameter PRINCIPALROLE = "OcuPilotTestRevokePrincipalRole";

/// <p>The comment and description every probe account and role carries, which
/// <method>Remove</method> requires before it deletes one.</p>
Parameter MARKER = "OcuPilot token revoke probe";

/// <p>The token rows, as comma-separated <code>&lt;authorization code&gt;:&lt;user name&gt;</code>
/// entries.</p>
Parameter TOKENS = "OcuPilotTestRevoke1:OcuPilotTestRevoke,OcuPilotTestRevoke2:OcuPilotTestRevoke,OcuPilotTestRevoke3:ocupilottestrevoke,OcuPilotTestRevoke4:OcuPilotTestRevokeOther";

/// <p>Create the accounts, the principal and the token rows after removing any left from an earlier
/// run, and answer the principal's password, generated for this run, in <var>pPassword</var>. The
/// principal's grants are read back: it must hold <code>%Admin_Secure:USE</code> and
/// <code>%DB_IRISSYS:READ</code> and must not hold <code>%Admin_OAuth2_Registration:USE</code>.</p>
ClassMethod Create(Output pPassword As %String) As %Status
{
    Set pPassword = ""
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TokenProbe creates users, a role and OAuth 2.0 token rows and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ..Remove()
    If $$$ISERR(tSC) Quit tSC
    Set tCode = ..CodeDatabaseResource()
    If tCode = "" Quit $$$ERROR($$$GeneralError, "the install namespace's code database resource could not be resolved")
    Set tPassword = "Ocu" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18)), "+/=", "xyz") _ "9a"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Roles).Create(..#PRINCIPALROLE, ..#MARKER, tCode _ ":R,%Admin_Secure:U,%DB_IRISSYS:R", "")
        If $$$ISERR(tSC) Quit
        For tCase = $ListBuild(..#HOLDER, ""), $ListBuild(..#OTHER, ""), $ListBuild(..#PRINCIPAL, ..#PRINCIPALROLE) {
            Set tSC = ##class(Security.Users).Create($List(tCase, 1), $List(tCase, 2), tPassword, $List(tCase, 1) _ " probe", "", "", "", 0, 1, ..#MARKER)
            If $$$ISERR(tSC) Quit
        }
        If $$$ISERR(tSC) Quit
        If ($SYSTEM.Security.CheckUserPermission(..#PRINCIPAL, "%Admin_Secure", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#PRINCIPAL, "%DB_IRISSYS", "READ") '= 1) || ($SYSTEM.Security.CheckUserPermission(..#PRINCIPAL, "%Admin_OAuth2_Registration", "USE") = 1) {
            Set tSC = $$$ERROR($$$GeneralError, "the probe principal " _ ..#PRINCIPAL _ "'s grants did not read back as declared")
            Quit
        }
        Set tExpires = $ZDateTime($ZTimeStamp, -2) + 86400
        For tI = 1:1:$Length(..#TOKENS, ",") {
            Set tEntry = $Piece(..#TOKENS, ",", tI)
            Set tToken = ##class(OAuth2.Server.AccessToken).%New()
            Set tToken.AuthorizationCode = $Piece(tEntry, ":", 1)
            Set tToken.Username = $Piece(tEntry, ":", 2)
            Set tToken.ClientId = ..#PREFIX
            Set tToken.AccessTokenExpires = tExpires
            Set tSC = tToken.%Save()
            Set tToken = ""
            If $$$ISERR(tSC) Quit
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    If $$$ISERR(tSC) {
        Do ..Remove()
        Quit tSC
    }
    Set pPassword = tPassword
    Quit $$$OK
}

/// <p>How many token rows in <code>%SYS</code> carry the user name <var>pName</var> exactly, case
/// included; <code>-1</code> when the count cannot be read.</p>
ClassMethod Count(pName As %String) As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM OAuth2_Server.AccessToken WHERE %EXACT(Username) = ?", pName)
        If (tRS.%SQLCODE = 0) && tRS.%Next() Set tCount = +tRS.%Get("N")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tCount = -1
    }
    Quit tCount
}

/// <p>Delete every token row <parameter>TOKENS</parameter> names by its exact authorization code,
/// then the three accounts and the role by exact name, each only where it carries
/// <parameter>MARKER</parameter>. An object already gone is not an error.</p>
ClassMethod Remove() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#TOKENS, ",") {
            Set tId = $Piece($Piece(..#TOKENS, ",", tI), ":", 1)
            If '##class(OAuth2.Server.AccessToken).%ExistsId(tId) Continue
            Set tToken = ##class(OAuth2.Server.AccessToken).%OpenId(tId, , .tOpenSC)
            If '$IsObject(tToken) {
                Set tSC = $$$ADDSC(tSC, tOpenSC)
                Continue
            }
            Set tSC = $$$ADDSC(tSC, tToken.Delete())
            Set tToken = ""
        }
        For tName = ..#HOLDER, ..#OTHER, ..#PRINCIPAL {
            If '##class(Security.Users).Exists(tName) Continue
            Kill tProps
            If $$$ISOK(##class(Security.Users).Get(tName, .tProps)) && ($Get(tProps("Comment")) = ..#MARKER) {
                Set tSC = $$$ADDSC(tSC, ##class(Security.Users).Delete(tName))
            } Else {
                Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the account " _ tName _ " is not this fixture's own, so it was left alone"))
            }
        }
        If ##class(Security.Roles).Exists(..#PRINCIPALROLE) {
            Kill tProps
            If $$$ISOK(##class(Security.Roles).Get(..#PRINCIPALROLE, .tProps)) && ($Get(tProps("Description")) = ..#MARKER) {
                Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete(..#PRINCIPALROLE))
            } Else {
                Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the role " _ ..#PRINCIPALROLE _ " is not this fixture's own, so it was left alone"))
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The resource guarding the install namespace's code database, whose read a principal needs to
/// reach OcuPilot's dispatch class at all (AD-9, AD-21), or <code>""</code>.</p>
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
