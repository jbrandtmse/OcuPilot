/// <p>The agent's advice on one query's plan (Story 21.27, AD-3, AD-21, AD-36, AD-60): the plan the instance gives the statement and the findings
/// <class>OcuPilot.Port.SqlAdvice</class> computes from that plan and the indices of the tables it reads, the answer SQL query's Advise
/// button shows. It runs nothing: <method>OcuPilot.Port.SqlPort.Plan</method> asks the instance for the plan alone, its typing prepare records the statement
/// in the namespace's statement index as Plan's does, and a statement the instance does not type as a query is refused 422 <code>EXPLORER.SQL.ADVICE</code>
/// before the plan is read.</p>
/// <p><b>It runs the console's own checks</b> as <class>OcuPilot.Screen.Tool.ExplorerSqlRead</class> does, in order: the screen's pairs,
/// <method>OcuPilot.Port.SqlPort.InputProblem</method> and <method>OcuPilot.Area.Explorer.SqlConsole.Check</method>, whose self-protection set
/// refuses OcuPilot's own tables. The statement reaches the instance only as the value <code>$SYSTEM.SQL.Explain</code> is given, and the two dictionary
/// reads behind the advice bind the names the plan gave. Every sentence of a finding is composed on the instance from fixed templates and names read from the
/// plan or the dictionary, and the whole result reaches the model through AD-60's sanitizer like every tool result.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlAdviceRead Extends OcuPilot.Screen.Tool.ExplorerSqlRead
{

Parameter TOOLNAME = "explorer.sqladvice.read";

Parameter DESCRIPTION = "Read the plan the instance gives one SQL query in the namespace this turn is scoped to, and advice on it: a full table scan, a missing index, a table that has not been tuned, a temporary file or an unused index, each with its table, a sentence and the plan text it came from. Send one SELECT. Nothing runs, and a statement that is not a query is refused. Advice is read from this one plan and its tables' indices. Check it against the real workload.";

/// <p>The statement alone: the plan is read without values.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set("statement", {"type": "string", "description": "One SQL query, 1 to 100,000 characters. Its plan is read and nothing runs; a value may be written as a ?."})
    Do tSchema.%Get("required").%Push("statement")
    Quit tSchema
}

/// <p>The result: <code>{namespace, kind, statementType, tables, outcome, plan, truncated, advice}</code> for a plan the instance gave, or
/// <code>{namespace, outcome, sqlcode, message}</code> for a statement it would not prepare or explain. <code>advice</code> is <code>{recognized, tables,
/// findings, truncated}</code>, each finding <code>{Kind, Confidence, Table, Fields, Index, Detail, Recommendation, Excerpt}</code>.</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "namespace": {"type": "string", "description": "The namespace the plan was read in."},
            "kind": {"type": "string", "description": "The kind the instance typed the statement: query."},
            "statementType": {"type": "integer", "description": "The instance's statement type number."},
            "tables": {"type": "array", "items": {"type": "string"}, "description": "The tables and views the instance records for the statement."},
            "outcome": {"type": "string", "enum": ["plan", "error"], "description": "plan: the instance gave the statement's plan. error: the instance refused or failed it, see sqlcode and message."},
            "plan": {"type": "string", "description": "The plan's text, cut at the port's bound."},
            "truncated": {"type": "boolean", "description": "True when the plan's text was cut."},
            "advice": {
                "type": "object",
                "description": "The advice read from the plan and the indices of the tables it reads.",
                "properties": {
                    "recognized": {"type": "boolean", "description": "False when OcuPilot did not recognize the plan's format, so it offers no advice."},
                    "tables": {"type": "array", "items": {"type": "object", "properties": {"Schema": {"type": "string"}, "Table": {"type": "string"}, "Class": {"type": "string", "description": "The table's compiled class, empty when the dictionary holds none."}}, "required": ["Schema", "Table", "Class"], "additionalProperties": false}, "description": "The tables the plan reads that were advised on."},
                    "findings": {"type": "array", "items": {"type": "object", "properties": {"Kind": {"type": "string", "enum": ["fullscan", "missingindex", "nottuned", "tempfile", "unusedindex"], "description": "fullscan: Full table scan. missingindex: Missing index. nottuned: Table not tuned. tempfile: Temporary file. unusedindex: Unused index."}, "Confidence": {"type": "string", "enum": ["high", "medium", "low"]}, "Table": {"type": "string", "description": "The table, schema and name, empty for a temporary file."}, "Fields": {"type": "string", "description": "The fields the finding is about, empty when it names none."}, "Index": {"type": "string", "description": "The index an unused-index finding is about, empty otherwise."}, "Detail": {"type": "string", "description": "What the plan shows, in a sentence."}, "Recommendation": {"type": "string", "description": "What to check next, in a sentence."}, "Excerpt": {"type": "string", "description": "The plan text the finding was read from."}}, "required": ["Kind", "Confidence", "Table", "Fields", "Index", "Detail", "Recommendation", "Excerpt"], "additionalProperties": false}, "description": "The findings, empty when there is nothing to advise."},
                    "truncated": {"type": "boolean", "description": "True when the tables or the findings were cut by a bound."}
                },
                "required": ["recognized", "tables", "findings", "truncated"],
                "additionalProperties": false
            },
            "sqlcode": {"type": "integer", "description": "The instance's SQLCODE, for an error outcome."},
            "message": {"type": "string", "description": "The instance's message, for an error outcome."},
            "rowsSent": {"type": "integer", "description": "How many rows this result carries."},
            "rowsAvailable": {"type": "integer", "description": "How many rows the read produced before the result was bounded."},
            "truncatedFields": {"type": "array", "items": {"type": "string"}, "description": "Field names whose value was shortened in this result, if any."}
        },
        "required": ["namespace", "outcome"],
        "additionalProperties": false
    }
}

/// <p>Read the plan and the advice for the statement <var>pArgs</var> carries and answer <method>ResultSchema</method>'s object. <var>pContextCap</var>
/// is not read here.</p>
/// <p>Every refusal is an error status with <var>pHttpStatus</var> and <var>pFault</var>: 400 <code>TOOL.ARGUMENTS</code> or
/// <code>EXPLORER.SQL.INPUT</code>, 403 for a missing pair or the self-protection set, 422 <code>EXPLORER.SQL.ADVICE</code> for a statement that is
/// not a query, and the port's own faults. A statement the instance did not prepare, or would not explain, is an <code>error</code> outcome with its SQLCODE.</p>
/// <p>Caller contract: not called from an escalated frame (AD-9); the prepare records the statement in the namespace's statement index (AD-7's fifth
/// shape).</p>
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
        Set tPort = ..#PORTCLASS
        If $ClassMethod(tPort, "InputProblem", tText) '= "" {
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

        Set tPlanSC = $ClassMethod(tPort, "Plan", tNamespace, tText, .tAnswer, .pHttpStatus, .pFault, 0, 1)
        If $$$ISERR(tPlanSC) {
            Set tSC = tPlanSC
            Quit
        }
        Set pResult = ..Advised(tNamespace, tGuard, tAnswer)
        Set pHttpStatus = 200
        Set pFault = ""
    } Catch ex {
        Set pResult = ""
        Set tSC = ..InternalRefusal("the SQL advice tool failed: " _ ex.Name, .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The tool's answer from the port's plan answer <var>pAnswer</var> and the classification <var>pGuard</var>: the namespace, kind, statement type and
/// tables, then the plan answer's own members but a JSON null.</p>
ClassMethod Advised(pNamespace As %String, pGuard As %DynamicObject, pAnswer As %DynamicObject) As %DynamicObject [ Private ]
{
    Set tResult = {}
    Do tResult.%Set("namespace", pNamespace, "string")
    Do tResult.%Set("kind", pGuard.%Get("Kind"), "string")
    Do tResult.%Set("statementType", pGuard.%Get("StatementType"), "number")
    Do tResult.%Set("tables", pGuard.%Get("Tables"))
    Set tIterator = pAnswer.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue, .tType) {
        If (tKey = "kind") || (tType = "null") Continue
        If (tType = "object") || (tType = "array") {
            Do tResult.%Set(tKey, tValue)
        } Else {
            Do tResult.%Set(tKey, tValue, tType)
        }
    }
    Quit tResult
}

}
