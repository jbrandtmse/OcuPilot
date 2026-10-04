/// <p>ECP settings' rules (AD-39, AD-55, Story 18.21): the one rule set
/// <class>OcuPilot.Screen.Tool.EcpSettingsUpdate</class>'s mint and confirm and
/// <class>OcuPilot.Area.OsMgmt.EcpSettingsSave</class>'s Save apply before any vendor call
/// (<method>Validate</method>, <method>Problem</method>), and the settings page's form read
/// (<method>HandleForm</method>).</p>
/// <p><b>The ranges are the classic page's</b>, which equal <code>Config.config</code>'s,
/// <code>Config.ECP</code>'s and <code>Security.System</code>'s own bounds: the two maximums whole numbers
/// from 0 to 254, the time to wait for recovery 10 to 65535 seconds, the time between reconnections 1 to
/// 60, the Troubled state's interval 20 to 65535, and ECP SSL/TLS support 0, 1 or 2. Each value must be a
/// JSON number. The vendor's <code>PUT</code> does not stop at a refused member (AD-4), so every value is
/// refused here, on its field, before the port is touched. Every sentence is
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s.</p>
Class OcuPilot.Area.OsMgmt.EcpSettingsRules Extends %RegisteredObject
{

/// <p>The screen whose declared pairs gate the form read (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EcpSettings";

/// <p>The tool whose port the form read asks (AD-52).</p>
Parameter UPDATETOOL = "OcuPilot.Screen.Tool.EcpSettingsUpdate";

/// <p>The two objects the body carries, and each one's members.</p>
Parameter APPGROUP = "AppServerSettings";

Parameter DATAGROUP = "DataServerSettings";

Parameter APPMEMBERS = "MaxServers,ClientReconnectDuration,ClientReconnectInterval";

Parameter DATAMEMBERS = "MaxServerConn,ServerTroubleDuration,SSLECPServer";

/// <p>Each member's rule, as <code>member:min:max:code</code> entries, comma-separated.</p>
Parameter RANGES = "MaxServers:0:254:ECP.SETTINGS.COUNT,ClientReconnectDuration:10:65535:ECP.SETTINGS.RECOVERY,ClientReconnectInterval:1:60:ECP.SETTINGS.INTERVAL,MaxServerConn:0:254:ECP.SETTINGS.COUNT,ServerTroubleDuration:20:65535:ECP.SETTINGS.TROUBLE,SSLECPServer:0:2:ECP.SETTINGS.SSL.SHAPE";

/// <p>The members of <var>pGroup</var>, as a <class>%List</class>, or <code>""</code> for a name that is
/// neither object.</p>
ClassMethod Members(pGroup As %String) As %List
{
    If pGroup = ..#APPGROUP Quit $ListFromString(..#APPMEMBERS)
    If pGroup = ..#DATAGROUP Quit $ListFromString(..#DATAMEMBERS)
    Quit ""
}

/// <p>The first key of <var>pArgs</var> no write admits, as <code>&lt;Object&gt;.&lt;member&gt;</code>
/// for a member or the bare name for a top-level key, or <code>""</code>. <var>pIgnore</var> lists the
/// top-level names the caller admits beside the two objects (the tool's identifying property and the
/// agent's own words).</p>
ClassMethod Unexpected(pArgs As %DynamicObject, pIgnore As %List = "") As %String
{
    If '$IsObject(pArgs) Quit ""
    Set tFound = ""
    Set tIterator = pArgs.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If $ListFind(pIgnore, tKey) Continue
        Set tMembers = ..Members(tKey)
        If tMembers = "" {
            Set tFound = tKey
            Quit
        }
        If pArgs.%GetTypeOf(tKey) '= "object" Continue
        Set tInner = pArgs.%Get(tKey).%GetIterator()
        While tInner.%GetNext(.tMember, .tMemberValue) {
            If $ListFind(tMembers, tMember) Continue
            Set tFound = tKey _ "." _ tMember
            Quit
        }
        If tFound '= "" Quit
    }
    Quit tFound
}

/// <p>Every rule over the members <var>pArgs</var> carries, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in <code>pViolations</code>: an
/// object that is not an object is refused <code>PORT.FIELD.SHAPE</code> on its name, and each member it
/// carries is held to its range on <code>&lt;Object&gt;.&lt;member&gt;</code>. A member neither object
/// names is <method>Unexpected</method>'s, and is not judged here.</p>
ClassMethod Validate(pArgs As %DynamicObject, Output pViolations) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Try {
        If '$IsObject(pArgs) Quit
        For tGroup = ..#APPGROUP, ..#DATAGROUP {
            Set tType = pArgs.%GetTypeOf(tGroup)
            If tType = "unassigned" Continue
            If tType '= "object" {
                Do ..Add(.pViolations, tGroup, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Continue
            }
            Set tObject = pArgs.%Get(tGroup)
            Set tMembers = ..Members(tGroup)
            For tI = 1:1:$ListLength(tMembers) {
                Set tMember = $List(tMembers, tI)
                If tObject.%GetTypeOf(tMember) = "unassigned" Continue
                Set tRule = ..Rule(tMember)
                If ..WholeIn(tObject, tMember, $Piece(tRule, ":", 2), $Piece(tRule, ":", 3)) Continue
                Do ..Add(.pViolations, tGroup _ "." _ tMember, $Piece(tRule, ":", 4))
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The rules of <method>Validate</method> and <method>Unexpected</method> as one problem sentence
/// naming each field and its published sentence, or <code>""</code>, in <var>pProblem</var>: what the
/// tool's <code>ArgumentProblem</code> and <code>MergeUpdate</code> answer. <var>pIgnore</var> is
/// <method>Unexpected</method>'s.</p>
ClassMethod Problem(pArgs As %DynamicObject, Output pProblem As %String, pIgnore As %List = "") As %Status
{
    Set pProblem = ""
    Set tUnexpected = ..Unexpected(pArgs, pIgnore)
    If tUnexpected '= "" {
        Set pProblem = "'" _ tUnexpected _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED)
        Quit $$$OK
    }
    Set tSC = ..Validate(pArgs, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>The rule of member <var>pMember</var>, a <parameter>RANGES</parameter> entry, or
/// <code>""</code>.</p>
ClassMethod Rule(pMember As %String) As %String
{
    For tI = 1:1:$Length(..#RANGES, ",") {
        Set tEntry = $Piece(..#RANGES, ",", tI)
        If $Piece(tEntry, ":", 1) = pMember Quit
        Set tEntry = ""
    }
    Quit $Get(tEntry)
}

/// <p>Answer <code>GET /ecp-settings/form</code>: <code>{licensed, serverSsl}</code>, where
/// <code>licensed</code> is whether the license enables ECP (<method>OcuPilot.Port.EcpPort.NetworkEnabled</method>)
/// and <code>serverSsl</code> the <code>%ECPServer</code> SSL/TLS configuration's state,
/// <code>absent</code>, <code>disabled</code> or <code>enabled</code>
/// (<method>OcuPilot.Port.EcpPort.SslState</method>), each read through the update tool's own port.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tPort = $ClassMethod(..#UPDATETOOL, "PortClass")
        Set tReadSC = $ClassMethod(tPort, "SslState", $Parameter(tPort, "SERVERSSL"), .tState, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            Set tSC = ##class(OcuPilot.Area.OsMgmt.LicenseRules).RenderRead(tReadSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("licensed", ''$ClassMethod(tPort, "NetworkEnabled"), "boolean")
        Do tBody.%Set("serverSsl", tState, "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Refuse a caller who does not hold ECP settings' declared pairs (AD-8): <var>pRefused</var> 1 means
/// the envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>Whether <var>pObject</var>'s <var>pMember</var> is a JSON number holding a whole number from
/// <var>pMin</var> to <var>pMax</var>.</p>
ClassMethod WholeIn(pObject As %DynamicObject, pMember As %String, pMin As %Integer, pMax As %Integer) As %Boolean [ Private ]
{
    If pObject.%GetTypeOf(pMember) '= "number" Quit 0
    Set tValue = pObject.%Get(pMember)
    If '$IsValidNum(tValue) Quit 0
    If +tValue '= (tValue \ 1) Quit 0
    Quit (+tValue >= pMin) && (+tValue <= pMax)
}

/// <p>Append one violation.</p>
ClassMethod Add(ByRef pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
