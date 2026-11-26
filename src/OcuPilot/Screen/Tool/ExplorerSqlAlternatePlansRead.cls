/// <p>The agent's read of the plans the optimizer considered for one query (Story 21.28, AD-3, AD-21, AD-36, AD-60): the possible plans with their cost,
/// map type and starting map, or the text of one of them by its plan number, the answer SQL query's Alternate plans and Show plan show.
/// <method>OcuPilot.Port.SqlPort.Plan</method> asks the instance for the plans alone and runs nothing; its typing prepare records the statement in the
/// namespace's statement index as Plan's does. The agent has no compare: comparing plans runs the statement, so it is a person's action on SQL query.</p>
/// <p><b>It runs the console's own checks</b> as <class>OcuPilot.Screen.Tool.ExplorerSqlRead</class> does, in order: the screen's pairs and the custom
/// resource assigned to the classic Alternate Show Plans page (<method>PrivilegePairs</method>), <method>OcuPilot.Port.SqlPort.InputProblem</method> and
/// <method>OcuPilot.Area.Explorer.SqlConsole.Check</method>, whose self-protection set refuses OcuPilot's own tables. A statement of any other kind than a
/// query is refused 422 <code>EXPLORER.SQL.CHANGES</code> before anything reaches the instance. The statement reaches the instance only as the value the
/// port passes it, and the whole result reaches the model through AD-60's sanitizer like every tool result.</p>
Class OcuPilot.Screen.Tool.ExplorerSqlAlternatePlansRead Extends OcuPilot.Screen.Tool.ExplorerSqlRead
{

Parameter TOOLNAME = "explorer.sqlalternateplans.read";

Parameter DESCRIPTION = "List the plans the optimizer considered for one SQL query, with their cost, map type and starting map, or show one of them by its plan number. This lists and shows plans and runs nothing.";

/// <p>The statement and, to show one plan's text instead of the list, that plan's number. There is no values argument and no compare argument.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set("statement", {"type": "string", "description": "One SQL query, 1 to 100,000 characters, of at most 4 tables and 4 conditions. Its plans are read and nothing runs; a value may be written as a ?."})
    Do tSchema.%Get("required").%Push("statement")
    Do tProperties.%Set("plan", {"type": "integer", "description": "A plan number from the list of this statement's possible plans. Send it to read that plan's text instead of the list. Absent, the list is read."})
    Quit tSchema
}

/// <p>The screen's own pairs with the custom resource assigned to the classic page <parameter>OcuPilot.Area.Explorer.SqlConsole.ALTERNATESPAGE</parameter>
/// (AD-8, AD-44): the statement's SQL privileges and the namespace's database pairs are the port's to check.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved), $Parameter("OcuPilot.Area.Explorer.SqlConsole", "ALTERNATESPAGE"))
}

/// <p>The result: <code>{namespace, kind, statementType, tables, outcome, plans, truncated}</code> for the list, <code>{namespace, kind, statementType,
/// tables, outcome, alternate, plan, truncated}</code> for one plan's text, or <code>{namespace, outcome, sqlcode, message}</code> for a statement the
/// instance would not prepare or explain. Each plan is <code>{Plan, Cost, MapType, StartingMap}</code>.</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "namespace": {"type": "string", "description": "The namespace the plans were read in."},
            "kind": {"type": "string", "description": "The kind the instance typed the statement: query."},
            "statementType": {"type": "integer", "description": "The instance's statement type number."},
            "tables": {"type": "array", "items": {"type": "string"}, "description": "The tables and views the instance records for the statement."},
            "outcome": {"type": "string", "enum": ["plans", "plan", "error"], "description": "plans: the list of possible plans. plan: the text of the one plan asked for. error: the instance refused or failed it, see sqlcode and message."},
            "plans": {"type": "array", "items": {"type": "object", "properties": {"Plan": {"type": "integer", "description": "The plan's number."}, "Cost": {"type": "string", "description": "The optimizer's cost for the plan."}, "MapType": {"type": "string", "description": "The type of the map the plan starts from."}, "StartingMap": {"type": "string", "description": "The map the plan starts from."}}, "required": ["Plan", "Cost", "MapType", "StartingMap"], "additionalProperties": false}, "description": "The possible plans, at most 100, for the list."},
            "alternate": {"type": "integer", "description": "The number of the plan whose text this is, for the plan outcome."},
            "plan": {"type": "string", "description": "The plan's text, cut at the port's bound, for the plan outcome."},
            "truncated": {"type": "boolean", "description": "True when the list was cut at 100 plans or the plan's text was cut."},
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

/// <p>Read the plans of the statement <var>pArgs</var> carries, or the text of the plan it numbers, and answer <method>ResultSchema</method>'s object.
/// <var>pContextCap</var> is not read here.</p>
/// <p>Every refusal is an error status with <var>pHttpStatus</var> and <var>pFault</var>: 400 <code>TOOL.ARGUMENTS</code>, <code>EXPLORER.SQL.INPUT</code>
/// or <code>EXPLORER.SQL.ALTPLAN</code>, 403 for a missing pair, the self-protection set, the SQL SELECT privilege on a table or the SQL EXECUTE privilege
/// on a procedure, 422 <code>EXPLORER.SQL.CHANGES</code> for a statement that is not a query or <code>EXPLORER.SQL.ALTBOUND</code> for one over the bound,
/// and the port's own faults. A statement the instance did not prepare, or would not explain, is an <code>error</code> outcome with its SQLCODE.</p>
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
        Set tPairs = ..PrivilegePairs(, .tResolved)
        If 'tResolved || '##class(OcuPilot.Screen.Gate).EvaluateRequired(tPairs, .tFailedPair) {
            Set pHttpStatus = ##class(OcuPilot.Kernel.Denial).#STATUS
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason())
            Do pFault.%Set("detail", ##class(OcuPilot.Kernel.Denial).Detail(tFailedPair))
            Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Kernel.Denial).Code())
            Quit
        }

        Set tText = tArgs.%Get("statement")
        Set tPlanId = $Select(tArgs.%GetTypeOf("plan") = "number": tArgs.%Get("plan"), 1: "")
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
        If $ClassMethod(tPort, "Mutating", tGuard.%Get("Kind")) {
            Set tSC = $ClassMethod(tPort, "RefuseFor", "changes", .pHttpStatus, .pFault)
            Quit
        }

        Set tPlanSC = $ClassMethod(tPort, "Plan", tNamespace, tText, .tAnswer, .pHttpStatus, .pFault, 0, 0, 1, tPlanId)
        If $$$ISERR(tPlanSC) {
            Set tSC = tPlanSC
            Quit
        }
        Set pResult = ..Listed(tNamespace, tGuard, tAnswer)
        Set pHttpStatus = 200
        Set pFault = ""
    } Catch ex {
        Set pResult = ""
        Set tSC = ..InternalRefusal("the alternate plans tool failed: " _ ex.Name, .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The tool's answer from the port's plan answer <var>pAnswer</var> and the classification <var>pGuard</var>: the namespace, kind, statement type and
/// tables, then the plan answer's own members but a JSON null.</p>
ClassMethod Listed(pNamespace As %String, pGuard As %DynamicObject, pAnswer As %DynamicObject) As %DynamicObject [ Private ]
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
