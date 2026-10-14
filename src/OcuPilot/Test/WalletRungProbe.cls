/// <p>Test-only helper for the wallet credential rung's suites: the probe collection, its use resource, its secrets
/// and its three principals, and the child process <class>OcuPilot.Test.WalletRung</class> starts to resolve as one of
/// them (AD-8). It extends <class>OcuPilot.Test.WalletProbe</class> for the collection and secret helpers, over its own
/// collection <parameter>COLLECTION</parameter>, and creates and removes every object by exact name.</p>
/// <p>The child process logs in as the principal and runs each step of a plan in the process, so the rung's checks see
/// that principal's roles. It signals <code>{matches, transient, refusal}</code> for a resolution and never the value:
/// <code>matches</code> is the resolution compared with the step's expected text inside the comparison.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.WalletRungProbe Extends OcuPilot.Test.WalletProbe
{

Parameter COLLECTION = "OcuPilotProbe1841";

Parameter RESOURCE = "OcuPilotProbe1841Use:USE";

/// <p>The resource <parameter>RESOURCE</parameter> names, without its permission.</p>
Parameter USERESOURCE = "OcuPilotProbe1841Use";

/// <p>The key-value secret with the default uses, which requires TLS, the one with the HTTP use alone, the one holding two
/// members and the symmetric key.</p>
Parameter DEFAULTSECRET = "OcuPilotProbe1841.kv";

Parameter HTTPONLYSECRET = "OcuPilotProbe1841.http";

Parameter MULTISECRET = "OcuPilotProbe1841.multi";

Parameter SYMMETRICSECRET = "OcuPilotProbe1841.sym";

/// <p>The key-value secret no resolution names: a refused direct vendor call on it writes the control row the suites
/// wait for before they count rows naming the others.</p>
Parameter CONTROLSECRET = "OcuPilotProbe1841.control";

/// <p>The key-value secret that requires TLS and lists the hosts it may be sent to, and the one that does not require
/// TLS and lists a host: the vendor ignores the list of the second.</p>
Parameter HOSTSECRET = "OcuPilotProbe1841.hostlist";

Parameter OPENSECRET = "OcuPilotProbe1841.opentls";

/// <p>The hosts <parameter>HOSTSECRET</parameter> lists, and the host <parameter>OPENSECRET</parameter> lists.</p>
Parameter LISTEDHOSTS = "api.allowed.test,second.allowed.test,[2001:db8::1]";

Parameter OPENHOSTS = "only.listed.test";

/// <p>The endpoint a resolution is made for when its step names none: https, and a host no list names.</p>
Parameter ENDPOINT = "https://wallet-rung.example.test/v1/messages";

/// <p>The vendor audit event the wallet writes a use row under, and the one it writes a refusal under.</p>
Parameter USEEVENT = "WalletSecretUse";

Parameter DENIEDEVENT = "AccessDenied";

/// <p>The principals, each <code>user:role:pairs</code> beyond the install namespace's code read: the holder has the
/// collection's use resource, the outsider nothing, and the administrator <code>%Admin_Wallet:USE</code>.</p>
Parameter PRINCIPALS = "OCUPROBE1841HOLDER:OCUPROBE1841HOLDERROLE:OcuPilotProbe1841Use:U,OCUPROBE1841NONE:OCUPROBE1841NONEROLE:,OCUPROBE1841ADMIN:OCUPROBE1841ADMINROLE:%Admin_Wallet:U";

/// <p>Whether <var>pName</var> is a name this class creates: it begins with the probe prefix, upper-cased.</p>
ClassMethod IsProbe(pName As %String) As %Boolean
{
    Quit ($Extract($ZConvert(pName, "U"), 1, 12) = "OCUPROBE1841") || ($Extract($ZConvert(pName, "U"), 1, 17) = "OCUPILOTPROBE1841")
}

/// <p>The principal of entry <var>pIndex</var> of <parameter>PRINCIPALS</parameter>.</p>
ClassMethod User(pIndex As %Integer) As %String
{
    Quit $Piece($Piece(..#PRINCIPALS, ",", pIndex), ":", 1)
}

/// <p>Create the use resource, the collection, every secret this class names and the three principals. The key-value
/// secrets hold <var>pValue</var> (the multi-member one as a member) but the control secret, which holds its own text, and
/// the principals take the password <var>pPassword</var>.</p>
ClassMethod SeedAll(pValue As %String, pPassword As %String) As %Status
{
    Set tSC = ..EnsureResource()
    If $$$ISOK(tSC) Set tSC = ..EnsureCollection()
    If $$$ISOK(tSC) Set tSC = ..AddKeyValue(..#DEFAULTSECRET, {"Secret": (pValue), "Usage": 15, "RequireTLS": true})
    If $$$ISOK(tSC) Set tSC = ..AddKeyValue(..#HTTPONLYSECRET, {"Secret": (pValue), "Usage": 1})
    If $$$ISOK(tSC) Set tSC = ..AddKeyValue(..#MULTISECRET, {"Secret": {"first": (pValue), "second": "two"}, "Usage": 15})
    If $$$ISOK(tSC) Set tSC = ..AddSymmetricKey(..#SYMMETRICSECRET)
    If $$$ISOK(tSC) Set tSC = ..AddKeyValue(..#CONTROLSECRET, {"Secret": "control", "Usage": 15})
    If $$$ISOK(tSC) Set tSC = ..AddKeyValue(..#HOSTSECRET, {"Secret": (pValue), "Usage": 15, "RequireTLS": true, "AllowedHosts": (..HostArray(..#LISTEDHOSTS))})
    If $$$ISOK(tSC) Set tSC = ..AddKeyValue(..#OPENSECRET, {"Secret": (pValue), "Usage": 15, "RequireTLS": false, "AllowedHosts": (..HostArray(..#OPENHOSTS))})
    For tI = 1:1:$Length(..#PRINCIPALS, ",") {
        If $$$ISERR(tSC) Quit
        Set tEntry = $Piece(..#PRINCIPALS, ",", tI)
        Set tSC = ..SeedPrincipal($Piece(tEntry, ":", 1), $Piece(tEntry, ":", 2), $Piece(tEntry, ":", 3, *), pPassword)
    }
    Quit tSC
}

/// <p>The comma-separated host list <var>pHosts</var> as the array the wallet takes for <code>AllowedHosts</code>.</p>
ClassMethod HostArray(pHosts As %String) As %DynamicArray
{
    Set tHosts = []
    For tI = 1:1:$Length(pHosts, ",") {
        Do tHosts.%Push($Piece(pHosts, ",", tI))
    }
    Quit tHosts
}

/// <p>Create the use resource, public permission none, unless it exists.</p>
ClassMethod EnsureResource() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Security.Resources).Exists(..#USERESOURCE) Set tSC = ##class(Security.Resources).Create(..#USERESOURCE, "OcuPilot wallet rung probe (throwaway)", "")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Create the probe user <var>pUser</var> over the role <var>pRole</var>, which holds read on the install
/// namespace's code database and <var>pResources</var>, a comma-separated <code>resource:permission</code> list.</p>
ClassMethod SeedPrincipal(pUser As %String, pRole As %String, pResources As %String = "", pPassword As %String = "") As %Status
{
    If '..IsProbe(pUser) || '..IsProbe(pRole) Quit $$$ERROR($$$GeneralError, "a probe principal's names start with OCUPROBE1841")
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
        Set tSC = ##class(Security.Roles).Create(pRole, "OcuPilot wallet rung probe (throwaway)", tCode _ $Select(pResources = "": "", 1: "," _ pResources), "")
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(pUser, pRole, pPassword, "OcuPilot wallet rung probe (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.WalletRungProbe")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Remove every object this class creates, each by its exact name: the secrets and the collection, the users, the
/// roles and the resource. <var>pRemaining</var> is how many survived, and the status is an error when any did.</p>
ClassMethod RemoveAll(Output pRemaining As %Integer) As %Status
{
    Set pRemaining = 0
    Set tSC = ..Remove(.tSecrets)
    Set pRemaining = tSecrets
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ",") {
            Set tEntry = $Piece(..#PRINCIPALS, ",", tI)
            Set tUser = $Piece(tEntry, ":", 1)
            Set tRole = $Piece(tEntry, ":", 2)
            If ##class(Security.Users).Exists(tUser) Set tSC = $$$ADDSC(tSC, ##class(Security.Users).Delete(tUser))
            If ##class(Security.Roles).Exists(tRole) Set tSC = $$$ADDSC(tSC, ##class(Security.Roles).Delete(tRole))
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tRole) Set pRemaining = pRemaining + 1
        }
        If ##class(Security.Resources).Exists(..#USERESOURCE) Set tSC = $$$ADDSC(tSC, ##class(Security.Resources).Delete(..#USERESOURCE))
        If ##class(Security.Resources).Exists(..#USERESOURCE) Set pRemaining = pRemaining + 1
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>Log in as <var>pUsername</var>, run the JSON array <var>pPlan</var>, and signal <code>{loggedIn, username,
/// steps}</code> to process <var>pParent</var>, or <code>{error}</code>. A step is <code>{kind: "resolve"|"exists",
/// name, expected, endpoint}</code>: <code>resolve</code> answers <code>{matches, transient, refusal}</code>, where
/// <code>refusal</code> is <code>code|detail</code> or <code>""</code>, for a call made to <code>endpoint</code>
/// (<parameter>ENDPOINT</parameter> when the step has no <code>endpoint</code> member; an empty text is an endpoint), and <code>exists</code> asks
/// the wallet whether the secret exists, as a direct vendor call that a caller without the pair is refused, and answers
/// <code>{opened}</code>.</p>
ClassMethod Run(pParent As %Integer, pUsername As %String, pPlan As %String)
{
    Set tOut = {}
    Try {
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUsername), "boolean")
        Do tOut.%Set("username", $Username)
        Set tSteps = []
        Set tIterator = ##class(%DynamicArray).%FromJSON(pPlan).%GetIterator()
        While tIterator.%GetNext(.tIndex, .tStep) {
            Do tSteps.%Push(..Step(tStep))
        }
        Do tOut.%Set("steps", tSteps)
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>Run one step of a plan.</p>
ClassMethod Step(pStep As %DynamicObject) As %DynamicObject
{
    Set tLeg = {}
    Try {
        If pStep.%Get("kind") = "exists" {
            Do tLeg.%Set("opened", ''##class(%Wallet.Secret).Exists(pStep.%Get("name"), .tSecret), "boolean")
            Set tSecret = ""
            Quit
        }
        Set tEndpoint = $Select(pStep.%IsDefined("endpoint"): pStep.%Get("endpoint"), 1: ..#ENDPOINT)
        Set tMatches = (##class(OcuPilot.Kernel.Secret.Ladder).Resolve("wallet", "", pStep.%Get("name"), .tTransient, .tRefusal, tEndpoint) = pStep.%Get("expected"))
        Do tLeg.%Set("matches", ''tMatches, "boolean")
        Do tLeg.%Set("transient", ''tTransient, "boolean")
        Do tLeg.%Set("refusal", $Select($ListValid(tRefusal): $ListToString(tRefusal, "|"), 1: ""), "string")
    } Catch ex {
        Do tLeg.%Set("error", ex.DisplayString())
    }
    Quit tLeg
}

/// <p>Whether the vendor audit event <parameter>USEEVENT</parameter> is enabled, or <code>-1</code> when it cannot be
/// read.</p>
ClassMethod UseEventEnabled() As %Integer
{
    Set tValue = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        If $$$ISOK(##class(Security.Events).Get("%System", "%Security", ..#USEEVENT, .tProps)) Set tValue = ''$Get(tProps("Enabled"))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValue = -1
    }
    Quit tValue
}

/// <p>How many <code>AccessDenied</code> rows since <var>pSince</var> name the secret <var>pSecret</var>, which the
/// vendor's refusal row carries in its data, so a row this suite did not cause is not counted. With <var>pWait</var>, a
/// zero is asked again for up to five seconds: the first row can take a moment to be readable.</p>
ClassMethod DeniedRows(pSince As %String, pSecret As %String, pWait As %Boolean = 0) As %Integer
{
    Quit ..RowsNaming(pSince, ..#DENIEDEVENT, pSecret _ " ", pWait)
}

/// <p>How many <code>WalletSecretUse</code> rows since <var>pSince</var> name the secret <var>pSecret</var>, with
/// <var>pWait</var> as <method>DeniedRows</method> takes it.</p>
ClassMethod UseRows(pSince As %String, pSecret As %String, pWait As %Boolean = 0) As %Integer
{
    Quit ..RowsNaming(pSince, ..#USEEVENT, pSecret, pWait)
}

/// <p>How many rows of the vendor audit event <var>pEvent</var> since <var>pSince</var> carry <var>pText</var>.</p>
ClassMethod RowsNaming(pSince As %String, pEvent As %String, pText As %String, pWait As %Boolean = 0) As %Integer
{
    Set tRows = ##class(OcuPilot.Test.AuditingUpdate).VendorRows(pSince, pEvent, pText, .tStamp)
    If pWait && (tRows < 1) {
        For tTry = 1:1:50 {
            Hang 0.1
            Set tRows = ##class(OcuPilot.Test.AuditingUpdate).VendorRows(pSince, pEvent, pText, .tStamp)
            If tRows > 0 Quit
        }
    }
    Quit tRows
}

/// <p>Turn the vendor audit event <parameter>USEEVENT</parameter> on or off.</p>
ClassMethod SetUseEvent(pEnabled As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tProps("Enabled") = ''pEnabled
        Set tSC = ##class(Security.Events).Modify("%System", "%Security", ..#USEEVENT, .tProps)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
