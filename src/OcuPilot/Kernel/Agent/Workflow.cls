/// <p>The guided-workflow catalog and the rules a workflow turn follows (AD-66): which workflows
/// exist, what the synthetic <code>workflow</code> result carries, and which write a workflow turn
/// may still propose.</p>
/// <p><b>The catalog is data.</b> <code>XData Catalog</code> holds the workflows as JSON, each an
/// <code>id</code>, a <code>purpose</code>, ordered <code>steps</code> and a <code>finish</code>; a
/// step says what to do and names the read tools (<code>reads</code>) and write tools
/// (<code>writes</code>) it uses by canonical name. A new workflow is a new entry, never a code
/// path. Every text is ASCII and names no tool the model cannot call. The steps are adapted from
/// iris-execute-mcp-v2's MCP prompts (<code>packages/*/src/prompts/*.ts</code>, MIT, Copyright (c) 2026
/// jbrandtmse, <code>ui/licenses/iris-execute-mcp-v2.txt</code>).</p>
/// <p><b>The result is OcuPilot's own data</b> (AD-11 rule 1): <method>Exchange</method> builds it from
/// the catalog's constants and from <code>previous</code>, the closed-vocabulary facts about the
/// proposals of the conversation's turn before (<method>Previous</method>). It holds no instance
/// text, so it adds no untrusted source; it reaches the model through the sanitizer beside screen
/// context (AD-60), counts within AD-24's total bound, and is never advertised as a tool, so a model
/// call named <code>workflow</code> is unknown.</p>
/// <p><b>Two refusals, one rule</b> (AD-66): in a workflow turn a write tool that no step names, and a
/// second proposal in the same turn, are refused by <method>WriteRefusal</method>'s answer. Every
/// write that passes is an ordinary proposal; the prohibited set, both switches and the governance
/// policy are evaluated where they are today, at the write (AD-40).</p>
Class OcuPilot.Kernel.Agent.Workflow Extends %RegisteredObject
{

/// <p>The most proposals <method>Previous</method> reports.</p>
Parameter PREVIOUSMAX As %Integer = 10;

/// <p>The class whose <code>XData Catalog</code> holds the workflows.</p>
Parameter CATALOGCLASS = "OcuPilot.Kernel.Agent.Workflow";

/// <p>The code <method>WriteRefusal</method> answers for a write tool no step names. The sentence it carries is
/// <class>OcuPilot.Api.WorkflowError</class>'s, which <code>OcuPilot.Test.WorkflowCatalog</code> holds equal to
/// this code; the kernel names no Api class but the error vocabulary.</p>
Parameter NOTASTEP = "WORKFLOW.NOTASTEP";

/// <p>The code <method>WriteRefusal</method> answers for a second proposal in one turn.</p>
Parameter ONECHANGE = "WORKFLOW.ONECHANGE";

/// <p>The catalog, parsed: <code>{"workflows": [...]}</code>, or <code>""</code> when it cannot be
/// read.</p>
ClassMethod Catalog() As %DynamicObject [ Private ]
{
    Set tCatalog = ""
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen(..#CATALOGCLASS, "Catalog", , .tOpenSC)
        If '$IsObject(tXData) Quit
        Do tXData.Data.Rewind()
        Set tParsed = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
        Set tXData = ""
        If $IsObject(tParsed) && tParsed.%IsA("%Library.DynamicObject") && (tParsed.%GetTypeOf("workflows") = "array") Set tCatalog = tParsed
    } Catch ex {
        Set tCatalog = ""
    }
    Quit tCatalog
}

/// <p>The catalog entry whose <code>id</code> is <var>pId</var>, matched exactly, or <code>""</code>.
/// <var>pFound</var> is 1 only when the entry exists.</p>
ClassMethod Lookup(pId As %String, Output pFound As %Boolean) As %DynamicObject
{
    Set pFound = 0
    Set tEntry = ""
    Try {
        If pId = "" Quit
        Set tCatalog = ..Catalog()
        If '$IsObject(tCatalog) Quit
        Set tIterator = tCatalog.%Get("workflows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tCandidate) {
            If $IsObject(tCandidate) && (tCandidate.%Get("id") = pId) {
                Set tEntry = tCandidate
                Set pFound = 1
                Quit
            }
        }
    } Catch ex {
        Set tEntry = ""
        Set pFound = 0
    }
    Quit tEntry
}

/// <p>Every workflow id the catalog holds, in catalog order, as a <class>%List</class>; empty when
/// the catalog cannot be read.</p>
ClassMethod Ids() As %List
{
    Set tIds = ""
    Try {
        Set tCatalog = ..Catalog()
        If '$IsObject(tCatalog) Quit
        Set tIterator = tCatalog.%Get("workflows").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tEntry) {
            If $IsObject(tEntry) && (tEntry.%GetTypeOf("id") = "string") Set tIds = tIds _ $ListBuild(tEntry.%Get("id"))
        }
    } Catch ex {
        Set tIds = ""
    }
    Quit tIds
}

/// <p>The canonical names of every write tool any step of workflow <var>pId</var> names, once each in
/// step order, as a <class>%List</class>; empty for a read-only workflow and for an unknown id.</p>
ClassMethod Writes(pId As %String) As %List
{
    Set tWrites = ""
    Try {
        Set tEntry = ..Lookup(pId, .tFound)
        If 'tFound Quit
        Set tSteps = tEntry.%Get("steps").%GetIterator()
        While tSteps.%GetNext(.tStepIndex, .tStep) {
            If tStep.%GetTypeOf("writes") '= "array" Continue
            Set tNames = tStep.%Get("writes").%GetIterator()
            While tNames.%GetNext(.tNameIndex, .tName) {
                If '$ListFind(tWrites, tName) Set tWrites = tWrites _ $ListBuild(tName)
            }
        }
    } Catch ex {
        Set tWrites = ""
    }
    Quit tWrites
}

/// <p>The code a workflow turn refuses a write call with, or <code>""</code> to let it through.
/// <var>pId</var> is the turn's workflow, <var>pTool</var> the write tool's canonical name and
/// <var>pMinted</var> how many proposals the turn already holds. A tool no step names is
/// <code>WORKFLOW.NOTASTEP</code>, and a step's tool once the turn holds a proposal is
/// <code>WORKFLOW.ONECHANGE</code>; the first test wins. Pure: it reads no turn state.</p>
ClassMethod WriteRefusal(pId As %String, pTool As %String, pMinted As %Integer) As %String
{
    If '$ListFind(..Writes(pId), pTool) Quit ..#NOTASTEP
    If +pMinted >= 1 Quit ..#ONECHANGE
    Quit ""
}

/// <p>The facts a workflow result reports about the proposals of the turn before, as an array of
/// <code>{tool, state, closedReason, readBack}</code>, at most
/// <parameter>PREVIOUSMAX</parameter>, in the order of <var>pRows</var>.</p>
/// <p><var>pRows</var> is <method>OcuPilot.Kernel.State.Propose.GuardedRowsForTurn</method>'s wire
/// array. <code>tool</code> is the registered tool's canonical name, <code>state</code> and
/// <code>closedReason</code> are the proposal row's own closed vocabularies, and
/// <code>readBack</code> is the recorded read-back's verdict (AD-58), or JSON <code>null</code> until
/// one is recorded. The target, the arguments and every other member stay out, so the result carries
/// no instance text (AD-11). Pure.</p>
ClassMethod Previous(pRows As %DynamicArray) As %DynamicArray
{
    Set tPrevious = []
    Try {
        If '$IsObject(pRows) Quit
        Set tIterator = pRows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tPrevious.%Size() >= ..#PREVIOUSMAX Quit
            If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicObject") Continue
            Set tOne = {}
            Do tOne.%Set("tool", tRow.%Get("tool"), "string")
            Do tOne.%Set("state", tRow.%Get("state"), "string")
            Do tOne.%Set("closedReason", tRow.%Get("closedReason"), "string")
            Set tReadBack = tRow.%Get("readBack")
            If $IsObject(tReadBack) && (tReadBack.%GetTypeOf("verdict") = "string") {
                Do tOne.%Set("readBack", tReadBack.%Get("verdict"), "string")
            } Else {
                Do tOne.%Set("readBack", "", "null")
            }
            Do tPrevious.%Push(tOne)
        }
    } Catch ex {
        Set tPrevious = []
    }
    Quit tPrevious
}

/// <p>The synthetic <code>workflow</code> result for workflow <var>pId</var>, as JSON text:
/// <code>{workflow, purpose, steps: [{step, say, reads?, writes?}], finish, previous}</code>, with
/// <code>step</code> numbered from 1 and <code>previous</code> the array <var>pPrevious</var>
/// (<method>Previous</method>'s answer; empty when omitted). <code>""</code> for an id the catalog
/// does not hold.</p>
ClassMethod Exchange(pId As %String, pPrevious As %DynamicArray = "") As %String
{
    Set tJson = ""
    Try {
        Set tEntry = ..Lookup(pId, .tFound)
        If 'tFound Quit
        Set tOut = {}
        Do tOut.%Set("workflow", pId, "string")
        Do tOut.%Set("purpose", tEntry.%Get("purpose"), "string")
        Set tSteps = []
        Set tIterator = tEntry.%Get("steps").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tStep) {
            Set tOne = {}
            Do tOne.%Set("step", tIndex + 1, "number")
            Do tOne.%Set("say", tStep.%Get("say"), "string")
            For tMember = "reads", "writes" {
                If tStep.%GetTypeOf(tMember) = "array" Do tOne.%Set(tMember, ..CopyNames(tStep.%Get(tMember)))
            }
            Do tSteps.%Push(tOne)
        }
        Do tOut.%Set("steps", tSteps)
        Do tOut.%Set("finish", tEntry.%Get("finish"), "string")
        If '$IsObject(pPrevious) Set pPrevious = []
        Do tOut.%Set("previous", pPrevious)
        Set tJson = tOut.%ToJSON()
    } Catch ex {
        Set tJson = ""
    }
    Quit tJson
}

/// <p>A new array holding the strings of <var>pNames</var>.</p>
ClassMethod CopyNames(pNames As %DynamicArray) As %DynamicArray [ Private ]
{
    Set tCopy = []
    Set tIterator = pNames.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tName) {
        Do tCopy.%Push(tName, "string")
    }
    Quit tCopy
}

/// <p>The workflows, as <code>{"workflows": [...]}</code>. A step names the read tools and write tools
/// it uses by canonical name; each resolves on the instance as the kind it is listed under, which
/// <class>OcuPilot.Test.WorkflowCatalog</class> holds.</p>
XData Catalog [ MimeType = application/json ]
{
{"workflows": [
 {"id": "recoverproduction", "purpose": "Recover a production that is troubled, stuck or not processing.",
  "steps": [
   {"say": "Read the production's state and each item's state.", "reads": ["interop.productions.read", "interop.items.read", "interop.itemstatus.read"]},
   {"say": "Find where messages wait and what the logs say.", "reads": ["interop.queues.read", "interop.monitor.read", "interop.itemlog.read", "logs.eventlog.read"]},
   {"say": "When it reads troubled or stuck, propose a recover first.", "writes": ["interop.productions.recover"]},
   {"say": "Read the state again; when it runs, report and stop.", "reads": ["interop.productions.read"]},
   {"say": "When it needs an update propose one; when it is still stuck propose a restart.", "writes": ["interop.productions.update", "interop.productions.restart"]}],
  "finish": "Say what changed and what still needs attention."},
 {"id": "resendmessages", "purpose": "Resend the failed messages of one business host once the person has seen what would be delivered again.",
  "steps": [
   {"say": "Find the failed messages for the host and the time window the person names, and read a few of their headers.", "reads": ["interop.messages.read", "interop.messageheader.read"]},
   {"say": "Tell the person that a resend delivers the data downstream again and ask them to confirm these messages are worth retrying; narrow the window or the host when they are not.", "reads": ["interop.messages.read"]},
   {"say": "When the person agrees, propose the resend of those messages. The resend is switched off until an administrator enables it; report a disabled answer and stop.", "writes": ["interop.messages.resend"]},
   {"say": "Read the messages again to see the new headers and report any that failed.", "reads": ["interop.messages.read", "interop.messageheader.read"]}],
  "finish": "Say what was resent, what failed and what still needs attention."},
 {"id": "tracemessage", "purpose": "Follow one message through its session and find where it failed.",
  "steps": [
   {"say": "Find the session of the message the person names, from the message list or from its header.", "reads": ["interop.messages.read", "interop.messageheader.read"]},
   {"say": "Read the session's trace to see each hop, its source, its target and its status.", "reads": ["interop.messagetrace.read"]},
   {"say": "For each hop that failed, read the item log and the event log around the same time.", "reads": ["interop.itemlog.read", "logs.eventlog.read"]},
   {"say": "Name the failure point: which item failed, what its log says and where in the flow it happened."}],
  "finish": "Say where the flow failed and what to check next. This workflow changes nothing."},
 {"id": "systemhealth", "purpose": "Check this instance's health and name the fix for anything that is not healthy.",
  "steps": [
   {"say": "Read the dashboard and the system usage for the overall state.", "reads": ["osmgmt.dashboard.read", "osmgmt.systemusage.read"]},
   {"say": "Check capacity: database free space, journals and the license.", "reads": ["osmgmt.databasefreespace.read", "osmgmt.journals.read", "osmgmt.licensesummary.read"]},
   {"say": "Check what waits or fails: locks, alerts.log and messages.log.", "reads": ["osmgmt.locks.read", "logs.alerts.read", "logs.messages.read"]},
   {"say": "When a finding names a fix, propose the one change that addresses the most serious finding: grow a database, end a runaway process or run an on-demand task.", "writes": ["osmgmt.localdatabases.update", "osmgmt.processes.terminate", "tasks.ondemand.run"]}],
  "finish": "Say what is healthy, what is not and what was changed."},
 {"id": "securityposture", "purpose": "Review this instance's security posture and report what to verify.",
  "steps": [
   {"say": "List the users and flag accounts that look stale or use a well-known default name, for the person to verify.", "reads": ["permissions.users.read"]},
   {"say": "List the roles and flag every role that grants %All, then every user who holds one.", "reads": ["permissions.roles.read", "permissions.users.read"]},
   {"say": "List the services and flag any that is enabled without authentication or is not needed.", "reads": ["permissions.services.read"]},
   {"say": "List the SSL/TLS configurations and flag a weak minimum version or a missing certificate.", "reads": ["security.ssl.read"]},
   {"say": "Check whether auditing is on and which system events it records.", "reads": ["security.auditing.read", "security.auditsystemevents.read"]}],
  "finish": "Report the default or weak credentials, the %All holders and the insecure services or configurations, and recommend fixes. This workflow changes nothing."},
 {"id": "slowquery", "purpose": "Find out why a query is slow and recommend a fix.",
  "steps": [
   {"say": "Read the statements recorded for the table the query uses and the cached queries, for their run counts and times.", "reads": ["explorer.sqltablestatements.read", "explorer.sqlcachedqueries.read"]},
   {"say": "Read the table's indices to see which could serve the query's conditions.", "reads": ["explorer.sqlindices.read"]},
   {"say": "When the person gave the statement, run it as a read to see what it returns.", "reads": ["explorer.sqlquery.read"]},
   {"say": "Weigh the findings: a condition on a column with no index, a function on an indexed column, a join without an index, a cached query with a high average time."}],
  "finish": "Recommend a fix, such as an index to add or a condition to rewrite, and say that nothing was changed."},
 {"id": "compileclass", "purpose": "Fix a class until it compiles, one confirmed change at a time.",
  "steps": [
   {"say": "Read the class and its source.", "reads": ["explorer.classes.read", "explorer.class.source"]},
   {"say": "Find what stops it compiling and propose a save of the class with the smallest fix. Confirm saves it and then compiles it, and the card shows the person the compiler's output, which you do not see.", "writes": ["explorer.classes.save"]},
   {"say": "After the person confirms, ask what the card's compile output says unless they have said; when it reports errors, read the class again and go back to the second step with them.", "reads": ["explorer.class.source"]},
   {"say": "When the person asks to compile it again, or to compile the classes that use it, propose that compile.", "writes": ["explorer.classes.compile"]}],
  "finish": "Say what was changed and whether the person reported that the class compiles."},
 {"id": "reviewclass", "purpose": "Review a class's ObjectScript for faults and style.",
  "steps": [
   {"say": "Read the class and its source.", "reads": ["explorer.classes.read", "explorer.class.source"]},
   {"say": "Check the code against ObjectScript practice: error handling, quits inside try blocks, SQL built from caller values, namespace switches and naming."}],
  "finish": "List the findings with the line each applies to, most serious first, and say that nothing was changed."},
 {"id": "newproject", "purpose": "Set up a new project's databases, namespace, user and web application, one confirmed change at a time.",
  "steps": [
   {"say": "Read what exists: the databases, the namespaces, the users and the web applications, so that no name is reused.", "reads": ["osmgmt.localdatabases.read", "osmgmt.namespaces.read", "permissions.users.read", "webapp.list.read"]},
   {"say": "Propose the project's databases, the data database first and then the code database.", "writes": ["osmgmt.localdatabases.create"]},
   {"say": "Propose the namespace over those databases.", "writes": ["osmgmt.namespaces.create"]},
   {"say": "Propose the project's user, with the new namespace as its default.", "writes": ["permissions.users.create"]},
   {"say": "Propose the web application for the project's namespace.", "writes": ["webapp.list.create"]},
   {"say": "When a step fails or the person asks to undo, propose the matching delete for the newest thing created, then the older ones in turn.", "writes": ["osmgmt.localdatabases.delete", "osmgmt.namespaces.delete", "permissions.users.delete", "webapp.list.delete"]}],
  "finish": "Say what was created and what is left to do by hand."}
]}
}

}
