/// <p>External language servers' start tool (AD-6, AD-51, AD-53): start one external language
/// server. Two callers reach it: the list's Start row action through
/// <class>OcuPilot.Api.ScreenAction</class>, sent with no dialog, and the agent's proposal and
/// confirmation. <class>OcuPilot.Screen.Tool.LanguageServerStop</class> is this tool with the
/// <code>STOP</code> request type and the opposite precondition.</p>
/// <p><b>It is action-style</b> (AD-51). The vendor exposes start only as the bodyless
/// <code>START</code> request type (<code>NeedsRequestBody()</code> admits only a put and a patch), so
/// the tool admits no settable field and sends no body. Its fresh read is <code>ACTIVITY</code>, the one
/// type that answers <code>CurrentlyRunning</code>; its precondition, its fingerprint subject and its
/// state row are that field, so a confirm after the server started or stopped elsewhere is refused.</p>
/// <p><b>The vendor's start does not refuse a running server</b> (it answers 200), so the refusal is
/// OcuPilot's: <method>StateDiff</method> answers <parameter>RUNNINGREASON</parameter>, the sentence
/// EXPERIENCE.md publishes, before anything is written. A start the instance refuses answers 500
/// <code>LANGUAGESERVER.START</code> (<parameter>OcuPilot.Port.AdminPort.TYPEFAULTS</parameter>).</p>
/// <p>A start blocks until the server answers or its <code>InitializationTimeout</code> runs out, 10.7
/// to 14.7 s for a Java server (measured on <code>ocupilot-ci</code>). It leaves only the launch's
/// <code>%System/%System/OSCommand</code> audit events.</p>
Class OcuPilot.Screen.Tool.LanguageServerStart Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.languageservers.start";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LanguageServerList";

Parameter DESCRIPTION = "Propose starting one external language server this instance defines: a Java, .NET, Python or other gateway. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the server exactly as the external language servers list reports it; names are compared with their case. A server that is already running is refused.";

/// <p>The screen's own row action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "start";

/// <p>The state read: <code>LanguageServer</code>'s <code>ACTIVITY</code>, the one type that answers
/// <code>CurrentlyRunning</code> (AD-36, AD-51).</p>
Parameter READTYPE = "ACTIVITY";

Parameter WRITETYPE = "START";

/// <p>No body: <code>START</code> and <code>STOP</code> read none
/// (<parameter>OcuPilot.Port.AdminPort.BODYLESSTYPES</parameter>).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p><code>%Admin_ExternalLanguageServerEdit:USE</code>, the vendor's own <code>ResourcesOR()</code>
/// resource and the pair <class>OcuPilot.Screen.Descriptor.LanguageServerList</class> declares as its
/// own (AD-8 as amended).</p>
Parameter WRITERESOURCE = "%Admin_ExternalLanguageServerEdit";

Parameter WRITEPERMISSION = "USE";

/// <p>The classic page whose Start this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.ExternalLanguageServerStart";

/// <p>The <code>ACTIVITY</code> field this tool's precondition reads, a JSON boolean.</p>
Parameter PRECONDITIONFIELD = "CurrentlyRunning";

Parameter FINGERPRINTSUBJECT = "CurrentlyRunning";

Parameter STATEFIELD = "CurrentlyRunning";

/// <p>Whether this tool starts the server (1) or stops it (0), which decides the state it refuses and
/// the state it moves to.</p>
Parameter STARTS As BOOLEAN = 1;

/// <p>The state row's two values, the words the list's Running column reads.</p>
Parameter RUNNINGWORD = "Yes";

Parameter STOPPEDWORD = "No";

/// <p>A start's refusal of a running server, published in EXPERIENCE.md's Fixed strings and pinned
/// equal to <code>languageServerRefusalRunning</code> by <file>ui/tools/self-protection.test.mjs</file>.</p>
Parameter RUNNINGREASON = "This server is already running.";

/// <p>A stop's refusal of a stopped server, published in EXPERIENCE.md's Fixed strings and pinned
/// equal to <code>languageServerRefusalStopped</code> by <file>ui/tools/self-protection.test.mjs</file>.</p>
Parameter STOPPEDREASON = "This server is not running.";

ClassMethod Endpoint() As %String
{
    Quit "LanguageServer"
}

/// <p>The server's name, which the list's rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

/// <p>The query parameter <code>LanguageServer</code> identifies a server by, for the
/// <code>ACTIVITY</code> read and the write alike.</p>
ClassMethod IdParam() As %String
{
    Quit "name"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The derived schema with the identifying property's description replaced: the target is one
/// server, named exactly as the list reports it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) Quit tSchema
    If tSchema.%GetTypeOf("properties") '= "object" Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) '= "object" Quit tSchema
    Do tProperties.%Get(..IdArgument()).%Set("description", "The external language server, named exactly as this instance's own external language servers list reports it, case included. A server the list does not report is refused.", "string")
    Quit tSchema
}

/// <p>What the caller must hold: the screen's own pairs (AD-8 as amended), then the custom resource
/// of each <parameter>CLASSICPAGES</parameter> page, each pair once (AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

/// <p>The one row this proposal's card shows, from the fresh <code>ACTIVITY</code> read
/// <var>pFresh</var>: <code>CurrentlyRunning</code> moving from No to Yes for a start, Yes to No for a
/// stop. A server already in the state the action leaves is <var>pProblem</var>,
/// <parameter>RUNNINGREASON</parameter> or <parameter>STOPPEDREASON</parameter>; a read that answered
/// no boolean <code>CurrentlyRunning</code> refuses too, since a state nobody established is not one
/// to act on.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tType = ""
        If $IsObject(pFresh) Set tType = pFresh.%GetTypeOf(..#PRECONDITIONFIELD)
        If tType '= "boolean" {
            Set pProblem = "this instance did not report whether that server is running"
            Quit
        }
        Set tRunning = ''pFresh.%Get(..#PRECONDITIONFIELD)
        If ..#STARTS && tRunning {
            Set pProblem = ..#RUNNINGREASON
            Quit
        }
        If '..#STARTS && 'tRunning {
            Set pProblem = ..#STOPPEDREASON
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", ..#STATEFIELD, "string")
        Do tRow.%Set("before", $Select(tRunning: ..#RUNNINGWORD, 1: ..#STOPPEDWORD), "string")
        Do tRow.%Set("after", $Select(tRunning: ..#STOPPEDWORD, 1: ..#RUNNINGWORD), "string")
        Do pRows.%Push(tRow)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
