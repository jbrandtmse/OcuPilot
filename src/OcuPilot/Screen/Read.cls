/// <p>The one executor of a descriptor-declared read (AD-36). A screen's list and its read tool
/// both resolve through <method>Execute</method>, so they cannot differ in field set, and both
/// narrow its rows through <method>ApplyView</method>, so they cannot differ in filter or sort.</p>
/// <p><b>Every read is bounded.</b> <method>Execute</method> asks the port for one row more than
/// the cap: the vendor class query stops at <code>maxRows</code> and signals nothing, so the extra
/// row is the only truncation signal that costs no second query. The answer carries at most
/// <code>maxRows</code> rows and <code>truncated</code> true exactly when more came back.</p>
/// <p><b>A read may name one per-row detail call</b> (<code>source.rowGet</code>, AD-36), issued
/// only for the rows that survive the cap. Its declared detail fields are merged into each row and
/// its derived fields are computed here, on the instance clock, so a screen and a tool see the same
/// value.</p>
/// <p><b>A read may declare server-search <code>criteria</code></b> (AD-21), for the one Release 1
/// list whose API searches on the server. <method>CriteriaParams</method> is the allow-list the
/// route and the read tool are both filtered through, so neither can send a parameter the
/// descriptor does not name; and a criterion's value is checked against its declared kind here,
/// before the port is called -- a <code>choice</code> against its options, a <code>datetime</code>
/// against the one form the instance reads.</p>
/// <p><b>A descriptor may also declare a <code>banner</code></b>: a second port read whose value
/// raises a strip above the table (<method>BannerKey</method>). It rides in this read's own
/// response, so an auto-refresh tick re-evaluates it and the strip is gone the moment the condition
/// clears; and it is chrome rather than rows, so it never reaches the read tool's payload.</p>
/// <p><b>One view rule, two implementations.</b> <method>ApplyView</method> is mirrored by
/// <file>ui/src/app/core/screen-read.ts</file>'s <code>applyView</code>, because the screen sorts
/// and filters on the client and a tool runs in-process on the server; both are pinned by the one
/// corpus in <class>OcuPilot.Test.ReadViewCorpus</class>.</p>
/// <p><b>A declared read names one of two source kinds</b> (AD-36). <code>port: "admin"</code> is
/// an instance endpoint reached through <method>PortClass</method>; <code>port: "state"</code> is
/// OcuPilot's own protected state (AD-9), resolved against a kernel store's guarded list through
/// <method>StateRows</method>. The second changes where the rows come from and nothing else: the
/// same declared <code>fields</code>, the same secret strip, the same filter, sort and view rule,
/// the same row cap and the same <code>truncated</code> signal, so a screen over OcuPilot's own
/// configuration is a declared read like any other rather than a page with a query of its own.</p>
/// <p>The port is reached through <method>PortClass</method> alone (AD-2, AD-27); a tool never
/// touches <code>%session</code>, <code>%request</code> or <code>$NAMESPACE</code>, and neither
/// does this.</p>
Class OcuPilot.Screen.Read Extends %RegisteredObject
{

/// <p>The cap a read is bounded by when its caller names none.</p>
Parameter DEFAULTMAXROWS As INTEGER = 1000;

/// <p>The one request type a Release 1 read issues.</p>
Parameter READTYPE = "LIST";

/// <p>The request type a declared <code>rowGet</code> issues once per surviving row.</p>
Parameter DETAILTYPE = "GET";

/// <p>The ASCII capitals the view rule lower-cases, and nothing else.</p>
Parameter UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

/// <p>What <parameter>UPPER</parameter> lower-cases to.</p>
Parameter LOWER = "abcdefghijklmnopqrstuvwxyz";

/// <p>The one form a <code>datetime</code> criterion's value may take: the instance's own local
/// <code>YYYY-MM-DD HH:MM:SS</code>, optionally with a fractional second.</p>
/// <p>The time part is required rather than defaulted. The instance reads a date alone as midnight,
/// and an end bound at midnight is rolled back by the vendor to the previous day at 86399.999
/// (<code>Audit.cls:1812</code>), so a bare end date silently drops the whole of the day it names.
/// Refusing it by name is what turns that into an answer the caller can act on (DW-280).</p>
Parameter DATETIMEFORM = "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?$";

/// <p>The port class every <b>admin</b> read is issued through. Overridable so a fixture can reach
/// <class>OcuPilot.Test.PortFixture</class>; production never overrides it.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

/// <p>The <code>read.source.port</code> value naming an instance endpoint reached through a port
/// (AD-2).</p>
Parameter SOURCEADMIN = "admin";

/// <p>The <code>read.source.port</code> value naming OcuPilot's own protected state (AD-9,
/// AD-36).</p>
Parameter SOURCESTATE = "state";

/// <p>The package a <code>state</code> source's <code>endpoint</code> names a class in, trailing
/// dot included. A source declares the class's short name -- <code>Agent</code> -- and never a
/// package-qualified one, so no descriptor can point the read at a class outside the kernel's own
/// stores.</p>
Parameter STATEPACKAGE = "OcuPilot.Kernel.State.";

/// <p>The method a kernel store answers a declared read's rows with.</p>
Parameter STATEROWSMETHOD = "GuardedScreenRows";

/// <p>The class a <code>state</code> source's <var>pEndpoint</var> resolves to.</p>
/// <p>Composed here rather than declared, so a descriptor names a store rather than a class and
/// the set of reachable classes is exactly <parameter>STATEPACKAGE</parameter>'s.
/// <method>OcuPilot.Screen.Registry.ReadProblem</method> refuses an endpoint that names a package
/// at all; a name that resolves to no compiled class is refused at read time by
/// <method>StateRows</method>, because whether a class exists is a property of the instance rather
/// than of the declaration, and the registry rule is the one both engines run.</p>
ClassMethod StateClass(pEndpoint As %String) As %String
{
    Quit ..#STATEPACKAGE _ pEndpoint
}

/// <p>What is wrong with <var>pMaxRows</var>, or <code>""</code>. Absent (<code>""</code>) is
/// sound and means <parameter>DEFAULTMAXROWS</parameter>; anything else must be a whole number
/// above zero, written without sign, fraction or leading zero.</p>
ClassMethod MaxRowsProblem(pMaxRows As %String) As %String
{
    If pMaxRows = "" Quit ""
    If $Match(pMaxRows, "^[1-9][0-9]*$") Quit ""
    Quit "maxRows must be a whole number above zero"
}

/// <p>Run <var>pDescriptor</var>'s declared read, bounded by <var>pMaxRows</var>.</p>
/// <p>On success <var>pResult</var> is <code>{fields, rows, truncated, banner}</code>:
/// <code>fields</code>
/// the declared field names without the descriptor's <code>context.secretFields</code>, each row an
/// object carrying exactly those keys (an absent key is <code>null</code>), and at most the cap's
/// rows. A secret field's value is dropped here, so neither the screen route nor the read tool can
/// return it (Conventions, Secrets). <code>banner</code> is <method>BannerKey</method>'s answer --
/// screen chrome the table renders a strip from, evaluated after the rows and <code>""</code> for
/// every screen that declares none. <var>pHttpStatus</var> is 200.</p>
/// <p>When the read declares <code>source.rowGet</code>, each surviving row's detail is read with
/// one <code>GET</code> carrying <code>param</code> set to that row's <code>key</code> value. Its
/// <code>fields</code> replace the row's with their JSON types, and each <code>derived</code> field
/// is set from its rule (<method>Derive</method>). A row whose <code>GET</code> answers 404 was
/// deleted between the calls and is dropped; <code>truncated</code> still follows the list. Any
/// other detail fault fails the whole read with that fault and no rows, and a row with no string
/// key, a detail that is not an object or a value its rule cannot read is a 500.</p>
/// <p><var>pCriteria</var> supplies the read's declared server-search parameters (AD-21), keyed by
/// the descriptor's own <code>read.criteria</code> parameter names. Only a declared name is read --
/// the roster is the allow-list, so a key nothing declares reaches no port -- and an empty value is
/// omitted from the query, which leaves the vendor's own default standing. A supplied value is
/// checked against its criterion's declared kind <b>before the port is called</b> -- a
/// <code>choice</code> against its <code>options</code>, a <code>datetime</code> against
/// <parameter>DATETIMEFORM</parameter> -- and anything else is 400 with
/// <code>READ.CRITERION</code>, no request issued. Those two refusals are what keep the vendor's
/// own silent conversions unreachable: an unknown authentication name answers <code>-1</code> and
/// matches nearly every row rather than none, and a date with no time part is read as midnight and
/// rolls an end bound back a day (DW-280).</p>
/// <p>A bad cap is refused before the port is called: 400 with <code>READ.MAXROWS</code>. A port
/// failure passes through unchanged -- its status, its HTTP status and its
/// <code>{error, reason, code}</code> fault. A descriptor with no read, or an answer that is not a
/// list, is a 500 with the internal fault. <var>pFault</var> is set exactly when the status is an
/// error.</p>
ClassMethod Execute(pDescriptor As %String, pMaxRows As %String = "", Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, ByRef pCriteria) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tMaxProblem = ..MaxRowsProblem(pMaxRows)
        If tMaxProblem '= "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#READMAXROWS, tMaxProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tMax = $Select(pMaxRows = "": ..#DEFAULTMAXROWS, 1: +pMaxRows)

        Set tRead = $ClassMethod(pDescriptor, "Read")
        Set tSource = $Select($IsObject(tRead): tRead.%Get("source"), 1: "")
        If '$IsObject(tSource) || (tSource.%Get("type") '= ..#READTYPE) {
            Set tSC = ..Internal(pDescriptor _ " declares no read this executor can issue", .pHttpStatus, .pFault)
            Quit
        }

        If tSource.%Get("port") = ..#SOURCESTATE {
            ; AD-36's second source kind: the rows come from a kernel store's guarded list rather
            ; than from a port, and everything below this line is unchanged -- the same field
            ; projection, the same secret strip, the same cap and the same truncation signal.
            Set tStateSC = ..StateRows(pDescriptor, tSource.%Get("endpoint"), tMax + 1, .tAnswer, .pHttpStatus, .pFault)
            If $$$ISERR(tStateSC) {
                Set tSC = tStateSC
                Quit
            }
        } Else {
            Set tQuery("maxRows") = tMax + 1
            Set tCriterionProblem = ..SeedCriteria(tRead, .pCriteria, .tQuery)
            If tCriterionProblem '= "" {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#READCRITERION, tCriterionProblem, .pHttpStatus, .pFault)
                Quit
            }
            Set tPortSC = $ClassMethod(..PortClass(), "Invoke", tSource.%Get("endpoint"), ..#READTYPE, .tQuery, "", .tAnswer, .pHttpStatus, .pFault)
            If $$$ISERR(tPortSC) {
                Set tSC = tPortSC
                Quit
            }
        }
        If '$IsObject(tAnswer) || 'tAnswer.%IsA("%Library.DynamicArray") {
            Set tSC = ..Internal(pDescriptor _ "'s read answered something other than a list", .pHttpStatus, .pFault)
            Quit
        }

        Set tSecrets = $ClassMethod(pDescriptor, "ContextSecretFields")
        Set tFields = []
        Set tIterator = tRead.%Get("fields").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            If '$ListFind(tSecrets, tField) Do tFields.%Push(tField)
        }
        Set tRowGet = tSource.%Get("rowGet")
        Set tHasRowGet = $IsObject(tRowGet) && tRowGet.%IsA("%Library.DynamicObject")
        Set tRows = []
        Set tSurviving = 0
        Set tIterator = tAnswer.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tSurviving = tMax Quit
            Set tSurviving = tSurviving + 1
            If 'tHasRowGet {
                Do tRows.%Push(..Project(tRow, tFields))
                Continue
            }
            Set tSC = ..DetailRow(pDescriptor, tSource.%Get("endpoint"), tRowGet, tRow, tFields, .tOut, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            If $IsObject(tOut) Do tRows.%Push(tOut)
        }
        If $$$ISERR(tSC) Quit
        Set pResult = {}
        Do pResult.%Set("fields", tFields)
        Do pResult.%Set("rows", tRows)
        Do pResult.%Set("truncated", tAnswer.%Size() > tMax, "boolean")
        Do pResult.%Set("banner", ..BannerKey(pDescriptor))
        Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Internal("the read failed: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The rows a <code>state</code> source answers with (AD-9, AD-36): the kernel store
/// <var>pEndpoint</var> names, asked for at most <var>pMaxRows</var> rows of its guarded list as a
/// <class>%DynamicArray</class>.</p>
/// <p><b>Bounded at the query.</b> <method>Execute</method> passes its cap plus one, the store binds
/// it into <code>SELECT TOP ?</code>, and <method>Execute</method> keeps at most the cap's rows and
/// reports <code>truncated</code> when the extra row came back, exactly as it does for a port
/// answer.</p>
/// <p><b>The escalated frame is the store's and stops there</b> (AD-9): this method calls one
/// class method and touches no <code>$ROLES</code> of its own, and nothing inside that frame
/// reaches a port, a tool or the provider.</p>
/// <p>A store that cannot be resolved, or that answers something other than an array, is a 500
/// with the generic fault and the detail in the status alone.</p>
ClassMethod StateRows(pDescriptor As %String, pEndpoint As %String, pMaxRows As %Integer, Output pAnswer As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Try {
        Set tClass = ..StateClass(pEndpoint)
        If '##class(%Dictionary.CompiledClass).%ExistsId(tClass) {
            Set tSC = ..Internal(pDescriptor _ " declares a state read against " _ tClass _ ", which this instance does not hold", .pHttpStatus, .pFault)
            Quit
        }
        Set tRowsSC = $ClassMethod(tClass, ..#STATEROWSMETHOD, .pAnswer, pMaxRows)
        If $$$ISERR(tRowsSC) {
            Set pAnswer = ""
            Set tSC = ..Internal(pDescriptor _ "'s state read failed: " _ $System.Status.GetErrorText(tRowsSC), .pHttpStatus, .pFault)
            Quit
        }
    } Catch ex {
        Set pAnswer = ""
        Set tSC = ..Internal("the state read failed: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The query parameter names <var>pDescriptor</var>'s read declares as server-search criteria,
/// in declaration order, as a <class>%List</class>; empty for a read that declares none
/// (AD-21).</p>
/// <p><b>This is the allow-list, and it has exactly one reader per caller.</b>
/// <method>OcuPilot.Api.ScreenRead.Handle</method> walks it to decide which query keys of an
/// incoming request are read at all, and <method>OcuPilot.Screen.Tool.Read.InputSchema</method>
/// walks it to publish one property per criterion -- so the screen and the tool send the same
/// search and neither can send a parameter the descriptor does not name.</p>
ClassMethod CriteriaParams(pDescriptor As %String) As %List
{
    Set tParams = ""
    Try {
        Set tRead = $ClassMethod(pDescriptor, "Read")
        If '$IsObject(tRead) Quit
        Set tCriteria = tRead.%Get("criteria")
        If '$IsObject(tCriteria) || 'tCriteria.%IsA("%Library.DynamicObject") Quit
        Set tFields = tCriteria.%Get("fields")
        If '$IsObject(tFields) || 'tFields.%IsA("%Library.DynamicArray") Quit
        Set tIterator = tFields.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            If '$IsObject(tField) Continue
            Set tParam = tField.%Get("param")
            If tParam '= "" Set tParams = tParams _ $ListBuild(tParam)
        }
    } Catch {
        Set tParams = ""
    }
    Quit tParams
}

/// <p>Seed <var>pQuery</var> with every declared criterion <var>pSupplied</var> carries a non-empty
/// value for, and answer what is wrong with one of those values, or <code>""</code>.</p>
/// <p>An empty value is omitted rather than sent, so the vendor's own default stands for that
/// criterion. Every value is bounded by its criterion's declared <code>maxLength</code> first,
/// whatever the kind (DW-279); then a <code>choice</code> criterion's value must be one of its
/// declared <code>options</code> exactly, and a <code>datetime</code> one must carry its time part
/// (<parameter>DATETIMEFORM</parameter>); anything else is refused by name and nothing is sent.</p>
/// <p><b>The length is checked here and not at the port</b> because this is the last place that
/// knows which parameter the value belongs to. A value longer than the vendor property
/// (<code>Pids</code> is <code>MAXLEN</code> 50) faults inside
/// <class>OcuPilot.Port.AdminPort</class>, which answers a fault naming no parameter at all; the
/// refusal here is 400 <code>READ.CRITERION</code> naming the parameter and its bound, with no
/// request issued. Both callers cross this method, so neither the screen route nor the read tool
/// can reach the port with an over-long value.</p>
/// <p><b>Public and value-driven</b>, for the reason
/// <method>OcuPilot.Screen.Registry.RefreshProblem</method> is: the seeding and the refusal are
/// exercised as values -- a declared value, an empty one and an off-list one against the shipped
/// declaration -- rather than through three port round trips.</p>
ClassMethod SeedCriteria(pRead As %DynamicObject, ByRef pSupplied, ByRef pQuery) As %String
{
    Set tProblem = ""
    If '$IsObject(pRead) Quit tProblem
    Set tCriteria = pRead.%Get("criteria")
    If '$IsObject(tCriteria) || 'tCriteria.%IsA("%Library.DynamicObject") Quit tProblem
    Set tFields = tCriteria.%Get("fields")
    If '$IsObject(tFields) || 'tFields.%IsA("%Library.DynamicArray") Quit tProblem
    Kill tSeed
    Set tIterator = tFields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        If '$IsObject(tField) Continue
        Set tParam = tField.%Get("param")
        If tParam = "" Continue
        Set tValue = $Get(pSupplied(tParam))
        If tValue = "" Continue
        ; DW-279, and before the kind, because the bound binds every kind. The vendor property is
        ; what the value lands in -- `Pids` is MAXLEN 50 -- and a longer one faults inside the port,
        ; where nothing can still name which parameter was too long.
        Set tMaxLength = tField.%Get("maxLength")
        If (tMaxLength > 0) && ($Length(tValue) > tMaxLength) {
            Set tProblem = tParam _ " must be " _ tMaxLength _ " characters or fewer"
            Quit
        }
        Set tKind = tField.%Get("kind")
        If tKind = "choice" {
            If '..ArrayHas(tField.%Get("options"), tValue) {
                Set tProblem = tParam _ " must be one of the values this screen declares"
                Quit
            }
        } ElseIf tKind = "datetime" {
            If '$Match(tValue, ..#DATETIMEFORM) {
                Set tProblem = tParam _ " must be a date and time, as YYYY-MM-DD HH:MM:SS"
                Quit
            }
        }
        Set tSeed(tParam) = tValue
    }
    ; Nothing is seeded until every value has been read, so a refused criterion leaves the query
    ; exactly as it was and the port is never called with half a search.
    If tProblem '= "" Quit tProblem
    Set tParam = ""
    For {
        Set tParam = $Order(tSeed(tParam))
        If tParam = "" Quit
        Set pQuery(tParam) = tSeed(tParam)
    }
    Quit ""
}

/// <p><var>pDescriptor</var>'s declared banner resolved against the instance: the
/// <code>messageKey</code> of the <b>first</b> declared case whose <code>equals</code> the banner's
/// source answers for <code>field</code>, and <code>""</code> when no case matches.
/// <code>""</code> for a descriptor that declares no banner.</p>
/// <p><b>One port call, whatever the number of cases</b> (DW-270). The field is read once and
/// compared against each case in declaration order, so a screen whose field has three states costs
/// the same read as one with a single state. The registry refuses a repeated <code>equals</code>,
/// which is what keeps "the first that matches" from hiding a case.</p>
/// <p><b>Every fault suppresses the banner and none fails the read</b> -- the opposite of the
/// <code>rowGet</code> fault rule above, deliberately. A banner is chrome over the rows: a strip
/// that cannot be resolved is one the user does not see, while a list that will not load because a
/// second endpoint refused is a screen the user cannot use. So a port failure, a non-2xx, an answer
/// that is not an object and an exception all answer <code>""</code>, and the rows list either way.
/// The declaration's own shape is refused at install instead
/// (<method>OcuPilot.Screen.Registry.BannerProblem</method>), which is what keeps that silence from
/// hiding a misdeclared banner.</p>
ClassMethod BannerKey(pDescriptor As %String) As %String [ Private ]
{
    Set tKey = ""
    Try {
        Set tBanner = $ClassMethod(pDescriptor, "Banner")
        If '$IsObject(tBanner) Quit
        Set tSource = tBanner.%Get("source")
        If '$IsObject(tSource) Quit
        Kill tQuery
        Set tPortSC = $ClassMethod(..PortClass(), "Invoke", tSource.%Get("endpoint"), tSource.%Get("type"), .tQuery, "", .tAnswer, .tHttp, .tFault)
        If $$$ISERR(tPortSC) Quit
        If '$IsObject(tAnswer) || 'tAnswer.%IsA("%Library.DynamicObject") Quit
        Set tValue = tAnswer.%Get(tBanner.%Get("field"))
        Set tCases = tBanner.%Get("cases")
        If '$IsObject(tCases) || 'tCases.%IsA("%Library.DynamicArray") Quit
        Set tIterator = tCases.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tCase) {
            If '$IsObject(tCase) Continue
            If tCase.%Get("equals") '= tValue Continue
            Set tKey = tCase.%Get("messageKey")
            Quit
        }
    } Catch {
        Set tKey = ""
    }
    Quit tKey
}

/// <p>One surviving list row with its detail merged, as <var>pOut</var>, or <var>pOut</var>
/// <code>""</code> when the row's <code>GET</code> answered 404. An error status carries the
/// detail call's fault, or the internal fault, in <var>pHttpStatus</var> and <var>pFault</var>,
/// which are left alone otherwise.</p>
ClassMethod DetailRow(pDescriptor As %String, pEndpoint As %String, pRowGet As %DynamicObject, pRow As %DynamicObject, pFields As %DynamicArray, Output pOut As %DynamicObject, ByRef pHttpStatus As %Integer, ByRef pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pOut = ""
    Try {
        Set tKeyField = pRowGet.%Get("key")
        If ('$IsObject(pRow)) || ('pRow.%IsA("%Library.DynamicObject")) || (pRow.%GetTypeOf(tKeyField) '= "string") || (pRow.%Get(tKeyField) = "") {
            Set tSC = ..Internal(pDescriptor _ "'s list row carries no string " _ tKeyField _ " to read its detail by", .pHttpStatus, .pFault)
            Quit
        }
        Set tQuery(pRowGet.%Get("param")) = pRow.%Get(tKeyField)
        Set tDetail = ""
        Set tPortSC = $ClassMethod(..PortClass(), "Invoke", pEndpoint, ..#DETAILTYPE, .tQuery, "", .tDetail, .tHttp, .tFault)
        If $$$ISERR(tPortSC) {
            If tHttp = 404 Quit
            Set pHttpStatus = tHttp
            Set pFault = tFault
            Set tSC = tPortSC
            Quit
        }
        If '$IsObject(tDetail) || 'tDetail.%IsA("%Library.DynamicObject") {
            Set tSC = ..Internal(pDescriptor _ "'s detail call answered something other than an object", .pHttpStatus, .pFault)
            Quit
        }

        Kill tDerived
        Set tEntries = pRowGet.%Get("derived").%GetIterator()
        While tEntries.%GetNext(.tIndex, .tEntry) {
            Set tValue = ..Derive(tEntry.%Get("rule"), tDetail, tEntry.%Get("from"), .tReadable)
            If 'tReadable {
                Set tSC = ..Internal(pDescriptor _ "'s derived field " _ tEntry.%Get("field") _ " cannot be read from " _ tEntry.%Get("from"), .pHttpStatus, .pFault)
                Quit
            }
            Set tDerived(tEntry.%Get("field")) = tValue
        }
        If $$$ISERR(tSC) Quit

        Set tDetailFields = ""
        Set tNames = pRowGet.%Get("fields").%GetIterator()
        While tNames.%GetNext(.tIndex, .tName) {
            Set tDetailFields = tDetailFields _ $ListBuild(tName)
        }
        Set tOut = {}
        Set tIterator = pFields.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            If $Data(tDerived(tField)) {
                Do tOut.%Set(tField, tDerived(tField), "boolean")
            } ElseIf $ListFind(tDetailFields, tField) {
                Do ..CopyValue(tDetail, tField, tOut)
            } Else {
                Do ..CopyValue(pRow, tField, tOut)
            }
        }
        Set pOut = tOut
    } Catch ex {
        Set pOut = ""
        Set tSC = ..Internal("the detail call failed: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The value derived rule <var>pRule</var> computes from <var>pDetail</var>'s
/// <var>pFrom</var>, with <var>pReadable</var> 0 when the value is not one the rule reads.</p>
/// <p><code>beforeToday</code> is true exactly when the value is a <code>YYYY-MM-DD</code> date
/// earlier than <code>+$Horolog</code>, the instance's own date, and false for <code>""</code>, a
/// <code>null</code> or an absent key.</p>
ClassMethod Derive(pRule As %String, pDetail As %DynamicObject, pFrom As %String, Output pReadable As %Boolean) As %Boolean
{
    Set pReadable = 0
    If pRule '= "beforeToday" Quit 0
    Set tType = pDetail.%GetTypeOf(pFrom)
    If (tType = "unassigned") || (tType = "null") {
        Set pReadable = 1
        Quit 0
    }
    If tType '= "string" Quit 0
    Set tValue = pDetail.%Get(pFrom)
    If tValue = "" {
        Set pReadable = 1
        Quit 0
    }
    If '$Match(tValue, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$") Quit 0
    Set tDate = $ZDateH(tValue, 3, , , , , , , -1)
    If tDate = -1 Quit 0
    Set pReadable = 1
    Quit tDate < (+$Horolog)
}

/// <p><var>pRow</var> projected to <var>pFields</var>: a new object with exactly those keys, in
/// that order, each value copied with its JSON type and an absent one <code>null</code>.</p>
ClassMethod Project(pRow As %DynamicObject, pFields As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Set tIterator = pFields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Do ..CopyValue(pRow, tField, tOut)
    }
    Quit tOut
}

/// <p>Copy <var>pKey</var> from <var>pFrom</var> to <var>pTo</var> keeping its JSON type;
/// <code>null</code> when <var>pFrom</var> is not an object or does not carry the key.</p>
ClassMethod CopyValue(pFrom As %DynamicObject, pKey As %String, pTo As %DynamicObject) [ Private ]
{
    Set tType = "unassigned"
    If $IsObject(pFrom) && pFrom.%IsA("%Library.DynamicObject") Set tType = pFrom.%GetTypeOf(pKey)
    If (tType = "unassigned") || (tType = "null") {
        Do pTo.%Set(pKey, "", "null")
    } ElseIf (tType = "string") || (tType = "number") || (tType = "boolean") {
        Do pTo.%Set(pKey, pFrom.%Get(pKey), tType)
    } Else {
        Do pTo.%Set(pKey, pFrom.%Get(pKey))
    }
}

/// <p>The view rule (AD-36): <var>pRows</var> filtered by <var>pFilter</var> and sorted by
/// <var>pSort</var> in <var>pDirection</var>, as a new array holding the same row objects.</p>
/// <p><b>Filter.</b> An empty filter keeps every row. Otherwise a row stays when the text of any
/// field <var>pRead</var>'s <code>filter</code> names contains the filter text, both with only the
/// ASCII capitals lower-cased. A string's text is itself, a number's its JSON text, a boolean's
/// <code>true</code> or <code>false</code>, an array's its members' texts by the same rule joined by
/// <code>, </code>, and <code>null</code>, an absent key or an object is empty.</p>
/// <p><b>Sort.</b> Stable, on one member of <code>sort.fields</code>, in one direction; a
/// <var>pSort</var> that is not a member, or a <var>pDirection</var> that is neither
/// <code>asc</code> nor <code>desc</code>, takes the declared <code>default</code> and
/// <code>direction</code>. Two numbers compare numerically, anything else by text in code-unit
/// order, and <code>null</code> sorts last in either direction. That comparison is not transitive
/// over a column mixing numbers with numeric-looking text, so the order depends on which pairs are
/// compared: the client's <code>applyView</code> runs this same bottom-up merge rather than its
/// engine's sort.</p>
ClassMethod ApplyView(pRows As %DynamicArray, pRead As %DynamicObject, pFilter As %String = "", pSort As %String = "", pDirection As %String = "") As %DynamicArray
{
    Set tNeedle = $Translate(pFilter, ..#UPPER, ..#LOWER)
    Set tFilterFields = pRead.%Get("filter")
    Set tSortDecl = pRead.%Get("sort")
    If '$IsObject(tSortDecl) Set tSortDecl = {}
    Set tKey = tSortDecl.%Get("default")
    If (pSort '= "") && ..ArrayHas(tSortDecl.%Get("fields"), pSort) Set tKey = pSort
    Set tDescending = (tSortDecl.%Get("direction") = "desc")
    If pDirection = "asc" Set tDescending = 0
    If pDirection = "desc" Set tDescending = 1

    ; Keep the filtered rows, and each one's sort key: type (0 null, 1 number, 2 text), value, and
    ; the view rule's text, which is what a number compares by against anything but a number.
    Set tCount = 0
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tNeedle '= "") && '..Matches(tRow, tFilterFields, tNeedle) Continue
        Set tCount = tCount + 1
        Set tKept(tCount) = tRow
        Set tText(tCount) = ..TextOf(tRow, tKey)
        Set tType = ..TypeOf(tRow, tKey)
        If tType = "null" {
            Set tKind(tCount) = 0
            Set tValue(tCount) = ""
        } ElseIf tType = "number" {
            Set tKind(tCount) = 1
            Set tValue(tCount) = tRow.%Get(tKey)
        } Else {
            Set tKind(tCount) = 2
            Set tValue(tCount) = ..TextOf(tRow, tKey)
        }
    }

    ; Bottom-up merge sort over positions, which is stable: a tie keeps the left run's row.
    For tI = 1:1:tCount Set tOrder(tI) = tI
    Set tWidth = 1
    While tWidth < tCount {
        Set tLeft = 1
        While tLeft <= tCount {
            Set tMid = tLeft + tWidth - 1
            Set tRight = tLeft + (2 * tWidth) - 1
            If tRight > tCount Set tRight = tCount
            If tMid < tRight {
                Set tA = tLeft, tB = tMid + 1, tK = tLeft
                While (tA <= tMid) || (tB <= tRight) {
                    If tB > tRight {
                        Set tNext = tOrder(tA), tA = tA + 1
                    } ElseIf tA > tMid {
                        Set tNext = tOrder(tB), tB = tB + 1
                    } ElseIf ..Compare(tKind(tOrder(tB)), tValue(tOrder(tB)), tText(tOrder(tB)), tKind(tOrder(tA)), tValue(tOrder(tA)), tText(tOrder(tA)), tDescending) < 0 {
                        Set tNext = tOrder(tB), tB = tB + 1
                    } Else {
                        Set tNext = tOrder(tA), tA = tA + 1
                    }
                    Set tMerged(tK) = tNext
                    Set tK = tK + 1
                }
                For tI = tLeft:1:tRight Set tOrder(tI) = tMerged(tI)
            }
            Set tLeft = tLeft + (2 * tWidth)
        }
        Set tWidth = tWidth * 2
    }

    Set tOut = []
    For tI = 1:1:tCount Do tOut.%Push(tKept(tOrder(tI)))
    Quit tOut
}

/// <p>Negative when the first key sorts before the second, positive when after, 0 on a tie.
/// <var>pKindA</var> and <var>pKindB</var> are 0 for null, 1 for a number, 2 for text;
/// <var>pTextA</var> and <var>pTextB</var> are each key's <method>TextOf</method> text.</p>
ClassMethod Compare(pKindA As %Integer, pValueA As %String, pTextA As %String, pKindB As %Integer, pValueB As %String, pTextB As %String, pDescending As %Boolean) As %Integer [ Private ]
{
    If (pKindA = 0) && (pKindB = 0) Quit 0
    If pKindA = 0 Quit 1
    If pKindB = 0 Quit -1
    Set tOrder = 0
    If (pKindA = 1) && (pKindB = 1) {
        Set tOrder = $Select(pValueA < pValueB: -1, pValueA > pValueB: 1, 1: 0)
    } Else {
        Set tOrder = $Select(pTextA = pTextB: 0, pTextB ] pTextA: -1, 1: 1)
    }
    Quit $Select(pDescending: -tOrder, 1: tOrder)
}

/// <p>Whether any of <var>pFields</var>' texts on <var>pRow</var>, lower-cased, contains
/// <var>pNeedle</var>.</p>
ClassMethod Matches(pRow As %DynamicObject, pFields As %DynamicArray, pNeedle As %String) As %Boolean [ Private ]
{
    Set tFound = 0
    If '$IsObject(pFields) Quit 0
    Set tIterator = pFields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        If $Translate(..TextOf(pRow, tField), ..#UPPER, ..#LOWER) [ pNeedle {
            Set tFound = 1
            Quit
        }
    }
    Quit tFound
}

/// <p>The JSON type of <var>pKey</var> on <var>pRow</var>, <code>null</code> when the row is not
/// an object or does not carry it.</p>
ClassMethod TypeOf(pRow As %DynamicObject, pKey As %String) As %String [ Private ]
{
    If '$IsObject(pRow) || 'pRow.%IsA("%Library.DynamicObject") Quit "null"
    Set tType = pRow.%GetTypeOf(pKey)
    If tType = "unassigned" Quit "null"
    Quit tType
}

/// <p>The view rule's text of <var>pKey</var> on <var>pRow</var>.</p>
ClassMethod TextOf(pRow As %DynamicObject, pKey As %String) As %String
{
    Set tType = ..TypeOf(pRow, pKey)
    If tType = "null" Quit ""
    Quit ..ValueText(pRow.%Get(pKey), tType)
}

/// <p>The view rule's text of <var>pValue</var>, whose JSON type is <var>pType</var>: a string is
/// itself, a number its JSON text, a boolean <code>true</code> or <code>false</code>, an array its
/// members' texts joined by <code>, </code>, and anything else empty.</p>
ClassMethod ValueText(pValue As %RawString, pType As %String) As %String [ Private ]
{
    If pType = "string" Quit pValue
    If pType = "boolean" Quit $Select(pValue: "true", 1: "false")
    If pType = "number" {
        Set tHolder = []
        Do tHolder.%Push(pValue, "number")
        Set tJson = tHolder.%ToJSON()
        Quit $Extract(tJson, 2, *-1)
    }
    If pType = "array" {
        Set tText = ""
        Set tIterator = pValue.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tMember, .tMemberType) {
            Set tText = tText _ $Select(tIndex = 0: "", 1: ", ") _ ..ValueText(tMember, tMemberType)
        }
        Quit tText
    }
    Quit ""
}

/// <p>Whether <var>pArray</var> holds the string <var>pValue</var>.</p>
ClassMethod ArrayHas(pArray As %DynamicArray, pValue As %String) As %Boolean [ Private ]
{
    Set tFound = 0
    If '$IsObject(pArray) Quit 0
    Set tIterator = pArray.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If tEntry = pValue {
            Set tFound = 1
            Quit
        }
    }
    Quit tFound
}

/// <p>A refusal this executor decided, with no port behind it.</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>An internal failure: the generic fault on the wire, the detail in the status alone.</p>
ClassMethod Internal(pDetail As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Quit $$$ERROR($$$GeneralError, pDetail)
}

}
