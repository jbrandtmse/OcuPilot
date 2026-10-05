/// <p>The agent's SQL query (Story 19.11, AD-3, AD-36, AD-61): one statement the instance types as a
/// query, run in the turn's namespace as the signed-in user, answered as columns and rows. It is a
/// read tool with a class of its own (<class>OcuPilot.Screen.Tool.ErrorRead</class> is the other
/// such source): a read answers every caller who holds its pairs and is not asked governance or the
/// restraint verdict, so a statement that changes anything is refused before it runs and is the
/// business of <class>OcuPilot.Screen.Tool.ExplorerSqlRun</class>.</p>
/// <p><b>It runs the console's own checks</b>, in order: the screen's pairs;
/// <method>OcuPilot.Port.SqlPort.InputProblem</method> (400 <code>EXPLORER.SQL.INPUT</code>);
/// <method>OcuPilot.Area.Explorer.SqlConsole.Check</method>, which is the port's classification and
/// then the self-protection set; a statement the instance did not prepare, answered as the
/// <code>error</code> outcome; a kind that changes something (422 <code>EXPLORER.SQL.CHANGES</code>);
/// values that do not number the statement's value positions (422
/// <code>EXPLORER.SQL.PARAMETERS</code>); and then <method>OcuPilot.Port.SqlPort.Run</method> in its
/// <code>query</code> mode, with every value bound. The statement is prepared with SQL privilege
/// checks on and never reaches the Atelier API's query route.</p>
/// <p><b>Its rows reach the model</b> (AD-36), bounded by <code>maxRows</code>, the kernel's row cap
/// and total bound, and the port's 1,000-character cell cut, and passed through the sanitizer like
/// every tool result. Every cell of a column whose name the credential pattern matches reads
/// <code>[redacted]</code>; a secret under another name, an alias or an expression is not caught,
/// because an arbitrary table carries no classification (AD-3). A function the query calls runs as
/// the user and can change state, which the statement's type does not show (AD-21's named
/// limit).</p>
Class OcuPilot.Screen.Tool.ExplorerSqlRead Extends OcuPilot.Screen.Tool.Base
{

Parameter TOOLNAME = "explorer.sqlquery.read";

Parameter KIND = "read";

Parameter DESCRIPTION = "Run one SQL query in the namespace this turn is scoped to, as the signed-in user, and read its columns and rows. Send one SELECT, with a ? where each value goes and the values in parameters; never put a value in the statement text. A statement that changes anything is refused here: propose it with explorer.sqlquery.run. Columns named like a credential read [redacted].";

/// <p>The screen whose pairs this tool requires and whose context lists it.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlQuery";

/// <p>The port that classifies and runs the statement. Overridable so a fixture can observe what
/// reaches it; production never overrides it.</p>
Parameter PORTCLASS = "OcuPilot.Port.SqlPort";

/// <p>The rows a call reads when it names no <code>maxRows</code>.</p>
Parameter DEFAULTROWS As INTEGER = 200;

/// <p>The text a masked cell reads.</p>
Parameter MASK = "[redacted]";

/// <p>The statement, its values and its row cap; the console's own bounds
/// (<method>OcuPilot.Port.SqlPort.InputProblem</method>).</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set("statement", {"type": "string", "description": "One SQL query, 1 to 100,000 characters, with a ? where each value goes."})
    Do tSchema.%Get("required").%Push("statement")
    Do tProperties.%Set("parameters", {"type": "array", "items": {"type": "string"}, "maxItems": 100, "description": "One value for each ? that takes a value, in order, at most 100, each at most 32,767 characters."})
    Do tProperties.%Set("maxRows", {"type": "integer", "minimum": 1, "maximum": 1000, "description": "The most rows to read, from 1 to 1,000. Absent, 200 are read."})
    Quit tSchema
}

/// <p>The screen's own pairs, the classic SQL page's custom resource among them, and nothing beyond
/// them (AD-8, AD-44): the statement's SQL privileges and the namespace's database pairs are the
/// port's to check.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
}

/// <p>Declared: none (AD-3). The statement and its values are the caller's own SQL, never a secret
/// of OcuPilot's.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p>The result: <code>{namespace, kind, statementType, tables, outcome, columns, rows, truncated,
/// redactedColumns}</code> for a statement that ran, with <code>sqlcode</code> and
/// <code>message</code> for an <code>error</code> outcome and <code>seconds</code> for a
/// <code>stopped</code> one.</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "namespace": {"type": "string", "description": "The namespace the statement ran in."},
            "kind": {"type": "string", "description": "The kind the instance typed the statement: query."},
            "statementType": {"type": "integer", "description": "The instance's statement type number."},
            "tables": {"type": "array", "items": {"type": "string"}, "description": "The tables and views the instance records for the statement."},
            "outcome": {"type": "string", "enum": ["rows", "error", "stopped"], "description": "rows: the statement ran. error: the instance refused or failed it, see sqlcode and message. stopped: it ran past its time bound."},
            "columns": {"type": "array", "items": {"type": "string"}, "description": "The result's column names."},
            "rows": {"type": "array", "items": {"type": "array", "items": {"type": "string"}}, "description": "One array of text cells for each row, in column order."},
            "truncated": {"type": "boolean", "description": "True when rows or cells were cut by a cap."},
            "redactedColumns": {"type": "array", "items": {"type": "string"}, "description": "The columns whose cells read [redacted] because their names look like credentials."},
            "sqlcode": {"type": "integer", "description": "The instance's SQLCODE, for an error outcome."},
            "message": {"type": "string", "description": "The instance's message, for an error outcome."},
            "seconds": {"type": "integer", "description": "The time bound the statement ran past, for a stopped outcome."},
            "rowsSent": {"type": "integer", "description": "How many rows this result carries."},
            "rowsAvailable": {"type": "integer", "description": "How many rows the read produced before the result was bounded."},
            "truncatedFields": {"type": "array", "items": {"type": "string"}, "description": "Field names whose value was shortened in this result, if any."}
        },
        "required": ["namespace", "outcome"],
        "additionalProperties": false
    }
}

/// <p>Run the statement <var>pArgs</var> carries and answer <method>ResultSchema</method>'s
/// object. <var>pContextCap</var> is the row cap the dispatcher applies after this method; it is
/// not read here, because the kernel's bound cuts the rows.</p>
/// <p>Every refusal is an error status with <var>pHttpStatus</var> and <var>pFault</var>: 400
/// <code>TOOL.ARGUMENTS</code> or <code>EXPLORER.SQL.INPUT</code>, 403 for a missing pair or the
/// self-protection set, 422 for a kind, a value count or a refused statement group, and the port's
/// own faults. A statement the instance did not prepare, or failed, is an <code>error</code>
/// outcome with its SQLCODE, not a fault.</p>
/// <p>Caller contract: not called from an escalated frame (AD-9); the prepare records the statement
/// in the namespace's statement index (AD-7's fifth shape).</p>
ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tArgs = $Select($IsObject(pArgs): pArgs, pArgs = "": {}, 1: pArgs)
        Set tValidSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(..InputSchema(), tArgs, .tProblem)
        If $$$ISERR(tValidSC) {
            Set tSC = ..ArgumentsRefusal(tProblem, .pHttpStatus, .pFault)
            Quit
        }
        Set tFailedPair = ""
        If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
            Set pHttpStatus = ##class(OcuPilot.Kernel.Denial).#STATUS
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason())
            Do pFault.%Set("detail", ##class(OcuPilot.Kernel.Denial).Detail(tFailedPair))
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Kernel.Denial).Code())
            Quit
        }

        Set tText = tArgs.%Get("statement")
        Set tValues = $Select(tArgs.%GetTypeOf("parameters") = "array": tArgs.%Get("parameters"), 1: [])
        Set tMaxRows = $Select(tArgs.%GetTypeOf("maxRows") = "number": tArgs.%Get("maxRows"), 1: ..#DEFAULTROWS)
        Set tPort = ..#PORTCLASS
        If $ClassMethod(tPort, "InputProblem", tText, tValues, tMaxRows) '= "" {
            Set tSC = $ClassMethod(tPort, "RefuseFor", "input", .pHttpStatus, .pFault)
            Quit
        }

        Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        Set tCheckSC = ##class(OcuPilot.Area.Explorer.SqlConsole).Check(tNamespace, tText, .tGuard, .pHttpStatus, .pFault)
        If $$$ISERR(tCheckSC) {
            Set tSC = tCheckSC
            Quit
        }
        Set pHttpStatus = 0
        Set pFault = ""
        If tGuard.%GetTypeOf("error") = "object" {
            Set tError = ##class(OcuPilot.Area.Explorer.SqlConsole).ErrorOutcome(tGuard)
            Do tError.%Set("namespace", tNamespace, "string")
            Set pResult = tError
            Set pHttpStatus = 200
            Quit
        }
        Set tKind = tGuard.%Get("Kind")
        If $ClassMethod(tPort, "Mutating", tKind) {
            Set tSC = $ClassMethod(tPort, "RefuseFor", "changes", .pHttpStatus, .pFault)
            Quit
        }
        If tValues.%Size() '= tGuard.%Get("Parameters") {
            Set tSC = $ClassMethod(tPort, "RefuseFor", "parameters", .pHttpStatus, .pFault)
            Quit
        }

        Set tRunSC = $ClassMethod(tPort, "Run", tNamespace, tText, tValues, tMaxRows, "query", .tAnswer, .pHttpStatus, .pFault)
        If $$$ISERR(tRunSC) {
            Set tSC = tRunSC
            Quit
        }
        Set pResult = ..Projected(tNamespace, tGuard, tAnswer)
        Set pHttpStatus = 200
        Set pFault = ""
    } Catch ex {
        Set pResult = ""
        Set tSC = ..InternalRefusal("the SQL read tool failed: " _ ex.Name, .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The tool's answer from the port's run answer <var>pAnswer</var> and the classification
/// <var>pGuard</var>: the namespace, kind, statement type and tables, then the run's own members,
/// with the cells of each credential-named column masked.</p>
ClassMethod Projected(pNamespace As %String, pGuard As %DynamicObject, pAnswer As %DynamicObject) As %DynamicObject [ Private ]
{
    Set tResult = {}
    Do tResult.%Set("namespace", pNamespace, "string")
    Do tResult.%Set("kind", pGuard.%Get("Kind"), "string")
    Do tResult.%Set("statementType", pGuard.%Get("StatementType"), "number")
    Do tResult.%Set("tables", pGuard.%Get("Tables"))
    Set tIterator = pAnswer.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue, .tType) {
        If (tKey = "kind") || (tKey = "rows") || (tKey = "columns") Continue
        If (tType = "object") || (tType = "array") {
            Do tResult.%Set(tKey, tValue)
        } Else {
            Do tResult.%Set(tKey, tValue, tType)
        }
    }
    If pAnswer.%GetTypeOf("rows") = "array" {
        Set tColumns = $Select(pAnswer.%GetTypeOf("columns") = "array": pAnswer.%Get("columns"), 1: [])
        Do tResult.%Set("columns", tColumns)
        Set tMasked = ""
        Set tRedacted = []
        Set tColumnIterator = tColumns.%GetIterator()
        While tColumnIterator.%GetNext(.tIndex, .tName) {
            If ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tName) {
                Set tMasked = tMasked _ $ListBuild(tIndex)
                Do tRedacted.%Push(tName)
            }
        }
        Set tRows = pAnswer.%Get("rows")
        If $ListLength(tMasked) > 0 Set tRows = ..MaskedRows(tRows, tMasked)
        Do tResult.%Set("rows", tRows)
        Do tResult.%Set("redactedColumns", tRedacted)
    }
    Quit tResult
}

/// <p><var>pRows</var> with each cell at a position listed in <var>pMasked</var> (zero-based column
/// positions) replaced by <parameter>MASK</parameter>.</p>
ClassMethod MaskedRows(pRows As %DynamicArray, pMasked As %List) As %DynamicArray [ Private ]
{
    Set tOut = []
    Set tRowIterator = pRows.%GetIterator()
    While tRowIterator.%GetNext(.tRowIndex, .tRow) {
        If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicArray") {
            Do tOut.%Push(tRow)
            Continue
        }
        Set tNew = []
        Set tCellIterator = tRow.%GetIterator()
        While tCellIterator.%GetNext(.tCellIndex, .tCell, .tCellType) {
            If $ListFind(pMasked, tCellIndex) {
                Do tNew.%Push(..#MASK, "string")
            } ElseIf (tCellType = "object") || (tCellType = "array") {
                Do tNew.%Push(tCell)
            } Else {
                Do tNew.%Push(tCell, tCellType)
            }
        }
        Do tOut.%Push(tNew)
    }
    Quit tOut
}

}
