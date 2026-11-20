/// <p>SQL activity's cancel tool (Story 21.20, AD-6, AD-51, AD-52, AD-53, AD-58): cancel one running SQL
/// statement. Two callers reach it: the list's Cancel query row action through
/// <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation. It is the cancel
/// sibling of <class>OcuPilot.Screen.Tool.BackgroundTaskCancel</class>.</p>
/// <p><b>Its port is <class>OcuPilot.Port.SqlActivityPort</class></b> (AD-52), whose <code>ROW</code> read answers
/// the one statement the composite id names, fresh at the write, and whose <code>CANCEL</code> stops it. A cancel
/// ends a statement, never the process that ran it. The read-back is the statement's absence
/// (<code>CHANGEACTION</code> <code>deleted</code>, which also drops the row from the list).</p>
/// <p><b>It is action-style</b> (AD-51): no settable field and no body. Its fingerprint covers the process, the
/// statement id and the start time, so a confirm after the process moved to another statement is refused.
/// A statement of another server is refused by the port for both callers.</p>
/// <p><b>The target is composite</b> (AD-13): the agent names <code>server</code>, the process id and
/// <code>statementHash</code>, which <class>OcuPilot.Screen.Tool.SqlActivityMint</class> joins, and the screen
/// sends the row's own composite id.</p>
Class OcuPilot.Screen.Tool.SqlActivityCancel Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.sqlactivity.cancel";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SqlActivityList";

Parameter DESCRIPTION = "Propose canceling one running SQL statement. It changes nothing by itself: it answers a proposal the user reviews and confirms. Canceling stops the statement where it is; the process that ran it keeps running. Name the statement by its server, process id and statement hash exactly as the SQL activity list reports them. A statement that is no longer running, one that runs on another server, and a cancel of another user's statement without the SQL privilege %CANCEL_QUERY are refused.";

/// <p>The screen's own row action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "cancel";

/// <p>The port this tool's target lives behind (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.SqlActivityPort";

/// <p>The port endpoint this tool reads and writes.</p>
Parameter ENDPOINTNAME = "CurrentStatements";

/// <p>The fresh read: the one statement the composite id names.</p>
Parameter READTYPE = "ROW";

Parameter WRITETYPE = "CANCEL";

/// <p>No body: the port builds the vendor call (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

/// <p>The statement is gone from the list once it is canceled, so a list drops the row and the read-back
/// expects its absence.</p>
Parameter CHANGEACTION = "deleted";

/// <p>Not declared destructive: a canceled statement ends where it was and the process keeps running, as a
/// canceled background task does.</p>
Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p><code>%Admin_Operate:USE</code>, the resource the classic page's Cancel and the screen both declare (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Operate";

Parameter WRITEPERMISSION = "USE";

Parameter PRECONDITIONFIELD = "StatementId";

/// <p>Everything the card lists is covered, so that no card row is read as a change of its own (AD-51).</p>
Parameter FINGERPRINTSUBJECT = "ProcessID,StatementId,Started,UserName,Namespace,Statement";

/// <p>The rows the card lists: the statement that would stop, as the fresh read describes it.</p>
Parameter REMOVALROWS = "ProcessID,UserName,Namespace,Started,Statement";

/// <p>The argument naming the row's server.</p>
Parameter SERVERARGUMENT = "server";

/// <p>The argument naming the row's statement hash.</p>
Parameter HASHARGUMENT = "statementHash";

ClassMethod Endpoint() As %String
{
    Quit ..#ENDPOINTNAME
}

/// <p>The process id, the argument the composite id's second part is read from.</p>
ClassMethod IdArgument() As %String
{
    Quit "processId"
}

/// <p>The query parameter the port reads the composite id from.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.SqlActivityPort).#IDPARAM
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The class the agent's proposal is minted by: the kernel's own mint, after the server, the process id
/// and the statement hash are joined into the composite id (AD-13).</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.SqlActivityMint"
}

/// <p>The derived schema with the identifying property's description replaced and the server and the
/// statement hash added, required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The process id, copied as a string exactly as the SQL activity list's Process ID column reports it. A statement the list does not report is refused.", "string")
    Do tProperties.%Set(..#SERVERARGUMENT, {"type": "string", "description": "The server the statement runs on, exactly as the SQL activity list reports it."})
    Do tProperties.%Set(..#HASHARGUMENT, {"type": "string", "description": "The statement hash, exactly as the SQL activity list reports it."})
    Do tSchema.%Get("required").%Push(..#SERVERARGUMENT)
    Do tSchema.%Get("required").%Push(..#HASHARGUMENT)
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs, and nothing more (AD-8). The vendor's own SQL
/// privilege <code>%CANCEL_QUERY</code>, which canceling another user's statement needs, is not a pair; the
/// port answers 403 <code>SQLACTIVITY.NOPRIVILEGE</code> when the instance refuses it.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Quit tPairs
}

/// <p>The removal rows this proposal's card shows, from the fresh row <var>pFresh</var>. A row that reads no
/// statement id is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%Get(..#PRECONDITIONFIELD) = "") {
            Set pProblem = "this instance did not report that statement's id, and a statement it cannot identify is not one to cancel"
            Quit
        }
        Set pRows = ..RemovalRows(pFresh)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
