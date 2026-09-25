/// <p>Makes, reads and removes the OAuth 2.0 server descriptions Story 12.4's tests write against on
/// a throwaway instance: descriptions whose issuer begins <parameter>PREFIX</parameter>, the issuer
/// of <class>OcuPilot.Test.OAuthIssuerFixture</class>, the client configuration
/// <parameter>CLIENT</parameter> and the resource server <parameter>RESOURCE</parameter>. Nothing
/// else is touched, and everything is removed by exact name.</p>
/// <p>The vendor calls run in <code>%SYS</code> by explicit save and restore (AD-16). A stored
/// registration access token is read back as its length alone. The SSL/TLS configuration and the
/// X.509 credential are the demo fixture's, so the instance needs the demo.</p>
Class OcuPilot.Test.OAuthServerProbe Extends %RegisteredObject
{

/// <p>The issuer prefix every probe description carries.</p>
Parameter PREFIX = "https://ocupilotprobe124.invalid/";

/// <p>The demo fixture's SSL/TLS configuration and X.509 credential.</p>
Parameter SSLCONFIG = "OcuPilotDemoTLS";

Parameter CREDENTIAL = "OcuPilotDemoCert";

/// <p>The client configuration and the resource server a test attaches to a description.</p>
Parameter CLIENT = "OcuPilotProbe124Client";

Parameter RESOURCE = "OcuPilotProbe124Resource";

/// <p>A probe issuer: <parameter>PREFIX</parameter> and <var>pSuffix</var>.</p>
ClassMethod Issuer(pSuffix As %String) As %String
{
    Quit ..#PREFIX _ pSuffix
}

/// <p>The two required endpoints, and <var>pMore</var>'s members, as a metadata object for
/// <var>pIssuer</var>.</p>
ClassMethod Metadata(pIssuer As %String, pMore As %DynamicObject = "") As %DynamicObject
{
    Set tMetadata = {}
    Do tMetadata.%Set("authorization_endpoint", pIssuer _ "/authorize", "string")
    Do tMetadata.%Set("token_endpoint", pIssuer _ "/token", "string")
    If $IsObject(pMore) {
        Set tIterator = pMore.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If $IsObject(tValue) {
                Do tMetadata.%Set(tKey, tValue)
            } Else {
                Do tMetadata.%Set(tKey, tValue, pMore.%GetTypeOf(tKey))
            }
        }
    }
    Quit tMetadata
}

/// <p>Make description <var>pIssuer</var> through the vendor class, with <var>pMetadata</var>
/// (<method>Metadata</method>'s when empty) and <var>pCredentials</var>.</p>
ClassMethod Add(pIssuer As %String, pMetadata As %DynamicObject = "", pCredentials As %String = "") As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        If '$IsObject(pMetadata) Set pMetadata = ..Metadata(pIssuer)
        Set $NAMESPACE = "%SYS"
        Set tDefinition = ##class(OAuth2.ServerDefinition).%New()
        Set tDefinition.IssuerEndpoint = pIssuer
        Set tDefinition.SSLConfiguration = ..#SSLCONFIG
        Set tDefinition.ServerCredentials = pCredentials
        Do tDefinition.Metadata.ImportJSON(pMetadata)
        Set tSC = tDefinition.%Save()
        Set tDefinition = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Attach client configuration <parameter>CLIENT</parameter> to <var>pIssuer</var>.</p>
ClassMethod AddClient(pIssuer As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDefinition = ##class(OAuth2.ServerDefinition).OpenByIssuer(pIssuer, .tSC)
        If '$IsObject(tDefinition) {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ERROR($$$GeneralError, "no description " _ pIssuer)
            Quit
        }
        Set tClient = ##class(OAuth2.Client).%New()
        Set tClient.ApplicationName = ..#CLIENT
        Set tClient.ClientType = "confidential"
        Set tClient.SSLConfiguration = ..#SSLCONFIG
        Set tClient.ServerDefinition = tDefinition
        Set tClient.RedirectionEndpoint.Host = "localhost"
        Set tSC = tClient.%Save()
        Set (tClient, tDefinition) = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Attach resource server <parameter>RESOURCE</parameter> to <var>pIssuer</var>.</p>
ClassMethod AddResource(pIssuer As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDefinition = ##class(OAuth2.ServerDefinition).OpenByIssuer(pIssuer, .tSC)
        If '$IsObject(tDefinition) {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ERROR($$$GeneralError, "no description " _ pIssuer)
            Quit
        }
        Set tResource = ##class(OAuth2.ResourceServer).%New()
        Set tResource.Name = ..#RESOURCE
        Set tResource.ServerDefinition = tDefinition
        Set tResource.Audiences = $ListBuild("https://ocupilotprobe124.invalid/resource")
        Set tSC = tResource.%Save()
        Set (tResource, tDefinition) = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Whether resource server <parameter>RESOURCE</parameter> exists and names a description id
/// that no longer exists.</p>
ClassMethod ResourceDangles() As %Boolean
{
    Set tDangles = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(OAuth2.ResourceServer).Exists(..#RESOURCE, .tResource, .tSC) {
            Set tId = tResource.ServerDefinitionGetObjectId()
            Set tDangles = (tId '= "") && '##class(OAuth2.ServerDefinition).%ExistsId(tId)
        }
        Set tResource = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tDangles = 0
    }
    Quit tDangles
}

/// <p>Whether a description carries <var>pIssuer</var>.</p>
ClassMethod Holds(pIssuer As %String) As %Boolean
{
    Set tHolds = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tHolds = $IsObject(##class(OAuth2.ServerDefinition).OpenByIssuer(pIssuer, .tSC))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tHolds
}

/// <p>How many descriptions the instance holds.</p>
ClassMethod Count() As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OAuth2.ServerDefinition")
        If (tResult.%SQLCODE = 0) && tResult.%Next() Set tCount = tResult.%GetData(1)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCount
}

/// <p>Description <var>pIssuer</var> as stored: <code>{IssuerEndpoint, SSLConfiguration,
/// ServerCredentials, Metadata, PublicJWKS, TokenLength, IsDiscovery}</code>, or <code>""</code>. The
/// token is answered as its length alone.</p>
ClassMethod Stored(pIssuer As %String) As %DynamicObject
{
    Set tStored = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDefinition = ##class(OAuth2.ServerDefinition).OpenByIssuer(pIssuer, .tSC)
        If $IsObject(tDefinition) {
            Set tStored = {}
            Do tStored.%Set("IssuerEndpoint", tDefinition.IssuerEndpoint, "string")
            Do tStored.%Set("SSLConfiguration", tDefinition.SSLConfiguration, "string")
            Do tStored.%Set("ServerCredentials", tDefinition.ServerCredentials, "string")
            Do tStored.%Set("Metadata", ##class(%DynamicAbstractObject).%FromJSON(tDefinition.Metadata.ExportJSON(0)))
            Do tStored.%Set("PublicJWKS", tDefinition.PublicJWKS, "string")
            Do tStored.%Set("TokenLength", $Length(tDefinition.InitialAccessToken), "number")
            Do tStored.%Set("IsDiscovery", tDefinition.IsDiscovery, "boolean")
        }
        Set tDefinition = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tStored = ""
    }
    Quit tStored
}

/// <p>Remove the probe client configuration and resource server, then every description whose
/// issuer's host is <parameter>PREFIX</parameter>'s under any scheme, path, query or fragment (a
/// malformed rename keeps the probe host) or is the issuer fixture's. <var>pRemaining</var> is how
/// many probe descriptions survive.</p>
ClassMethod RemoveAll(Output pRemaining As %Integer) As %Status
{
    Set tSC = $$$OK
    Set pRemaining = 0
    Set tOrigNS = $NAMESPACE
    Set tFixture = ##class(OcuPilot.Test.OAuthIssuerFixture).Issuer()
    Set tHost = $Piece($Piece(..#PREFIX, "://", 2), "/", 1)
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(OAuth2.Client).%ExistsId(..#CLIENT) Set tSC = $$$ADDSC(tSC, ##class(OAuth2.Client).DeleteId(..#CLIENT))
        If ##class(OAuth2.ResourceServer).Exists(..#RESOURCE, .tResource, .tExistsSC) {
            Set tResource = ""
            Set tSC = $$$ADDSC(tSC, ##class(OAuth2.ResourceServer).Delete(..#RESOURCE))
        }
        For tPass = 1, 2 {
            Set tIds = ""
            Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, IssuerEndpoint FROM OAuth2.ServerDefinition")
            While tResult.%Next() {
                Set tIssuer = tResult.%GetData(2)
                If ($Piece($Piece($Piece($Piece(tIssuer, "://", 2), "/", 1), "?", 1), "#", 1) = tHost) || ($Extract(tIssuer, 1, $Length(tFixture)) = tFixture) Set tIds = tIds _ $ListBuild(tResult.%GetData(1))
            }
            If tPass = 2 {
                Set pRemaining = $ListLength(tIds)
                Quit
            }
            For tI = 1:1:$ListLength(tIds) Set tSC = $$$ADDSC(tSC, ##class(OAuth2.ServerDefinition).DeleteId($List(tIds, tI)))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>Mint one write of tool class <var>pTool</var> against <var>pIssuer</var> with <var>pArgs</var>
/// through the shipped mint, inside a seeded completed turn whose key is <var>pTurnKey</var>.</p>
ClassMethod Mint(pTool As %String, pIssuer As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pTurnKey As %String) As %Status
{
    Set pProposal = ""
    Set pFault = ""
    Set pHttpStatus = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(pTool, "DESCRIPTORCLASS"), $Parameter(pTool, "TOOLNAME"), $Username, "", pTurnKey, pArgs, "OcuPilot.Kernel.Agent.Limits", .pProposal, .pHttpStatus, .pFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pIssuer, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
}

/// <p>The <code>detail.problem</code> of a mint refusal <var>pFault</var>, or <code>""</code>.</p>
ClassMethod Problem(pFault) As %String
{
    If '$IsObject(pFault) || (pFault.%GetTypeOf("detail") '= "object") Quit ""
    Quit pFault.%Get("detail").%Get("problem")
}

/// <p>The code <var>pViolations</var> carries for <var>pField</var>, or <code>""</code>.</p>
ClassMethod CodeFor(ByRef pViolations, pField As %String) As %String
{
    Set tCode = ""
    For tI = 1:1:$Get(pViolations) {
        If $List(pViolations(tI), 1) = pField Set tCode = $List(pViolations(tI), 2) Quit
    }
    Quit tCode
}

/// <p>The top-level key names of <var>pObject</var>, sorted, comma-separated.</p>
ClassMethod Keys(pObject) As %String
{
    If '$IsObject(pObject) Quit ""
    Set tIterator = pObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tSorted(tKey) = ""
    }
    Set tKeys = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
    }
    Quit tKeys
}

/// <p><var>pList</var>'s members sorted and comma-separated.</p>
ClassMethod Sorted(pList As %List) As %String
{
    For tI = 1:1:$ListLength(pList) Set tSorted($List(pList, tI)) = ""
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

/// <p>The vendor's own OAuth 2.0 audit rows (<code>%System/%Security/OAuth2</code>) since
/// <var>pSince</var> whose description names <var>pIssuer</var>, as their descriptions joined with
/// <code>|</code>; <code>-1</code> when the read failed. The event data, which can carry a stored
/// token, is not read.</p>
ClassMethod VendorRows(pSince As %String, pIssuer As %String) As %String
{
    Set tRows = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Description FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = '%System' AND %NOINDEX EventType = '%Security' AND %NOINDEX Event = 'OAuth2' ORDER BY UTCTimeStamp", pSince)
        If tRS.%SQLCODE < 0 {
            Set tRows = -1
        } Else {
            While tRS.%Next() {
                Set tDescription = tRS.%Get("Description")
                If tDescription '[ pIssuer Continue
                Set tRows = tRows _ $Select(tRows = "": "", 1: "|") _ $ZStrip(tDescription, "<>W")
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tRows = -1
    }
    Quit tRows
}

}
