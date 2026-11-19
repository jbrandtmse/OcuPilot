/// <p>The locale definitions' refusals (AD-29, AD-51, AD-55, Story 21.14): which write may not run against the locale's state, as one
/// code from <class>OcuPilot.Api.LocaleError</class>, before any vendor call. Two callers ask the same question: the write tools' mint
/// (<method>WriteProblem</method>), which phrases it for the person or the agent, and <class>OcuPilot.Port.LocalePort</class>, which asks
/// it again at the write for the confirm and for a screen's action alike (<method>Code</method>). It also answers the screen-only route
/// <code>GET /locales/:name/validation</code> (<method>HandleValidate</method>).</p>
/// <p><b>The state is the port's own read</b> of the locale (<code>GET</code>): its row's <code>Custom</code> and <code>Current</code>.
/// Whether the vendor's own check admits an install is the port's to ask, inside the confirmed install (<code>pInstallable</code> of
/// <method>Code</method>); the mint never asks it, because the vendor's check writes some locales' definitions. Nothing here reads the
/// instance.</p>
Class OcuPilot.Area.OsMgmt.LocaleRules Extends %RegisteredObject
{

/// <p>The write types this class judges.</p>
Parameter INSTALL = "INSTALL";

Parameter DELETE = "DELETE";

Parameter COPY = "COPY";

/// <p>The write types the port's own judgement decides (<method>PropertyProblem</method>).</p>
Parameter PROPERTYTYPES = "COPY,SET,ADD,REMOVE,LOAD";

/// <p>The screen whose declared pairs gate the validation route.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocaleList";

/// <p>The code of the refusal the write <var>pWriteType</var> meets against the locale row <var>pRow</var>, or <code>""</code> when it
/// may run. An install is refused when <var>pInstallable</var>, the vendor's own answer, is false. A delete is refused for a locale InterSystems ships (its name
/// does not start with <code>y</code>) and then for the current locale.</p>
ClassMethod Code(pWriteType As %String, pRow As %DynamicObject, pInstallable As %Boolean = 1) As %String
{
    If pWriteType = ..#INSTALL {
        If 'pInstallable Quit ##class(OcuPilot.Api.LocaleError).#NOTINSTALLABLE
        Quit ""
    }
    If pWriteType = ..#DELETE {
        If '..Flag(pRow, "Custom") Quit ##class(OcuPilot.Api.LocaleError).#SYSTEM
        If ..Flag(pRow, "Current") Quit ##class(OcuPilot.Api.LocaleError).#CURRENT
        Quit ""
    }
    Quit ""
}

/// <p>The agent's arguments refused by the write's rules against the locale's state, before anything is stored (AD-55): the locale is read
/// through the tool's own port and <method>Code</method> asks the question. A locale the port reports absent is its own refusal sentence; any other failed read is an error status.</p>
/// <p><var>pProblem</var> is the sentence, or <code>""</code> when the write may run.</p>
ClassMethod WriteProblem(pToolClass As %String, pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tPort = $ClassMethod(pToolClass, "PortClass")
        Set tType = $ClassMethod(pToolClass, "WriteType")
        If $ListFind($ListFromString(..#PROPERTYTYPES), tType) {
            Set tSC = ..PropertyProblem(tPort, tType, pIdValue, pArgs, .pProblem)
            Quit
        }
        Kill tQuery
        Set tQuery($ClassMethod(pToolClass, "ReadIdParam")) = pIdValue
        Set tReadSC = $ClassMethod(tPort, "Invoke", $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "ReadType"), .tQuery, "", .tRow, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            If ..IsRefusal($Get(tFault)) {
                Set pProblem = tFault.%Get("reason")
                Quit
            }
            Set tSC = tReadSC
            Quit
        }
        Set tCode = ..Code($ClassMethod(pToolClass, "WriteType"), tRow)
        If tCode '= "" Set pProblem = ##class(OcuPilot.Api.LocaleError).ReasonFor(tCode)
    } Catch ex {
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The refusal of the copy, set, add, remove or load <var>pType</var> the port's own judgement
/// (<method>OcuPilot.Port.LocalePort.Judge</method>) meets for the tool's id <var>pIdValue</var> and arguments <var>pArgs</var>, as one sentence in
/// <var>pProblem</var>, or <code>""</code> when the write may run. The locale is read through the port first, which asks the read gate; a copy's
/// id is the new name and its <code>Source</code> the locale read, the others' id is the composite <code>[locale, name]</code>.</p>
ClassMethod PropertyProblem(pPort As %String, pType As %String, pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tIsCopy = (pType = ..#COPY)
    If tIsCopy {
        Set tLocale = pIdValue
        Set tName = ""
        Set tRead = $Select($IsObject(pArgs) && (pArgs.%GetTypeOf("Source") = "string"): pArgs.%Get("Source"), 1: "")
    } Else {
        Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue)
        Set tLocale = $Select($ListLength(tParts) = 2: $List(tParts, 1), 1: "")
        Set tName = $Select($ListLength(tParts) = 2: $List(tParts, 2), 1: "")
        Set tRead = tLocale
    }
    Kill tQuery
    Set tQuery($Parameter(pPort, "NAMEKEY")) = tRead
    Set tReadSC = $ClassMethod(pPort, "Invoke", $Parameter(pPort, "LOCALESENDPOINT"), $Parameter(pPort, "TYPEGET"), .tQuery, "", .tRow, .tHttp, .tFault)
    If $$$ISERR(tReadSC) {
        If ..IsRefusal($Get(tFault)) {
            Set pProblem = tFault.%Get("reason")
            Quit $$$OK
        }
        Quit tReadSC
    }
    Set tSC = $ClassMethod(pPort, "Judge", pType, tLocale, tName, pArgs, .tProps, .tPropertyRow, .tJudgeHttp, .tJudgeFault)
    If $$$ISOK(tSC) Quit $$$OK
    If ..IsRefusal($Get(tJudgeFault)) {
        Set pProblem = tJudgeFault.%Get("reason")
        Quit $$$OK
    }
    Quit tSC
}

/// <p>The code of the refusal a change meets against the locale row <var>pRow</var>: <code>LOCALE.EDIT.CURRENT</code> for the current locale, else
/// <code>LOCALE.EDIT.SYSTEM</code> for a locale InterSystems ships, else <code>""</code>. The current locale is named first because it is the more
/// specific sentence: the instance's own locale is a shipped one, and the person's way out is to copy it.</p>
ClassMethod EditCode(pRow As %DynamicObject) As %String
{
    If ..Flag(pRow, "Current") Quit ##class(OcuPilot.Api.LocaleError).#EDITCURRENT
    If '..Flag(pRow, "Custom") Quit ##class(OcuPilot.Api.LocaleError).#EDITSYSTEM
    Quit ""
}

/// <p><code>LOCALE.COPY.NAME</code> unless <var>pName</var> is <code>y</code>, two lowercase letters or digits and the last character of
/// <var>pSource</var>, which is <code>w</code> or <code>8</code>; else <code>""</code>.</p>
ClassMethod CopyCode(pName As %String, pSource As %String) As %String
{
    Set tEnd = $Extract(pSource, *)
    If '$Match(pName, "^y[a-z0-9]{2}[8w]$") || ($Extract(pName, *) '= tEnd) Quit ##class(OcuPilot.Api.LocaleError).#COPYNAME
    Quit ""
}

/// <p>The code of the refusal the set of the property row <var>pRow</var> to <var>pValue</var> meets, or <code>""</code>: a row shown and never changed,
/// and every table row, is <code>CONFIG.SETTING.READONLY</code>; a value its limits <var>pLimits</var> do not accept, or a text that does not hold
/// exactly the names its property holds, is <code>CONFIG.SETTING.VALUE</code>.</p>
ClassMethod SetCode(pRow As %DynamicObject, pLimits As %List, pValue As %String) As %String
{
    If '$IsObject(pRow) || 'pRow.%IsA("%Library.DynamicObject") Quit ##class(OcuPilot.Api.ConfigError).#SETTINGNOTFOUND
    If ..Flag(pRow, "ReadOnly") Quit ##class(OcuPilot.Api.ConfigError).#SETTINGREADONLY
    If pLimits = "" Quit ##class(OcuPilot.Api.ConfigError).#SETTINGNOTFOUND
    If '##class(OcuPilot.Area.OsMgmt.ConfigSettingRules).ValueHolds(pLimits, pValue) Quit ##class(OcuPilot.Api.ConfigError).#SETTINGVALUE
    Set tCount = ##class(OcuPilot.Port.LocalePort).NameCount(pRow.%Get("Name"))
    If tCount {
        If $Length(pValue, " ") '= tCount Quit ##class(OcuPilot.Api.ConfigError).#SETTINGVALUE
        Set tEmpty = 0
        For tI = 1:1:tCount {
            If $Piece(pValue, " ", tI) = "" Set tEmpty = 1
        }
        If tEmpty Quit ##class(OcuPilot.Api.ConfigError).#SETTINGVALUE
    }
    Quit ""
}

/// <p>The code of the refusal the removal of the property row <var>pRow</var> meets, or <code>""</code>: a row that is not a table is
/// <code>LOCALE.TABLE.ROW</code>; a table that is its list's default, or, for an input/output table, the table any input/output default names, is
/// <code>LOCALE.TABLE.DEFAULT</code>. <var>pProps</var> is the locale's fresh read.</p>
ClassMethod RemoveCode(pRow As %DynamicObject, ByRef pProps) As %String
{
    If '$IsObject(pRow) || (pRow.%Get("Kind") '= "table") Quit ##class(OcuPilot.Api.LocaleError).#TABLEROW
    Set tName = pRow.%Get("Name")
    Set tList = $Piece(tName, ":", 1)
    Set tTable = $Piece(tName, ":", 2, *)
    If tList = ##class(OcuPilot.Port.LocalePort).#IOLIST {
        Set tDefaults = ##class(OcuPilot.Port.LocalePort).GroupNames("iodefaults")
        For tI = 1:1:$ListLength(tDefaults) {
            If $Get(pProps($List(tDefaults, tI))) = tTable Quit
        }
        If $Get(pProps($List(tDefaults, tI))) = tTable Quit ##class(OcuPilot.Api.LocaleError).#TABLEDEFAULT
        Quit ""
    }
    If $Get(pProps($Extract(tList, 1, *-1))) = tTable Quit ##class(OcuPilot.Api.LocaleError).#TABLEDEFAULT
    Quit ""
}

/// <p><code>LOCALE.TABLE.NOTLOADABLE</code> unless the property row <var>pRow</var> is a table the port reads as loadable.</p>
ClassMethod LoadCode(pRow As %DynamicObject) As %String
{
    If '$IsObject(pRow) || '..Flag(pRow, "Loadable") Quit ##class(OcuPilot.Api.LocaleError).#TABLENOTLOADABLE
    Quit ""
}

/// <p><code>LOCALE.TABLE.TAKEN</code> when the locale already lists the table, else <code>LOCALE.TABLE.UNAVAILABLE</code> when the instance does not
/// hold it for the locale's character set, else <code>""</code>.</p>
ClassMethod AddCode(pTaken As %Boolean, pAvailable As %Boolean) As %String
{
    If pTaken Quit ##class(OcuPilot.Api.LocaleError).#TABLETAKEN
    If 'pAvailable Quit ##class(OcuPilot.Api.LocaleError).#TABLEUNAVAILABLE
    Quit ""
}

/// <p><code>GET /locales/:name/validation</code>: the Validate dialog's read, screen-only. The caller's pairs are the screen's (AD-8), then
/// <class>OcuPilot.Port.LocalePort</class> reads the locale named by the percent-encoded segment <var>pName</var> and answers
/// <code>{Name, Valid, ErrorCount, WarningCount}</code>, no vendor-written line (AD-39). A locale the instance does not list is
/// 404 <code>LOCALE.NOTFOUND</code>.</p>
ClassMethod HandleValidate(pName As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tFailedPair = ""
        If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
            Set tSC = ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
            Quit
        }
        Set tPort = "OcuPilot.Port.LocalePort"
        Kill tQuery
        Set tQuery($Parameter(tPort, "NAMEKEY")) = ##class(OcuPilot.Kernel.EntityId).Decode(pName)
        Set tReadSC = $ClassMethod(tPort, "Invoke", $Parameter(tPort, "VALIDATIONENDPOINT"), $Parameter(tPort, "TYPEGET"), .tQuery, "", .tAnswer, .tHttp, .tFault)
        If $$$ISERR(tReadSC) {
            Set tSC = ..RenderRefusal(tReadSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>The envelope for the port's refusal <var>pFault</var> on status <var>pHttpStatus</var>; a fault that is the generic internal one, or
/// none, is rendered as an internal error carrying <var>pSC</var>.</p>
ClassMethod RenderRefusal(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status [ Private ]
{
    If '..IsRefusal($Get(pFault)) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Whether <var>pFault</var> is a wire fault carrying a written reason that is not the generic internal one.</p>
ClassMethod IsRefusal(pFault) As %Boolean [ Private ]
{
    If '$IsObject(pFault) || 'pFault.%IsA("%Library.DynamicObject") Quit 0
    Quit (pFault.%Get("reason") '= "") && (pFault.%Get("code") '= ##class(OcuPilot.Api.Error).#INTERNAL)
}

/// <p>Whether <var>pObject</var>'s <var>pField</var> is true or 1.</p>
ClassMethod Flag(pObject, pField As %String) As %Boolean [ Private ]
{
    If '$IsObject(pObject) || 'pObject.%IsA("%Library.DynamicObject") Quit 0
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit 0
    Set tText = pObject.%Get(pField) _ ""
    Quit (tText = 1) || (tText = "true")
}

}
