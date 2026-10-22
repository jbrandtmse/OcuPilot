/// <p>The agent's MDX read (Story 20.35, AD-7, AD-24, AD-36, AD-39, AD-60, AD-65): one MDX statement run in
/// the turn's namespace as the signed-in user, answered as the cells of a SELECT or as a drill-through's
/// listing. It is a read tool with a class of its own, bound to MDX query
/// (<class>OcuPilot.Screen.Descriptor.AnalyticsMdxQuery</class>): MDX query's run is the person's own
/// tool and its answer never reaches the model, while this read never executes code.</p>
/// <p><b>The order is fixed</b>, and the vendor is first called by the prepare, after: the argument schema,
/// <code>drill</code>'s keys and bounds (<method>DrillProblem</method>); MDX query's pairs through <method>OcuPilot.Screen.Gate.Evaluate</method>, an
/// adjustment and the classic page's custom resource included; <method>OcuPilot.Port.AnalyticsPort.MdxAdmit</method>
/// in the turn's namespace; and <method>OcuPilot.Port.AnalyticsPort.MdxConstructs</method> on the statement. The
/// prepare (<method>OcuPilot.Port.AnalyticsPort.MdxPrepare</method>) then makes the port's kind and axes refusals, and
/// its <code>ask</code> on the variable-resolved text is read here. A statement in which the
/// detector finds <code>%SEARCH</code>, <code>%SQLRESTRICT</code>, <code>RETURN</code>,
/// <code>%ORDER</code> or <code>%PARM</code>, or which it cannot read, is refused 422
/// <code>ANALYTICS.MDX.SQL</code> before it is prepared, and one whose resolved text it refuses is
/// refused after a prepare, which executes nothing, and is never run. Only SELECT with at most two axes,
/// and DRILLTHROUGH, run; no pivot variable is handed to the prepare in production
/// (<method>Variables</method>).</p>
/// <p><b>It runs in the turn job</b> through <method>OcuPilot.Port.AnalyticsPort.MdxRun</method>, under
/// the port's <code>MDX*</code> caps, and reserves no background run. The run polls the vendor and
/// <method>MdxStopRequested</method>, which reads the turn's stop and abandon signals and its lease, and
/// at the time bound or on any of them cancels the vendor's query, waits for it to finish and answers
/// <code>stopped</code>, so nothing is left running.</p>
/// <p><b>What reaches the model</b> (AD-36, AD-60): the namespace, cube, columns, rows, counts,
/// truncation, an error's message cut at the port's cell bound, or a stop's seconds, bounded again by
/// the kernel's row cap and per-reply total (AD-24). A listing column whose name the credential pattern
/// matches reads <code>[redacted]</code>, and a credential value in any other text cell is masked, as the
/// SQL read masks them. The statement is the turn's own argument and reaches no log line. A member name or
/// a cell that holds a secret reaches the model.</p>
Class OcuPilot.Screen.Tool.AnalyticsMdxRead Extends OcuPilot.Screen.Tool.Base
{

Parameter TOOLNAME = "analytics.mdxquery.read";

Parameter KIND = "read";

Parameter DESCRIPTION = "Run one MDX query in the namespace this turn is scoped to, as the signed-in user, and read its cells, or with drill, one cell's listing. Send one SELECT (columns and rows at most) or DRILLTHROUGH; find cubes with analytics.cubes.read. Text that runs server-side code or SQL (%SEARCH, %SQLRESTRICT, RETURN, %ORDER, %PARM), or that cannot be read as MDX, is refused: ask the person to run it on MDX query. Listing columns named like a credential read [redacted].";

/// <p>The screen whose pairs this tool requires and whose context lists it.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsMdxQuery";

/// <p>The port that detects, prepares and runs the statement. Overridable so a fixture can observe what
/// reaches it; production never overrides it.</p>
Parameter PORTCLASS = "OcuPilot.Port.AnalyticsPort";

/// <p>The statement, and one cell of its answer to drill into. The statement carries the screen's bound
/// (<parameter>OcuPilot.Port.AnalyticsPort.MDXMAXSTATEMENT</parameter>). <code>drill</code> is a bare object, because an advertised
/// schema admits no nested properties (<parameter>OcuPilot.Screen.Tool.Registry.EMITTEDKEYWORDS</parameter>): its keys and bounds
/// (<parameter>OcuPilot.Port.AnalyticsPort.MDXMAXROWS</parameter> and <parameter>MDXMAXCOLUMNS</parameter>) are <method>DrillProblem</method>'s
/// to check, and its description says them.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tPort = ..#PORTCLASS
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set("statement", {"type": "string", "maxLength": ($Parameter(tPort, "MDXMAXSTATEMENT")), "description": "One MDX statement, a SELECT with at most two axes or a DRILLTHROUGH, up to 100,000 characters."})
    Do tSchema.%Get("required").%Push("statement")
    Do tProperties.%Set("drill", {"type": "object", "description": ("Read the listing behind one cell of the SELECT's answer instead of its cells: an object with exactly two whole numbers, row (1 to " _ $Parameter(tPort, "MDXMAXROWS") _ ", counted in the answer's rows) and column (1 to " _ $Parameter(tPort, "MDXMAXCOLUMNS") _ ", counted among the column labels after the empty label column). Not for a DRILLTHROUGH statement.")})
    Quit tSchema
}

/// <p>What is wrong with the <code>drill</code> object <var>pDrill</var>, or <code>""</code>: it holds exactly <code>row</code> and
/// <code>column</code>, each a whole number from 1 to the port's row or column cap.</p>
ClassMethod DrillProblem(pDrill As %DynamicObject) As %String
{
    Set tPort = ..#PORTCLASS
    Set tProblem = ""
    Set tIterator = pDrill.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If '$ListFind($ListBuild("row", "column"), tKey) {
            Set tProblem = "argument 'drill." _ tKey _ "' is not a declared property (additionalProperties: false)"
            Quit
        }
    }
    If tProblem '= "" Quit tProblem
    For tPosition = $ListBuild("row", "MDXMAXROWS"), $ListBuild("column", "MDXMAXCOLUMNS") {
        Set tName = $List(tPosition, 1)
        Set tMax = $Parameter(tPort, $List(tPosition, 2))
        If pDrill.%GetTypeOf(tName) = "unassigned" {
            Set tProblem = "argument 'drill." _ tName _ "' is missing (required)"
        } ElseIf (pDrill.%GetTypeOf(tName) '= "number") || (pDrill.%Get(tName) '= (pDrill.%Get(tName) \ 1)) {
            Set tProblem = "argument 'drill." _ tName _ "' must be of type integer (type)"
        } ElseIf pDrill.%Get(tName) < 1 {
            Set tProblem = "argument 'drill." _ tName _ "' is below 1 (minimum)"
        } ElseIf pDrill.%Get(tName) > tMax {
            Set tProblem = "argument 'drill." _ tName _ "' is above " _ tMax _ " (maximum)"
        }
        If tProblem '= "" Quit
    }
    Quit tProblem
}

/// <p>MDX query's own pairs, the classic MDX page's custom resource among them, and nothing beyond them
/// (AD-8, AD-44): the namespace's database pairs are the port's to check.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
}

/// <p>Declared: none (AD-3). The statement is the caller's own MDX, never a secret of OcuPilot's.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p>The result: <code>{namespace, outcome, cube, columns, rows, rowsAvailable, columnsAvailable,
/// truncated}</code> for a <code>cells</code> outcome, <code>{namespace, outcome, columns, rows,
/// truncated, redactedColumns}</code> for a <code>rows</code> one, <code>message</code> for an
/// <code>error</code> one and <code>seconds</code> for a <code>stopped</code> one.</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "namespace": {"type": "string", "description": "The namespace the statement ran in."},
            "outcome": {"type": "string", "enum": ["cells", "rows", "error", "stopped"], "description": "cells: a SELECT ran. rows: a listing was read. error: the instance refused or failed the statement, see message. stopped: it ran past its time bound, or the turn was stopped."},
            "cube": {"type": "string", "description": "The cube the SELECT ran over, for a cells outcome."},
            "columns": {"type": "array", "items": {"type": "string"}, "description": "For cells, an empty label for the row-label column and then each column's label. For rows, the listing's column names."},
            "rows": {"type": "array", "items": {"type": "array", "items": {"type": "string"}}, "description": "One array of text for each row. For cells, the row's label and then its cells, as the instance computed them, an empty text for an empty cell. For rows, the listing's cells."},
            "rowsAvailable": {"type": "integer", "description": "How many rows the answer holds before this result was bounded."},
            "columnsAvailable": {"type": "integer", "description": "How many columns of cells the answer holds before this result was bounded, the label column not counted, for a cells outcome."},
            "truncated": {"type": "boolean", "description": "True when rows, columns or cells were cut by a cap."},
            "message": {"type": "string", "description": "The instance's message, for an error outcome."},
            "seconds": {"type": "number", "description": "The seconds the statement ran before it was stopped, for a stopped outcome."},
            "redactedColumns": {"type": "array", "items": {"type": "string"}, "description": "The listing columns whose cells read [redacted] because their names look like credentials."},
            "rowsSent": {"type": "integer", "description": "How many rows this result carries."},
            "truncatedFields": {"type": "array", "items": {"type": "string"}, "description": "Field names whose value was shortened in this result, if any."}
        },
        "required": ["namespace", "outcome"],
        "additionalProperties": false
    }
}

/// <p>Run the statement <var>pArgs</var> carries and answer <method>ResultSchema</method>'s object.
/// <var>pContextCap</var> is the row cap the dispatcher applies after this method; it is not read here,
/// because the kernel's bound cuts the rows.</p>
/// <p>Every refusal is an error status with <var>pHttpStatus</var> and <var>pFault</var>: 400
/// <code>TOOL.ARGUMENTS</code>, <code>ANALYTICS.MDX.INPUT</code> (a drill of a
/// DRILLTHROUGH, a drill past the answer's axes), 403 for a missing pair, 409
/// <code>ANALYTICS.NAMESPACE</code> or <code>ANALYTICS.MDX.READONLY</code>, 422
/// <code>ANALYTICS.MDX.KIND</code>, <code>ANALYTICS.MDX.AXES</code> or <code>ANALYTICS.MDX.SQL</code>,
/// and the port's own faults. A statement the instance did not prepare, or failed, is an
/// <code>error</code> outcome with its text, not a fault.</p>
/// <p>Caller contract: not called from an escalated frame (AD-9); the prepare and the run write the
/// vendor's result cache in the namespace's database (AD-7).</p>
ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tRS = ""
    Set tNamespace = ""
    Set tPort = ..#PORTCLASS
    Try {
        Set tArgs = $Select($IsObject(pArgs): pArgs, pArgs = "": {}, 1: pArgs)
        Set tValidSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(..InputSchema(), tArgs, .tProblem)
        If $$$ISERR(tValidSC) {
            Set tSC = ..ArgumentsRefusal(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        If tArgs.%GetTypeOf("drill") = "object" {
            Set tDrillProblem = ..DrillProblem(tArgs.%Get("drill"))
            If tDrillProblem '= "" {
                Set tSC = ..ArgumentsRefusal(tDrillProblem, .pHttpStatus, .pFault)
                Quit
            }
        }
        Set tStatement = tArgs.%Get("statement")
        Set tFailedPair = ""
        If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
            Set pHttpStatus = ##class(OcuPilot.Kernel.Denial).#STATUS
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason())
            Do pFault.%Set("detail", ##class(OcuPilot.Kernel.Denial).Detail(tFailedPair))
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Kernel.Denial).Code())
            Quit
        }

        Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        Set tAdmitSC = $ClassMethod(tPort, "MdxAdmit", tNamespace, .pHttpStatus, .pFault)
        If $$$ISERR(tAdmitSC) {
            Set tSC = tAdmitSC
            Quit
        }
        If $ClassMethod(tPort, "MdxConstructs", tStatement, .tFound, .tUnread) {
            Set tSC = $ClassMethod(tPort, "RefuseFor", "sql", .pHttpStatus, .pFault)
            Quit
        }
        Do ..Variables(.tVariables)
        Set tPrepareSC = $ClassMethod(tPort, "MdxPrepare", tNamespace, tStatement, .tRS, .tAnswer, .pHttpStatus, .pFault, .tAsk, .tFoundResolved, .tVariables)
        If $$$ISERR(tPrepareSC) {
            Set tSC = tPrepareSC
            Quit
        }
        If $IsObject($Get(tAnswer)) {
            Set pResult = ..Projected(tNamespace, tAnswer)
            Set pHttpStatus = 200
            Set pFault = ""
            Quit
        }
        If tAsk {
            Set tSC = $ClassMethod(tPort, "RefuseFor", "sql", .pHttpStatus, .pFault)
            Quit
        }
        Set tDrillRow = ""
        Set tDrillColumn = ""
        If tArgs.%GetTypeOf("drill") = "object" {
            If $ClassMethod(tPort, "MdxKind", tRS) '= "SELECT" {
                Set tSC = $ClassMethod(tPort, "RefuseFor", "input", .pHttpStatus, .pFault)
                Quit
            }
            Set tDrillRow = tArgs.%Get("drill").%Get("row")
            Set tDrillColumn = tArgs.%Get("drill").%Get("column")
        }

        Set tRunSC = $ClassMethod(tPort, "MdxRun", tNamespace, tRS, tDrillRow, tDrillColumn, ..BoundSeconds(), $ClassName(), ##class(OcuPilot.Kernel.Proposal.Caller).TurnKey(), .tRunAnswer, .tStopped, .pHttpStatus, .pFault)
        If $$$ISERR(tRunSC) {
            Set tSC = tRunSC
            Quit
        }
        Set pResult = ..Projected(tNamespace, tRunAnswer)
        Set pHttpStatus = 200
        Set pFault = ""
    } Catch ex {
        Set pResult = ""
        Set tSC = ..InternalRefusal("the MDX read tool failed: " _ ex.Name, .pHttpStatus, .pFault)
    }
    If $IsObject(tRS) Do $ClassMethod(tPort, "MdxRelease", tNamespace, .tRS)
    Quit tSC
}

/// <p>The seconds a run is bounded to: the port's <parameter>OcuPilot.Port.AnalyticsPort.MDXSECONDS</parameter>. A fixture subclass
/// overrides it; production never does.</p>
ClassMethod BoundSeconds() As %Numeric
{
    Quit $Parameter(..#PORTCLASS, "MDXSECONDS")
}

/// <p>The pivot variables <method>OcuPilot.Port.AnalyticsPort.MdxPrepare</method> resolves
/// <code>$variable.&lt;name&gt;</code> from, as an array subscripted by name. Production hands none, so each
/// resolves to an empty text. A fixture subclass overrides it; production never does.</p>
ClassMethod Variables(Output pVariables)
{
    Kill pVariables
}

/// <p>Whether the turn <var>pKey</var> asks its MDX read to stop: its stop or abandon signal is set, or its
/// lease is at least <parameter>OcuPilot.Kernel.Agent.Limits.LEASESECONDS</parameter> old or was never renewed,
/// as <method>OcuPilot.Kernel.Agent.Loop.Boundary</method> reads them between steps; a signal that cannot be
/// read asks too. 0 for an empty key, a call made outside a turn. It is the stop hook
/// <method>OcuPilot.Port.AnalyticsPort.MdxRun</method> asks.</p>
ClassMethod MdxStopRequested(pKey As %String) As %Boolean
{
    If pKey = "" Quit 0
    Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedSignals(pKey, .tStop, .tAbandon, .tRenewedAt)
    If $$$ISERR(tSC) Quit 1
    If tStop || tAbandon Quit 1
    If tRenewedAt = "" Quit 1
    Quit (##class(OcuPilot.Kernel.State.Turn).NowSeconds() - tRenewedAt) >= ##class(OcuPilot.Kernel.Agent.Limits).#LEASESECONDS
}

/// <p>The tool's answer from the run's answer <var>pAnswer</var>, in <var>pNamespace</var>. A
/// <code>cells</code> answer gives <code>columns</code> as an empty label and then the column labels, and
/// each row as its label and then its cells as text, with one row labeled <code>""</code> when the statement
/// has no rows axis. A <code>rows</code> answer gives the listing's columns and rows with the cells of each
/// credential-named column masked and those columns listed in <code>redactedColumns</code>
/// (<method>OcuPilot.Screen.Tool.ExplorerSqlRead.RedactedColumns</method> and
/// <method>OcuPilot.Screen.Tool.ExplorerSqlRead.MaskedRows</method>). An <code>error</code> answer passes its
/// message, and a <code>stopped</code> one its seconds. The run's own seconds are left out.</p>
ClassMethod Projected(pNamespace As %String, pAnswer As %DynamicObject) As %DynamicObject
{
    Set tResult = {}
    Set tOutcome = pAnswer.%Get("outcome")
    Do tResult.%Set("namespace", pNamespace, "string")
    Do tResult.%Set("outcome", tOutcome, "string")
    If tOutcome = "error" {
        Do tResult.%Set("message", pAnswer.%Get("message"), "string")
        Quit tResult
    }
    If tOutcome = "stopped" {
        Do tResult.%Set("seconds", pAnswer.%Get("seconds"), "number")
        Quit tResult
    }
    If tOutcome = "cells" {
        Do tResult.%Set("cube", pAnswer.%Get("cube"), "string")
        Set tColumns = []
        Do tColumns.%Push("", "string")
        Set tHeaders = pAnswer.%Get("columns").%GetIterator()
        While tHeaders.%GetNext(.tIndex, .tHeader) {
            Do tColumns.%Push(tHeader, "string")
        }
        Do tResult.%Set("columns", tColumns)
        Set tRows = []
        Set tRowIterator = pAnswer.%Get("rows").%GetIterator()
        While tRowIterator.%GetNext(.tRowIndex, .tRow) {
            Set tLine = []
            Do tLine.%Push(tRow.%Get("label"), "string")
            Set tCells = tRow.%Get("cells").%GetIterator()
            While tCells.%GetNext(.tCellIndex, .tCell) {
                Do tLine.%Push(tCell, "string")
            }
            Do tRows.%Push(tLine)
        }
        Do tResult.%Set("rows", tRows)
        Do tResult.%Set("rowsAvailable", pAnswer.%Get("rowsAvailable"), "number")
        Do tResult.%Set("columnsAvailable", pAnswer.%Get("columnsAvailable"), "number")
        Do tResult.%Set("truncated", ''pAnswer.%Get("truncated"), "boolean")
        Quit tResult
    }
    Set tListed = pAnswer.%Get("columns")
    Set tRedacted = ##class(OcuPilot.Screen.Tool.ExplorerSqlRead).RedactedColumns(tListed, .tMasked)
    Do tResult.%Set("columns", tListed)
    Do tResult.%Set("rows", ##class(OcuPilot.Screen.Tool.ExplorerSqlRead).MaskedRows(pAnswer.%Get("rows"), tMasked))
    Do tResult.%Set("truncated", ''pAnswer.%Get("truncated"), "boolean")
    Do tResult.%Set("redactedColumns", tRedacted)
    Quit tResult
}

}
