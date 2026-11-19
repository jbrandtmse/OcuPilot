/// <p>The configuration settings' refusals (AD-29, AD-55, Stories 21.3 and 21.4): which value a set may not
/// send for the setting a row describes, as one code from <class>OcuPilot.Api.ConfigError</class>, before any vendor
/// call. Two callers ask the same question: the set tools' mint (<method>WriteProblem</method>), which phrases it for
/// the agent, and <class>OcuPilot.Port.ConfigPort</class>, which asks it again at the write for the confirm and for a
/// screen's action alike (<method>Code</method>).</p>
/// <p><b>The state is the port's own read</b> of the setting (<code>GET</code>): its row's <code>ReadOnly</code>, and the
/// limits <method>OcuPilot.Port.ConfigPort.Limits</method> reads from the compiled property, or, for the SQL Shell, TSQL and
/// ISQL settings, from the port's roster entry. Nothing here reads the instance beyond that, and no value is judged by a
/// pattern the vendor does not also hold.</p>
Class OcuPilot.Area.OsMgmt.ConfigSettingRules Extends %RegisteredObject
{

/// <p>The write type this class judges.</p>
Parameter SET = "SET";

/// <p>What a datatype of a DDL mapping looks like: an optional <code>%</code>, a class name, and the parameters in parentheses when it takes
/// any, as every system mapping's datatype does on this build.</p>
Parameter DATATYPEPATTERN = "^%?[A-Za-z][A-Za-z0-9.]*(\(.*\))?$";

/// <p>The longest whole number the rules read: a longer one is out of every range a setting declares.</p>
Parameter MAXDIGITS As INTEGER = 15;

/// <p>The code of the refusal the set of the setting <var>pRow</var> describes to <var>pValue</var> meets, or
/// <code>""</code> when it may run: a setting shown and never changed is <code>CONFIG.SETTING.READONLY</code>, a value
/// its kind does not accept is <code>CONFIG.SETTING.VALUE</code>.</p>
ClassMethod Code(pEndpoint As %String, pRow As %DynamicObject, pValue As %String) As %String
{
    If '$IsObject(pRow) || 'pRow.%IsA("%Library.DynamicObject") Quit ##class(OcuPilot.Api.ConfigError).#SETTINGNOTFOUND
    If pRow.%Get("ReadOnly") Quit ##class(OcuPilot.Api.ConfigError).#SETTINGREADONLY
    Set tLimits = ..Limits(pEndpoint, pRow.%Get("Name"), pRow)
    If tLimits = "" Quit ##class(OcuPilot.Api.ConfigError).#SETTINGNOTFOUND
    If '..ValueHolds(tLimits, pValue) Quit ##class(OcuPilot.Api.ConfigError).#SETTINGVALUE
    Quit ""
}

/// <p>The limits of the setting <var>pName</var> of <var>pEndpoint</var> that <method>Code</method> judges a value by
/// (<method>OcuPilot.Port.ConfigPort.Limits</method>); a rules class for another port overrides it, and may read the setting's row <var>pRow</var>.</p>
ClassMethod Limits(pEndpoint As %String, pName As %String, pRow As %DynamicObject = "") As %List
{
    Quit ##class(OcuPilot.Port.ConfigPort).Limits(pEndpoint, pName)
}

/// <p>Whether <var>pValue</var> is one the limits <var>pLimits</var> (<method>OcuPilot.Port.ConfigPort.Limits</method>'s
/// answer) accept.</p>
ClassMethod ValueHolds(pLimits As %List, pValue As %String) As %Boolean
{
    Set tKind = $ListGet(pLimits, 1)
    If tKind = "boolean" Quit (pValue = "0") || (pValue = "1")
    If tKind = "choice" Quit ''$ListFind($ListGet(pLimits, 4), pValue)
    If tKind = "blocksizes" Quit ..BlockSizesHold(pValue)
    If tKind = "datatype" {
        If ($Length(pValue) < 1) || ($Length(pValue) > $ListGet(pLimits, 5)) Quit 0
        Quit ($ZStrip(pValue, "*C") = pValue) && $Match(pValue, ..#DATATYPEPATTERN)
    }
    If tKind = "text" {
        If $Length(pValue) > $ListGet(pLimits, 5) Quit 0
        Quit ($ZStrip(pValue, "*C") = pValue)
    }
    If tKind '= "integer" Quit 0
    If '$Match(pValue, "^(0|-?[1-9][0-9]*)$") || ($Length(pValue) > ..#MAXDIGITS) Quit 0
    If pValue = $ListGet(pLimits, 6) Quit 1
    If +pValue < $ListGet(pLimits, 2) Quit 0
    If ($ListGet(pLimits, 3) '= "") && (+pValue > $ListGet(pLimits, 3)) Quit 0
    Quit 1
}

/// <p>The code of the refusal a name <var>pName</var> meets as the name of a new DDL mapping, or <code>""</code>: 1 to
/// <parameter>OcuPilot.Port.ConfigPort.NAMEMAXLEN</parameter> characters, none of <code>=</code>, comma, <code>*</code> or <code>^</code>
/// (the characters of the vendor's list pattern and of a configuration line), no control character and no space at either end is
/// <code>CONFIG.MAPPING.NAME</code>.</p>
ClassMethod NameCode(pName As %String) As %String
{
    If ($Length(pName) < 1) || ($Length(pName) > ##class(OcuPilot.Port.ConfigPort).#NAMEMAXLEN) Quit ##class(OcuPilot.Api.ConfigError).#MAPPINGNAME
    If $ZStrip(pName, "*C") '= pName Quit ##class(OcuPilot.Api.ConfigError).#MAPPINGNAME
    If (pName [ "=") || (pName [ ",") || (pName [ "*") || (pName [ "^") Quit ##class(OcuPilot.Api.ConfigError).#MAPPINGNAME
    If $ZStrip(pName, "<>W") '= pName Quit ##class(OcuPilot.Api.ConfigError).#MAPPINGNAME
    Quit ""
}

/// <p>The code of the refusal the create of a user DDL mapping named <var>pName</var> with the datatype <var>pValue</var> meets, or
/// <code>""</code> when it may run: the name first (<method>NameCode</method>), then the datatype
/// (<code>CONFIG.SETTING.VALUE</code>).</p>
ClassMethod CreateCode(pName As %String, pValue As %String) As %String
{
    Set tCode = ..NameCode(pName)
    If tCode '= "" Quit tCode
    If '..ValueHolds(##class(OcuPilot.Port.ConfigPort).DatatypeLimits(), pValue) Quit ##class(OcuPilot.Api.ConfigError).#SETTINGVALUE
    Quit ""
}

/// <p>Whether <var>pValue</var> is a comma-separated list of distinct database block sizes the instance offers, which
/// holds the required one, as the classic value editor offers them (<method>OcuPilot.Port.ConfigPort.BlockSizeAvailable</method>).</p>
ClassMethod BlockSizesHold(pValue As %String) As %Boolean
{
    Set tSizes = $ListFromString(##class(OcuPilot.Port.ConfigPort).#BLOCKSIZES)
    Set tSeen = ""
    For tI = 1:1:$Length(pValue, ",") {
        Set tSize = $Piece(pValue, ",", tI)
        If '$ListFind(tSizes, tSize) || $ListFind(tSeen, tSize) Quit
        If '##class(OcuPilot.Port.ConfigPort).BlockSizeAvailable(tSize) Quit
        Set tSeen = tSeen _ $ListBuild(tSize)
    }
    Quit ($ListLength(tSeen) = $Length(pValue, ",")) && $ListFind(tSeen, ##class(OcuPilot.Port.ConfigPort).#BLOCKSIZEREQUIRED)
}

/// <p>The agent's arguments refused by the set's rules against the setting's own row, before anything is stored (AD-55); for a tool that
/// creates its target, by <method>CreateCode</method> over its name and its <code>Value</code> alone:
/// the row is read through the tool's own port and <method>Code</method> asks the question for the <code>Value</code>
/// <var>pArgs</var> carries. A setting the port reports absent is its own refusal sentence; any other failed read is an
/// error status. <var>pProblem</var> is the sentence, or <code>""</code> when the set may run.</p>
ClassMethod WriteProblem(pToolClass As %String, pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If $ClassMethod(pToolClass, "Creates") {
            Set tCreateValue = $Select($IsObject(pArgs) && (pArgs.%GetTypeOf("Value") = "string"): pArgs.%Get("Value"), 1: "")
            Set tCreateCode = ..CreateCode(pIdValue, tCreateValue)
            If tCreateCode '= "" Set pProblem = ##class(OcuPilot.Api.ConfigError).ReasonFor(tCreateCode)
            Quit
        }
        Kill tQuery
        Set tQuery($ClassMethod(pToolClass, "ReadIdParam")) = pIdValue
        Set tEndpoint = $ClassMethod(pToolClass, "Endpoint")
        Set tReadSC = $ClassMethod($ClassMethod(pToolClass, "PortClass"), "Invoke", tEndpoint, $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .tRow, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            If $IsObject($Get(tFault)) && (tFault.%Get("reason") '= "") && (tFault.%Get("code") '= ##class(OcuPilot.Api.Error).#INTERNAL) {
                Set pProblem = tFault.%Get("reason")
                Quit
            }
            Set tSC = tReadSC
            Quit
        }
        Set tValue = $Select($IsObject(pArgs) && (pArgs.%GetTypeOf("Value") = "string"): pArgs.%Get("Value"), 1: "")
        Set tCode = ..Code(tEndpoint, tRow, tValue)
        If tCode '= "" Set pProblem = ##class(OcuPilot.Api.ConfigError).ReasonFor(tCode)
    } Catch ex {
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
