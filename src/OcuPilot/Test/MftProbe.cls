/// <p>Test-only helper for Story 18.26's suites: the probe managed file transfer connections, the probe OAuth 2.0
/// client configurations and server descriptions they name, the client SSL/TLS configuration they use
/// (<parameter>SSLCONFIG</parameter>, made in <code>%SYS</code>), the instance's connection list as one JSON text
/// (<method>Facts</method>), and the agent's mint through a tool's own class (<method>Mint</method>). It holds no
/// assertions.</p>
/// <p><b>Only <parameter>PREFIX</parameter> is ever touched.</b> A connection and a client configuration are
/// named from it, a description's issuer is on <parameter>HOST</parameter>, and each is removed by exact name.
/// Connections are created and deleted through the real admin port, so a delete removes the client configuration
/// and description the connection names, as the vendor does; <method>RemoveAll</method> then removes whatever
/// that left.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MftProbe Extends %RegisteredObject
{

/// <p>What every probe connection and client configuration name begins with, case included.</p>
Parameter PREFIX = "OcuMftProbe";

/// <p>The host every probe description's issuer names.</p>
Parameter HOST = "ocumftprobe.invalid";

/// <p>The client (Type 0) SSL/TLS configuration every probe connection names. <method>EnsureSsl</method> creates it
/// and <method>RemoveAll</method> removes it, so no test depends on a configuration a stock instance may lack.</p>
Parameter SSLCONFIG = "OcuMftProbeClientTLS";

Parameter ENDPOINT = "Security.MFT";

/// <p>A probe name: <parameter>PREFIX</parameter> and <var>pSuffix</var>.</p>
ClassMethod Name(pSuffix As %String) As %String
{
    Quit ..#PREFIX _ pSuffix
}

/// <p>A body for the connection <var>pName</var>: the five fields, the client configuration named
/// <var>pName</var> followed by <code>App</code>, with each member of <var>pOverrides</var> applied. It first
/// makes the SSL/TLS configuration the body names (<method>EnsureSsl</method>) and throws when that fails.</p>
ClassMethod Body(pName As %String, pOverrides As %DynamicObject = "") As %DynamicObject
{
    $$$ThrowOnError(..EnsureSsl())
    Set tBody = {"Service": "Box", "URL": "https://api.box.ocumftprobe.invalid/", "SSLConfiguration": (..#SSLCONFIG), "Username": "probe@ocumftprobe.invalid", "ApplicationName": (pName _ "App")}
    If $IsObject(pOverrides) {
        Set tIterator = pOverrides.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Do tBody.%Set(tKey, tValue)
        }
    }
    Quit tBody
}

/// <p>Create the client SSL/TLS configuration <parameter>SSLCONFIG</parameter> in <code>%SYS</code> when the
/// instance holds none of that name; a second call changes nothing.</p>
ClassMethod EnsureSsl() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Security.SSLConfigs).Exists(..#SSLCONFIG) {
            Set tProps("Description") = "OcuPilot MFT probe client configuration"
            Set tProps("Type") = 0
            Set tSC = ##class(Security.SSLConfigs).Create(..#SSLCONFIG, .tProps)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether the instance holds <parameter>SSLCONFIG</parameter>: <code>1</code> or <code>0</code>, and
/// <code>-1</code> when it cannot be read.</p>
ClassMethod HoldsSsl() As %Integer
{
    Set tHolds = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tHolds = ''##class(Security.SSLConfigs).Exists(..#SSLCONFIG)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tHolds
}

/// <p><var>pId</var> as one query-string value or route-target segment, percent-encoded once: the route target
/// receives one decode less than <method>OcuPilot.Kernel.EntityId.Encode</method> answers.</p>
ClassMethod QueryId(pId As %String) As %String
{
    Quit $ZConvert($ZConvert(pId, "O", "UTF8"), "O", "URL")
}

/// <p>Create the probe connection <var>pName</var> through the real admin port with <method>Body</method>.</p>
ClassMethod Seed(pName As %String, pOverrides As %DynamicObject = "") As %Status
{
    If $Extract(pName, 1, $Length(..#PREFIX)) '= ..#PREFIX Quit $$$ERROR($$$GeneralError, "only a name beginning " _ ..#PREFIX _ " is written")
    Kill tQuery
    Set tQuery("connection") = pName
    Quit ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "PUT", .tQuery, ..Body(pName, pOverrides), .tResult, .tHttp, .tFault)
}

/// <p>The connection <var>pName</var> as the vendor's <code>GET</code> reads it, or <code>""</code>.</p>
ClassMethod Stored(pName As %String) As %DynamicObject
{
    Kill tQuery
    Set tQuery("connection") = pName
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRead)) Quit ""
    Quit tRead
}

/// <p>The instance's connection list, as the vendor's <code>LIST</code> answers it, as JSON text: the state a
/// test must leave as it found it.</p>
ClassMethod Facts() As %String
{
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit "unreadable"
    Quit tRows.%ToJSON()
}

/// <p>The names of the probe connections the instance lists, as a <class>%List</class>.</p>
ClassMethod Names() As %List
{
    Set tNames = ""
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tRows)) Quit tNames
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Extract(tRow.%Get("Name"), 1, $Length(..#PREFIX)) = ..#PREFIX Set tNames = tNames _ $ListBuild(tRow.%Get("Name"))
    }
    Quit tNames
}

/// <p>Make the probe OAuth 2.0 client configuration <var>pName</var> and a description on
/// <parameter>HOST</parameter> for it, through the vendor classes.</p>
ClassMethod AddClient(pName As %String) As %Status
{
    If $Extract(pName, 1, $Length(..#PREFIX)) '= ..#PREFIX Quit $$$ERROR($$$GeneralError, "only a name beginning " _ ..#PREFIX _ " is written")
    Set tSC = ##class(OcuPilot.Test.OAuthClientProbe).AddServer("https://" _ ..#HOST _ "/" _ pName, .tServerId)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Test.OAuthClientProbe).AddClient(pName, tServerId)
}

/// <p>Whether the client configuration <var>pName</var> exists.</p>
ClassMethod HoldsClient(pName As %String) As %Boolean
{
    Quit ##class(OcuPilot.Test.OAuthClientProbe).Holds(pName)
}

/// <p>How many server descriptions the probe host has.</p>
ClassMethod Descriptions() As %Integer
{
    Quit $ListLength(..DescriptionIds())
}

/// <p>The ids of the descriptions whose issuer is on <parameter>HOST</parameter>.</p>
ClassMethod DescriptionIds() As %List
{
    Set tIds = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, IssuerEndpoint FROM OAuth2.ServerDefinition")
        While tResult.%Next() {
            If $Piece($Piece($Piece($Piece(tResult.%GetData(2), "://", 2), "/", 1), "?", 1), "#", 1) = ..#HOST Set tIds = tIds _ $ListBuild(tResult.%GetData(1))
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tIds
}

/// <p>The probe client configurations' names, as a <class>%List</class>.</p>
ClassMethod Clients() As %List
{
    Set tNames = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(ApplicationName) FROM OAuth2.Client WHERE %EXACT(ApplicationName) %STARTSWITH ?", ..#PREFIX)
        While tResult.%Next() { Set tNames = tNames _ $ListBuild(tResult.%GetData(1)) }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tNames
}

/// <p>Delete every probe connection by exact name, then every probe client configuration by exact name, then
/// every description on <parameter>HOST</parameter> by id, then the client SSL/TLS configuration, then clear the system monitor: the vendor answers
/// the delete of a connection whose client is absent 500, which the admin port logs at severity 2, raising the
/// instance's alert state, and only a clear resets it.</p>
ClassMethod RemoveAll() As %Status
{
    Set tSC = $$$OK
    Set tNames = ..Names()
    For tI = 1:1:$ListLength(tNames) {
        Kill tQuery
        Set tQuery("connection") = $List(tNames, tI)
        Do ##class(OcuPilot.Port.AdminPort).Invoke(..#ENDPOINT, "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    }
    Set tClients = ..Clients()
    Set tIds = ..DescriptionIds()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$ListLength(tClients) Set tSC = $$$ADDSC(tSC, ##class(OAuth2.Client).DeleteId($List(tClients, tI)))
        For tI = 1:1:$ListLength(tIds) Set tSC = $$$ADDSC(tSC, ##class(OAuth2.ServerDefinition).DeleteId($List(tIds, tI)))
        If ##class(Security.SSLConfigs).Exists(..#SSLCONFIG) Set tSC = $$$ADDSC(tSC, ##class(Security.SSLConfigs).Delete(..#SSLCONFIG))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Do $SYSTEM.Monitor.Clear()
    Quit tSC
}

/// <p>How many probe connections, client configurations and descriptions the instance holds.</p>
ClassMethod Remaining() As %Integer
{
    Quit $ListLength(..Names()) + $ListLength(..Clients()) + ..Descriptions()
}

/// <p>Mint the proposal for the tool <var>pToolClass</var> over <var>pArgs</var> through the tool's own mint class,
/// as the agent's call does, naming the target <var>pName</var>. <var>pProblem</var> is the refusal's problem or
/// code.</p>
ClassMethod Mint(pToolClass As %String, pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pProblem As %String, pUser As %String = {$Username}) As %Status
{
    Set pProposal = ""
    Set pHttp = 0
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod($ClassMethod(pToolClass, "MintClass"), "Mint", $Parameter(pToolClass, "DESCRIPTORCLASS"), $Parameter(pToolClass, "TOOLNAME"), pUser, "", tTurnKey, pArgs, "OcuPilot.Kernel.Agent.Limits", .tResult, .pHttp, .tFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pName, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
    If $IsObject($Get(tResult)) Set pProposal = tResult
    If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set pProblem = tFault.%Get("detail").%Get("problem")
    If $IsObject($Get(tFault)) && (pProblem = "") Set pProblem = tFault.%Get("code")
    If '$IsObject(pProposal) Quit $$$ERROR($$$GeneralError, "the mint answered no proposal: " _ pHttp _ " " _ pProblem)
    Quit $$$OK
}

}
