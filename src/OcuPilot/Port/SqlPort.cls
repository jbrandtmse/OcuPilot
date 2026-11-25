Include %msql

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
/// <p><b>The tuning track reads and writes the statement index and the cached queries here too</b> (AD-51's Story 21.6 case):
/// <method>TuningInvoke</method> answers a statement or the whole index (<code>STATEMENT</code>), the cached queries a target holds
/// (<code>PURGE</code>), the five statement writes and the purge, each as one vendor call made with the hash alone or with qualifiers
/// built from the target alone.</p>
/// <p><b>Table maintenance reads and writes a table's index here too</b> (AD-51's Story 21.25 case): <method>TablesInvoke</method> answers a table's
/// statistics (<code>TABLESTATS</code>) and one of its indices (<code>INDEX</code>), each resolved through the caller's own information schema, and
/// rebuilds one index or all of a table's (<code>REBUILD</code>, <code>REBUILDALL</code>), each as one vendor call made with the table's class and the
/// index named by the instance's own row, in the request's process. It answers a schema (<code>SCHEMA</code>), collects a table's statistics
/// (<code>TUNE</code>), removes its fixed statistics (<code>CLEARSTATS</code>) and collects every table's of a schema (<code>TUNESCHEMA</code>), each as one
/// vendor call with display off and no log file, taking the tune's two declared booleans alone.</p>
/// <p><b>Runtime statistics are counted and purged here too</b> (AD-51's Story 21.26 case): <method>TuningInvoke</method> answers a namespace's
/// runtime statistics row count (<code>STATS</code>) and, as <code>PURGESTATS</code>, removes every row with <code>clearStatsSQL</code> called
/// with the namespace alone (<method>StatementCall</method>).</p>
/// <p>Seams a fixture subclass overrides: <method>GateClass</method>, <method>BoundSeconds</method>, <method>StatementCall</method> and
/// <method>TableCall</method>. Production overrides none.</p>
Class OcuPilot.Port.SqlPort Extends (%RegisteredObject, OcuPilot.Kernel.RowFetch)
{

/// <p>The console's endpoint.</p>
Parameter ENDPOINTSQL = "Sql";

/// <p>The fresh read of a console run: <method>Classify</method>'s guard with the run's three
/// declared values answered <code>null</code> beside it.</p>
Parameter TYPEGUARD = "GUARD";

/// <p>The confirmed run of a statement that changes something (<method>Run</method>).</p>
Parameter TYPERUN = "RUN";

/// <p>The writes this port composes from the caller's declared values, as <code>endpoint/type</code>
/// (AD-51): the run, from its statement, values and Max rows; and the data browser's save, from its
/// schema, table and staged changes.</p>
Parameter COMPOSEDTYPES = "Sql/RUN,SqlData/RUN,Statements/FREEZE,Statements/UNFREEZE,Statements/CLEARSTATISTICS,Statements/CLEARERROR,Statements/CLEAN,CachedQueries/PURGEQUERIES,Tables/REBUILD,Tables/REBUILDALL,Tables/TUNE,Tables/CLEARSTATS,Tables/TUNESCHEMA,Tables/SETEXTENT,Tables/SETSELECTIVITY,Tables/SETMAPSIZE,RuntimeStats/PURGESTATS";

/// <p>The runtime statistics endpoint (Story 21.26, AD-51): <parameter>TYPESTATS</parameter> answers how many runtime statistics rows the namespace holds
/// for the target <parameter>ALLID</parameter>, and <parameter>TYPEPURGESTATS</parameter> removes every one of them with
/// <code>clearStatsSQL</code>, called with the namespace alone.</p>
Parameter ENDPOINTRUNTIMESTATS = "RuntimeStats";

Parameter TYPESTATS = "STATS";

Parameter TYPEPURGESTATS = "PURGESTATS";

/// <p>The count <parameter>TYPESTATS</parameter> reads: the runtime statistics rows of one namespace, a fixed statement with the namespace bound, prepared
/// without SQL privilege checks as the source code API's query route prepares the statistics list's read, which the gate has already admitted.</p>
Parameter STATSCOUNTQUERY = "SELECT COUNT(*) FROM %SYS_PTools.StatsSQL WHERE NameSpace = ?";

/// <p>The vendor class whose <code>clearStatsSQL</code> the purge calls.</p>
Parameter STATSCLASS = "%SYS.PTools.StatsSQL";

/// <p>The tuning track's two endpoints (Story 21.6, AD-51): the namespace's statement index, whose
/// <parameter>TYPESTATEMENT</parameter> read answers one statement by its hash, or the index itself for
/// <parameter>ALLID</parameter>, and whose five writes are <parameter>STATEMENTWRITES</parameter>; and its cached
/// queries, whose <parameter>TYPEPURGE</parameter> read answers the count a target holds and whose write is
/// <parameter>TYPEPURGEQUERIES</parameter>. Both take their target from <parameter>IDKEY</parameter>.</p>
Parameter ENDPOINTSTATEMENTS = "Statements";

Parameter ENDPOINTCACHEDQUERIES = "CachedQueries";

Parameter TYPESTATEMENT = "STATEMENT";

Parameter TYPEPURGE = "PURGE";

Parameter TYPEFREEZE = "FREEZE";

Parameter TYPEUNFREEZE = "UNFREEZE";

Parameter TYPECLEARSTATISTICS = "CLEARSTATISTICS";

Parameter TYPECLEARERROR = "CLEARERROR";

Parameter TYPECLEAN = "CLEAN";

Parameter TYPEPURGEQUERIES = "PURGEQUERIES";

/// <p>The writes the <parameter>ENDPOINTSTATEMENTS</parameter> endpoint serves.</p>
Parameter STATEMENTWRITES = "FREEZE,UNFREEZE,CLEARSTATISTICS,CLEARERROR,CLEAN";

/// <p>The table maintenance endpoint (Story 21.25, AD-51): a table's statistics (<parameter>TYPETABLESTATS</parameter>, target
/// <code>Schema.Table</code>) and one of its indices (<parameter>TYPEINDEX</parameter>, the composite <code>[Table, Map]</code>), and its writes
/// <parameter>TABLEWRITES</parameter>: the rebuild of one index (<code>[Table, Map]</code>) and of every index of a table (<code>Schema.Table</code>), the
/// collection of a table's statistics (<code>TUNE</code>, <code>Schema.Table</code>), the removal of its fixed statistics (<code>CLEARSTATS</code>,
/// <code>Schema.Table</code>) and the collection of every table's of a schema (<code>TUNESCHEMA</code>, the schema's name). A schema's read is
/// <parameter>TYPESCHEMA</parameter>.</p>
Parameter ENDPOINTTABLES = "Tables";

Parameter TYPETABLESTATS = "TABLESTATS";

Parameter TYPEINDEX = "INDEX";

Parameter TYPEREBUILD = "REBUILD";

Parameter TYPEREBUILDALL = "REBUILDALL";

Parameter TYPETUNE = "TUNE";

Parameter TYPECLEARSTATS = "CLEARSTATS";

Parameter TYPETUNESCHEMA = "TUNESCHEMA";

Parameter TYPESCHEMA = "SCHEMA";

/// <p>The fixed statistics' read and writes (Story 21.31): <parameter>TYPEFIELDSTATS</parameter> answers one field's statistics (the composite
/// <code>[Table, Field]</code>), and the writes set a table's extent size (<parameter>TYPESETEXTENT</parameter>, <code>Schema.Table</code>), a field's
/// selectivity (<parameter>TYPESETSELECTIVITY</parameter>, <code>[Table, Field]</code>) and a map's size
/// (<parameter>TYPESETMAPSIZE</parameter>, <code>[Table, Map]</code>), each as a fixed statistic.</p>
Parameter TYPEFIELDSTATS = "FIELDSTATS";

Parameter TYPESETEXTENT = "SETEXTENT";

Parameter TYPESETSELECTIVITY = "SETSELECTIVITY";

Parameter TYPESETMAPSIZE = "SETMAPSIZE";

Parameter TABLEWRITES = "REBUILD,REBUILDALL,TUNE,CLEARSTATS,TUNESCHEMA,SETEXTENT,SETSELECTIVITY,SETMAPSIZE";

/// <p>The query keys the setters' declared values travel under, which are the tools' own value names.</p>
Parameter EXTENTSIZEKEY = "ExtentSize";

Parameter SELECTIVITYKEY = "Selectivity";

Parameter OUTLIERSELECTIVITYKEY = "OutlierSelectivity";

Parameter OUTLIERVALUEKEY = "OutlierValue";

Parameter AVERAGESIZEKEY = "AverageFieldSize";

Parameter SIZEMBKEY = "SizeMB";

/// <p>The largest extent size a setter accepts. The instance accepts any value, including one above this, a fraction and text.</p>
Parameter MAXEXTENTSIZE As INTEGER = 1000000000000;

/// <p>A whole number 0 or more, of at most 15 digits: a field's average size.</p>
Parameter WHOLEPATTERN = "^(0|[1-9][0-9]{0,14})$";

/// <p>A whole number 1 or more, of at most 15 digits: a map's size in MB. The instance replaces a size of 0 with the measured one.</p>
Parameter POSITIVEPATTERN = "^[1-9][0-9]{0,14}$";

/// <p>A percentage's number, before its optional <code>%</code>: one or two digits and at most six decimals. A selectivity is also
/// bounded to over 0 and at most <parameter>MAXSELECTIVITY</parameter>.</p>
Parameter PERCENTPATTERN = "^[0-9]{1,2}(\.[0-9]{1,6})?$";

Parameter MAXSELECTIVITY = 99.999;

/// <p>A map's size is set in blocks of 2 KB, so one MB is this many.</p>
Parameter BLOCKSPERMB As INTEGER = 512;

/// <p>The longest outlier value, as the plain text a caller sends. The instance evaluates the value it is given as an ObjectScript expression, so the
/// port builds that expression itself (<method>OutlierExpression</method>) and the caller's text is only ever data.</p>
Parameter MAXOUTLIERVALUE As INTEGER = 128;

/// <p>The vendor's form of a text outlier value as the instance stores and shows it: double-quoted, an embedded quote doubled.</p>
Parameter OUTLIERSTRINGPATTERN = "^""([^""]|"""")*""$";

/// <p>The fixed and the collected statistics of every field of a table, one row each, bound with the schema and the table and read in the
/// table's namespace (<method>FieldRead</method>).</p>
Parameter FIELDSTATSQUERY = "SELECT f.FIELD_NAME AS FIELD_NAME, f.SELECTIVITY AS FIXED_SELECTIVITY, f.OUTLIER_VALUE AS FIXED_OUTLIER_VALUE, f.OUTLIER_SELECTIVITY AS FIXED_OUTLIER_SELECTIVITY, f.AVERAGE_FIELD_SIZE AS FIXED_AVERAGE_FIELD_SIZE, c.SELECTIVITY AS COLLECTED_SELECTIVITY, c.OUTLIER_VALUE AS COLLECTED_OUTLIER_VALUE, c.OUTLIER_SELECTIVITY AS COLLECTED_OUTLIER_SELECTIVITY, c.AVERAGE_FIELD_SIZE AS COLLECTED_AVERAGE_FIELD_SIZE FROM (SELECT ? AS s, ? AS t) t, %SQL_Manager.FieldCurrentSelectivity(t.s, t.t) f LEFT JOIN %SQL_Manager.CollectedFieldSelectivity(t.s, t.t) c ON f.FIELD_NAME = c.FIELD_NAME";

/// <p>What the instance shows for a field's outlier value that has an outlier selectivity and no value.</p>
Parameter NULLOUTLIER = "<Null>";

/// <p>The query key carrying a schema tune's declared boolean, <code>true</code> or <code>false</code>: whether the schema's fixed values are cleared.
/// <parameter>TYPETUNE</parameter> takes no value and always clears none.</p>
Parameter CLEARVALUESKEY = "ClearValues";

/// <p>The schema one name resolves to among the base tables the caller's own information schema shows, spelled as the instance holds it, and how
/// many base tables it holds there, each bound with the schema's name, which the schema's read answers.</p>
Parameter SCHEMANAMEQUERY = "SELECT TOP 1 TABLE_SCHEMA FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' AND TABLE_SCHEMA = ?";

Parameter SCHEMATABLESQUERY = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE' AND TABLE_SCHEMA = ?";

/// <p>The word the instance's index type carries for the table's data map, which holds the rows and has no index to rebuild.</p>
Parameter DATAMAPTYPE = "Data";

/// <p>The target that names a namespace's whole statement index, or the whole of its cached queries.</p>
Parameter ALLID = "*";

/// <p>The shape of a statement hash, which holds <code>/</code>, <code>+</code> and <code>=</code> beside the
/// letters and digits (AD-13).</p>
Parameter HASHPATTERN = "^[A-Za-z0-9+/=]{1,64}$";

/// <p>The shape of a cached query's class name: the prefix, the namespace it belongs to and a number. The count of cached queries
/// reads the information schema's locations that begin with <parameter>CACHEDQUERYPREFIX</parameter>.</p>
Parameter CACHEDQUERYPATTERN = "^%sqlcq\.[A-Za-z0-9_%-]{1,64}\.cls[0-9]{1,12}$";

Parameter CACHEDQUERYPREFIX = "%sqlcq.";

/// <p>The statement index's row count, and the count of its entries no class or routine holds whose plan is not frozen, which are the
/// entries the vendor's clean removes, in the target namespace.</p>
Parameter INDEXCOUNTQUERY = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATEMENTS";

Parameter STALECOUNTQUERY = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATEMENTS s WHERE (s.Frozen IS NULL OR s.Frozen NOT IN (1, 2)) AND NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.STATEMENT_LOCATIONS l WHERE l.Statement = s.Hash)";

/// <p>The distinct cached-query locations of the namespace, of one table (bound with its relation key,
/// <method>OcuPilot.Port.AtelierPort.CatalogRelation</method>) and of one class, each bound with its prefix.</p>
Parameter PURGENAMESPACEQUERY = "SELECT COUNT(DISTINCT Location) FROM INFORMATION_SCHEMA.STATEMENT_LOCATIONS WHERE Location %STARTSWITH ?";

Parameter PURGETABLEQUERY = "SELECT COUNT(DISTINCT l.Location) FROM INFORMATION_SCHEMA.STATEMENT_RELATIONS r JOIN INFORMATION_SCHEMA.STATEMENT_LOCATIONS l ON l.Statement = r.Statement WHERE r.Relation = ? AND l.Location %STARTSWITH ?";

/// <p>The class whose <code>PurgeCachedQueries</code> purges cached queries, run in the target namespace (Story 21.4's purge, one for both
/// callers).</p>
Parameter PURGECLASS = "OcuPilot.Port.ConfigPort";

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
/// (AD-51, AD-52); <parameter>ENDPOINTSTATEMENTS</parameter> and <parameter>ENDPOINTCACHEDQUERIES</parameter> are
/// <method>TuningInvoke</method>'s, and <parameter>ENDPOINTTABLES</parameter> is <method>TablesInvoke</method>'s. <var>pQuery</var> carries <code>id</code>, which must be
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
        If (pEndpoint = ..#ENDPOINTSTATEMENTS) || (pEndpoint = ..#ENDPOINTCACHEDQUERIES) || (pEndpoint = ..#ENDPOINTRUNTIMESTATS) {
            Set tSC = ..TuningInvoke(pEndpoint, pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            If $$$ISOK(tSC) Set pHttpStatus = 200
            Quit
        }
        If pEndpoint = ..#ENDPOINTTABLES {
            Set tSC = ..TablesInvoke(pType, .pQuery, .pResult, .pHttpStatus, .pFault)
            If $$$ISOK(tSC) Set pHttpStatus = 200
            Quit
        }
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

/// <p>The tuning track's way in (Story 21.6, AD-51, AD-52): serve <var>pType</var> of
/// <parameter>ENDPOINTSTATEMENTS</parameter> or <parameter>ENDPOINTCACHEDQUERIES</parameter>. <var>pQuery</var> carries
/// <code>id</code>, the target (a statement's hash, a table as <code>Schema.Table</code>, a cached query's class, or
/// <parameter>ALLID</parameter>), and <code>namespace</code>, or the request's resolved scope where it is absent.
/// <var>pResult</var> is the read's answer, or a write's <code>{Namespace, Target}</code>.</p>
/// <p><b>The order of every call is fixed.</b> An endpoint or type this port does not serve is 501
/// <code>PORT.NOTIMPLEMENTED</code>; then the gate (<method>Gate</method>, a write with
/// <method>OcuPilot.Port.AtelierPort.WritePairs</method>), 403 naming the failed pair; then the target's shape, 400
/// <code>PORT.VALIDATION</code>; then the call. Nothing is read or written before the gate has answered.</p>
/// <p><b>A statement write is one vendor call made with the hash alone</b> (<method>StatementCall</method>), and a purge is
/// <code>PurgeQueries</code> with qualifiers built from the target alone (<method>PurgeTarget</method>). The namespace is switched
/// by save and restore around the call (<method>Applied</method>). A statement write the instance answers with an error status is
/// 409 <code>SQL.STATEMENT.VENDOR</code>, the instance's message in <code>detail.message</code> alone and never logged (AD-39).</p>
ClassMethod TuningInvoke(pEndpoint As %String, pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tStatementWrite = ''$ListFind($ListFromString(..#STATEMENTWRITES), pType)
    Set tWrite = tStatementWrite || (pType = ..#TYPEPURGEQUERIES) || (pType = ..#TYPEPURGESTATS)
    If pEndpoint = ..#ENDPOINTSTATEMENTS {
        Set tServed = (pType = ..#TYPESTATEMENT) || tStatementWrite
    } ElseIf pEndpoint = ..#ENDPOINTRUNTIMESTATS {
        Set tServed = (pType = ..#TYPESTATS) || (pType = ..#TYPEPURGESTATS)
    } Else {
        Set tServed = (pType = ..#TYPEPURGE) || (pType = ..#TYPEPURGEQUERIES)
    }
    If 'tServed {
        Quit ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ##class(OcuPilot.Port.AtelierPort).#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
    }
    Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
    If tNamespace = "" Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
    Set tSC = ..Gate(tNamespace, .pHttpStatus, .pFault, tWrite)
    If $$$ISERR(tSC) Quit tSC
    Set tId = $Get(pQuery(..#IDKEY))
    If pEndpoint = ..#ENDPOINTRUNTIMESTATS {
        If tId '= ..#ALLID {
            Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Api.Error).#REASONPORTFIELDSHAPE, .pHttpStatus, .pFault)
        }
        If pType = ..#TYPESTATS Quit ..RuntimeStatsRead(tNamespace, .pResult, .pHttpStatus, .pFault)
        Quit ..StatementWrite(tNamespace, pType, tId, .pResult, .pHttpStatus, .pFault)
    }
    If pEndpoint = ..#ENDPOINTSTATEMENTS {
        Set tAll = (tId = ..#ALLID)
        Set tHash = ..HashValid(tId)
        Set tShapeOK = $Case(pType, ..#TYPESTATEMENT: tAll || tHash, ..#TYPECLEAN: tAll, : tHash)
        If 'tShapeOK {
            Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Api.Error).#REASONPORTFIELDSHAPE, .pHttpStatus, .pFault)
        }
        If pType = ..#TYPESTATEMENT Quit ..StatementRead(tNamespace, tId, .pResult, .pHttpStatus, .pFault)
        Quit ..StatementWrite(tNamespace, pType, tId, .pResult, .pHttpStatus, .pFault)
    }
    If pType = ..#TYPEPURGE Quit ..PurgeRead(tNamespace, tId, .pResult, .pHttpStatus, .pFault)
    Quit ..PurgeWrite(tNamespace, tId, .pResult, .pHttpStatus, .pFault)
}

/// <p>Whether <var>pText</var> has the shape of a statement hash (<parameter>HASHPATTERN</parameter>). Pure.</p>
ClassMethod HashValid(pText As %String) As %Boolean
{
    Quit $Match(pText, ..#HASHPATTERN)
}

/// <p>The sentence <var>pCode</var> carries, one of <class>OcuPilot.Api.AtelierError</class>'s <code>SQL.*</code> codes, or
/// <code>""</code>. A tool names this method rather than the error class, which only a port may name.</p>
ClassMethod ReasonFor(pCode As %String) As %String
{
    Quit ##class(OcuPilot.Api.AtelierError).SqlReasonFor(pCode)
}

/// <p>One select <var>pText</var> run in <var>pNamespace</var> with <var>pValues</var> bound, at most <var>pMaxRows</var> rows, as
/// <method>Executed</method> answers it in <var>pRaw</var>; a statement the instance did not prepare, a refusal, a stop or a row beyond
/// the cap is the internal fault, logged by its name alone. A cell cut at <parameter>MAXCELL</parameter> characters is the caller's
/// to judge.</p>
ClassMethod ReadRows(pNamespace As %String, pText As %String, pValues As %DynamicArray, pMaxRows As %Integer, Output pRaw As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..Executed(pNamespace, pText, 1, pValues, ..BoundSeconds(), 1, pMaxRows, .pRaw)
    If $$$ISERR(tSC) Quit ..Fail("a statement index read failed", tSC, .pHttpStatus, .pFault)
    If pRaw.%Get("stopped") || pRaw.%Get("changed") || (pRaw.%Get("sqlcode") < 0) || pRaw.%Get("more") || (pRaw.%GetTypeOf("rows") '= "array") {
        Quit ..Fail("a statement index read failed", $$$ERROR($$$GeneralError, $Select(pRaw.%Get("changed"): "not prepared", pRaw.%Get("stopped"): "stopped", 1: "refused")), .pHttpStatus, .pFault)
    }
    Quit $$$OK
}

/// <p>The one number <var>pText</var> counts in <var>pNamespace</var>, with <var>pValues</var> bound, as <var>pCount</var>.</p>
ClassMethod CountOf(pNamespace As %String, pText As %String, pValues As %DynamicArray, Output pCount As %Integer, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pCount = 0
    Set tSC = ..ReadRows(pNamespace, pText, pValues, 2, .tRaw, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If tRaw.%Get("rows").%Size() '= 1 Quit ..Fail("a statement index count answered no row", $$$ERROR($$$GeneralError, "no row"), .pHttpStatus, .pFault)
    Set pCount = +tRaw.%Get("rows").%Get(0).%Get(0)
    Quit $$$OK
}

/// <p>The statement index's answer for <var>pId</var> in <var>pNamespace</var>: for a hash, the statement's
/// <code>{Namespace, Hash, PlanState, NewPlan, PlanError, Executions, AverageTime, Tables}</code> read through
/// <parameter>OcuPilot.Port.AtelierPort.CATALOGSTATEMENTINDEXQUERY</parameter> with the hash bound, 404 <code>PORT.NOTFOUND</code>
/// when the index holds none; a list of <code>Tables</code> cut at <parameter>MAXCELL</parameter> characters is the internal fault,
/// since a cut list could hide a table. For <parameter>ALLID</parameter>, <code>{Namespace, Statements, Stale}</code>: how many
/// statements the index holds and how many of them no class or routine holds a location of and are not frozen. A statement's <code>Executions</code> and
/// <code>AverageTime</code> are numbers, or <code>""</code> where it has none.</p>
ClassMethod StatementRead(pNamespace As %String, pId As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pAnswer = ""
    Set tAnswer = {}
    Do tAnswer.%Set("Namespace", pNamespace, "string")
    If pId = ..#ALLID {
        Set tSC = ..CountOf(pNamespace, ..#INDEXCOUNTQUERY, [], .tStatements, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        Set tSC = ..CountOf(pNamespace, ..#STALECOUNTQUERY, [], .tStale, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        Do tAnswer.%Set("Statements", tStatements, "number")
        Do tAnswer.%Set("Stale", tStale, "number")
        Set pAnswer = tAnswer
        Quit $$$OK
    }
    Set tSC = ..ReadRows(pNamespace, ##class(OcuPilot.Port.AtelierPort).#CATALOGSTATEMENTINDEXQUERY, [(pId), (pId)], 2, .tRaw, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tRows = tRaw.%Get("rows")
    If (tRows.%Size() '= 1) || (tRows.%Get(0).%Get(0) '= pId) {
        Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, ##class(OcuPilot.Api.AtelierError).#REASONSTATEMENTNOTFOUND, .pHttpStatus, .pFault)
    }
    Set tRow = tRows.%Get(0)
    Set tTables = tRow.%Get(14)
    If ($Length(tTables) = ..#MAXCELL) && ($Extract(tTables, *) = $Char(8230)) {
        Quit ..Fail("a statement's tables are cut by the read's cell bound", $$$ERROR($$$GeneralError, "cut"), .pHttpStatus, .pFault)
    }
    Do tAnswer.%Set("Hash", tRow.%Get(0), "string")
    Do tAnswer.%Set("PlanState", tRow.%Get(1), "string")
    Do tAnswer.%Set("NewPlan", (tRow.%Get(2) = 1), "boolean")
    Do tAnswer.%Set("PlanError", tRow.%Get(3), "string")
    Do ..SetNumber(tAnswer, "Executions", tRow.%Get(6))
    Do ..SetNumber(tAnswer, "AverageTime", tRow.%Get(8))
    Set tList = []
    If tTables '= "" {
        For tI = 1:1:$Length(tTables, ",") {
            Do tList.%Push($Piece(tTables, ",", tI), "string")
        }
    }
    Do tAnswer.%Set("Tables", tList)
    Set pAnswer = tAnswer
    Quit $$$OK
}

/// <p><var>pValue</var> as member <var>pName</var> of <var>pObject</var>: a number when it is one, else the text, which is
/// <code>""</code> where the instance holds none.</p>
ClassMethod SetNumber(pObject As %DynamicObject, pName As %String, pValue As %String) [ Private ]
{
    If (pValue '= "") && $IsValidNum(pValue) {
        Do pObject.%Set(pName, +pValue, "number")
    } Else {
        Do pObject.%Set(pName, pValue, "string")
    }
}

/// <p>The statement write <var>pType</var> (<parameter>STATEMENTWRITES</parameter>) on <var>pId</var>, a hash or, for
/// <parameter>TYPECLEAN</parameter>, <parameter>ALLID</parameter>, in <var>pNamespace</var>. The write is the one vendor call
/// <method>StatementCall</method> makes; a refusal that call answers is 409 <code>SQL.STATEMENT.VENDOR</code>.</p>
ClassMethod StatementWrite(pNamespace As %String, pType As %String, pId As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pAnswer = ""
    Set tSC = ..Applied(pNamespace, pType, pId, .tStatus)
    If $$$ISERR(tSC) Quit ..Fail("a statement write failed", tSC, .pHttpStatus, .pFault)
    If $$$ISERR(tStatus) {
        Set tDetail = {}
        Do tDetail.%Set("message", $System.Status.GetErrorText(tStatus), "string")
        If pType = ..#TYPEPURGESTATS Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.AtelierError).#RUNTIMESTATSVENDOR, ##class(OcuPilot.Api.AtelierError).#REASONRUNTIMESTATSVENDOR, .pHttpStatus, .pFault, tDetail)
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.AtelierError).#STATEMENTVENDOR, ##class(OcuPilot.Api.AtelierError).#REASONSTATEMENTVENDOR, .pHttpStatus, .pFault, tDetail)
    }
    Set pAnswer = {}
    Do pAnswer.%Set("Namespace", pNamespace, "string")
    Do pAnswer.%Set("Target", pId, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The runtime statistics read (<parameter>TYPESTATS</parameter>): <code>{Namespace, Rows}</code>, the number of runtime statistics rows
/// <var>pNamespace</var> holds (<method>StatsCount</method>).</p>
ClassMethod RuntimeStatsRead(pNamespace As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pAnswer = ""
    Set tSC = ..StatsCount(pNamespace, .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pAnswer = {}
    Do pAnswer.%Set("Namespace", pNamespace, "string")
    Do pAnswer.%Set("Rows", tRows, "number")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>How many runtime statistics rows <var>pNamespace</var> holds, as <var>pCount</var>, from <parameter>STATSCOUNTQUERY</parameter> with the
/// namespace bound, prepared without SQL privilege checks and run in <var>pNamespace</var>. A statement the instance refuses or a failed read is
/// the internal fault. The switched region calls vendor classes only.</p>
ClassMethod StatsCount(pNamespace As %String, Output pCount As %Integer, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pCount = 0
    Set tText = ..#STATSCOUNTQUERY
    Set tBound = $ZConvert(pNamespace, "U")
    Set tCode = 0
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare(tText, 0)
        If $$$ISOK(tSC) {
            Set tResult = tStatement.%Execute(tBound)
            Set tCode = tResult.%SQLCODE
            If (tCode >= 0) && tResult.%Next() Set pCount = +tResult.%GetData(1)
        }
        Set (tResult, tStatement) = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ERROR($$$GeneralError, "the runtime statistics count raised " _ ex.Name)
    }
    If $$$ISOK(tSC) && (tCode < 0) Set tSC = $$$ERROR($$$GeneralError, "the runtime statistics count answered SQLCODE " _ tCode)
    If $$$ISERR(tSC) Quit ..Fail("the runtime statistics count failed", tSC, .pHttpStatus, .pFault)
    Quit $$$OK
}

/// <p>The one vendor call of statement write <var>pType</var> on <var>pHash</var>, in <var>pNamespace</var>, as its status:
/// <code>FreezeStatement</code>, <code>UnfreezeStatement</code> and <code>ClearStatement</code> with the hash alone, the plan
/// error update with the hash and an empty error, <code>Clean</code>, which takes no argument and cleans the namespace's stale
/// entries, and the runtime statistics purge (<code>clearStatsSQL</code> with the namespace alone, which answers the rows it removed or an error
/// status). A call that answers no status is <code>$$$OK</code>. The namespace is switched by save and restore around the vendor
/// call alone, restored first when it throws, and the throw is passed on. Overridable so a fixture can feed an error status;
/// production overrides none.</p>
ClassMethod StatementCall(pType As %String, pHash As %String, pNamespace As %String) As %Status
{
    Set tStatus = $$$ERROR($$$GeneralError, "no statement call for " _ pType)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        If pType = ..#TYPEFREEZE {
            Set tStatus = $SYSTEM.SQL.Statement.FreezeStatement(pHash)
        } ElseIf pType = ..#TYPEUNFREEZE {
            Set tStatus = $SYSTEM.SQL.Statement.UnfreezeStatement(pHash)
        } ElseIf pType = ..#TYPECLEARSTATISTICS {
            Set tStatus = $SYSTEM.SQL.Statement.ClearStatement(pHash)
        } ElseIf pType = ..#TYPECLEARERROR {
            Do UpdateSQLIndex^%SYS.SQLSRV(pHash, "")
            Set tStatus = $$$OK
        } ElseIf pType = ..#TYPECLEAN {
            Do $SYSTEM.SQL.Statement.Clean()
            Set tStatus = $$$OK
        } ElseIf pType = ..#TYPEPURGESTATS {
            Set tCleared = ##class(%SYS.PTools.StatsSQL).clearStatsSQL(pNamespace, "", 0, 1, 0, 1)
            Set tStatus = $Select($Match(tCleared, "^[0-9]+$"): $$$OK, $System.Status.IsError(tCleared): tCleared, 1: $$$ERROR($$$GeneralError, "the runtime statistics purge answered no count"))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Quit tStatus
}

/// <p>The call of <var>pType</var> in <var>pNamespace</var>: <method>StatementCall</method> with <var>pArgument</var>, a hash, or
/// <parameter>PURGECLASS</parameter>'s <code>PurgeCachedQueries</code> with <var>pArgument</var>, the qualifiers, answering the call's
/// own status as <var>pStatus</var>. Each call is named <var>pNamespace</var> and switches to it around its vendor call alone, so no
/// OcuPilot class is called while switched; the returned status is an unexpected failure.</p>
ClassMethod Applied(pNamespace As %String, pType As %String, pArgument, Output pStatus As %Status) As %Status [ Private ]
{
    Set pStatus = $$$OK
    Set tSC = $$$OK
    Try {
        If pType = ..#TYPEPURGEQUERIES {
            Set pStatus = $ClassMethod(..#PURGECLASS, "PurgeCachedQueries", pArgument, pNamespace)
        } Else {
            Set pStatus = ..StatementCall(pType, pArgument, pNamespace)
        }
    } Catch ex {
        Set tSC = $$$ERROR($$$GeneralError, "the write raised " _ ex.Name)
    }
    Quit tSC
}

/// <p>What <var>pId</var> names in <var>pNamespace</var> as the target of a cached-query purge, with the count of cached queries it
/// holds, in <var>pCount</var>:</p>
/// <ul>
/// <li><parameter>ALLID</parameter>: <var>pKind</var> <code>namespace</code>, the namespace's cached queries;</li>
/// <li>a class (<parameter>CACHEDQUERYPATTERN</parameter>) of the namespace: <code>class</code>, 404 <code>PORT.NOTFOUND</code> when
/// no statement index location names it, and 400 <code>PORT.VALIDATION</code> for a class of another namespace;</li>
/// <li>a table, <code>Schema.Table</code>: <code>table</code>, resolved through the caller's own information schema as
/// <method>BrowsePlan</method> resolves one, 404 when it shows none and 400 for a name that matches more than one.</li>
/// </ul>
/// <p>The count is the distinct <parameter>CACHEDQUERYPREFIX</parameter> locations in the index for the target, a table's joined through
/// its relation key. <var>pName</var> is the target as the instance holds it.</p>
ClassMethod PurgeTarget(pNamespace As %String, pId As %String, Output pKind As %String, Output pName As %String, Output pCount As %Integer, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pKind = ""
    Set pName = ""
    Set pCount = 0
    Set tPort = "OcuPilot.Port.AtelierPort"
    If pId = ..#ALLID {
        Set pKind = "namespace"
        Set pName = ..#ALLID
        Quit ..CountOf(pNamespace, ..#PURGENAMESPACEQUERY, [(..#CACHEDQUERYPREFIX)], .pCount, .pHttpStatus, .pFault)
    }
    If $Extract(pId, 1, $Length(..#CACHEDQUERYPREFIX)) = ..#CACHEDQUERYPREFIX {
        If '$Match(pId, ..#CACHEDQUERYPATTERN) || ($ZConvert($Piece(pId, ".", 2), "U") '= $ZConvert(pNamespace, "U")) {
            Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Api.Error).#REASONPORTFIELDSHAPE, .pHttpStatus, .pFault)
        }
        Set tSC = ..CountOf(pNamespace, ..#PURGENAMESPACEQUERY, [(pId _ ".")], .pCount, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        If pCount = 0 {
            Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, ##class(OcuPilot.Api.AtelierError).#REASONCACHEDQUERYNOTFOUND, .pHttpStatus, .pFault)
        }
        Set pKind = "class"
        Set pName = pId
        Quit $$$OK
    }
    Set tSC = ..ResolveTable(pNamespace, pId, .tSchema, .tTable, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pKind = "table"
    Set pName = tSchema _ "." _ tTable
    Quit ..CountOf(pNamespace, ..#PURGETABLEQUERY, [($ClassMethod(tPort, "CatalogRelation", tSchema, tTable)), (..#CACHEDQUERYPREFIX)], .pCount, .pHttpStatus, .pFault)
}

/// <p>The base table <var>pId</var>, <code>Schema.Table</code>, names in <var>pNamespace</var> as the caller's own information schema shows it
/// (<parameter>OcuPilot.Port.AtelierPort.CATALOGRESOLVEQUERY</parameter>), as <var>pSchema</var> and <var>pTable</var> spelled as the instance holds
/// them. A name outside the table shape (no dot, over <parameter>OcuPilot.Port.AtelierPort.MAXTABLE</parameter> characters, or a control character)
/// is 400 <code>PORT.VALIDATION</code>, a name the caller's schema shows no table for is 404 <code>PORT.NOTFOUND</code>, and one that matches more than
/// one table is 400.</p>
ClassMethod ResolveTable(pNamespace As %String, pId As %String, Output pSchema As %String, Output pTable As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pSchema = ""
    Set pTable = ""
    Set tPort = "OcuPilot.Port.AtelierPort"
    If (pId '[ ".") || ($Length(pId) > $Parameter(tPort, "MAXTABLE")) || ($ZStrip(pId, "*C") '= pId) {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, $Parameter(tPort, "REASONCATALOGTABLE"), .pHttpStatus, .pFault)
    }
    Set tSC = ..ReadRows(pNamespace, $Parameter(tPort, "CATALOGRESOLVEQUERY"), [(pId)], 3, .tRaw, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tRows = tRaw.%Get("rows")
    If tRows.%Size() = 0 {
        Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, $Parameter(tPort, "REASONCATALOGNOTFOUND"), .pHttpStatus, .pFault)
    }
    If tRows.%Size() > 1 {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, $Parameter(tPort, "REASONCATALOGAMBIGUOUS"), .pHttpStatus, .pFault)
    }
    Set pSchema = tRows.%Get(0).%Get(0)
    Set pTable = tRows.%Get(0).%Get(1)
    Quit $$$OK
}

/// <p>The cached-query purge's fresh read: <code>{Namespace, Target, Kind, CachedQueries}</code> for <var>pId</var>
/// (<method>PurgeTarget</method>).</p>
ClassMethod PurgeRead(pNamespace As %String, pId As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pAnswer = ""
    Set tSC = ..PurgeTarget(pNamespace, pId, .tKind, .tName, .tCount, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pAnswer = {}
    Do pAnswer.%Set("Namespace", pNamespace, "string")
    Do pAnswer.%Set("Target", tName, "string")
    Do pAnswer.%Set("Kind", tKind, "string")
    Do pAnswer.%Set("CachedQueries", tCount, "number")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The cached-query purge of <var>pId</var> in <var>pNamespace</var>: the target is resolved as <method>PurgeRead</method>
/// resolves it, and <code>PurgeQueries</code> is called with qualifiers built from it alone, <code>{}</code> for the namespace,
/// <code>{"table": [...]}</code> for a table and <code>{"class": [...]}</code> for one cached query. A purge the instance answers
/// with an error status is the internal fault.</p>
ClassMethod PurgeWrite(pNamespace As %String, pId As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pAnswer = ""
    Set tSC = ..PurgeTarget(pNamespace, pId, .tKind, .tName, .tCount, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tQualifiers = $Case(tKind, "namespace": {}, "table": {"table": [(tName)]}, : {"class": [(tName)]})
    Set tSC = ..Applied(pNamespace, ..#TYPEPURGEQUERIES, tQualifiers, .tStatus)
    If $$$ISOK(tSC) && $$$ISERR(tStatus) Set tSC = tStatus
    If $$$ISERR(tSC) Quit ..Fail("the cached queries could not be purged", tSC, .pHttpStatus, .pFault)
    Set pAnswer = {}
    Do pAnswer.%Set("Namespace", pNamespace, "string")
    Do pAnswer.%Set("Target", tName, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The table maintenance way in (Story 21.25, AD-51, AD-52): serve <var>pType</var> of <parameter>ENDPOINTTABLES</parameter>. <var>pQuery</var> carries
/// <code>id</code>, the target (a table as <code>Schema.Table</code>, or for <parameter>TYPEINDEX</parameter> and <parameter>TYPEREBUILD</parameter> the
/// composite <code>[Table, Map]</code>), and <code>namespace</code>, or the request's resolved scope where it is absent. <var>pResult</var> is the read's
/// answer (<method>TableAnswer</method>), or a write's <code>{Namespace, Target}</code>.</p>
/// <p><b>The order of every call is fixed.</b> A type this endpoint does not serve is 501 <code>PORT.NOTIMPLEMENTED</code>; then the gate
/// (<method>Gate</method>, a write with <method>OcuPilot.Port.AtelierPort.WritePairs</method>), 403 naming the failed pair; then the target's shape, 400
/// <code>PORT.VALIDATION</code>; then the table, resolved through the caller's own information schema (<method>ResolveTable</method>); then the call.
/// Nothing is read or written before the gate has answered.</p>
ClassMethod TablesInvoke(pType As %String, ByRef pQuery, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tWrite = ''$ListFind($ListFromString(..#TABLEWRITES), pType)
    If 'tWrite && (pType '= ..#TYPETABLESTATS) && (pType '= ..#TYPEINDEX) && (pType '= ..#TYPESCHEMA) && (pType '= ..#TYPEFIELDSTATS) {
        Quit ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, ##class(OcuPilot.Port.AtelierPort).#REASONNOTIMPLEMENTED, .pHttpStatus, .pFault)
    }
    Set tNamespace = $Get(pQuery(..#NAMESPACEKEY))
    If tNamespace = "" Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
    Set tSC = ..Gate(tNamespace, .pHttpStatus, .pFault, tWrite)
    If $$$ISERR(tSC) Quit tSC
    Set tId = $Get(pQuery(..#IDKEY))
    Set tValues = ""
    If pType = ..#TYPETUNESCHEMA {
        Set tSC = ..TuneValues(pType, .pQuery, .tValues, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
    }
    If (pType = ..#TYPESETEXTENT) || (pType = ..#TYPESETSELECTIVITY) || (pType = ..#TYPESETMAPSIZE) {
        Set tSC = ..SetValues(pType, .pQuery, .tValues, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
    }
    If (pType = ..#TYPESCHEMA) || (pType = ..#TYPETUNESCHEMA) {
        Quit ..SchemaServe(tNamespace, pType, tId, tValues, .pResult, .pHttpStatus, .pFault)
    }
    Set tTableId = tId
    Set (tMap, tField) = ""
    If (pType = ..#TYPEINDEX) || (pType = ..#TYPEREBUILD) || (pType = ..#TYPESETMAPSIZE) || (pType = ..#TYPEFIELDSTATS) || (pType = ..#TYPESETSELECTIVITY) {
        Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(tId)
        Set tSecond = $ListGet(tParts, 2)
        If ($ListLength(tParts) '= 2) || ($List(tParts, 1) = "") || (tSecond = "") || ($Length(tSecond) > ..#MAXNAME) || ($ZStrip(tSecond, "*C") '= tSecond) {
            Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Api.Error).#REASONPORTFIELDSHAPE, .pHttpStatus, .pFault)
        }
        If (pType = ..#TYPEFIELDSTATS) || (pType = ..#TYPESETSELECTIVITY) {
            Set tField = tSecond
        } Else {
            Set tMap = tSecond
        }
        Set tTableId = $List(tParts, 1)
    }
    Set tSC = ..TableTarget(tNamespace, tTableId, tMap, tField, .tFacts, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If 'tWrite {
        Set pResult = ..TableAnswer(pType, tNamespace, tFacts)
        Quit $$$OK
    }
    Quit ..TableWrite(tNamespace, pType, tId, tFacts, tValues, .pResult, .pHttpStatus, .pFault)
}

/// <p>The schema tune's declared boolean, as the text <method>TableCall</method> takes: <code>1</code> or <code>0</code> for whether the fixed values are
/// cleared. The query key is <code>true</code> or <code>false</code>, and anything else, or none, is 400 <code>PORT.VALIDATION</code> before any call.</p>
ClassMethod TuneValues(pType As %String, ByRef pQuery, Output pValues As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pValues = ""
    Set tClear = $Get(pQuery(..#CLEARVALUESKEY))
    If (tClear '= "true") && (tClear '= "false") {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Api.Error).#REASONPORTFIELDSHAPE, .pHttpStatus, .pFault)
    }
    Set pValues = (tClear = "true")
    Quit $$$OK
}

/// <p>The declared values of setter <var>pType</var> (<parameter>TYPESETEXTENT</parameter>, <parameter>TYPESETSELECTIVITY</parameter> or
/// <parameter>TYPESETMAPSIZE</parameter>), read from <var>pQuery</var> under their own names, as <var>pValues</var>, a JSON object of the text
/// <method>TableCall</method> sends: the extent size, the map's <code>SizeMB</code>, or the selectivity with the outlier selectivity, outlier value and
/// average size where they are present (an empty one is not). The required value is checked by <method>ValueProblem</method> here, before any call, and
/// a selectivity is sent with its <code>%</code>, but for <code>1</code>, a unique field's selectivity; a value outside its shape is 400, its code
/// carrying the published sentence. A selectivity's optional values are checked once the field is read (<method>TableWrite</method>).</p>
ClassMethod SetValues(pType As %String, ByRef pQuery, Output pValues As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pValues = ""
    Set tNames = $Case(pType, ..#TYPESETEXTENT: ..#EXTENTSIZEKEY, ..#TYPESETMAPSIZE: ..#SIZEMBKEY, : ..#SELECTIVITYKEY _ "," _ ..#OUTLIERSELECTIVITYKEY _ "," _ ..#OUTLIERVALUEKEY _ "," _ ..#AVERAGESIZEKEY)
    Set tValues = {}
    Set tReason = ""
    For tI = 1:1:$Length(tNames, ",") {
        Set tName = $Piece(tNames, ",", tI)
        Set tText = $Get(pQuery(tName))
        If (tText = "") && (tI > 1) Continue
        If (pType '= ..#TYPESETSELECTIVITY) || (tI = 1) {
            Set tReason = ..ValueProblem(tName, tText, .tCode)
            If tReason '= "" Quit
            If tName = ..#SELECTIVITYKEY Set tText = ..PercentText(tText, 1)
        }
        Do tValues.%Set(tName, tText, "string")
    }
    If tReason '= "" Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, tCode, tReason, .pHttpStatus, .pFault)
    Set pValues = tValues.%ToJSON()
    Quit $$$OK
}

/// <p>The first reason one of a selectivity's optional values in <var>pSet</var> (<method>SetValues</method>'s object) is not one the instance may be sent,
/// with its code as <var>pCode</var>, or <code>""</code>. A value that is the one the field holds in use now (<var>pFacts</var>'s field row, the fixed value
/// where the table has fixed statistics and the collected one otherwise) is not a declared change: the request may carry the values the field was read
/// with, which the collected statistics may hold as fractions, so it is dropped from <var>pSet</var> and <method>SettingCall</method> reads the field's own.
/// Any other is checked by <method>ValueProblem</method>, and an outlier selectivity is given its <code>%</code>.</p>
ClassMethod OptionalProblem(pSet As %DynamicObject, pFacts As %DynamicObject, Output pCode As %String) As %String
{
    Set pCode = ""
    Set tRow = pFacts.%Get("Field")
    Set tKind = $Select(pFacts.%Get("HasFixed"): "Fixed", 1: "Collected")
    For tName = ..#OUTLIERSELECTIVITYKEY, ..#OUTLIERVALUEKEY, ..#AVERAGESIZEKEY {
        Set tText = pSet.%Get(tName)
        If tText = "" Continue
        Set tHeld = tRow.%Get(tKind _ tName)
        If tName = ..#OUTLIERVALUEKEY Set tHeld = ..OutlierPlain(tHeld)
        Set tSame = (tText = tHeld)
        If 'tSame && (tName '= ..#OUTLIERVALUEKEY) && $IsValidNum($Translate(tText, "%")) && $IsValidNum($Translate(tHeld, "%")) Set tSame = (+$Translate(tText, "%") = +$Translate(tHeld, "%"))
        If tSame {
            Do pSet.%Remove(tName)
            Continue
        }
        Set tReason = ..ValueProblem(tName, tText, .pCode)
        If tReason '= "" Quit
        If tName = ..#OUTLIERSELECTIVITYKEY Do pSet.%Set(tName, ..PercentText(tText, 0), "string")
    }
    Quit $Get(tReason)
}

/// <p>Why <var>pValue</var> is not a value of the setter's value <var>pName</var> (<parameter>EXTENTSIZEKEY</parameter>,
/// <parameter>SELECTIVITYKEY</parameter>, <parameter>OUTLIERSELECTIVITYKEY</parameter>, <parameter>OUTLIERVALUEKEY</parameter>,
/// <parameter>AVERAGESIZEKEY</parameter> or <parameter>SIZEMBKEY</parameter>), as the published sentence, with its code as <var>pCode</var>, or
/// <code>""</code> for a value the instance may be sent. An extent size is a whole number from 0 to <parameter>MAXEXTENTSIZE</parameter>. A
/// selectivity or outlier selectivity is <code>1</code> or a percentage over 0 and up to <parameter>MAXSELECTIVITY</parameter>, with or without its
/// <code>%</code>. An average size is a whole number of <parameter>WHOLEPATTERN</parameter> and a map's size one of <parameter>POSITIVEPATTERN</parameter>.
/// An outlier value is plain data of at most <parameter>MAXOUTLIERVALUE</parameter> characters holding no control character; it is never run
/// (<method>OutlierExpression</method>). Pure.</p>
ClassMethod ValueProblem(pName As %String, pValue As %String, Output pCode As %String) As %String
{
    Set tError = "OcuPilot.Api.AtelierError"
    Set pCode = ""
    If pName = ..#EXTENTSIZEKEY {
        If '$Match(pValue, "^(0|[1-9][0-9]{0,12})$") || (pValue > ..#MAXEXTENTSIZE) Set pCode = $Parameter(tError, "TABLEEXTENTSIZE")
    } ElseIf (pName = ..#SELECTIVITYKEY) || (pName = ..#OUTLIERSELECTIVITYKEY) {
        If '..PercentValid(pValue) Set pCode = $Parameter(tError, "TABLESELECTIVITY")
    } ElseIf pName = ..#SIZEMBKEY {
        If '$Match(pValue, ..#POSITIVEPATTERN) Set pCode = $Parameter(tError, "TABLEMAPSIZE")
    } ElseIf pName = ..#AVERAGESIZEKEY {
        If '$Match(pValue, ..#WHOLEPATTERN) Set pCode = $Parameter(tError, "TABLEWHOLENUMBER")
    } ElseIf pName = ..#OUTLIERVALUEKEY {
        If $Length(pValue) > ..#MAXOUTLIERVALUE {
            Set pCode = $Parameter(tError, "TABLEOUTLIERVALUE")
        } ElseIf (pValue = "") || ($ZStrip(pValue, "*C") '= pValue) || (pValue [ $Char(127)) {
            Set pCode = ##class(OcuPilot.Api.Error).#PORTVALIDATION
            Quit ##class(OcuPilot.Api.Error).#REASONPORTFIELDSHAPE
        }
    } Else {
        Set pCode = ##class(OcuPilot.Api.Error).#PORTVALIDATION
        Quit ##class(OcuPilot.Api.Error).#REASONPORTFIELDSHAPE
    }
    If pCode = "" Quit ""
    Quit ##class(OcuPilot.Api.AtelierError).SqlReasonFor(pCode)
}

/// <p>Whether <var>pValue</var> is <code>1</code>, a unique field's selectivity, or a percentage over 0 and up to
/// <parameter>MAXSELECTIVITY</parameter>, with or without a trailing <code>%</code>. Pure.</p>
ClassMethod PercentValid(pValue As %String) As %Boolean
{
    If pValue = "1" Quit 1
    Set tNumber = $Select($Extract(pValue, *) = "%": $Extract(pValue, 1, *-1), 1: pValue)
    If '$Match(tNumber, ..#PERCENTPATTERN) Quit 0
    Quit (+tNumber > 0) && (+tNumber <= ..#MAXSELECTIVITY)
}

/// <p>The text of the percentage <var>pValue</var> as the instance is sent it: with its <code>%</code>, which the instance needs to read it as a
/// percentage (a bare number is a count of rows), except <code>1</code> where <var>pUnique</var>, a unique field's selectivity. Pure.</p>
ClassMethod PercentText(pValue As %String, pUnique As %Boolean) As %String
{
    If pUnique && (pValue = "1") Quit "1"
    If $Extract(pValue, *) = "%" Quit pValue
    Quit pValue _ "%"
}

/// <p>The expression the instance is handed for the plain outlier value <var>pValue</var>, which it evaluates and runs: a canonical number as it is, and
/// anything else as a double-quoted string literal with each embedded quote doubled, so the caller's text is data and never code. Pure.</p>
ClassMethod OutlierExpression(pValue As %String) As %String
{
    If ($Number(pValue) '= "") && (+pValue = pValue) Quit pValue
    Quit """" _ $Replace(pValue, """", """""") _ """"
}

/// <p>The plain text of the outlier value <var>pStored</var> as the instance holds it: a double-quoted string literal reads as its inner text with the
/// doubled quotes undone, and anything else, a number or an expression set through the classic page, as it is. Pure.</p>
ClassMethod OutlierPlain(pStored As %String) As %String
{
    If '$Match(pStored, ..#OUTLIERSTRINGPATTERN) Quit pStored
    Quit $Replace($Extract(pStored, 2, *-1), """""", """")
}

/// <p>The schema's read (<parameter>TYPESCHEMA</parameter>, <code>{Namespace, Schema, Tables}</code>) and its tune (<parameter>TYPETUNESCHEMA</parameter>,
/// <code>{Namespace, Target}</code>) for the schema <var>pSchemaId</var> of <var>pNamespace</var>, which the caller's own information schema must show
/// at least one base table of (<parameter>SCHEMANAMEQUERY</parameter>, <parameter>SCHEMATABLESQUERY</parameter>): a name outside the schema shape is 400 <code>PORT.VALIDATION</code> and a schema it
/// shows none of is 404 <code>PORT.NOTFOUND</code>. <code>Schema</code> is spelled as the instance holds it and <code>Tables</code> counts the base tables
/// the caller sees; it also answers the declared boolean as <code>null</code>, so a merge of the value makes its row on the card. A tune is the one vendor call <method>TableCall</method> makes, with the declared <var>pValues</var>; a refusal the instance answers is
/// 409 <code>SQL.TABLE.VENDOR</code>, its message in <code>detail.message</code> alone and never logged.</p>
ClassMethod SchemaServe(pNamespace As %String, pType As %String, pSchemaId As %String, pValues As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set tPort = "OcuPilot.Port.AtelierPort"
    If (pSchemaId = "") || ($Length(pSchemaId) > $Parameter(tPort, "MAXSCHEMA")) || ($ZStrip(pSchemaId, "*C") '= pSchemaId) {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, $Parameter(tPort, "REASONCATALOGSCHEMA"), .pHttpStatus, .pFault)
    }
    Set tSC = ..ReadRows(pNamespace, ..#SCHEMANAMEQUERY, [(pSchemaId)], 3, .tRaw, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tRows = tRaw.%Get("rows")
    If tRows.%Size() = 0 {
        Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, $Parameter(tPort, "REASONCATALOGNOTFOUND"), .pHttpStatus, .pFault)
    }
    Set tSchema = tRows.%Get(0).%Get(0)
    If pType = ..#TYPESCHEMA {
        Set tSC = ..CountOf(pNamespace, ..#SCHEMATABLESQUERY, [(tSchema)], .tTables, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
        Set pResult = {}
        Do pResult.%Set("Namespace", pNamespace, "string")
        Do pResult.%Set("Schema", tSchema, "string")
        Do pResult.%Set("Tables", tTables, "number")
        Do pResult.%Set(..#CLEARVALUESKEY, "", "null")
        Set pHttpStatus = 200
        Quit $$$OK
    }
    Quit ..TableWritten(pNamespace, pType, tSchema, pValues, pSchemaId, .pResult, .pHttpStatus, .pFault)
}

/// <p>What <var>pTableId</var> names in <var>pNamespace</var>, resolved through the caller's own information schema, with the instance's facts about it
/// in <var>pFacts</var> (<method>TableFacts</method>) and the table as <code>Table</code>, <code>Schema.Table</code> spelled as the instance holds it.
/// With <var>pMap</var>, the index of that SQL map name too, and with <var>pField</var> that field's statistics; a table that has no class to address is
/// 404 <code>PORT.NOTFOUND</code>, and a map or a field the table does not hold is 400 <code>PORT.VALIDATION</code>.</p>
ClassMethod TableTarget(pNamespace As %String, pTableId As %String, pMap As %String, pField As %String, Output pFacts As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pFacts = ""
    Set tSC = ..ResolveTable(pNamespace, pTableId, .tSchema, .tTable, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..TableFacts(pNamespace, tSchema, tTable, pMap, pField, .tFacts)
    If $$$ISERR(tSC) Quit ..Fail("a table's statistics could not be read", tSC, .pHttpStatus, .pFault)
    If tFacts.%Get("Class") = "" {
        Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#PORTNOTFOUND, ##class(OcuPilot.Port.AtelierPort).#REASONCATALOGNOTFOUND, .pHttpStatus, .pFault)
    }
    If ((pMap '= "") && 'tFacts.%Get("Found")) || ((pField '= "") && 'tFacts.%Get("FieldFound")) {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Api.Error).#REASONPORTFIELDSHAPE, .pHttpStatus, .pFault)
    }
    Do tFacts.%Set("Table", tSchema _ "." _ tTable, "string")
    Do tFacts.%Set("Schema", tSchema, "string")
    Do tFacts.%Set("Name", tTable, "string")
    Set pFacts = tFacts
    Quit $$$OK
}

/// <p>What the instance holds about the table <var>pSchema</var>.<var>pTable</var> of <var>pNamespace</var>, read with vendor calls alone while switched
/// to it (AD-16; the restore is the first line of the <code>Catch</code>), as <var>pFacts</var>: <code>Class</code>, the class the table's indices are
/// built through (the parent's, for a collection child table, as the classic page uses it), <code>HasFixed</code>, <code>StatsKind</code>
/// (<code>fixed</code>, <code>collected</code> or <code>none</code>), <code>ExtentSize</code> and <code>CollectedAt</code>. The extent size is the
/// collected one unless the table has fixed statistics, which the optimizer then uses; a table with neither reads the instance's default. With
/// <var>pMap</var>, <code>Found</code> and the index's <code>Index</code>, <code>Map</code>, <code>Type</code> and <code>Argument</code>, the name the
/// instance builds the index by, and <code>SizeMB</code>, the size in MB the indices list reports for it. With <var>pField</var>,
/// <code>FieldFound</code> and the field's row as <method>FieldRead</method> answers it, under <code>Field</code>.</p>
ClassMethod TableFacts(pNamespace As %String, pSchema As %String, pTable As %String, pMap As %String, pField As %String, Output pFacts As %DynamicObject) As %Status [ Private ]
{
    Set pFacts = ""
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Set (tClass, tCollected, tAt, tIndex, tType, tArgument) = ""
    Set (tHasFixed, tFound) = 0
    Set tCurrent = 0
    Set tSizeMB = 0
    Set tFieldRow = ""
    Try {
        Set $NAMESPACE = pNamespace
        Set tIQN = $$IntQualifiedName^%apiSQL(pSchema _ "." _ pTable)
        If tIQN '= "" {
            Set tClass = $$$GetClassNameFromIQN(tIQN)
            Set tExtent = $$$GetExtentNameFromIQN(tIQN)
            Set tInfo = $$$EXTsqlinfo($$$rEXT,tExtent)
            If $$$SQLLocTableChildTableType(tInfo) '= "" Set tClass = $$$GetClassNameFromIQN($$$SQLLocTableParentTable(tInfo))
        }
        If tClass '= "" {
            Set tHasFixed = ''##class(%SQL.Manager.Catalog).HasFixedStats(pSchema, pTable)
            Set tCurrent = ##class(%SQL.Manager.Catalog).GetCurrentTableExtentSize(pSchema, pTable)
            Kill tStat
            Do ##class(%SQL.Manager.Catalog).DisplayExtentDBStats(pSchema, pTable, .tStatClass, .tStat, .tStatId)
            If $IsObject($Get(tStat)) {
                Set tCollected = tStat.ExtentSize
                Set tAt = $Translate($Extract(##class(%Library.PosixTime).LogicalToOdbc(tStat.EndTime), 1, 19), " ", "T") _ "Z"
            }
            Set tStat = ""
        }
        If (tClass '= "") && (pMap '= "") {
            Set tStatement = ##class(%SQL.Statement).%New()
            Set tSC = tStatement.%PrepareClassQuery("%SQL.Manager.Catalog", "Indices")
            If $$$ISOK(tSC) {
                Set tResult = tStatement.%Execute(pSchema, pTable)
                If tResult.%SQLCODE < 0 {
                    Set tSC = $$$ERROR($$$GeneralError, "the index list was refused")
                } Else {
                    While tResult.%Next() {
                        If tResult.%Get("SQL_MAP_NAME") = pMap {
                            Set tFound = 1
                            Set tIndex = tResult.%Get("INDEX_NAME")
                            Set tType = tResult.%Get("TYPE")
                            Set tArgument = tResult.%Get("BI_ARGUMENT")
                            If tArgument = "" Set tArgument = tIndex
                            Set tSizeMB = +$Piece(tResult.%Get("SIZE_MB"), " ", 1)
                            Quit
                        }
                    }
                }
            }
            Set tResult = ""
            Set tStatement = ""
        }
        If (tClass '= "") && (pField '= "") && $$$ISOK(tSC) Set tSC = ..FieldRead(pSchema, pTable, pField, .tFieldRow)
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) Quit tSC
    Set tKind = $Select(tHasFixed: "fixed", tCollected '= "": "collected", 1: "none")
    Set pFacts = {}
    Do pFacts.%Set("Class", tClass, "string")
    Do pFacts.%Set("HasFixed", tHasFixed, "boolean")
    Do pFacts.%Set("StatsKind", tKind, "string")
    Do pFacts.%Set("ExtentSize", $Select(tKind = "collected": +tCollected, 1: +tCurrent), "number")
    Do pFacts.%Set("CollectedAt", tAt, "string")
    Do pFacts.%Set("Found", tFound, "boolean")
    Do pFacts.%Set("Index", tIndex, "string")
    Do pFacts.%Set("Map", $Select(tFound: pMap, 1: ""), "string")
    Do pFacts.%Set("Type", tType, "string")
    Do pFacts.%Set("Argument", tArgument, "string")
    Do pFacts.%Set("SizeMB", tSizeMB, "number")
    Do pFacts.%Set("FieldFound", $IsObject(tFieldRow) && tFieldRow.%Get("Found"), "boolean")
    Do pFacts.%Set("Field", $Select($IsObject(tFieldRow): tFieldRow, 1: {}))
    Quit $$$OK
}

/// <p>The statistics of the field <var>pField</var> of table <var>pSchema</var>.<var>pTable</var>, read in the current namespace
/// (<parameter>FIELDSTATSQUERY</parameter>, bound with the schema and the table, the field matched exactly), as <var>pRow</var>:
/// <code>Found</code> and, as the instance's own text, <code>FixedSelectivity</code>, <code>FixedOutlierSelectivity</code>, <code>FixedOutlierValue</code>,
/// <code>FixedAverageFieldSize</code> and the four <code>Collected</code> ones. An outlier value the instance shows as
/// <parameter>NULLOUTLIER</parameter> is <code>""</code>.</p>
ClassMethod FieldRead(pSchema As %String, pTable As %String, pField As %String, Output pRow As %DynamicObject) As %Status [ Private ]
{
    Set pRow = {}
    Do pRow.%Set("Found", 0, "boolean")
    Set tStatement = ##class(%SQL.Statement).%New()
    Set tSC = tStatement.%Prepare(..#FIELDSTATSQUERY)
    If $$$ISERR(tSC) Quit tSC
    Set tResult = tStatement.%Execute(pSchema, pTable)
    If tResult.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, "the field statistics were refused")
    While tResult.%Next() {
        If tResult.%Get("FIELD_NAME") '= pField Continue
        Do pRow.%Set("Found", 1, "boolean")
        Do pRow.%Set("Name", pField, "string")
        For tName = "Selectivity", "OutlierSelectivity", "OutlierValue", "AverageFieldSize" {
            For tKind = "Fixed", "Collected" {
                Set tText = tResult.%Get($ZConvert(tKind, "U") _ "_" _ $Case(tName, "Selectivity": "SELECTIVITY", "OutlierSelectivity": "OUTLIER_SELECTIVITY", "OutlierValue": "OUTLIER_VALUE", : "AVERAGE_FIELD_SIZE"))
                If (tName = "OutlierValue") && (tText = ..#NULLOUTLIER) Set tText = ""
                Do pRow.%Set(tKind _ tName, tText, "string")
            }
        }
        Quit
    }
    Quit $$$OK
}

/// <p>The read answer of <var>pType</var> (<parameter>TYPETABLESTATS</parameter>, <parameter>TYPEINDEX</parameter> or
/// <parameter>TYPEFIELDSTATS</parameter>) for the facts <var>pFacts</var>
/// <method>TableTarget</method> answered: <code>{Namespace, Table, Class, ExtentSize, StatsKind, CollectedAt, HasFixed}</code> for the
/// table, <code>{Namespace, Table, Class, Index, Map, Type, SizeMB, StatsKind, CollectedAt, HasFixed}</code> for the index, and
/// <code>{Namespace, Table, Class, Field, Selectivity, OutlierSelectivity, OutlierValue, AverageFieldSize, StatsKind, HasFixed}</code> for the field,
/// each value the one in use: the fixed one when the table has fixed statistics, the collected one otherwise. A field's <code>OutlierValue</code> is
/// the plain text of the stored value (<method>OutlierPlain</method>).</p>
ClassMethod TableAnswer(pType As %String, pNamespace As %String, pFacts As %DynamicObject) As %DynamicObject [ Private ]
{
    Set tAnswer = {}
    Do tAnswer.%Set("Namespace", pNamespace, "string")
    Do tAnswer.%Set("Table", pFacts.%Get("Table"), "string")
    Do tAnswer.%Set("Class", pFacts.%Get("Class"), "string")
    If pType = ..#TYPEINDEX {
        Do tAnswer.%Set("Index", pFacts.%Get("Index"), "string")
        Do tAnswer.%Set("Map", pFacts.%Get("Map"), "string")
        Do tAnswer.%Set("Type", pFacts.%Get("Type"), "string")
        Do tAnswer.%Set("SizeMB", pFacts.%Get("SizeMB"), "number")
        Do tAnswer.%Set("StatsKind", pFacts.%Get("StatsKind"), "string")
        Do tAnswer.%Set("CollectedAt", pFacts.%Get("CollectedAt"), "string")
        Do tAnswer.%Set("HasFixed", pFacts.%Get("HasFixed"), "boolean")
        Quit tAnswer
    }
    If pType = ..#TYPEFIELDSTATS {
        Set tRow = pFacts.%Get("Field")
        Set tKind = $Select(pFacts.%Get("HasFixed"): "Fixed", 1: "Collected")
        Do tAnswer.%Set("Field", tRow.%Get("Name"), "string")
        Do tAnswer.%Set("Selectivity", tRow.%Get(tKind _ "Selectivity"), "string")
        Do tAnswer.%Set("OutlierSelectivity", tRow.%Get(tKind _ "OutlierSelectivity"), "string")
        Do tAnswer.%Set("OutlierValue", ..OutlierPlain(tRow.%Get(tKind _ "OutlierValue")), "string")
        Set tAverage = tRow.%Get(tKind _ "AverageFieldSize")
        If tAverage = "" {
            Do tAnswer.%Set("AverageFieldSize", "", "string")
        } Else {
            Do tAnswer.%Set("AverageFieldSize", +tAverage, "number")
        }
        Do tAnswer.%Set("StatsKind", pFacts.%Get("StatsKind"), "string")
        Do tAnswer.%Set("HasFixed", pFacts.%Get("HasFixed"), "boolean")
        Quit tAnswer
    }
    Do tAnswer.%Set("ExtentSize", pFacts.%Get("ExtentSize"), "number")
    Do tAnswer.%Set("StatsKind", pFacts.%Get("StatsKind"), "string")
    Do tAnswer.%Set("CollectedAt", pFacts.%Get("CollectedAt"), "string")
    Do tAnswer.%Set("HasFixed", pFacts.%Get("HasFixed"), "boolean")
    Quit tAnswer
}

/// <p>The table write <var>pType</var> (<parameter>TABLEWRITES</parameter>) on <var>pId</var>, whose facts are <var>pFacts</var>, in
/// <var>pNamespace</var>, with the schema tune's declared boolean <var>pValues</var> (<method>TuneValues</method>). The write is the one vendor call
/// <method>TableCall</method> makes. A rebuild of the table's data map is 409 <code>SQL.TABLE.DATAMAP</code>, the removal of fixed statistics from a table
/// that has none is 409 <code>SQL.TABLE.NOFIXEDSTATS</code>, and a refusal the instance answers is 409 <code>SQL.TABLE.VENDOR</code>, its message in
/// <code>detail.message</code> alone and never logged (AD-39).</p>
ClassMethod TableWrite(pNamespace As %String, pType As %String, pId As %String, pFacts As %DynamicObject, pValues As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pAnswer = ""
    If (pType = ..#TYPEREBUILD) && (pFacts.%Get("Type") [ ..#DATAMAPTYPE) {
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.AtelierError).#TABLEDATAMAP, ##class(OcuPilot.Api.AtelierError).#REASONTABLEDATAMAP, .pHttpStatus, .pFault)
    }
    If (pType = ..#TYPECLEARSTATS) && 'pFacts.%Get("HasFixed") {
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.AtelierError).#TABLENOFIXEDSTATS, ##class(OcuPilot.Api.AtelierError).#REASONTABLENOFIXEDSTATS, .pHttpStatus, .pFault)
    }
    If (pType = ..#TYPETUNE) || (pType = ..#TYPECLEARSTATS) {
        Set tTarget = pFacts.%Get("Table")
        Set tValues = ""
    } ElseIf (pType = ..#TYPESETEXTENT) || (pType = ..#TYPESETSELECTIVITY) || (pType = ..#TYPESETMAPSIZE) {
        Set tTarget = pFacts.%Get("Table")
        Set tSet = ##class(%DynamicObject).%FromJSON(pValues)
        If pType = ..#TYPESETSELECTIVITY {
            Set tReason = ..OptionalProblem(tSet, pFacts, .tCode)
            If tReason '= "" Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, tCode, tReason, .pHttpStatus, .pFault)
        }
        Do tSet.%Set("StatsKind", pFacts.%Get("StatsKind"), "string")
        If pType = ..#TYPESETMAPSIZE Do tSet.%Set("Map", pFacts.%Get("Map"), "string")
        If pType = ..#TYPESETSELECTIVITY Do tSet.%Set("Field", pFacts.%Get("Field").%Get("Name"), "string")
        Set tValues = tSet.%ToJSON()
    } Else {
        Set tTarget = pFacts.%Get("Class")
        Set tValues = $Select(pType = ..#TYPEREBUILD: pFacts.%Get("Argument"), 1: "")
    }
    Quit ..TableWritten(pNamespace, pType, tTarget, tValues, pId, .pAnswer, .pHttpStatus, .pFault)
}

/// <p>Table write <var>pType</var> made as <method>TableCall</method> makes it with <var>pTarget</var> and <var>pValues</var>, answering
/// <code>{Namespace, Target}</code> with <var>pId</var> as the target as the caller named it. An unexpected raise is the internal fault, and an error
/// status the instance answers is 409 <code>SQL.TABLE.VENDOR</code>, with the reason <parameter>OcuPilot.Api.AtelierError.REASONTABLESETUNAPPLIED</parameter>
/// and <code>detail.statisticsFixed</code> where the table's collected statistics were saved as its fixed ones first.</p>
ClassMethod TableWritten(pNamespace As %String, pType As %String, pTarget As %String, pValues As %String, pId As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pAnswer = ""
    Set tSC = ..TableApplied(pNamespace, pType, pTarget, pValues, .tStatus, .tFixed)
    If $$$ISERR(tSC) Quit ..Fail("a table write failed", tSC, .pHttpStatus, .pFault)
    If $$$ISERR(tStatus) {
        Set tDetail = {}
        Do tDetail.%Set("message", $System.Status.GetErrorText(tStatus), "string")
        If tFixed Do tDetail.%Set("statisticsFixed", 1, "boolean")
        Set tReason = $Select(tFixed: ##class(OcuPilot.Api.AtelierError).#REASONTABLESETUNAPPLIED, 1: ##class(OcuPilot.Api.AtelierError).#REASONTABLEVENDOR)
        Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.AtelierError).#TABLEVENDOR, tReason, .pHttpStatus, .pFault, tDetail)
    }
    Set pAnswer = {}
    Do pAnswer.%Set("Namespace", pNamespace, "string")
    Do pAnswer.%Set("Target", pId, "string")
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The one vendor call of table write <var>pType</var>, in <var>pNamespace</var>, as its status: <code>RebuildIndices</code> of the class
/// <var>pTarget</var> with the one index <var>pValues</var> names for <parameter>TYPEREBUILD</parameter>, and with none, which rebuilds every index,
/// for <parameter>TYPEREBUILDALL</parameter>. The call purges each index and holds the table's extent lock while it builds. The tunes take the
/// table as <code>Schema.Table</code> and the schema by its name, spelled as the instance holds them and not quoted, as the classic page passes them
/// (the instance refuses a quoted schema name): <parameter>TYPETUNE</parameter> is <code>TuneTable</code> over
/// <var>pTarget</var>, display off, no log file, the class definition left as it is and fixed values kept; <parameter>TYPECLEARSTATS</parameter> is
/// <code>ClearTableStats</code>; <parameter>TYPETUNESCHEMA</parameter> is <code>TuneSchema</code> over the schema, with <var>pValues</var>
/// <code>1</code> or <code>0</code> for whether the fixed values are cleared. A message the tune answers is its error status. A call that
/// answers no status is <code>$$$OK</code>. The namespace is switched by save and restore around the vendor call alone, restored first when it throws, and
/// the throw is passed on. Overridable so a fixture can feed an error status; production overrides none.</p>
/// <p>The setters (<parameter>TYPESETEXTENT</parameter>, <parameter>TYPESETSELECTIVITY</parameter>, <parameter>TYPESETMAPSIZE</parameter>) take
/// <var>pTarget</var> as <code>Schema.Table</code> and <var>pValues</var> as the JSON <method>TableWrite</method> built, and make the vendor call of
/// <method>SettingCall</method> with the class kept as it is. <var>pFixed</var> is 1 when the table's collected statistics were saved as its fixed
/// ones before a setter ran, so a setter that then fails can say so.</p>
ClassMethod TableCall(pType As %String, pTarget As %String, pValues As %String, pNamespace As %String, Output pFixed As %Boolean) As %Status
{
    Set pFixed = 0
    Set tStatus = $$$ERROR($$$GeneralError, "no table call for " _ pType)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Kill tMessage
        If (pType = ..#TYPESETEXTENT) || (pType = ..#TYPESETSELECTIVITY) || (pType = ..#TYPESETMAPSIZE) {
            Set tStatus = ..SettingCall(pType, pTarget, pValues, .pFixed)
        } ElseIf pType = ..#TYPEREBUILD {
            Set tStatus = ##class(%SQL.Manager.API).RebuildIndices(pTarget, $ListBuild(pValues))
        } ElseIf pType = ..#TYPEREBUILDALL {
            Set tStatus = ##class(%SQL.Manager.API).RebuildIndices(pTarget, "")
        } ElseIf pType = ..#TYPETUNE {
            Do ##class(%SYSTEM.SQL).TuneTable(pTarget, 1, 0, .tMessage, 0, 0, "")
            Set tStatus = ..MessageStatus(.tMessage)
        } ElseIf pType = ..#TYPECLEARSTATS {
            Set tStatus = ##class(%SYSTEM.SQL.Stats.Table).ClearTableStats(pTarget)
        } ElseIf pType = ..#TYPETUNESCHEMA {
            Do ##class(%SYSTEM.SQL).TuneSchema(pTarget, 1, 0, .tMessage, 0, +pValues, "")
            Set tStatus = ..MessageStatus(.tMessage)
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Throw ex
    }
    Quit tStatus
}

/// <p>The vendor calls of setter <var>pType</var> over table <var>pTarget</var> (<code>Schema.Table</code>, split at its first <code>.</code>: the
/// instance refuses a delimited name that holds one), in the current namespace, with the JSON <var>pValues</var> carries (<method>TableWrite</method>).
/// When <code>StatsKind</code> is <code>collected</code>, the table's collected statistics are first saved as its fixed ones
/// (<code>FixTableStats</code>), as the classic page does, so the values the setter leaves alone keep what was measured; <var>pFixed</var> is then 1
/// and a setter that raises is its error status. Then the setter, the class kept as it is: <code>SetTableExtentSize</code> over
/// <code>ExtentSize</code>; <code>SetMapBlockCount</code> over <code>Map</code> and <code>SizeMB</code> in blocks
/// (<parameter>BLOCKSPERMB</parameter> to the MB); <code>SetFieldSelectivity</code> over <code>Field</code>, <code>Selectivity</code> and the outlier
/// selectivity, outlier value and average size, each one not declared being the field's fixed value as it reads after the save and just before the
/// call (<method>FieldRead</method>), since the instance clears one it is not given. A fixed outlier value is passed back exactly as the instance holds
/// it; one that was sent is plain data and is handed over as <method>OutlierExpression</method> builds it. A fixed outlier selectivity or average size that
/// is not a number (with a percent sign, for the selectivity) is not passed back.</p>
ClassMethod SettingCall(pType As %String, pTarget As %String, pValues As %String, Output pFixed As %Boolean) As %Status [ Private ]
{
    Set pFixed = 0
    Set tValues = ##class(%DynamicObject).%FromJSON(pValues)
    Set tSchema = $Piece(pTarget, ".", 1)
    Set tTable = $Piece(pTarget, ".", 2, *)
    If tValues.%Get("StatsKind") = "collected" {
        Set tStatus = ##class(%SYSTEM.SQL.Stats.Table).FixTableStats(pTarget)
        If $$$ISERR(tStatus) Quit tStatus
        Set pFixed = 1
    }
    Set tStatus = $$$OK
    Try {
        If pType = ..#TYPESETEXTENT {
            Set tStatus = ##class(%SQL.Manager.Catalog).SetTableExtentSize(tSchema, tTable, tValues.%Get(..#EXTENTSIZEKEY), 0)
        } ElseIf pType = ..#TYPESETMAPSIZE {
            Set tStatus = ##class(%SQL.Manager.Catalog).SetMapBlockCount(tSchema, tTable, tValues.%Get("Map"), tValues.%Get(..#SIZEMBKEY) * ..#BLOCKSPERMB, 0)
        } Else {
            Set tField = tValues.%Get("Field")
            Set tStatus = ..FieldRead(tSchema, tTable, tField, .tRow)
            If $$$ISERR(tStatus) Quit
            Set tOutlierSelectivity = tValues.%Get(..#OUTLIERSELECTIVITYKEY)
            If tOutlierSelectivity = "" {
                Set tOutlierSelectivity = tRow.%Get("FixedOutlierSelectivity")
                If '$Match(tOutlierSelectivity, "^[0-9]*\.?[0-9]+%?$") Set tOutlierSelectivity = ""
            }
            Set tOutlierValue = tValues.%Get(..#OUTLIERVALUEKEY)
            Set tOutlierValue = $Select(tOutlierValue = "": tRow.%Get("FixedOutlierValue"), 1: ..OutlierExpression(tOutlierValue))
            Set tAverage = tValues.%Get(..#AVERAGESIZEKEY)
            If tAverage = "" {
                Set tAverage = tRow.%Get("FixedAverageFieldSize")
                If '$Match(tAverage, "^[0-9]*\.?[0-9]+$") Set tAverage = ""
            }
            Set tStatus = ##class(%SQL.Manager.Catalog).SetFieldSelectivity(tSchema, tTable, tField, tValues.%Get(..#SELECTIVITYKEY), 0, tOutlierSelectivity, tOutlierValue, tAverage)
        }
    } Catch ex {
        If 'pFixed Throw ex
        Set tStatus = ex.AsStatus()
    }
    Quit tStatus
}

/// <p>The error status of the message a tune answered in <var>pMessage</var>, its text and the text of each of its subscripts, or
/// <code>$$$OK</code> when it holds none. A message of <code>0</code> or <code>""</code> is none.</p>
ClassMethod MessageStatus(ByRef pMessage) As %Status [ Private ]
{
    Set tText = ""
    If $Get(pMessage) '= "" && ($Get(pMessage) '= 0) Set tText = pMessage
    Set tKey = ""
    For {
        Set tKey = $Order(pMessage(tKey))
        If tKey = "" Quit
        If $Get(pMessage(tKey)) '= "" Set tText = tText _ $Select(tText = "": "", 1: " ") _ pMessage(tKey)
    }
    If tText = "" Quit $$$OK
    Quit $$$ERROR($$$GeneralError, tText)
}

/// <p><method>TableCall</method> answering its own status as <var>pStatus</var>, and whether it saved the table's collected statistics as its fixed
/// ones as <var>pFixed</var>; the returned status is an unexpected failure.</p>
ClassMethod TableApplied(pNamespace As %String, pType As %String, pTarget As %String, pValues As %String, Output pStatus As %Status, Output pFixed As %Boolean) As %Status [ Private ]
{
    Set pStatus = $$$OK
    Set pFixed = 0
    Set tSC = $$$OK
    Try {
        Set pStatus = ..TableCall(pType, pTarget, pValues, pNamespace, .pFixed)
    } Catch ex {
        Set tSC = $$$ERROR($$$GeneralError, "the write raised " _ ex.Name)
    }
    Quit tSC
}

/// <p>The table write <var>pType</var> as a script (AD-59) in the namespace <code>namespace</code> names: the one vendor call, the table's class found
/// from its SQL name and, for one index, the name the instance builds it by read from the table's indices list as <method>TableFacts</method> reads
/// it, each name shown as a string literal, so nothing the query carries runs as code.</p>
ClassMethod TableSnippet(pType As %String, ByRef pQuery) As %DynamicArray [ Private ]
{
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite($Get(pQuery(..#IDKEY)))
    Set tTable = $ListGet(tParts, 1)
    Set tText = " Set $NAMESPACE = " _ ..Literal($Get(pQuery(..#NAMESPACEKEY)))
    Set tClear = $Select($Get(pQuery(..#CLEARVALUESKEY)) = "true": 1, 1: 0)
    If (pType = ..#TYPESETEXTENT) || (pType = ..#TYPESETSELECTIVITY) || (pType = ..#TYPESETMAPSIZE) Quit ..SettingSnippet(pType, .pQuery, tText, tTable, $ListGet(tParts, 2))
    If pType = ..#TYPETUNE {
        Set tText = tText _ $Char(10) _ " Do $SYSTEM.SQL.TuneTable(" _ ..Literal($Get(pQuery(..#IDKEY))) _ ", 1, 0, .tMessage, 0, 0)"
        Set tText = tText _ $Char(10) _ " If $Data(tMessage) ZWrite tMessage"
        Quit ..SnippetSteps(tText)
    }
    If pType = ..#TYPECLEARSTATS {
        Set tText = tText _ $Char(10) _ " Set tSC = $SYSTEM.SQL.Stats.Table.ClearTableStats(" _ ..Literal($Get(pQuery(..#IDKEY))) _ ")"
        Set tText = tText _ $Char(10) _ " If $System.Status.IsError(tSC) Do $System.Status.DisplayError(tSC)"
        Quit ..SnippetSteps(tText)
    }
    If pType = ..#TYPETUNESCHEMA {
        Set tText = tText _ $Char(10) _ " Do $SYSTEM.SQL.TuneSchema(" _ ..Literal($Get(pQuery(..#IDKEY))) _ ", 1, 0, .tMessage, 0, " _ tClear _ ")"
        Set tText = tText _ $Char(10) _ " If $Data(tMessage) ZWrite tMessage"
        Quit ..SnippetSteps(tText)
    }
    Set tText = tText _ $Char(10) _ " Set tClass = ##class(%SQL.Manager.API).FindClassName(" _ ..Literal(tTable) _ ")"
    If pType = ..#TYPEREBUILD {
        Set tText = tText _ $Char(10) _ " Set tStatement = ##class(%SQL.Statement).%New()"
        Set tText = tText _ $Char(10) _ " Set tSC = tStatement.%PrepareClassQuery(""%SQL.Manager.Catalog"", ""Indices"")"
        Set tText = tText _ $Char(10) _ " Set tResult = tStatement.%Execute(" _ ..Literal($Piece(tTable, ".", 1)) _ ", " _ ..Literal($Piece(tTable, ".", 2, *)) _ ")"
        Set tText = tText _ $Char(10) _ " Set tIndex = """""
        Set tText = tText _ $Char(10) _ " While tResult.%Next() { If tResult.%Get(""SQL_MAP_NAME"") = " _ ..Literal($ListGet(tParts, 2)) _ " { Set tIndex = tResult.%Get(""BI_ARGUMENT"") Quit } }"
        Set tIndices = "$ListBuild(tIndex)"
    } Else {
        Set tIndices = """"""
    }
    Set tText = tText _ $Char(10) _ " Set tSC = ##class(%SQL.Manager.API).RebuildIndices(tClass, " _ tIndices _ ")"
    Set tText = tText _ $Char(10) _ " If $System.Status.IsError(tSC) Do $System.Status.DisplayError(tSC)"
    Quit ..SnippetSteps(tText)
}

/// <p>Setter <var>pType</var> as a script (AD-59) over table <var>pTable</var> (<code>Schema.Table</code>) and <var>pSecond</var>, the map or field its composite
/// id names, after the namespace line <var>pHead</var>: the save of the table's collected statistics as its fixed ones where it has collected statistics
/// and no fixed ones, then the setter's one vendor call, made only when the save did not fail, with the declared values (<method>SetValues</method>), the
/// class kept as it is, and for a selectivity, the field's fixed outlier selectivity, outlier value and average size read first for each one not
/// declared. Each name and value is shown as a string literal; an outlier value is shown as the expression <method>OutlierExpression</method> builds.</p>
ClassMethod SettingSnippet(pType As %String, ByRef pQuery, pHead As %String, pTable As %String, pSecond As %String) As %DynamicArray [ Private ]
{
    Set tSchema = ..Literal($Piece(pTable, ".", 1))
    Set tName = ..Literal($Piece(pTable, ".", 2, *))
    Set tText = pHead
    Set tText = tText _ $Char(10) _ " Do ##class(%SQL.Manager.Catalog).DisplayExtentDBStats(" _ tSchema _ ", " _ tName _ ", .tStatClass, .tStat, .tStatId)"
    Set tText = tText _ $Char(10) _ " Set tSC = 1"
    Set tText = tText _ $Char(10) _ " If '##class(%SQL.Manager.Catalog).HasFixedStats(" _ tSchema _ ", " _ tName _ ") && $IsObject($Get(tStat)) Set tSC = $SYSTEM.SQL.Stats.Table.FixTableStats(" _ ..Literal(pTable) _ ")"
    If pType = ..#TYPESETEXTENT {
        Set tCall = "SetTableExtentSize(" _ tSchema _ ", " _ tName _ ", " _ ..Literal($Get(pQuery(..#EXTENTSIZEKEY))) _ ", 0)"
    } ElseIf pType = ..#TYPESETMAPSIZE {
        Set tCall = "SetMapBlockCount(" _ tSchema _ ", " _ tName _ ", " _ ..Literal(pSecond) _ ", " _ ..Literal($Get(pQuery(..#SIZEMBKEY))) _ " * " _ ..#BLOCKSPERMB _ ", 0)"
    } Else {
        Set tText = tText _ $Char(10) _ " Set tStatement = ##class(%SQL.Statement).%New()"
        Set tText = tText _ $Char(10) _ " Set tPrepared = tStatement.%Prepare(" _ ..Literal("SELECT OUTLIER_SELECTIVITY, OUTLIER_VALUE, AVERAGE_FIELD_SIZE FROM %SQL_Manager.FieldCurrentSelectivity(?, ?) WHERE FIELD_NAME = ?") _ ")"
        Set tText = tText _ $Char(10) _ " Set tResult = tStatement.%Execute(" _ tSchema _ ", " _ tName _ ", " _ ..Literal(pSecond) _ ")"
        Set tText = tText _ $Char(10) _ " Set tOutlierSelectivity = """", tOutlierValue = """", tAverage = """""
        Set tText = tText _ $Char(10) _ " If tResult.%Next() Set tOutlierSelectivity = tResult.%GetData(1), tOutlierValue = tResult.%GetData(2), tAverage = tResult.%GetData(3)"
        Set tText = tText _ $Char(10) _ " If tOutlierValue = " _ ..Literal(..#NULLOUTLIER) _ " Set tOutlierValue = """""
        Set tOutlierSelectivity = $Get(pQuery(..#OUTLIERSELECTIVITYKEY))
        Set tOutlierValue = $Get(pQuery(..#OUTLIERVALUEKEY))
        Set tAverage = $Get(pQuery(..#AVERAGESIZEKEY))
        Set tCall = "SetFieldSelectivity(" _ tSchema _ ", " _ tName _ ", " _ ..Literal(pSecond) _ ", " _ ..Literal(..PercentText($Get(pQuery(..#SELECTIVITYKEY)), 1)) _ ", 0, "
        Set tCall = tCall _ $Select(tOutlierSelectivity = "": "tOutlierSelectivity", 1: ..Literal(..PercentText(tOutlierSelectivity, 0))) _ ", "
        Set tCall = tCall _ $Select(tOutlierValue = "": "tOutlierValue", 1: ..Literal(..OutlierExpression(tOutlierValue))) _ ", "
        Set tCall = tCall _ $Select(tAverage = "": "tAverage", 1: ..Literal(tAverage)) _ ")"
    }
    Set tText = tText _ $Char(10) _ " If $System.Status.IsOK(tSC) Set tSC = ##class(%SQL.Manager.Catalog)." _ tCall
    Set tText = tText _ $Char(10) _ " If $System.Status.IsError(tSC) Do $System.Status.DisplayError(tSC)"
    Quit ..SnippetSteps(tText)
}

/// <p>The one <code>objectscript</code> step whose text is <var>pText</var>.</p>
ClassMethod SnippetSteps(pText As %String) As %DynamicArray [ Private ]
{
    Set tStep = {}
    Do tStep.%Set("kind", "objectscript", "string")
    Do tStep.%Set("text", pText, "string")
    Quit [(tStep)]
}

/// <p>The tuning write <var>pType</var> as a script (AD-59) in the namespace <code>namespace</code> names: the one vendor call, with
/// the target <code>id</code> names as its argument, each shown as a string literal, so nothing the query carries runs as code.</p>
ClassMethod TuningSnippet(pType As %String, ByRef pQuery) As %DynamicArray [ Private ]
{
    Set tId = $Get(pQuery(..#IDKEY))
    If pType = ..#TYPEPURGEQUERIES {
        Set tQualifiers = $Select(tId = ..#ALLID: "{}", $Extract(tId, 1, $Length(..#CACHEDQUERYPREFIX)) = ..#CACHEDQUERYPREFIX: "{""class"": [" _ ..Literal(tId) _ "]}", 1: "{""table"": [" _ ..Literal(tId) _ "]}")
        Set tCall = " Set tSC = $SYSTEM.SQL.PurgeQueries(" _ tQualifiers _ ")"
    } ElseIf pType = ..#TYPEFREEZE {
        Set tCall = " Set tSC = $SYSTEM.SQL.Statement.FreezeStatement(" _ ..Literal(tId) _ ")"
    } ElseIf pType = ..#TYPEUNFREEZE {
        Set tCall = " Set tSC = $SYSTEM.SQL.Statement.UnfreezeStatement(" _ ..Literal(tId) _ ")"
    } ElseIf pType = ..#TYPECLEARSTATISTICS {
        Set tCall = " Set tSC = $SYSTEM.SQL.Statement.ClearStatement(" _ ..Literal(tId) _ ")"
    } ElseIf pType = ..#TYPECLEARERROR {
        Set tCall = " Do UpdateSQLIndex^%SYS.SQLSRV(" _ ..Literal(tId) _ ", """")"
    } ElseIf pType = ..#TYPEPURGESTATS {
        Set tCall = " Set tRemoved = ##class(" _ ..#STATSCLASS _ ").clearStatsSQL(" _ ..Literal($Get(pQuery(..#NAMESPACEKEY))) _ ", """", 0, 1, 0, 1)" _ $Char(10) _ " If '$Match(tRemoved, ""^[0-9]+$"") Do $System.Status.DisplayError(tRemoved)"
    } Else {
        Set tCall = " Do $SYSTEM.SQL.Statement.Clean()"
    }
    Set tText = " Set $NAMESPACE = " _ ..Literal($Get(pQuery(..#NAMESPACEKEY))) _ $Char(10) _ tCall
    If tCall [ "Set tSC" Set tText = tText _ $Char(10) _ " If $System.Status.IsError(tSC) Do $System.Status.DisplayError(tSC)"
    Set tStep = {}
    Do tStep.%Set("kind", "objectscript", "string")
    Do tStep.%Set("text", tText, "string")
    Quit [(tStep)]
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
    If (pEndpoint = ..#ENDPOINTSTATEMENTS) && $ListFind($ListFromString(..#STATEMENTWRITES), pType) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTCACHEDQUERIES) && (pType = ..#TYPEPURGEQUERIES) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTRUNTIMESTATS) && (pType = ..#TYPEPURGESTATS) Quit "objectscript"
    If (pEndpoint = ..#ENDPOINTTABLES) && $ListFind($ListFromString(..#TABLEWRITES), pType) Quit "objectscript"
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
    If (pEndpoint = ..#ENDPOINTSTATEMENTS) || (pEndpoint = ..#ENDPOINTCACHEDQUERIES) || (pEndpoint = ..#ENDPOINTRUNTIMESTATS) Quit ..TuningSnippet(pType, .pQuery)
    If pEndpoint = ..#ENDPOINTTABLES Quit ..TableSnippet(pType, .pQuery)
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
/// <code>PORT.VALIDATION</code>. With <var>pWrite</var>, the pair set is
/// <method>OcuPilot.Port.AtelierPort.WritePairs</method>: WRITE on the namespace's routines database beside the reads.</p>
ClassMethod Gate(pNamespace As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pWrite As %Boolean = 0) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tFailedPair = ""
    If '$ClassMethod(..GateClass(), "EvaluateRequired", ##class(OcuPilot.Port.AtelierPort).Pairs(), .tFailedPair) Quit ..Deny(tFailedPair, .pHttpStatus, .pFault)
    If '$Match(pNamespace, ##class(OcuPilot.Port.AtelierPort).#NAMESPACEPATTERN) {
        Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, ##class(OcuPilot.Port.AtelierPort).#REASONNAMESPACESHAPE, .pHttpStatus, .pFault)
    }
    Set tPairs = $Select(pWrite: ##class(OcuPilot.Port.AtelierPort).WritePairs(pNamespace), 1: ##class(OcuPilot.Port.AtelierPort).NamespacePairs(pNamespace))
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
                Do ..FetchRows(tSet, tColumns, pMaxRows, .tRows, .tTruncated, .tMore, .tCut)
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
