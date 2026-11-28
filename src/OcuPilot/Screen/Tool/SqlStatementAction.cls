/// <p>The base of the SQL statements writes (Story 21.6, AD-6, AD-10, AD-51, AD-52, AD-53, AD-58): an action-style write over one statement of
/// the namespace's statement index, or over the index itself, through <class>OcuPilot.Port.SqlPort</class>. Two callers reach each: the list's
/// row action, or the page's own, through <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation.</p>
/// <p><b>It sends no body.</b> The port makes one vendor call with the statement's hash alone, or, for a clean, no argument
/// (<method>OcuPilot.Port.SqlPort.StatementCall</method>). The fresh read is the port's <code>STATEMENT</code>, which answers the statement's
/// plan state, its new-plan flag, its plan error and its run statistics, and for the id <code>*</code> the index's statements and stale
/// entries. The fingerprint covers <parameter>FINGERPRINTSUBJECT</parameter>, which names the namespace so that a confirm reaches the namespace
/// the proposal read (<method>PortQuery</method>); a statement that changed after its proposal is closed target-changed.</p>
/// <p><b>Its rules are the tool's.</b> <method>Holds</method> decides whether the fresh read still meets the action's precondition, and
/// <method>StateDiff</method> refuses an unmet one with the sentence <method>RefusalCode</method> names, for both callers. A statement
/// any of whose tables is OcuPilot's own is refused by the kernel's own-statement arm for both callers, before any write
/// (<class>OcuPilot.Kernel.Proposal.Prohibited</class>).</p>
/// <p><b>Its pairs</b> are its screen's, which hold the custom resource of the classic SQL page the screen replaces, and WRITE on the namespace's
/// routines database as an argument pair (<method>ArgumentPairs</method>), which the port checks again for the namespace it writes (AD-8, AD-44).</p>
Class OcuPilot.Screen.Tool.SqlStatementAction Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

/// <p>The port every statement write reaches its target through (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.SqlPort";

/// <p>The port-composed fresh read: the statement-index row of the target hash, or the index's own counts for <code>*</code> (AD-51's Story 21.6
/// case).</p>
Parameter READTYPE = "STATEMENT";

/// <p>No body: the port makes the vendor call with the hash alone.</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>None of the writes removes data a person owns: a freeze, an unfreeze and a clear change the statement index alone.</p>
Parameter DESTRUCTIVE As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>The pair the write itself names: <code>%Development:USE</code>, which the vendor's freeze, unfreeze and clear of statistics check
/// themselves and its clean and plan-error update do not, so the port's gate is what holds it for all five.</p>
Parameter WRITERESOURCE = "%Development";

Parameter WRITEPERMISSION = "USE";

/// <p>What the <code>STATEMENT</code> read answers for a hash.</p>
Parameter READANSWERS = "Namespace,Hash,PlanState,NewPlan,PlanError,Executions,AverageTime,Tables";

/// <p>The namespace, plan state, new-plan flag and plan error a statement write was reviewed against; the run statistics are not in the
/// subject, since a statement that runs moves them without moving what the person reviewed.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,PlanState,NewPlan,PlanError";

/// <p>The read field the action's precondition reads, which a declared subject must carry (AD-51): the plan state here, for the writes whose
/// precondition reads it and for the one that has none, which still holds the plan it was reviewed against.</p>
Parameter PRECONDITIONFIELD = "PlanState";

/// <p>The payload field naming the namespace the write runs in.</p>
Parameter NAMESPACEFIELD = "Namespace";

/// <p>The code whose sentence refuses a fresh read that does not meet the precondition, or <code>""</code> for a write with none.</p>
Parameter REFUSALCODE;

/// <p>What the state row's after reads.</p>
Parameter STATEAFTER;

/// <p>The code the card and the dialog state their consequence by.</p>
Parameter CONSEQUENCECODE;

/// <p>The arguments this tool admits beside its target, comma-separated, in the order the dialog draws them, or <code>""</code> for a tool that admits
/// none. Each is a declared argument of the kind <method>ValueType</method> names, which reaches the port in its query (<method>PortQuery</method>) and
/// is part of the fingerprint's subject, so a confirm writes the values the person reviewed (Stories 21.25 and 21.27).</p>
Parameter VALUENAMES;

/// <p>The names among <parameter>VALUENAMES</parameter> an argument must carry, comma-separated, or <code>""</code>: every one. A name left out of a
/// non-empty list is optional, and an omitted one is not sent.</p>
Parameter REQUIREDVALUES;

/// <p>The description the input schema gives each of the arguments, as <code>name=description</code> entries separated by <code>|</code>.</p>
Parameter VALUEDESCRIPTIONS;

/// <p>The description the input schema gives the identifying property.</p>
Parameter IDDESCRIPTION = "The statement to change, named by the hash this namespace's SQL statements list reports in its Statement hash column.";

/// <p>The statement's hash.</p>
ClassMethod IdArgument() As %String
{
    Quit "Hash"
}

/// <p>The query key the port reads the target from.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.SqlPort).#IDKEY
}

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.SqlPort).#ENDPOINTSTATEMENTS
}

/// <p>The declared arguments (<parameter>VALUENAMES</parameter>), none beyond the target where it is empty.</p>
ClassMethod SettableFields() As %List
{
    If ..#VALUENAMES = "" Quit ""
    Quit $ListFromString(..#VALUENAMES)
}

/// <p>The declared arguments an argument set must carry, as a list: <parameter>REQUIREDVALUES</parameter>, or every declared one.</p>
ClassMethod RequiredFields() As %List
{
    If ..#REQUIREDVALUES = "" Quit ..SettableFields()
    Quit $ListFromString(..#REQUIREDVALUES)
}

/// <p>The kind of declared argument <var>pName</var>: <code>boolean</code> here, <code>true</code> or <code>false</code>. A tool that takes another
/// kind answers <code>integer</code> (a number) or <code>string</code>, and judges each value in <method>ValueProblem</method>.</p>
ClassMethod ValueType(pName As %String) As %String
{
    Quit "boolean"
}

/// <p>Why <var>pValue</var>, the text of declared argument <var>pName</var>, is not a value this tool sends, as a sentence, or <code>""</code>. A
/// boolean is judged by its type, so none here; a tool that takes another kind judges its shape here, as the port does.</p>
ClassMethod ValueProblem(pName As %String, pValue As %String) As %String
{
    Quit ""
}

/// <p>The text of the stored value <var>pValue</var> of declared argument <var>pName</var>, of the JSON type <var>pType</var>, as it travels in the
/// port's query: <code>true</code> or <code>false</code> for a boolean, the value's own text otherwise.</p>
ClassMethod QueryValue(pName As %String, pValue As %String, pType As %String) As %String
{
    If pType = "boolean" Quit $Select(pValue: "true", 1: "false")
    Quit pValue
}

/// <p>The JSON type a declared argument of kind <var>pKind</var> is stored as: <code>boolean</code>, <code>number</code> or <code>string</code>.</p>
ClassMethod JsonTypeOf(pKind As %String) As %String
{
    Quit $Case(pKind, "integer": "number", : pKind)
}

/// <p>The description <parameter>VALUEDESCRIPTIONS</parameter> gives <var>pName</var>, or <code>""</code>.</p>
ClassMethod ValueDescription(pName As %String) As %String
{
    Set tEntry = ""
    For tI = 1:1:$Length(..#VALUEDESCRIPTIONS, "|") {
        Set tEntry = $Piece(..#VALUEDESCRIPTIONS, "|", tI)
        If $Piece(tEntry, "=", 1) = pName Quit
    }
    If $Piece(tEntry, "=", 1) '= pName Quit ""
    Quit $Piece(tEntry, "=", 2, *)
}

/// <p>The identifying property described, and each declared argument added, of its kind, and each required one required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", ..#IDDESCRIPTION, "string")
    Set tNames = ..SettableFields()
    Set tRequired = ..RequiredFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Set tProperty = {}
        Do tProperty.%Set("type", ..ValueType(tName), "string")
        Do tProperty.%Set("description", ..ValueDescription(tName), "string")
        Do tProperties.%Set(tName, tProperty)
        If $ListFind(tRequired, tName) && (tSchema.%GetTypeOf("required") = "array") Do tSchema.%Get("required").%Push(tName)
    }
    Quit tSchema
}

/// <p>The screen's own pairs, the custom resource of its classic page among them (AD-44), each pair once. <var>pResolved</var> is 0 when
/// the screen's pairs cannot be read.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
}

/// <p>WRITE on the routines database of the namespace the stored payload names, else of the request's scope
/// (<method>OcuPilot.Screen.Tool.ExplorerSave.CodeWritePairs</method>), so a confirm is gated on the namespace it writes; the port asks the
/// same pair for that namespace before any vendor call.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Tool.ExplorerSave).CodeWritePairs(pArgs, .pResolved)
}

/// <p>The namespace, then each declared argument of the stored payload (or of the caller's arguments) <var>pPayload</var> under the port's own query
/// keys, as <method>QueryValue</method> renders it, so the confirm's re-read and write reach the namespace the proposal read (AD-52) and tune, gather or run
/// with the values the person reviewed. A fresh read, whose payload is empty, is scoped by the port. A value of the wrong kind, or one the payload does
/// not hold, is not sent.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.SqlPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
    Set tNames = ..SettableFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Set tType = pPayload.%GetTypeOf(tName)
        If tType = ..JsonTypeOf(..ValueType(tName)) Set pQuery(tName) = ..QueryValue(tName, pPayload.%Get(tName), tType)
    }
}

/// <p>Why <var>pId</var> is not a target of this tool, or <code>""</code>: a statement's hash here. <code>*</code> is the clean's alone.</p>
ClassMethod IdProblem(pId As %String) As %String
{
    If '$IsObject(pId) && ##class(OcuPilot.Port.SqlPort).HashValid(pId) Quit ""
    Quit "'" _ ..IdArgument() _ "' names one statement by its hash, as this namespace's SQL statements list reports it"
}

/// <p>The target refused as <method>IdProblem</method> refuses it, then each required declared argument that is not of its kind, and each other one
/// that is present and not (<method>ValueProblem</method>), before anything is stored (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ..IdProblem(pIdValue)
    If pProblem '= "" Quit $$$OK
    Set tNames = ..SettableFields()
    Set tRequired = ..RequiredFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Set tType = $Select($IsObject(pArgs): pArgs.%GetTypeOf(tName), 1: "unassigned")
        If '$ListFind(tRequired, tName) && (tType = "unassigned") Continue
        If ..ValueType(tName) = "boolean" {
            If tType '= "boolean" {
                Set pProblem = "'" _ tName _ "' is true or false"
                Quit
            }
            Continue
        }
        Set tText = $Select(tType = ..JsonTypeOf(..ValueType(tName)): pArgs.%Get(tName), 1: "")
        Set pProblem = ..ValueProblem(tName, tText)
        If pProblem '= "" Quit
    }
    Quit $$$OK
}

/// <p>The target refused as <method>IdProblem</method> refuses it for the screen's route, which passes it as <method>IdArgument</method> in
/// <var>pValues</var>, then the screen's values as this tool's arguments, each of its kind and any other spelling refused (AD-56 (ii)): a boolean is
/// <code>true</code> or <code>false</code>, and another kind is judged by <method>ValueProblem</method>. An optional value the screen does not send is left
/// out.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pActionId, pValues, pFresh, .pArgs, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tId = ""
    If $IsObject(pValues) && (pValues.%GetTypeOf(..IdArgument()) = "string") Set tId = pValues.%Get(..IdArgument())
    Set pProblem = ..IdProblem(tId)
    If pProblem '= "" Quit $$$OK
    Set tNames = ..SettableFields()
    Set tRequired = ..RequiredFields()
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        Set tValue = ""
        If $IsObject(pValues) Set tValue = pValues.%Get(tName)
        If '$ListFind(tRequired, tName) && (tValue = "") Continue
        If ..ValueType(tName) = "boolean" {
            If (tValue '= "true") && (tValue '= "false") {
                Set pProblem = "'" _ tName _ "' is true or false"
                Set pArgs = {}
                Quit
            }
            Do pArgs.%Set(tName, (tValue = "true"), "boolean")
            Continue
        }
        Set pProblem = ..ValueProblem(tName, tValue)
        If pProblem '= "" {
            Set pArgs = {}
            Quit
        }
        If ..ValueType(tName) = "integer" {
            Do pArgs.%Set(tName, +tValue, "number")
        } Else {
            Do pArgs.%Set(tName, tValue, "string")
        }
    }
    Quit $$$OK
}

/// <p>Whether the fresh read <var>pFresh</var> still meets this write's precondition. <code>1</code> here, for a write with none.</p>
ClassMethod Holds(pFresh As %DynamicObject) As %Boolean
{
    Quit 1
}

/// <p>The code whose sentence refuses the fresh read <var>pFresh</var>, which does not meet the precondition: <parameter>REFUSALCODE</parameter>
/// here, for a write whose refusals state one reason.</p>
ClassMethod RefusalCode(pFresh As %DynamicObject) As %String
{
    Quit ..#REFUSALCODE
}

/// <p>The one state row this proposal's card shows, from the fresh read <var>pFresh</var>: <parameter>STATEFIELD</parameter> moving from
/// what the instance holds to <parameter>STATEAFTER</parameter>. A read that does not meet the precondition (<method>Holds</method>) is
/// <var>pProblem</var>, the sentence <method>RefusalCode</method> names.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || '..Holds(pFresh) {
            Set pProblem = ##class(OcuPilot.Port.SqlPort).ReasonFor(..RefusalCode(pFresh))
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(..#STATEFIELD), pFresh.%GetTypeOf(..#STATEFIELD)), "string")
        Do tRow.%Set("after", ..#STATEAFTER, "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><parameter>CONSEQUENCECODE</parameter>, the sentence the card and the dialog state.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

}
