/// <p>The SQL console's port (AD-61's named case, Story 19.6): one caller statement, prepared whole
/// with <code>%SQL.Statement.%Prepare(text, 1)</code> -- SQL privilege checks on -- in the target
/// namespace, in the request's own process, as the signed-in user, and run there with its values
/// bound positionally. It names no class of the source code API and calls no other port's
/// <code>Invoke</code>: it reuses only <class>OcuPilot.Port.AtelierPort</class>'s pair set.</p>
/// <p><b>The order of every call is fixed.</b> The gate first, in the caller's process
/// (<method>Gate</method>: <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, then READ on the
/// namespace's code databases, through <code>EvaluateRequired</code>); then the bounds
/// (<method>InputProblem</method>); then the password refusal, before any prepare
/// (<parameter>PASSWORDPATTERN</parameter>); then the prepare, whose statement type decides the kind
/// through the closed table <method>KindOf</method>; then the refusal of the session, administration
/// and server-file kinds; then, for a DDL statement, the system privilege its type requires
/// (<parameter>DDLPRIVILEGES</parameter>), asked of the instance. Nothing is prepared before the gate,
/// the bounds and the password check have answered.</p>
/// <p><b>The namespace is switched by explicit save and restore</b> (AD-16) around a region that calls
/// only vendor classes (<method>Prepared</method>, <method>Executed</method>,
/// <method>Explained</method>, <method>HoldsPrivilege</method>, <method>Closed</method>), and the
/// restore is the first line of each <code>Catch</code>. The caller's statement is released before
/// the namespace is restored (<method>Closed</method>).</p>
/// <p><b>A statement's text, values, rows, SQL error text and plan reach the caller's answer and
/// nothing else</b> (AD-39's sixth exception): no log line here carries any of them. A prepare or
/// execute error is the <code>error</code> outcome, never a fault.</p>
/// <p>Seams a fixture subclass overrides: <method>GateClass</method> and
/// <method>BoundSeconds</method>. Production overrides neither.</p>
Class OcuPilot.Port.SqlPort Extends %RegisteredObject
{

/// <p>The one endpoint this port serves.</p>
Parameter ENDPOINTSQL = "Sql";

/// <p>The fresh read of a console run: <method>Classify</method>'s guard with the run's three
/// declared values answered <code>null</code> beside it.</p>
Parameter TYPEGUARD = "GUARD";

/// <p>The confirmed run of a statement that changes something (<method>Run</method>).</p>
Parameter TYPERUN = "RUN";

/// <p>The write this port composes from the caller's declared values, as <code>endpoint/type</code>
/// (AD-51): the run, from its statement, values and Max rows.</p>
Parameter COMPOSEDTYPES = "Sql/RUN";

/// <p>The query keys: the namespace, the target id (always <parameter>IDVALUE</parameter>), the
/// statement, its values as JSON array text, and the row cap.</p>
Parameter NAMESPACEKEY = "namespace";

Parameter IDKEY = "id";

Parameter IDVALUE = "sql";

Parameter STATEMENTKEY = "statement";

Parameter PARAMETERSKEY = "parameters";

Parameter MAXROWSKEY = "maxRows";

/// <p>The class the gate evaluates through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The bounds a request is held to before anything is prepared.</p>
Parameter MAXSTATEMENT As INTEGER = 100000;

Parameter MAXVALUES As INTEGER = 100;

Parameter MAXVALUE As INTEGER = 32767;

Parameter MAXROWS As INTEGER = 1000;

/// <p>The bounds an answer is held to: a cell, and the whole answer measured as each kept row's JSON
/// text, cut by whole rows from the end.</p>
Parameter MAXCELL As INTEGER = 1000;

Parameter MAXANSWER As INTEGER = 1000000;

/// <p>ODBC select mode, so dates and times read alike across locales.</p>
Parameter SELECTMODE As INTEGER = 1;

/// <p>Text that sets a password, refused before any prepare, because the instance keeps a prepared
/// statement's text in its statement index. <code>CREATE USER</code> and <code>ALTER USER</code> take
/// one after <code>IDENTIFY BY</code>, <code>IDENTIFIED BY</code> or <code>[WITH] PASSWORD</code>, so
/// the pattern matches <code>IDENTIFY</code> or <code>IDENTIFIED</code> anywhere, or the words
/// <code>CREATE</code> or <code>ALTER</code>, <code>USER</code> and <code>PASSWORD</code> in that
/// order, comments and literals included. It is fail-closed: it also refuses a statement that only
/// names such a word, as a literal, a column or a table, such as a <code>CREATE TABLE</code> naming a
/// table <code>User</code> and a column <code>Password</code>. Each atomic group commits to the first
/// occurrence, which keeps the match linear in the text's length.</p>
Parameter PASSWORDPATTERN = "(?is)\bIDENTIF(Y|IED)\b|^(?>.*?\b(?:CREATE|ALTER)\b)(?>.*?\bUSER\b).*\bPASSWORD\b";

/// <p>The system privilege the SQL reference names for a DDL statement type, as
/// <code>type:privilege</code> pairs: a statement of a listed type runs only for a caller who holds
/// it (<method>HoldsPrivilege</method>). An unlisted type is left to the instance's own check.
/// <code>DROP VIEW</code> (14) is unlisted because the reference accepts <code>%DROP_VIEW</code> or
/// DELETE on the view, so a check for the system privilege alone would refuse a caller the instance
/// admits.</p>
Parameter DDLPRIVILEGES = "9:%CREATE_TABLE,10:%ALTER_TABLE,11:%DROP_TABLE,12:%CREATE_VIEW,13:%ALTER_VIEW,15:%ALTER_TABLE,17:%ALTER_TABLE,35:%CREATE_FUNCTION,36:%CREATE_METHOD,37:%CREATE_PROCEDURE,38:%CREATE_QUERY,39:%DROP_FUNCTION,40:%DROP_METHOD,41:%DROP_PROCEDURE,42:%DROP_QUERY,43:%CREATE_TRIGGER,44:%DROP_TRIGGER,52:%ALTER_TABLE,54:%MANAGE_MODEL,55:%MANAGE_MODEL,56:%MANAGE_MODEL,57:%MANAGE_MODEL,58:%USE_MODEL,60:%CREATE_ML_CONFIGURATION,61:%ALTER_ML_CONFIGURATION,62:%DROP_ML_CONFIGURATION,66:%BUILD_INDEX";

/// <p>The SQLCODE the instance answers a privilege violation with.</p>
Parameter PRIVILEGESQLCODE As INTEGER = -99;

/// <p>The closed kind table over <code>%Metadata.statementType</code>. A number no row names is
/// <parameter>KINDOTHER</parameter>.</p>
Parameter TYPESQUERY = "1,28,32,79";

Parameter TYPESDML = "2,3,4";

Parameter TYPESDDL = "9,10,11,12,13,14,15,17,35,36,37,38,39,40,41,42,43,44,52,54,55,56,57,58,60,61,62,63,64,65,66,67,68,70,71";

Parameter TYPESCALL = "45";

Parameter TYPESOTHER = "16,25,27,99";

Parameter TYPESSESSION = "5,6,20,21,22,23,24,26,46,47,48,51,53,59,78";

Parameter TYPESADMINISTRATION = "7,8,18,19,29,30,31,33,34,49,50";

Parameter TYPESSERVERFILES = "69,72,73,74,75,76,77,80";

/// <p>The kinds.</p>
Parameter KINDQUERY = "query";

Parameter KINDDML = "dml";

Parameter KINDDDL = "ddl";

Parameter KINDCALL = "call";

Parameter KINDOTHER = "other";

Parameter KINDSESSION = "session";

Parameter KINDADMINISTRATION = "administration";

Parameter KINDSERVERFILES = "serverfiles";

/// <p>The outcomes a run or a plan answers.</p>
Parameter OUTCOMEROWS = "rows";

Parameter OUTCOMEDONE = "done";

Parameter OUTCOMEERROR = "error";

Parameter OUTCOMESTOPPED = "stopped";

Parameter OUTCOMEPLAN = "plan";

Parameter OUTCOMENOPLAN = "noplan";

/// <p>The SQLCODE the instance answers a statement its alarm stopped with.</p>
Parameter ALARMSQLCODE As INTEGER = -450;

/// <p>The subsystem a fault is logged under.</p>
Parameter LOGSUBSYSTEM = "sqlport";

/// <p>The class the gate evaluates through. Overridable so a fixture can drive a denial in process;
/// production never overrides it.</p>
ClassMethod GateClass() As %String
{
    Quit ..#GATECLASS
}

/// <p>The seconds a query or a DML statement may run before it is stopped:
/// <method>OcuPilot.Kernel.Provider.TestCall.BoundSeconds</method> of the gateway's timeout, read at
/// each call. Overridable so a fixture can stop a probe statement quickly; production never overrides
/// it.</p>
ClassMethod BoundSeconds() As %Integer
{
    Quit ##class(OcuPilot.Kernel.Provider.TestCall).BoundSeconds(##class(OcuPilot.Kernel.Provider.TestCall).GatewaySeconds())
}

/// <p>The kind <var>pType</var>, a prepared statement's <code>statementType</code>, belongs to in the
/// closed table: <parameter>KINDQUERY</parameter>, <parameter>KINDDML</parameter>,
/// <parameter>KINDDDL</parameter>, <parameter>KINDCALL</parameter>,
/// <parameter>KINDSESSION</parameter>, <parameter>KINDADMINISTRATION</parameter>,
/// <parameter>KINDSERVERFILES</parameter>, or <parameter>KINDOTHER</parameter> for every number the
/// table does not name. Pure.</p>
ClassMethod KindOf(pType As %String) As %String
{
    If (pType = "") || '$Match(pType, "^[0-9]+$") Quit ..#KINDOTHER
    Set tType = +pType
    If $ListFind($ListFromString(..#TYPESQUERY), tType) Quit ..#KINDQUERY
    If $ListFind($ListFromString(..#TYPESDML), tType) Quit ..#KINDDML
    If $ListFind($ListFromString(..#TYPESDDL), tType) Quit ..#KINDDDL
    If $ListFind($ListFromString(..#TYPESCALL), tType) Quit ..#KINDCALL
    If $ListFind($ListFromString(..#TYPESSESSION), tType) Quit ..#KINDSESSION
    If $ListFind($ListFromString(..#TYPESADMINISTRATION), tType) Quit ..#KINDADMINISTRATION
    If $ListFind($ListFromString(..#TYPESSERVERFILES), tType) Quit ..#KINDSERVERFILES
    Quit ..#KINDOTHER
}

/// <p>The system privilege a statement of type <var>pType</var> requires, from
/// <parameter>DDLPRIVILEGES</parameter>, or <code>""</code> for a type it does not list. Pure.</p>
ClassMethod PrivilegeFor(pType As %String) As %String
{
    If (pType = "") || '$Match(pType, "^[0-9]+$") Quit ""
    Set tPairs = $ListFromString(..#DDLPRIVILEGES)
    For tI = 1:1:$ListLength(tPairs) {
        If +$Piece($List(tPairs, tI), ":", 1) = +pType Return $Piece($List(tPairs, tI), ":", 2)
    }
    Quit ""
}

/// <p>Whether a statement of kind <var>pKind</var> runs only once a person confirms it: every kind
/// but <parameter>KINDQUERY</parameter> that the console runs at all.</p>
ClassMethod Mutating(pKind As %String) As %Boolean
{
    Quit (pKind = ..#KINDDML) || (pKind = ..#KINDDDL) || (pKind = ..#KINDCALL) || (pKind = ..#KINDOTHER)
}

/// <p>Whether a run of kind <var>pKind</var> is bounded by the alarm: a query and a DML statement.
/// A DDL statement, a CALL and an unclassified statement run unbounded (named limit).</p>
ClassMethod Bounded(pKind As %String) As %Boolean
{
    Quit (pKind = ..#KINDQUERY) || (pKind = ..#KINDDML)
}

/// <p>What is wrong with a request's statement <var>pText</var>, values <var>pValues</var> (a
/// <class>%DynamicArray</class>, or <code>""</code> for none) and row cap <var>pMaxRows</var>
/// (<code>""</code> for the default), as a sentence for the caller's own use, or <code>""</code>. A
/// caller refuses a non-empty answer 400 <parameter>OcuPilot.Api.AtelierError.SQLINPUT</parameter>
/// before anything is prepared.</p>
ClassMethod InputProblem(pText As %String, pValues As %DynamicArray = "", pMaxRows As %String = "") As %String
{
    If $IsObject(pText) Quit "statement"
    If ($Length(pText) < 1) || ($Length(pText) > ..#MAXSTATEMENT) Quit "statement"
    If $ZStrip(pText, "<>W") = "" Quit "statement"
    If pValues '= "" {
        If '$IsObject(pValues) || 'pValues.%IsA("%Library.DynamicArray") Quit "parameters"
        If pValues.%Size() > ..#MAXVALUES Quit "parameters"
        Set tIterator = pValues.%GetIterator()
        Set tBad = 0
        While tIterator.%GetNext(.tIndex, .tValue) {
            If (pValues.%GetTypeOf(tIndex) '= "string") || ($Length(tValue) > ..#MAXVALUE) {
                Set tBad = 1
                Quit
            }
        }
        If tBad Quit "parameters"
    }
    If pMaxRows '= "" {
        If '$Match(pMaxRows, "^[1-9][0-9]{0,3}$") || (+pMaxRows > ..#MAXROWS) Quit "maxRows"
    }
    Quit ""
}

/// <p>Whether <var>pText</var> sets a password, read as text before any prepare
/// (<parameter>PASSWORDPATTERN</parameter>). Fail-closed: it also refuses such a word in a literal or a
/// comment.</p>
ClassMethod SetsPassword(pText As %String) As %Boolean
{
    Quit ($Locate(pText, ..#PASSWORDPATTERN) > 0)
}

/// <p>Classify <var>pText</var> in <var>pNamespace</var>: the gate, the bounds, the password check,
/// the prepare and the refused kinds, in that order. On success <var>pGuard</var> is
/// <code>{Namespace, Kind, StatementType, Tables, RecordsTables, Parameters, Columns,
/// DefaultSchema}</code> -- <code>Parameters</code> the count of the <code>?</code> positions that
/// take a value, <code>Tables</code> the tables and views the instance's statement index records for
/// the statement, a view's base tables among them -- or, when the prepare failed, the same object with
/// <code>Kind</code> empty and <code>error</code> <code>{sqlcode, message}</code>.</p>
/// <p>A DDL statement of a type <parameter>DDLPRIVILEGES</parameter> lists is answered the same way,
/// with the instance's privilege violation (<parameter>PRIVILEGESQLCODE</parameter>), unless
/// <code>%CHECKPRIV</code> in <var>pNamespace</var> answers that the caller holds the type's system
/// privilege. The instance checks that privilege only when it compiles the statement, and a cached
/// compile another session still holds open answers the next prepare of the same text without it
/// (measured).</p>
/// <p>Otherwise an error status, with <var>pHttpStatus</var> and <var>pFault</var>: 403
/// <code>AUTH.NOPRIVILEGE</code> naming the pair; 400 <code>PORT.VALIDATION</code> for a namespace
/// whose code databases cannot be named; 400 <code>EXPLORER.SQL.INPUT</code>; 422
/// <code>EXPLORER.SQL.PASSWORD</code>; 422 <code>EXPLORER.SQL.SESSION</code>,
/// <code>.ADMINISTRATION</code> or <code>.SERVERFILES</code>; and 500 <code>INTERNAL</code> when the
/// statement index cannot be read for a query or a DML statement.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9). The prepare records the
/// statement in the namespace's statement index (AD-7's fifth shape).</p>
ClassMethod Classify(pNamespace As %String, pText As %String, Output pGuard As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pGuard = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Set tSC = ..Gate(pNamespace, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If ..InputProblem(pText) '= "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AtelierError).#SQLINPUT, ##class(OcuPilot.Api.AtelierError).#REASONSQLINPUT, .pHttpStatus, .pFault)
            Quit
        }
        If ..SetsPassword(pText) {
            Set tSC = ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AtelierError).#SQLPASSWORD, ##class(OcuPilot.Api.AtelierError).#REASONSQLPASSWORD, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Prepared(pNamespace, pText, .tRaw)
        If $$$ISERR(tSC) {
            Set tSC = ..Fail("the statement could not be classified", tSC, .pHttpStatus, .pFault)
            Quit
        }
        Set tGuard = ..EmptyGuard(pNamespace)
        If tRaw.%GetTypeOf("error") = "object" {
            Do tGuard.%Set("error", tRaw.%Get("error"))
            Set pGuard = tGuard
            Quit
        }
        Set tType = tRaw.%Get("type")
        Set tKind = ..KindOf(tType)
        Do tGuard.%Set("Kind", tKind, "string")
        Do tGuard.%Set("StatementType", +tType, "number")
        Do tGuard.%Set("Tables", tRaw.%Get("tables"))
        Do tGuard.%Set("RecordsTables", (tRaw.%Get("tables").%Size() > 0), "boolean")
        Do tGuard.%Set("Parameters", ..ValuePositions(tRaw.%Get("positions")), "number")
        Do tGuard.%Set("Columns", tRaw.%Get("columns"))
        Do tGuard.%Set("DefaultSchema", tRaw.%Get("defaultSchema"), "string")
        ; Fail closed: a query or a DML statement whose statement-index row cannot be found has tables
        ; nobody can read, which the self-protection check needs.
        If ((tKind = ..#KINDQUERY) || (tKind = ..#KINDDML)) && 'tRaw.%Get("indexed") {
            Set tSC = ..Fail("the statement index answered no row for a prepared statement", $$$ERROR($$$GeneralError, "no statement index row"), .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..RefuseKind(tKind, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tPrivilege = ..PrivilegeFor(tType)
        If tPrivilege '= "" {
            Set tSC = ..HoldsPrivilege(pNamespace, tPrivilege, .tHolds)
            If $$$ISERR(tSC) {
                Set tSC = ..Fail("the statement's system privilege could not be checked", tSC, .pHttpStatus, .pFault)
                Quit
            }
            If 'tHolds {
                Set tRefused = ..EmptyGuard(pNamespace)
                Set tError = {}
                Do tError.%Set("sqlcode", ..#PRIVILEGESQLCODE, "number")
                Do tError.%Set("message", $SYSTEM.SQL.Functions.SQLCODE(..#PRIVILEGESQLCODE), "string")
                Do tRefused.%Set("error", tError)
                Set pGuard = tRefused
                Quit
            }
        }
        Set pGuard = tGuard
    } Catch ex {
        Set pGuard = ""
        Set tSC = ..Fail("the statement could not be classified", $$$ERROR($$$GeneralError, ex.Name), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Run <var>pText</var> in <var>pNamespace</var> with the values <var>pValues</var> (a
/// <class>%DynamicArray</class> of strings, one per value position, in order) and the row cap
/// <var>pMaxRows</var>. <var>pMode</var> <code>query</code> runs only a statement of kind
/// <parameter>KINDQUERY</parameter>, and <code>write</code> only one that changes something, refusing a
/// query 422 <code>EXPLORER.SQL.READS</code>.</p>
/// <p>The statement is classified again first (<method>Classify</method>), so every refusal it answers
/// applies; values that do not number the value positions are refused 422
/// <code>EXPLORER.SQL.PARAMETERS</code>. A query and a DML statement run under the alarm
/// (<method>BoundSeconds</method>). A run that leaves <code>$TLevel</code> above where it started is
/// rolled back to that level and answers <code>error</code> with <code>rolledBack</code>.</p>
/// <p>On success <var>pAnswer</var> is one of: <code>{outcome: rows, kind, columns, rows,
/// truncated}</code>, at most <var>pMaxRows</var> rows of text cells, each cut at
/// <parameter>MAXCELL</parameter> characters ending in U+2026, the whole cut by whole rows at
/// <parameter>MAXANSWER</parameter> characters, <code>truncated</code> reporting any cut (a CALL that
/// answers a result set answers its first one this way); <code>{outcome: done, kind, rowCount}</code>;
/// <code>{outcome: error, kind, sqlcode, message, rolledBack?}</code>; or <code>{outcome: stopped,
/// kind, seconds}</code>.</p>
ClassMethod Run(pNamespace As %String, pText As %String, pValues As %DynamicArray, pMaxRows As %Integer, pMode As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Set tValues = $Select($IsObject(pValues): pValues, 1: [])
        Set tMaxRows = $Select(pMaxRows = "": ..#MAXROWS, 1: pMaxRows)
        Set tSC = ..Gate(pNamespace, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If ..InputProblem(pText, tValues, tMaxRows) '= "" {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AtelierError).#SQLINPUT, ##class(OcuPilot.Api.AtelierError).#REASONSQLINPUT, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Classify(pNamespace, pText, .tGuard, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If tGuard.%GetTypeOf("error") = "object" {
            Set pAnswer = ..ErrorAnswer("", tGuard.%Get("error").%Get("sqlcode"), tGuard.%Get("error").%Get("message"))
            Quit
        }
        Set tKind = tGuard.%Get("Kind")
        If pMode = "write" {
            If tKind = ..#KINDQUERY {
                Set tSC = ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AtelierError).#SQLREADS, ##class(OcuPilot.Api.AtelierError).#REASONSQLREADS, .pHttpStatus, .pFault)
                Quit
            }
        } ElseIf tKind '= ..#KINDQUERY {
            Set tSC = ..Fail("a run asked for a query was answered another kind", $$$ERROR($$$GeneralError, tKind), .pHttpStatus, .pFault)
            Quit
        }
        If tValues.%Size() '= tGuard.%Get("Parameters") {
            Set tSC = ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AtelierError).#SQLPARAMETERS, ##class(OcuPilot.Api.AtelierError).#REASONSQLPARAMETERS, .pHttpStatus, .pFault)
            Quit
        }
        Set tBound = $Select(..Bounded(tKind): ..BoundSeconds(), 1: 0)
        Set tFetch = (tKind = ..#KINDQUERY) || (tKind = ..#KINDCALL)
        Set tSC = ..Executed(pNamespace, pText, tGuard.%Get("StatementType"), tValues, tBound, tFetch, tMaxRows, .tRaw)
        If $$$ISERR(tSC) {
            Set tSC = ..Fail("the statement could not be run", tSC, .pHttpStatus, .pFault)
            Quit
        }
        Set pAnswer = ..RunAnswer(tKind, tBound, tRaw)
    } Catch ex {
        Set pAnswer = ""
        Set tSC = ..Fail("the statement could not be run", $$$ERROR($$$GeneralError, ex.Name), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The query plan of <var>pText</var> in <var>pNamespace</var>, executing nothing: classified
/// first (<method>Classify</method>), then, for a query or a DML statement,
/// <code>$SYSTEM.SQL.Explain</code> with its output silenced. <var>pAnswer</var> is <code>{outcome:
/// plan, kind, plan, truncated}</code>, the plan's text cut at <parameter>MAXANSWER</parameter>
/// characters; <code>{outcome: noplan, kind}</code> for every other kind; or <code>{outcome: error,
/// kind, sqlcode, message}</code>. Every refusal is <method>Classify</method>'s.</p>
ClassMethod Plan(pNamespace As %String, pText As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Set tSC = ..Classify(pNamespace, pText, .tGuard, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If tGuard.%GetTypeOf("error") = "object" {
            Set pAnswer = ..ErrorAnswer("", tGuard.%Get("error").%Get("sqlcode"), tGuard.%Get("error").%Get("message"))
            Quit
        }
        Set tKind = tGuard.%Get("Kind")
        Set pAnswer = {}
        Do pAnswer.%Set("kind", tKind, "string")
        If (tKind '= ..#KINDQUERY) && (tKind '= ..#KINDDML) {
            Do pAnswer.%Set("outcome", ..#OUTCOMENOPLAN, "string")
            Quit
        }
        Set tSC = ..Explained(pNamespace, pText, .tPlan, .tCode, .tMessage)
        If $$$ISERR(tSC) {
            Set pAnswer = ""
            Set tSC = ..Fail("the statement's plan could not be read", tSC, .pHttpStatus, .pFault)
            Quit
        }
        If tCode '= "" {
            Set pAnswer = ..ErrorAnswer(tKind, tCode, tMessage)
            Quit
        }
        Do pAnswer.%Set("outcome", ..#OUTCOMEPLAN, "string")
        Do pAnswer.%Set("plan", $Extract(tPlan, 1, ..#MAXANSWER), "string")
        Do pAnswer.%Set("truncated", ($Length(tPlan) > ..#MAXANSWER), "boolean")
    } Catch ex {
        Set pAnswer = ""
        Set tSC = ..Fail("the statement's plan could not be read", $$$ERROR($$$GeneralError, ex.Name), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Serve <var>pEndpoint</var> (<parameter>ENDPOINTSQL</parameter>) for request type
/// <var>pType</var>, the write path's way in (AD-51, AD-52). <var>pQuery</var> carries
/// <code>id</code>, which must be <parameter>IDVALUE</parameter>; <code>namespace</code>, or the
/// request's resolved scope where it is absent; and <code>statement</code>,
/// <code>parameters</code> (JSON array text) and <code>maxRows</code>. <var>pBody</var> is not
/// read.</p>
/// <p><parameter>TYPEGUARD</parameter> answers <method>Classify</method>'s guard with
/// <code>statement</code>, <code>parameters</code> and <code>maxRows</code> <code>null</code> beside
/// it, or, with no statement, the empty guard after the gate alone. <parameter>TYPERUN</parameter>
/// answers <method>Run</method>'s answer in <code>write</code> mode. Any other endpoint or type is 501
/// <code>PORT.NOTIMPLEMENTED</code>, and any other id 404 <code>PORT.NOTFOUND</code>, before any
/// call.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        If (pEndpoint '= ..#ENDPOINTSQL) || ((pType '= ..#TYPEGUARD) && (pType '= ..#TYPERUN)) {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ##class(OcuPilot.Port.AtelierPort).#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If $ZConvert($Get(pQuery(..#IDKEY)), "L") '= ..#IDVALUE {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, ##class(OcuPilot.Port.AtelierPort).#REASONNOTFOUND, .pHttpStatus, .pFault)
            Quit
        }
        Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
        If tNamespace = "" Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        Set tText = $Get(pQuery(..#STATEMENTKEY))
        If pType = ..#TYPEGUARD {
            If tText = "" {
                Set tSC = ..Gate(tNamespace, .pHttpStatus, .pFault)
                If $$$ISERR(tSC) Quit
                Set tGuard = ..EmptyGuard(tNamespace)
            } Else {
                Set tSC = ..Classify(tNamespace, tText, .tGuard, .pHttpStatus, .pFault)
                If $$$ISERR(tSC) Quit
            }
            For tKey = ..#STATEMENTKEY, ..#PARAMETERSKEY, ..#MAXROWSKEY {
                Do tGuard.%Set(tKey, "", "null")
            }
            Set pResult = tGuard
            Set pHttpStatus = 200
            Quit
        }
        Set tValues = ..ValuesFrom($Get(pQuery(..#PARAMETERSKEY)), .tReadable)
        If 'tReadable {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AtelierError).#SQLINPUT, ##class(OcuPilot.Api.AtelierError).#REASONSQLINPUT, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Run(tNamespace, tText, tValues, $Get(pQuery(..#MAXROWSKEY)), "write", .pResult, .pHttpStatus, .pFault)
        If $$$ISOK(tSC) Set pHttpStatus = 200
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail("the console's port failed", $$$ERROR($$$GeneralError, ex.Name), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p><var>pText</var>, JSON array text, as a <class>%DynamicArray</class>, with
/// <var>pReadable</var> 0 when it is not an array; <code>""</code> and an absent key read as no
/// values.</p>
ClassMethod ValuesFrom(pText As %String, Output pReadable As %Boolean) As %DynamicArray
{
    Set pReadable = 1
    If pText = "" Quit []
    Set tValues = ""
    Try {
        Set tValues = ##class(%DynamicAbstractObject).%FromJSON(pText)
    } Catch {
        Set tValues = ""
    }
    If $IsObject(tValues) && tValues.%IsA("%Library.DynamicArray") Quit tValues
    Set pReadable = 0
    Quit []
}

/// <p><code>objectscript</code> for <parameter>TYPERUN</parameter>, the one write this port carries;
/// <code>""</code> for the read, which has no script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If (pEndpoint = ..#ENDPOINTSQL) && (pType = ..#TYPERUN) Quit "objectscript"
    Quit ""
}

/// <p><method>Invoke</method>'s <parameter>TYPERUN</parameter> as a script (AD-59), in the namespace
/// <code>namespace</code> names: the statement prepared with privilege checks on in ODBC select mode,
/// each value bound at the next position that takes one, as <method>Executed</method> binds it, then
/// executed, and its SQLCODE, message and row count shown. Every value is rendered as a string
/// literal, so nothing the query carries runs as code.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    Set tValues = ..ValuesFrom($Get(pQuery(..#PARAMETERSKEY)), .tReadable)
    Set tList = ""
    Set tIterator = tValues.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        Set tList = tList _ $Select(tList = "": "", 1: ", ") _ ..Literal(tValue)
    }
    Set tText = " Set $NAMESPACE = " _ ..Literal($Get(pQuery(..#NAMESPACEKEY)))
    Set tText = tText _ $Char(10) _ " Set tStatement = ##class(%SQL.Statement).%New()"
    Set tText = tText _ $Char(10) _ " Set tStatement.%SelectMode = " _ ..#SELECTMODE
    Set tText = tText _ $Char(10) _ " Set tSC = tStatement.%Prepare(" _ ..Literal($Get(pQuery(..#STATEMENTKEY))) _ ", 1)"
    Set tText = tText _ $Char(10) _ " If $System.Status.IsError(tSC) { Do $System.Status.DisplayError(tSC) Quit }"
    Set tText = tText _ $Char(10) _ " Set tValues = $ListBuild(" _ tList _ ")"
    Set tText = tText _ $Char(10) _ " Set tArgs = tStatement.%Metadata.parameters.Count(), tNext = 0"
    Set tText = tText _ $Char(10) _ " For tI = 1:1:tArgs { Set tType = tStatement.%Metadata.parameters.GetAt(tI).columnType If (tType '= 4) && (tType '= 5) { Set tNext = tNext + 1, tArgs(tI) = $ListGet(tValues, tNext) } }"
    Set tText = tText _ $Char(10) _ " Set tResult = tStatement.%Execute(tArgs...)"
    Set tText = tText _ $Char(10) _ " ZWrite tResult.%SQLCODE, tResult.%Message, tResult.%ROWCOUNT"
    Set tStep = {}
    Do tStep.%Set("kind", "objectscript", "string")
    Do tStep.%Set("text", tText, "string")
    Quit [(tStep)]
}

/// <p>The gate (AD-29, AD-61 rule 1): <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, then
/// READ on <var>pNamespace</var>'s code databases (<method>OcuPilot.Port.AtelierPort.NamespacePairs</method>),
/// each through <code>EvaluateRequired</code>, so an empty pair set fails closed. A refusal names the
/// failed pair; a malformed namespace, or one whose databases cannot be named, is 400
/// <code>PORT.VALIDATION</code>.</p>
ClassMethod Gate(pNamespace As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tFailedPair = ""
    If '$ClassMethod(..GateClass(), "EvaluateRequired", ##class(OcuPilot.Port.AtelierPort).Pairs(), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    If '$Match(pNamespace, ##class(OcuPilot.Port.AtelierPort).#NAMESPACEPATTERN) {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Port.AtelierPort).#REASONNAMESPACESHAPE, .pHttpStatus, .pFault)
    }
    Set tPairs = ##class(OcuPilot.Port.AtelierPort).NamespacePairs(pNamespace)
    If tPairs = "" {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Port.AtelierPort).#REASONNAMESPACEUNKNOWN, .pHttpStatus, .pFault)
    }
    If '$ClassMethod(..GateClass(), "EvaluateRequired", tPairs, .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>The guard of no statement in <var>pNamespace</var>: every member present and empty.</p>
ClassMethod EmptyGuard(pNamespace As %String) As %DynamicObject [ Private ]
{
    Set tGuard = {}
    Do tGuard.%Set("Namespace", pNamespace, "string")
    Do tGuard.%Set("Kind", "", "string")
    Do tGuard.%Set("StatementType", "", "string")
    Do tGuard.%Set("Tables", [])
    Do tGuard.%Set("RecordsTables", 0, "boolean")
    Do tGuard.%Set("Parameters", 0, "number")
    Do tGuard.%Set("Columns", [])
    Do tGuard.%Set("DefaultSchema", "", "string")
    Quit tGuard
}

/// <p>The refusal of a statement of kind <var>pKind</var>: the session, administration and
/// server-file kinds are each refused 422 by name, and every other kind passes.</p>
ClassMethod RefuseKind(pKind As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tError = "OcuPilot.Api.AtelierError"
    If pKind = ..#KINDSESSION Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, $Parameter(tError, "SQLSESSION"), $Parameter(tError, "REASONSQLSESSION"), .pHttpStatus, .pFault)
    If pKind = ..#KINDADMINISTRATION Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, $Parameter(tError, "SQLADMINISTRATION"), $Parameter(tError, "REASONSQLADMINISTRATION"), .pHttpStatus, .pFault)
    If pKind = ..#KINDSERVERFILES Quit ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, $Parameter(tError, "SQLSERVERFILES"), $Parameter(tError, "REASONSQLSERVERFILES"), .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>How many of <var>pPositions</var>, the parameters' <code>columnType</code>s in order, take a
/// value: every type but output (4) and return value (5).</p>
ClassMethod ValuePositions(pPositions As %DynamicArray) As %Integer [ Private ]
{
    Set tCount = 0
    If '$IsObject(pPositions) Quit 0
    Set tIterator = pPositions.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tType) {
        If (tType '= 4) && (tType '= 5) Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The answer of a run of kind <var>pKind</var> bounded at <var>pBound</var> seconds (0 for none),
/// from <method>Executed</method>'s raw answer <var>pRaw</var>.</p>
ClassMethod RunAnswer(pKind As %String, pBound As %Integer, pRaw As %DynamicObject) As %DynamicObject [ Private ]
{
    If pRaw.%Get("stopped") {
        Set tAnswer = {}
        Do tAnswer.%Set("outcome", ..#OUTCOMESTOPPED, "string")
        Do tAnswer.%Set("kind", pKind, "string")
        Do tAnswer.%Set("seconds", pBound, "number")
        Quit tAnswer
    }
    If pRaw.%Get("changed") {
        Quit ..ErrorAnswer(pKind, "", "")
    }
    If (pRaw.%Get("sqlcode") < 0) || pRaw.%Get("rolledBack") {
        Set tAnswer = ..ErrorAnswer(pKind, $Select(pRaw.%Get("sqlcode") < 0: pRaw.%Get("sqlcode"), 1: ""), $Select(pRaw.%Get("sqlcode") < 0: pRaw.%Get("message"), 1: ""))
        If pRaw.%Get("rolledBack") Do tAnswer.%Set("rolledBack", 1, "boolean")
        Quit tAnswer
    }
    Set tAnswer = {}
    Do tAnswer.%Set("kind", pKind, "string")
    If pRaw.%GetTypeOf("rows") = "array" {
        Do tAnswer.%Set("outcome", ..#OUTCOMEROWS, "string")
        Do tAnswer.%Set("columns", pRaw.%Get("columns"))
        Do tAnswer.%Set("rows", pRaw.%Get("rows"))
        Do tAnswer.%Set("truncated", ''pRaw.%Get("truncated"), "boolean")
        Quit tAnswer
    }
    Do tAnswer.%Set("outcome", ..#OUTCOMEDONE, "string")
    Do tAnswer.%Set("rowCount", +pRaw.%Get("rowCount"), "number")
    Quit tAnswer
}

/// <p>The <code>error</code> outcome: <code>{outcome, kind, sqlcode, message}</code>, an empty
/// SQLCODE answered as <code>null</code>.</p>
ClassMethod ErrorAnswer(pKind As %String, pCode As %String, pMessage As %String) As %DynamicObject [ Private ]
{
    Set tAnswer = {}
    Do tAnswer.%Set("outcome", ..#OUTCOMEERROR, "string")
    Do tAnswer.%Set("kind", pKind, "string")
    If pCode = "" {
        Do tAnswer.%Set("sqlcode", "", "null")
    } Else {
        Do tAnswer.%Set("sqlcode", +pCode, "number")
    }
    Do tAnswer.%Set("message", pMessage, "string")
    Quit tAnswer
}

/// <p>Prepare <var>pText</var> in <var>pNamespace</var> and answer in <var>pRaw</var> what the
/// instance says of it: <code>{type, positions, columns, indexed, tables, defaultSchema}</code>, or
/// <code>{error: {sqlcode, message}}</code> when the prepare failed. <code>tables</code> is the
/// statement index's relations for the statement, keyed by the cached query's
/// <code>%StatementIndexHash</code>, else by its <code>STATEMENT_LOCATIONS</code> row
/// <code>&lt;class&gt;.1</code>, then each view's base tables from
/// <code>INFORMATION_SCHEMA.VIEW_TABLE_USAGE</code>; <code>indexed</code> is 0 when either cannot be
/// read.</p>
/// <p><b>The switched region calls vendor classes only</b> (AD-16): nothing in it reaches an
/// OcuPilot class, and the restore is the first line of the <code>Catch</code>. The statement is
/// released in <var>pNamespace</var> (<method>Closed</method>). An error status names the exception
/// and nothing of the statement.</p>
ClassMethod Prepared(pNamespace As %String, pText As %String, Output pRaw As %DynamicObject) As %Status [ Private ]
{
    Set pRaw = {}
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tStatement.%SelectMode = ..#SELECTMODE
        Set tPrepareSC = tStatement.%Prepare(pText, 1)
        If $$$ISERR(tPrepareSC) {
            Set tMessage = ""
            Set tCode = $System.Status.StatusToSQLCODE(tPrepareSC, .tMessage)
            Set tError = {}
            Do tError.%Set("sqlcode", +tCode, "number")
            Do tError.%Set("message", tMessage, "string")
            Do pRaw.%Set("error", tError)
        } Else {
            Set tMetadata = tStatement.%Metadata
            Do pRaw.%Set("type", +tMetadata.statementType, "number")
            Set tPositions = []
            For tI = 1:1:tMetadata.parameters.Count() {
                Do tPositions.%Push(+tMetadata.parameters.GetAt(tI).columnType, "number")
            }
            Do pRaw.%Set("positions", tPositions)
            Set tColumns = []
            For tI = 1:1:tMetadata.columns.Count() {
                Do tColumns.%Push(tMetadata.columns.GetAt(tI).colName, "string")
            }
            Do pRaw.%Set("columns", tColumns)
            Set tClass = ""
            Do tStatement.%GetImplementationDetails(.tClass)
            Set tHash = ""
            If tClass '= "" Set tHash = $Parameter(tClass, "%StatementIndexHash")
            If (tHash = "") && (tClass '= "") {
                Set tLocation = ##class(%SQL.Statement).%ExecDirect(, "SELECT Statement FROM INFORMATION_SCHEMA.STATEMENT_LOCATIONS WHERE Location = ?", tClass _ ".1")
                If (tLocation.%SQLCODE >= 0) && tLocation.%Next() Set tHash = tLocation.%GetData(1)
            }
            Set tTables = []
            Set tIndexed = (tHash '= "")
            If tIndexed {
                Set tRelations = ##class(%SQL.Statement).%ExecDirect(, "SELECT Relation FROM INFORMATION_SCHEMA.STATEMENT_RELATIONS WHERE Statement = ?", tHash)
                If tRelations.%SQLCODE < 0 {
                    Set tIndexed = 0
                } Else {
                    While tRelations.%Next() {
                        Set tSeen($ZConvert(tRelations.%GetData(1), "U")) = ""
                        Do tTables.%Push(tRelations.%GetData(1), "string")
                    }
                    If tRelations.%SQLCODE < 0 Set tIndexed = 0
                }
            }
            ; A view's base tables: the index leaves them out for an INSERT through a view (measured).
            If tIndexed {
                Set tUsage = ##class(%SQL.Statement).%New()
                If $$$ISERR(tUsage.%Prepare("SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.VIEW_TABLE_USAGE WHERE VIEW_SCHEMA = ? AND VIEW_NAME = ?")) Set tIndexed = 0
                Set tAt = 0
                While tIndexed && (tAt < tTables.%Size()) {
                    Set tRelation = tTables.%Get(tAt)
                    Set tAt = tAt + 1
                    Set tUsed = tUsage.%Execute($Piece(tRelation, ".", 1), $Piece(tRelation, ".", 2, *))
                    While tUsed.%Next() {
                        Set tBase = $ZConvert(tUsed.%GetData(1) _ "." _ tUsed.%GetData(2), "U")
                        If '$Data(tSeen(tBase)) {
                            Set tSeen(tBase) = ""
                            Do tTables.%Push(tBase, "string")
                        }
                    }
                    If tUsed.%SQLCODE < 0 Set tIndexed = 0
                }
            }
            Do pRaw.%Set("indexed", tIndexed, "boolean")
            Do pRaw.%Set("tables", tTables)
            Do pRaw.%Set("defaultSchema", $SYSTEM.SQL.Schema.Default(), "string")
        }
        Set (tMetadata, tStatement) = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tMetadata = ""
        Do ..Closed(pNamespace, .tStatement)
        Set pRaw = {}
        Set tSC = $$$ERROR($$$GeneralError, "the prepare raised " _ ex.Name)
    }
    Quit tSC
}

/// <p>Run <var>pText</var> in <var>pNamespace</var> with the values <var>pValues</var>, after
/// preparing it again and checking it is still of statement type <var>pType</var>: each value is bound
/// at the next position that takes one, and an output or return position is left undefined, which is
/// how <code>%Execute</code> is told to skip it. It runs under an alarm of
/// <var>pBound</var> seconds when that is above 0. With <var>pFetch</var>, the rows of a query, or of
/// a CALL's first result set, are read: at most <var>pMaxRows</var>, one more fetched to learn
/// whether more exist, each cell cut at <parameter>MAXCELL</parameter> characters, and rows kept
/// while their JSON text totals at most <parameter>MAXANSWER</parameter> characters.</p>
/// <p><var>pRaw</var> is <code>{sqlcode, message, rowCount, columns?, rows?, truncated?, stopped,
/// rolledBack, changed}</code>: <code>stopped</code> when the alarm stopped the run,
/// <code>rolledBack</code> when <code>$TLevel</code> was left above where it started and was rolled
/// back to it, <code>changed</code> when the second prepare answered another type or failed.</p>
/// <p><b>The switched region calls vendor classes only</b> (AD-16), and the restore is the first line
/// of the <code>Catch</code>, before the alarm is cleared and the transaction rolled back. The
/// statement is released in <var>pNamespace</var>, its results first (<method>Closed</method>).</p>
ClassMethod Executed(pNamespace As %String, pText As %String, pType As %Integer, pValues As %DynamicArray, pBound As %Integer, pFetch As %Boolean, pMaxRows As %Integer, Output pRaw As %DynamicObject) As %Status [ Private ]
{
    Set pRaw = {"sqlcode": 0, "message": "", "rowCount": 0, "stopped": false, "rolledBack": false, "changed": false}
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set tLevel = $TLevel
    Set tAlarmed = 0
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tStatement.%SelectMode = ..#SELECTMODE
        Set tPrepareSC = tStatement.%Prepare(pText, 1)
        If $$$ISERR(tPrepareSC) || (+tStatement.%Metadata.statementType '= +pType) {
            Do pRaw.%Set("changed", 1, "boolean")
            Set tStatement = ""
            Set $NAMESPACE = tOrigNS
            Quit
        }
        Kill tArgs
        Set tArgs = tStatement.%Metadata.parameters.Count()
        Set tNext = 0
        For tI = 1:1:tArgs {
            Set tPositionType = tStatement.%Metadata.parameters.GetAt(tI).columnType
            If (tPositionType = 4) || (tPositionType = 5) Continue
            If tNext < pValues.%Size() Set tArgs(tI) = pValues.%Get(tNext)
            Set tNext = tNext + 1
        }
        If pBound > 0 {
            Do $System.Alarm.Set(pBound)
            Set tAlarmed = 1
        }
        Set tResult = tStatement.%Execute(tArgs...)
        Kill tArgs
        Set tCode = tResult.%SQLCODE
        Set tMessage = tResult.%Message
        Set tRowCount = tResult.%ROWCOUNT
        If pFetch && (tCode >= 0) {
            Set tSet = $Select(+pType = 45: tResult.%NextResult(), 1: tResult)
            If $IsObject(tSet) {
                Set tColumns = []
                Set tMeta = $Select(+pType = 45: tSet.%GetMetadata(), 1: tStatement.%Metadata)
                For tI = 1:1:tMeta.columns.Count() {
                    Do tColumns.%Push(tMeta.columns.GetAt(tI).colName, "string")
                }
                Set tWidth = tColumns.%Size()
                Set tRows = []
                Set tTotal = 0
                Set tTruncated = 0
                While tSet.%Next() {
                    If tRows.%Size() >= pMaxRows {
                        Set tTruncated = 1
                        Quit
                    }
                    Set tRow = []
                    For tI = 1:1:tWidth {
                        Set tValue = tSet.%GetData(tI)
                        If $IsObject(tValue) Set tValue = ""
                        If $Length(tValue) > ..#MAXCELL {
                            Set tValue = $Extract(tValue, 1, ..#MAXCELL - 1) _ $Char(8230)
                            Set tTruncated = 1
                        }
                        Do tRow.%Push(tValue, "string")
                    }
                    Set tLength = $Length(tRow.%ToJSON())
                    If tTotal + tLength > ..#MAXANSWER {
                        Set tTruncated = 1
                        Quit
                    }
                    Set tTotal = tTotal + tLength
                    Do tRows.%Push(tRow)
                }
                If tSet.%SQLCODE < 0 {
                    Set tCode = tSet.%SQLCODE
                    Set tMessage = tSet.%Message
                }
                Do pRaw.%Set("columns", tColumns)
                Do pRaw.%Set("rows", tRows)
                Do pRaw.%Set("truncated", tTruncated, "boolean")
            }
        }
        If tAlarmed {
            Do $System.Alarm.Clear()
            Set tAlarmed = 0
            If (tCode = ..#ALARMSQLCODE) || ((tCode < 0) && (tMessage [ "<ALARM>")) Do pRaw.%Set("stopped", 1, "boolean")
        }
        Do pRaw.%Set("sqlcode", +tCode, "number")
        Do pRaw.%Set("message", tMessage, "string")
        Do pRaw.%Set("rowCount", +tRowCount, "number")
        If $TLevel > tLevel {
            While $TLevel > tLevel {
                TRollback 1
            }
            Do pRaw.%Set("rolledBack", 1, "boolean")
        }
        Set (tSet, tMeta, tResult, tStatement) = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        If tAlarmed Do $System.Alarm.Clear()
        Set (tSet, tMeta, tResult) = ""
        Do ..Closed(pNamespace, .tStatement)
        Set tRolledBack = 0
        While $TLevel > tLevel {
            TRollback 1
            Set tRolledBack = 1
        }
        Do pRaw.%Set("rolledBack", tRolledBack, "boolean")
        If ex.Name = "<ALARM>" {
            Do pRaw.%Set("stopped", 1, "boolean")
        } ElseIf ex.%IsA("%Exception.SQL") {
            Do pRaw.%Set("sqlcode", +ex.Code, "number")
            Do pRaw.%Set("message", ex.Data, "string")
        } Else {
            Set tSC = $$$ERROR($$$GeneralError, "the run raised " _ ex.Name)
        }
    }
    Quit tSC
}

/// <p>The plan of <var>pText</var> in <var>pNamespace</var>, from <code>$SYSTEM.SQL.Explain</code>
/// with its output silenced, in <var>pPlan</var>; when the instance refuses it, <var>pCode</var> and
/// <var>pMessage</var> carry its SQLCODE and message and <var>pPlan</var> is empty. Explain executes
/// nothing (measured). The switched region calls vendor classes only.</p>
ClassMethod Explained(pNamespace As %String, pText As %String, Output pPlan As %String, Output pCode As %String, Output pMessage As %String) As %Status [ Private ]
{
    Set pPlan = ""
    Set pCode = ""
    Set pMessage = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tText = pText
        Set tPlan = ""
        Set tExplainSC = $SYSTEM.SQL.Explain(.tText, {"silent": 1}, , .tPlan)
        If $$$ISERR(tExplainSC) {
            Set tMessage = ""
            Set pCode = $System.Status.StatusToSQLCODE(tExplainSC, .tMessage)
            Set pMessage = tMessage
        } Else {
            Set pPlan = $Get(tPlan)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pPlan = ""
        Set tSC = $$$ERROR($$$GeneralError, "the plan read raised " _ ex.Name)
    }
    Quit tSC
}

/// <p>Whether the caller holds the system privilege <var>pPrivilege</var>, a name from
/// <parameter>DDLPRIVILEGES</parameter>, in <var>pNamespace</var>, read at this call from the instance
/// with <code>%CHECKPRIV</code>, which the instance never answers from a cached query: SQLCODE 0 is
/// held and 100 is not. Any other answer is an error status naming its SQLCODE. The switched region
/// calls vendor classes only.</p>
ClassMethod HoldsPrivilege(pNamespace As %String, pPrivilege As %String, Output pHolds As %Boolean) As %Status [ Private ]
{
    Set pHolds = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "%CHECKPRIV " _ pPrivilege)
        Set tCode = tResult.%SQLCODE
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
        If tCode = 0 {
            Set pHolds = 1
        } ElseIf tCode '= 100 {
            Set tSC = $$$ERROR($$$GeneralError, "the privilege check answered SQLCODE " _ tCode)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pHolds = 0
        Set tSC = $$$ERROR($$$GeneralError, "the privilege check raised " _ ex.Name)
    }
    Quit tSC
}

/// <p>Release <var>pStatement</var> in <var>pNamespace</var>, its own namespace. A statement of a
/// type the instance prepares for one use purges its cached query as it closes, in the namespace it
/// closes in; closed in another, that cached query outlives it and answers a later prepare of the same
/// text without the privilege check its compile makes (measured). A caller releases every other
/// reference to the statement first.</p>
ClassMethod Closed(pNamespace As %String, ByRef pStatement) [ Private ]
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set pStatement = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set pStatement = ""
    }
}

/// <p>The privilege refusal naming <var>pFailedPair</var> (AD-8, AD-39).</p>
ClassMethod Deny(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDenial = ##class(OcuPilot.Kernel.Denial).Detail(pFailedPair)
    Quit ..Refuse(##class(OcuPilot.Kernel.Denial).#STATUS, ##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason(), .pHttpStatus, .pFault, tDenial)
}

/// <p>A refusal this port decided, with a written reason. <var>pDetail</var>, when supplied, becomes
/// the fault's <code>detail</code> (AD-39).</p>
ClassMethod Refuse(pHttp As %Integer, pSlug As %String, pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pDetail As %DynamicObject = "") As %Status [ Private ]
{
    Set pHttpStatus = pHttp
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(pSlug, pCode, pReason)
    If $IsObject(pDetail) Do pFault.%Set("detail", pDetail)
    Quit $$$ERROR($$$GeneralError, pCode _ ": " _ pReason)
}

/// <p>An unexpected failure: the generic internal fault on the wire, and to the log a line naming
/// <var>pMessage</var> and <var>pStatus</var>, which every caller here builds from an exception's name
/// and never from a statement, a value or a message the instance answered.</p>
ClassMethod Fail(pMessage As %String, pStatus As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 500
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, pFault.code)
    Quit $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
}

/// <p><var>pValue</var> as an ObjectScript string literal, a control character spelled as a
/// <code>$Char</code>.</p>
ClassMethod Literal(pValue As %String) As %String [ Private ]
{
    Set tText = """" _ $Replace(pValue, """", """""") _ """"
    For tCode = 0:1:31 {
        If tText [ $Char(tCode) Set tText = $Replace(tText, $Char(tCode), """_$Char(" _ tCode _ ")_""")
    }
    Quit tText
}

}
