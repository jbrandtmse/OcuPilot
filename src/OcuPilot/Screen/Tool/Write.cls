/// <p>The base every write tool extends (AD-6, AD-40). A write tool does one thing: it mints a
/// proposal. It reads the target fresh, merges its resolved arguments over that object, stores the
/// complete payload with its diff, its fingerprint and a single-use token, and answers the model
/// the proposal's id and what changed.</p>
/// <p><b>The model can reach the minting path and nothing else.</b> <method>View</method> is
/// <code>Final</code> and calls <class>OcuPilot.Kernel.Proposal.Mint</class>; no method here, and
/// no method a subclass may add, names <class>OcuPilot.Kernel.Proposal.Write</class>. Applying a
/// proposal is claimed by a user-originated confirm request, which is not a tool and is not in the
/// registry.</p>
/// <p><b>Nothing here writes to the instance.</b> The payload is assembled and stored; Story 5.3
/// sends it inside the atomic transition a confirm claims.</p>
/// <p><b>The input schema is derived, not transcribed</b> (AD-3). Its properties are the classified
/// rows of this tool's <class>OcuPilot.Screen.Tool.ToolFields</class> entry: every row the reviewed
/// classification calls <code>ordinary</code>, minus the subtrees the tool excludes by name and
/// minus the fields the descriptor declares secret. A row classified anything but
/// <code>ordinary</code> never reaches the model, which is what makes the generator's fail-closed
/// default (an unnamed row is <code>secret</code>) a real bound rather than a label.</p>
/// <p>A concrete tool declares its <parameter>TOOLNAME</parameter>,
/// <parameter>DESCRIPTORCLASS</parameter> and <parameter>DESCRIPTION</parameter>, answers
/// <method>Endpoint</method> and <method>SettableFields</method>, and adds the pairs its write
/// requires beyond its screen's own. An <b>action-style</b> write declares its own request types
/// and sends no body (AD-51): <parameter>READTYPE</parameter>, <parameter>WRITETYPE</parameter>,
/// <parameter>SENDSBODY</parameter>, <method>StateDiff</method> and the fingerprint subject
/// <parameter>FINGERPRINTSUBJECT</parameter> names, which are the merge write's own behavior by
/// default. Every write also declares the <b>port</b> it reaches its target through
/// (<parameter>PORTCLASS</parameter>, AD-52), which defaults to the admin port.</p>
Class OcuPilot.Screen.Tool.Write Extends OcuPilot.Screen.Tool.Base [ Abstract ]
{

Parameter KIND = "write";

/// <p>A write is decided on the instance, never in the browser (AD-11 rule 3); the registry
/// refuses the other combination outright.</p>
Parameter FULFILMENT = "instance";

/// <p>The screen this tool writes for. A concrete tool names its descriptor class here, the idiom
/// <class>OcuPilot.Screen.Tool.ErrorRead</class> established.</p>
Parameter DESCRIPTORCLASS = "";

/// <p>The generated field lists every write tool's schema is derived from.</p>
Parameter TOOLFIELDSCLASS = "OcuPilot.Screen.Tool.ToolFields";

/// <p>Whether this tool's write is <b>destructive</b>: a change whose effect the user cannot
/// simply undo by proposing the opposite, and which the card therefore draws in the destructive
/// treatment (DESIGN.md's proposal-card rows). <code>0</code> here; a concrete tool that is one
/// declares <code>1</code> and says why.</p>
/// <p><b>The declaration is the tool's, not a kernel list naming tools.</b> A second constant
/// enumerating destructive tool names would have to be kept in step with the tool set by hand, and
/// a tool added outside it would ship undeclared -- so the tool that knows its own effect states
/// it, and <class>OcuPilot.Kernel.Proposal.Mint</class> reads it through
/// <method>Destructive</method>.</p>
Parameter DESTRUCTIVE As BOOLEAN = 0;

/// <p>The admin request type the mint's fresh read and the confirm's fingerprint re-read are made
/// with. <code>GET</code> here, AD-36's single-object read; a tool whose state is not in that
/// answer declares the type that carries it (AD-51).</p>
Parameter READTYPE = "GET";

/// <p>The admin request type the confirmed write is issued with. <code>PUT</code> here, the merge
/// write every body-taking tool makes; an action-style tool declares the vendor's own request type
/// instead (AD-51).</p>
Parameter WRITETYPE = "PUT";

/// <p>Whether the confirmed write carries a body. <code>1</code> here; an action-style tool whose
/// vendor request type reads no body declares <code>0</code>, and then nothing is sent, nothing is
/// disclosed as unchanged, and the ledger records no field names (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 1;

/// <p>The one field name an action-style write's state row carries, or <code>""</code> for a write
/// that sends a body. <code>""</code> here.</p>
/// <p>A state row's <code>field</code> is the product's <b>label</b> for the state the action
/// moves, not a property of the payload, so the prohibited set must not read it as one: a label
/// that happens to spell a property the endpoint also answers would otherwise be compared against
/// that property's live value (AD-10, AD-51).</p>
Parameter STATEFIELD = "";

/// <p>The <b>subject</b> the proposal's fingerprint covers, as comma-separated top-level names of
/// this tool's own fresh read, or <code>""</code> for a write whose fingerprint is the descriptor's
/// exclusions over the whole payload. <code>""</code> here, which is every merge write (AD-6).</p>
/// <p><b>Only an action-style write declares one</b> (AD-51 as amended 2026-09-22). It sends no
/// payload, so there is no property set to exclude from, and a digest over the whole of a live
/// read refuses every confirm whose target moved a counter -- hardest for exactly the targets such
/// an action exists to act on. The subject is what the user reviewed: this target, in this state.</p>
/// <p><b>Adequacy is structural.</b> Every action-style write declares one; a declared subject
/// carries <parameter>PRECONDITIONFIELD</parameter>, names nothing the descriptor's
/// <code>fingerprintExcludes</code> also names, and every name in it is one the screen's own
/// declaration knows <b>or</b> one <parameter>READANSWERS</parameter> declares;
/// <method>OcuPilot.Screen.Registry.FingerprintSubjectProblem</method> refuses anything else at
/// registration, through the extraction that validates <code>fingerprintExcludes</code>. The
/// target identity is <b>not</b> required and may be named: the fingerprint asks whether the
/// reviewed state moved, and which object this is is the proposal's <code>TargetRef</code>
/// (AD-13, AD-51 as amended 2026-09-22).</p>
/// <p>A screen's declared read and this tool's own <parameter>READTYPE</parameter> read are not the
/// same set: where a list and a single-object read spell a field differently, the name the mint
/// projects is the tool read's, so a tool whose two sets differ declares its own through
/// <parameter>READANSWERS</parameter> rather than relying on the screen's spelling.</p>
Parameter FINGERPRINTSUBJECT = "";

/// <p>The read field this tool's own precondition reads -- the field whose movement between the
/// mint and the confirm invalidates the reviewed intent -- or <code>""</code> for a write with no
/// precondition of its own. <code>""</code> here.</p>
/// <p>It is the name a declared <parameter>FINGERPRINTSUBJECT</parameter> must carry: a subject
/// without it would let a confirm succeed against a target somebody else had already moved into
/// the state the action was going to move it to (AD-51).</p>
Parameter PRECONDITIONFIELD = "";

/// <p>The port this tool reaches its target through (AD-52). <code>OcuPilot.Port.AdminPort</code>
/// here, which is every write whose target is an admin API endpoint; a tool whose target lives
/// behind another port names it.</p>
/// <p><b>The declaration is the tool's, because the port is a property of the target rather than of
/// the screen.</b> The mint's fresh read, the confirm's fingerprint re-read, the prohibited set's
/// live read and the write itself all resolve through this one declaration, and nothing else about
/// the write path changes -- a port is where the target lives, never a lighter path to it.</p>
Parameter PORTCLASS = "OcuPilot.Port.AdminPort";

/// <p>The AD-14 action a confirmed write of this tool performs, which the change event carries and
/// a screen showing the entity type decides what to do with. <code>updated</code> here, which every
/// write against an object that already exists performs; a tool that declares
/// <parameter>CREATES</parameter> declares <code>created</code> beside it (AD-54).</p>
/// <p><b>It is the tool's declaration, not the client's inference.</b> The action vocabulary is the
/// kernel's closed set (AD-14), and a client deriving "this looked like a delete" from the shape of
/// a diff would be authoring the one field a screen routes on. A tool whose write removes its
/// target declares <code>deleted</code>.</p>
Parameter CHANGEACTION = "updated";

/// <p>Whether this tool <b>creates</b> its target rather than changing one that already exists
/// (AD-54). <code>0</code> here, which is every write the product shipped before Epic 8.</p>
/// <p>A create changes exactly two things about the write path and nothing else. The mint's fresh
/// read keeps its place through the same declared port (<parameter>PORTCLASS</parameter>), the same
/// endpoint and the same <parameter>READTYPE</parameter>, and <b>inverts its acceptance</b>: the
/// target must be absent, so a 404 is the success precondition and a present target refuses the
/// mint. And the fingerprint covers the target's <b>absence</b> under AD-13's canonical spelling
/// rather than a property set, because for a create the property set is entirely the caller's own
/// arguments and nothing about it can move, while what must be protected is that the name is still
/// free.</p>
/// <p><b>The payload is composed, not merged</b> (AD-4 has no subject here): every field the
/// arguments supply is a diff row and the unchanged count is zero. A tool that declares this also
/// declares <parameter>CHANGEACTION</parameter> <code>created</code>, and its permitted field set
/// is <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method>'s rather than
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method>'s.</p>
Parameter CREATES As BOOLEAN = 0;

/// <p>The screen row actions (AD-5) this tool carries out, comma-separated, or <code>""</code> for
/// a tool no screen action reaches. <code>""</code> here.</p>
/// <p>Each entry is an action id the descriptor declares, optionally followed by the one argument
/// that action sends: <code>&lt;id&gt;</code>, or <code>&lt;id&gt;=&lt;field&gt;:&lt;value&gt;</code>
/// where <var>field</var> is one of this tool's own settable fields. An action-style write takes
/// the bare form, because it sends no body at all (AD-51).</p>
/// <p><b>The declaration is the tool's, not the descriptor's</b> (AD-53). A descriptor declares
/// that a row carries an action and what self-protection rule explains its refusal; <i>which</i>
/// operation carries it out is a property of the write, beside the port it reaches its target
/// through (<parameter>PORTCLASS</parameter>), the request type it issues
/// (<parameter>WRITETYPE</parameter>) and the change event it publishes
/// (<parameter>CHANGEACTION</parameter>). One tool may serve two actions -- enable and disable are
/// one merge write over one field -- which a per-descriptor map could not express without naming
/// the field twice.</p>
Parameter SCREENACTIONS = "";

/// <p>The top-level names this tool's own <parameter>READTYPE</parameter> read answers,
/// comma-separated, or <code>""</code> where the screen's declared read is the whole record of
/// them.</p>
/// <p><b>It exists because a screen's declared read and a tool's own read are not the same set</b>
/// (DW-1475). The registration guard over <parameter>FINGERPRINTSUBJECT</parameter> checks every
/// declared name against what the screen knows, and a screen that declares no <code>read</code> at
/// all -- a drill-down whose levels are three column sets -- knows nothing, so every name its write
/// tool could declare would be refused at registration. Declaring the read's own names here gives
/// that guard something real to validate against, through the one extraction
/// <method>OcuPilot.Screen.Registry.DeclaredNames</method> already answers
/// <code>fingerprintExcludes</code> with.</p>
Parameter READANSWERS = "";

/// <p>The query parameter this tool's fresh read sends the target's id under, or <code>""</code>
/// for <method>IdParam</method>, which is every tool whose read and write identify a target the
/// same way (AD-51).</p>
Parameter READIDPARAM = "";

/// <p>The row key a <b>list-type</b> fresh read is filtered by, or <code>""</code> for a read that
/// answers one object (AD-51 as amended 2026-09-23). When set, the read answers an array and the
/// target is the one row whose member of this name equals the id, compared without regard to case;
/// no such row reads as absent (404).</p>
Parameter READROWKEY = "";

/// <p>The declared secret arguments an action-style write sends as its <b>only</b> body,
/// comma-separated, or <code>""</code> for a write whose body is a merge or nothing (AD-56 (i)).
/// <code>""</code> here, which is every write but a password change.</p>
/// <p>Each name must also be one the descriptor's <code>secretArguments</code> declares:
/// <method>OcuPilot.Kernel.Proposal.Operation.SecretBody</method> carries a name only when both
/// lists hold it, so the confirm channel and the screen's value channel stay the one declaration
/// AD-6 closes. The vendor's own spelling of the body key is the port's wire fact, not this
/// list's (<parameter>OcuPilot.Port.AdminPort.RENAMEDTYPES</parameter>).</p>
Parameter SECRETBODY = "";

/// <p>The values a screen action sends this tool beyond its static argument, comma-separated
/// <code>&lt;action&gt;=&lt;name&gt;[:&lt;name&gt;...]</code> entries, or <code>""</code>
/// (AD-56 (ii)). <code>""</code> here, so every shipped action admits no value.</p>
/// <p><b>A value name is a declaration, never a field.</b> The route admits a request's
/// <code>values</code> only under the names its action declares here and refuses any other key; a
/// name that is a declared secret goes to <method>OcuPilot.Kernel.Proposal.Operation.SecretBody</method>
/// and nowhere else, and the rest are handed to <method>ScreenActionDelta</method>, which turns
/// them into this tool's own settable arguments over the fresh read.</p>
Parameter SCREENVALUES = "";

/// <p>This tool's own class, which <method>View</method> hands the mint so
/// <method>ReadType</method>, <method>SendsBody</method> and <method>StateDiff</method> are read
/// from the concrete tool rather than from this base (AD-51).</p>
/// <p><method>View</method> is <code>Final</code> and every call site is
/// <code>##class(&lt;tool&gt;).View(...)</code>, so the concrete class is the one this answers --
/// the same resolution <code>..#TOOLNAME</code> already relies on.
/// <method>OcuPilot.Test.ToolWrite.TestTheTaskResumeToolIsAnActionWriteOverTheScreensOwnPairs</method>
/// pins it against that tool's own name.</p>
ClassMethod ToolClass() As %String
{
    Quit $ClassName()
}

/// <p><parameter>READTYPE</parameter>, for the mint and the confirm, which resolve a tool by name
/// and hold only its class.</p>
ClassMethod ReadType() As %String
{
    Quit ..#READTYPE
}

/// <p>The query parameter the fresh read sends the id under: <parameter>READIDPARAM</parameter>,
/// or <method>IdParam</method> where it declares none.</p>
ClassMethod ReadIdParam() As %String
{
    If ..#READIDPARAM '= "" Quit ..#READIDPARAM
    Quit ..IdParam()
}

/// <p><parameter>READROWKEY</parameter>, for the one helper every fresh read goes through
/// (<method>OcuPilot.Kernel.Proposal.Operation.ReadTarget</method>).</p>
ClassMethod ReadRowKey() As %String
{
    Quit ..#READROWKEY
}

/// <p>What happens once this tool's write has read OK, through the same port, for the target
/// <var>pIdValue</var> whose fresh read before the write was <var>pFresh</var>. An error status
/// carries <var>pHttpStatus</var> and <var>pFault</var>, which the caller answers with; the write
/// itself has already been applied.</p>
/// <p><b>Caller contract:</b> called by <method>OcuPilot.Kernel.Proposal.Operation.ApplyAt</method>
/// alone, for both callers of the operation (AD-53). Nothing here by default.</p>
ClassMethod AfterWrite(pPort As %String, pEndpoint As %String, pIdParam As %String, pIdValue As %String, pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Quit $$$OK
}

/// <p><parameter>WRITETYPE</parameter>, read at the one site that issues the write.</p>
ClassMethod WriteType() As %String
{
    Quit ..#WRITETYPE
}

/// <p><parameter>PORTCLASS</parameter> (AD-52), read by the mint, the confirm and the prohibited
/// set, each of which resolves a tool by name and holds only its class.</p>
ClassMethod PortClass() As %String
{
    Quit ..#PORTCLASS
}

/// <p><parameter>CHANGEACTION</parameter>, read by the confirm, which resolves a tool by name and
/// holds only its class (AD-14).</p>
ClassMethod ChangeAction() As %String
{
    Quit ..#CHANGEACTION
}

/// <p><parameter>CREATES</parameter> as a boolean (AD-54), read by the mint, the confirm and the
/// prohibited set, each of which resolves a tool by name and holds only its class.</p>
ClassMethod Creates() As %Boolean
{
    Quit ''..#CREATES
}

/// <p>Add to <var>pPayload</var> the fields this tool's <b>server</b> derives from the caller's
/// own arguments, immediately before the port is invoked.</p>
/// <p><b>Caller contract:</b> called once per write, on the body the write will actually send,
/// after the prohibited set has reached its verdict over the fields the caller supplied and after
/// a declared secret has been merged in. It reads nothing but <var>pPayload</var> and writes
/// nothing else, and it never touches a field <method>SettableFields</method> admits -- a derived
/// field is one no caller may set, so it is outside the diff the user reviewed and outside the set
/// the prohibited predicates sweep.</p>
/// <p>Empty here, so every write that shipped before Epic 8 sends exactly its stored payload. The
/// web-application create is the first tool with one: <code>Path</code> is derived from
/// <code>WSGIAppLocation</code> for a WSGI or ASGI application and left alone otherwise, because
/// <method>Security.Applications.Create</method> creates the directory a CSP application names and
/// a caller-supplied path is a filesystem path this product never accepts (AD-21).</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
}

/// <p>The composed payload and diff of a <b>create</b> (AD-54) from the caller's arguments
/// <var>pArgs</var>, in <method>OcuPilot.Kernel.Proposal.Mint.Compose</method>'s contract: one
/// payload property per supplied settable field, one diff row per supplied field, and
/// <var>pUnchanged</var> the payload properties no diff row names.</p>
/// <p><b>Caller contract:</b> the mint calls it once for a tool that declares
/// <parameter>CREATES</parameter>, after the absence read and before the tool's own field rules.
/// The kernel's <method>OcuPilot.Kernel.Proposal.Mint.Compose</method> here, so every create that
/// shipped before Story 9.7 composes exactly as it did; a create whose endpoint requires a complete
/// body, or whose arguments include an object, composes its own.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Compose(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

/// <p>The merged payload and diff of a <b>change</b> (AD-4) from the fresh read <var>pFresh</var> and
/// the caller's arguments <var>pArgs</var>, in <method>OcuPilot.Kernel.Proposal.Mint.Merge</method>'s
/// contract.</p>
/// <p><b>Caller contract:</b> called by the mint, by the confirm's fingerprint re-merge and by a
/// screen's Save, so the three take one payload and one digest. The kernel's
/// <method>OcuPilot.Kernel.Proposal.Mint.Merge</method> here, so every change that shipped before
/// Story 9.8 merges exactly as it did; a tool whose object argument merges member by member merges its
/// own.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Quit ##class(OcuPilot.Kernel.Proposal.Mint).Merge(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

/// <p>The id the instance allocated for the target this tool's confirmed write <var>pWritten</var>
/// created, or <code>""</code> (AD-14). The confirm's answer carries it as <code>createdId</code>,
/// and the client publishes it as the change event's id in place of the proposal's target id.</p>
/// <p><code>""</code> here: every create before Story 9.7 names its target by the id the caller
/// chose, so the target's own id is the created one.</p>
ClassMethod CreatedId(pWritten) As %String
{
    Quit ""
}

/// <p>The row-action ids <parameter>SCREENACTIONS</parameter> names, as a <class>%List</class>.</p>
ClassMethod ScreenActionIds() As %List
{
    Set tIds = ""
    For tI = 1:1:$Length(..#SCREENACTIONS, ",") {
        Set tId = $ZStrip($Piece($Piece(..#SCREENACTIONS, ",", tI), "=", 1), "<>W")
        If (tId '= "") && '$ListFind(tIds, tId) Set tIds = tIds _ $ListBuild(tId)
    }
    Quit tIds
}

/// <p>The arguments a screen action <var>pActionId</var> sends this tool, as a
/// <class>%DynamicObject</class>, with <var>pServes</var> 0 when this tool does not carry that
/// action at all.</p>
/// <p><b>Caller contract:</b> <class>OcuPilot.Api.ScreenAction</class> calls it once per request
/// and merges the answer over the fresh read exactly as the mint merges the agent's own arguments
/// (AD-4), so the two callers of this operation send one body computed one way. An action that
/// names no field answers <code>{}</code>, which is every action-style write (AD-51).</p>
/// <p>A value spelled <code>true</code> or <code>false</code> is carried as a boolean and a numeric
/// one as a number, so the merge's own type check reads the declaration as the instance holds the
/// field rather than as a string spelling of it.</p>
ClassMethod ScreenActionArguments(pActionId As %String, Output pServes As %Boolean) As %DynamicObject
{
    Set pServes = 0
    Set tArgs = {}
    If pActionId = "" Quit tArgs
    For tI = 1:1:$Length(..#SCREENACTIONS, ",") {
        Set tEntry = $ZStrip($Piece(..#SCREENACTIONS, ",", tI), "<>W")
        If $Piece(tEntry, "=", 1) '= pActionId Continue
        Set pServes = 1
        Set tAssignment = $Piece(tEntry, "=", 2, *)
        If tAssignment = "" Quit
        Set tField = $Piece(tAssignment, ":", 1)
        Set tValue = $Piece(tAssignment, ":", 2, *)
        If tField = "" Quit
        If (tValue = "true") || (tValue = "false") {
            Do tArgs.%Set(tField, (tValue = "true"), "boolean")
        } ElseIf $IsValidNum(tValue) {
            Do tArgs.%Set(tField, +tValue, "number")
        } Else {
            Do tArgs.%Set(tField, tValue, "string")
        }
        Quit
    }
    Quit tArgs
}

/// <p><parameter>READANSWERS</parameter> as a <class>%List</class>, for the registration guard.</p>
ClassMethod ReadAnswers() As %List
{
    Set tNames = ""
    For tI = 1:1:$Length(..#READANSWERS, ",") {
        Set tName = $ZStrip($Piece(..#READANSWERS, ",", tI), "<>W")
        If (tName '= "") && '$ListFind(tNames, tName) Set tNames = tNames _ $ListBuild(tName)
    }
    Quit tNames
}

/// <p>Add to <var>pQuery</var> whatever this tool's port needs beyond the identifying parameter,
/// given the <b>stored</b> payload <var>pPayload</var> the proposal was fingerprinted over.</p>
/// <p><b>Caller contract:</b> <class>OcuPilot.Kernel.Proposal.Confirm</class> calls it twice, both
/// inside the transition -- once before the fingerprint re-read and once before the write -- after
/// the identifying parameter is set and before the port is invoked. It reads nothing but
/// <var>pPayload</var>, writes nothing, and never replaces the identifying entry.</p>
/// <p>Empty here, so every write that ships against an admin endpoint is unchanged: the vendor
/// identifies a target by one query parameter, and both calls pass the same query the mint used.</p>
/// <p><b>A tool whose port addresses a set rather than an object names that set here</b> -- the
/// application-error delete, whose subject is the enumerated id set the user reviewed. Both calls
/// matter and they do different work. On the <b>write</b> it is what makes the confirm remove
/// exactly those ids rather than re-running its own selection. On the <b>re-read</b> it is what
/// makes the digest a question about the reviewed set alone: the port answers which of those ids
/// still exist, so an id another party removed changes the digest while one logged after the
/// proposal -- which is in no stored set -- does not. Without it the re-read would enumerate afresh
/// and every error the instance logged in the window would refuse the confirm, which is AD-48's
/// residue clause read backwards (AD-48, AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
}

/// <p><parameter>SENDSBODY</parameter> as a boolean.</p>
ClassMethod SendsBody() As %Boolean
{
    Quit ''..#SENDSBODY
}

/// <p><parameter>STATEFIELD</parameter>, read by <class>OcuPilot.Kernel.Proposal.Prohibited</class>
/// so it can tell a state row's label from a payload field.</p>
ClassMethod StateField() As %String
{
    Quit ..#STATEFIELD
}

/// <p><parameter>FINGERPRINTSUBJECT</parameter> as a <class>%List</class>, for the mint and the
/// confirm, which resolve a tool by name and hold only its class (AD-51).</p>
ClassMethod FingerprintSubject() As %List
{
    Set tNames = ""
    For tI = 1:1:$Length(..#FINGERPRINTSUBJECT, ",") {
        Set tName = $ZStrip($Piece(..#FINGERPRINTSUBJECT, ",", tI), "<>W")
        If (tName '= "") && '$ListFind(tNames, tName) Set tNames = tNames _ $ListBuild(tName)
    }
    Quit tNames
}

/// <p><parameter>PRECONDITIONFIELD</parameter>, read by the registration-time guard that holds a
/// declared subject adequate.</p>
ClassMethod PreconditionField() As %String
{
    Quit ..#PRECONDITIONFIELD
}

/// <p>The <b>state</b> rows this tool's proposal shows, given the fresh read <var>pFresh</var>:
/// one <code>{field, before, after}</code> per state the action moves, in <var>pRows</var>, with
/// <var>pProblem</var> naming why the target is not in the state the action moves it out of.</p>
/// <p><b>Caller contract:</b> <class>OcuPilot.Kernel.Proposal.Mint</class> calls it once, after the
/// fresh read and before anything is stored, and refuses the mint when <var>pProblem</var> is
/// non-empty. It reads nothing but <var>pFresh</var> and writes nothing.</p>
/// <p>Empty here. A merge write's diff is the fields its arguments move
/// (<method>OcuPilot.Kernel.Proposal.Mint.Merge</method>); an action-style write sends no body, so
/// the card's rows can only come from the read, and the tool is what knows which state its action
/// moves (AD-51).</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The class a minted proposal is built by. Overridable so a test can observe what a tool
/// asked for; production never overrides it.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Mint"
}

/// <p><parameter>DESTRUCTIVE</parameter> as a boolean, for the mint that carries it onto the wire.
/// A method rather than a bare parameter read because the mint resolves the tool by name and holds
/// only its class.</p>
ClassMethod Destructive() As %Boolean
{
    Quit ''..#DESTRUCTIVE
}

/// <p>The admin endpoint this tool's target is read from and written to.</p>
ClassMethod Endpoint() As %String [ Abstract ]
{
    Quit ""
}

/// <p>The payload field names the merge may set, as a <class>%List</class>. Derived from the
/// tool's own classified field list (<method>AdmittedFields</method>), never transcribed.</p>
ClassMethod SettableFields() As %List [ Abstract ]
{
    Quit ""
}

/// <p>The input property that names the target. <code>Name</code> for every admin endpoint keyed
/// by a name; a tool whose endpoint identifies a target differently overrides it.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

/// <p>The query parameter this endpoint's <code>GET</code> identifies a target by, which is the
/// vendor's own spelling and need not match <method>IdArgument</method>.</p>
ClassMethod IdParam() As %String
{
    Quit "name"
}

/// <p>The top-level field names this tool never admits, whatever their classification, as a
/// <class>%List</class>. Empty here; a tool naming a subtree AD-10 forbids declares it and says
/// why.</p>
ClassMethod ExcludedFields() As %List
{
    Quit ""
}

/// <p>The <b>only</b> top-level field names this tool admits, as a <class>%List</class>;
/// <code>""</code> means no positive restriction and every <code>ordinary</code> top-level field of
/// the entry is admitted.</p>
/// <p>Empty here. A tool whose entity type has reviewed predicates for a few of its properties
/// names those few, so a vendor property a later IRIS build adds to the endpoint's own template is
/// absent from the advertised schema until somebody reviews it -- which is AD-10's "absent from the
/// tool set" for the fields the prohibited set refuses by shape rather than by name.</p>
ClassMethod PermittedFields() As %List
{
    Quit ""
}

/// <p>What <parameter>DESCRIPTORCLASS</parameter> declares secret (AD-3, AD-6), which is what the
/// confirm channel is closed to all but. <var>pDeclared</var> is always 1: a write tool's
/// classification is its descriptor's declaration, and an absent list is an empty one.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    If ..#DESCRIPTORCLASS = "" Quit ""
    Quit $ClassMethod(..#DESCRIPTORCLASS, "SecretArguments")
}

/// <p><parameter>SECRETBODY</parameter> as a <class>%List</class> (AD-56).</p>
ClassMethod SecretBodyNames() As %List
{
    Set tNames = ""
    For tI = 1:1:$Length(..#SECRETBODY, ",") {
        Set tName = $ZStrip($Piece(..#SECRETBODY, ",", tI), "<>W")
        If (tName '= "") && '$ListFind(tNames, tName) Set tNames = tNames _ $ListBuild(tName)
    }
    Quit tNames
}

/// <p>The value names <parameter>SCREENVALUES</parameter> declares for screen action
/// <var>pActionId</var>, as a <class>%List</class>; <code>""</code> for an action that admits
/// none.</p>
ClassMethod ScreenActionValueNames(pActionId As %String) As %List
{
    Set tNames = ""
    If pActionId = "" Quit tNames
    For tI = 1:1:$Length(..#SCREENVALUES, ",") {
        Set tEntry = $ZStrip($Piece(..#SCREENVALUES, ",", tI), "<>W")
        If $Piece(tEntry, "=", 1) '= pActionId Continue
        Set tSpec = $Piece(tEntry, "=", 2, *)
        For tJ = 1:1:$Length(tSpec, ":") {
            Set tName = $ZStrip($Piece(tSpec, ":", tJ), "<>W")
            If (tName '= "") && '$ListFind(tNames, tName) Set tNames = tNames _ $ListBuild(tName)
        }
    }
    Quit tNames
}

/// <p>The arguments screen action <var>pActionId</var> sends this tool, given the declared
/// non-secret values <var>pValues</var> and the fresh read <var>pFresh</var>, in <var>pArgs</var>;
/// <var>pProblem</var> names why the values cannot be applied to this target (AD-56 (ii)).</p>
/// <p><b>Caller contract:</b> <class>OcuPilot.Api.ScreenAction</class> calls it once, after the
/// fresh read, and holds every key of <var>pArgs</var> to <method>SettableFields</method> exactly
/// as it holds the static arguments; a non-empty <var>pProblem</var> is refused 400
/// <code>TOOL.ARGUMENTS</code> with nothing written. It writes nothing; an override may read through
/// the tool's own port to resolve a value.</p>
/// <p>The default answers <method>ScreenActionArguments</method>, so every tool that declares no
/// value is unchanged. A tool whose value changes a list declares the delta here -- over the fresh
/// read, never as a list the client computed -- so a concurrent change to another member
/// survives.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set pArgs = ..ScreenActionArguments(pActionId, .tServes)
    Quit $$$OK
}

/// <p>The rows of this tool's <class>OcuPilot.Screen.Tool.ToolFields</class> entry that a schema
/// may admit, as <code>pRows(n) = $ListBuild(field, templateType, isArray)</code> in the entry's
/// own order, with the count in <code>pRows</code>.</p>
/// <p>A tool that sends no body (<method>SendsBody</method>) answers no rows and no error: its
/// field list is empty by derivation rather than by an entry nobody wrote (AD-3, AD-51).</p>
/// <p>A row is admitted when its class is <code>ordinary</code>, its path is a top-level literal
/// or a top-level array of literals, its name is outside <method>ExcludedFields</method>, its name
/// is inside <method>PermittedFields</method> where that list is not empty, and the descriptor does
/// not declare it secret. A deeper path -- a member of an object, an element of an array of objects
/// -- is not admitted at all: the advertised schema subset is flat, so a nested path could only be
/// admitted by a shape the validator does not enforce.</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 0
    Set tSC = $$$OK
    Try {
        ; AD-51: a write that sends no body admits no field, and its endpoint's own template
        ; describes the request it does not make. There is nothing to derive, so an absent entry
        ; is the right answer rather than a failure -- which is what keeps such a tool's schema
        ; the identifying property and the agent's own words.
        If '..SendsBody() Quit
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen(..#TOOLFIELDSCLASS, "Tools", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the generated tool field lists are missing from " _ ..#TOOLFIELDSCLASS)
            Quit
        }
        Do tXData.Data.Rewind()
        Set tTools = ##class(%DynamicAbstractObject).%FromJSON(tXData.Data)
        Set tXData = ""
        Set tEntry = ""
        If $IsObject(tTools) Set tEntry = tTools.%Get(..#TOOLNAME)
        If '$IsObject(tEntry) || (tEntry.%GetTypeOf("fields") '= "array") {
            Set tSC = $$$ERROR($$$GeneralError, ..#TOOLNAME _ " has no entry in " _ ..#TOOLFIELDSCLASS)
            Quit
        }
        Set tExcluded = ..ExcludedFields()
        Set tPermitted = ..PermittedFields()
        Set tSecrets = ..SecretArguments(..#DESCRIPTORCLASS, .tDeclared)
        Set tIterator = tEntry.%Get("fields").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tField) {
            If '$IsObject(tField) Continue
            If tField.%Get("class") '= "ordinary" Continue
            If tField.%Get("shape") '= "literal" Continue
            Set tPath = tField.%Get("path")
            If tPath [ "." Continue
            Set tIsArray = ($Extract(tPath, *-1, *) = "[]")
            Set tName = $Select(tIsArray: $Extract(tPath, 1, *-2), 1: tPath)
            If tName [ "[" Continue
            If $ListFind(tExcluded, tName) Continue
            If (tPermitted '= "") && '$ListFind(tPermitted, tName) Continue
            If $ListFind(tSecrets, tName) Continue
            Set pRows($Increment(pRows)) = $ListBuild(tName, tField.%Get("templateType"), tIsArray)
        }
    } Catch ex {
        Kill pRows
        Set pRows = 0
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The names <method>FieldRows</method> admits, as a <class>%List</class> -- what a concrete
/// tool answers from <method>SettableFields</method>. Empty when the entry cannot be read, which
/// is what makes an unreadable field list a tool that changes nothing rather than one that changes
/// anything.</p>
ClassMethod AdmittedFields() As %List
{
    Set tFields = ""
    Set tSC = ..FieldRows(.tRows)
    If $$$ISERR(tSC) Quit ""
    For tI = 1:1:+$Get(tRows) {
        Set tFields = tFields _ $ListBuild($List(tRows(tI), 1))
    }
    Quit tFields
}

/// <p>The tool's input schema: the identifying property, required; one property per admitted
/// field; and the agent's own words, all optional. Closed with
/// <code>additionalProperties: false</code>, so a field the classification did not admit -- a
/// privilege subtree among them -- is refused as an unknown argument rather than ignored.</p>
/// <p><var>pDescriptor</var> is ignored: a write tool has a class of its own and derives its
/// schema from its own field-list entry.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = {"type": "object", "properties": {}, "required": [], "additionalProperties": false}
    Set tProperties = tSchema.%Get("properties")
    ; AD-54: a create's target is one the instance does NOT hold, so the identifying property's own
    ; description is inverted with the read's acceptance rather than left saying the opposite.
    Set tIdDescription = "The target this write is about, exactly as this instance's own list reports it. A target it does not report is refused."
    Set tValueDescription = "The new value for this field. Omit it to leave the field as the instance holds it."
    Set tListDescription = "The new value for this field, replacing the whole list."
    If ..Creates() {
        Set tIdDescription = "The name the new object will take. A name this instance already holds is refused, so check the list first."
        Set tValueDescription = "The value this create sets. Omit it to leave the field at the instance's own default."
        Set tListDescription = "The whole list this create sets."
    }
    Do tProperties.%Set(..IdArgument(), {"type": "string", "description": (tIdDescription)})
    Do tSchema.%Get("required").%Push(..IdArgument())
    Set tSC = ..FieldRows(.tRows)
    If $$$ISERR(tSC) Quit tSchema
    For tI = 1:1:+$Get(tRows) {
        Set tName = $List(tRows(tI), 1)
        If tName = ..IdArgument() Continue
        Set tType = ..JsonType($List(tRows(tI), 2))
        If $List(tRows(tI), 3) {
            Set tProperty = {"type": "array", "description": (tListDescription)}
            Do tProperty.%Set("items", {"type": (tType)})
        } Else {
            Set tProperty = {"description": (tValueDescription)}
            Do tProperty.%Set("type", tType, "string")
        }
        Do tProperties.%Set(tName, tProperty)
    }
    Do tProperties.%Set("rationale", {"type": "string", "description": "Why this change is being proposed, in one sentence, shown to the user above the diff."})
    Do tProperties.%Set("expectedImpact", {"type": "string", "description": "What the user should expect to happen once this is confirmed, in one sentence."})
    Do tProperties.%Set("reverse", {"type": "string", "description": "How to undo this change, in one sentence. Omit it where no reversal exists."})
    Quit tSchema
}

/// <p>The result a mint answers.</p>
ClassMethod ResultSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit {
        "type": "object",
        "properties": {
            "proposalId": {"type": "string", "description": "The proposal's identifier. Report it; the user confirms it, and this turn never applies it."},
            "target": {"type": "object", "description": "The scoped target: its entity type, its scope and its id."},
            "tool": {"type": "string", "description": "The tool that minted the proposal."},
            "changed": {"type": "array", "items": {"type": "object"}, "description": "One object per changed field, carrying the field name, the value before and the value after."},
            "unchangedCount": {"type": "integer", "description": "How many of the target's other properties the write sends unchanged."},
            "expiresAt": {"type": "string", "description": "When the proposal stops being confirmable, ISO-8601 UTC."}
        },
        "required": ["proposalId", "target", "tool", "changed", "unchangedCount", "expiresAt"],
        "additionalProperties": false
    }
}

/// <p>Mint the proposal this call describes. <var>pArgs</var> is validated against
/// <method>InputSchema</method> before anything is read; a refusal is 400
/// <code>TOOL.ARGUMENTS</code> and no port is called. <var>pContextCap</var> is ignored: a
/// proposal carries a diff, not rows.</p>
/// <p><b>Final, and the only method the model reaches.</b> The turn and the conversation come from
/// <class>OcuPilot.Kernel.Proposal.Caller</class>, which the turn job stashed; the user is the
/// process's own, because a tool runs as the caller (AD-1).</p>
ClassMethod View(pDescriptor As %String, pArgs As %DynamicAbstractObject, pContextCap As %Integer, Output pResult As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Final ]
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
        Set tId = tArgs.%Get(..IdArgument())
        If tId = "" {
            Set tSC = ..ArgumentsRefusal("'" _ ..IdArgument() _ "' names the target and cannot be empty", .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = $ClassMethod(..MintClass(), "Mint", ..#DESCRIPTORCLASS, ..#TOOLNAME, $Username, ##class(OcuPilot.Kernel.Proposal.Caller).ConvKey(), ##class(OcuPilot.Kernel.Proposal.Caller).TurnKey(), tArgs, ..LimitsClass(), .pResult, .pHttpStatus, .pFault, ..Endpoint(), ..IdParam(), tId, ..IdArgument(), ..SettableFields(), ..ToolClass())
    } Catch ex {
        Set pResult = ""
        Set tSC = ..InternalRefusal("the write tool failed: " _ ex.DisplayString(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>The class the proposal's expiry and its text caps are read from. Overridable so a test
/// narrows the window; production never overrides it.</p>
ClassMethod LimitsClass() As %String
{
    Quit "OcuPilot.Kernel.Agent.Limits"
}

/// <p>The JSON type a derived field's template placeholder implies. A placeholder's scalar type is
/// information rather than contract (AD-3) -- this instance answers a number for five
/// <code>WebApp.App</code> fields whose template shows a string -- so the merge compares values in
/// their rendered form and a string spelling of a number changes nothing.</p>
ClassMethod JsonType(pTemplateType As %String) As %String [ Private ]
{
    If pTemplateType = "boolean" Quit "boolean"
    If pTemplateType = "number" Quit "number"
    Quit "string"
}

/// <p>The refusal of a call's arguments under this tool's own field rules, in
/// <var>pProblem</var>, or <code>""</code> (AD-55). The mint asks it of every tool, after the fresh
/// read and before anything is stored, so the agent cannot mint a write that the screen would
/// refuse.</p>
/// <p>Empty here: a change merges over a fresh read and a field it omits keeps the instance's
/// value, while a create's omitted field takes the vendor's default.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Quit $$$OK
}

}
