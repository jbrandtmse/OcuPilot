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
/// <p><b>Validation</b> answers <code>{Name, Valid, ErrorCount, WarningCount}</code> from the vendor's <code>IsValid</code> alone:
/// <code>Valid</code> is its answer and the counts are of the error and warning lines it answered. It is a read: it never calls
/// <code>IsInstallable</code>, which writes the locale's definition for some locales. The lines are vendor-written text and are never
/// answered (AD-39).</p>
/// <p><b>Every write is judged before the vendor's install or delete</b> by <class>OcuPilot.Area.OsMgmt.LocaleRules</class>, which the tools' mint asks
/// too: a delete is refused for a locale InterSystems ships and for the current locale. An install is refused when the vendor's own
/// <code>IsInstallable</code> refuses it; that check runs only here, inside the confirmed install, after the write gate
/// (<method>ReadInstallable</method>). An install answers <code>{Name, TempCollationBefore, TempCollationAfter}</code>, the default collation of IRISTEMP around the call; a
/// delete answers <code>{Name}</code>. A vendor refusal is logged and answered 500 <code>INTERNAL</code> (AD-39).</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>LogFault</method>, <method>ReadValidation</method>,
/// <method>ReadInstallable</method>, <method>TempCollation</method>, <method>SendInstall</method> and <method>SendDelete</method>. Production overrides none of them.</p>
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
Parameter ENDPOINTS = "Locales,Properties";

Parameter LOCALESENDPOINT = "Locales";

Parameter VALIDATIONENDPOINT = "Validation";

/// <p>One locale's properties, tables and input/output tables, one row each (Story 21.16).</p>
Parameter PROPERTIESENDPOINT = "Properties";

Parameter TYPELIST = "LIST";

Parameter TYPEGET = "GET";

Parameter TYPEINSTALL = "INSTALL";

Parameter TYPEDELETE = "DELETE";

Parameter TYPECOPY = "COPY";

Parameter TYPESET = "SET";

Parameter TYPEADD = "ADD";

Parameter TYPEREMOVE = "REMOVE";

Parameter TYPELOAD = "LOAD";

/// <p>The write request types.</p>
Parameter WRITETYPES = "INSTALL,DELETE,COPY,SET,ADD,REMOVE,LOAD";

/// <p>The write types that take a body.</p>
Parameter BODYTYPES = "COPY,SET,ADD";

/// <p>The query keys: the locale named, the locale a property row belongs to, the action a create's read is composed for, and the
/// rows a list is read for.</p>
Parameter NAMEKEY = "name";

Parameter LOCALEKEY = "locale";

Parameter ACTIONKEY = "action";

Parameter MAXROWSKEY = "maxRows";

/// <p>The vendor class that holds a locale's definition.</p>
Parameter VENDORCLASS = "Config.NLS.Locales";

/// <p>The editable scalar properties by group, <code>group:Name,Name|group:...</code>. A locale's table lists and its
/// input/output tables are the rows of groups <code>tables</code> and <code>iotables</code>.</p>
Parameter SCALARGROUPS = "basic:Description,Currency|formats:DateFormat,DateSeparator,TimeFormat,TimeSeparator,TimePrecision,MinusSign,PlusSign,DecimalSeparator,NumericGroupSeparator,NumericGroupSize|strings:AM,PM,Noon,Midnight,WeekdayName,WeekdayAbbr,MonthName,MonthAbbr|tabledefaults:PatternTable,IdentifierTable,UpperCaseTable,LowerCaseTable,TitleCaseTable,AccentTable,CollationTable,XYTable|iodefaults:TranZCVT,TranProgrammer,TranTerminal,TranSequential,TranMagTape,TranTCP,TranSystemCall,TranPrinter";

/// <p>The properties shown and never changed, in group <code>basic</code>.</p>
Parameter SHOWN = "Country,CountryAbbr,Language,LanguageAbbr,CharacterSet";

/// <p>The internal table lists and the table type each one holds, in the vendor's own spelling of the type.</p>
Parameter TABLELISTS = "PatternTables:Pattern,IdentifierTables:Ident,UpperCaseTables:UpperCase,LowerCaseTables:LowerCase,TitleCaseTables:TitleCase,AccentTables:Accent,CollationTables:COL,XYTables:XY";

/// <p>The list of input/output tables, and its table type.</p>
Parameter IOLIST = "XLTTables";

Parameter IOTYPE = "XLT";

/// <p>The table types a table load accepts: every type the lists hold but <code>Accent</code>.</p>
Parameter LOADTYPES = "XLT,UpperCase,LowerCase,TitleCase,Pattern,Ident,COL,XY";

/// <p>The properties that hold a whole number of space-separated names, and how many.</p>
Parameter NAMECOUNTS = "WeekdayName:7,WeekdayAbbr:7,MonthName:12,MonthAbbr:12";

/// <p>The longest name an input/output table is given.</p>
Parameter IONAMEMAXLEN As INTEGER = 64;

Parameter REASONCOPYBODY = "a copy takes the locale to copy in Source, and optionally a Description.";

Parameter REASONSETBODY = "a set takes the new value as text in Value.";

Parameter REASONADDBODY = "an input/output table takes InputFrom and OutputTo as text, and no other table takes either.";

Parameter REASONIONAME = "an input/output table's name is 1 to 64 characters with no control character.";

Parameter REASONROWNAME = "a property row is named <list>:<table> for a table and by its own name otherwise.";

/// <p>The cap a list that names none is read under.</p>
Parameter DEFAULTMAXROWS As INTEGER = 1000;

/// <p>The most locales one read of the instance's list holds.</p>
Parameter LOCALESMAXROWS As INTEGER = 5000;

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
    If pEndpoint = ..#LOCALESENDPOINT Quit (pType = ..#TYPELIST) || (pType = ..#TYPEGET) || (pType = ..#TYPEINSTALL) || (pType = ..#TYPEDELETE) || (pType = ..#TYPECOPY)
    If pEndpoint = ..#VALIDATIONENDPOINT Quit pType = ..#TYPEGET
    If pEndpoint = ..#PROPERTIESENDPOINT Quit (pType = ..#TYPELIST) || (pType = ..#TYPEGET) || (pType = ..#TYPESET) || (pType = ..#TYPEADD) || (pType = ..#TYPEREMOVE) || (pType = ..#TYPELOAD)
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
        If ($IsObject(pBody) || (pBody '= "")) && '$ListFind($ListFromString(..#BODYTYPES), pType) {
            Set tSC = ..Fail(pEndpoint _ " " _ pType _ " was given a caller body, and it takes none", $$$ERROR($$$GeneralError, "a locale call takes no body"), .pHttpStatus, .pFault)
            Quit
        }
        If '..Serves(pEndpoint, pType) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        Set tName = $Get(pQuery(..#NAMEKEY))
        If pEndpoint = ..#PROPERTIESENDPOINT {
            Set tSC = ..Property(pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPECOPY {
            Set tSC = ..Copy(tName, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If (pType = ..#TYPEGET) && ($Get(pQuery(..#ACTIONKEY)) = ..#TYPECOPY) {
            Set tSC = ..Absence(tName, .pResult, .pHttpStatus, .pFault)
            Quit
        }
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
    If (pEndpoint '= ..#LOCALESENDPOINT) || '..Serves(pEndpoint, ..#TYPELIST) Quit ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
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

/// <p>The validation of the locale <var>pName</var>, in <var>pAnswer</var>, from <method>ReadValidation</method>: the verdict and the
/// counts of the error and warning lines, never a line (AD-39). A name the list does not hold is 404 <code>LOCALE.NOTFOUND</code>.</p>
ClassMethod Validation(pName As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set tSC = ..State(pName, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ReadValidation(pName, .tValid, .tErrorLines, .tWarningLines)
    If $$$ISERR(tSC) Quit ..Fail("the locale could not be validated", tSC, .pHttpStatus, .pFault)
    Set pAnswer = {}
    Do pAnswer.%Set("Name", pName, "string")
    Do pAnswer.%Set("Valid", ''tValid, "boolean")
    Do pAnswer.%Set("ErrorCount", $ListLength(tErrorLines), "number")
    Do pAnswer.%Set("WarningCount", $ListLength(tWarningLines), "number")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The vendor's <code>IsValid</code> of the locale <var>pName</var>, which writes nothing, in <code>%SYS</code> by save and restore:
/// <var>pValid</var> is its answer, <var>pErrors</var> and <var>pWarnings</var> the lines it answered, as <code>%List</code>s. Overridable so
/// a fixture can feed an answer; production never overrides it.</p>
ClassMethod ReadValidation(pName As %String, Output pValid As %Boolean, Output pErrors As %List, Output pWarnings As %List) As %Status
{
    Set tSC = $$$OK
    Set pValid = 0
    Set pErrors = ""
    Set pWarnings = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tValid = ##class(Config.NLS.Locales).IsValid(pName, .tErrors, .tWarnings)
        Set pValid = ''tValid
        For tI = 1:1:+$Get(tErrors) Set pErrors = pErrors _ $ListBuild(tErrors(tI))
        For tI = 1:1:+$Get(tWarnings) Set pWarnings = pWarnings _ $ListBuild(tWarnings(tI))
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The vendor's <code>IsInstallable</code> of the locale <var>pName</var>, in <code>%SYS</code> by save and restore. The vendor's check
/// writes the locale's definition for some locales, so only <method>Install</method> calls it, after the write gate. Overridable so a
/// fixture can feed an answer and see the call; production never overrides it.</p>
ClassMethod ReadInstallable(pName As %String, Output pInstallable As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set pInstallable = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set pInstallable = ''##class(Config.NLS.Locales).IsInstallable(pName)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Install the locale <var>pName</var> as the instance's current locale: the locale is read, the vendor's own check
/// (<method>ReadInstallable</method>) is asked, the rules refuse a locale it does not admit, and then <method>SendInstall</method> installs it with the default collation of IRISTEMP read before and after
/// (<method>TempCollation</method>). Answers <code>{Name, TempCollationBefore, TempCollationAfter}</code>.</p>
ClassMethod Install(pName As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..State(pName, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ReadInstallable(pName, .tInstallable)
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

/// <p>The read a copy's create asks (<code>action</code> <code>COPY</code>): a locale the instance lists is 409 <code>LOCALE.COPY.TAKEN</code>,
/// an unlisted name the 404 a create expects.</p>
ClassMethod Absence(pName As %String, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..State(pName, .tRow, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) Quit ..Refused(##class(OcuPilot.Api.LocaleError).#COPYTAKEN, .pHttpStatus, .pFault)
    Quit tSC
}

/// <p>The locale and the property a request names: the query's <code>locale</code> and <code>name</code>, or, when the request names no
/// locale, the composite id <code>[locale, name]</code> the write tools carry in <code>name</code>.</p>
ClassMethod Target(ByRef pQuery, Output pLocale As %String, Output pName As %String)
{
    Set pLocale = $Get(pQuery(..#LOCALEKEY))
    Set pName = $Get(pQuery(..#NAMEKEY))
    If pLocale '= "" Quit
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pName)
    If $ListLength(tParts) '= 2 Quit
    Set pLocale = $List(tParts, 1)
    Set pName = $List(tParts, 2)
}

/// <p>Serve the <code>Properties</code> endpoint for request type <var>pType</var>: <code>LIST</code> and <code>GET</code> read the rows of
/// the locale the request names; the four writes are judged by <method>Judge</method> and then sent under a lock on the locale.</p>
ClassMethod Property(pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Do ..Target(.pQuery, .tLocale, .tName)
    If (pType = ..#TYPELIST) || (pType = ..#TYPEGET) {
        Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
        If (pType = ..#TYPELIST) && (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
            Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
        }
        Set tSC = ..State(tLocale, .tLocaleRow, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        Set tSC = ..LocaleProperties(tLocale, .tProps)
        If $$$ISERR(tSC) Quit ..Fail("the properties of a locale could not be read", tSC, .pHttpStatus, .pFault)
        Set tSC = ..PropertyRows(tLocale, tLocaleRow, .tProps, .tRows, .tIndex)
        If $$$ISERR(tSC) Quit ..Fail("the properties of a locale could not be listed", tSC, .pHttpStatus, .pFault)
        If pType = ..#TYPELIST {
            Set tMax = $Select(tMaxText = "": ..#DEFAULTMAXROWS, 1: +tMaxText)
            Set pResult = []
            Set tIterator = tRows.%GetIterator()
            While tIterator.%GetNext(.tIndexNumber, .tRow) {
                If pResult.%Size() >= tMax Quit
                Do pResult.%Push(tRow)
            }
            Set pHttpStatus = 200
            Quit $$$OK
        }
        If '$Data(tIndex(tName)) {
            Quit ..Refused(##class(OcuPilot.Api.ConfigError).#SETTINGNOTFOUND, .pHttpStatus, .pFault)
        }
        If $Get(pQuery(..#ACTIONKEY)) = ..#TYPEADD {
            Quit ..Refused(##class(OcuPilot.Api.LocaleError).#TABLETAKEN, .pHttpStatus, .pFault)
        }
        Set pResult = tIndex(tName)
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Quit ..WriteUnderLock(pType, tLocale, tName, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Take the lock on the locale <var>pLocale</var>, judge and send the write <var>pType</var>, and release the lock.</p>
ClassMethod WriteUnderLock(pType As %String, pLocale As %String, pName As %String, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tTarget = pLocale
    Lock +^OcuPilotLocaleWrite(tTarget):5
    If '$Test Quit ..Fail("the locale " _ tTarget _ " is being written by another request", $$$ERROR($$$GeneralError, "the locale's lock is held"), .pHttpStatus, .pFault)
    Try {
        Set tSC = ..Send(pType, pLocale, pName, pBody, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("a locale write failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Lock -^OcuPilotLocaleWrite(tTarget)
    Quit tSC
}

/// <p>The write <var>pType</var>, judged against the fresh read (<method>Judge</method>) and then sent, with the complete settable set the read
/// holds and the one change applied (AD-4). A copy's <var>pLocale</var> is the new locale's name; the others' <var>pName</var> is the property row.</p>
ClassMethod Send(pType As %String, pLocale As %String, pName As %String, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..Judge(pType, pLocale, pName, pBody, .tProps, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If pType = ..#TYPECOPY {
        Merge tCopy = tProps
        Set tCopy("Description") = $Select(pBody.%GetTypeOf("Description") = "string": pBody.%Get("Description"), 1: $Get(tProps("Description")))
        Set tVendor = ..SendCreate(pLocale, .tCopy)
        If $$$ISERR(tVendor) Quit ..Fail("the copy of a locale was refused by the vendor", tVendor, .pHttpStatus, .pFault)
        Set pResult = {}
        Do pResult.%Set("Name", pLocale, "string")
        Do pResult.%Set("Description", tCopy("Description"), "string")
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Set tList = $Piece(pName, ":", 1)
    Set tTable = $Piece(pName, ":", 2, *)
    If pType = ..#TYPELOAD {
        Set tVendor = ..SendLoad(pLocale, ..TypeOf(tList), tTable)
        If $$$ISERR(tVendor) {
            Do ..LogFault("the load of the table " _ pName _ " was refused by the vendor", tVendor, ##class(OcuPilot.Api.LocaleError).#TABLENOTLOADABLE)
            Quit ..Refused(##class(OcuPilot.Api.LocaleError).#TABLENOTLOADABLE, .pHttpStatus, .pFault)
        }
        Set pResult = {}
        Do pResult.%Set("Locale", pLocale, "string")
        Do pResult.%Set("Name", pName, "string")
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Do ..SettableSet(.tProps, .tSet)
    Set tValue = ""
    If pType = ..#TYPESET {
        Set tValue = pBody.%Get("Value")
        Set tSet(pName) = $Select(..NameCount(pName): " " _ tValue, 1: tValue)
    } ElseIf pType = ..#TYPEADD {
        If $Data(tSet(tList)) = 1 Kill tSet(tList)
        If tList = ..#IOLIST {
            Set tSet(tList, tTable) = $ListBuild(pBody.%Get("InputFrom"), $Get(tProps("CharacterSet")), $Get(tProps("CharacterSet")), pBody.%Get("OutputTo"))
            Set tValue = pBody.%Get("InputFrom") _ " / " _ pBody.%Get("OutputTo")
        } Else {
            Set tSet(tList, tTable) = ""
            Set tValue = tTable
        }
    } Else {
        Kill tSet(tList, tTable)
        If '$Data(tSet(tList)) Set tSet(tList) = ""
    }
    Set tVendor = ..SendModify(pLocale, .tSet)
    If $$$ISERR(tVendor) {
        If pType = ..#TYPESET {
            Do ..LogFault("the property " _ pName _ " of a locale was refused by the vendor", tVendor, ##class(OcuPilot.Api.ConfigError).#SETTINGVALUE)
            Quit ..Refused(##class(OcuPilot.Api.ConfigError).#SETTINGVALUE, .pHttpStatus, .pFault)
        }
        Quit ..Fail("the change to a locale's tables was refused by the vendor", tVendor, .pHttpStatus, .pFault)
    }
    Set pResult = {}
    Do pResult.%Set("Locale", pLocale, "string")
    Do pResult.%Set("Name", pName, "string")
    If pType '= ..#TYPEREMOVE Do pResult.%Set("Value", tValue, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Judge the write <var>pType</var> against the instance's own state, before any vendor call, and answer the refusal it meets as a status
/// with <var>pHttpStatus</var> and <var>pFault</var>. <var>pProps</var> is the fresh <code>Get</code> of the locale (of the source, for a copy)
/// and <var>pRow</var> the property row the write names. The mint's rules and the confirmed write both ask it; it sends nothing.</p>
/// <p>A copy: <var>pLocale</var> is the new name and <var>pBody</var> carries <code>Source</code>. The others: <var>pLocale</var> is the locale
/// and <var>pName</var> the row, <code>&lt;list&gt;:&lt;table&gt;</code> for a table.</p>
ClassMethod Judge(pType As %String, pLocale As %String, pName As %String, pBody As %DynamicAbstractObject, ByRef pProps, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pRow = ""
    Set tRules = "OcuPilot.Area.OsMgmt.LocaleRules"
    If pType = ..#TYPECOPY {
        Set tBodyOK = $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") && (pBody.%GetTypeOf("Source") = "string")
        If tBodyOK Set tBodyOK = (pBody.%GetTypeOf("Description") = "unassigned") || (pBody.%GetTypeOf("Description") = "string")
        If tBodyOK && (pBody.%GetTypeOf("Description") = "string") {
            Set tMaxLength = $ListGet(..VendorLimits("Description"), 5)
            If (tMaxLength '= "") && ($Length(pBody.%Get("Description")) > tMaxLength) Set tBodyOK = 0
        }
        If 'tBodyOK Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONCOPYBODY, .pHttpStatus, .pFault)
        Set tSource = pBody.%Get("Source")
        Set tSC = ..State(tSource, .tSourceRow, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        Set tCode = $ClassMethod(tRules, "CopyCode", pLocale, tSource)
        If tCode '= "" Quit ..Refused(tCode, .pHttpStatus, .pFault)
        Set tSC = ..State(pLocale, .tTaken, .tHttp, .tFault)
        If $$$ISOK(tSC) Quit ..Refused(##class(OcuPilot.Api.LocaleError).#COPYTAKEN, .pHttpStatus, .pFault)
        If tHttp '= 404 {
            Set pHttpStatus = tHttp
            Set pFault = tFault
            Quit tSC
        }
        Set tSC = ..LocaleProperties(tSource, .pProps)
        If $$$ISERR(tSC) Quit ..Fail("the locale to copy could not be read", tSC, .pHttpStatus, .pFault)
        Quit $$$OK
    }
    Set tSC = ..State(pLocale, .tLocaleRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If pType '= ..#TYPELOAD {
        Set tCode = $ClassMethod(tRules, "EditCode", tLocaleRow)
        If tCode '= "" Quit ..Refused(tCode, .pHttpStatus, .pFault)
    }
    Set tSC = ..LocaleProperties(pLocale, .pProps)
    If $$$ISERR(tSC) Quit ..Fail("the properties of a locale could not be read", tSC, .pHttpStatus, .pFault)
    Set tSC = ..PropertyRows(pLocale, tLocaleRow, .pProps, .tRows, .tIndex)
    If $$$ISERR(tSC) Quit ..Fail("the properties of a locale could not be listed", tSC, .pHttpStatus, .pFault)
    If pType = ..#TYPEADD Quit ..JudgeAdd(pLocale, pName, pBody, .pProps, .tIndex, .pHttpStatus, .pFault)
    If '$Data(tIndex(pName)) Quit ..Refused(##class(OcuPilot.Api.ConfigError).#SETTINGNOTFOUND, .pHttpStatus, .pFault)
    Set pRow = tIndex(pName)
    If pType = ..#TYPESET {
        If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") || (pBody.%GetTypeOf("Value") '= "string") {
            Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONSETBODY, .pHttpStatus, .pFault)
        }
        Set tCode = $ClassMethod(tRules, "SetCode", pRow, ..PropertyLimits(pLocale, pName, .pProps), pBody.%Get("Value"))
    } ElseIf pType = ..#TYPEREMOVE {
        Set tCode = $ClassMethod(tRules, "RemoveCode", pRow, .pProps)
    } Else {
        Set tCode = $ClassMethod(tRules, "LoadCode", pRow)
    }
    If tCode '= "" Quit ..Refused(tCode, .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>The part of <method>Judge</method> that judges an added table: the list is one of the nine, the sides belong only to an input/output
/// table, the table is not listed and the instance holds it for the locale's character set.</p>
ClassMethod JudgeAdd(pLocale As %String, pName As %String, pBody As %DynamicAbstractObject, ByRef pProps, ByRef pIndex, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tList = $Piece(pName, ":", 1)
    Set tTable = $Piece(pName, ":", 2, *)
    If (pName '[ ":") || (tTable = "") || (..TypeOf(tList) = "") {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONROWNAME, .pHttpStatus, .pFault)
    }
    Set tIsObject = $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject")
    Set tSides = tIsObject && (pBody.%GetTypeOf("InputFrom") '= "unassigned") || (tIsObject && (pBody.%GetTypeOf("OutputTo") '= "unassigned"))
    If tList = ..#IOLIST {
        If 'tIsObject || (pBody.%GetTypeOf("InputFrom") '= "string") || (pBody.%GetTypeOf("OutputTo") '= "string") || (pBody.%Get("InputFrom") = "") || (pBody.%Get("OutputTo") = "") {
            Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONADDBODY, .pHttpStatus, .pFault)
        }
        If ($Length(tTable) > ..#IONAMEMAXLEN) || ($ZStrip(tTable, "*C") '= tTable) {
            Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONIONAME, .pHttpStatus, .pFault)
        }
    } ElseIf tSides {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONADDBODY, .pHttpStatus, .pFault)
    }
    Set tTaken = $Data(pIndex(pName)) '= 0
    Set tCharacterSet = $Get(pProps("CharacterSet"))
    If tList = ..#IOLIST {
        Set tAvailable = ..TableAvailable(..#IOTYPE, tCharacterSet, pBody.%Get("OutputTo")) && ..TableAvailable(..#IOTYPE, pBody.%Get("InputFrom"), tCharacterSet)
    } Else {
        Set tAvailable = ..TableAvailable(..TypeOf(tList), tCharacterSet, tTable)
    }
    Set tCode = $ClassMethod("OcuPilot.Area.OsMgmt.LocaleRules", "AddCode", tTaken, tAvailable)
    If tCode '= "" Quit ..Refused(tCode, .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>Copy a locale: <var>pName</var> is the new name and <var>pBody</var> carries <code>Source</code> and optionally <code>Description</code>.
/// Answers <code>{Name, Description}</code>; a <code>Description</code> longer than the vendor's limit is 400 <code>PORT.VALIDATION</code>.</p>
ClassMethod Copy(pName As %String, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..WriteUnderLock(..#TYPECOPY, pName, "", pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The table type the list <var>pList</var> holds, in the vendor's spelling, or <code>""</code> for a name that is no list of a locale's
/// tables.</p>
ClassMethod TypeOf(pList As %String) As %String
{
    If pList = ..#IOLIST Quit ..#IOTYPE
    Set tType = ""
    For tI = 1:1:$Length(..#TABLELISTS, ",") {
        Set tEntry = $Piece(..#TABLELISTS, ",", tI)
        If $Piece(tEntry, ":", 1) = pList Set tType = $Piece(tEntry, ":", 2)
    }
    Quit tType
}

/// <p>The names of the property group <var>pGroup</var>, as a <class>%List</class>.</p>
ClassMethod GroupNames(pGroup As %String) As %List
{
    Set tNames = ""
    For tI = 1:1:$Length(..#SCALARGROUPS, "|") {
        Set tEntry = $Piece(..#SCALARGROUPS, "|", tI)
        If $Piece(tEntry, ":", 1) = pGroup Set tNames = $ListFromString($Piece(tEntry, ":", 2), ",")
    }
    Quit tNames
}

/// <p>How many space-separated names the property <var>pName</var> holds, or <code>0</code> for a property that holds none.</p>
ClassMethod NameCount(pName As %String) As %Integer
{
    Set tCount = 0
    For tI = 1:1:$Length(..#NAMECOUNTS, ",") {
        Set tEntry = $Piece(..#NAMECOUNTS, ",", tI)
        If $Piece(tEntry, ":", 1) = pName Set tCount = +$Piece(tEntry, ":", 2)
    }
    Quit tCount
}

/// <p>The complete settable set the fresh read <var>pProps</var> holds, in <var>pSet</var>: every editable scalar, each of the eight table lists
/// and the input/output tables, an empty list as <code>""</code> so the vendor empties it (AD-4). The set is returned as its own array.</p>
ClassMethod SettableSet(ByRef pProps, Output pSet) As %String
{
    Kill pSet
    Set tGroups = $ListBuild("basic", "formats", "strings", "tabledefaults", "iodefaults")
    For tI = 1:1:$ListLength(tGroups) {
        Set tNames = ..GroupNames($List(tGroups, tI))
        For tJ = 1:1:$ListLength(tNames) {
            Set tName = $List(tNames, tJ)
            If $Data(pProps(tName)) = 1 Set pSet(tName) = pProps(tName)
        }
    }
    Set tLists = ..#IOLIST
    For tI = 1:1:$Length(..#TABLELISTS, ",") Set tLists = tLists _ "," _ $Piece($Piece(..#TABLELISTS, ",", tI), ":", 1)
    For tI = 1:1:$Length(tLists, ",") {
        Set tList = $Piece(tLists, ",", tI)
        Set tKey = ""
        For {
            Set tKey = $Order(pProps(tList, tKey))
            If tKey = "" Quit
            Set pSet(tList, tKey) = pProps(tList, tKey)
        }
        If '$Data(pSet(tList)) Set pSet(tList) = ""
    }
    Quit ""
}

/// <p>The limits of the property <var>pName</var> of <var>pLocale</var>, in <method>OcuPilot.Port.ConfigPort.Limits</method>'s shape: the
/// date and time formats a range, a table default a choice of its list's members, an input/output default a choice of the input/output tables the
/// instance holds for the locale, and every other property the vendor's declared limits. <code>""</code> for a property with none.</p>
ClassMethod PropertyLimits(pLocale As %String, pName As %String, ByRef pProps) As %List
{
    If pName = "DateFormat" Quit $ListBuild("integer", 0, 14, "", "", "")
    If pName = "TimeFormat" Quit $ListBuild("integer", 1, 4, "", "", "")
    If $ListFind(..GroupNames("tabledefaults"), pName) {
        Set tList = pName _ "s"
        Set tMembers = ""
        Set tKey = ""
        For {
            Set tKey = $Order(pProps(tList, tKey))
            If tKey = "" Quit
            Set tMembers = tMembers _ $ListBuild(tKey)
        }
        Quit $ListBuild("choice", "", "", tMembers, "", "")
    }
    If $ListFind(..GroupNames("iodefaults"), pName) Quit $ListBuild("choice", "", "", ..LocaleTables(pLocale, ..#IOTYPE, 1), "", "")
    Quit ..VendorLimits(pName)
}

/// <p>The vendor's declared limits of the property <var>pName</var> of a locale definition (<method>OcuPilot.Port.ConfigPort.ClassLimits</method>).</p>
ClassMethod VendorLimits(pName As %String) As %List
{
    Quit ##class(OcuPilot.Port.ConfigPort).ClassLimits(..#VENDORCLASS, pName)
}

/// <p>One property row: <code>{Locale, Group, Name, Value, Kind, Accepts, ReadOnly, Refusal, Loadable}</code>.</p>
ClassMethod NewRow(pLocale As %String, pGroup As %String, pName As %String, pValue As %String, pKind As %String, pAccepts As %String, pReadOnly As %Boolean, pRefusal As %String, pLoadable As %Boolean) As %DynamicObject [ Private ]
{
    Set tRow = {}
    Do tRow.%Set("Locale", pLocale, "string")
    Do tRow.%Set("Group", pGroup, "string")
    Do tRow.%Set("Name", pName, "string")
    Do tRow.%Set("Value", pValue, "string")
    Do tRow.%Set("Kind", pKind, "string")
    Do tRow.%Set("Accepts", pAccepts, "string")
    Do tRow.%Set("ReadOnly", ''pReadOnly, "boolean")
    Do tRow.%Set("Refusal", pRefusal, "string")
    Do tRow.%Set("Loadable", ''pLoadable, "boolean")
    Quit tRow
}

/// <p>One row per property, table and input/output table of the locale <var>pLocale</var>, from the fresh read <var>pProps</var>: the editable
/// properties by group, the shown ones, each member of the eight internal table lists and each input/output table. <var>pIndex</var> holds each
/// row by its <code>Name</code>. A table is <code>Loadable</code> only when its type is one a load accepts and the instance's own
/// <code>Tables</code> query lists it for the locale as a table that is not built in, compared exactly.</p>
ClassMethod PropertyRows(pLocale As %String, pLocaleRow As %DynamicObject, ByRef pProps, Output pRows As %DynamicArray, ByRef pIndex) As %Status [ Private ]
{
    Set tSC = $$$OK
    Kill pIndex
    Set pRows = []
    Try {
        Set tRefusal = $ClassMethod("OcuPilot.Area.OsMgmt.LocaleRules", "EditCode", pLocaleRow)
        Set tReadOnlyText = ##class(OcuPilot.Api.ConfigError).#ACCEPTSREADONLY
        For tI = 1:1:$Length(..#LOADTYPES, ",") {
            Set tType = $Piece(..#LOADTYPES, ",", tI)
            Set tLoadable(tType) = ..LocaleTables(pLocale, tType, 0)
        }
        Set tOrder = $ListBuild("basic", "formats", "tables", "iotables", "tabledefaults", "iodefaults", "strings")
        For tI = 1:1:$ListLength(tOrder) {
            Set tGroup = $List(tOrder, tI)
            If tGroup = "tables" {
                For tJ = 1:1:$Length(..#TABLELISTS, ",") {
                    Set tList = $Piece($Piece(..#TABLELISTS, ",", tJ), ":", 1)
                    Set tType = $Piece($Piece(..#TABLELISTS, ",", tJ), ":", 2)
                    Set tKey = ""
                    For {
                        Set tKey = $Order(pProps(tList, tKey))
                        If tKey = "" Quit
                        Set tLoad = ''$ListFind($ListFromString(..#LOADTYPES, ","), tType) && ''$ListFind($Get(tLoadable(tType)), tKey)
                        If tLoad Set tLoad = $Select(tType = "COL": ..TableLoadable(tType, tKey, $Get(pProps("CharacterSet"))) && ..TableLoadable(tType, $Get(pProps("CharacterSet")), tKey), 1: ..TableLoadable(tType, $Get(pProps("CharacterSet")), tKey))
                        Set tRow = ..NewRow(pLocale, tGroup, tList _ ":" _ tKey, tKey, "table", tReadOnlyText, 1, tRefusal, tLoad)
                        Do pRows.%Push(tRow)
                        Set pIndex(tList _ ":" _ tKey) = tRow
                    }
                }
                Continue
            }
            If tGroup = "iotables" {
                Set tKey = ""
                For {
                    Set tKey = $Order(pProps(..#IOLIST, tKey))
                    If tKey = "" Quit
                    Set tEntry = pProps(..#IOLIST, tKey)
                    Set tLoad = ''$ListFind($Get(tLoadable(..#IOTYPE)), tKey)
                    If tLoad Set tLoad = ..TableLoadable(..#IOTYPE, $List(tEntry, 1), $List(tEntry, 2)) && ..TableLoadable(..#IOTYPE, $List(tEntry, 3), $List(tEntry, 4))
                    Set tRow = ..NewRow(pLocale, tGroup, ..#IOLIST _ ":" _ tKey, $List(tEntry, 1) _ " / " _ $List(tEntry, 4), "table", tReadOnlyText, 1, tRefusal, tLoad)
                    Do pRows.%Push(tRow)
                    Set pIndex(..#IOLIST _ ":" _ tKey) = tRow
                }
                Continue
            }
            Set tNames = ..GroupNames(tGroup)
            For tJ = 1:1:$ListLength(tNames) {
                Set tName = $List(tNames, tJ)
                If $Data(pProps(tName)) '= 1 Continue
                Set tLimits = ..PropertyLimits(pLocale, tName, .pProps)
                If tLimits = "" Continue
                Set tValue = pProps(tName)
                If ..NameCount(tName) && ($Extract(tValue) = " ") Set tValue = $Extract(tValue, 2, *)
                Set tRow = ..NewRow(pLocale, tGroup, tName, tValue, $ListGet(tLimits, 1), ##class(OcuPilot.Port.ConfigPort).AcceptsOf(tLimits), 0, tRefusal, 0)
                Do pRows.%Push(tRow)
                Set pIndex(tName) = tRow
            }
            If tGroup = "basic" {
                Set tShown = $ListFromString(..#SHOWN, ",")
                For tJ = 1:1:$ListLength(tShown) {
                    Set tName = $List(tShown, tJ)
                    If $Data(pProps(tName)) '= 1 Continue
                    Set tRow = ..NewRow(pLocale, tGroup, tName, pProps(tName), "text", tReadOnlyText, 1, tRefusal, 0)
                    Do pRows.%Push(tRow)
                    Set pIndex(tName) = tRow
                }
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
        Set pRows = []
    }
    Quit tSC
}

/// <p>The locale <var>pLocale</var>'s fresh <code>Get</code>, in <var>pProps</var>, read in <code>%SYS</code> by save and restore, with the
/// vendor's comment nodes dropped. Overridable so a fixture can pose a definition; production never overrides it.</p>
ClassMethod LocaleProperties(pLocale As %String, ByRef pProps) As %Status
{
    Set tSC = $$$OK
    Kill pProps
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = $ClassMethod(..#VENDORCLASS, "Get", pLocale, .pProps)
        Set tKey = ""
        For {
            Set tKey = $Order(pProps(tKey))
            If tKey = "" Quit
            Kill pProps(tKey, "Comment"), pProps(tKey, "Comments")
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The names of the tables of type <var>pType</var> the instance holds for <var>pLocale</var>, as a <class>%List</class>: the vendor's
/// <code>Tables</code> query, with built-in tables only when <var>pBuiltIn</var>. The locale is one the port has read from its own list.
/// Overridable so a fixture can pose an answer; production never overrides it.</p>
ClassMethod LocaleTables(pLocale As %String, pType As %String, pBuiltIn As %Boolean = 0) As %List
{
    Set tNames = ""
    Set tRS = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New("Config.NLS.Locales:Tables")
        Set tSC = tRS.Execute(pLocale, pType, ''pBuiltIn)
        If $$$ISOK(tSC) {
            Set tCount = 0
            While tRS.Next() {
                If $Increment(tCount) > ..#LOCALESMAXROWS Quit
                Set tNames = tNames _ $ListBuild(tRS.GetData(1))
            }
        }
    } Catch {
        Set tNames = ""
    }
    Set tRS = ""
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tNames
}

/// <p>Whether the instance holds a table of type <var>pType</var> that the character set <var>pCharacterSet</var> pairs with the table
/// <var>pTable</var>, found in the vendor's <code>Tables:List</code> by an exact comparison (a collation table is listed the other way
/// round), or, for type <code>XLT</code>, a translation from <var>pCharacterSet</var> to <var>pTable</var>. Overridable so a fixture can pose an answer;
/// production never overrides it.</p>
ClassMethod TableAvailable(pType As %String, pCharacterSet As %String, pTable As %String) As %Boolean
{
    Set tFound = 0
    Set tRS = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If pType = ..#IOTYPE {
            Set tFound = ''##class(Config.NLS.Tables).Exists(..#IOTYPE, pCharacterSet, pTable)
        } Else {
            Set tRS = ##class(%ResultSet).%New("Config.NLS.Tables:List")
            Set tSC = tRS.Execute(pType, "*", "*")
            If $$$ISOK(tSC) {
                Set tCount = 0
                While tRS.Next() {
                    If $Increment(tCount) > ..#LOCALESMAXROWS Quit
                    Set tFrom = tRS.Get("NameFrom")
                    Set tTo = tRS.Get("NameTo")
                    If $Select(pType = "COL": (tFrom = pTable) && (tTo = pCharacterSet), 1: (tFrom = pCharacterSet) && (tTo = pTable)) {
                        Set tFound = 1
                        Quit
                    }
                }
            }
        }
    } Catch {
        Set tFound = 0
    }
    Set tRS = ""
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tFound
}

/// <p>Whether the vendor holds the table of type <var>pType</var> from <var>pFrom</var> to <var>pTo</var> compiled, so that a load can find it
/// (<code>Config.NLS.Tables.IsLoadable</code>). A table a locale lists but the instance never compiled is not loadable. Overridable so a fixture
/// can pose an answer; production never overrides it.</p>
ClassMethod TableLoadable(pType As %String, pFrom As %String, pTo As %String) As %Boolean
{
    Set tLoadable = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tLoadable = ''##class(Config.NLS.Tables).IsLoadable(pType, pFrom, pTo)
    } Catch {
        Set tLoadable = 0
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tLoadable
}

/// <p>The one call that creates a locale: the vendor's <code>Create</code> of <var>pName</var> with the definition <var>pProps</var>, in
/// <code>%SYS</code> by save and restore. Overridable so a fixture can record the call; production never overrides it.</p>
ClassMethod SendCreate(pName As %String, ByRef pProps) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Config.NLS.Locales).Create(pName, .pProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The one call that changes a locale: the vendor's <code>Modify</code> of <var>pLocale</var> with the complete settable set
/// <var>pSet</var>, in <code>%SYS</code> by save and restore. Overridable so a fixture can record the call; production never overrides
/// it.</p>
ClassMethod SendModify(pLocale As %String, ByRef pSet) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Config.NLS.Locales).Modify(pLocale, .pSet)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The one call that loads a table: the vendor's <code>Tables.Load</code> of the table <var>pTable</var> of type <var>pType</var> that
/// <var>pLocale</var> lists, in <code>%SYS</code> by save and restore. Overridable so a fixture can record the call; production never overrides
/// it.</p>
ClassMethod SendLoad(pLocale As %String, pType As %String, pTable As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Config.NLS.Tables).Load(pLocale, pType, pTable)
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
    If ##class(OcuPilot.Api.LocaleError).HttpStatusFor(pCode) = 0 {
        Quit ..Refuse(##class(OcuPilot.Api.ConfigError).HttpStatusFor(pCode), ##class(OcuPilot.Api.ConfigError).SlugFor(pCode), pCode, ##class(OcuPilot.Api.ConfigError).ReasonFor(pCode), .pHttpStatus, .pFault)
    }
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
    If pEndpoint = ..#PROPERTIESENDPOINT Quit ..PropertySnippet(pType, .pQuery, pBody)
    Set tName = $ClassMethod(tAdmin, "Literal", $Get(pQuery(..#NAMEKEY)))
    If pType = ..#TYPECOPY {
        Set tSource = $ClassMethod(tAdmin, "Literal", $Select($IsObject(pBody) && (pBody.%GetTypeOf("Source") = "string"): pBody.%Get("Source"), 1: ""))
        Set tLines = $ListBuild("Set tSC = ##class(Config.NLS.Locales).Get(" _ tSource _ ", .tProps)", "Set tProps(""Name"") = " _ tName)
        If $IsObject(pBody) && (pBody.%GetTypeOf("Description") = "string") {
            Set tLines = tLines _ $ListBuild("Set tProps(""Description"") = " _ $ClassMethod(tAdmin, "Literal", pBody.%Get("Description")))
        }
        Set tLines = tLines _ $ListBuild("Set tSC = ##class(Config.NLS.Locales).Create(" _ tName _ ", .tProps)")
        Quit [($ClassMethod(tAdmin, "ObjectScriptStep", tLines))]
    }
    Set tLine = "Set tSC = ##class(Config.NLS.Locales)." _ $Select(pType = ..#TYPEINSTALL: "Install", 1: "Delete") _ "(" _ tName _ ")"
    Quit [($ClassMethod(tAdmin, "ObjectScriptStep", $ListBuild(tLine)))]
}

/// <p>The script of a write on the <code>Properties</code> endpoint (AD-59), with every name and value a string literal: the locale's
/// <code>Get</code>, the one change and <code>Modify</code>, or <code>Tables.Load</code>.</p>
ClassMethod PropertySnippet(pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject) As %DynamicArray [ Private ]
{
    Set tAdmin = "OcuPilot.Port.AdminPort"
    Do ..Target(.pQuery, .tLocale, .tName)
    Set tLocaleLiteral = $ClassMethod(tAdmin, "Literal", tLocale)
    Set tList = $Piece(tName, ":", 1)
    Set tTable = $Piece(tName, ":", 2, *)
    If pType = ..#TYPELOAD Quit [($ClassMethod(tAdmin, "ObjectScriptStep", $ListBuild("Set tSC = ##class(Config.NLS.Tables).Load(" _ tLocaleLiteral _ ", " _ $ClassMethod(tAdmin, "Literal", ..TypeOf(tList)) _ ", " _ $ClassMethod(tAdmin, "Literal", tTable) _ ")")))]
    Set tLines = $ListBuild("Set tSC = ##class(Config.NLS.Locales).Get(" _ tLocaleLiteral _ ", .tProps)")
    If pType = ..#TYPESET {
        Set tValue = $Select($IsObject(pBody) && (pBody.%GetTypeOf("Value") = "string"): pBody.%Get("Value"), 1: "")
        Set tLines = tLines _ $ListBuild("Set tProps(" _ $ClassMethod(tAdmin, "Literal", tName) _ ") = " _ $ClassMethod(tAdmin, "Literal", $Select(..NameCount(tName): " " _ tValue, 1: tValue)))
    } ElseIf pType = ..#TYPEADD {
        If tList = ..#IOLIST {
            Set tFrom = $ClassMethod(tAdmin, "Literal", $Select($IsObject(pBody) && (pBody.%GetTypeOf("InputFrom") = "string"): pBody.%Get("InputFrom"), 1: ""))
            Set tTo = $ClassMethod(tAdmin, "Literal", $Select($IsObject(pBody) && (pBody.%GetTypeOf("OutputTo") = "string"): pBody.%Get("OutputTo"), 1: ""))
            Set tLines = tLines _ $ListBuild("Set tProps(" _ $ClassMethod(tAdmin, "Literal", tList) _ ", " _ $ClassMethod(tAdmin, "Literal", tTable) _ ") = $ListBuild(" _ tFrom _ ", tProps(""CharacterSet""), tProps(""CharacterSet""), " _ tTo _ ")")
        } Else {
            Set tLines = tLines _ $ListBuild("Set tProps(" _ $ClassMethod(tAdmin, "Literal", tList) _ ", " _ $ClassMethod(tAdmin, "Literal", tTable) _ ") = """"")
        }
    } Else {
        Set tLines = tLines _ $ListBuild("Kill tProps(" _ $ClassMethod(tAdmin, "Literal", tList) _ ", " _ $ClassMethod(tAdmin, "Literal", tTable) _ ")")
    }
    Set tLines = tLines _ $ListBuild("Set tSC = ##class(Config.NLS.Locales).Modify(" _ tLocaleLiteral _ ", .tProps)")
    Quit [($ClassMethod(tAdmin, "ObjectScriptStep", tLines))]
}

}
