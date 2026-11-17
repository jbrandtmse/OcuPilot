/// <p>The locale port (AD-16, AD-21, AD-29, AD-36, AD-39, AD-51, AD-52, AD-53, AD-58, AD-59, Story 21.14): the one product class, with
/// <class>OcuPilot.Port.ConfigPort</class>, that names <code>Config.NLS.Locales</code>. It lists the instance's locale definitions, reads
/// one locale's validation, installs a locale as the instance's current locale and deletes a custom one. It switches
/// <code>$NAMESPACE</code> to <code>%SYS</code> by save and restore around each vendor call (AD-16).</p>
/// <p><b>Its gate comes first</b> (AD-29): <parameter>PAIRS</parameter> for a read, <parameter>WRITEPAIRS</parameter> for a write,
/// evaluated through <method>GateClass</method> in the calling process before any vendor call or body. A caller missing one is refused 403
/// <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>.</p>
/// <p><b>Endpoints and request types.</b> <parameter>LOCALESENDPOINT</parameter>: <code>LIST</code>, <code>GET</code> (one locale, the
/// fresh read of the write tools, AD-51), <code>INSTALL</code> and <code>DELETE</code>; <parameter>VALIDATIONENDPOINT</parameter>:
/// <code>GET</code>. A locale is named by the query's <code>name</code> and found in the instance's own list by an exact comparison, so no
/// caller value reaches the vendor's <code>List</code> pattern (AD-21). A row is <code>{Name, Description, Current, Custom}</code>:
/// <code>Current</code> is the name <code>^%SYS("LOCALE","CURRENT")</code> holds, <code>Custom</code> a name that starts with
/// <parameter>CUSTOMPREFIX</parameter>.</p>
/// <p><b>Validation</b> answers <code>{Name, Valid, Installable, Errors, Warnings, ErrorCount, WarningCount, Truncated}</code> from the
/// vendor's <code>IsValid</code>, <code>IsLoadable</code> and <code>IsInstallable</code>, which write nothing: <code>Valid</code> reads
/// true when the definition is valid and loadable, <code>Installable</code> is the vendor's own install check. At most
/// <parameter>LINESMAX</parameter> lines, errors first, are answered, with <code>Truncated</code> true when more existed; the counts are of
/// every line. The lines are vendor-written text and reach the screen only (AD-39).</p>
/// <p><b>Every write is judged before any vendor call</b> by <class>OcuPilot.Area.OsMgmt.LocaleRules</class>, the rules the tools' mint asks
/// too: an install is refused when the vendor's own check refuses it, a delete for a locale InterSystems ships and for the current locale.
/// An install answers <code>{Name, TempCollationBefore, TempCollationAfter}</code>, the default collation of IRISTEMP around the call; a
/// delete answers <code>{Name}</code>. A vendor refusal is logged and answered 500 <code>INTERNAL</code> (AD-39).</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>LogFault</method>, <method>ReadValidation</method>,
/// <method>TempCollation</method>, <method>SendInstall</method> and <method>SendDelete</method>. Production overrides none of them.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace is unchanged on return.</p>
Class OcuPilot.Port.LocalePort Extends %RegisteredObject
{

/// <p>The pair set every read requires, comma-separated as <code>resource:permission</code>, in the order the gate reports in (AD-8,
/// AD-29): the classic locale page's own.</p>
Parameter PAIRS = "%Admin_Manage:USE,%DB_IRISSYS:READ";

/// <p>The pair set every write requires: the read pairs and <code>%DB_IRISSYS:WRITE</code>, which the vendor's install, delete and the
/// <code>^SYS("NLS")</code> definitions need of a caller that does not hold <code>%All</code> (measured on <code>ocupilot-ci</code>).</p>
Parameter WRITEPAIRS = "%Admin_Manage:USE,%DB_IRISSYS:READ,%DB_IRISSYS:WRITE";

/// <p>The class the pair sets are evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The endpoints a screen's read lists, in <code>LIST</code>.</p>
Parameter ENDPOINTS = "Locales";

Parameter LOCALESENDPOINT = "Locales";

Parameter VALIDATIONENDPOINT = "Validation";

Parameter TYPELIST = "LIST";

Parameter TYPEGET = "GET";

Parameter TYPEINSTALL = "INSTALL";

Parameter TYPEDELETE = "DELETE";

/// <p>The write request types.</p>
Parameter WRITETYPES = "INSTALL,DELETE";

/// <p>The query keys: the locale named, and the rows a list is read for.</p>
Parameter NAMEKEY = "name";

Parameter MAXROWSKEY = "maxRows";

/// <p>The cap a list that names none is read under.</p>
Parameter DEFAULTMAXROWS As INTEGER = 1000;

/// <p>The most locales one read of the instance's list holds.</p>
Parameter LOCALESMAXROWS As INTEGER = 5000;

/// <p>The most validation lines, errors first, an answer carries, and the most characters of one line.</p>
Parameter LINESMAX As INTEGER = 50;

Parameter LINEMAX As INTEGER = 500;

/// <p>What a custom locale's name starts with: the vendor keeps only these across an upgrade.</p>
Parameter CUSTOMPREFIX = "y";

/// <p>The subsystem every log line of this port is written under.</p>
Parameter LOGSUBSYSTEM = "localeport";

Parameter REASONNOTIMPLEMENTED = "This instance does not implement that operation.";

Parameter REASONMAXROWS = "maxRows must be a whole number above zero.";

/// <p>The class the pair sets are evaluated through. Overridable so a fixture can drive a denial in process; production never overrides
/// it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture the line; production never overrides
/// it.</p>
ClassMethod LogFault(pMessage As %String, pStatus As %Status, pCode As %String = "")
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pCode)
}

/// <p>The pairs <var>pSpec</var> names as the <code>%List</code> the gate evaluates.</p>
ClassMethod Pairs(pSpec As %String) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).ParsePairSpec(pSpec)
}

/// <p>Whether <var>pType</var> is one of <parameter>WRITETYPES</parameter>.</p>
ClassMethod IsWrite(pType As %String) As %Boolean
{
    Quit ''$ListFind($ListFromString(..#WRITETYPES), pType)
}

/// <p>Whether <var>pEndpoint</var> serves request type <var>pType</var>.</p>
ClassMethod Serves(pEndpoint As %String, pType As %String) As %Boolean
{
    If pEndpoint = ..#LOCALESENDPOINT Quit (pType = ..#TYPELIST) || (pType = ..#TYPEGET) || (pType = ..#TYPEINSTALL) || (pType = ..#TYPEDELETE)
    If pEndpoint = ..#VALIDATIONENDPOINT Quit pType = ..#TYPEGET
    Quit 0
}

/// <p>Serve <var>pEndpoint</var> for request type <var>pType</var>, after the gate.</p>
/// <p>A read answers <var>pResult</var> as an array of rows (<code>LIST</code>, at most <parameter>DEFAULTMAXROWS</parameter> unless
/// <var>pQuery</var> carries <parameter>MAXROWSKEY</parameter>) or as one object (<code>GET</code>); a write answers its own object.
/// <var>pBody</var> must be empty.</p>
/// <p>Otherwise an error status is returned, <var>pHttpStatus</var> is the status to answer with and <var>pFault</var> the wire fault: 403
/// <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>; 501 <code>PORT.NOTIMPLEMENTED</code> for another endpoint or type;
/// 400 <code>PORT.VALIDATION</code> for a cap of the wrong shape; each <code>LOCALE.*</code> refusal on the status
/// <class>OcuPilot.Api.LocaleError</class> names; and 500 <code>INTERNAL</code>, logged, for a body or any failure.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSC = ..Admit(pType, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If $IsObject(pBody) || (pBody '= "") {
            Set tSC = ..Fail(pEndpoint _ " " _ pType _ " was given a caller body, and it takes none", $$$ERROR($$$GeneralError, "a locale call takes no body"), .pHttpStatus, .pFault)
            Quit
        }
        If '..Serves(pEndpoint, pType) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tName = $Get(pQuery(..#NAMEKEY))
        If pType = ..#TYPELIST {
            Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
            If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
                Quit
            }
            Set tMax = $Select(tMaxText = "": ..#DEFAULTMAXROWS, 1: +tMaxText)
            Set tSC = ..Listing(tMax, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pEndpoint = ..#VALIDATIONENDPOINT {
            Set tSC = ..Validation(tName, .pResult, .pHttpStatus, .pFault)
        } ElseIf pType = ..#TYPEGET {
            Set tSC = ..State(tName, .pResult, .pHttpStatus, .pFault)
        } ElseIf pType = ..#TYPEINSTALL {
            Set tSC = ..Install(tName, .pResult, .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..Remove(tName, .pResult, .pHttpStatus, .pFault)
        }
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) Set pResult = ""
    Quit tSC
}

/// <p>The rows of the list <var>pEndpoint</var> names, after the read gate, at most <var>pMax</var> of them: the call the screens' and
/// the read tools' reads are issued through (AD-36). Otherwise <method>Invoke</method>'s answers.</p>
ClassMethod Rows(pEndpoint As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pRows = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Admit(..#TYPELIST, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '..Serves(pEndpoint, ..#TYPELIST) Quit ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
    Try {
        Set tSC = ..Listing(pMax, .pRows, .pHttpStatus, .pFault)
    } Catch ex {
        Set pRows = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) Set pRows = ""
    Quit tSC
}

/// <p>The gate: <parameter>WRITEPAIRS</parameter> for a write type, otherwise <parameter>PAIRS</parameter>.</p>
ClassMethod Admit(pType As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tFailedPair = ""
    ; EvaluateRequired, not EvaluatePairs: a pair parameter mis-edited to empty fails closed.
    If $ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs($Select(..IsWrite(pType): ..#WRITEPAIRS, 1: ..#PAIRS)), .tFailedPair) Quit $$$OK
    Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
}

/// <p>The locale rows, at most <var>pMax</var> of them.</p>
ClassMethod Listing(pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..LocaleRows(.tAll)
    If $$$ISERR(tSC) Quit ..Fail("the locales could not be read", tSC, .pHttpStatus, .pFault)
    Set pHttpStatus = 200
    Set pRows = []
    Set tIterator = tAll.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If pRows.%Size() >= pMax Quit
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

/// <p>The vendor's locale list as <code>{Name, Description, Current, Custom}</code>, at most <parameter>LOCALESMAXROWS</parameter>. The
/// list is asked for every locale (<code>*</code>), never for a caller's name.</p>
ClassMethod LocaleRows(Output pRows As %DynamicArray) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tRS = ""
    Set pRows = []
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tCurrent = $Get(^%SYS("LOCALE", "CURRENT"))
        Set tRS = ##class(%ResultSet).%New("Config.NLS.Locales:List")
        Set tSC = tRS.Execute("*")
        If $$$ISERR(tSC) Quit
        Set tCount = 0
        While tRS.Next() {
            If $Increment(tCount) > ..#LOCALESMAXROWS Quit
            Set tName = tRS.Get("Name")
            Set tRow = {}
            Do tRow.%Set("Name", tName, "string")
            Do tRow.%Set("Description", tRS.Get("Description"), "string")
            Do tRow.%Set("Current", (tName = tCurrent), "boolean")
            Do tRow.%Set("Custom", ($Extract(tName, 1, $Length(..#CUSTOMPREFIX)) = ..#CUSTOMPREFIX), "boolean")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    ; The query is closed in %SYS, where it was opened: closing it from another namespace leaves the next execution refused.
    Set tRS = ""
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    If $$$ISERR(tSC) Set pRows = []
    Quit tSC
}

/// <p>The locale <var>pName</var> as the instance lists it, in <var>pRow</var>, found by an exact comparison. A name the list does not hold
/// is 404 <code>LOCALE.NOTFOUND</code>.</p>
ClassMethod State(pName As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pRow = ""
    If pName = "" Quit ..Refused(##class(OcuPilot.Api.LocaleError).#NOTFOUND, .pHttpStatus, .pFault)
    Set tSC = ..LocaleRows(.tRows)
    If $$$ISERR(tSC) Quit ..Fail("the locales could not be read", tSC, .pHttpStatus, .pFault)
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Name") = pName {
            Set pRow = tRow
            Set pHttpStatus = 200
            Quit
        }
    }
    If '$IsObject(pRow) Quit ..Refused(##class(OcuPilot.Api.LocaleError).#NOTFOUND, .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>The validation of the locale <var>pName</var>, in <var>pAnswer</var>, from <method>ReadValidation</method>: the lines are cut to
/// <parameter>LINESMAX</parameter>, errors first, each to <parameter>LINEMAX</parameter> characters with control characters removed. A name
/// the list does not hold is 404 <code>LOCALE.NOTFOUND</code>.</p>
ClassMethod Validation(pName As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set tSC = ..State(pName, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ReadValidation(pName, .tValid, .tInstallable, .tErrorLines, .tWarningLines)
    If $$$ISERR(tSC) Quit ..Fail("the locale could not be validated", tSC, .pHttpStatus, .pFault)
    Set tErrors = []
    Set tWarnings = []
    Set tLeft = ..#LINESMAX
    For tI = 1:1:$ListLength(tErrorLines) {
        If tLeft < 1 Quit
        Do tErrors.%Push(..Line($List(tErrorLines, tI)), "string")
        Set tLeft = tLeft - 1
    }
    For tI = 1:1:$ListLength(tWarningLines) {
        If tLeft < 1 Quit
        Do tWarnings.%Push(..Line($List(tWarningLines, tI)), "string")
        Set tLeft = tLeft - 1
    }
    Set pAnswer = {}
    Do pAnswer.%Set("Name", pName, "string")
    Do pAnswer.%Set("Valid", ''tValid, "boolean")
    Do pAnswer.%Set("Installable", ''tInstallable, "boolean")
    Do pAnswer.%Set("Errors", tErrors)
    Do pAnswer.%Set("Warnings", tWarnings)
    Do pAnswer.%Set("ErrorCount", $ListLength(tErrorLines), "number")
    Do pAnswer.%Set("WarningCount", $ListLength(tWarningLines), "number")
    Do pAnswer.%Set("Truncated", ($ListLength(tErrorLines) + $ListLength(tWarningLines) > ..#LINESMAX), "boolean")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>One vendor line cut to <parameter>LINEMAX</parameter> characters, control characters removed.</p>
ClassMethod Line(pLine As %String) As %String [ Private ]
{
    Quit $Extract($ZStrip(pLine, "*C"), 1, ..#LINEMAX)
}

/// <p>The vendor's three checks of the locale <var>pName</var>, which write nothing, in <code>%SYS</code> by save and restore:
/// <var>pValid</var> is true when <code>IsValid</code> and <code>IsLoadable</code> both are, <var>pInstallable</var> is
/// <code>IsInstallable</code>, <var>pErrors</var> and <var>pWarnings</var> every line the three answered, as <code>%List</code>s, in the
/// order <code>IsValid</code>, <code>IsLoadable</code>, <code>IsInstallable</code>. Overridable so a fixture can feed an answer;
/// production never overrides it.</p>
ClassMethod ReadValidation(pName As %String, Output pValid As %Boolean, Output pInstallable As %Boolean, Output pErrors As %List, Output pWarnings As %List) As %Status
{
    Set tSC = $$$OK
    Set pValid = 0
    Set pInstallable = 0
    Set pErrors = ""
    Set pWarnings = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tValid = ##class(Config.NLS.Locales).IsValid(pName, .tValidErrors, .tValidWarnings)
        Set tLoadable = ##class(Config.NLS.Locales).IsLoadable(pName, , .tLoadErrors)
        Set tInstallable = ##class(Config.NLS.Locales).IsInstallable(pName, .tInstallErrors, .tInstallWarnings)
        Set pValid = ''(tValid && tLoadable)
        Set pInstallable = ''tInstallable
        For tI = 1:1:+$Get(tValidErrors) Set pErrors = pErrors _ $ListBuild(tValidErrors(tI))
        For tI = 1:1:+$Get(tLoadErrors) Set pErrors = pErrors _ $ListBuild(tLoadErrors(tI))
        For tI = 1:1:+$Get(tInstallErrors) Set pErrors = pErrors _ $ListBuild(tInstallErrors(tI))
        For tI = 1:1:+$Get(tValidWarnings) Set pWarnings = pWarnings _ $ListBuild(tValidWarnings(tI))
        For tI = 1:1:+$Get(tInstallWarnings) Set pWarnings = pWarnings _ $ListBuild(tInstallWarnings(tI))
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Install the locale <var>pName</var> as the instance's current locale: the locale is read, the rules refuse one the vendor's own check
/// does not admit, and then <method>SendInstall</method> installs it with the default collation of IRISTEMP read before and after
/// (<method>TempCollation</method>). Answers <code>{Name, TempCollationBefore, TempCollationAfter}</code>.</p>
ClassMethod Install(pName As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..State(pName, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ReadValidation(pName, .tValid, .tInstallable, .tErrors, .tWarnings)
    If $$$ISERR(tSC) Quit ..Fail("the locale could not be checked before its install", tSC, .pHttpStatus, .pFault)
    Set tCode = ##class(OcuPilot.Area.OsMgmt.LocaleRules).Code(##class(OcuPilot.Area.OsMgmt.LocaleRules).#INSTALL, tRow, tInstallable)
    If tCode '= "" Quit ..Refused(tCode, .pHttpStatus, .pFault)
    Set tBefore = ..TempCollation()
    Set tVendor = ..SendInstall(pName)
    If $$$ISERR(tVendor) Quit ..Fail("the install of a locale was refused by the vendor", tVendor, .pHttpStatus, .pFault)
    Set pResult = {}
    Do pResult.%Set("Name", pName, "string")
    Do pResult.%Set("TempCollationBefore", tBefore, "string")
    Do pResult.%Set("TempCollationAfter", ..TempCollation(), "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Delete the locale <var>pName</var>: the locale is read, the rules refuse a locale InterSystems ships and the current locale, and then
/// <method>SendDelete</method> deletes it. Answers <code>{Name}</code>.</p>
ClassMethod Remove(pName As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..State(pName, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tCode = ##class(OcuPilot.Area.OsMgmt.LocaleRules).Code(##class(OcuPilot.Area.OsMgmt.LocaleRules).#DELETE, tRow)
    If tCode '= "" Quit ..Refused(tCode, .pHttpStatus, .pFault)
    Set tVendor = ..SendDelete(pName)
    If $$$ISERR(tVendor) Quit ..Fail("the delete of a locale was refused by the vendor", tVendor, .pHttpStatus, .pFault)
    Set pResult = {}
    Do pResult.%Set("Name", pName, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The default collation of IRISTEMP as the vendor names it, or <code>""</code> when it cannot be read, in <code>%SYS</code> by save and
/// restore. Overridable so a fixture can feed an answer; production never overrides it.</p>
ClassMethod TempCollation() As %String
{
    Set tName = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Do GetCacheDirs^STU(.tTempDir)
        If $$GetDatabaseInfo^%SYS.DATABASE(tTempDir, .tInfo) = 1 Set tName = $$GetName^COLLATE(+$Piece(tInfo, ",", 13))
    } Catch {
        Set tName = ""
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tName
}

/// <p>The one call that installs a locale: the vendor's <code>Install</code> of <var>pName</var>, a locale the rules have admitted, in
/// <code>%SYS</code> by save and restore. Overridable so a fixture can record the call; production never overrides it.</p>
ClassMethod SendInstall(pName As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Config.NLS.Locales).Install(pName)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The one call that deletes a locale: the vendor's <code>Delete</code> of <var>pName</var>, a custom locale that is not current, in
/// <code>%SYS</code> by save and restore. Overridable so a fixture can record the call; production never overrides it.</p>
ClassMethod SendDelete(pName As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Config.NLS.Locales).Delete(pName)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The 403 the gate answers, <code>AUTH.NOPRIVILEGE</code> with the pair in <code>detail.failedPair</code> (AD-8, AD-39).</p>
ClassMethod Deny(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = ##class(OcuPilot.Kernel.Denial).#STATUS
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason())
    Set tDetail = ##class(OcuPilot.Kernel.Denial).Detail(pFailedPair)
    If $IsObject(tDetail) Do pFault.%Set("detail", tDetail)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p>A refusal this port decided, with a written reason (AD-39).</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>The refusal <var>pCode</var> of <class>OcuPilot.Api.LocaleError</class>, on the status and slug that class names and with its sentence.
/// Nothing is logged: a refusal is an answer, not a fault.</p>
ClassMethod Refused(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..Refuse(##class(OcuPilot.Api.LocaleError).HttpStatusFor(pCode), ##class(OcuPilot.Api.LocaleError).SlugFor(pCode), pCode, ##class(OcuPilot.Api.LocaleError).ReasonFor(pCode), .pHttpStatus, .pFault)
}

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p><code>objectscript</code> for each write; <code>""</code> for every read, which has no script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If ..IsWrite(pType) && ..Serves(pEndpoint, pType) Quit "objectscript"
    Quit ""
}

/// <p>The write as a script (AD-59), in <code>%SYS</code>: <code>Config.NLS.Locales.Install</code> or <code>Delete</code> of the locale named
/// as a string literal, so nothing the query carries runs as code. A read renders none.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tAdmin = "OcuPilot.Port.AdminPort"
    Set tName = $ClassMethod(tAdmin, "Literal", $Get(pQuery(..#NAMEKEY)))
    Set tLine = "Set tSC = ##class(Config.NLS.Locales)." _ $Select(pType = ..#TYPEINSTALL: "Install", 1: "Delete") _ "(" _ tName _ ")"
    Quit [($ClassMethod(tAdmin, "ObjectScriptStep", $ListBuild(tLine)))]
}

}
