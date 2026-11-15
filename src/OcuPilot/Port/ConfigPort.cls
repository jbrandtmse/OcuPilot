/// <p>The configuration settings port (AD-4, AD-16, AD-29, AD-36, AD-52, AD-53, AD-58, AD-59, Story 21.3): the one
/// product class that lists the instance's startup settings (<code>Config.Startup</code>), memory settings
/// (<code>Config.config</code>) and compatibility settings (<code>Config.Miscellaneous</code>), and that sets one
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
/// <code>SET</code> (the write). A row is <code>{Name, Value, Kind, Accepts, Restart, ReadOnly}</code>: the class's own
/// <code>Get</code> array less <parameter>EXCLUDED</parameter> and a comment, with <code>Kind</code>,
/// <code>Accepts</code> and the limits <method>Limits</method> answers read from the compiled property at call time
/// (<code>RuntimeType</code>, <code>MINVAL</code>, <code>MAXVAL</code>, <code>VALUELIST</code>, <code>MAXLEN</code>).</p>
/// <p><b>A set is a merge that sends the complete property set</b> (AD-4): the class is read fresh, the one named key
/// takes its new value and every key the read answered is sent. Before any vendor call the row is read and
/// <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class>, the rules the tools' mint asks too, judge the value; a
/// setting this port shows and never changes (<method>IsReadOnly</method>) is refused. No path is set (AD-21).</p>
/// <p>Seams a test subclass overrides: <method>GateClass</method>, <method>LogFault</method> and
/// <method>SendProperties</method>. Production overrides none of them.</p>
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

/// <p>The class the pair sets are evaluated through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The endpoints a screen's read lists, in <code>LIST</code>.</p>
Parameter ENDPOINTS = "Startup,Memory,Compatibility";

Parameter STARTUPENDPOINT = "Startup";

Parameter MEMORYENDPOINT = "Memory";

Parameter COMPATIBILITYENDPOINT = "Compatibility";

/// <p>The vendor class each endpoint lists and sets.</p>
Parameter STARTUPCLASS = "Config.Startup";

Parameter MEMORYCLASS = "Config.config";

Parameter COMPATIBILITYCLASS = "Config.Miscellaneous";

Parameter TYPELIST = "LIST";

Parameter TYPEGET = "GET";

Parameter TYPESET = "SET";

/// <p>The write request types.</p>
Parameter WRITETYPES = "SET";

/// <p>The query keys: the setting named, and the rows a list is read for.</p>
Parameter NAMEKEY = "name";

Parameter MAXROWSKEY = "maxRows";

/// <p>The cap a list that names none is read under.</p>
Parameter DEFAULTMAXROWS As INTEGER = 1000;

/// <p>The settings no row lists, as the classic table leaves them out: platform facts, a value that is always 0,
/// the journal paths Journal settings shows, and the long-string switch.</p>
Parameter EXCLUDED = "EnableLongStrings,OsType,Platform,PageSizeAlt,ZaMode,globals2kb,pijdir,wijdir";

/// <p>The setting listed only on an interoperability instance.</p>
Parameter INTEROPONLY = "EnsembleAutoStart";

/// <p>The settings shown and never changed (AD-21): the path-valued strings, and the four network settings whose change
/// would cut OcuPilot off at the next restart, because the web gateway reaches the instance through the default
/// superserver and the private web server serves OcuPilot on this build. Every property of the vendor's path type
/// (<parameter>PATHTYPE</parameter>) is read only too.</p>
Parameter READONLY = "LibPath,Path,PythonPath,PythonRuntimeLibrary,DefaultPort,DefaultPortBindAddress,WebServer,WebServerPort";

Parameter PATHTYPE = "%Library.SysPath";

/// <p>The settings a vendor source states take effect only at the next restart, and the vendor's own source for each
/// memory setting is <code>Config.config.NoRestartOnActivate</code>.</p>
Parameter RESTARTSTARTUP = "WebServer,ErrorPurge,DefaultPort";

Parameter RESTARTCOMPATIBILITY = "NullSubscripts";

/// <p>The block sizes a <code>DBSizesAllowed</code> value lists, and the one it must hold.</p>
Parameter BLOCKSIZES = "4096,8192,16384,32768,65536";

Parameter BLOCKSIZEREQUIRED = 8192;

/// <p>The text length a setting whose property declares none is held to.</p>
Parameter DEFAULTMAXLEN As INTEGER = 255;

/// <p>The subsystem every log line of this port is written under.</p>
Parameter LOGSUBSYSTEM = "configport";

Parameter REASONNOTIMPLEMENTED = "This instance does not implement that operation.";

Parameter REASONMAXROWS = "maxRows must be a whole number above zero.";

Parameter REASONBODY = "a set takes the new value as text in Value.";

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

/// <p>Whether <var>pEndpoint</var> serves request type <var>pType</var>: every endpoint answers all three.</p>
ClassMethod Serves(pEndpoint As %String, pType As %String) As %Boolean
{
    If '$ListFind($ListFromString(..#ENDPOINTS), pEndpoint) Quit 0
    Quit (pType = ..#TYPELIST) || (pType = ..#TYPEGET) || (pType = ..#TYPESET)
}

/// <p>The vendor class <var>pEndpoint</var> lists and sets, or <code>""</code> for an endpoint this port does not
/// serve.</p>
ClassMethod VendorClass(pEndpoint As %String) As %String
{
    If pEndpoint = ..#STARTUPENDPOINT Quit ..#STARTUPCLASS
    If pEndpoint = ..#MEMORYENDPOINT Quit ..#MEMORYCLASS
    If pEndpoint = ..#COMPATIBILITYENDPOINT Quit ..#COMPATIBILITYCLASS
    Quit ""
}

/// <p>Serve <var>pEndpoint</var> for request type <var>pType</var>, after the gate.</p>
/// <p>A read answers <var>pResult</var> as an array of rows (<code>LIST</code>) or as one row (<code>GET</code>); a
/// <code>SET</code> answers <code>{Name, Value}</code>. A <code>LIST</code> and a <code>GET</code> take no body; a
/// <code>SET</code> takes the object whose <code>Value</code> is the new value as text.</p>
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
        If $IsObject(pBody) || (pBody '= "") {
            Set tSC = ..Fail(pEndpoint _ " " _ pType _ " was given a caller body, and it takes none", $$$ERROR($$$GeneralError, "a settings read takes no body"), .pHttpStatus, .pFault)
            Quit
        }
        If pType = ..#TYPEGET {
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
/// <parameter>COMPATIBILITYPAIRS</parameter> added for the <code>Compatibility</code> endpoint.</p>
ClassMethod Admit(pEndpoint As %String, pType As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tFailedPair = ""
    Set tSpec = $Select(..IsWrite(pType): ..#WRITEPAIRS, 1: ..#PAIRS)
    If pEndpoint = ..#COMPATIBILITYENDPOINT Set tSpec = tSpec _ "," _ ..#COMPATIBILITYPAIRS
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
        Set tClass = ..VendorClass(pEndpoint)
        If tClass = "" Quit
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
            Set tData(tKey) = $ListBuild(tProps(tKey), ..LimitsOf(tClass, tKey), ..IsReadOnly(tClass, tKey), ..NeedsRestart(pEndpoint, tClass, tKey))
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

/// <p>The row of the setting <var>pName</var> from <var>pData</var>, <code>$ListBuild(value, limits, readOnly,
/// restart)</code>.</p>
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
    Quit tRow
}

/// <p>The limits of the setting <var>pName</var> of <var>pEndpoint</var>, read at call time, as
/// <code>$ListBuild(kind, min, max, choices, maxLength, sentinel)</code>, or <code>""</code> when the class has no such
/// property. <code>kind</code> is <code>boolean</code>, <code>integer</code>, <code>choice</code>, <code>text</code> or
/// <code>blocksizes</code>; <code>choices</code> is a <code>$ListBuild</code> list; <code>sentinel</code> is the one value
/// outside the range that the setting also accepts, or <code>""</code>.</p>
/// <p>Beyond the dictionary: <code>DBSizesAllowed</code> is block sizes, <code>ListFormat</code> is 0 or 1,
/// <code>bbsiz</code> is -1 or 256 to 2147483647 and <code>routines</code> is 0 or 36 to 65536, as the classic Memory and
/// Startup page and value editor judge them; an integer with no declared minimum starts at 0, which is stricter than the
/// dictionary and what the vendor's own check holds the two settings that declare only a maximum to.</p>
ClassMethod Limits(pEndpoint As %String, pName As %String) As %List
{
    Set tLimits = ""
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

/// <p><method>Limits</method> for the vendor class <var>pClass</var>, in <code>%SYS</code>.</p>
ClassMethod LimitsOf(pClass As %String, pName As %String) As %List [ Private ]
{
    Set tProperty = ##class(%Dictionary.CompiledProperty).%OpenId(pClass _ "||" _ pName, 0)
    If '$IsObject(tProperty) Quit ""
    If pName = "DBSizesAllowed" Quit $ListBuild("blocksizes", "", "", "", "", "")
    If pName = "ListFormat" Quit $ListBuild("choice", "", "", $ListBuild(0, 1), "", "")
    If pName = "bbsiz" Quit $ListBuild("integer", 256, 2147483647, "", "", -1)
    If pName = "routines" Quit $ListBuild("integer", 36, 65536, "", "", 0)
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
    If tKind = "choice" Quit ##class(OcuPilot.Api.ConfigError).Accepting(##class(OcuPilot.Api.ConfigError).#ACCEPTSCHOICE, $ListToString($ListGet(pLimits, 4), ", "))
    If tKind = "text" Quit ##class(OcuPilot.Api.ConfigError).Accepting(##class(OcuPilot.Api.ConfigError).#ACCEPTSTEXT, $ListGet(pLimits, 5))
    If tKind = "integer" {
        If $ListGet(pLimits, 3) = "" Quit ##class(OcuPilot.Api.ConfigError).Accepting(##class(OcuPilot.Api.ConfigError).#ACCEPTSMINIMUM, $ListGet(pLimits, 2))
        Quit ##class(OcuPilot.Api.ConfigError).Accepting(##class(OcuPilot.Api.ConfigError).#ACCEPTSRANGE, $ListGet(pLimits, 2), $ListGet(pLimits, 3))
    }
    Quit ""
}

/// <p>Whether the setting <var>pName</var> of <var>pClass</var> is shown and never changed: one of
/// <parameter>READONLY</parameter>, or a property of the vendor's path type (<parameter>PATHTYPE</parameter>). In
/// <code>%SYS</code>.</p>
ClassMethod IsReadOnly(pClass As %String, pName As %String) As %Boolean [ Private ]
{
    If $ListFind($ListFromString(..#READONLY), pName) Quit 1
    Set tProperty = ##class(%Dictionary.CompiledProperty).%OpenId(pClass _ "||" _ pName, 0)
    Quit $IsObject(tProperty) && (tProperty.RuntimeType = ..#PATHTYPE)
}

/// <p>Whether a change of the setting <var>pName</var> takes effect only at the next restart, by the vendor's own source
/// for each class: <code>Config.config.NoRestartOnActivate</code> for a memory setting, and the lists the vendor's
/// documentation and the classic pages state for the other two. A setting with no source reads false. In
/// <code>%SYS</code>.</p>
ClassMethod NeedsRestart(pEndpoint As %String, pClass As %String, pName As %String) As %Boolean [ Private ]
{
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
/// refuse a setting shown and never changed and a value it does not accept, and then the class is read fresh and sent
/// whole with that one key changed (<method>VendorModify</method>). Answers <code>{Name, Value}</code>.</p>
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
    Set tVendor = ..VendorModify(..VendorClass(pEndpoint), tName, tValue)
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
/// <code>%SYS</code> by save and restore.</p>
ClassMethod ReadProperties(pClass As %String, Output pProps) As %Status [ Private ]
{
    Set tSC = $$$OK
    Kill pProps
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = $ClassMethod(pClass, "Get", .pProps)
        If $$$ISERR(tSC) Quit
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

/// <p>The write as a script (AD-59), in <code>%SYS</code>: the class's <code>Get</code>, the one key set, and
/// <code>Modify</code>, the same call the port makes. The name and the value are string literals, so nothing the query or
/// the body carries runs as code.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tAdmin = "OcuPilot.Port.AdminPort"
    Set tClass = ..VendorClass(pEndpoint)
    Set tValue = $Select($IsObject(pBody) && (pBody.%GetTypeOf("Value") = "string"): pBody.%Get("Value"), 1: "")
    Set tLines = $ListBuild("Set tSC = ##class(" _ tClass _ ").Get(.tProps)")
    Set tLines = tLines _ $ListBuild("Set tProps(" _ $ClassMethod(tAdmin, "Literal", $Get(pQuery(..#NAMEKEY))) _ ") = " _ $ClassMethod(tAdmin, "Literal", tValue))
    Set tLines = tLines _ $ListBuild("Set tSC = ##class(" _ tClass _ ").Modify(.tProps)")
    Quit [($ClassMethod(tAdmin, "ObjectScriptStep", tLines))]
}

}
