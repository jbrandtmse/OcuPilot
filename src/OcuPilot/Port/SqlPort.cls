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
/// through the closed table <method>KindOf</method>; then the refusal of a query or a DML statement
/// the statement index does not record; then the refusal of the session, administration
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
/// <p><b>The data browser reads a table's or a view's rows here too</b> (AD-61's Story 19.7 case):
/// <method>BrowsePlan</method> resolves the request through the caller's own privilege-filtered
/// catalog and composes the page and count statements (<method>Composed</method>);
/// <method>BrowseRun</method> runs them. Both pass the gate first, prepare with privilege checks on
/// through <method>Executed</method> under one alarm budget, bind every value, and never pass through
/// <method>Classify</method>. Their rows, SQLCODE and message reach the caller's answer alone.</p>
/// <p><b>The data browser saves a table's staged rows here too</b> (AD-61's Story 19.8 case):
/// <method>SavePlan</method> answers the save's fresh read, and <method>Save</method> resolves the
/// table as <method>BrowsePlan</method> does and runs one port-composed statement per staged row
/// (<method>SaveComposed</method>) through <method>Executed</method> under one alarm budget, each row's
/// outcome the instance's own row count. Its keys, values, SQLCODEs and messages reach the caller's
/// answer alone.</p>
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

/// <p>The writes this port composes from the caller's declared values, as <code>endpoint/type</code>
/// (AD-51): the run, from its statement, values and Max rows; and the data browser's save, from its
/// schema, table and staged changes.</p>
Parameter COMPOSEDTYPES = "Sql/RUN,SqlData/RUN";

/// <p>The data browser's save (Story 19.8): its endpoint, and its fresh read, the plan of the table
/// it writes (<method>SavePlan</method>); its write is <parameter>TYPERUN</parameter>
/// (<method>Save</method>).</p>
Parameter ENDPOINTDATA = "SqlData";

Parameter TYPEPLAN = "PLAN";

/// <p>The query keys: the namespace, the target id (always <parameter>IDVALUE</parameter>), the
/// statement, its values as JSON array text, and the row cap.</p>
Parameter NAMESPACEKEY = "namespace";

Parameter IDKEY = "id";

Parameter IDVALUE = "sql";

Parameter STATEMENTKEY = "statement";

Parameter PARAMETERSKEY = "parameters";

Parameter MAXROWSKEY = "maxRows";

/// <p>The save's query keys: the table's schema and name, and its staged changes as JSON array
/// text.</p>
Parameter SCHEMAKEY = "schema";

Parameter TABLEKEY = "table";

Parameter CHANGESKEY = "changes";

/// <p>The class the gate evaluates through.</p>
Parameter GATECLASS = "OcuPilot.Screen.Gate";

/// <p>The bounds a request is held to before anything is prepared.</p>
Parameter MAXSTATEMENT As INTEGER = 100000;

Parameter MAXVALUES As INTEGER = 100;

Parameter MAXVALUE As INTEGER = 32767;

Parameter MAXROWS As INTEGER = 1000;

/// <p>The bounds a save is held to: the staged rows it carries, and the characters of its changes'
/// JSON text. Each value is held to <parameter>MAXVALUE</parameter>.</p>
Parameter MAXCHANGES As INTEGER = 100;

Parameter MAXCHANGESTEXT As INTEGER = 1000000;

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

/// <p>The keyword and the value after it that <method>MaskCredentials</method> masks: <code>IDENTIFY BY</code>,
/// <code>IDENTIFIED BY</code> or <code>PASSWORD</code>, an <code>=</code> after it if any, then a single-quoted literal (a doubled quote
/// inside it stays inside), a double-quoted identifier, or a bare token. A literal or identifier a cut
/// left unterminated runs to the end of the text. A lone <code>?</code> is a bound value and is left.</p>
Parameter CREDENTIALVALUEPATTERN = "(?is)\b(?:IDENTIF(?:Y|IED)\s+BY|PASSWORD)\b\s*(?:=\s*)?('(?:[^']|'')*'?|""(?:[^""]|"""")*""?|[^\s,;()'""?][^\s,;()]*)";

/// <p>The keyword, an <code>=</code> after it if any, and the white space around them, anchored at the start of a
/// <parameter>CREDENTIALVALUEPATTERN</parameter> match.</p>
Parameter CREDENTIALKEYWORDPATTERN = "(?is)^(?:IDENTIF(?:Y|IED)\s+BY|PASSWORD)\b\s*(?:=\s*)?";

/// <p>What a masked credential value reads.</p>
Parameter CREDENTIALMASK = "[redacted]";

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

/// <p>The statement types that create code the instance later runs: CREATE FUNCTION (35), METHOD
/// (36), PROCEDURE (37), QUERY (38), TRIGGER (43) and AGGREGATE (67) (Story 19.11). The agent is
/// refused a statement of one of them (<method>CarriesCode</method>); a person's own run is not.</p>
Parameter CODETYPES = "35,36,37,38,43,67";

/// <p>The word a CREATE or ALTER TABLE statement names to carry ObjectScript in a computed
/// field.</p>
Parameter CODEWORD = "COMPUTECODE";

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

/// <p>The data browser's kind for each column type the catalog spells (Story 19.7), as
/// <code>kind=type,type</code> groups: the <code>INFORMATION_SCHEMA.COLUMNS.DATA_TYPE</code> spellings
/// the instance answers for the DDL types, read on the instance. A type no group names is
/// <code>text</code>.</p>
Parameter KINDS = "number=tinyint,smallint,integer,bigint,numeric,double;boolean=bit;date=date;time=time;timestamp=timestamp;stream=longvarchar;binary=varbinary,longvarbinary";

/// <p>The data browser's request keys, its sort's two keys and its two directions.</p>
Parameter BROWSESCHEMAKEY = "schema";

Parameter BROWSETABLEKEY = "table";

Parameter BROWSEFILTERSKEY = "filters";

Parameter BROWSESORTKEY = "sort";

Parameter BROWSEOFFSETKEY = "offset";

Parameter BROWSESIZEKEY = "size";

Parameter BROWSECOLUMNKEY = "column";

Parameter BROWSEDIRECTIONKEY = "direction";

Parameter BROWSEDIRECTIONS = "asc,desc";

/// <p>The data browser's request bounds: a schema, table or column name, a filter value, the
/// filters, the offset, and the page sizes with the default.</p>
Parameter MAXNAME As INTEGER = 128;

Parameter MAXFILTER As INTEGER = 1000;

Parameter MAXFILTERS As INTEGER = 100;

Parameter MAXOFFSET As INTEGER = 99999999;

Parameter PAGESIZES = "50,100,250,500";

Parameter PAGESIZE As INTEGER = 100;

/// <p>What a stream column's select reads, one character past a cell's cut, and what a binary
/// column's select reads, one byte past the 499 a cell shows.</p>
Parameter STREAMCHARS As INTEGER = 1001;

Parameter BINARYBYTES As INTEGER = 500;

/// <p>The rows a data browser catalog read keeps: a table with more columns than this is refused
/// rather than shown in part.</p>
Parameter MAXCOLUMNS As INTEGER = 1000;

/// <p>The data browser's fixed catalog statements, each sent with its values bound (AD-21,
/// AD-61): the one table or view a request names, its columns in ordinal order, and its first
/// primary key's columns. Each reads the caller's own privilege-filtered catalog.</p>
Parameter BROWSETABLEQUERY = "SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?";

Parameter BROWSECOLUMNSQUERY = "SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, IS_IDENTITY, IS_GENERATED FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? ORDER BY ORDINAL_POSITION";

Parameter BROWSEKEYQUERY = "SELECT k.COLUMN_NAME, c.CONSTRAINT_NAME FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS c JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE k ON k.CONSTRAINT_SCHEMA = c.CONSTRAINT_SCHEMA AND k.CONSTRAINT_NAME = c.CONSTRAINT_NAME AND k.TABLE_SCHEMA = c.TABLE_SCHEMA AND k.TABLE_NAME = c.TABLE_NAME WHERE c.TABLE_SCHEMA = ? AND c.TABLE_NAME = ? AND c.CONSTRAINT_TYPE = 'PRIMARY KEY' ORDER BY c.CONSTRAINT_NAME, k.ORDINAL_POSITION";

/// <p>The catalog's table types that are views.</p>
Parameter VIEWTYPES = "VIEW,SYSTEM VIEW";

/// <p>The column a table without a declared key or an identity column is keyed by, when it lists
/// one.</p>
Parameter ROWIDCOLUMN = "ID";

/// <p>A staged change's three operations (Story 19.8).</p>
Parameter OPUPDATE = "update";

Parameter OPINSERT = "insert";

Parameter OPDELETE = "delete";

/// <p>The statement type each operation prepares as, which <method>Executed</method> checks again
/// before it runs.</p>
Parameter STATEMENTINSERT As INTEGER = 2;

Parameter STATEMENTUPDATE As INTEGER = 3;

Parameter STATEMENTDELETE As INTEGER = 4;

/// <p>A staged row's outcomes: the instance changed it; an update or a delete matched no row; the
/// instance refused the caller the statement (<parameter>PRIVILEGESQLCODE</parameter>); any other
/// SQL error; the row the budget interrupted; and every row after it.</p>
Parameter ROWSAVED = "saved";

Parameter ROWCHANGED = "changed";

Parameter ROWGONE = "gone";

Parameter ROWREFUSED = "refused";

Parameter ROWERROR = "error";

Parameter ROWSTOPPED = "stopped";

Parameter ROWSKIPPED = "skipped";

/// <p>The outcome a save answers once its rows ran, whatever each row's own.</p>
Parameter OUTCOMESAVED = "saved";

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

/// <p>Whether a statement of type <var>pType</var> and text <var>pText</var> carries code the
/// instance would later run: its type is one of <parameter>CODETYPES</parameter>, or its text holds
/// <parameter>CODEWORD</parameter> in any case (Story 19.11). Fail-closed: it also reads the word in a
/// literal or a comment. Pure.</p>
ClassMethod CarriesCode(pType As %String, pText As %String) As %Boolean
{
    If (pType '= "") && $Match(pType, "^[0-9]+$") && $ListFind($ListFromString(..#CODETYPES), +pType) Quit 1
    Quit ($ZConvert(pText, "U") [ ..#CODEWORD)
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

/// <p><var>pText</var>, a statement's text as the instance holds or runs it, with the value after each
/// <code>IDENTIFY BY</code>, <code>IDENTIFIED BY</code> and <code>PASSWORD</code> replaced by
/// <parameter>CREDENTIALMASK</parameter> (<parameter>CREDENTIALVALUEPATTERN</parameter>). A text
/// <parameter>PASSWORDPATTERN</parameter> does not match comes back unchanged. Pure.</p>
ClassMethod MaskCredentials(pText As %String) As %String
{
    If '$Locate(pText, ..#PASSWORDPATTERN) Quit pText
    Set tOut = ""
    Set tPos = 1
    While tPos <= $Length(pText) {
        Set tStart = $Locate(pText, ..#CREDENTIALVALUEPATTERN, tPos, tEnd, tMatch)
        If 'tStart Quit
        Set tKeywordStart = $Locate(tMatch, ..#CREDENTIALKEYWORDPATTERN, 1, tKeywordEnd)
        Set tOut = tOut _ $Extract(pText, tPos, tStart - 1) _ $Extract(tMatch, 1, tKeywordEnd - 1) _ ..#CREDENTIALMASK
        Set tPos = tEnd
    }
    Quit tOut _ $Extract(pText, tPos, *)
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
/// <code>EXPLORER.SQL.PASSWORD</code>; 422 <code>EXPLORER.SQL.UNRECORDED</code> for a query or a DML
/// statement the statement index holds no row for once prepared, whose tables the self-protection
/// check therefore cannot read; 422 <code>EXPLORER.SQL.SESSION</code>, <code>.ADMINISTRATION</code> or
/// <code>.SERVERFILES</code>; and 500 <code>INTERNAL</code> when the statement index cannot be read
/// for a query or a DML statement.</p>
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
        ; Fail closed: a query or a DML statement whose statement-index row is absent or unreadable has
        ; tables nobody can read, which the self-protection check needs, so it never runs.
        If (tKind = ..#KINDQUERY) || (tKind = ..#KINDDML) {
            If tRaw.%Get("unrecorded") {
                Set tSC = ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AtelierError).#SQLUNRECORDED, ##class(OcuPilot.Api.AtelierError).#REASONSQLUNRECORDED, .pHttpStatus, .pFault)
                Quit
            }
            If 'tRaw.%Get("indexed") {
                Set tSC = ..Fail("the statement index could not be read for a prepared statement", $$$ERROR($$$GeneralError, "statement index unreadable"), .pHttpStatus, .pFault)
                Quit
            }
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

/// <p>Serve <var>pEndpoint</var> (<parameter>ENDPOINTSQL</parameter> or
/// <parameter>ENDPOINTDATA</parameter>) for request type <var>pType</var>, the write path's way in
/// (AD-51, AD-52). <var>pQuery</var> carries <code>id</code>, which must be
/// <parameter>IDVALUE</parameter>; <code>namespace</code>, or the request's resolved scope where it is
/// absent; for the console, <code>statement</code>, <code>parameters</code> (JSON array text) and
/// <code>maxRows</code>; for the data browser's save, <code>schema</code>, <code>table</code> and
/// <code>changes</code> (JSON array text). <var>pBody</var> is not read.</p>
/// <p>For the console, <parameter>TYPEGUARD</parameter> answers <method>Classify</method>'s guard with
/// <code>statement</code>, <code>parameters</code> and <code>maxRows</code> <code>null</code> beside
/// it, or, with no statement, the empty guard after the gate alone; <parameter>TYPERUN</parameter>
/// answers <method>Run</method>'s answer in <code>write</code> mode. For the save,
/// <parameter>TYPEPLAN</parameter> answers <method>SavePlan</method> and <parameter>TYPERUN</parameter>
/// <method>Save</method>. Any other endpoint or type is 501 <code>PORT.NOTIMPLEMENTED</code>, and any
/// other id 404 <code>PORT.NOTFOUND</code>, before any call.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Set tServed = ((pEndpoint = ..#ENDPOINTSQL) && ((pType = ..#TYPEGUARD) || (pType = ..#TYPERUN))) || ((pEndpoint = ..#ENDPOINTDATA) && ((pType = ..#TYPEPLAN) || (pType = ..#TYPERUN)))
        If 'tServed {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ##class(OcuPilot.Port.AtelierPort).#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
            Quit
        }
        If $ZConvert($Get(pQuery(..#IDKEY)), "L") '= ..#IDVALUE {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, ##class(OcuPilot.Port.AtelierPort).#REASONNOTFOUND, .pHttpStatus, .pFault)
            Quit
        }
        Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
        If tNamespace = "" Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        If pEndpoint = ..#ENDPOINTDATA {
            If pType = ..#TYPEPLAN {
                Set tSC = ..SavePlan(tNamespace, .pQuery, .pResult, .pHttpStatus, .pFault)
            } Else {
                Set tSC = ..Save(tNamespace, .pQuery, .pResult, .pHttpStatus, .pFault)
            }
            If $$$ISOK(tSC) Set pHttpStatus = 200
            Quit
        }
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

/// <p><code>objectscript</code> for <parameter>TYPERUN</parameter> of either endpoint, the two writes
/// this port carries; <code>""</code> for the reads, which have no script form (AD-59).</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If ((pEndpoint = ..#ENDPOINTSQL) || (pEndpoint = ..#ENDPOINTDATA)) && (pType = ..#TYPERUN) Quit "objectscript"
    Quit ""
}

/// <p><method>Invoke</method>'s <parameter>TYPERUN</parameter> as a script (AD-59), in the namespace
/// <code>namespace</code> names: the statement prepared with privilege checks on in ODBC select mode,
/// each value bound at the next position that takes one, as <method>Executed</method> binds it, then
/// executed, and its SQLCODE, message and row count shown. Every value is rendered as a string
/// literal, so nothing the query carries runs as code. The data browser's save renders as
/// <method>SaveSnippet</method> does.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If ..SnippetForm(pEndpoint, pType) = "" Quit []
    If pEndpoint = ..#ENDPOINTDATA Quit ..SaveSnippet(.pQuery)
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
/// instance says of it: <code>{type, positions, columns, unrecorded, indexed, tables,
/// defaultSchema}</code>, or <code>{error: {sqlcode, message}}</code> when the prepare failed.
/// <code>tables</code> is the statement index's relations for the statement, keyed by the cached
/// query's <code>%StatementIndexHash</code>, else by its <code>STATEMENT_LOCATIONS</code> row
/// <code>&lt;class&gt;.1</code>, then each view's base tables from
/// <code>INFORMATION_SCHEMA.VIEW_TABLE_USAGE</code>. <code>unrecorded</code> is 1 when the index was
/// read and holds no row for the statement, as for a query the instance compiles with runtime plan
/// choice, whose row it writes only when the query runs (measured); <code>indexed</code> is 0 when the
/// row is absent or it or its relations cannot be read.</p>
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
            Set tUnrecorded = 0
            If tClass '= "" Set tHash = $Parameter(tClass, "%StatementIndexHash")
            If (tHash = "") && (tClass '= "") {
                Set tLocation = ##class(%SQL.Statement).%ExecDirect(, "SELECT Statement FROM INFORMATION_SCHEMA.STATEMENT_LOCATIONS WHERE Location = ?", tClass _ ".1")
                If (tLocation.%SQLCODE >= 0) && tLocation.%Next() Set tHash = tLocation.%GetData(1)
                Set tUnrecorded = (tHash = "") && (tLocation.%SQLCODE >= 0)
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
            Do pRaw.%Set("unrecorded", tUnrecorded, "boolean")
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
/// <p><var>pRaw</var> is <code>{sqlcode, message, rowCount, columns?, rows?, truncated?, more?, cut?,
/// stopped, rolledBack, changed}</code>: <code>more</code> when a fetched row was not kept, past
/// <var>pMaxRows</var> or dropped by the answer's cut, and <code>cut</code> when a cell was cut, the
/// two parts of <code>truncated</code>; <code>stopped</code> when the alarm stopped the run,
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
                Set tMore = 0
                Set tCut = 0
                While tSet.%Next() {
                    If tRows.%Size() >= pMaxRows {
                        Set tTruncated = 1
                        Set tMore = 1
                        Quit
                    }
                    Set tRow = []
                    For tI = 1:1:tWidth {
                        Set tValue = tSet.%GetData(tI)
                        If $IsObject(tValue) Set tValue = ""
                        If $Length(tValue) > ..#MAXCELL {
                            Set tValue = $Extract(tValue, 1, ..#MAXCELL - 1) _ $Char(8230)
                            Set tTruncated = 1
                            Set tCut = 1
                        }
                        Do tRow.%Push(tValue, "string")
                    }
                    Set tLength = $Length(tRow.%ToJSON())
                    If tTotal + tLength > ..#MAXANSWER {
                        Set tTruncated = 1
                        Set tMore = 1
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
                Do pRaw.%Set("more", tMore, "boolean")
                Do pRaw.%Set("cut", tCut, "boolean")
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

/// <p>The refusal an agent tool answers for <var>pWhich</var>, with the code and sentence this port
/// publishes (Story 19.11): <code>input</code> (400 <code>EXPLORER.SQL.INPUT</code>),
/// <code>changes</code> (422 <code>EXPLORER.SQL.CHANGES</code>), <code>reads</code> (422
/// <code>EXPLORER.SQL.READS</code>), <code>agentcode</code> (422 <code>EXPLORER.SQL.AGENTCODE</code>),
/// <code>notprepared</code> (422 <code>EXPLORER.SQL.NOTPREPARED</code>) and <code>parameters</code>
/// (422 <code>EXPLORER.SQL.PARAMETERS</code>), <var>pDetail</var> becoming the fault's
/// <code>detail</code> when supplied. A tool names this method rather than the error class, which only
/// a port may name.</p>
ClassMethod RefuseFor(pWhich As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pDetail As %DynamicObject = "") As %Status
{
    Set tError = "OcuPilot.Api.AtelierError"
    If pWhich = "input" Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, $Parameter(tError, "SQLINPUT"), $Parameter(tError, "REASONSQLINPUT"), .pHttpStatus, .pFault, pDetail)
    Set tSlug = ##class(OcuPilot.Api.Error).#VALIDATIONFAILED
    If pWhich = "changes" Quit ..Refuse(422, tSlug, $Parameter(tError, "SQLCHANGES"), $Parameter(tError, "REASONSQLCHANGES"), .pHttpStatus, .pFault, pDetail)
    If pWhich = "reads" Quit ..Refuse(422, tSlug, $Parameter(tError, "SQLREADS"), $Parameter(tError, "REASONSQLREADS"), .pHttpStatus, .pFault, pDetail)
    If pWhich = "agentcode" Quit ..Refuse(422, tSlug, $Parameter(tError, "SQLAGENTCODE"), $Parameter(tError, "REASONSQLAGENTCODE"), .pHttpStatus, .pFault, pDetail)
    If pWhich = "notprepared" Quit ..Refuse(422, tSlug, $Parameter(tError, "SQLNOTPREPARED"), $Parameter(tError, "REASONSQLNOTPREPARED"), .pHttpStatus, .pFault, pDetail)
    If pWhich = "parameters" Quit ..Refuse(422, tSlug, $Parameter(tError, "SQLPARAMETERS"), $Parameter(tError, "REASONSQLPARAMETERS"), .pHttpStatus, .pFault, pDetail)
    Quit ..Fail("an agent tool asked for a refusal the port does not publish", $$$ERROR($$$GeneralError, pWhich), .pHttpStatus, .pFault)
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

/// <p>The data browser's kind (Story 19.7) of a column whose catalog <code>DATA_TYPE</code> is
/// <var>pDataType</var>, from <parameter>KINDS</parameter>, ignoring case: <code>number</code>,
/// <code>boolean</code>, <code>date</code>, <code>time</code>, <code>timestamp</code>,
/// <code>stream</code>, <code>binary</code>, or <code>text</code> for every type no group names.
/// Pure.</p>
ClassMethod KindOfType(pDataType As %String) As %String
{
    Set tType = $ZConvert(pDataType, "L")
    If tType = "" Quit "text"
    For tI = 1:1:$Length(..#KINDS, ";") {
        Set tGroup = $Piece(..#KINDS, ";", tI)
        If $ListFind($ListFromString($Piece(tGroup, "=", 2)), tType) Return $Piece(tGroup, "=", 1)
    }
    Quit "text"
}

/// <p><var>pName</var> as a delimited identifier: wrapped in <code>"</code>, each <code>"</code> in
/// it doubled. The data browser emits every identifier this way, and only in the catalog's own
/// spelling (AD-21). Pure.</p>
ClassMethod Quoted(pName As %String) As %String
{
    Quit """" _ $Replace(pName, """", """""") _ """"
}

/// <p><var>pText</var>, a data browser filter, as the value a <code>LIKE ? ESCAPE '\'</code> binds:
/// <code>\</code>, <code>%</code> and <code>_</code> each escaped with <code>\</code>, so they match
/// themselves, then <code>*</code> mapped to <code>%</code> and <code>?</code> to <code>_</code>. The
/// whole value must match. Pure.</p>
ClassMethod LikeValue(pText As %String) As %String
{
    Set tOut = ""
    For tI = 1:1:$Length(pText) {
        Set tChar = $Extract(pText, tI)
        If (tChar = "\") || (tChar = "%") || (tChar = "_") {
            Set tOut = tOut _ "\" _ tChar
        } ElseIf tChar = "*" {
            Set tOut = tOut _ "%"
        } ElseIf tChar = "?" {
            Set tOut = tOut _ "_"
        } Else {
            Set tOut = tOut _ tChar
        }
    }
    Quit tOut
}

/// <p>Whether <var>pText</var> is a name the data browser takes: a string of 1 to
/// <parameter>MAXNAME</parameter> characters with no control character. Pure.</p>
ClassMethod BrowseName(pText) As %Boolean
{
    If $IsObject(pText) Quit 0
    If ($Length(pText) < 1) || ($Length(pText) > ..#MAXNAME) Quit 0
    Quit ($ZStrip(pText, "*C") = pText)
}

/// <p>Read <var>pBody</var>, a data browser request (Story 19.7), into <var>pRequest</var>,
/// answering 0 for any shape outside its closed keys and bounds. The body is
/// <code>{schema, table, filters?, sort?, offset?, size?}</code>: <code>schema</code> and
/// <code>table</code> names (<method>BrowseName</method>); <code>filters</code> an object mapping a
/// name to a string of 1 to <parameter>MAXFILTER</parameter> characters, at most
/// <parameter>MAXFILTERS</parameter> entries; <code>sort</code> <code>{column, direction}</code>, the
/// direction <code>asc</code> or <code>desc</code>; <code>offset</code> a whole number from 0 to
/// <parameter>MAXOFFSET</parameter> (0 when absent); <code>size</code> one of
/// <parameter>PAGESIZES</parameter> (<parameter>PAGESIZE</parameter> when absent). An absent or
/// <code>null</code> <code>filters</code> or <code>sort</code> is none.</p>
/// <p><var>pRequest</var> is <code>{schema, table, filters: [{column, value}], sort: {column,
/// direction} | null, offset, size}</code>, the filters in the body's order. Pure.</p>
ClassMethod BrowseRequest(pBody, Output pRequest As %DynamicObject) As %Boolean
{
    Set pRequest = ""
    If '$IsObject($Get(pBody)) || 'pBody.%IsA("%Library.DynamicObject") Quit 0
    Set tKeys = $ListBuild(..#BROWSESCHEMAKEY, ..#BROWSETABLEKEY, ..#BROWSEFILTERSKEY, ..#BROWSESORTKEY, ..#BROWSEOFFSETKEY, ..#BROWSESIZEKEY)
    Set tStray = 0
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If '$ListFind(tKeys, tKey) Set tStray = 1
    }
    If tStray Quit 0
    For tKey = ..#BROWSESCHEMAKEY, ..#BROWSETABLEKEY {
        If (pBody.%GetTypeOf(tKey) '= "string") || '..BrowseName(pBody.%Get(tKey)) Return 0
    }
    Set tFilters = []
    Set tType = pBody.%GetTypeOf(..#BROWSEFILTERSKEY)
    If tType = "object" {
        Set tGiven = pBody.%Get(..#BROWSEFILTERSKEY)
        Set tBad = 0
        Set tIterator = tGiven.%GetIterator()
        While tIterator.%GetNext(.tColumn, .tValue) {
            If '..BrowseName(tColumn) || (tGiven.%GetTypeOf(tColumn) '= "string") || ($Length(tValue) < 1) || ($Length(tValue) > ..#MAXFILTER) || (tFilters.%Size() >= ..#MAXFILTERS) {
                Set tBad = 1
                Quit
            }
            Set tFilter = {}
            Do tFilter.%Set(..#BROWSECOLUMNKEY, tColumn, "string")
            Do tFilter.%Set("value", tValue, "string")
            Do tFilters.%Push(tFilter)
        }
        If tBad Quit 0
    } ElseIf (tType '= "unassigned") && (tType '= "null") {
        Quit 0
    }
    Set tSort = ""
    Set tType = pBody.%GetTypeOf(..#BROWSESORTKEY)
    If tType = "object" {
        Set tGiven = pBody.%Get(..#BROWSESORTKEY)
        Set tCount = 0
        Set tStray = 0
        Set tIterator = tGiven.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tCount = tCount + 1
            If (tKey '= ..#BROWSECOLUMNKEY) && (tKey '= ..#BROWSEDIRECTIONKEY) Set tStray = 1
        }
        If tStray || (tCount '= 2) Quit 0
        If (tGiven.%GetTypeOf(..#BROWSECOLUMNKEY) '= "string") || '..BrowseName(tGiven.%Get(..#BROWSECOLUMNKEY)) Quit 0
        If (tGiven.%GetTypeOf(..#BROWSEDIRECTIONKEY) '= "string") || '$ListFind($ListFromString(..#BROWSEDIRECTIONS), tGiven.%Get(..#BROWSEDIRECTIONKEY)) Quit 0
        Set tSort = {}
        Do tSort.%Set(..#BROWSECOLUMNKEY, tGiven.%Get(..#BROWSECOLUMNKEY), "string")
        Do tSort.%Set(..#BROWSEDIRECTIONKEY, tGiven.%Get(..#BROWSEDIRECTIONKEY), "string")
    } ElseIf (tType '= "unassigned") && (tType '= "null") {
        Quit 0
    }
    Set tOffset = 0
    Set tType = pBody.%GetTypeOf(..#BROWSEOFFSETKEY)
    If tType = "number" {
        Set tOffset = pBody.%Get(..#BROWSEOFFSETKEY)
        If '$Match(tOffset, "^(0|[1-9][0-9]{0,7})$") || (+tOffset > ..#MAXOFFSET) Quit 0
    } ElseIf tType '= "unassigned" {
        Quit 0
    }
    Set tSize = ..#PAGESIZE
    Set tType = pBody.%GetTypeOf(..#BROWSESIZEKEY)
    If tType = "number" {
        Set tSize = pBody.%Get(..#BROWSESIZEKEY)
        If '$Match(tSize, "^[1-9][0-9]{0,2}$") || '$ListFind($ListFromString(..#PAGESIZES), tSize) Quit 0
    } ElseIf tType '= "unassigned" {
        Quit 0
    }
    Set pRequest = {}
    Do pRequest.%Set(..#BROWSESCHEMAKEY, pBody.%Get(..#BROWSESCHEMAKEY), "string")
    Do pRequest.%Set(..#BROWSETABLEKEY, pBody.%Get(..#BROWSETABLEKEY), "string")
    Do pRequest.%Set(..#BROWSEFILTERSKEY, tFilters)
    If $IsObject(tSort) {
        Do pRequest.%Set(..#BROWSESORTKEY, tSort)
    } Else {
        Do pRequest.%Set(..#BROWSESORTKEY, "", "null")
    }
    Do pRequest.%Set(..#BROWSEOFFSETKEY, +tOffset, "number")
    Do pRequest.%Set(..#BROWSESIZEKEY, +tSize, "number")
    Quit 1
}

/// <p>The data browser's two statements (Story 19.7) for <var>pPlan</var>, a plan
/// <method>BrowsePlan</method> resolved: <code>{page, pageValues, count, countValues}</code>.</p>
/// <ul>
/// <li><code>page</code> is <code>SELECT &lt;columns&gt; FROM "&lt;schema&gt;"."&lt;name&gt;" [WHERE
/// ...] [ORDER BY ...] OFFSET ? ROWS FETCH NEXT ? ROWS ONLY</code>. The select list names each
/// column in ordinal order, a stream column as <code>SUBSTRING("col", 1, 1001) AS "col"</code> and a
/// binary one as <code>SUBSTRING("col", 1, 500) AS "col"</code>.</li>
/// <li>Each filter is <code>"col" LIKE ? ESCAPE '\'</code>, or <code>%ODBCOUT("col") LIKE ? ESCAPE
/// '\'</code> for a date, time or timestamp column, joined with <code>AND</code>.</li>
/// <li>The order is the sort column in its direction, then each key column ascending; with no sort,
/// the key columns, or none.</li>
/// <li><code>count</code> is <code>SELECT COUNT(*)</code> over the same <code>FROM</code> and
/// <code>WHERE</code>.</li>
/// </ul>
/// <p><code>pageValues</code> are each filter's <method>LikeValue</method> in order, then the offset
/// and the page size plus one; <code>countValues</code> the filters' alone. Every identifier is the
/// plan's catalog spelling, <method>Quoted</method>, and the direction is one of two words. Pure.</p>
/// <p>The filter and sort rules here and in <method>Quoted</method> and <method>LikeValue</method> are
/// ported from iris-table-editor v0.2.3 (MIT, <code>ui/licenses/iris-table-editor.txt</code>),
/// <code>packages/core/src/utils/SqlBuilder.ts</code> :30-47 and :107-201.</p>
ClassMethod Composed(pPlan As %DynamicObject) As %DynamicObject
{
    Set tFrom = ..Quoted(pPlan.%Get("table").%Get("schema")) _ "." _ ..Quoted(pPlan.%Get("table").%Get("name"))
    Set tSelect = ""
    Set tIterator = pPlan.%Get("columns").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tColumn) {
        Set tName = ..Quoted(tColumn.%Get("name"))
        Set tKind = tColumn.%Get("kind")
        If tKind = "stream" {
            Set tItem = "SUBSTRING(" _ tName _ ", 1, " _ ..#STREAMCHARS _ ") AS " _ tName
        } ElseIf tKind = "binary" {
            Set tItem = "SUBSTRING(" _ tName _ ", 1, " _ ..#BINARYBYTES _ ") AS " _ tName
        } Else {
            Set tItem = tName
        }
        Set tSelect = tSelect _ $Select(tSelect = "": "", 1: ", ") _ tItem
    }
    Set tWhere = ""
    Set tValues = []
    If pPlan.%GetTypeOf("filters") = "array" {
        Set tIterator = pPlan.%Get("filters").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tFilter) {
            Set tName = ..Quoted(tFilter.%Get(..#BROWSECOLUMNKEY))
            Set tKind = tFilter.%Get("kind")
            Set tOperand = $Select((tKind = "date") || (tKind = "time") || (tKind = "timestamp"): "%ODBCOUT(" _ tName _ ")", 1: tName)
            Set tWhere = tWhere _ $Select(tWhere = "": " WHERE ", 1: " AND ") _ tOperand _ " LIKE ? ESCAPE '\'"
            Do tValues.%Push(..LikeValue(tFilter.%Get("value")), "string")
        }
    }
    Set tOrder = ""
    Set tSorted = ""
    If pPlan.%GetTypeOf("sort") = "object" {
        Set tSorted = pPlan.%Get("sort").%Get(..#BROWSECOLUMNKEY)
        Set tOrder = ..Quoted(tSorted) _ " " _ $Case(pPlan.%Get("sort").%Get(..#BROWSEDIRECTIONKEY), "desc": "DESC", : "ASC")
    }
    If pPlan.%GetTypeOf("key") = "array" {
        Set tIterator = pPlan.%Get("key").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tKeyColumn) {
            If tKeyColumn = tSorted Continue
            Set tOrder = tOrder _ $Select(tOrder = "": "", 1: ", ") _ ..Quoted(tKeyColumn) _ " ASC"
        }
    }
    Set tComposed = {}
    Do tComposed.%Set("page", "SELECT " _ tSelect _ " FROM " _ tFrom _ tWhere _ $Select(tOrder = "": "", 1: " ORDER BY " _ tOrder) _ " OFFSET ? ROWS FETCH NEXT ? ROWS ONLY", "string")
    Set tPageValues = []
    Set tIterator = tValues.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        Do tPageValues.%Push(tValue, "string")
    }
    Do tPageValues.%Push(+pPlan.%Get(..#BROWSEOFFSETKEY), "number")
    Do tPageValues.%Push(pPlan.%Get(..#BROWSESIZEKEY) + 1, "number")
    Do tComposed.%Set("pageValues", tPageValues)
    Do tComposed.%Set("count", "SELECT COUNT(*) FROM " _ tFrom _ tWhere, "string")
    Do tComposed.%Set("countValues", tValues)
    Quit tComposed
}

/// <p>One data browser cell (Story 19.7) of a column of kind <var>pKind</var>, from the
/// <var>pValue</var> an ODBC-mode fetch answered: <code>""</code> is SQL NULL, answered with
/// <var>pNull</var> 1; <code>$Char(0)</code> is an empty value, answered as <code>""</code>; a binary
/// cell is <code>0x</code> and the upper-case hex of at most 499 of its bytes, ending in U+2026 with
/// <var>pCut</var> 1 when <parameter>BINARYBYTES</parameter> came back; anything else is itself.
/// Pure.</p>
ClassMethod CellOf(pKind As %String, pValue As %String, Output pNull As %Boolean, Output pCut As %Boolean) As %String
{
    Set pNull = 0
    Set pCut = 0
    If pValue = "" {
        Set pNull = 1
        Quit ""
    }
    If pValue = $Char(0) Quit ""
    If pKind '= "binary" Quit pValue
    Set tBytes = $Extract(pValue, 1, ..#BINARYBYTES - 1)
    Set tHex = "0x"
    For tI = 1:1:$Length(tBytes) {
        Set tHex = tHex _ $Translate($Justify($ZHex(+$Ascii(tBytes, tI)), 2), " ", "0")
    }
    If $Length(pValue) >= ..#BINARYBYTES {
        Set tHex = tHex _ $Char(8230)
        Set pCut = 1
    }
    Quit tHex
}

/// <p>Resolve a data browser request (Story 19.7), <var>pRequest</var> as
/// <method>BrowseRequest</method> answers it, in <var>pNamespace</var>, into <var>pPlan</var>: the
/// gate (<method>Gate</method>) first, then only the port's fixed catalog statements over the
/// caller's own privilege-filtered <code>INFORMATION_SCHEMA</code>, each through
/// <method>Executed</method> with its values bound, under what remains of one budget of
/// <method>BoundSeconds</method> whose start the plan keeps.</p>
/// <ul>
/// <li>Exactly one <code>TABLES</code> row names the table or view; none, or more, is 404
/// <code>EXPLORER.DATA.NOTFOUND</code>, unlogged. Its <code>COLUMNS</code> follow in ordinal order,
/// and none is the same 404.</li>
/// <li>The key is the first primary key constraint's columns, else the identity column, else a
/// column named <parameter>ROWIDCOLUMN</parameter>, and none unless every key column is
/// listed. <code>keyUnique</code> says whether it is the primary key or the identity column, each
/// naming one row; a column merely named <parameter>ROWIDCOLUMN</parameter> orders a page but may
/// repeat (Story 19.8).</li>
/// <li>Each filter and the sort must name a listed column exactly, of a kind other than
/// <code>stream</code> and <code>binary</code>; otherwise 400 <code>EXPLORER.DATA.INPUT</code>.</li>
/// <li>A view's base tables are those the statement index records for a <code>SELECT</code> of its
/// listed columns (<method>Prepared</method>), which a column grant on the view prepares; a text it
/// does not index fails closed, 500, logged. A view the instance will not prepare that select for
/// keeps the instance's answer as the plan's <code>error</code>.</li>
/// </ul>
/// <p><var>pPlan</var> is <code>{namespace, start, bound, table: {schema, name, type}, columns:
/// [{name, type, kind, nullable, key, identity, generated}], key, keyUnique, filters: [{column, kind, value}], sort, offset, size,
/// tables, page, pageValues, count, countValues}</code> (<method>Composed</method>), with
/// <code>stopped</code> when the budget ran out first and <code>error</code> as above.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9). No statement here is
/// classified (<method>Classify</method>), and nothing of a request, a row or the instance's SQL text
/// is logged.</p>
ClassMethod BrowsePlan(pNamespace As %String, pRequest As %DynamicObject, Output pPlan As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pPlan = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Set tPlan = {}
        Do tPlan.%Set("namespace", pNamespace, "string")
        Do tPlan.%Set("start", $ZHorolog, "number")
        Do tPlan.%Set("bound", ..BoundSeconds(), "number")
        Set tSC = ..Gate(pNamespace, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If '$IsObject($Get(pRequest)) || 'pRequest.%IsA("%Library.DynamicObject") || '..BrowseName(pRequest.%Get(..#BROWSESCHEMAKEY)) || '..BrowseName(pRequest.%Get(..#BROWSETABLEKEY)) {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AtelierError).#DATAINPUT, ##class(OcuPilot.Api.AtelierError).#REASONDATAINPUT, .pHttpStatus, .pFault)
            Quit
        }
        Set tTable = {}
        Do tTable.%Set("schema", pRequest.%Get(..#BROWSESCHEMAKEY), "string")
        Do tTable.%Set("name", pRequest.%Get(..#BROWSETABLEKEY), "string")
        Do tTable.%Set("type", "", "string")
        Do tPlan.%Set("table", tTable)
        Do tPlan.%Set("columns", [])
        Do tPlan.%Set("key", [])
        Do tPlan.%Set("tables", [])
        Do tPlan.%Set(..#BROWSEOFFSETKEY, +pRequest.%Get(..#BROWSEOFFSETKEY), "number")
        Do tPlan.%Set(..#BROWSESIZEKEY, $Select(+pRequest.%Get(..#BROWSESIZEKEY): +pRequest.%Get(..#BROWSESIZEKEY), 1: ..#PAGESIZE), "number")
        Set tSC = ..CatalogRows(pNamespace, tPlan, ..#BROWSETABLEQUERY, [(tTable.schema), (tTable.name)], .tRows, .tStopped, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If tStopped {
            Do tPlan.%Set("stopped", 1, "boolean")
            Set pPlan = tPlan
            Quit
        }
        If tRows.%Size() '= 1 {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.AtelierError).#DATANOTFOUND, ##class(OcuPilot.Api.AtelierError).#REASONDATANOTFOUND, .pHttpStatus, .pFault)
            Quit
        }
        Do tTable.%Set("schema", tRows.%Get(0).%Get(0), "string")
        Do tTable.%Set("name", tRows.%Get(0).%Get(1), "string")
        Do tTable.%Set("type", $Select($ListFind($ListFromString(..#VIEWTYPES), $ZConvert(tRows.%Get(0).%Get(2), "U")): "view", 1: "table"), "string")
        Set tSC = ..CatalogRows(pNamespace, tPlan, ..#BROWSECOLUMNSQUERY, [(tTable.schema), (tTable.name)], .tRows, .tStopped, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If tStopped {
            Do tPlan.%Set("stopped", 1, "boolean")
            Set pPlan = tPlan
            Quit
        }
        If tRows.%Size() = 0 {
            Set tSC = ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.AtelierError).#DATANOTFOUND, ##class(OcuPilot.Api.AtelierError).#REASONDATANOTFOUND, .pHttpStatus, .pFault)
            Quit
        }
        Set tColumns = []
        Set tIdentity = ""
        Set tRowId = ""
        Kill tKindOf
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tName = tRow.%Get(0)
            Set tColumn = {}
            Do tColumn.%Set("name", tName, "string")
            Do tColumn.%Set("type", tRow.%Get(1), "string")
            Do tColumn.%Set("kind", ..KindOfType(tRow.%Get(1)), "string")
            Do tColumn.%Set("nullable", ($ZConvert(tRow.%Get(2), "U") = "YES"), "boolean")
            Do tColumn.%Set("key", 0, "boolean")
            Do tColumn.%Set("identity", ($ZConvert(tRow.%Get(3), "U") = "YES"), "boolean")
            Do tColumn.%Set("generated", ($ZConvert(tRow.%Get(4), "U") = "YES"), "boolean")
            Do tColumns.%Push(tColumn)
            Set tKindOf(tName) = tColumn.%Get("kind")
            If (tIdentity = "") && ($ZConvert(tRow.%Get(3), "U") = "YES") Set tIdentity = tName
            If tName = ..#ROWIDCOLUMN Set tRowId = tName
        }
        Do tPlan.%Set("columns", tColumns)
        Set tSC = ..CatalogRows(pNamespace, tPlan, ..#BROWSEKEYQUERY, [(tTable.schema), (tTable.name)], .tRows, .tStopped, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If tStopped {
            Do tPlan.%Set("stopped", 1, "boolean")
            Set pPlan = tPlan
            Quit
        }
        Set tKey = ""
        Set tIterator = tRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.%Get(1) '= tRows.%Get(0).%Get(1) Quit
            Set tKey = tKey _ $ListBuild(tRow.%Get(0))
        }
        ; A primary key or an identity column names one row each; a column merely named ID orders a
        ; page but may repeat, so it is never a key a save targets.
        Set tKeyUnique = (tKey '= "") || (tIdentity '= "")
        If tKey = "" Set tKey = $Select(tIdentity '= "": $ListBuild(tIdentity), tRowId '= "": $ListBuild(tRowId), 1: "")
        For tI = 1:1:$ListLength(tKey) {
            If '$Data(tKindOf($List(tKey, tI))) {
                Set tKey = ""
                Quit
            }
        }
        If tKey = "" Set tKeyUnique = 0
        Do tPlan.%Set("keyUnique", tKeyUnique, "boolean")
        Set tKeyNames = []
        For tI = 1:1:$ListLength(tKey) {
            Do tKeyNames.%Push($List(tKey, tI), "string")
        }
        Set tIterator = tColumns.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tColumn) {
            If $ListFind(tKey, tColumn.%Get("name")) Do tColumn.%Set("key", 1, "boolean")
        }
        Do tPlan.%Set("key", tKeyNames)
        Set tFilters = []
        Set tBad = 0
        Set tGiven = $Select(pRequest.%GetTypeOf(..#BROWSEFILTERSKEY) = "array": pRequest.%Get(..#BROWSEFILTERSKEY), 1: [])
        Set tIterator = tGiven.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tFilter) {
            Set tName = tFilter.%Get(..#BROWSECOLUMNKEY)
            If '..Browsable(.tKindOf, tName) {
                Set tBad = 1
                Quit
            }
            Set tResolved = {}
            Do tResolved.%Set(..#BROWSECOLUMNKEY, tName, "string")
            Do tResolved.%Set("kind", tKindOf(tName), "string")
            Do tResolved.%Set("value", tFilter.%Get("value"), "string")
            Do tFilters.%Push(tResolved)
        }
        If 'tBad && (pRequest.%GetTypeOf(..#BROWSESORTKEY) = "object") {
            If '..Browsable(.tKindOf, pRequest.%Get(..#BROWSESORTKEY).%Get(..#BROWSECOLUMNKEY)) Set tBad = 1
        }
        If tBad {
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AtelierError).#DATAINPUT, ##class(OcuPilot.Api.AtelierError).#REASONDATAINPUT, .pHttpStatus, .pFault)
            Quit
        }
        Do tPlan.%Set("filters", tFilters)
        If pRequest.%GetTypeOf(..#BROWSESORTKEY) = "object" {
            Set tSort = {}
            Do tSort.%Set(..#BROWSECOLUMNKEY, pRequest.%Get(..#BROWSESORTKEY).%Get(..#BROWSECOLUMNKEY), "string")
            Do tSort.%Set(..#BROWSEDIRECTIONKEY, $Case(pRequest.%Get(..#BROWSESORTKEY).%Get(..#BROWSEDIRECTIONKEY), "desc": "desc", : "asc"), "string")
            Do tPlan.%Set("sort", tSort)
        } Else {
            Do tPlan.%Set("sort", "", "null")
        }
        Set tTables = []
        Do tTables.%Push(tTable.schema _ "." _ tTable.name, "string")
        If tTable.type = "view" {
            Set tListed = ""
            Set tIterator = tColumns.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tColumn) {
                Set tListed = tListed _ $Select(tListed = "": "", 1: ", ") _ ..Quoted(tColumn.%Get("name"))
            }
            Set tSC = ..Prepared(pNamespace, "SELECT " _ tListed _ " FROM " _ ..Quoted(tTable.schema) _ "." _ ..Quoted(tTable.name), .tRaw)
            If $$$ISERR(tSC) {
                Set tSC = ..Fail("a data browser view's tables could not be read", tSC, .pHttpStatus, .pFault)
                Quit
            }
            If tRaw.%GetTypeOf("error") = "object" {
                Do tPlan.%Set("error", tRaw.%Get("error"))
            } ElseIf 'tRaw.%Get("indexed") {
                Set tSC = ..Fail("a data browser view's tables are not recorded by the statement index", $$$ERROR($$$GeneralError, "statement index unreadable"), .pHttpStatus, .pFault)
                Quit
            } Else {
                Set tIterator = tRaw.%Get("tables").%GetIterator()
                While tIterator.%GetNext(.tIndex, .tBase) {
                    Do tTables.%Push(tBase, "string")
                }
            }
        }
        Do tPlan.%Set("tables", tTables)
        Set tComposed = ..Composed(tPlan)
        Set tIterator = tComposed.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Do tPlan.%Set(tKey, tValue)
        }
        Set pPlan = tPlan
    } Catch ex {
        Set pPlan = ""
        Set tSC = ..Fail("a data browser request could not be planned", $$$ERROR($$$GeneralError, ex.Name), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Run <var>pPlan</var>, a plan <method>BrowsePlan</method> answered, in <var>pNamespace</var>
/// (Story 19.7): the gate again, then the page and, with what remains of the plan's budget, the
/// count, each through <method>Executed</method> with its values bound. Every answer carries
/// <code>table</code>, <code>columns</code>, <code>key</code> and <code>keyUnique</code>, and is one
/// of:</p>
/// <ul>
/// <li><code>{outcome: rows, rows, offset, size, more, total, truncated, cuts}</code>: at most the
/// page size of rows, each a cell per column (<method>CellOf</method>, <code>null</code> for SQL
/// NULL), cut by whole rows at <parameter>MAXANSWER</parameter> characters; <code>more</code> when a
/// row was fetched and not kept; <code>truncated</code> when a cell was cut; <code>total</code> the
/// count, or <code>null</code> when it ran out of budget, was refused or failed; <code>cuts</code>
/// each cut cell as a <code>[row, column]</code> pair of indexes into <code>rows</code> (Story
/// 19.8);</li>
/// <li><code>{outcome: stopped, seconds}</code> when the page, or the plan, ran out of the
/// budget;</li>
/// <li><code>{outcome: error, sqlcode, message}</code> when the instance refused or failed the
/// page.</li>
/// </ul>
/// <p>The rows, the SQLCODE and the message reach this answer and nothing else (AD-39's sixth
/// exception): nothing here is logged but a fault's name.</p>
ClassMethod BrowseRun(pNamespace As %String, pPlan As %DynamicObject, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Set tSC = ..Gate(pNamespace, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tAnswer = {}
        Do tAnswer.%Set("outcome", "", "string")
        Do tAnswer.%Set("table", pPlan.%Get("table"))
        Do tAnswer.%Set("columns", pPlan.%Get("columns"))
        Do tAnswer.%Set("key", pPlan.%Get("key"))
        Do tAnswer.%Set("keyUnique", ''pPlan.%Get("keyUnique"), "boolean")
        Set tBound = +pPlan.%Get("bound")
        If pPlan.%Get("stopped") {
            Set pAnswer = ..StoppedBrowse(tAnswer, tBound)
            Quit
        }
        If pPlan.%GetTypeOf("error") = "object" {
            Set pAnswer = ..ErrorBrowse(tAnswer, pPlan.%Get("error").%Get("sqlcode"), pPlan.%Get("error").%Get("message"))
            Quit
        }
        Set tRemaining = ..Remaining(pPlan.%Get("start"), tBound)
        If tRemaining < 1 {
            Set pAnswer = ..StoppedBrowse(tAnswer, tBound)
            Quit
        }
        Set tSize = +pPlan.%Get(..#BROWSESIZEKEY)
        Set tSC = ..Executed(pNamespace, pPlan.%Get("page"), 1, pPlan.%Get("pageValues"), tRemaining, 1, tSize, .tRaw)
        If $$$ISERR(tSC) {
            Set tSC = ..Fail("a data browser page could not be read", tSC, .pHttpStatus, .pFault)
            Quit
        }
        If tRaw.%Get("stopped") {
            Set pAnswer = ..StoppedBrowse(tAnswer, tBound)
            Quit
        }
        If tRaw.%Get("changed") {
            Set tSC = ..PrepareProblem(pNamespace, pPlan.%Get("page"), .tCode, .tMessage)
            If $$$ISERR(tSC) {
                Set tSC = ..Fail("a data browser page could not be prepared", tSC, .pHttpStatus, .pFault)
                Quit
            }
            Set pAnswer = ..ErrorBrowse(tAnswer, tCode, tMessage)
            Quit
        }
        If (tRaw.%Get("sqlcode") < 0) || tRaw.%Get("rolledBack") || (tRaw.%GetTypeOf("rows") '= "array") {
            Set pAnswer = ..ErrorBrowse(tAnswer, $Select(tRaw.%Get("sqlcode") < 0: tRaw.%Get("sqlcode"), 1: ""), $Select(tRaw.%Get("sqlcode") < 0: tRaw.%Get("message"), 1: ""))
            Quit
        }
        Set tColumns = pPlan.%Get("columns")
        Set tWidth = tColumns.%Size()
        Set tRows = []
        Set tTotal = 0
        Set tMore = ''tRaw.%Get("more")
        Set tTruncated = ''tRaw.%Get("cut")
        Set tCuts = []
        Set tIterator = tRaw.%Get("rows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tFetched) {
            Set tRow = []
            Set tRowCuts = ""
            For tI = 0:1:tWidth - 1 {
                Set tKind = tColumns.%Get(tI).%Get("kind")
                Set tCell = ..CellOf(tKind, tFetched.%Get(tI), .tNull, .tCut)
                If tCut Set tTruncated = 1
                ; Executed cuts a long cell to MAXCELL characters ending in U+2026; a value already of
                ; that shape is marked cut too, so it is never offered for editing.
                If tCut || ('tNull && (tKind '= "binary") && ($Length(tCell) = ..#MAXCELL) && ($Extract(tCell, *) = $Char(8230))) Set tRowCuts = tRowCuts _ $ListBuild(tI)
                If tNull {
                    Do tRow.%Push("", "null")
                } Else {
                    Do tRow.%Push(tCell, "string")
                }
            }
            Set tLength = $Length(tRow.%ToJSON())
            If tTotal + tLength > ..#MAXANSWER {
                Set tMore = 1
                Quit
            }
            Set tTotal = tTotal + tLength
            For tI = 1:1:$ListLength(tRowCuts) {
                Do tCuts.%Push([(tRows.%Size()), ($List(tRowCuts, tI))])
            }
            Do tRows.%Push(tRow)
        }
        Do tAnswer.%Set("outcome", ..#OUTCOMEROWS, "string")
        Do tAnswer.%Set("rows", tRows)
        Do tAnswer.%Set(..#BROWSEOFFSETKEY, +pPlan.%Get(..#BROWSEOFFSETKEY), "number")
        Do tAnswer.%Set(..#BROWSESIZEKEY, tSize, "number")
        Do tAnswer.%Set("more", tMore, "boolean")
        Set tCount = ""
        Set tRemaining = ..Remaining(pPlan.%Get("start"), tBound)
        If tRemaining >= 1 {
            Set tCountSC = ..Executed(pNamespace, pPlan.%Get("count"), 1, pPlan.%Get("countValues"), tRemaining, 1, 1, .tCountRaw)
            If $$$ISOK(tCountSC) && 'tCountRaw.%Get("stopped") && 'tCountRaw.%Get("changed") && (tCountRaw.%Get("sqlcode") >= 0) && (tCountRaw.%GetTypeOf("rows") = "array") && $IsObject(tCountRaw.%Get("rows").%Get(0)) {
                Set tCount = tCountRaw.%Get("rows").%Get(0).%Get(0)
                If '$Match(tCount, "^[0-9]+$") Set tCount = ""
            }
        }
        If tCount = "" {
            Do tAnswer.%Set("total", "", "null")
        } Else {
            Do tAnswer.%Set("total", +tCount, "number")
        }
        Do tAnswer.%Set("truncated", tTruncated, "boolean")
        Do tAnswer.%Set("cuts", tCuts)
        Set pAnswer = tAnswer
    } Catch ex {
        Set pAnswer = ""
        Set tSC = ..Fail("a data browser page could not be read", $$$ERROR($$$GeneralError, ex.Name), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether <var>pName</var> names a column of <var>pKindOf</var> (each listed column's kind,
/// subscripted by its exact name) that a filter or a sort may name: any kind but
/// <code>stream</code> and <code>binary</code>.</p>
ClassMethod Browsable(ByRef pKindOf, pName As %String) As %Boolean [ Private ]
{
    If (pName = "") || '$Data(pKindOf(pName)) Quit 0
    Quit (pKindOf(pName) '= "stream") && (pKindOf(pName) '= "binary")
}

/// <p>The whole seconds left of a budget of <var>pBound</var> seconds that started at
/// <var>pStart</var> (a <code>$ZHorolog</code> reading), rounded up as the alarm counts them, or 0
/// when none is left.</p>
ClassMethod Remaining(pStart As %Numeric, pBound As %Integer) As %Integer [ Private ]
{
    Set tElapsed = $ZHorolog - pStart
    If tElapsed < 0 Set tElapsed = tElapsed + 86400
    Set tLeft = pBound - tElapsed
    If tLeft <= 0 Quit 0
    Set tWhole = tLeft \ 1
    If tWhole < tLeft Set tWhole = tWhole + 1
    Quit tWhole
}

/// <p>Run <var>pText</var>, one of the data browser's fixed catalog statements, in
/// <var>pNamespace</var> with <var>pValues</var> bound, under what remains of <var>pPlan</var>'s
/// budget, answering its rows in <var>pRows</var>, or <var>pStopped</var> 1 when the budget ran out.
/// A refusal, a failure, or an answer cut by rows or by a cell is 500 <code>INTERNAL</code>, logged
/// with nothing the instance answered.</p>
ClassMethod CatalogRows(pNamespace As %String, pPlan As %DynamicObject, pText As %String, pValues As %DynamicArray, Output pRows As %DynamicArray, Output pStopped As %Boolean, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = []
    Set pStopped = 0
    Set tRemaining = ..Remaining(pPlan.%Get("start"), pPlan.%Get("bound"))
    If tRemaining < 1 {
        Set pStopped = 1
        Quit $$$OK
    }
    Set tSC = ..Executed(pNamespace, pText, 1, pValues, tRemaining, 1, ..#MAXCOLUMNS, .tRaw)
    If $$$ISERR(tSC) Quit ..Fail("a data browser catalog read failed", tSC, .pHttpStatus, .pFault)
    If tRaw.%Get("stopped") {
        Set pStopped = 1
        Quit $$$OK
    }
    If tRaw.%Get("changed") || (tRaw.%Get("sqlcode") < 0) || tRaw.%Get("more") || tRaw.%Get("cut") || (tRaw.%GetTypeOf("rows") '= "array") {
        Quit ..Fail("a data browser catalog read failed", $$$ERROR($$$GeneralError, $Select(tRaw.%Get("changed"): "not prepared", tRaw.%Get("more") || tRaw.%Get("cut"): "cut", 1: "refused")), .pHttpStatus, .pFault)
    }
    Set pRows = tRaw.%Get("rows")
    Quit $$$OK
}

/// <p>Prepare <var>pText</var> in <var>pNamespace</var> with privilege checks on, as
/// <method>Executed</method> does, to read the SQLCODE and message the instance refuses it with into
/// <var>pCode</var> and <var>pMessage</var>, both <code>""</code> when it prepares. It reads no
/// statement index. The switched region calls vendor classes only, and the statement is released in
/// <var>pNamespace</var>.</p>
ClassMethod PrepareProblem(pNamespace As %String, pText As %String, Output pCode As %String, Output pMessage As %String) As %Status [ Private ]
{
    Set pCode = ""
    Set pMessage = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tStatement.%SelectMode = ..#SELECTMODE
        Set tPrepareSC = tStatement.%Prepare(pText, 1)
        If $$$ISERR(tPrepareSC) {
            Set tMessage = ""
            Set pCode = $System.Status.StatusToSQLCODE(tPrepareSC, .tMessage)
            Set pMessage = tMessage
        }
        Set tStatement = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Do ..Closed(pNamespace, .tStatement)
        Set tSC = $$$ERROR($$$GeneralError, "the prepare raised " _ ex.Name)
    }
    Quit tSC
}

/// <p><var>pAnswer</var>, a data browser answer's frame, as the <code>stopped</code> outcome of a
/// budget of <var>pBound</var> seconds.</p>
ClassMethod StoppedBrowse(pAnswer As %DynamicObject, pBound As %Integer) As %DynamicObject [ Private ]
{
    Do pAnswer.%Set("outcome", ..#OUTCOMESTOPPED, "string")
    Do pAnswer.%Set("seconds", pBound, "number")
    Quit pAnswer
}

/// <p><var>pAnswer</var>, a data browser answer's frame, as the <code>error</code> outcome, an empty
/// SQLCODE answered as <code>null</code>.</p>
ClassMethod ErrorBrowse(pAnswer As %DynamicObject, pCode As %String, pMessage As %String) As %DynamicObject [ Private ]
{
    Do pAnswer.%Set("outcome", ..#OUTCOMEERROR, "string")
    If pCode = "" {
        Do pAnswer.%Set("sqlcode", "", "null")
    } Else {
        Do pAnswer.%Set("sqlcode", +pCode, "number")
    }
    Do pAnswer.%Set("message", pMessage, "string")
    Quit pAnswer
}

/// <p>The data browser save's changes (Story 19.8) from <var>pText</var>, their JSON array text,
/// into <var>pChanges</var>, answering 0 with <var>pProblem</var> a sentence for any shape outside
/// its bounds. The text is at most <parameter>MAXCHANGESTEXT</parameter> characters and holds 1 to
/// <parameter>MAXCHANGES</parameter> members, each one of:</p>
/// <ul>
/// <li><code>{op: "update", key, original, values}</code>;</li>
/// <li><code>{op: "insert", values}</code>;</li>
/// <li><code>{op: "delete", key}</code>.</li>
/// </ul>
/// <p><code>key</code> maps each key column to a string; <code>values</code> maps each column it sets
/// to a string or <code>null</code>; <code>original</code> maps each column to the string or
/// <code>null</code> the page read. Each is a non-empty object whose names are column names
/// (<method>BrowseName</method>), named once each ignoring case, and each string is at most
/// <parameter>MAXVALUE</parameter> characters. No sentence carries a value. Pure.</p>
ClassMethod SaveChanges(pText, Output pChanges As %DynamicArray, Output pProblem As %String) As %Boolean
{
    Set pChanges = ""
    Set pProblem = "'" _ ..#CHANGESKEY _ "' is JSON array text of 1 to 100 changes, at most 1,000,000 characters"
    If $IsObject($Get(pText)) || ($Length($Get(pText)) < 1) || ($Length(pText) > ..#MAXCHANGESTEXT) Quit 0
    Set tChanges = ""
    Try {
        Set tChanges = ##class(%DynamicAbstractObject).%FromJSON(pText)
    } Catch {
        Set tChanges = ""
    }
    If '$IsObject(tChanges) || 'tChanges.%IsA("%Library.DynamicArray") Quit 0
    If (tChanges.%Size() < 1) || (tChanges.%Size() > ..#MAXCHANGES) Quit 0
    Set tProblem = ""
    Set tIterator = tChanges.%GetIterator()
    While (tProblem = "") && tIterator.%GetNext(.tIndex, .tChange) {
        Set tWhere = "change " _ (tIndex + 1) _ ": "
        If (tChanges.%GetTypeOf(tIndex) '= "object") || (tChange.%GetTypeOf("op") '= "string") {
            Set tProblem = tWhere _ "'op' is update, insert or delete"
            Quit
        }
        Set tOp = tChange.%Get("op")
        Set tShape = $Case(tOp, ..#OPUPDATE: $ListBuild("op", "key", "original", "values"), ..#OPINSERT: $ListBuild("op", "values"), ..#OPDELETE: $ListBuild("op", "key"), : "")
        If tShape = "" {
            Set tProblem = tWhere _ "'op' is update, insert or delete"
            Quit
        }
        Set tKeyIterator = tChange.%GetIterator()
        While tKeyIterator.%GetNext(.tMember, .tValue) {
            If '$ListFind(tShape, tMember) Set tProblem = tWhere _ "an update carries op, key, original and values; an insert op and values; a delete op and key"
        }
        For tI = 2:1:$ListLength(tShape) {
            If tProblem '= "" Quit
            Set tMember = $List(tShape, tI)
            If '..SaveMember(tChange, tMember, (tMember '= "key")) Set tProblem = tWhere _ $Case(tMember, "key": "'key' maps each key column to its value, a string", "values": "'values' maps each column to a string of at most 32,767 characters, or null", : "'original' maps each changed column to the value read, a string or null") _ ", each column named once"
        }
    }
    If tProblem '= "" {
        Set pProblem = tProblem
        Quit 0
    }
    Set pChanges = tChanges
    Set pProblem = ""
    Quit 1
}

/// <p>Whether <var>pChange</var>'s member <var>pMember</var> is a non-empty object of column names
/// (<method>BrowseName</method>), each named once ignoring case, mapped to strings of at most
/// <parameter>MAXVALUE</parameter> characters, or to <code>null</code> where <var>pNullable</var>.</p>
ClassMethod SaveMember(pChange As %DynamicObject, pMember As %String, pNullable As %Boolean) As %Boolean [ Private ]
{
    If pChange.%GetTypeOf(pMember) '= "object" Quit 0
    Set tObject = pChange.%Get(pMember)
    If tObject.%Size() < 1 Quit 0
    Set tGood = 1
    Kill tSeen
    Set tIterator = tObject.%GetIterator()
    While tIterator.%GetNext(.tName, .tValue) {
        Set tType = tObject.%GetTypeOf(tName)
        If '..BrowseName(tName) || $Data(tSeen($ZConvert(tName, "U"))) || '((tType = "string") || (pNullable && (tType = "null"))) || ((tType = "string") && ($Length(tValue) > ..#MAXVALUE)) {
            Set tGood = 0
            Quit
        }
        Set tSeen($ZConvert(tName, "U")) = ""
    }
    Quit tGood
}

/// <p>Whether a save may change <var>pColumn</var>, a plan's column, on an existing row: it is not a
/// key column, neither an identity nor a generated column, and neither a stream nor a binary one.
/// Pure.</p>
ClassMethod Editable(pColumn As %DynamicObject) As %Boolean
{
    If '$IsObject($Get(pColumn)) Quit 0
    If pColumn.%Get("key") Quit 0
    Quit ..Insertable(pColumn)
}

/// <p>Whether a save may set <var>pColumn</var>, a plan's column, on a new row: as
/// <method>Editable</method>, except that a key column may be set. Pure.</p>
ClassMethod Insertable(pColumn As %DynamicObject) As %Boolean
{
    If '$IsObject($Get(pColumn)) Quit 0
    If pColumn.%Get("identity") || pColumn.%Get("generated") Quit 0
    Quit (pColumn.%Get("kind") '= "stream") && (pColumn.%Get("kind") '= "binary")
}

/// <p>What is wrong with <var>pChanges</var> (<method>SaveChanges</method>'s answer) against
/// <var>pPlan</var>, a plan <method>BrowsePlan</method> resolved, as a sentence, or <code>""</code>.
/// An update and a delete name exactly the plan's key columns in <code>key</code>; an update's
/// <code>values</code> name only columns <method>Editable</method> admits, and its
/// <code>original</code> exactly those; an insert's <code>values</code> name only columns
/// <method>Insertable</method> admits. A name must equal a listed column exactly. No sentence carries
/// a value. Pure.</p>
ClassMethod ChangeProblem(pPlan As %DynamicObject, pChanges As %DynamicArray) As %String
{
    Kill tColumn
    Set tIterator = pPlan.%Get("columns").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tColumn(tEntry.%Get("name")) = tEntry
    }
    Set tKey = ""
    Set tIterator = pPlan.%Get("key").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        Set tKey = tKey _ $ListBuild(tName)
    }
    Set tProblem = ""
    Set tIterator = pChanges.%GetIterator()
    While (tProblem = "") && tIterator.%GetNext(.tIndex, .tChange) {
        Set tWhere = "change " _ (tIndex + 1) _ ": "
        Set tOp = tChange.%Get("op")
        If (tOp = ..#OPUPDATE) || (tOp = ..#OPDELETE) {
            Set tGiven = tChange.%Get("key")
            Set tExact = (tGiven.%Size() = $ListLength(tKey))
            For tI = 1:1:$ListLength(tKey) {
                If tGiven.%GetTypeOf($List(tKey, tI)) '= "string" Set tExact = 0
            }
            If 'tExact {
                Set tProblem = tWhere _ "'key' names exactly the table's key columns, " _ $ListToString(tKey, ", ")
                Quit
            }
        }
        If tOp = ..#OPDELETE Continue
        Set tValues = tChange.%Get("values")
        Set tNames = tValues.%GetIterator()
        While tNames.%GetNext(.tName, .tValue) {
            If '$Data(tColumn(tName)) || '$Select(tOp = ..#OPINSERT: ..Insertable(tColumn(tName)), 1: ..Editable(tColumn(tName))) {
                Set tProblem = tWhere _ "'" _ tName _ "' is not a column " _ $Select(tOp = ..#OPINSERT: "a new row may set", 1: "a save may change")
                Quit
            }
        }
        If (tProblem '= "") || (tOp '= ..#OPUPDATE) Continue
        Set tOriginal = tChange.%Get("original")
        Set tSame = (tOriginal.%Size() = tValues.%Size())
        Set tNames = tValues.%GetIterator()
        While tNames.%GetNext(.tName, .tValue) {
            If tOriginal.%GetTypeOf(tName) = "unassigned" Set tSame = 0
        }
        If 'tSame Set tProblem = tWhere _ "'original' names exactly the columns 'values' changes"
    }
    Quit tProblem
}

/// <p>The one statement a save runs for <var>pChange</var>, a change <method>ChangeProblem</method>
/// passed, against <var>pPlan</var>: <code>{text, type, values, columns}</code>, the text with a
/// <code>?</code> for each value, its statement type, the values bound in order, and the column each
/// value is bound for.</p>
/// <ul>
/// <li>An update is <code>UPDATE "S"."T" SET "c" = ?, ... WHERE "k" = ? AND ...</code>, then one guard
/// term per changed column: <code>"c" IS NULL</code> where the value read was <code>null</code>,
/// <code>%EXACT("c") = ?</code> for a column of kind <code>text</code>, and <code>"c" = ?</code>
/// otherwise. Its values are the new values, the keys, then the values read the guard compares.</li>
/// <li>An insert is <code>INSERT INTO "S"."T" ("c", ...) VALUES (?, ...)</code>.</li>
/// <li>A delete is <code>DELETE FROM "S"."T" WHERE "k" = ? AND ...</code>.</li>
/// </ul>
/// <p>Columns follow the plan's order and keys its key's. Every identifier is the plan's catalog
/// spelling, <method>Quoted</method>; a <code>null</code> binds <code>""</code>, SQL NULL, and an empty
/// string binds <code>$Char(0)</code>. Pure.</p>
ClassMethod SaveComposed(pPlan As %DynamicObject, pChange As %DynamicObject) As %DynamicObject
{
    Set tTable = ..Quoted(pPlan.%Get("table").%Get("schema")) _ "." _ ..Quoted(pPlan.%Get("table").%Get("name"))
    Set tOp = pChange.%Get("op")
    Set tKeyText = ""
    Set tKeyValues = []
    Set tKeyColumns = []
    If tOp '= ..#OPINSERT {
        Set tGiven = pChange.%Get("key")
        Set tIterator = pPlan.%Get("key").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tName) {
            Set tKeyText = tKeyText _ $Select(tKeyText = "": "", 1: " AND ") _ ..Quoted(tName) _ " = ?"
            Do tKeyValues.%Push(..Bound(tGiven, tName), "string")
            Do tKeyColumns.%Push(tName, "string")
        }
    }
    Set tComposed = {}
    Set tBound = []
    Set tColumns = []
    If tOp = ..#OPDELETE {
        Do tComposed.%Set("text", "DELETE FROM " _ tTable _ " WHERE " _ tKeyText, "string")
        Do tComposed.%Set("type", ..#STATEMENTDELETE, "number")
        Do ..Append(tBound, tKeyValues)
        Do ..Append(tColumns, tKeyColumns)
    } Else {
        Set tValues = pChange.%Get("values")
        Set tOriginal = $Select(pChange.%GetTypeOf("original") = "object": pChange.%Get("original"), 1: {})
        Set tNames = ""
        Set tMarks = ""
        Set tSet = ""
        Set tGuard = ""
        Set tGuardValues = []
        Set tGuardColumns = []
        Set tIterator = pPlan.%Get("columns").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tColumn) {
            Set tName = tColumn.%Get("name")
            If tValues.%GetTypeOf(tName) = "unassigned" Continue
            Do tBound.%Push(..Bound(tValues, tName), "string")
            Do tColumns.%Push(tName, "string")
            Set tNames = tNames _ $Select(tNames = "": "", 1: ", ") _ ..Quoted(tName)
            Set tMarks = tMarks _ $Select(tMarks = "": "", 1: ", ") _ "?"
            Set tSet = tSet _ $Select(tSet = "": "", 1: ", ") _ ..Quoted(tName) _ " = ?"
            If tOp '= ..#OPUPDATE Continue
            If tOriginal.%GetTypeOf(tName) = "null" {
                Set tGuard = tGuard _ " AND " _ ..Quoted(tName) _ " IS NULL"
                Continue
            }
            Set tGuard = tGuard _ " AND " _ $Select(tColumn.%Get("kind") = "text": "%EXACT(" _ ..Quoted(tName) _ ")", 1: ..Quoted(tName)) _ " = ?"
            Do tGuardValues.%Push(..Bound(tOriginal, tName), "string")
            Do tGuardColumns.%Push(tName, "string")
        }
        If tOp = ..#OPINSERT {
            Do tComposed.%Set("text", "INSERT INTO " _ tTable _ " (" _ tNames _ ") VALUES (" _ tMarks _ ")", "string")
            Do tComposed.%Set("type", ..#STATEMENTINSERT, "number")
        } Else {
            Do tComposed.%Set("text", "UPDATE " _ tTable _ " SET " _ tSet _ " WHERE " _ tKeyText _ tGuard, "string")
            Do tComposed.%Set("type", ..#STATEMENTUPDATE, "number")
            Do ..Append(tBound, tKeyValues)
            Do ..Append(tColumns, tKeyColumns)
            Do ..Append(tBound, tGuardValues)
            Do ..Append(tColumns, tGuardColumns)
        }
    }
    Do tComposed.%Set("values", tBound)
    Do tComposed.%Set("columns", tColumns)
    Quit tComposed
}

/// <p>The value <var>pObject</var> holds under <var>pName</var> as a save binds it: <code>null</code>
/// or absent as <code>""</code>, SQL NULL; an empty string as <code>$Char(0)</code>; any other string
/// as itself.</p>
ClassMethod Bound(pObject As %DynamicObject, pName As %String) As %String [ Private ]
{
    Set tType = pObject.%GetTypeOf(pName)
    If (tType = "null") || (tType = "unassigned") Quit ""
    Set tValue = pObject.%Get(pName)
    If tValue = "" Quit $Char(0)
    Quit tValue
}

/// <p>Push each string of <var>pFrom</var> onto <var>pTo</var>.</p>
ClassMethod Append(pTo As %DynamicArray, pFrom As %DynamicArray) [ Private ]
{
    Set tIterator = pFrom.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        Do pTo.%Push(tValue, "string")
    }
}

/// <p>The save's fresh read (Story 19.8, AD-51) in <var>pNamespace</var>: the gate, then, for the
/// table <var>pQuery</var>'s <code>schema</code> and <code>table</code> name, its plan
/// (<method>BrowsePlan</method>). <var>pAnswer</var> is <code>{Namespace, Kind, Tables, RecordsTables,
/// DefaultSchema, statement, schema, table, changes}</code>: <code>Kind</code> <code>table</code> or
/// <code>view</code>, <code>Tables</code> the table and a view's base tables, which the self-protection
/// check judges, <code>RecordsTables</code> true, <code>DefaultSchema</code> the namespace's, and the
/// last four <code>null</code>. With no schema it answers the empty plan, <code>Kind</code>
/// <code>""</code> and no table, after the gate alone. Every refusal is <method>BrowsePlan</method>'s;
/// a name outside its shape is 400 <code>TOOL.ARGUMENTS</code>.</p>
/// <p>Caller contract: must not be called from an escalated frame (AD-9). Nothing of the request is
/// logged.</p>
ClassMethod SavePlan(pNamespace As %String, ByRef pQuery, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Set tSchema = $Get(pQuery(..#SCHEMAKEY))
        Set tTables = []
        Set tKind = ""
        If tSchema = "" {
            Set tSC = ..Gate(pNamespace, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
        } Else {
            Set tSC = ..SaveTable(pNamespace, tSchema, $Get(pQuery(..#TABLEKEY)), .tPlan, .pHttpStatus, .pFault)
            If $$$ISERR(tSC) Quit
            If tPlan.%Get("stopped") {
                Set tSC = ..Fail("a data browser save's plan ran out of its budget", $$$ERROR($$$GeneralError, "stopped"), .pHttpStatus, .pFault)
                Quit
            }
            Set tKind = tPlan.%Get("table").%Get("type")
            Set tTables = tPlan.%Get("tables")
        }
        Set tSC = ..DefaultSchemaOf(pNamespace, .tDefault)
        If $$$ISERR(tSC) {
            Set tSC = ..Fail("a data browser save's default schema could not be read", tSC, .pHttpStatus, .pFault)
            Quit
        }
        Set tAnswer = {}
        Do tAnswer.%Set("Namespace", pNamespace, "string")
        Do tAnswer.%Set("Kind", tKind, "string")
        Do tAnswer.%Set("Tables", tTables)
        Do tAnswer.%Set("RecordsTables", 1, "boolean")
        Do tAnswer.%Set("DefaultSchema", tDefault, "string")
        For tKey = ..#STATEMENTKEY, ..#SCHEMAKEY, ..#TABLEKEY, ..#CHANGESKEY {
            Do tAnswer.%Set(tKey, "", "null")
        }
        Set pAnswer = tAnswer
    } Catch ex {
        Set pAnswer = ""
        Set tSC = ..Fail("a data browser save could not be planned", $$$ERROR($$$GeneralError, ex.Name), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Save <var>pQuery</var>'s staged <code>changes</code> to the table its <code>schema</code> and
/// <code>table</code> name, in <var>pNamespace</var> (Story 19.8), in this order:</p>
/// <ol>
/// <li>the gate (<method>Gate</method>);</li>
/// <li>the changes' shape (<method>SaveChanges</method>) and the names', else 400
/// <code>TOOL.ARGUMENTS</code>;</li>
/// <li>the plan (<method>BrowsePlan</method>): 404 <code>EXPLORER.DATA.NOTFOUND</code>, and 409
/// <code>EXPLORER.DATA.READONLY</code> for a view, a table with no key the caller can list, or one
/// keyed only by a column named <code>ID</code> that is neither its primary key nor an identity
/// column (<code>keyUnique</code> false);</li>
/// <li>the column rules (<method>ChangeProblem</method>), else 400
/// <code>EXPLORER.DATA.CHANGES</code>;</li>
/// <li>each change in order, one statement each (<method>SaveComposed</method>) through
/// <method>Executed</method> with what remains of the plan's budget, with no surrounding
/// transaction.</li>
/// </ol>
/// <p><var>pAnswer</var> is <code>{outcome: saved, results: [{index, outcome, rowCount?, sqlcode?,
/// message?, seconds?}], saved, failed}</code>. A row is <code>saved</code> when the instance's row
/// count is at least 1; an update matching no row is <code>changed</code> and a delete
/// <code>gone</code>; <code>refused</code> answers the instance's privilege violation; any other SQL
/// error is <code>error</code> with its SQLCODE and message; the row the budget interrupts is
/// <code>stopped</code>, which <method>Executed</method> rolls back, and every row after it
/// <code>skipped</code>.</p>
/// <p>A row's outcome is an answer, never a fault. Nothing of a key, a value, a SQLCODE or a message is
/// logged.</p>
ClassMethod Save(pNamespace As %String, ByRef pQuery, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Set tSC = ..Gate(pNamespace, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tSchema = $Get(pQuery(..#SCHEMAKEY))
        Set tName = $Get(pQuery(..#TABLEKEY))
        If '..SaveChanges($Get(pQuery(..#CHANGESKEY)), .tChanges, .tProblem) || '..BrowseName(tSchema) || '..BrowseName(tName) {
            If tProblem = "" Set tProblem = "'" _ ..#SCHEMAKEY _ "' and '" _ ..#TABLEKEY _ "' name the table as the tree shows it"
            Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS, .pHttpStatus, .pFault, {"problem": (tProblem)})
            Quit
        }
        Set tSC = ..SaveTable(pNamespace, tSchema, tName, .tPlan, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        If 'tPlan.%Get("stopped") && ((tPlan.%Get("table").%Get("type") '= "table") || (tPlan.%Get("key").%Size() = 0) || 'tPlan.%Get("keyUnique")) {
            Set tSC = ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.AtelierError).#DATAREADONLY, ##class(OcuPilot.Api.AtelierError).#REASONDATAREADONLY, .pHttpStatus, .pFault)
            Quit
        }
        If 'tPlan.%Get("stopped") {
            Set tProblem = ..ChangeProblem(tPlan, tChanges)
            If tProblem '= "" {
                Set tSC = ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AtelierError).#DATACHANGES, ##class(OcuPilot.Api.AtelierError).#REASONDATACHANGES, .pHttpStatus, .pFault, {"problem": (tProblem)})
                Quit
            }
        }
        Set tHalted = ''tPlan.%Get("stopped")
        Set tResults = []
        Set tSaved = 0
        Set tIterator = tChanges.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tChange) {
            Set tRemaining = $Select(tHalted: 0, 1: ..Remaining(tPlan.%Get("start"), tPlan.%Get("bound")))
            If tRemaining < 1 {
                Set tHalted = 1
                Do tResults.%Push(..RowResult(tIndex, ..#ROWSKIPPED))
                Continue
            }
            Set tComposed = ..SaveComposed(tPlan, tChange)
            Set tRunSC = ..Executed(pNamespace, tComposed.%Get("text"), tComposed.%Get("type"), tComposed.%Get("values"), tRemaining, 0, 1, .tRaw)
            Set tResult = ..SaveOutcome(pNamespace, tIndex, tChange.%Get("op"), tComposed.%Get("text"), +tPlan.%Get("bound"), tRunSC, $Get(tRaw))
            If tResult.%Get("outcome") = ..#ROWSTOPPED Set tHalted = 1
            If tResult.%Get("outcome") = ..#ROWSAVED Set tSaved = tSaved + 1
            Do tResults.%Push(tResult)
        }
        Set tAnswer = {}
        Do tAnswer.%Set("outcome", ..#OUTCOMESAVED, "string")
        Do tAnswer.%Set("results", tResults)
        Do tAnswer.%Set("saved", tSaved, "number")
        Do tAnswer.%Set("failed", tResults.%Size() - tSaved, "number")
        Set pAnswer = tAnswer
    } Catch ex {
        Set pAnswer = ""
        Set tSC = ..Fail("a data browser save could not be run", $$$ERROR($$$GeneralError, ex.Name), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The plan of the table <var>pSchema</var>.<var>pName</var> in <var>pNamespace</var> a save
/// writes, as <method>BrowsePlan</method> resolves it, in <var>pPlan</var>. A name outside its shape
/// is 400 <code>TOOL.ARGUMENTS</code> once the gate has passed.</p>
ClassMethod SaveTable(pNamespace As %String, pSchema As %String, pName As %String, Output pPlan As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pPlan = ""
    Set tBody = {}
    Do tBody.%Set(..#BROWSESCHEMAKEY, pSchema, "string")
    Do tBody.%Set(..#BROWSETABLEKEY, pName, "string")
    If '..BrowseRequest(tBody, .tRequest) {
        Set tSC = ..Gate(pNamespace, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS, .pHttpStatus, .pFault, {"problem": ("'" _ ..#SCHEMAKEY _ "' and '" _ ..#TABLEKEY _ "' name the table as the tree shows it")})
    }
    Quit ..BrowsePlan(pNamespace, tRequest, .pPlan, .pHttpStatus, .pFault)
}

/// <p>The result of the staged change at <var>pIndex</var>, an operation <var>pOp</var> whose text
/// <var>pText</var> <method>Executed</method> ran with status <var>pRunSC</var> and raw answer
/// <var>pRaw</var>, under a budget of <var>pBound</var> seconds. A failed prepare is asked again for
/// its SQLCODE in <var>pNamespace</var> (<method>PrepareProblem</method>); every other branch reads
/// <var>pRaw</var> alone. A status that is an error logs only that the row could not be run.</p>
ClassMethod SaveOutcome(pNamespace As %String, pIndex As %Integer, pOp As %String, pText As %String, pBound As %Integer, pRunSC As %Status, pRaw) As %DynamicObject
{
    If $$$ISERR(pRunSC) || '$IsObject(pRaw) {
        Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, "a data browser save's row could not be run", pRunSC, ##class(OcuPilot.Api.Error).#INTERNAL)
        Quit ..RowResult(pIndex, ..#ROWERROR, "", "", "")
    }
    If pRaw.%Get("stopped") {
        Set tResult = ..RowResult(pIndex, ..#ROWSTOPPED)
        Do tResult.%Set("seconds", pBound, "number")
        Quit tResult
    }
    If pRaw.%Get("changed") {
        Set tProblemSC = ..PrepareProblem(pNamespace, pText, .tCode, .tMessage)
        If $$$ISERR(tProblemSC) || (tCode = "") Quit ..RowResult(pIndex, ..#ROWERROR, "", "", "")
        If +tCode = ..#PRIVILEGESQLCODE Quit ..RowResult(pIndex, ..#ROWREFUSED, "", tCode)
        Quit ..RowResult(pIndex, ..#ROWERROR, "", tCode, tMessage)
    }
    If +pRaw.%Get("sqlcode") = ..#PRIVILEGESQLCODE Quit ..RowResult(pIndex, ..#ROWREFUSED, "", ..#PRIVILEGESQLCODE)
    If pRaw.%Get("sqlcode") < 0 Quit ..RowResult(pIndex, ..#ROWERROR, "", pRaw.%Get("sqlcode"), pRaw.%Get("message"))
    If pRaw.%Get("rolledBack") Quit ..RowResult(pIndex, ..#ROWERROR, "", "", "")
    Set tCount = +pRaw.%Get("rowCount")
    If tCount >= 1 Quit ..RowResult(pIndex, ..#ROWSAVED, tCount)
    If pOp = ..#OPUPDATE Quit ..RowResult(pIndex, ..#ROWCHANGED, 0)
    If pOp = ..#OPDELETE Quit ..RowResult(pIndex, ..#ROWGONE, 0)
    Quit ..RowResult(pIndex, ..#ROWERROR, "", "", "")
}

/// <p>One row's result: <code>{index, outcome}</code>, with <code>rowCount</code> where
/// <var>pRowCount</var> is given, and <code>sqlcode</code> (an empty one <code>null</code>) and
/// <code>message</code> where <var>pCode</var> is passed.</p>
ClassMethod RowResult(pIndex As %Integer, pOutcome As %String, pRowCount As %String = "", pCode As %String, pMessage As %String) As %DynamicObject [ Private ]
{
    Set tResult = {}
    Do tResult.%Set("index", +pIndex, "number")
    Do tResult.%Set("outcome", pOutcome, "string")
    If pRowCount '= "" Do tResult.%Set("rowCount", +pRowCount, "number")
    If $Data(pCode) {
        If pCode = "" {
            Do tResult.%Set("sqlcode", "", "null")
        } Else {
            Do tResult.%Set("sqlcode", +pCode, "number")
        }
    }
    If $Data(pMessage) Do tResult.%Set("message", pMessage, "string")
    Quit tResult
}

/// <p><var>pNamespace</var>'s default SQL schema, read there, in <var>pDefault</var>. The switched
/// region calls vendor classes only.</p>
ClassMethod DefaultSchemaOf(pNamespace As %String, Output pDefault As %String) As %Status [ Private ]
{
    Set pDefault = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set pDefault = $SYSTEM.SQL.Schema.Default()
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pDefault = ""
        Set tSC = $$$ERROR($$$GeneralError, "the default schema read raised " _ ex.Name)
    }
    Quit tSC
}

/// <p>The data browser's save (<parameter>ENDPOINTDATA</parameter>, <parameter>TYPERUN</parameter>) as
/// a script (AD-59), in the namespace <code>namespace</code> names: each change of
/// <code>changes</code> composed as <method>SaveComposed</method> composes it, prepared with privilege
/// checks on in ODBC select mode and executed, its SQLCODE, message and row count shown. Every bound
/// value is rendered as its column's <code>"&lt;column&gt;"</code> placeholder, never a row value. The
/// script reads no catalog, so each column is composed as kind <code>text</code>, which renders every
/// guard on a value read as <code>%EXACT</code>; the port compares a column of another kind with
/// <code>=</code>. Changes that do not read render the namespace line alone.</p>
ClassMethod SaveSnippet(ByRef pQuery) As %DynamicArray [ Private ]
{
    Set tChanges = ..ValuesFrom($Get(pQuery(..#CHANGESKEY)), .tReadable)
    Set tText = " Set $NAMESPACE = " _ ..Literal($Get(pQuery(..#NAMESPACEKEY)))
    Set tIterator = tChanges.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tChange) {
        If '$IsObject(tChange) || 'tChange.%IsA("%Library.DynamicObject") Continue
        If '$ListFind($ListBuild(..#OPUPDATE, ..#OPINSERT, ..#OPDELETE), tChange.%Get("op")) Continue
        Set tComposed = ..SaveComposed(..SnippetPlan($Get(pQuery(..#SCHEMAKEY)), $Get(pQuery(..#TABLEKEY)), tChange), tChange)
        Set tList = ""
        Set tNames = tComposed.%Get("columns").%GetIterator()
        While tNames.%GetNext(.tAt, .tName) {
            Set tList = tList _ $Select(tList = "": "", 1: ", ") _ ..Literal("<" _ tName _ ">")
        }
        Set tText = tText _ $Char(10) _ " Set tStatement = ##class(%SQL.Statement).%New(), tStatement.%SelectMode = " _ ..#SELECTMODE
        Set tText = tText _ $Char(10) _ " Set tSC = tStatement.%Prepare(" _ ..Literal(tComposed.%Get("text")) _ ", 1)"
        Set tText = tText _ $Char(10) _ " If $System.Status.IsError(tSC) { Do $System.Status.DisplayError(tSC) } Else { Set tResult = tStatement.%Execute(" _ tList _ ") ZWrite tResult.%SQLCODE, tResult.%Message, tResult.%ROWCOUNT }"
    }
    Set tStep = {}
    Do tStep.%Set("kind", "objectscript", "string")
    Do tStep.%Set("text", tText, "string")
    Quit [(tStep)]
}

/// <p>The plan <method>SaveSnippet</method> composes <var>pChange</var> against: the table
/// <var>pSchema</var>.<var>pName</var>, the change's own key names in order as its key, and each name
/// it carries as a column of kind <code>text</code>.</p>
ClassMethod SnippetPlan(pSchema As %String, pName As %String, pChange As %DynamicObject) As %DynamicObject [ Private ]
{
    Set tPlan = {"table": {}, "key": [], "columns": []}
    Do tPlan.%Get("table").%Set("schema", pSchema, "string")
    Do tPlan.%Get("table").%Set("name", pName, "string")
    Kill tSeen
    For tMember = "key", "values" {
        If pChange.%GetTypeOf(tMember) '= "object" Continue
        Set tIterator = pChange.%Get(tMember).%GetIterator()
        While tIterator.%GetNext(.tName, .tValue) {
            If tMember = "key" Do tPlan.%Get("key").%Push(tName, "string")
            If $Data(tSeen(tName)) Continue
            Set tSeen(tName) = ""
            Do tPlan.%Get("columns").%Push({"name": (tName), "kind": "text"})
        }
    }
    Quit tPlan
}

}
