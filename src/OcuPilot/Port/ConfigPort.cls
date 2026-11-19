/// <p>The configuration settings port (AD-4, AD-16, AD-29, AD-36, AD-52, AD-53, AD-58, AD-59, Stories 21.3 and 21.4): the one
/// product class that lists the instance's startup settings (<code>Config.Startup</code>), memory settings
/// (<code>Config.config</code>), compatibility settings (<code>Config.Miscellaneous</code>), SQL settings
/// (<code>Config.SQL</code>), SQL Shell settings, TSQL settings (<code>%SYSTEM.TSQL</code>) and ISQL settings, and that sets one
/// setting of them. It is also the one product class that names <code>SYS.Database.CheckBlockSizeAvailable</code> for
/// these screens. It switches <code>$NAMESPACE</code> to <code>%SYS</code> by save and restore around each vendor call
/// (AD-16).</p>
/// <p><b>Its gate comes first</b> (AD-29): <parameter>PAIRS</parameter> for a read and <parameter>WRITEPAIRS</parameter>
/// for a write, with <parameter>COMPATIBILITYPAIRS</parameter> added for the <code>Compatibility</code> endpoint,
/// evaluated through <method>GateClass</method> in the calling process before any vendor call or body. A caller missing
/// one is refused 403 <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>.</p>
/// <p><b>Endpoints and request types.</b> Each of <parameter>ENDPOINTS</parameter> answers <code>LIST</code> (the rows,
/// at most <parameter>DEFAULTMAXROWS</parameter> unless the query carries <parameter>MAXROWSKEY</parameter>),
/// <code>GET</code> (the one row the query's <code>name</code> names, the fresh read of the write tools, AD-51) and
/// <code>SET</code> (the write). A row is <code>{Name, Value, Kind, Accepts, Restart, ReadOnly, Purges}</code>: the class's own
/// <code>Get</code> array less <parameter>EXCLUDED</parameter> and a comment (or the roster's names), with <code>Kind</code>,
/// <code>Accepts</code> and the limits <method>Limits</method> answers read from the compiled property at call time
/// (<code>RuntimeType</code>, <code>MINVAL</code>, <code>MAXVAL</code>, <code>VALUELIST</code>, <code>MAXLEN</code>).</p>
/// <p><b>A set is a merge that sends the complete property set</b> (AD-4): the class is read fresh, the one named key
/// takes its new value and every key the read answered is sent. Before any vendor call the row is read and
/// <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class>, the rules the tools' mint asks too, judge the value; a
/// setting this port shows and never changes (<method>IsReadOnly</method>) is refused. No path is set (AD-21).</p>
/// <p><b>The SQL Shell and ISQL settings have no backing class</b>: each is one <code>^%SYS</code> node at a fixed roster of
/// names (<parameter>SHELLROSTER</parameter>, <parameter>ISQLROSTER</parameter>), written as the classic page writes it, with
/// the stored code of the choice the caller named. The TSQL settings are read and set through <code>%SYSTEM.TSQL</code>
/// (<parameter>TSQLROSTER</parameter>). No caller value names a node or a method. A row is <code>Purges</code> when a change
/// of it purges the cached queries of every namespace (<parameter>PURGESQL</parameter>); the set tool purges them once a write
/// that changed it has read OK (<method>PurgeAfterSet</method>).</p>
/// <p><b>The two DDL mapping endpoints</b> (<code>SystemDDL</code>, <code>UserDDL</code>, Story 21.13) list the entries of
/// <code>Config.SqlSysDatatypes</code> and <code>Config.SqlUserDatatypes</code>, each a named entry whose <code>Name</code> is the DDL type
/// and whose <code>Value</code> is its datatype class. They also answer <code>CREATE</code> (<code>UserDDL</code> only) and
/// <code>DELETE</code> (both). A caller's name is only ever passed to the vendor's <code>Exists</code>, <code>Get</code>, <code>Create</code>,
/// <code>Modify</code> and <code>Delete</code>, never to its <code>List</code> query, whose <code>Names</code> argument is a pattern.
/// A <code>GET</code> carrying <parameter>ACTIONKEY</parameter> <code>CREATE</code> is the absence read of a create: a held name is
/// 409 <code>CONFIG.MAPPING.TAKEN</code> and a free one the 404 a create expects; an endpoint that serves no create reads plain.</p>
/// <p><b>The NLS configured defaults</b> (<code>NLSDefaults</code>, Story 21.14) list one row per <code>%SYS.NLS.Table</code> category
/// (<parameter>NLSCATEGORIES</parameter>) and the locale-format switch <code>LocaleFormat</code>. A table row's <code>Value</code> is the
/// configured table, else the current locale's (<code>CSP</code> else <parameter>NLSCSPDEFAULT</parameter>), and its <code>Source</code>
/// is <code>config</code> or <code>locale</code>; a table row is read only. <code>LocaleFormat</code> is <code>1</code> while its node
/// (<code>^SYS("NLS","Config","LocaleFormat")</code>) reads 1, else <code>0</code>, with <code>Source</code> <code>config</code> while the
/// node is defined; it is the one row a set changes, and the current locale is reloaded once the write has read OK
/// (<method>ReloadAfterSet</method>). Only this endpoint's rows carry <code>Source</code>.</p>
/// <p><b>The system-wide security parameters</b> (<code>Security</code>, Story 21.10) are the settings of <code>Security.System</code>
/// that the classic Parameters page shows, named by <parameter>SECURITYROSTER</parameter>: a read emits those names and no other
/// property of the class, whose <code>Get</code> array also carries key material and a mail password (AD-35). A set sends the settable
/// roster names through the vendor's <code>Modify</code>, the one named key at its new value and every other settable name as the read
/// answered it (AD-4); a name the roster marks shown and never changed is refused before any vendor call. The endpoint's gate adds
/// <parameter>SECURITYPAIRS</parameter>.</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>LogFault</method>,
/// <method>SendProperties</method>, <method>ReadEntry</method>, <method>CollectNamed</method>, <method>SendEntry</method>,
/// <method>CreateEntry</method>, <method>DeleteEntry</method>,
/// <method>SendNode</method>, <method>SendNlsNode</method>, <method>SendTsql</method>, <method>StoredDialect</method>,
/// <method>PurgeCachedQueries</method> and <method>ReloadLocale</method>. Production overrides none of them.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9); the caller's namespace is unchanged on
/// return.</p>
Class OcuPilot.Port.ConfigPort Extends %RegisteredObject
{

/// <p>The pair set every read requires, comma-separated as <code>resource:permission</code>, in the order the gate
/// reports in (AD-8, AD-29): the classic Memory and Startup tables' own.</p>
Parameter PAIRS = "%Admin_Manage:USE,%DB_IRISSYS:READ";

/// <p>The pair set every write requires: the read pairs and <code>%DB_IRISSYS:WRITE</code>, which the vendor's
/// <code>Config</code> writes need of a caller that does not hold <code>%All</code> (measured on
/// <code>ocupilot-ci</code>).</p>
Parameter WRITEPAIRS = "%Admin_Manage:USE,%DB_IRISSYS:READ,%DB_IRISSYS:WRITE";

/// <p>The pair the <code>Compatibility</code> endpoint requires beyond the read or write set: the classic menu's own
/// gate on its Compatibility page.</p>
Parameter COMPATIBILITYPAIRS = "%Admin_Secure:USE";

/// <p>The pair the <code>Security</code> endpoint requires beyond the read or write set: the one <code>Security.System</code>'s
/// <code>Get</code> and <code>Modify</code> need of a caller that does not hold <code>%All</code> (measured on
/// <code>ocupilot-ci</code>).</p>
Parameter SECURITYPAIRS = "%Admin_Secure:USE";

/// <p>The class the pair sets are evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The endpoints a screen's read lists, in <code>LIST</code>.</p>
Parameter ENDPOINTS = "Startup,Memory,Compatibility,SQL,SQLShell,TSQL,ISQL,SystemDDL,UserDDL,NLSDefaults,Security";

Parameter STARTUPENDPOINT = "Startup";

Parameter MEMORYENDPOINT = "Memory";

Parameter COMPATIBILITYENDPOINT = "Compatibility";

Parameter SQLENDPOINT = "SQL";

Parameter SHELLENDPOINT = "SQLShell";

Parameter TSQLENDPOINT = "TSQL";

Parameter ISQLENDPOINT = "ISQL";

Parameter SYSTEMDDLENDPOINT = "SystemDDL";

Parameter USERDDLENDPOINT = "UserDDL";

Parameter NLSENDPOINT = "NLSDefaults";

Parameter SECURITYENDPOINT = "Security";

/// <p>The vendor class each endpoint lists and sets.</p>
Parameter STARTUPCLASS = "Config.Startup";

Parameter MEMORYCLASS = "Config.config";

Parameter COMPATIBILITYCLASS = "Config.Miscellaneous";

Parameter SQLCLASS = "Config.SQL";

Parameter SYSTEMDDLCLASS = "Config.SqlSysDatatypes";

Parameter USERDDLCLASS = "Config.SqlUserDatatypes";

/// <p>The property of a DDL mapping entry that holds its datatype class, which a row shows as its <code>Value</code>.</p>
Parameter DATATYPEPROPERTY = "Datatype";

/// <p>The most characters a DDL type name and a datatype hold, as the vendor's own properties declare them (<code>Config.CommonProperties.Name</code>,
/// <code>Config.SqlUserDatatypes.Datatype</code>).</p>
Parameter NAMEMAXLEN As INTEGER = 64;

Parameter DATATYPEMAXLEN As INTEGER = 256;

/// <p>The most entries a named list reads.</p>
Parameter NAMEDMAXROWS As INTEGER = 5000;

/// <p>The <code>Config.SQL</code> settings a caller may set: the classic SQL page's offered keys less
/// <code>DefaultSchema</code>. Every other key is listed and never changed here; a key a later build adds is read only until it
/// is named.</p>
Parameter SETTABLESQL = "AdaptiveMode,AutoParallel,AutoStatsForEfficientSamplingTableOnly,AutoStatsForFixedStatsTable,AutoStatsForRemoteGlobalTable,ClientMaxIdleTime,DDLNo30,DDLNo201,DDLNo307,DDLNo311,DDLNo315,DDLNo324,DDLNo333,DisableNLSCollationMismatchLogging,FastDistinct,HNSWLIBMemoryLimit,IdKey,LockThreshold,LockTimeout,ODBCVarcharMaxlen,ParameterSampling,SaveMAC,TCPKeepAlive,TimePrecision,TODATEDefaultFormat";

/// <p>The <code>Config.SQL</code> settings whose change purges the cached queries of every namespace, as the classic SQL page does.</p>
Parameter PURGESQL = "AdaptiveMode,AutoParallel,DefaultSchema,FastDistinct,ODBCVarcharMaxlen,ParameterSampling";

/// <p>The rosters of the endpoints that have no backing class, entries separated by <code>;</code> and fields by
/// <code>|</code>: name, kind (<code>boolean</code>, <code>choice</code> or <code>text</code>), the choices as
/// <code>shown=stored</code> pairs separated by <code>,</code> (a choice with no <code>=</code> is stored as shown) or a text's
/// longest length, the stored default read while the node is not defined, and whether the name is settable (1) or shown and
/// never changed (0). The SQL Shell's defaults are the shell's own (<code>%SQL.Shell</code>); <code>EscapeCondition</code> is
/// evaluated code, and <code>DisplayPath</code> and <code>DisplayFile</code> are paths (AD-21).</p>
Parameter SHELLROSTER = "SelectMode|choice|Logical=0,ODBC=1,Display=2|0|1;Dialect|choice|IRIS,MSSQL,Sybase|IRIS|1;Path|text||SQLUser|1;ColAlign|choice|Delimiter=0,Header=1,Data=2|0|1;CommandPrefix|text|||1;DisplayMode|choice|CURRENTDEVICE=-1,XML=0,HTML=1,PDF=2,TXT=99,CSV=100|-1|1;DisplayPath|text|||0;DisplayFile|text|||0;DisplayTranslateTable|text||UTF8|1;EchoMode|choice|On=1,Off=0|1|1;ExecuteMode|choice|Immediate=1,Deferred=0|1|1;MessagesMode|choice|On=1,Off=0|1|1;EscapeCondition|text||1|0";

Parameter ISQLROSTER = "DELIMIDENT|boolean||0|1;TRACE|boolean||0|1;FUNCTIONRETURNSSET|boolean||1|1;RESERVEDWORDPREFIX|text|||1";

/// <p>The TSQL settings: the four the classic page offers are settable, the three it omits are shown and never changed. The stored
/// value is the getter's answer (<code>%SYSTEM.TSQL</code>), so the default field is unused.</p>
Parameter TSQLROSTER = "DIALECT|choice|MSSQL,Sybase||1;ANSI_NULLS|choice|OFF,ON||1;CASEINSCOMPARE|choice|OFF,ON||1;QUOTED_IDENTIFIER|choice|OFF,ON||1;EQUAL_LITERAL_REPLACEMENT|choice|OFF,ON||0;OWNER_AS_SCHEMA|choice|OFF,ON||0;TRACE|choice|OFF,ON||0";

/// <p>The <code>%SYSTEM.TSQL</code> setter each settable TSQL name goes through, and the dialect a flag set passes when none is
/// stored, as the classic page saves its shown default.</p>
Parameter TSQLSETTERS = "DIALECT=SetDialect,ANSI_NULLS=SetAnsiNulls,CASEINSCOMPARE=SetCaseInsCompare,QUOTED_IDENTIFIER=SetQuotedIdentifier";

Parameter TSQLDEFAULTDIALECT = "Sybase";

/// <p>What a <code>%SYSTEM.TSQL</code> setter's answer starts with when it refused the value.</p>
Parameter TSQLREFUSAL = "Invalid";

/// <p>The vendor class the <code>Security</code> endpoint reads and sets, and the one record it holds.</p>
Parameter SECURITYCLASS = "Security.System";

Parameter SECURITYNAME = "SYSTEM";

/// <p>The system-wide security parameters, in <parameter>SHELLROSTER</parameter>'s grammar with one more kind, <code>integer</code>,
/// whose detail is <code>minimum:maximum</code> (no maximum when it is empty), and a text's detail its longest length. They are the
/// nineteen fields of the classic Parameters page, each one property of <code>Security.System</code>. The vendor holds some of the
/// page's limits and not others, so the limits here are the page's: a flag is 0 or 1, <code>InactiveLimit</code> is 0 to 365,
/// <code>InvalidLoginLimit</code> 0 to 64 and <code>PasswordExpirationDays</code> 0 to 99999. The last field is whether the name is
/// settable (1) or shown and never changed (0): <code>RequiredRole</code> and <code>PasswordValidationRoutine</code> could lock the
/// instance's own requests out or run code, a positive <code>PasswordExpirationDays</code> expires the password of every account
/// that does not exempt it, a service account's included (AD-10, <code>PROHIBITED.SERVICEACCOUNTSIGNIN</code>), <code>ConfigurationSecurityEnabled</code>, <code>SecurityDomains</code> and
/// <code>DefaultSecurityDomain</code> change how a login is named, <code>AuditEnabled</code> belongs to Auditing, and
/// <code>SSLTelnetServer</code> is listed on Windows only (<parameter>SECURITYWINDOWSONLY</parameter>).</p>
Parameter SECURITYROSTER = "AuditEnabled|boolean|||0;AuditFlags|boolean|||1;ConfigurationSecurityEnabled|boolean|||0;DefaultSecurityDomain|text|128||0;DefaultSignatureHash|choice|SHA1,SHA256,SHA384,SHA512||1;EscalateAuthTimeout|integer|0:||1;EscalateLoginTimeout|integer|0:||1;InactiveLimit|integer|0:365||1;InvalidLoginAction|boolean|||1;InvalidLoginLimit|integer|0:64||1;PasswordExpirationDays|integer|0:99999||0;PasswordPattern|text|64||1;PasswordValidationRoutine|text|128||0;PercentGlobalWrite|boolean|||1;RequiredRole|text|64||0;SQLSecurity|boolean|||1;SSLTelnetServer|integer|0:2||0;SecurityDomains|boolean|||0;WebAppPctAccess|boolean|||1";

/// <p>The roster name listed only where <code>$System.Version.GetOS()</code> reads <code>Windows</code>, as the classic page lists it.</p>
Parameter SECURITYWINDOWSONLY = "SSLTelnetServer";

Parameter TYPELIST = "LIST";

Parameter TYPEGET = "GET";

Parameter TYPESET = "SET";

Parameter TYPECREATE = "CREATE";

Parameter TYPEDELETE = "DELETE";

/// <p>The write request types.</p>
Parameter WRITETYPES = "SET,CREATE,DELETE";

/// <p>The query key a <code>GET</code> carries to ask for the absence read of a create (<code>CREATE</code> is its only value).</p>
Parameter ACTIONKEY = "action";

/// <p>The query keys: the setting named, and the rows a list is read for.</p>
Parameter NAMEKEY = "name";

Parameter MAXROWSKEY = "maxRows";

/// <p>The cap a list that names none is read under.</p>
Parameter DEFAULTMAXROWS As INTEGER = 1000;

/// <p>The settings no row lists, as the classic table leaves them out: platform facts, a value that is always 0,
/// the journal paths Journal settings shows, and the long-string switch. <code>PasswordHash</code> is listed by no read and
/// named by no get or set: it holds the instance password's hash, salt, work factor and algorithm (AD-35). A set still sends
/// it back as the vendor's <code>Get</code> answered it.</p>
Parameter EXCLUDED = "EnableLongStrings,OsType,Platform,PageSizeAlt,ZaMode,globals2kb,pijdir,wijdir,PasswordHash";

/// <p>The setting listed only on an interoperability instance.</p>
Parameter INTEROPONLY = "EnsembleAutoStart";

/// <p>The settings shown and never changed (AD-21): the path-valued strings, and the six network settings whose change
/// could cut OcuPilot off at the next restart, because the web gateway reaches the instance through the default
/// superserver and the private web server serves OcuPilot on this build. Every property of the vendor's path type
/// (<parameter>PATHTYPE</parameter>) is read only too.</p>
Parameter READONLY = "LibPath,Path,PythonPath,PythonRuntimeLibrary,DefaultPort,DefaultPortBindAddress,WebServer,WebServerName,WebServerPort,WebServerProtocol";

Parameter PATHTYPE = "%Library.SysPath";

/// <p>The settings a vendor source states take effect only at the next restart, and the vendor's own source for each
/// memory setting is <code>Config.config.NoRestartOnActivate</code>. <code>MaxIRISTempSizeAtStart</code>'s source is its own property
/// description in <code>Config.Startup</code>, which applies it when the system restarts.</p>
Parameter RESTARTSTARTUP = "WebServer,ErrorPurge,DefaultPort,MaxIRISTempSizeAtStart";

Parameter RESTARTCOMPATIBILITY = "NullSubscripts";

/// <p>The block sizes a <code>DBSizesAllowed</code> value lists, and the one it must hold.</p>
Parameter BLOCKSIZES = "4096,8192,16384,32768,65536";

Parameter BLOCKSIZEREQUIRED = 8192;

/// <p>The text length a setting whose property declares none is held to.</p>
Parameter DEFAULTMAXLEN As INTEGER = 255;

/// <p>The <code>%SYS.NLS.Table</code> categories the <code>NLSDefaults</code> endpoint lists, as <code>category=locale property</code>: the
/// locale property whose table a category inherits while no table is configured. <code>CSP</code> has none and reads
/// <parameter>NLSCSPDEFAULT</parameter>.</p>
Parameter NLSCATEGORIES = "Process=TranZCVT,IRISTerminal=TranProgrammer,OtherTerminal=TranTerminal,File=TranSequential,Magtape=TranMagTape,TCPIP=TranTCP,DSMDDP=TranDDP,DTMDCP=TranDTMDCP,SystemCall=TranSystemCall,Printer=TranPrinter,PatternMatch=PatternTable,Identifier=IdentifierTable,Uppercase=UpperCaseTable,Lowercase=LowerCaseTable,Titlecase=TitleCaseTable,Accent=AccentTable,Collation=CollationTable,XYAction=XYTable,CSP=";

Parameter NLSCSPDEFAULT = "UTF8";

/// <p>The one settable row of the <code>NLSDefaults</code> endpoint.</p>
Parameter NLSFORMATNAME = "LocaleFormat";

/// <p>The subsystem every log line of this port is written under.</p>
Parameter LOGSUBSYSTEM = "configport";

Parameter REASONNOTIMPLEMENTED = "This instance does not implement that operation.";

Parameter REASONMAXROWS = "maxRows must be a whole number above zero.";

Parameter REASONBODY = "a set takes the new value as text in Value.";

Parameter REASONCREATEBODY = "a create takes the datatype as text in Value.";

/// <p>The class the pair sets are evaluated through. Overridable so a fixture can drive a denial in process;
/// production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>Send a raw status to the log, and nowhere else (AD-39). Overridable so a fixture can capture the line;
/// production never overrides it.</p>
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

/// <p>Whether <var>pEndpoint</var> serves request type <var>pType</var>: every endpoint answers <code>LIST</code>, <code>GET</code> and
/// <code>SET</code>; <code>CREATE</code> only the user DDL mappings, and <code>DELETE</code> only the two DDL mappings.</p>
ClassMethod Serves(pEndpoint As %String, pType As %String) As %Boolean
{
    If '$ListFind($ListFromString(..#ENDPOINTS), pEndpoint) Quit 0
    If pType = ..#TYPECREATE Quit pEndpoint = ..#USERDDLENDPOINT
    If pType = ..#TYPEDELETE Quit ..IsNamed(pEndpoint)
    Quit (pType = ..#TYPELIST) || (pType = ..#TYPEGET) || (pType = ..#TYPESET)
}

/// <p>The vendor class <var>pEndpoint</var> lists and sets, or <code>""</code> for an endpoint this port does not
/// serve.</p>
ClassMethod VendorClass(pEndpoint As %String) As %String
{
    If pEndpoint = ..#STARTUPENDPOINT Quit ..#STARTUPCLASS
    If pEndpoint = ..#MEMORYENDPOINT Quit ..#MEMORYCLASS
    If pEndpoint = ..#COMPATIBILITYENDPOINT Quit ..#COMPATIBILITYCLASS
    If pEndpoint = ..#SQLENDPOINT Quit ..#SQLCLASS
    If pEndpoint = ..#SYSTEMDDLENDPOINT Quit ..#SYSTEMDDLCLASS
    If pEndpoint = ..#USERDDLENDPOINT Quit ..#USERDDLCLASS
    Quit ""
}

/// <p>Whether <var>pEndpoint</var> lists named entries, each read by the vendor's <code>Get</code> of its name: the two DDL mappings.</p>
ClassMethod IsNamed(pEndpoint As %String) As %Boolean
{
    Quit (pEndpoint = ..#SYSTEMDDLENDPOINT) || (pEndpoint = ..#USERDDLENDPOINT)
}

/// <p>Whether <var>pEndpoint</var> has no backing class and is listed from a fixed roster: the SQL Shell, TSQL and ISQL
/// settings.</p>
ClassMethod IsRoster(pEndpoint As %String) As %Boolean
{
    Quit (pEndpoint = ..#SHELLENDPOINT) || (pEndpoint = ..#TSQLENDPOINT) || (pEndpoint = ..#ISQLENDPOINT)
}

/// <p>Whether <var>pEndpoint</var> lists the NLS configured defaults and the locale-format switch.</p>
ClassMethod IsNls(pEndpoint As %String) As %Boolean
{
    Quit pEndpoint = ..#NLSENDPOINT
}

/// <p>Whether <var>pEndpoint</var> lists the system-wide security parameters.</p>
ClassMethod IsSecurity(pEndpoint As %String) As %Boolean
{
    Quit pEndpoint = ..#SECURITYENDPOINT
}

/// <p>Whether <var>pName</var> is a <code>%SYS.NLS.Table</code> category <parameter>NLSCATEGORIES</parameter> names.</p>
ClassMethod IsNlsCategory(pName As %String) As %Boolean
{
    For tI = 1:1:$Length(..#NLSCATEGORIES, ",") {
        If $Piece($Piece(..#NLSCATEGORIES, ",", tI), "=", 1) = pName Quit
    }
    Quit ($Piece($Piece(..#NLSCATEGORIES, ",", tI), "=", 1) = pName) && (pName '= "")
}

/// <p>Serve <var>pEndpoint</var> for request type <var>pType</var>, after the gate.</p>
/// <p>A read answers <var>pResult</var> as an array of rows (<code>LIST</code>) or as one row (<code>GET</code>); a
/// <code>SET</code> and a <code>CREATE</code> answer <code>{Name, Value}</code> and a <code>DELETE</code> <code>{Name}</code>. A
/// <code>LIST</code>, a <code>GET</code> and a <code>DELETE</code> take no body; a <code>SET</code> and a <code>CREATE</code> take the
/// object whose <code>Value</code> is the new value, or the new mapping's datatype, as text.</p>
/// <p>Otherwise an error status is returned, <var>pHttpStatus</var> is the status to answer with and
/// <var>pFault</var> the wire fault: 403 <code>AUTH.NOPRIVILEGE</code> with <code>detail.failedPair</code>; 501
/// <code>PORT.NOTIMPLEMENTED</code> for another endpoint or type; 400 <code>PORT.VALIDATION</code> for a cap or a body
/// of the wrong shape; each <code>CONFIG.*</code> refusal on the status <class>OcuPilot.Api.ConfigError</class> names;
/// and 500 <code>INTERNAL</code>, logged, for any failure.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSC = ..Admit(pEndpoint, pType, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '..Serves(pEndpoint, pType) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPESET {
            Set tSC = ..SetValue(pEndpoint, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPECREATE {
            Set tSC = ..CreateValue(pEndpoint, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If $IsObject(pBody) || (pBody '= "") {
            Set tSC = ..Fail(pEndpoint _ " " _ pType _ " was given a caller body, and it takes none", $$$ERROR($$$GeneralError, "a settings read takes no body"), .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPEDELETE {
            Set tSC = ..DeleteValue(pEndpoint, .pQuery, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPEGET {
            If ($Get(pQuery(..#ACTIONKEY)) = ..#TYPECREATE) && ..Serves(pEndpoint, ..#TYPECREATE) {
                Set tSC = ..Absence(pEndpoint, $Get(pQuery(..#NAMEKEY)), .pResult, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..Row(pEndpoint, $Get(pQuery(..#NAMEKEY)), .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tMaxText = $Get(pQuery(..#MAXROWSKEY))
        If (tMaxText '= "") && '$Match(tMaxText, "^[1-9][0-9]*$") {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONMAXROWS, .pHttpStatus, .pFault)
            Quit
        }
        Set tMax = $Select(tMaxText = "": ..#DEFAULTMAXROWS, 1: +tMaxText)
        Set tSC = ..Listing(pEndpoint, tMax, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) Set pResult = ""
    Quit tSC
}

/// <p>The rows of <var>pEndpoint</var>, after the read gate, at most <var>pMax</var> of them: the call the screens' and
/// the read tools' reads are issued through (AD-36). Otherwise <method>Invoke</method>'s answers.</p>
ClassMethod Rows(pEndpoint As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pRows = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Admit(pEndpoint, ..#TYPELIST, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '..Serves(pEndpoint, ..#TYPELIST) Quit ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ..#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
    Try {
        Set tSC = ..Listing(pEndpoint, pMax, .pRows, .pHttpStatus, .pFault)
    } Catch ex {
        Set pRows = ""
        Set tSC = ..Fail(pEndpoint _ " failed inside the port", ex.AsStatus(), .pHttpStatus, .pFault)
    }
    If $$$ISERR(tSC) Set pRows = ""
    Quit tSC
}

/// <p>The gate: <parameter>WRITEPAIRS</parameter> for a write type, otherwise <parameter>PAIRS</parameter>, with
/// <parameter>COMPATIBILITYPAIRS</parameter> added for the <code>Compatibility</code> endpoint and
/// <parameter>SECURITYPAIRS</parameter> for the <code>Security</code> endpoint.</p>
ClassMethod Admit(pEndpoint As %String, pType As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tFailedPair = ""
    Set tSpec = $Select(..IsWrite(pType): ..#WRITEPAIRS, 1: ..#PAIRS)
    If pEndpoint = ..#COMPATIBILITYENDPOINT Set tSpec = tSpec _ "," _ ..#COMPATIBILITYPAIRS
    If pEndpoint = ..#SECURITYENDPOINT Set tSpec = tSpec _ "," _ ..#SECURITYPAIRS
    ; EvaluateRequired, not EvaluatePairs: a pair parameter mis-edited to empty fails closed.
    If $ClassMethod(..GateClass(), "EvaluateRequired", ..Pairs(tSpec), .tFailedPair) Quit $$$OK
    Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
}

/// <p>The rows of <var>pEndpoint</var>'s list as an array, at most <var>pMax</var> of them.</p>
ClassMethod Listing(pEndpoint As %String, pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 200
    Set tSC = ..Collect(pEndpoint, "", .tAll)
    If $$$ISERR(tSC) Quit ..Fail("the settings could not be read", tSC, .pHttpStatus, .pFault)
    Set pRows = []
    Set tIterator = tAll.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If pRows.%Size() >= pMax Quit
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

/// <p>The row of the setting <var>pName</var>, compared exactly, in <var>pRow</var>. A name the class does not list is
/// 404 <code>CONFIG.SETTING.NOTFOUND</code>.</p>
ClassMethod Row(pEndpoint As %String, pName As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pRow = ""
    If pName = "" Quit ..Refused(##class(OcuPilot.Api.ConfigError).#SETTINGNOTFOUND, .pHttpStatus, .pFault)
    Set tSC = ..Collect(pEndpoint, pName, .tOne)
    If $$$ISERR(tSC) Quit ..Fail("the setting could not be read", tSC, .pHttpStatus, .pFault)
    If tOne.%Size() = 0 Quit ..Refused(##class(OcuPilot.Api.ConfigError).#SETTINGNOTFOUND, .pHttpStatus, .pFault)
    Set pRow = tOne.%Get(0)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The absence read of a create of <var>pName</var> on <var>pEndpoint</var>: a name the endpoint holds is 409
/// <code>CONFIG.MAPPING.TAKEN</code>, and a free one the 404 <code>CONFIG.SETTING.NOTFOUND</code> a create expects.</p>
ClassMethod Absence(pEndpoint As %String, pName As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pRow = ""
    If pName = "" Quit ..Refused(##class(OcuPilot.Api.ConfigError).#SETTINGNOTFOUND, .pHttpStatus, .pFault)
    Set tSC = ..Row(pEndpoint, pName, .pRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pRow = ""
    Quit ..Refused(##class(OcuPilot.Api.ConfigError).#MAPPINGTAKEN, .pHttpStatus, .pFault)
}

/// <p>The rows of <var>pEndpoint</var>'s class in <var>pRows</var>, or, when <var>pName</var> is given, that
/// setting's row alone when the class lists it. <code>Get</code> and the limits are read in <code>%SYS</code>, where no
/// product class is visible, so the rows are built after the namespace is restored.</p>
ClassMethod Collect(pEndpoint As %String, pName As %String, Output pRows As %DynamicArray) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pRows = []
    Kill tData
    Set tOrigNS = $NAMESPACE
    Try {
        If ..IsRoster(pEndpoint) {
            Set $NAMESPACE = "%SYS"
            Set tSC = ..CollectRoster(pEndpoint, pName, .tData)
            Quit
        }
        If ..IsNls(pEndpoint) {
            Set $NAMESPACE = "%SYS"
            Set tSC = ..CollectNls(pName, .tData)
            Quit
        }
        If ..IsSecurity(pEndpoint) {
            Set tSC = ..CollectSecurity(pName, .tData)
            Quit
        }
        Set tClass = ..VendorClass(pEndpoint)
        If tClass = "" Quit
        If ..IsNamed(pEndpoint) {
            Set $NAMESPACE = "%SYS"
            Set tSC = ..CollectNamed(tClass, pName, .tData)
            Quit
        }
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tSC = $ClassMethod(tClass, "Get", .tProps)
        If $$$ISERR(tSC) Quit
        Set tInterop = ##class(%Library.EnsembleMgr).IsEnsembleInstalled()
        Set tKey = ""
        For {
            Set tKey = $Order(tProps(tKey))
            If tKey = "" Quit
            If (pName '= "") && (tKey '= pName) Continue
            If $ListFind($ListFromString(..#EXCLUDED), tKey) Continue
            If 'tInterop && $ListFind($ListFromString(..#INTEROPONLY), tKey) Continue
            Set tData(tKey) = $ListBuild(tProps(tKey), ..LimitsOf(tClass, tKey), ..IsReadOnly(pEndpoint, tClass, tKey), ..NeedsRestart(pEndpoint, tClass, tKey), ..IsPurging(pEndpoint, tKey))
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    If $$$ISERR(tSC) Quit tSC
    Set tKey = ""
    For {
        Set tKey = $Order(tData(tKey))
        If tKey = "" Quit
        Do pRows.%Push(..BuildRow(tKey, tData(tKey)))
    }
    Quit $$$OK
}

/// <p>The rows of the <code>NLSDefaults</code> endpoint into <var>pData</var>, or the one named <var>pName</var>, in the shape
/// <method>BuildRow</method> reads with its sixth item, the <code>Source</code>: each category's configured table, else the current
/// locale's, and <code>LocaleFormat</code>. In <code>%SYS</code>.</p>
ClassMethod CollectNls(pName As %String, ByRef pData) As %Status [ Private ]
{
    Set tConfig = ##class(%SYS.NLS.Table).%New("Config")
    Set tLocale = ##class(Config.NLS.Locales).OpenCurrent(.tOpen)
    If $$$ISERR(tOpen) Quit tOpen
    If '$IsObject(tLocale) Quit $$$ERROR($$$GeneralError, "the current locale could not be opened")
    For tI = 1:1:$Length(..#NLSCATEGORIES, ",") {
        Set tName = $Piece($Piece(..#NLSCATEGORIES, ",", tI), "=", 1)
        Set tProperty = $Piece($Piece(..#NLSCATEGORIES, ",", tI), "=", 2)
        If (pName '= "") && (tName '= pName) Continue
        Set tValue = $Property(tConfig, tName)
        Set tSource = "config"
        If tValue = "" {
            Set tSource = "locale"
            Set tValue = $Select(tProperty = "": ..#NLSCSPDEFAULT, 1: $Property(tLocale, tProperty))
        }
        Set pData(tName) = $ListBuild(tValue, ..Limits(..#NLSENDPOINT, tName), 1, 0, 0, tSource)
    }
    If (pName = "") || (pName = ..#NLSFORMATNAME) {
        Set tNode = $Get(^SYS("NLS", "Config", "LocaleFormat"))
        Set pData(..#NLSFORMATNAME) = $ListBuild($Select(tNode = 1: 1, 1: 0), ..Limits(..#NLSENDPOINT, ..#NLSFORMATNAME), 0, 0, 0, $Select($Data(^SYS("NLS", "Config", "LocaleFormat")): "config", 1: "locale"))
    }
    Quit $$$OK
}

/// <p>The rows of the <code>Security</code> endpoint into <var>pData</var>, or the one named <var>pName</var>, in the shape
/// <method>BuildRow</method> reads: one row per name of <parameter>SECURITYROSTER</parameter> (less the Windows-only name elsewhere),
/// valued from the vendor's <code>Get</code> through <method>ReadEntry</method>; <parameter>SECURITYWINDOWSONLY</parameter> is left out
/// off Windows. No other property of the vendor's answer is listed.</p>
ClassMethod CollectSecurity(pName As %String, ByRef pData) As %Status [ Private ]
{
    Set tSC = ..ReadEntry(..#SECURITYCLASS, ..#SECURITYNAME, .tProps)
    If $$$ISERR(tSC) Quit tSC
    Set tRoster = ..RosterOf(..#SECURITYENDPOINT)
    For tI = 1:1:$ListLength(tRoster) {
        Set tEntry = $List(tRoster, tI)
        Set tKey = $List(tEntry, 1)
        If (pName '= "") && (tKey '= pName) Continue
        If (tKey = ..#SECURITYWINDOWSONLY) && ($System.Version.GetOS() '= "Windows") Continue
        Set pData(tKey) = $ListBuild($Get(tProps(tKey)), ..EntryLimits(tEntry), '$List(tEntry, 5), 0, 0)
    }
    Quit $$$OK
}

/// <p>The entries of the named class <var>pClass</var> into <var>pData</var>, in the shape <method>BuildRow</method> reads: all of them
/// through the vendor's <code>List</code> query with <code>*</code>, at most <parameter>NAMEDMAXROWS</parameter>, or, when
/// <var>pName</var> is given, that one entry through <code>Exists</code> and <code>Get</code>, which compare the name exactly. A name
/// is never passed to <code>List</code>, whose <code>Names</code> argument is a pattern. In <code>%SYS</code>.</p>
ClassMethod CollectNamed(pClass As %String, pName As %String, ByRef pData) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tLimits = ..DatatypeLimits()
    If pName '= "" {
        If '$ClassMethod(pClass, "Exists", pName) Quit $$$OK
        Kill tProps
        Set tSC = $ClassMethod(pClass, "Get", pName, .tProps)
        If $$$ISERR(tSC) Quit tSC
        Set pData(pName) = $ListBuild($Get(tProps(..#DATATYPEPROPERTY)), tLimits, 0, 0, 0)
        Quit $$$OK
    }
    Set tResult = ##class(%ResultSet).%New(pClass _ ":List")
    Set tSC = tResult.Execute("*")
    If $$$ISERR(tSC) Quit tSC
    Set tCount = 0
    While tResult.Next() {
        If $Increment(tCount) > ..#NAMEDMAXROWS Quit
        Set pData(tResult.Get("Name")) = $ListBuild(tResult.Get(..#DATATYPEPROPERTY), tLimits, 0, 0, 0)
    }
    Quit $$$OK
}

/// <p>The limits of a DDL mapping's datatype, in <method>Limits</method>'s shape: kind <code>datatype</code> and its longest length.</p>
ClassMethod DatatypeLimits() As %List
{
    Quit $ListBuild("datatype", "", "", "", ..#DATATYPEMAXLEN, "")
}

/// <p>The row of the setting <var>pName</var> from <var>pData</var>, <code>$ListBuild(value, limits, readOnly,
/// restart, purges)</code>, with <code>Source</code> when <var>pData</var> carries a sixth item.</p>
ClassMethod BuildRow(pName As %String, pData As %List) As %DynamicObject [ Private ]
{
    Set tLimits = $List(pData, 2)
    Set tReadOnly = $List(pData, 3)
    Set tRow = {}
    Do tRow.%Set("Name", pName, "string")
    Do tRow.%Set("Value", $List(pData, 1) _ "", "string")
    Do tRow.%Set("Kind", $ListGet(tLimits, 1), "string")
    Do tRow.%Set("Accepts", $Select(tReadOnly: ##class(OcuPilot.Api.ConfigError).#ACCEPTSREADONLY, 1: ..AcceptsOf(tLimits)), "string")
    Do tRow.%Set("Restart", ''$List(pData, 4), "boolean")
    Do tRow.%Set("ReadOnly", ''tReadOnly, "boolean")
    Do tRow.%Set("Purges", ''$List(pData, 5), "boolean")
    If $ListLength(pData) > 5 Do tRow.%Set("Source", $List(pData, 6), "string")
    Quit tRow
}

/// <p>The limits of the setting <var>pName</var> of <var>pEndpoint</var>, read at call time, as
/// <code>$ListBuild(kind, min, max, choices, maxLength, sentinel)</code>, or <code>""</code> when the class has no such
/// property. <code>kind</code> is <code>boolean</code>, <code>integer</code>, <code>choice</code>, <code>text</code> or
/// <code>blocksizes</code>; <code>choices</code> is a <code>$ListBuild</code> list; <code>sentinel</code> is the one value
/// outside the range that the setting also accepts, or <code>""</code>.</p>
/// <p>Beyond the dictionary: <code>DBSizesAllowed</code> is block sizes, <code>ListFormat</code> is 0 or 1,
/// <code>bbsiz</code> is -1 or 256 to 2147483647, <code>routines</code> is 0 or 36 to 65536 and
/// <code>HNSWLIBMemoryLimit</code> is -1 or 0 to 2147483647, as the classic pages and value editor judge them; an integer with
/// no declared minimum starts at 0, which is stricter than the dictionary and what the vendor's own check holds the two settings
/// that declare only a maximum to. A roster endpoint's limits are its roster entry's (<method>EntryLimits</method>).</p>
ClassMethod Limits(pEndpoint As %String, pName As %String) As %List
{
    Set tLimits = ""
    If ..IsRoster(pEndpoint) || ..IsSecurity(pEndpoint) Quit ..EntryLimits(..RosterEntry(pEndpoint, pName))
    If ..IsNamed(pEndpoint) Quit ..DatatypeLimits()
    If ..IsNls(pEndpoint) {
        If pName = ..#NLSFORMATNAME Quit $ListBuild("boolean", "", "", "", "", "")
        If ..IsNlsCategory(pName) Quit $ListBuild("text", "", "", "", ..#DEFAULTMAXLEN, "")
        Quit ""
    }
    Set tClass = ..VendorClass(pEndpoint)
    If tClass = "" Quit ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tLimits = ..LimitsOf(tClass, pName)
    } Catch {
        Set tLimits = ""
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tLimits
}

/// <p><method>LimitsOf</method> for the property <var>pName</var> of the vendor class <var>pClass</var>, read in <code>%SYS</code> by save and
/// restore; <code>""</code> when the class has no such property or cannot be read.</p>
ClassMethod ClassLimits(pClass As %String, pName As %String) As %List
{
    Set tLimits = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tLimits = ..LimitsOf(pClass, pName)
    } Catch {
        Set tLimits = ""
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tLimits
}

/// <p><method>Limits</method> for the vendor class <var>pClass</var>, in <code>%SYS</code>.</p>
ClassMethod LimitsOf(pClass As %String, pName As %String) As %List
{
    Set tProperty = ##class(%Dictionary.CompiledProperty).%OpenId(pClass _ "||" _ pName, 0)
    If '$IsObject(tProperty) Quit ""
    If pName = "DBSizesAllowed" Quit $ListBuild("blocksizes", "", "", "", "", "")
    If pName = "ListFormat" Quit $ListBuild("choice", "", "", $ListBuild(0, 1), "", "")
    If pName = "bbsiz" Quit $ListBuild("integer", 256, 2147483647, "", "", -1)
    If pName = "routines" Quit $ListBuild("integer", 36, 65536, "", "", 0)
    If pName = "HNSWLIBMemoryLimit" Quit $ListBuild("integer", 0, 2147483647, "", "", -1)
    Set tType = tProperty.RuntimeType
    Set tValueList = tProperty.Parameters.GetAt("VALUELIST")
    If tValueList '= "" {
        Set tChoices = ""
        For tI = 1:1:$Length(tValueList, ",") {
            Set tChoice = $Piece(tValueList, ",", tI)
            If tChoice '= "" Set tChoices = tChoices _ $ListBuild(tChoice)
        }
        Quit $ListBuild("choice", "", "", tChoices, "", "")
    }
    If tType = "%Library.Boolean" Quit $ListBuild("boolean", "", "", "", "", "")
    If tType = "%Library.Integer" {
        Set tMin = tProperty.Parameters.GetAt("MINVAL")
        Set tMax = tProperty.Parameters.GetAt("MAXVAL")
        Quit $ListBuild("integer", $Select(tMin = "": 0, 1: tMin), tMax, "", "", "")
    }
    Set tLength = tProperty.Parameters.GetAt("MAXLEN")
    Quit $ListBuild("text", "", "", "", $Select(tLength = "": ..#DEFAULTMAXLEN, 1: tLength), "")
}

/// <p>What a row's <code>Accepts</code> reads for <var>pLimits</var> (<method>Limits</method>'s answer), from
/// <class>OcuPilot.Api.ConfigError</class>'s sentences.</p>
ClassMethod AcceptsOf(pLimits As %List) As %String
{
    Set tKind = $ListGet(pLimits, 1)
    If tKind = "boolean" Quit ##class(OcuPilot.Api.ConfigError).#ACCEPTSBOOLEAN
    If tKind = "blocksizes" Quit ##class(OcuPilot.Api.ConfigError).#ACCEPTSBLOCKSIZES
    If tKind = "datatype" Quit ##class(OcuPilot.Api.ConfigError).#ACCEPTSDATATYPE
    If tKind = "choice" Quit ##class(OcuPilot.Api.ConfigError).Accepting(##class(OcuPilot.Api.ConfigError).#ACCEPTSCHOICE, $ListToString($ListGet(pLimits, 4), ", "))
    If tKind = "text" Quit ##class(OcuPilot.Api.ConfigError).Accepting(##class(OcuPilot.Api.ConfigError).#ACCEPTSTEXT, $ListGet(pLimits, 5))
    If tKind = "integer" {
        If $ListGet(pLimits, 3) = "" Quit ##class(OcuPilot.Api.ConfigError).Accepting(##class(OcuPilot.Api.ConfigError).#ACCEPTSMINIMUM, $ListGet(pLimits, 2))
        Quit ##class(OcuPilot.Api.ConfigError).Accepting(##class(OcuPilot.Api.ConfigError).#ACCEPTSRANGE, $ListGet(pLimits, 2), $ListGet(pLimits, 3))
    }
    Quit ""
}

/// <p>Whether the setting <var>pName</var> of <var>pClass</var> is shown and never changed: for the <code>SQL</code> endpoint,
/// any key outside <parameter>SETTABLESQL</parameter>; otherwise one of <parameter>READONLY</parameter>, or a property of the
/// vendor's path type (<parameter>PATHTYPE</parameter>). In <code>%SYS</code>.</p>
ClassMethod IsReadOnly(pEndpoint As %String, pClass As %String, pName As %String) As %Boolean [ Private ]
{
    If pEndpoint = ..#SQLENDPOINT Quit '$ListFind($ListFromString(..#SETTABLESQL), pName)
    If $ListFind($ListFromString(..#READONLY), pName) Quit 1
    Set tProperty = ##class(%Dictionary.CompiledProperty).%OpenId(pClass _ "||" _ pName, 0)
    Quit $IsObject(tProperty) && (tProperty.RuntimeType = ..#PATHTYPE)
}

/// <p>Whether a change of the setting <var>pName</var> takes effect only at the next restart, by the vendor's own source
/// for each class: <code>Config.config.NoRestartOnActivate</code> for a memory setting, and the lists the vendor's
/// documentation and the classic pages state for the other two. A setting with no source reads false, as does every SQL
/// setting. In <code>%SYS</code>.</p>
ClassMethod NeedsRestart(pEndpoint As %String, pClass As %String, pName As %String) As %Boolean [ Private ]
{
    If pEndpoint = ..#SQLENDPOINT Quit 0
    If pEndpoint = ..#MEMORYENDPOINT Quit '$ClassMethod(pClass, "NoRestartOnActivate", pName)
    If pEndpoint = ..#STARTUPENDPOINT Quit ''$ListFind($ListFromString(..#RESTARTSTARTUP), pName)
    Quit ''$ListFind($ListFromString(..#RESTARTCOMPATIBILITY), pName)
}

/// <p>Whether the database block size <var>pSize</var> can be allowed on this instance, by
/// <code>SYS.Database.CheckBlockSizeAvailable</code>. A failed probe reads false.</p>
ClassMethod BlockSizeAvailable(pSize As %Integer) As %Boolean
{
    Set tAvailable = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tAvailable = ''##class(SYS.Database).CheckBlockSizeAvailable(pSize)
    } Catch {
        Set tAvailable = 0
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAvailable
}

/// <p>Set the setting <var>pQuery</var> names to the <code>Value</code> of <var>pBody</var>: the setting is read, the rules
/// refuse a setting shown and never changed and a value it does not accept, and then the write is made as its family does: a
/// class is read fresh and sent whole with that one key changed (<method>VendorModify</method>), a roster node is written with
/// the stored code of the choice (<method>SendNode</method>), a TSQL setting goes through its setter
/// (<method>SendTsql</method>). It purges no cached query: the set tool does that once the write has read OK
/// (<method>PurgeAfterSet</method>). Answers <code>{Name, Value}</code>.</p>
ClassMethod SetValue(pEndpoint As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tName = $Get(pQuery(..#NAMEKEY))
    Set tSC = ..Row(pEndpoint, tName, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") || (pBody.%GetTypeOf("Value") '= "string") {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONBODY, .pHttpStatus, .pFault)
    }
    Set tValue = pBody.%Get("Value")
    Set tCode = ##class(OcuPilot.Area.OsMgmt.ConfigSettingRules).Code(pEndpoint, tRow, tValue)
    If tCode '= "" Quit ..Refused(tCode, .pHttpStatus, .pFault)
    Set tVendor = ..Apply(pEndpoint, tName, tValue)
    If $$$ISERR(tVendor) {
        Do ..LogFault("the setting " _ tName _ " was refused by the vendor", tVendor, ##class(OcuPilot.Api.ConfigError).#SETTINGVALUE)
        Quit ..Refused(##class(OcuPilot.Api.ConfigError).#SETTINGVALUE, .pHttpStatus, .pFault)
    }
    Set pResult = {}
    Do pResult.%Set("Name", tName, "string")
    Do pResult.%Set("Value", tValue, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Create the named entry <var>pQuery</var> names with the datatype <var>pBody</var>'s <code>Value</code> carries, on a user DDL
/// mapping endpoint: a name the endpoint holds is 409 <code>CONFIG.MAPPING.TAKEN</code>; then
/// <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class> judge the name and the datatype
/// (<code>CONFIG.MAPPING.NAME</code>, <code>CONFIG.SETTING.VALUE</code>), and the entry is created through
/// <method>CreateEntry</method>. Answers <code>{Name, Value}</code>.</p>
ClassMethod CreateValue(pEndpoint As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tName = $Get(pQuery(..#NAMEKEY))
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") || (pBody.%GetTypeOf("Value") '= "string") {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ..#REASONCREATEBODY, .pHttpStatus, .pFault)
    }
    If tName '= "" {
        Set tSC = ..Collect(pEndpoint, tName, .tOne)
        If $$$ISERR(tSC) Quit ..Fail("the mapping could not be read", tSC, .pHttpStatus, .pFault)
        If tOne.%Size() > 0 Quit ..Refused(##class(OcuPilot.Api.ConfigError).#MAPPINGTAKEN, .pHttpStatus, .pFault)
    }
    Set tValue = pBody.%Get("Value")
    Set tCode = ##class(OcuPilot.Area.OsMgmt.ConfigSettingRules).CreateCode(tName, tValue)
    If tCode '= "" Quit ..Refused(tCode, .pHttpStatus, .pFault)
    Kill tProps
    Set tProps(..#DATATYPEPROPERTY) = tValue
    Set tVendor = ..CreateEntry(..VendorClass(pEndpoint), tName, .tProps)
    If $$$ISERR(tVendor) {
        Do ..LogFault("the mapping " _ tName _ " was refused by the vendor", tVendor, ##class(OcuPilot.Api.ConfigError).#SETTINGVALUE)
        Quit ..Refused(##class(OcuPilot.Api.ConfigError).#SETTINGVALUE, .pHttpStatus, .pFault)
    }
    Set pResult = {}
    Do pResult.%Set("Name", tName, "string")
    Do pResult.%Set("Value", tValue, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>Delete the named entry <var>pQuery</var> names: an entry the endpoint does not hold is 404
/// <code>CONFIG.SETTING.NOTFOUND</code>; otherwise it is deleted through <method>DeleteEntry</method>, and a vendor refusal is logged
/// and 400 <code>CONFIG.SETTING.VALUE</code>. Answers <code>{Name}</code>.</p>
ClassMethod DeleteValue(pEndpoint As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tName = $Get(pQuery(..#NAMEKEY))
    Set tSC = ..Row(pEndpoint, tName, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tVendor = ..DeleteEntry(..VendorClass(pEndpoint), tName)
    If $$$ISERR(tVendor) {
        Do ..LogFault("the mapping " _ tName _ " was refused by the vendor", tVendor, ##class(OcuPilot.Api.ConfigError).#SETTINGVALUE)
        Quit ..Refused(##class(OcuPilot.Api.ConfigError).#SETTINGVALUE, .pHttpStatus, .pFault)
    }
    Set pResult = {}
    Do pResult.%Set("Name", tName, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The write of the setting <var>pName</var> of <var>pEndpoint</var> to the value <var>pValue</var>, as its family makes it.</p>
ClassMethod Apply(pEndpoint As %String, pName As %String, pValue As %String) As %Status [ Private ]
{
    If pEndpoint = ..#TSQLENDPOINT {
        Set tDialect = ..StoredDialect()
        Quit ..SendTsql(pName, $Select(tDialect = "": ..#TSQLDEFAULTDIALECT, 1: tDialect), pValue)
    }
    If ..IsRoster(pEndpoint) Quit ..SendNode(pEndpoint, pName, ..StoredFor(..RosterEntry(pEndpoint, pName), pValue))
    If ..IsNls(pEndpoint) Quit ..SendNlsNode(pValue)
    If ..IsSecurity(pEndpoint) Quit ..ModifySecurity(pName, pValue)
    If ..IsNamed(pEndpoint) Quit ..ModifyEntry(..VendorClass(pEndpoint), pName, pValue)
    Quit ..VendorModify(..VendorClass(pEndpoint), pName, pValue)
}

/// <p>The roster of <var>pEndpoint</var>, as a list of <code>$ListBuild(name, kind, detail, default, settable)</code>, or
/// <code>""</code> for an endpoint that has none.</p>
ClassMethod RosterOf(pEndpoint As %String) As %List
{
    Set tSpec = $Case(pEndpoint, ..#SHELLENDPOINT: ..#SHELLROSTER, ..#ISQLENDPOINT: ..#ISQLROSTER, ..#TSQLENDPOINT: ..#TSQLROSTER, ..#SECURITYENDPOINT: ..#SECURITYROSTER, : "")
    Set tRoster = ""
    For tI = 1:1:$Length(tSpec, ";") {
        Set tEntry = $Piece(tSpec, ";", tI)
        If tEntry = "" Continue
        Set tRoster = tRoster _ $ListBuild($ListBuild($Piece(tEntry, "|", 1), $Piece(tEntry, "|", 2), $Piece(tEntry, "|", 3), $Piece(tEntry, "|", 4), +$Piece(tEntry, "|", 5)))
    }
    Quit tRoster
}

/// <p>The entry of the roster of <var>pEndpoint</var> that names <var>pName</var>, compared exactly, or <code>""</code>.</p>
ClassMethod RosterEntry(pEndpoint As %String, pName As %String) As %List
{
    Set tRoster = ..RosterOf(pEndpoint)
    For tI = 1:1:$ListLength(tRoster) {
        If $List($List(tRoster, tI), 1) = pName Quit
    }
    Quit $Select(($ListLength(tRoster) > 0) && ($List($List(tRoster, tI), 1) = pName): $List(tRoster, tI), 1: "")
}

/// <p>The limits of a roster entry, in <method>Limits</method>'s shape, or <code>""</code> for no entry.</p>
ClassMethod EntryLimits(pEntry As %List) As %List
{
    If pEntry = "" Quit ""
    Set tKind = $List(pEntry, 2)
    If tKind = "boolean" Quit $ListBuild("boolean", "", "", "", "", "")
    If tKind = "choice" Quit $ListBuild("choice", "", "", ..ChoiceNames($List(pEntry, 3)), "", "")
    If tKind = "integer" Quit $ListBuild("integer", +$Piece($List(pEntry, 3), ":", 1), $Piece($List(pEntry, 3), ":", 2), "", "", "")
    Quit $ListBuild("text", "", "", "", $Select($List(pEntry, 3) = "": ..#DEFAULTMAXLEN, 1: $List(pEntry, 3)), "")
}

/// <p>The names a roster entry's choices show, from its <code>shown=stored</code> pairs.</p>
ClassMethod ChoiceNames(pDetail As %String) As %List [ Private ]
{
    Set tNames = ""
    For tI = 1:1:$Length(pDetail, ",") Set tNames = tNames _ $ListBuild($Piece($Piece(pDetail, ",", tI), "=", 1))
    Quit tNames
}

/// <p>The stored code of the value <var>pValue</var> a roster entry's choices show, or <var>pValue</var> itself for a kind that has
/// no choices.</p>
ClassMethod StoredFor(pEntry As %List, pValue As %String) As %String
{
    If $List(pEntry, 2) '= "choice" Quit pValue
    Set tDetail = $List(pEntry, 3)
    For tI = 1:1:$Length(tDetail, ",") {
        Set tPair = $Piece(tDetail, ",", tI)
        If $Piece(tPair, "=", 1) = pValue Quit
    }
    If $Piece($Piece(tDetail, ",", tI), "=", 1) '= pValue Quit pValue
    Quit $Piece(tPair, "=", $Length(tPair, "="))
}

/// <p>The choice a roster entry shows for the stored code <var>pStored</var>, or the stored text itself when no choice has that
/// code.</p>
ClassMethod ShownFor(pEntry As %List, pStored As %String) As %String
{
    If $List(pEntry, 2) '= "choice" Quit pStored
    Set tDetail = $List(pEntry, 3)
    For tI = 1:1:$Length(tDetail, ",") {
        Set tPair = $Piece(tDetail, ",", tI)
        If $Piece(tPair, "=", $Length(tPair, "=")) = pStored Quit
    }
    If $Piece($Piece(tDetail, ",", tI), "=", $Length($Piece(tDetail, ",", tI), "=")) '= pStored Quit pStored
    Quit $Piece(tPair, "=", 1)
}

/// <p>The rows of the roster endpoint <var>pEndpoint</var> into <var>pData</var>, or the one named <var>pName</var>, in
/// <code>%SYS</code>.</p>
ClassMethod CollectRoster(pEndpoint As %String, pName As %String, ByRef pData) As %Status [ Private ]
{
    Set tRoster = ..RosterOf(pEndpoint)
    For tI = 1:1:$ListLength(tRoster) {
        Set tEntry = $List(tRoster, tI)
        Set tKey = $List(tEntry, 1)
        If (pName '= "") && (tKey '= pName) Continue
        Set pData(tKey) = $ListBuild(..RosterValue(pEndpoint, tEntry), ..EntryLimits(tEntry), '$List(tEntry, 5), 0, 0)
    }
    Quit $$$OK
}

/// <p>The value the roster entry <var>pEntry</var> reads now: a TSQL setting's getter answer, otherwise the node as stored, or
/// the roster's default while it is not defined, shown as its choice. In <code>%SYS</code>.</p>
ClassMethod RosterValue(pEndpoint As %String, pEntry As %List) As %String [ Private ]
{
    Set tName = $List(pEntry, 1)
    If pEndpoint = ..#TSQLENDPOINT Quit ..TsqlValue(tName)
    If pEndpoint = ..#SHELLENDPOINT Quit ..ShownFor(pEntry, $Get(^%SYS("sql", "shell", tName), $List(pEntry, 4)))
    Quit ..ShownFor(pEntry, $Get(^%SYS("xsql", "informix", tName), $List(pEntry, 4)))
}

/// <p>The TSQL setting <var>pName</var> as <code>%SYSTEM.TSQL</code>'s getter answers it: the flag follows the comma and space the
/// getters put after the dialect, and an unset dialect reads empty. In <code>%SYS</code>.</p>
ClassMethod TsqlValue(pName As %String) As %String [ Private ]
{
    If pName = "DIALECT" Quit ##class(%SYSTEM.TSQL).GetDialect()
    If pName = "ANSI_NULLS" Quit $Piece(##class(%SYSTEM.TSQL).GetAnsiNulls(), ", ", 2)
    If pName = "CASEINSCOMPARE" Quit $Piece(##class(%SYSTEM.TSQL).GetCaseInsCompare(), ", ", 2)
    If pName = "QUOTED_IDENTIFIER" Quit $Piece(##class(%SYSTEM.TSQL).GetQuotedIdentifier(), ", ", 2)
    If pName = "EQUAL_LITERAL_REPLACEMENT" Quit $Piece(##class(%SYSTEM.TSQL).GetEqualLiteralReplacement(), ", ", 2)
    If pName = "OWNER_AS_SCHEMA" Quit ##class(%SYSTEM.TSQL).GetOwnerAsSchema()
    If pName = "TRACE" Quit ##class(%SYSTEM.TSQL).GetTrace()
    Quit ""
}

/// <p>Whether a change of the setting <var>pName</var> of <var>pEndpoint</var> purges the cached queries of every namespace.</p>
ClassMethod IsPurging(pEndpoint As %String, pName As %String) As %Boolean [ Private ]
{
    Quit (pEndpoint = ..#SQLENDPOINT) && ''$ListFind($ListFromString(..#PURGESQL), pName)
}

/// <p>The TSQL dialect stored on this instance, or <code>""</code> when none is. Overridable so a fixture can feed the stored
/// dialect a flag set passes on; production never overrides it.</p>
ClassMethod StoredDialect() As %String
{
    Set tDialect = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tDialect = ##class(%SYSTEM.TSQL).GetDialect()
    } Catch {
        Set tDialect = ""
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tDialect
}

/// <p>The one call that changes a SQL Shell or ISQL node: <var>pName</var>'s node of <var>pEndpoint</var> set to the stored code
/// <var>pStored</var>, in <code>%SYS</code> by save and restore. The name is a roster name the rules have already admitted.
/// Overridable so a fixture can record the write; production never overrides it.</p>
ClassMethod SendNode(pEndpoint As %String, pName As %String, pStored As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If pEndpoint = ..#SHELLENDPOINT {
            Set ^%SYS("sql", "shell", pName) = pStored
        } ElseIf pEndpoint = ..#ISQLENDPOINT {
            Set ^%SYS("xsql", "informix", pName) = pStored
        } Else {
            Set tSC = $$$ERROR($$$GeneralError, "no node is written for " _ pEndpoint)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The one call that changes the locale-format switch: the node <code>^SYS("NLS","Config","LocaleFormat")</code> set to <var>pValue</var>, which
/// the rules have admitted as <code>0</code> or <code>1</code>, in <code>%SYS</code> by save and restore. Overridable so a fixture can record
/// the write; production never overrides it.</p>
ClassMethod SendNlsNode(pValue As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set ^SYS("NLS", "Config", "LocaleFormat") = pValue
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The <code>%SYSTEM.TSQL</code> setter <parameter>TSQLSETTERS</parameter> names for the TSQL setting <var>pName</var>, or
/// <code>""</code>.</p>
ClassMethod TsqlSetter(pName As %String) As %String [ Private ]
{
    Set tSetter = ""
    For tI = 1:1:$Length(..#TSQLSETTERS, ",") {
        If $Piece($Piece(..#TSQLSETTERS, ",", tI), "=", 1) = pName Set tSetter = $Piece($Piece(..#TSQLSETTERS, ",", tI), "=", 2)
    }
    Quit tSetter
}

/// <p>The one call that changes a TSQL setting: <var>pName</var>'s <code>%SYSTEM.TSQL</code> setter, given the dialect
/// <var>pDialect</var> the flag setters take and the value, in <code>%SYS</code> by save and restore. A setter answer that starts
/// with <parameter>TSQLREFUSAL</parameter> is an error. Overridable so a fixture can record the call; production never overrides
/// it.</p>
ClassMethod SendTsql(pName As %String, pDialect As %String, pValue As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSetter = ..TsqlSetter(pName)
        If tSetter = "" {
            Set tSC = $$$ERROR($$$GeneralError, "no TSQL setter is named for " _ pName)
            Quit
        }
        If pName = "DIALECT" {
            Set tAnswer = $ClassMethod("%SYSTEM.TSQL", tSetter, pValue)
        } Else {
            Set tAnswer = $ClassMethod("%SYSTEM.TSQL", tSetter, pDialect, pValue)
        }
        If $Extract(tAnswer, 1, $Length(..#TSQLREFUSAL)) = ..#TSQLREFUSAL Set tSC = $$$ERROR($$$GeneralError, tAnswer)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The purge a set of the setting <var>pName</var> of <var>pEndpoint</var> owes once its write has read OK, run by the set tool's
/// <method>OcuPilot.Screen.Tool.ConfigSettingSet.AfterWrite</method> for both callers, so a purge that fails is the failure of an
/// applied write, which the agent's confirm still marks (AD-15). A setting that does not purge owes none. Otherwise, after the
/// write gate, the setting is read again and the cached queries of every namespace are purged in this request
/// (<method>PurgeCachedQueries</method>) when it no longer reads <var>pBefore</var>, its value before the write; with
/// <var>pKnown</var> 0, no value before the write being known, they are purged whatever it reads. A re-read or a purge that fails
/// is 500 <code>INTERNAL</code>, logged; the setting stays as written.</p>
ClassMethod PurgeAfterSet(pEndpoint As %String, pName As %String, pBefore As %String, pKnown As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    If '..IsPurging(pEndpoint, pName) Quit $$$OK
    Set tSC = ..Admit(pEndpoint, ..#TYPESET, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tMessage = "the cached queries could not be purged after the setting " _ pName _ " changed"
    Try {
        If pKnown {
            Set tSC = ..Row(pEndpoint, pName, .tRow, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            Set pHttpStatus = 0
            If (tRow.%Get("Value") _ "") = (pBefore _ "") Quit
        }
        Set tPurge = ..PurgeCachedQueries()
        If $$$ISERR(tPurge) Set tSC = ..Fail(tMessage, tPurge, .pHttpStatus, .pFault)
    } Catch ex {
        Set tSC = ..Fail(tMessage, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p><method>PurgeAfterSet</method> as a copy-out script step (AD-59): the purge of the cached queries of every namespace for a
/// setting <var>pName</var> of <var>pEndpoint</var> that purges, else no step.</p>
ClassMethod PurgeSteps(pEndpoint As %String, pName As %String) As %DynamicArray
{
    If '..IsPurging(pEndpoint, pName) Quit []
    Quit [(##class(OcuPilot.Port.AdminPort).ObjectScriptStep($ListBuild("Set tSC = $SYSTEM.SQL.PurgeQueries({""allNamespace"": 1})")))]
}

/// <p>Purge the cached queries of every namespace, as the classic SQL page does after one of the settings it names changes. A
/// failed purge is the returned status. Overridable so a fixture can record the call or feed a failure; production never
/// overrides it.</p>
ClassMethod PurgeCachedQueries() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = $SYSTEM.SQL.PurgeQueries({"allNamespace": 1})
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Whether a change of the setting <var>pName</var> of <var>pEndpoint</var> reloads the current locale: the locale-format switch.</p>
ClassMethod IsReloading(pEndpoint As %String, pName As %String) As %Boolean [ Private ]
{
    Quit ..IsNls(pEndpoint) && (pName = ..#NLSFORMATNAME)
}

/// <p>The reload a set of the setting <var>pName</var> of <var>pEndpoint</var> owes once its write has read OK, run by the set tool's
/// <method>OcuPilot.Screen.Tool.NlsDefaultSet.AfterWrite</method> for both callers, so a reload that fails is the failure of an applied
/// write, which the agent's confirm still marks (AD-15). A setting that does not reload owes none. Otherwise, after the write gate, the
/// setting is read again and the current locale is reloaded in this request (<method>ReloadLocale</method>) when it no longer reads
/// <var>pBefore</var>, its value before the write; with <var>pKnown</var> 0, no value before the write being known, it is reloaded
/// whatever it reads. A re-read or a reload that fails is 500 <code>INTERNAL</code>, logged; the setting stays as written.</p>
ClassMethod ReloadAfterSet(pEndpoint As %String, pName As %String, pBefore As %String, pKnown As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    If '..IsReloading(pEndpoint, pName) Quit $$$OK
    Set tSC = ..Admit(pEndpoint, ..#TYPESET, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tMessage = "the current locale could not be reloaded after the setting " _ pName _ " changed"
    Try {
        If pKnown {
            Set tSC = ..Row(pEndpoint, pName, .tRow, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            Set pHttpStatus = 0
            If (tRow.%Get("Value") _ "") = (pBefore _ "") Quit
        }
        Set tReload = ..ReloadLocale()
        If $$$ISERR(tReload) Set tSC = ..Fail(tMessage, tReload, .pHttpStatus, .pFault)
    } Catch ex {
        Set tSC = ..Fail(tMessage, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p><method>ReloadAfterSet</method> as a copy-out script step (AD-59): the reload of the current locale for the setting <var>pName</var>
/// of <var>pEndpoint</var> that reloads, else no step.</p>
ClassMethod ReloadSteps(pEndpoint As %String, pName As %String) As %DynamicArray
{
    If '..IsReloading(pEndpoint, pName) Quit []
    Quit [(##class(OcuPilot.Port.AdminPort).ObjectScriptStep($ListBuild("Set tSC = ##class(Config.NLS.Locales).Reload()")))]
}

/// <p>Reload the current locale, as the classic locale page does after the locale-format switch changes, in <code>%SYS</code> by save and
/// restore. A failed reload is the returned status. Overridable so a fixture can record the call or feed a failure; production never
/// overrides it.</p>
ClassMethod ReloadLocale() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Config.NLS.Locales).Reload()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The vendor's <code>Modify</code> of <var>pClass</var> with every key its <code>Get</code> answers and the key
/// <var>pName</var> set to <var>pValue</var> (AD-4: the complete property set is re-sent, so no key falls back to a default).
/// A comment is not a setting and is not sent.</p>
ClassMethod VendorModify(pClass As %String, pName As %String, pValue As %String) As %Status [ Private ]
{
    Set tSC = ..ReadProperties(pClass, .tProps)
    If $$$ISERR(tSC) Quit tSC
    Set tProps(pName) = pValue
    Quit ..SendProperties(pClass, pName, .tProps)
}

/// <p>The vendor class <var>pClass</var>'s <code>Get</code> array without its comments, in <var>pProps</var>, read in
/// <code>%SYS</code> by save and restore: the class's own <code>Get</code>, or, when <var>pEntry</var> is given, its <code>Get</code> of that
/// named entry.</p>
ClassMethod ReadProperties(pClass As %String, Output pProps, pEntry As %String = "") As %Status [ Private ]
{
    Set tSC = $$$OK
    Kill pProps
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If pEntry = "" {
            Set tSC = $ClassMethod(pClass, "Get", .pProps)
        } Else {
            Set tSC = $ClassMethod(pClass, "Get", pEntry, .pProps)
        }
        If $$$ISERR(tSC) Quit
        Set tKey = ""
        For {
            Set tKey = $Order(pProps(tKey))
            If tKey = "" Quit
            Kill pProps(tKey, "Comment"), pProps(tKey, "Comments")
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The one call that changes the instance: the vendor's <code>Modify</code> of <var>pClass</var> with the complete
/// property set <var>pProps</var>, in which <var>pName</var> is the key this set changed, in <code>%SYS</code> by save and
/// restore. Overridable so a fixture can record the set or feed a vendor refusal without changing the instance; production
/// never overrides it.</p>
ClassMethod SendProperties(pClass As %String, pName As %String, ByRef pProps) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = $ClassMethod(pClass, "Modify", .pProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The vendor class <var>pClass</var>'s <code>Get</code> of the entry <var>pName</var> without its comments, in <var>pProps</var>, through
/// <method>ReadProperties</method>. Overridable so a fixture can hold an entry the instance does not; production never overrides it.</p>
ClassMethod ReadEntry(pClass As %String, pName As %String, Output pProps) As %Status [ Private ]
{
    Quit ..ReadProperties(pClass, .pProps, pName)
}

/// <p>The vendor's <code>Modify</code> of the entry <var>pName</var> of <var>pClass</var> with every key its <code>Get</code> answers and the
/// datatype set to <var>pValue</var> (AD-4).</p>
ClassMethod ModifyEntry(pClass As %String, pName As %String, pValue As %String) As %Status [ Private ]
{
    Set tSC = ..ReadEntry(pClass, pName, .tProps)
    If $$$ISERR(tSC) Quit tSC
    Set tProps(..#DATATYPEPROPERTY) = pValue
    Quit ..SendEntry(pClass, pName, .tProps)
}

/// <p>The vendor's <code>Modify</code> of the system-wide security record with the settable names of <parameter>SECURITYROSTER</parameter>
/// as <method>ReadEntry</method> answered them and <var>pName</var> set to <var>pValue</var> (AD-4). A name the roster does not mark
/// settable is an error status and nothing is sent; no other property of the record is sent.</p>
ClassMethod ModifySecurity(pName As %String, pValue As %String) As %Status [ Private ]
{
    Set tEntry = ..RosterEntry(..#SECURITYENDPOINT, pName)
    If (tEntry = "") || '$List(tEntry, 5) Quit $$$ERROR($$$GeneralError, "the security parameter " _ pName _ " is not one this port changes")
    Set tSC = ..ReadEntry(..#SECURITYCLASS, ..#SECURITYNAME, .tProps)
    If $$$ISERR(tSC) Quit tSC
    Set tRoster = ..RosterOf(..#SECURITYENDPOINT)
    For tI = 1:1:$ListLength(tRoster) {
        Set tKey = $List($List(tRoster, tI), 1)
        If '$List($List(tRoster, tI), 5) Continue
        If $Data(tProps(tKey))#2 Set tSend(tKey) = tProps(tKey)
    }
    Set tSend(pName) = pValue
    Quit ..SendEntry(..#SECURITYCLASS, ..#SECURITYNAME, .tSend)
}

/// <p>The one call that changes an existing entry: the vendor's <code>Modify</code> of the entry <var>pName</var> of <var>pClass</var> with
/// the complete property set <var>pProps</var>, in <code>%SYS</code> by save and restore. Overridable so a fixture can record the set or
/// feed a vendor refusal; production never overrides it.</p>
ClassMethod SendEntry(pClass As %String, pName As %String, ByRef pProps) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = $ClassMethod(pClass, "Modify", pName, .pProps)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The one call that creates an entry: the vendor's <code>Create</code> of <var>pName</var> on <var>pClass</var> with the properties
/// <var>pProps</var>, in <code>%SYS</code> by save and restore. Overridable like <method>SendEntry</method>; production never overrides it.</p>
ClassMethod CreateEntry(pClass As %String, pName As %String, ByRef pProps) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = $ClassMethod(pClass, "Create", pName, .pProps)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The one call that deletes an entry: the vendor's <code>Delete</code> of <var>pName</var> on <var>pClass</var>, in <code>%SYS</code> by
/// save and restore. Overridable like <method>SendEntry</method>; production never overrides it.</p>
ClassMethod DeleteEntry(pClass As %String, pName As %String) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = $ClassMethod(pClass, "Delete", pName)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The 403 the gate answers, <code>AUTH.NOPRIVILEGE</code> with the pair in <code>detail.failedPair</code> (AD-8,
/// AD-39).</p>
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

/// <p>The refusal <var>pCode</var> of <class>OcuPilot.Api.ConfigError</class>, on the status and slug that class names and
/// with its sentence. Nothing is logged: a refusal is an answer, not a fault.</p>
ClassMethod Refused(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..Refuse(##class(OcuPilot.Api.ConfigError).HttpStatusFor(pCode), ##class(OcuPilot.Api.ConfigError).SlugFor(pCode), pCode, ##class(OcuPilot.Api.ConfigError).ReasonFor(pCode), .pHttpStatus, .pFault)
}

/// <p>An unexpected failure: the generic internal fault on the wire, the raw status to the log.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ..LogFault(pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p><code>objectscript</code> for the write; <code>""</code> for every read, which has no script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If ..IsWrite(pType) && ..Serves(pEndpoint, pType) Quit "objectscript"
    Quit ""
}

/// <p>The write as a script (AD-59), in <code>%SYS</code>: for a class, its <code>Get</code>, the one key set, and
/// <code>Modify</code>, the same call the port makes (the purge a key that purges owes is the set tool's step,
/// <method>PurgeSteps</method>); for a roster endpoint, the one node set to the stored code with literal subscripts, or the TSQL setter; for the
/// NLS defaults, the locale-format node set with literal subscripts (the reload it owes is the set tool's step, <method>ReloadSteps</method>). The name and the value are string
/// literals, so nothing the query or the body carries runs as code. A roster name or an NLS name that is not settable renders no script.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tAdmin = "OcuPilot.Port.AdminPort"
    Set tName = $Get(pQuery(..#NAMEKEY))
    Set tValue = $Select($IsObject(pBody) && (pBody.%GetTypeOf("Value") = "string"): pBody.%Get("Value"), 1: "")
    If ..IsNamed(pEndpoint) Quit [($ClassMethod(tAdmin, "ObjectScriptStep", ..EntryLines(pEndpoint, pType, tName, tValue)))]
    If ..IsSecurity(pEndpoint) {
        Set tEntry = ..RosterEntry(pEndpoint, tName)
        If (tEntry = "") || '$List(tEntry, 5) Quit []
        Set tLines = $ListBuild("Set tProps(" _ $ClassMethod(tAdmin, "Literal", tName) _ ") = " _ $ClassMethod(tAdmin, "Literal", tValue))
        Set tLines = tLines _ $ListBuild("Set tSC = ##class(" _ ..#SECURITYCLASS _ ").Modify(" _ $ClassMethod(tAdmin, "Literal", ..#SECURITYNAME) _ ", .tProps)")
        Quit [($ClassMethod(tAdmin, "ObjectScriptStep", tLines))]
    }
    If ..IsNls(pEndpoint) {
        If tName '= ..#NLSFORMATNAME Quit []
        Quit [($ClassMethod(tAdmin, "ObjectScriptStep", $ListBuild("Set ^SYS(""NLS"", ""Config"", ""LocaleFormat"") = " _ $ClassMethod(tAdmin, "Literal", tValue))))]
    }
    If ..IsRoster(pEndpoint) {
        Set tEntry = ..RosterEntry(pEndpoint, tName)
        If (tEntry = "") || '$List(tEntry, 5) Quit []
        Set tLines = $ListBuild(..RosterLine(pEndpoint, tEntry, tValue))
        Quit [($ClassMethod(tAdmin, "ObjectScriptStep", tLines))]
    }
    Set tClass = ..VendorClass(pEndpoint)
    Set tLines = $ListBuild("Set tSC = ##class(" _ tClass _ ").Get(.tProps)")
    Set tLines = tLines _ $ListBuild("Set tProps(" _ $ClassMethod(tAdmin, "Literal", tName) _ ") = " _ $ClassMethod(tAdmin, "Literal", tValue))
    Set tLines = tLines _ $ListBuild("Set tSC = ##class(" _ tClass _ ").Modify(.tProps)")
    Quit [($ClassMethod(tAdmin, "ObjectScriptStep", tLines))]
}

/// <p>The lines of script for the write <var>pType</var> of the named entry <var>pName</var> of <var>pEndpoint</var> with the datatype
/// <var>pValue</var>, as a <class>%List</class>: <code>Get</code>, the key set and <code>Modify</code> for a set; for a create, the taken-name
/// refusal, the key set and <code>Create</code> gated on one line by <code>Exists</code>, the port's own taken-name rule (AD-59); and
/// <code>Delete</code> for a delete; each with the name and the datatype as string literals.</p>
ClassMethod EntryLines(pEndpoint As %String, pType As %String, pName As %String, pValue As %String) As %List [ Private ]
{
    Set tAdmin = "OcuPilot.Port.AdminPort"
    Set tClass = ..VendorClass(pEndpoint)
    Set tName = $ClassMethod(tAdmin, "Literal", pName)
    Set tSet = "Set tProps(" _ $ClassMethod(tAdmin, "Literal", ..#DATATYPEPROPERTY) _ ") = " _ $ClassMethod(tAdmin, "Literal", pValue)
    If pType = ..#TYPEDELETE Quit $ListBuild("Set tSC = ##class(" _ tClass _ ").Delete(" _ tName _ ")")
    If pType = ..#TYPECREATE {
        Set tTaken = "Set tSC = $System.Status.Error(5001, " _ $ClassMethod(tAdmin, "Literal", ##class(OcuPilot.Api.ConfigError).#REASONMAPPINGTAKEN) _ ")"
        Quit $ListBuild(tTaken, tSet, "If '##class(" _ tClass _ ").Exists(" _ tName _ ") Set tSC = ##class(" _ tClass _ ").Create(" _ tName _ ", .tProps)")
    }
    Quit $ListBuild("Set tSC = ##class(" _ tClass _ ").Get(" _ tName _ ", .tProps)", tSet, "Set tSC = ##class(" _ tClass _ ").Modify(" _ tName _ ", .tProps)")
}

/// <p>The line of script that sets the roster entry <var>pEntry</var> of <var>pEndpoint</var> to <var>pValue</var>.</p>
ClassMethod RosterLine(pEndpoint As %String, pEntry As %List, pValue As %String) As %String [ Private ]
{
    Set tAdmin = "OcuPilot.Port.AdminPort"
    Set tName = $List(pEntry, 1)
    If pEndpoint = ..#TSQLENDPOINT {
        Set tSetter = ..TsqlSetter(tName)
        If tSetter = "" Quit ""
        If tName = "DIALECT" Quit "Set tPrevious = ##class(%SYSTEM.TSQL)." _ tSetter _ "(" _ $ClassMethod(tAdmin, "Literal", pValue) _ ")"
        Set tDialect = ..StoredDialect()
        Quit "Set tPrevious = ##class(%SYSTEM.TSQL)." _ tSetter _ "(" _ $ClassMethod(tAdmin, "Literal", $Select(tDialect = "": ..#TSQLDEFAULTDIALECT, 1: tDialect)) _ ", " _ $ClassMethod(tAdmin, "Literal", pValue) _ ")"
    }
    Set tRoot = $Select(pEndpoint = ..#SHELLENDPOINT: """sql"", ""shell""", 1: """xsql"", ""informix""")
    Quit "Set ^%SYS(" _ tRoot _ ", " _ $ClassMethod(tAdmin, "Literal", tName) _ ") = " _ $ClassMethod(tAdmin, "Literal", ..StoredFor(pEntry, pValue))
}

}
