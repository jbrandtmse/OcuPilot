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
/// <p><b>Import and export (Story 21.15).</b> The vendor's <code>ImportAll</code> and <code>ExportList</code> are handed only a temporary file this port
/// names under <parameter>TRANSFERDIRECTORY</parameter> and deletes on every path; no caller value is a path. An import's text is a server file
/// (<parameter>ROOTPARAM</parameter> and <parameter>PATHPARAM</parameter>, resolved through <class>OcuPilot.Port.PathPort</class> as a source) or the
/// screen's local text; <method>ImportReview</method> keeps only the custom records, the file the vendor reads holds just those, and the review's
/// digest and replaced-record count are compared again at the write. An export names one listed locale and copies the vendor's file to the resolved
/// server file or answers it as lines; it is judged against <parameter>PAIRS</parameter>.</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>LogFault</method>, <method>ReadValidation</method>,
/// <method>ReadInstallable</method>, <method>TempCollation</method>, <method>SendInstall</method>, <method>SendDelete</method>,
/// <method>CurrentFootprint</method>, <method>VendorImport</method>, <method>VendorExport</method>, <method>PathPortClass</method>,
/// <method>TransferParent</method>, <method>TransferName</method>, <method>TakeLock</method> and <method>ReleaseLock</method>. Production overrides none of them.</p>
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

/// <p>The import file as reviewed: its custom records, counted (Story 21.15).</p>
Parameter TYPEIMPORTFILE = "IMPORTFILE";

/// <p>One locale as an export reads it.</p>
Parameter TYPEEXPORTLOCALE = "EXPORTLOCALE";

Parameter TYPEIMPORT = "IMPORT";

Parameter TYPEEXPORT = "EXPORT";

/// <p>The write request types.</p>
Parameter WRITETYPES = "INSTALL,DELETE,COPY,SET,ADD,REMOVE,LOAD,IMPORT,EXPORT";

/// <p>The write types judged against <parameter>PAIRS</parameter> alone: an export changes no locale or table, so it needs no
/// <code>%DB_IRISSYS:WRITE</code>.</p>
Parameter READPAIRWRITES = "EXPORT";

/// <p>The literal an import names as its target: it names a file, not a locale.</p>
Parameter IMPORTID = "import";

/// <p>The query keys of a transfer: the server file (<parameter>ROOTPARAM</parameter> and <parameter>PATHPARAM</parameter>), the local file
/// (<parameter>FILENAMEPARAM</parameter> and <parameter>CONTENTPARAM</parameter>) and the reviewed values an import's write compares.</p>
Parameter ROOTPARAM = "root";

Parameter PATHPARAM = "path";

Parameter FILENAMEPARAM = "fileName";

Parameter CONTENTPARAM = "content";

Parameter DIGESTPARAM = "digest";

Parameter LOCALESPARAM = "locales";

Parameter TABLESPARAM = "tables";

Parameter SUBTABLESPARAM = "subtables";

Parameter REPLACESPARAM = "replaces";

/// <p>An export replaces a file already at its name: the overwrite is this constant, never a caller's.</p>
Parameter EXPORTOVERWRITES As BOOLEAN = 1;

/// <p>The vendor's import flags: sub-tables, tables and locales.</p>
Parameter IMPORTFLAGS As INTEGER = 7;

/// <p>The most locale names an import review lists.</p>
Parameter LISTEDLOCALES As INTEGER = 50;

/// <p>The name every transfer's directory starts with, under the operating system's temporary directory; the rest of the name is unique to the transfer.</p>
Parameter TRANSFERDIRECTORY = "ocupilot-locale";

/// <p>The shape a locale record's name must have to be imported: <code>y</code>, two lowercase letters or digits, and <code>8</code> or
/// <code>w</code>.</p>
Parameter IMPORTNAMEPATTERN = "^y[a-z0-9]{2}[8w]$";

/// <p>The elements a locale record must hold, the properties <code>Config.NLS.Locales</code> requires. The vendor reads a record without them as
/// imported and replaces the existing locale of that name with nothing, so a record that lacks one is not an export.</p>
Parameter IMPORTREQUIRED = "CharacterSet,CollationTable,CollationTables,Country,CountryAbbr,DateSeparator,DecimalSeparator,IdentifierTable,IdentifierTables,Language,LanguageAbbr,MinusSign,MonthAbbr,MonthName,NumericGroupSeparator,PatternTable,PatternTables,PlusSign,TimeSeparator,TranDDP,TranDTMDCP,TranMagTape,TranPrinter,TranTCP,TranProgrammer,TranSequential,TranSystemCall,TranTerminal,TranZCVT,WeekdayAbbr,WeekdayName,XYTable,XYTables";

/// <p>The write types that take a body.</p>
Parameter BODYTYPES = "COPY,SET,ADD";

/// <p>The writes whose call this port composes from their arguments, as <code>endpoint/type</code>: an import and an export send no caller body.</p>
Parameter COMPOSEDTYPES = "Locales/EXPORT,Locales/IMPORT";

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

/// <p>The input/output defaults the vendor requires that the classic editor does not show: never a row, but their tables are defaults all the same.</p>
Parameter IOHIDDENDEFAULTS = "TranDDP,TranDTMDCP";

/// <p>The seconds a write waits for another write to the same locale to finish.</p>
Parameter LOCKSECONDS As INTEGER = 5;

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
    If pEndpoint = ..#LOCALESENDPOINT Quit (pType = ..#TYPELIST) || (pType = ..#TYPEGET) || (pType = ..#TYPEINSTALL) || (pType = ..#TYPEDELETE) || (pType = ..#TYPECOPY) || (pType = ..#TYPEIMPORTFILE) || (pType = ..#TYPEEXPORTLOCALE) || (pType = ..#TYPEIMPORT) || (pType = ..#TYPEEXPORT)
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
        If pType = ..#TYPEIMPORTFILE {
            Set tSC = ..ReadImportFile(tName, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPEIMPORT {
            Set tSC = ..ImportUnderLock(tName, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPEEXPORTLOCALE {
            Set tSC = ..ReadExportLocale(tName, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPEEXPORT {
            Set tSC = ..Export(tName, .pQuery, .pResult, .pHttpStatus, .pFault)
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

/// <p>The gate: <parameter>WRITEPAIRS</parameter> for a write type that changes a locale, otherwise <parameter>PAIRS</parameter>.</p>
ClassMethod Admit(pType As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tFailedPair = ""
    Set tWrites = ..IsWrite(pType) && '$ListFind($ListFromString(..#READPAIRWRITES), pType)
    ; EvaluateRequired, not EvaluatePairs: a pair parameter mis-edited to empty fails closed.
    If $ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs($Select(tWrites: ..#WRITEPAIRS, 1: ..#PAIRS)), .tFailedPair) Quit $$$OK
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

/// <p>Take the lock on the locale <var>pLocale</var>, judge and send the write <var>pType</var>, and release the lock. The lock is a node of
/// <code>^CacheTemp.OcuPilotLocaleWrite</code>, in the instance's temporary database, so a caller holding only the screen's pairs can take it;
/// a lock another request keeps past <parameter>LOCKSECONDS</parameter> is 409 <code>WRITE.TARGETBUSY</code>.</p>
ClassMethod WriteUnderLock(pType As %String, pLocale As %String, pName As %String, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tTarget = pLocale
    If tTarget = "" Quit ..Refused(##class(OcuPilot.Api.LocaleError).#NOTFOUND, .pHttpStatus, .pFault)
    If '..TakeLock(tTarget) Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#WRITETARGETBUSY, ##class(OcuPilot.Api.Error).#REASONWRITETARGETBUSY, .pHttpStatus, .pFault)
    Try {
        Set tSC = ..Send(pType, pLocale, pName, pBody, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("a locale write failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Do ..ReleaseLock(tTarget)
    Quit tSC
}

/// <p>Take the write lock on <var>pTarget</var>, waiting <parameter>LOCKSECONDS</parameter>; whether it was taken.</p>
ClassMethod TakeLock(pTarget As %String) As %Boolean [ Private ]
{
    Lock +^CacheTemp.OcuPilotLocaleWrite(pTarget):..#LOCKSECONDS
    Quit $Test
}

/// <p>Release the lock <method>TakeLock</method> took.</p>
ClassMethod ReleaseLock(pTarget As %String) [ Private ]
{
    Lock -^CacheTemp.OcuPilotLocaleWrite(pTarget)
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
/// and the input/output tables, an empty list as <code>""</code> so the vendor empties it (AD-4).</p>
ClassMethod SettableSet(ByRef pProps, Output pSet) As %Status
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
    Quit $$$OK
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

/// <p>The class that resolves the allowed directories (AD-21). Overridable so a fixture can move them; production never overrides it.</p>
ClassMethod PathPortClass() As %String
{
    Quit "OcuPilot.Port.PathPort"
}

/// <p>The text of the file an import names in <var>pQuery</var>, in <var>pText</var>: the server file <parameter>ROOTPARAM</parameter> and
/// <parameter>PATHPARAM</parameter> name, resolved through <method>PathPortClass</method> as a <code>source</code> and read as UTF-8 text, or the
/// local file <parameter>FILENAMEPARAM</parameter> and <parameter>CONTENTPARAM</parameter> send. Refused before any vendor call: 400
/// <code>PORT.VALIDATION</code> when both files or neither is named, or a local file's name is longer than
/// <parameter>OcuPilot.Port.AtelierPort.MAXFILENAME</parameter> or holds <code>/</code>, <code>\</code> or a control character; the resolve's own
/// refusal on its field; and 409 <code>LOCALE.TOOLARGE</code> for text longer than <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter>.</p>
ClassMethod ImportText(ByRef pQuery, Output pText As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pText = ""
    Set tRoot = $Get(pQuery(..#ROOTPARAM))
    Set tPath = $Get(pQuery(..#PATHPARAM))
    Set tFileName = $Get(pQuery(..#FILENAMEPARAM))
    Set tContent = $Get(pQuery(..#CONTENTPARAM))
    Set tServer = (tRoot '= "") || (tPath '= "")
    Set tLocal = (tFileName '= "") || (tContent '= "")
    If tServer = tLocal Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Port.InteropPort).#REASONIMPORTSOURCE, .pHttpStatus, .pFault)
    If tLocal {
        If (tFileName = "") || ($Length(tFileName) > ##class(OcuPilot.Port.AtelierPort).#MAXFILENAME) || (tFileName [ "/") || (tFileName [ "\") || ($ZStrip(tFileName, "*C") '= tFileName) {
            Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Port.InteropPort).#REASONIMPORTFILENAME, .pHttpStatus, .pFault)
        }
        If $Length(tContent) > ##class(OcuPilot.Port.AtelierPort).#MAXIMPORTCHARACTERS Quit ..Refused(##class(OcuPilot.Api.LocaleError).#TOOLARGE, .pHttpStatus, .pFault)
        Set pText = tContent
        Quit $$$OK
    }
    Set tPathPort = ..PathPortClass()
    Set tSC = $ClassMethod(tPathPort, "Resolve", tRoot, tPath, $Parameter(tPathPort, "KINDSOURCE"), ..#ROOTPARAM, ..#PATHPARAM, .tResolved, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Port.AtelierPort).ReadText(tResolved, .pText, .tTooLarge)
    If $$$ISERR(tSC) Quit ..Fail("the import's file could not be read", tSC, .pHttpStatus, .pFault)
    If tTooLarge {
        Set pText = ""
        Quit ..Refused(##class(OcuPilot.Api.LocaleError).#TOOLARGE, .pHttpStatus, .pFault)
    }
    Quit $$$OK
}

/// <p>The SHA-256 of <var>pText</var>'s UTF-8 bytes, as lower-case hex; <code>""</code> when it cannot be computed.</p>
ClassMethod TextDigest(pText As %String) As %String [ Private ]
{
    Set tDigest = ""
    Try {
        Set tBytes = ##class(%Stream.GlobalBinary).%New()
        For tAt = 1:30000:$Length(pText) {
            Do tBytes.Write($ZConvert($Extract(pText, tAt, tAt + 29999), "O", "UTF8"))
        }
        Do tBytes.Rewind()
        Set tHash = $System.Encryption.SHAHashStream(256, tBytes, .tHashSC)
        If $$$ISOK(tHashSC) Set tDigest = $ZConvert(##class(%xsd.hexBinary).LogicalToXSD(tHash), "L")
    } Catch {
        Set tDigest = ""
    }
    Quit tDigest
}

/// <p><var>pText</var> escaped as XML character data.</p>
ClassMethod XmlText(pText As %String) As %String [ Private ]
{
    Quit $Replace($Replace($Replace(pText, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
}

/// <p>Read <var>pText</var> as a locale and table export and sort its records. <var>pShape</var> is 1 when the text is not well-formed, holds an
/// element or attribute with a namespace prefix inside a record, or holds a record the vendor could not read (a locale with no name or a name
/// that is not <parameter>IMPORTNAMEPATTERN</parameter>, a table with no type or no side, a sub-table with no name or no type). Only the three
/// record paths of the vendor's own export are read. <var>pScan</var> holds, with <code>L</code>, <code>T</code> and <code>S</code> the custom
/// locales, tables and sub-tables kept: <code>pScan("L", n) = $ListBuild(name, xml)</code>, <code>pScan("T", n) = $ListBuild(type, from, to,
/// subTableName, xml)</code> and <code>pScan("S", name) = xml</code>, each with its count in the node itself; <code>pScan("seen")</code> the records
/// read and <code>pScan("skipped")</code> those dropped. A table is custom when its <code>NameFrom</code> or <code>NameTo</code> starts with
/// <parameter>CUSTOMPREFIX</parameter>; a sub-table is kept only when it is custom (<method>IsCustomSubTable</method>) and a kept table names it.
/// Nothing is read from the instance.</p>
ClassMethod ScanImport(pText As %String, Output pScan, Output pShape As %Boolean) As %Status [ Private ]
{
    Kill pScan
    Set pShape = 0
    Set pScan("seen") = 0
    Set pScan("skipped") = 0
    Set pScan("L") = 0
    Set pScan("T") = 0
    Set pScan("S") = 0
    ; KeepWhiteSpace: a property's leading and trailing spaces are part of its value (the month and weekday names hold their leading space).
    Set tSC = ##class(%XML.TextReader).ParseString(pText, .tReader, , , , , 1)
    If $$$ISERR(tSC) {
        Set pShape = 1
        Quit $$$OK
    }
    Set tPrefix = ..#CUSTOMPREFIX
    Set tLocalesPath = "/LocalesDeepExport/LocalesExport/Locales"
    Set tTablesPath = "/LocalesDeepExport/TablesDeepExport/TablesExport/Tables"
    Set tSubTablesPath = "/LocalesDeepExport/TablesDeepExport/SubTablesExport/SubTables"
    Set tRecord = ""
    Set tRecordPath = ""
    Set tDepth = 0
    Set tXml = ""
    Set tField = ""
    Set tText = ""
    While tReader.Read() {
        Set tType = tReader.NodeType
        If tRecord = "" {
            If tType '= "element" Continue
            Set tNow = tReader.Path
            If tNow = tLocalesPath {
                Set tRecord = "L"
            } ElseIf tNow = tTablesPath {
                Set tRecord = "T"
            } ElseIf tNow = tSubTablesPath {
                Set tRecord = "S"
            }
            If tRecord = "" Continue
            Set tRecordPath = tNow
            Set tDepth = tReader.Depth
            Set tXml = ""
            Set tField = ""
            Kill tFields
        }
        If tType = "element" {
            If tReader.Name '= tReader.LocalName Set pShape = 1
            Set tXml = tXml _ "<" _ tReader.Name
            For tI = 1:1:tReader.AttributeCount {
                Do tReader.MoveToAttributeIndex(tI)
                If tReader.Name [ ":" Set pShape = 1
                Set tXml = tXml _ " " _ tReader.Name _ "=""" _ $Replace(..XmlText(tReader.Value), """", "&quot;") _ """"
            }
            Do tReader.MoveToElement()
            Set tXml = tXml _ ">"
            If tReader.Depth = (tDepth + 1) {
                Set tField = tReader.Name
                Set tText = ""
            }
        } ElseIf tType = "chars" {
            Set tXml = tXml _ ..XmlText(tReader.Value)
            If (tField '= "") && (tReader.Depth = (tDepth + 1)) Set tText = tText _ tReader.Value
        } ElseIf tType = "endelement" {
            Set tXml = tXml _ "</" _ tReader.Name _ ">"
            If tReader.Path = tRecordPath {
                Do ..KeepRecord(tRecord, .tFields, tXml, tPrefix, .pScan, .pShape)
                Set tRecord = ""
            } ElseIf (tField '= "") && (tReader.Depth = tDepth) {
                ; A record names each of its values once; a repeated one could be read differently by the vendor.
                If $Data(tFields(tField)) Set pShape = 1
                Set tFields(tField) = tText
                Set tField = ""
            }
        }
    }
    If pShape Quit $$$OK
    ; A sub-table is kept when it is custom and a kept table names it.
    Set tNamed = ""
    For tI = 1:1:pScan("T") {
        Set tSubName = $List(pScan("T", tI), 4)
        If (tSubName '= "") && $Data(pScan("all", tSubName)) && ..IsCustomSubTable(tSubName) Set tNamed(tSubName) = ""
    }
    Set tName = ""
    For {
        Set tName = $Order(pScan("all", tName))
        If tName = "" Quit
        If $Data(tNamed(tName)) {
            Set pScan("S", tName) = pScan("all", tName)
            Set pScan("S") = pScan("S") + 1
        } Else {
            Set pScan("skipped") = pScan("skipped") + 1
        }
    }
    Kill pScan("all")
    Quit $$$OK
}

/// <p>Sort the record <var>pXml</var> of kind <var>pKind</var> (<code>L</code>, <code>T</code> or <code>S</code>) whose child values are
/// <var>pFields</var> into <var>pScan</var> (<method>ScanImport</method>). A sub-table is held in <code>pScan("all", name)</code> until the tables
/// that name it are known.</p>
ClassMethod KeepRecord(pKind As %String, ByRef pFields, pXml As %String, pPrefix As %String, ByRef pScan, ByRef pShape As %Boolean) [ Private ]
{
    Set pScan("seen") = pScan("seen") + 1
    If pKind = "L" {
        Set tName = $Get(pFields("Name"))
        If tName = "" {
            Set pShape = 1
        } ElseIf $Extract(tName, 1, $Length(pPrefix)) '= pPrefix {
            Set pScan("skipped") = pScan("skipped") + 1
        } ElseIf '$Match(tName, ..#IMPORTNAMEPATTERN) || '..HoldsRequired(.pFields) {
            Set pShape = 1
        } Else {
            Set pScan("L") = pScan("L") + 1
            Set pScan("L", pScan("L")) = $ListBuild(tName, pXml)
        }
        Quit
    }
    If pKind = "T" {
        Set tType = $Get(pFields("Type"))
        Set tFrom = $Get(pFields("NameFrom"))
        Set tTo = $Get(pFields("NameTo"))
        If (tType = "") || (tFrom = "") || (tTo = "") {
            Set pShape = 1
        } ElseIf ($Extract(tFrom, 1, $Length(pPrefix)) = pPrefix) || ($Extract(tTo, 1, $Length(pPrefix)) = pPrefix) {
            Set pScan("T") = pScan("T") + 1
            Set pScan("T", pScan("T")) = $ListBuild(tType, tFrom, tTo, $Get(pFields("SubTableName")), pXml)
        } Else {
            Set pScan("skipped") = pScan("skipped") + 1
        }
        Quit
    }
    Set tName = $Get(pFields("Name"))
    If (tName = "") || ($Get(pFields("Type")) = "") {
        Set pShape = 1
    } ElseIf $Data(pScan("all", tName)) {
        Set pScan("skipped") = pScan("skipped") + 1
    } Else {
        Set pScan("all", tName) = pXml
    }
}

/// <p>Whether the sub-table <var>pName</var> (<code>type-from-to</code>) is custom as <code>Config.NLS.SubTables</code> defines it: its from or to
/// part starts with <parameter>CUSTOMPREFIX</parameter>, or the name ends with a dot and four digits.</p>
ClassMethod IsCustomSubTable(pName As %String) As %Boolean
{
    Set tPrefix = ..#CUSTOMPREFIX
    If $Extract($Piece(pName, "-", 2), 1, $Length(tPrefix)) = tPrefix Quit 1
    If $Extract($Piece(pName, "-", 3, *), 1, $Length(tPrefix)) = tPrefix Quit 1
    Quit $Match(pName, ".*\.[0-9]{4}")
}

/// <p>Whether the locale record whose child values are <var>pFields</var> holds every element of <parameter>IMPORTREQUIRED</parameter>.</p>
ClassMethod HoldsRequired(ByRef pFields) As %Boolean [ Private ]
{
    Set tHolds = 1
    For tI = 1:1:$Length(..#IMPORTREQUIRED, ",") {
        If '$Data(pFields($Piece(..#IMPORTREQUIRED, ",", tI))) Set tHolds = 0
    }
    Quit tHolds
}

/// <p>The import file <var>pText</var> as reviewed (Story 21.15). It answers, in <var>pReview</var>, <code>{Digest, Locales, Truncated,
/// LocaleCount, TableCount, SubTableCount, Replaces, Skipped}</code>: the digest of the whole text, the names of the custom locales kept (at most
/// <parameter>LISTEDLOCALES</parameter>), the counts of the custom locales, tables and sub-tables kept, how many of them the instance already
/// holds, and how many records the file holds that are dropped; and, in <var>pKept</var>, the file the vendor is handed, which holds just the kept
/// records, and in <var>pNames</var> every kept locale's name as a <class>%List</class>. Refused with no vendor call: 409
/// <code>LOCALE.IMPORT.SHAPE</code> for a text with a document type declaration, one that is not a locale or table export (<method>ScanImport</method>)
/// or one that holds no record, or a kept record the vendor's class does not take (<method>KeptRecordsValid</method>); <code>LOCALE.IMPORT.EMPTY</code>
/// when no record is custom; and <code>LOCALE.IMPORT.CURRENT</code> when a kept record is the current locale, or a table or sub-table it loads
/// (<method>CurrentFootprint</method>).</p>
ClassMethod ImportReview(pText As %String, Output pReview As %DynamicObject, Output pKept As %Stream.TmpCharacter, Output pNames As %List, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pReview = ""
    Set pKept = ""
    Set pNames = ""
    If $ZConvert(pText, "U") [ "<!DOCTYPE" Quit ..Refused(##class(OcuPilot.Api.LocaleError).#IMPORTSHAPE, .pHttpStatus, .pFault)
    Set tSC = ..ScanImport(pText, .tScan, .tShape)
    If $$$ISERR(tSC) Quit ..Fail("the import file could not be read", tSC, .pHttpStatus, .pFault)
    If tShape || 'tScan("seen") Quit ..Refused(##class(OcuPilot.Api.LocaleError).#IMPORTSHAPE, .pHttpStatus, .pFault)
    If 'tScan("L") && 'tScan("T") && 'tScan("S") Quit ..Refused(##class(OcuPilot.Api.LocaleError).#IMPORTEMPTY, .pHttpStatus, .pFault)
    Set tSC = ..CurrentFootprint(.tCurrent, .tCurrentTables, .tCurrentSubTables)
    If $$$ISERR(tSC) Quit ..Fail("the current locale could not be read", tSC, .pHttpStatus, .pFault)
    Set tHit = 0
    Set tNames = ""
    For tI = 1:1:tScan("L") {
        Set tNames = tNames _ $ListBuild($List(tScan("L", tI), 1))
        If $List(tScan("L", tI), 1) = tCurrent Set tHit = 1
    }
    For tI = 1:1:tScan("T") {
        If $Data(tCurrentTables($List(tScan("T", tI), 1), $List(tScan("T", tI), 2), $List(tScan("T", tI), 3))) Set tHit = 1
    }
    Set tName = ""
    For {
        Set tName = $Order(tScan("S", tName))
        If tName = "" Quit
        If $Data(tCurrentSubTables(tName)) Set tHit = 1
    }
    If tHit Quit ..Refused(##class(OcuPilot.Api.LocaleError).#IMPORTCURRENT, .pHttpStatus, .pFault)
    Set tSC = ..KeptRecordsValid(.tScan, .tValid)
    If $$$ISERR(tSC) Quit ..Fail("the import file's records could not be checked", tSC, .pHttpStatus, .pFault)
    If 'tValid Quit ..Refused(##class(OcuPilot.Api.LocaleError).#IMPORTSHAPE, .pHttpStatus, .pFault)
    Set tSC = ..ReplacedCount(.tScan, .tReplaces)
    If $$$ISERR(tSC) Quit ..Fail("the instance's locales could not be read", tSC, .pHttpStatus, .pFault)
    Set tDigest = ..TextDigest(pText)
    If tDigest = "" Quit ..Fail("the import file could not be digested", $$$ERROR($$$GeneralError, "no digest"), .pHttpStatus, .pFault)
    Set pKept = ##class(%Stream.TmpCharacter).%New()
    Do pKept.Write("<?xml version=""1.0"" encoding=""UTF-8""?>" _ $Char(10) _ "<LocalesDeepExport>" _ $Char(10) _ "<LocalesExport>" _ $Char(10))
    For tI = 1:1:tScan("L") Do pKept.Write($List(tScan("L", tI), 2) _ $Char(10))
    Do pKept.Write("</LocalesExport>" _ $Char(10) _ "<TablesDeepExport>" _ $Char(10) _ "<TablesExport>" _ $Char(10))
    For tI = 1:1:tScan("T") Do pKept.Write($List(tScan("T", tI), 5) _ $Char(10))
    Do pKept.Write("</TablesExport>" _ $Char(10) _ "<SubTablesExport>" _ $Char(10))
    Set tName = ""
    For {
        Set tName = $Order(tScan("S", tName))
        If tName = "" Quit
        Do pKept.Write(tScan("S", tName) _ $Char(10))
    }
    Do pKept.Write("</SubTablesExport>" _ $Char(10) _ "</TablesDeepExport>" _ $Char(10) _ "</LocalesDeepExport>" _ $Char(10))
    Do pKept.Rewind()
    Set pNames = tNames
    Set pReview = {}
    Do pReview.%Set("Digest", tDigest, "string")
    Set tListed = []
    For tI = 1:1:$ListLength(pNames) {
        If tListed.%Size() >= ..#LISTEDLOCALES Quit
        Do tListed.%Push($List(pNames, tI), "string")
    }
    Do pReview.%Set("Locales", tListed)
    Do pReview.%Set("Truncated", ($ListLength(pNames) > ..#LISTEDLOCALES), "boolean")
    Do pReview.%Set("LocaleCount", tScan("L"), "number")
    Do pReview.%Set("TableCount", tScan("T"), "number")
    Do pReview.%Set("SubTableCount", tScan("S"), "number")
    Do pReview.%Set("Replaces", tReplaces, "number")
    Do pReview.%Set("Skipped", tScan("skipped"), "number")
    Quit $$$OK
}

/// <p>Whether every record <var>pScan</var> keeps (<method>ScanImport</method>) reads and validates as the vendor's own class would take it
/// (<method>RecordValid</method>), in <var>pValid</var>. The vendor's import writes the records in order and fails on the first it rejects, so a rejected
/// record would leave the records before it written. Read in <code>%SYS</code> by save and restore; nothing is saved.</p>
ClassMethod KeptRecordsValid(ByRef pScan, Output pValid As %Boolean) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pValid = 1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:pScan("L") {
            If pValid && '..RecordValid($List(pScan("L", tI), 2), "Locales", "Config.NLS.Locales") Set pValid = 0
        }
        For tI = 1:1:pScan("T") {
            If pValid && '..RecordValid($List(pScan("T", tI), 5), "Tables", "Config.NLS.Tables") Set pValid = 0
        }
        Set tName = ""
        For {
            Set tName = $Order(pScan("S", tName))
            If tName = "" Quit
            If pValid && '..RecordValid(pScan("S", tName), "SubTables", "Config.NLS.SubTables") Set pValid = 0
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Whether the record <var>pXml</var>, an element <var>pElement</var>, imports into an unsaved object of the vendor class <var>pClass</var> and
/// validates. A record the class cannot read is not valid.</p>
ClassMethod RecordValid(pXml As %String, pElement As %String, pClass As %String) As %Boolean [ Private ]
{
    Set tValid = 0
    Try {
        Set tReader = ##class(%XML.Reader).%New()
        Set tSC = tReader.OpenString(pXml)
        If $$$ISOK(tSC) {
            Do tReader.Correlate(pElement, pClass)
            If tReader.Next(.tObject, .tSC) && $$$ISOK(tSC) Set tValid = $$$ISOK(tObject.%ValidateObject())
        }
    } Catch {
        Set tValid = 0
    }
    Set tObject = ""
    Quit tValid
}

/// <p>How many of the records <var>pScan</var> keeps (<method>ScanImport</method>) the instance already holds, in <var>pReplaces</var>, read in
/// <code>%SYS</code> by save and restore: a locale by name, a table by type and sides, a sub-table by name.</p>
ClassMethod ReplacedCount(ByRef pScan, Output pReplaces As %Integer) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pReplaces = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:pScan("L") {
            If ##class(Config.NLS.Locales).Exists($List(pScan("L", tI), 1)) Set pReplaces = pReplaces + 1
        }
        For tI = 1:1:pScan("T") {
            If ##class(Config.NLS.Tables).Exists($List(pScan("T", tI), 1), $List(pScan("T", tI), 2), $List(pScan("T", tI), 3)) Set pReplaces = pReplaces + 1
        }
        Set tName = ""
        For {
            Set tName = $Order(pScan("S", tName))
            If tName = "" Quit
            If ##class(Config.NLS.SubTables).Exists(tName) Set pReplaces = pReplaces + 1
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The tables and sub-tables the locale <var>pLocale</var> loads, in <var>pTables</var> (<code>pTables(type, from, to)</code>) and
/// <var>pSubTables</var> (<code>pSubTables(name)</code>, the names of sub-tables the instance holds): its own <code>GetTables</code> set and the
/// <code>SubTableName</code> of each table in it. Read in <code>%SYS</code> by save and restore; a locale the instance does not hold has none.</p>
ClassMethod LocaleFootprint(pLocale As %String, Output pTables, Output pSubTables) As %Status
{
    Set tSC = $$$OK
    Kill pTables, pSubTables
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tLocale = ##class(Config.NLS.Locales).%OpenId(pLocale)
        If $IsObject(tLocale) {
            Do tLocale.GetTables(.tSet)
            Set tType = ""
            For {
                Set tType = $Order(tSet(tType))
                If tType = "" Quit
                Set tFrom = ""
                For {
                    Set tFrom = $Order(tSet(tType, tFrom))
                    If tFrom = "" Quit
                    Set tTo = ""
                    For {
                        Set tTo = $Order(tSet(tType, tFrom, tTo))
                        If tTo = "" Quit
                        Set pTables(tType, tFrom, tTo) = ""
                        Set tTable = ##class(Config.NLS.Tables).%OpenId(tType _ "||" _ tFrom _ "||" _ tTo)
                        If '$IsObject(tTable) Continue
                        Set tSub = tTable.SubTableName
                        If (tSub '= "") && ##class(Config.NLS.SubTables).Exists(tSub) Set pSubTables(tSub) = ""
                    }
                }
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
        Kill pTables, pSubTables
    }
    Set tLocale = ""
    Set tTable = ""
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The current locale's name, in <var>pLocale</var>, and what it loads (<method>LocaleFootprint</method>). Overridable so a fixture can pose a
/// current locale that holds custom records; production never overrides it.</p>
ClassMethod CurrentFootprint(Output pLocale As %String, Output pTables, Output pSubTables) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set pLocale = $Get(^%SYS("LOCALE", "CURRENT"))
    } Catch {
        Set pLocale = ""
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit ..LocaleFootprint(pLocale, .pTables, .pSubTables)
}

/// <p>The import row the file <var>pQuery</var> names reads as, for the target <var>pName</var>: <code>{Digest, Locales, Truncated, LocaleCount,
/// TableCount, SubTableCount, Replaces, Skipped, root, path, fileName, content}</code> with the file's names as the query carried them and
/// <code>content</code> always empty, so the row never holds a local file's text. A target other than <parameter>IMPORTID</parameter> is 404
/// <code>LOCALE.NOTFOUND</code>; the file's refusals are <method>ImportText</method>'s and <method>ImportReview</method>'s.</p>
ClassMethod ReadImportFile(pName As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If pName '= ..#IMPORTID Quit ..Refused(##class(OcuPilot.Api.LocaleError).#NOTFOUND, .pHttpStatus, .pFault)
    Set tSC = ..ImportText(.pQuery, .tText, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ImportReview(tText, .pResult, .tKept, .tNames, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Do pResult.%Set(..#ROOTPARAM, $Get(pQuery(..#ROOTPARAM)), "string")
    Do pResult.%Set(..#PATHPARAM, $Get(pQuery(..#PATHPARAM)), "string")
    Do pResult.%Set(..#FILENAMEPARAM, $Get(pQuery(..#FILENAMEPARAM)), "string")
    Do pResult.%Set(..#CONTENTPARAM, "", "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Import the file <var>pQuery</var> names under the write lock on <parameter>IMPORTID</parameter> and on each custom locale the file keeps, taken in
/// name order (<method>TakeLocales</method>), the locks <method>WriteUnderLock</method> takes for the same locale: the file is read and reviewed once to
/// name them, and <method>PerformImport</method> reviews it again under them. A lock another request keeps past <parameter>LOCKSECONDS</parameter> is 409
/// <code>WRITE.TARGETBUSY</code>, with every lock this call took released.</p>
ClassMethod ImportUnderLock(pName As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    If pName '= ..#IMPORTID Quit ..Refused(##class(OcuPilot.Api.LocaleError).#NOTFOUND, .pHttpStatus, .pFault)
    Set tSC = ..ImportText(.pQuery, .tText, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ImportReview(tText, .tReview, .tKept, .tNames, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tText = ""
    Set tKept = ""
    If '..TakeLock(..#IMPORTID) Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#WRITETARGETBUSY, ##class(OcuPilot.Api.Error).#REASONWRITETARGETBUSY, .pHttpStatus, .pFault)
    If '..TakeLocales(tNames, .tLocked) {
        Do ..ReleaseLock(..#IMPORTID)
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#WRITETARGETBUSY, ##class(OcuPilot.Api.Error).#REASONWRITETARGETBUSY, .pHttpStatus, .pFault)
    }
    Try {
        Set tSC = ..PerformImport(.pQuery, .tLocked, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("a locale import failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Do ..ReleaseLocales(.tLocked)
    Do ..ReleaseLock(..#IMPORTID)
    Quit tSC
}

/// <p>Take the write lock on each locale of <var>pNames</var> (a <class>%List</class>), in name order, noting each in <var>pLocked</var>; whether all were
/// taken. When one is not, the locks taken are released and <var>pLocked</var> is empty.</p>
ClassMethod TakeLocales(pNames As %List, Output pLocked) As %Boolean [ Private ]
{
    Kill pLocked
    Kill tSorted
    For tI = 1:1:$ListLength(pNames) {
        Set tSorted($List(pNames, tI)) = ""
    }
    Set tAll = 1
    Set tName = ""
    For {
        Set tName = $Order(tSorted(tName))
        If tName = "" Quit
        If '..TakeLock(tName) {
            Set tAll = 0
            Quit
        }
        Set pLocked(tName) = ""
    }
    If 'tAll Do ..ReleaseLocales(.pLocked)
    Quit tAll
}

/// <p>Release every lock <var>pLocked</var> notes, as <method>TakeLocales</method> filled it, and empty it.</p>
ClassMethod ReleaseLocales(ByRef pLocked) [ Private ]
{
    Set tName = ""
    For {
        Set tName = $Order(pLocked(tName))
        If tName = "" Quit
        Do ..ReleaseLock(tName)
    }
    Kill pLocked
}

/// <p>The import, with the locks of <var>pLocked</var> held: the file is read and reviewed again (<method>ImportText</method>,
/// <method>ImportReview</method>), and unless it keeps no locale the locks do not cover, and its digest and the count of records it replaces are the
/// reviewed <parameter>DIGESTPARAM</parameter> and <parameter>REPLACESPARAM</parameter> of the query, the write is 409
/// <code>LOCALE.IMPORT.CHANGED</code> with nothing imported. Then <method>SendImport</method> hands the vendor the kept records, and
/// every locale reviewed must be listed. Answers <code>{Locales, Tables, SubTables}</code>, the vendor's own counts.</p>
ClassMethod PerformImport(ByRef pQuery, ByRef pLocked, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..ImportText(.pQuery, .tText, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ImportReview(tText, .tReview, .tKept, .tNames, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tUncovered = 0
    For tI = 1:1:$ListLength(tNames) {
        If '$Data(pLocked($List(tNames, tI))) Set tUncovered = 1
    }
    If tUncovered Quit ..Refused(##class(OcuPilot.Api.LocaleError).#IMPORTCHANGED, .pHttpStatus, .pFault)
    If '$Data(pQuery(..#DIGESTPARAM)) || '$Data(pQuery(..#REPLACESPARAM)) || (pQuery(..#DIGESTPARAM) '= tReview.%Get("Digest")) || (pQuery(..#REPLACESPARAM) '= tReview.%Get("Replaces")) {
        Quit ..Refused(##class(OcuPilot.Api.LocaleError).#IMPORTCHANGED, .pHttpStatus, .pFault)
    }
    Set tVendor = ..SendImport(tKept, .tCounts)
    ; Only the vendor's error numbers are logged: its text quotes the file's values.
    If $$$ISERR(tVendor) Quit ..Fail("the import of locales was refused by the vendor", $$$ERROR($$$GeneralError, "vendor error " _ $System.Status.GetErrorCodes(tVendor)), .pHttpStatus, .pFault)
    If (+$Get(tCounts("Locales")) '= tReview.%Get("LocaleCount")) || (+$Get(tCounts("Tables")) '= tReview.%Get("TableCount")) || (+$Get(tCounts("SubTables")) '= tReview.%Get("SubTableCount")) {
        Quit ..Fail("the vendor imported other counts than were reviewed", $$$ERROR($$$GeneralError, "imported " _ +$Get(tCounts("Locales")) _ "/" _ +$Get(tCounts("Tables")) _ "/" _ +$Get(tCounts("SubTables")) _ " of " _ tReview.%Get("LocaleCount") _ "/" _ tReview.%Get("TableCount") _ "/" _ tReview.%Get("SubTableCount")), .pHttpStatus, .pFault)
    }
    Set tSC = ..LocaleRows(.tRows)
    If $$$ISERR(tSC) Quit ..Fail("the locales could not be read after the import", tSC, .pHttpStatus, .pFault)
    Kill tListed
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tListed(tRow.%Get("Name")) = ""
    }
    Set tMissing = 0
    For tI = 1:1:$ListLength(tNames) {
        If '$Data(tListed($List(tNames, tI))) Set tMissing = 1
    }
    If tMissing Quit ..Fail("an imported locale is not listed", $$$ERROR($$$GeneralError, "a reviewed locale is not listed after the import"), .pHttpStatus, .pFault)
    Set pResult = {}
    Do pResult.%Set("Locales", +$Get(tCounts("Locales")), "number")
    Do pResult.%Set("Tables", +$Get(tCounts("Tables")), "number")
    Do pResult.%Set("SubTables", +$Get(tCounts("SubTables")), "number")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The one call that imports: the kept records <var>pKept</var> written to a temporary file this port names, and the vendor's
/// <code>ImportAll</code> of that file (<method>VendorImport</method>); the file is deleted on every path. <var>pCounts</var> is the vendor's
/// <code>NumImported</code>. Overridable so a fixture can record the call; production never overrides it.</p>
ClassMethod SendImport(pKept As %Stream.TmpCharacter, Output pCounts) As %Status [ Private ]
{
    Set tFile = ""
    Set tDirectory = ""
    Kill pCounts
    Try {
        Set tSC = ..TransferFile(.tFile, .tDirectory)
        If $$$ISOK(tSC) Set tSC = ..WriteTransferFile(tFile, pKept)
        If $$$ISOK(tSC) Set tSC = ..VendorImport(tFile, .pCounts)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Do ..RemoveTransfer(tFile, tDirectory)
    Quit tSC
}

/// <p>The vendor's <code>ImportAll</code> of the file <var>pFile</var>, an OcuPilot-named temporary file, with <parameter>IMPORTFLAGS</parameter>, in
/// <code>%SYS</code> by save and restore. <var>pCounts</var> holds the vendor's counts (<code>Locales</code>, <code>Tables</code>,
/// <code>SubTables</code>). Overridable so a fixture can fail it or see the file; production never overrides it.</p>
ClassMethod VendorImport(pFile As %String, Output pCounts) As %Status [ Private ]
{
    Set tSC = $$$OK
    Kill pCounts
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Config.NLS.Locales).ImportAll(pFile, .tCounts, ..#IMPORTFLAGS)
        Merge pCounts = tCounts
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>A directory this port makes for one transfer, in <var>pDirectory</var>, and an empty temporary file in it, in <var>pFile</var>; the caller removes
/// both with <method>RemoveTransfer</method>. The directory is named <parameter>TRANSFERDIRECTORY</parameter> and <method>TransferName</method> under
/// <method>TransferParent</method>; a directory already at that name is refused and left as it is.</p>
ClassMethod TransferFile(Output pFile As %String, Output pDirectory As %String) As %Status [ Private ]
{
    Set pFile = ""
    Set pDirectory = ""
    Set tParent = ..TransferParent()
    If tParent = "" Quit $$$ERROR($$$GeneralError, "the locale transfer directory could not be placed")
    Set tDirectory = ##class(%File).NormalizeDirectory(..#TRANSFERDIRECTORY _ "-" _ ..TransferName(), tParent)
    If ##class(%File).DirectoryExists(tDirectory) Quit $$$ERROR($$$GeneralError, "the locale transfer directory is already there")
    If '##class(%File).CreateDirectory(tDirectory) Quit $$$ERROR($$$GeneralError, "the locale transfer directory could not be made")
    Set pDirectory = tDirectory
    Set pFile = ##class(%File).TempFilename("xml", tDirectory)
    If pFile = "" Quit $$$ERROR($$$GeneralError, "the locale transfer file could not be made")
    Quit $$$OK
}

/// <p>Delete the transfer file <var>pFile</var> and remove the transfer directory <var>pDirectory</var> with whatever it still holds; either may be
/// empty.</p>
ClassMethod RemoveTransfer(pFile As %String, pDirectory As %String) [ Private ]
{
    If pFile '= "" Do ##class(%File).Delete(pFile)
    If pDirectory '= "" Do ##class(%File).RemoveDirectoryTree(pDirectory)
}

/// <p>The operating system's temporary directory, where each transfer's directory is made; <code>""</code> when it cannot be found. Overridable so a
/// fixture can name its own; production never overrides it.</p>
ClassMethod TransferParent() As %String
{
    Set tProbe = ##class(%File).TempFilename("tmp")
    If tProbe = "" Quit ""
    Set tParent = ##class(%File).GetDirectory(tProbe)
    Do ##class(%File).Delete(tProbe)
    Quit tParent
}

/// <p>The part of a transfer directory's name that is unique to the transfer. Overridable so a fixture can pose a name that is taken; production never
/// overrides it.</p>
ClassMethod TransferName() As %String
{
    Quit $Translate($System.Util.CreateGUID(), "{}", "")
}

/// <p><var>pStream</var>'s text written to the file <var>pFile</var> as UTF-8.</p>
ClassMethod WriteTransferFile(pFile As %String, pStream As %Stream.TmpCharacter) As %Status [ Private ]
{
    Set tSC = $$$OK
    Try {
        Set tFile = ##class(%Stream.FileCharacter).%New()
        Set tFile.TranslateTable = "UTF8"
        Set tSC = tFile.LinkToFile(pFile)
        If $$$ISERR(tSC) Quit
        Do pStream.Rewind()
        While 'pStream.AtEnd {
            Set tSC = tFile.Write(pStream.Read(32000))
            If $$$ISERR(tSC) Quit
        }
        If $$$ISOK(tSC) Set tSC = tFile.%Save()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The export row of the locale <var>pName</var>: <code>{Name, Description, Tables, SubTables, root, path}</code>. <code>Tables</code> and
/// <code>SubTables</code> are what the locale loads (<method>LocaleFootprint</method>) and <code>root</code> and <code>path</code> the file the
/// query names, as it carried them. A locale the instance does not list is 404 <code>LOCALE.NOTFOUND</code>.</p>
ClassMethod ReadExportLocale(pName As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..State(pName, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..LocaleFootprint(pName, .tTables, .tSubTables)
    If $$$ISERR(tSC) Quit ..Fail("the tables of a locale could not be read", tSC, .pHttpStatus, .pFault)
    Set tTableCount = 0
    Set tType = ""
    For {
        Set tType = $Order(tTables(tType))
        If tType = "" Quit
        Set tFrom = ""
        For {
            Set tFrom = $Order(tTables(tType, tFrom))
            If tFrom = "" Quit
            Set tTo = ""
            For {
                Set tTo = $Order(tTables(tType, tFrom, tTo))
                If tTo = "" Quit
                Set tTableCount = tTableCount + 1
            }
        }
    }
    Set tSubTableCount = 0
    Set tSub = ""
    For {
        Set tSub = $Order(tSubTables(tSub))
        If tSub = "" Quit
        Set tSubTableCount = tSubTableCount + 1
    }
    Set pResult = {}
    Do pResult.%Set("Name", pName, "string")
    Do pResult.%Set("Description", tRow.%Get("Description"), "string")
    Do pResult.%Set("Tables", tTableCount, "number")
    Do pResult.%Set("SubTables", tSubTableCount, "number")
    Do pResult.%Set(..#ROOTPARAM, $Get(pQuery(..#ROOTPARAM)), "string")
    Do pResult.%Set(..#PATHPARAM, $Get(pQuery(..#PATHPARAM)), "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The export's file for <var>pRoot</var> and <var>pPath</var>, resolved through <method>PathPortClass</method> as a <code>file</code> with
/// <parameter>EXPORTOVERWRITES</parameter>, each refusal on its field, then <code>EXPLORER.EXPORT.DIRECTORY</code> when the resolved name's
/// directory does not exist; a directory is never created. On success <var>pResolved</var> is the path.</p>
ClassMethod ExportFile(pRoot As %String, pPath As %String, Output pResolved As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResolved = ""
    Set tPathPort = ..PathPortClass()
    Set tSC = $ClassMethod(tPathPort, "Resolve", pRoot, pPath, $Parameter(tPathPort, "KINDFILE"), ..#ROOTPARAM, ..#PATHPARAM, .pResolved, .pHttpStatus, .pFault, ..#EXPORTOVERWRITES)
    If $$$ISERR(tSC) {
        Set pResolved = ""
        Quit tSC
    }
    If '##class(%File).DirectoryExists(##class(%File).GetDirectory(pResolved)) {
        Set pResolved = ""
        Set tCode = ##class(OcuPilot.Api.AtelierError).#EXPORTDIRECTORY
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, tCode, ##class(OcuPilot.Api.Error).ReasonForViolation(tCode), .pHttpStatus, .pFault)
    }
    Quit $$$OK
}

/// <p>The export's file for <var>pRoot</var> and <var>pPath</var>, resolved and checked exactly as <method>Export</method> checks it before its vendor
/// call, for a mint that must refuse what the write would: the read gate, then <method>ExportFile</method>. Nothing is written.</p>
ClassMethod CheckExport(pRoot As %String, pPath As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSC = ..Admit(..#TYPEEXPORT, .pHttpStatus, .pFault)
        If $$$ISOK(tSC) Set tSC = ..ExportFile(pRoot, pPath, .tResolved, .pHttpStatus, .pFault)
    } Catch ex {
        Set tSC = ..Fail("the export's file could not be checked", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Export the locale <var>pName</var> and its tables: to the server file <parameter>ROOTPARAM</parameter> and <parameter>PATHPARAM</parameter>
/// name, resolved and checked by <method>ExportFile</method> before the call, the answer <code>{Name, Locales, Tables, SubTables, root, path}</code>
/// with the vendor's own counts; or, naming neither, as lines for the browser, the answer <code>{Name, Locales, Tables, SubTables, lines}</code>, and
/// 409 <code>LOCALE.TOOLARGE</code> past <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter> characters. A locale the instance does
/// not list is 404 <code>LOCALE.NOTFOUND</code>. It changes no locale and no table.</p>
ClassMethod Export(pName As %String, ByRef pQuery, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tSC = ..State(pName, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tRoot = $Get(pQuery(..#ROOTPARAM))
    Set tPath = $Get(pQuery(..#PATHPARAM))
    Set tToFile = (tRoot '= "") || (tPath '= "")
    Set tResolved = ""
    If tToFile {
        Set tSC = ..ExportFile(tRoot, tPath, .tResolved, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
    }
    Set tVendor = ..SendExport(pName, tResolved, .tCounts, .tText, .tTooLarge)
    If +$Get(tTooLarge) Quit ..Refused(##class(OcuPilot.Api.LocaleError).#TOOLARGE, .pHttpStatus, .pFault)
    If $$$ISERR(tVendor) Quit ..Fail("the export of a locale was refused by the vendor", tVendor, .pHttpStatus, .pFault)
    Set pResult = {}
    Do pResult.%Set("Name", pName, "string")
    Do pResult.%Set("Locales", +$Get(tCounts("Locales")), "number")
    Do pResult.%Set("Tables", +$Get(tCounts("Tables")), "number")
    Do pResult.%Set("SubTables", +$Get(tCounts("SubTables")), "number")
    If tToFile {
        Do pResult.%Set(..#ROOTPARAM, tRoot, "string")
        Do pResult.%Set(..#PATHPARAM, tPath, "string")
    } Else {
        Set tLines = []
        Set tLength = $Length(tText, $Char(10))
        For tI = 1:1:tLength {
            Set tLine = $Piece(tText, $Char(10), tI)
            If (tI = tLength) && (tLine = "") Quit
            Do tLines.%Push(tLine, "string")
        }
        Do pResult.%Set("lines", tLines)
    }
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The one call that exports: the vendor's <code>ExportList</code> of the locale <var>pName</var> alone into a temporary file this port names
/// (<method>VendorExport</method>), then either its copy over the resolved file <var>pResolved</var> or, when that is empty, its text in
/// <var>pText</var> (<var>pTooLarge</var> when it holds more than <parameter>OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS</parameter> characters).
/// The temporary file is deleted on every path. Overridable so a fixture can record the call; production never overrides it.</p>
ClassMethod SendExport(pName As %String, pResolved As %String, Output pCounts, Output pText As %String, Output pTooLarge As %Boolean) As %Status [ Private ]
{
    Set tFile = ""
    Set tDirectory = ""
    Set pText = ""
    Set pTooLarge = 0
    Kill pCounts
    Try {
        Set tSC = ..TransferFile(.tFile, .tDirectory)
        If $$$ISOK(tSC) Set tSC = ..VendorExport(tFile, pName, .pCounts)
        If $$$ISOK(tSC) {
            If pResolved '= "" {
                If '##class(%File).CopyFile(tFile, pResolved, 1) Set tSC = $$$ERROR($$$GeneralError, "the exported locale could not be copied to its file")
            } Else {
                Set tSC = ##class(OcuPilot.Port.AtelierPort).ReadText(tFile, .pText, .pTooLarge)
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Do ..RemoveTransfer(tFile, tDirectory)
    Quit tSC
}

/// <p>The vendor's <code>ExportList</code> of the locale <var>pName</var> alone into the OcuPilot-named temporary file <var>pFile</var>, in
/// <code>%SYS</code> by save and restore. <var>pCounts</var> holds the vendor's counts. Overridable so a fixture can fail it or see the file;
/// production never overrides it.</p>
ClassMethod VendorExport(pFile As %String, pName As %String, Output pCounts) As %Status [ Private ]
{
    Set tSC = $$$OK
    Kill pCounts
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tLocales(pName) = ""
        Set tSC = ##class(Config.NLS.Locales).ExportList(pFile, .tCounts, .tLocales)
        Merge pCounts = tCounts
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
    If pType = ..#TYPEIMPORT Quit ..TransferSnippet(pType, .pQuery)
    If pType = ..#TYPEEXPORT Quit ..TransferSnippet(pType, .pQuery)
    Set tName = $ClassMethod(tAdmin, "Literal", $Get(pQuery(..#NAMEKEY)))
    If pType = ..#TYPECOPY {
        Set tSource = $ClassMethod(tAdmin, "Literal", $Select($IsObject(pBody) && (pBody.%GetTypeOf("Source") = "string"): pBody.%Get("Source"), 1: ""))
        Set tLines = ..ReadLines(tSource)
        If $IsObject(pBody) && (pBody.%GetTypeOf("Description") = "string") {
            Set tLines = tLines _ $ListBuild("Set tProps(""Description"") = " _ $ClassMethod(tAdmin, "Literal", pBody.%Get("Description")))
        }
        Set tLines = tLines _ $ListBuild("If ##class(Config.NLS.Locales).Exists(" _ tName _ ") Set tSC = $System.Status.Error(5001, " _ $ClassMethod(tAdmin, "Literal", ##class(OcuPilot.Api.LocaleError).#REASONCOPYTAKEN) _ ")")
        Set tLines = tLines _ $ListBuild("If $System.Status.IsOK(tSC), '##class(Config.NLS.Locales).Exists(" _ tName _ ") Set tSC = ##class(Config.NLS.Locales).Create(" _ tName _ ", .tProps)")
        Quit [($ClassMethod(tAdmin, "ObjectScriptStep", tLines))]
    }
    Set tLine = "Set tSC = ##class(Config.NLS.Locales)." _ $Select(pType = ..#TYPEINSTALL: "Install", 1: "Delete") _ "(" _ tName _ ")"
    Quit [($ClassMethod(tAdmin, "ObjectScriptStep", $ListBuild(tLine)))]
}

/// <p>The script of an import or an export (AD-59): the vendor's own call on a file and the locale as a string literal. An import whose file the query
/// names (<method>ImportSnippet</method>) writes the kept records into the script's own file and imports that; an export, and an import that names no
/// file, use a placeholder file name. A server file is named by its allowed directory and relative name in a comment, since the directory is resolved
/// when the write runs; a local file's text is never in a script, so its comment says the file is the one this browser sent.</p>
ClassMethod TransferSnippet(pType As %String, ByRef pQuery) As %DynamicArray [ Private ]
{
    Set tAdmin = "OcuPilot.Port.AdminPort"
    Set tPath = $Get(pQuery(..#PATHPARAM))
    If (pType = ..#TYPEIMPORT) && (($Get(pQuery(..#ROOTPARAM)) '= "") || (tPath '= "")) Quit ..ImportSnippet(.pQuery)
    If tPath '= "" {
        Set tSource = "; The file is the allowed directory " _ $Translate($Get(pQuery(..#ROOTPARAM)), $Char(10) _ $Char(13), "  ") _ " and the name " _ $Translate(tPath, $Char(10) _ $Char(13), "  ")
    } ElseIf pType = ..#TYPEIMPORT {
        Set tSource = "; tFile names the file this browser sent, which no script carries"
    } Else {
        Set tSource = ""
    }
    Set tLines = $Select(tSource = "": "", 1: $ListBuild(tSource)) _ $ListBuild("Set tFile = ""locales.xml""")
    If pType = ..#TYPEIMPORT {
        Set tLines = tLines _ $ListBuild("Set tSC = ##class(Config.NLS.Locales).ImportAll(tFile, .tImported, " _ ..#IMPORTFLAGS _ ")")
    } Else {
        Set tLines = tLines _ $ListBuild("Set tLocales(" _ $ClassMethod(tAdmin, "Literal", $Get(pQuery(..#NAMEKEY))) _ ") = """"", "Set tSC = ##class(Config.NLS.Locales).ExportList(tFile, .tExported, .tLocales)")
    }
    Quit [($ClassMethod(tAdmin, "ObjectScriptStep", tLines))]
}

/// <p>The script of an import of the file <var>pQuery</var> names: the records <method>ImportReview</method> keeps, written line by line into a
/// temporary file the script makes as <method>SendImport</method> does, then <code>ImportAll</code> of that file with <parameter>IMPORTFLAGS</parameter>
/// and the file's deletion. A file the import refuses renders that refusal's sentence as one comment step; a script that would pass
/// <parameter>OcuPilot.Port.AtelierPort.SNIPPETMAXCHARACTERS</parameter> characters renders no step.</p>
ClassMethod ImportSnippet(ByRef pQuery) As %DynamicArray [ Private ]
{
    Set tAdmin = "OcuPilot.Port.AdminPort"
    Set tMax = ##class(OcuPilot.Port.AtelierPort).#SNIPPETMAXCHARACTERS
    Set tSC = ..ImportText(.pQuery, .tText, .tHttpStatus, .tFault)
    If $$$ISOK(tSC) Set tSC = ..ImportReview(tText, .tReview, .tKept, .tNames, .tHttpStatus, .tFault)
    If $$$ISERR(tSC) Quit [($ClassMethod(tAdmin, "Step", "comment", $Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)))]
    Set tKeptText = ""
    While 'tKept.AtEnd && ($Length(tKeptText) <= tMax) {
        Set tKeptText = tKeptText _ tKept.Read(32000)
    }
    If $Length(tKeptText) > tMax Quit []
    Set tPath = $Get(pQuery(..#PATHPARAM))
    Set tLines = ""
    If tPath '= "" Set tLines = $ListBuild("; The file is the allowed directory " _ $Translate($Get(pQuery(..#ROOTPARAM)), $Char(10) _ $Char(13), "  ") _ " and the name " _ $Translate(tPath, $Char(10) _ $Char(13), "  "))
    Set tLines = tLines _ $ListBuild("Set tFile = ##class(%File).TempFilename(""xml"")", "Set tStream = ##class(%Stream.FileCharacter).%New()", "Set tStream.TranslateTable = ""UTF8""", "Set tSC = tStream.LinkToFile(tFile)")
    Set tLength = 0
    For tI = 1:1:$Length(tKeptText, $Char(10)) - 1 {
        Set tLine = "Do tStream.Write(" _ $ClassMethod(tAdmin, "Literal", $Piece(tKeptText, $Char(10), tI) _ $Char(10)) _ ")"
        Set tLength = tLength + $Length(tLine)
        If tLength > tMax Quit
        Set tLines = tLines _ $ListBuild(tLine)
    }
    If tLength > tMax Quit []
    Set tLines = tLines _ $ListBuild("If $System.Status.IsOK(tSC) Set tSC = tStream.%Save()", "If $System.Status.IsOK(tSC) Set tSC = ##class(Config.NLS.Locales).ImportAll(tFile, .tImported, " _ ..#IMPORTFLAGS _ ")", "Do ##class(%File).Delete(tFile)")
    Set tStep = $ClassMethod(tAdmin, "ObjectScriptStep", tLines)
    If $Length(tStep.%Get("text")) > tMax Quit []
    Quit [(tStep)]
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
    Set tLines = ..ReadLines(tLocaleLiteral)
    If pType = ..#TYPESET {
        Set tValue = $Select($IsObject(pBody) && (pBody.%GetTypeOf("Value") = "string"): pBody.%Get("Value"), 1: "")
        Set tLines = tLines _ $ListBuild("Set tProps(" _ $ClassMethod(tAdmin, "Literal", tName) _ ") = " _ $ClassMethod(tAdmin, "Literal", $Select(..NameCount(tName): " " _ tValue, 1: tValue)))
    } ElseIf pType = ..#TYPEADD {
        Set tLines = tLines _ $ListBuild("If $Data(tProps(" _ $ClassMethod(tAdmin, "Literal", tList) _ ")) = 1 Kill tProps(" _ $ClassMethod(tAdmin, "Literal", tList) _ ")")
        If tList = ..#IOLIST {
            Set tFrom = $ClassMethod(tAdmin, "Literal", $Select($IsObject(pBody) && (pBody.%GetTypeOf("InputFrom") = "string"): pBody.%Get("InputFrom"), 1: ""))
            Set tTo = $ClassMethod(tAdmin, "Literal", $Select($IsObject(pBody) && (pBody.%GetTypeOf("OutputTo") = "string"): pBody.%Get("OutputTo"), 1: ""))
            Set tLines = tLines _ $ListBuild("Set tProps(" _ $ClassMethod(tAdmin, "Literal", tList) _ ", " _ $ClassMethod(tAdmin, "Literal", tTable) _ ") = $ListBuild(" _ tFrom _ ", tProps(""CharacterSet""), tProps(""CharacterSet""), " _ tTo _ ")")
        } Else {
            Set tLines = tLines _ $ListBuild("Set tProps(" _ $ClassMethod(tAdmin, "Literal", tList) _ ", " _ $ClassMethod(tAdmin, "Literal", tTable) _ ") = """"")
        }
    } Else {
        Set tLines = tLines _ $ListBuild("Kill tProps(" _ $ClassMethod(tAdmin, "Literal", tList) _ ", " _ $ClassMethod(tAdmin, "Literal", tTable) _ ")")
        Set tLines = tLines _ $ListBuild("If '$Data(tProps(" _ $ClassMethod(tAdmin, "Literal", tList) _ ")) Set tProps(" _ $ClassMethod(tAdmin, "Literal", tList) _ ") = """"")
    }
    Set tLines = tLines _ $ListBuild("If $System.Status.IsOK(tSC) Set tSC = ##class(Config.NLS.Locales).Modify(" _ tLocaleLiteral _ ", .tProps)")
    Quit [($ClassMethod(tAdmin, "ObjectScriptStep", tLines))]
}

/// <p>The script's fresh read of the locale <var>pLocaleLiteral</var> (a string literal) into <code>tProps</code>, with the vendor's comment nodes
/// dropped, as <method>LocaleProperties</method> reads it.</p>
ClassMethod ReadLines(pLocaleLiteral As %String) As %List [ Private ]
{
    Quit $ListBuild("Kill tProps Set tSC = ##class(Config.NLS.Locales).Get(" _ pLocaleLiteral _ ", .tProps)", "Set tKey = """" For { Set tKey = $Order(tProps(tKey)) Quit:tKey=""""  Kill tProps(tKey, ""Comment""), tProps(tKey, ""Comments"") }")
}

}
