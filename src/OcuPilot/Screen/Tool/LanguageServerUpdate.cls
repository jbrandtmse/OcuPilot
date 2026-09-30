/// <p>External language servers' edit tool (AD-4, AD-6, AD-10, AD-55, Story 16.25): propose a change to
/// one external language server. Two callers reach it: the editor's Save through
/// <class>OcuPilot.Area.OsMgmt.LanguageServerSave</class>, and the agent's proposal and confirmation.
/// It reads the server fresh through <class>OcuPilot.Port.LanguageServerPort</class>, merges the
/// arguments over that read (<method>MergeUpdate</method>) and mints a proposal the user confirms. It
/// writes nothing.</p>
/// <p><b>A merge write under AD-4's named exception</b>: the body is the fresh read with the changed
/// fields applied, its type and its file locations sent back as the instance holds them, and
/// <code>Custom</code> merged member by member. An unchanged <code>Custom</code> is left out of the
/// body, because a <code>PUT</code> carrying it blanks the stored settings the type's
/// <code>Custom</code> does not name -- on a Python server its virtual-environment flag and its
/// PYTHONPATH, which the read never answers (measured on <code>ocupilot-ci</code>). The running state is
/// never sent.</p>
/// <p><b>A running server is refused</b>, as the classic editor refuses it, unless it is
/// <code>Remote</code>: an edit while it runs leaves the running process as it was, so a changed port
/// orphans a listener no screen can see (measured). The refusal sits in <method>MergeUpdate</method>,
/// so the confirm's re-merge refuses a server started since the mint too.</p>
Class OcuPilot.Screen.Tool.LanguageServerUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.languageservers.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LanguageServerList";

Parameter DESCRIPTION = "Propose a change to one external language server on this instance: its port, timeouts, bind address, resource, TLS settings or its type's own settings in Custom. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the server exactly as the external language servers list reports it, and send only the fields to change; its name and type cannot be changed, and file locations are set on the classic portal. A running server is refused unless its type is Remote. On a Python server, changing a Custom setting has a consequence: Saving this also turns the server's virtual environment back on and clears its PYTHONPATH, which only the classic portal shows.";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The port that completes the read with the running state (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.LanguageServerPort";

/// <p>The derived top-level fields this tool admits, comma-separated: the create's less
/// <code>Type</code> (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names
/// these and <parameter>CUSTOMFIELD</parameter>).</p>
Parameter PERMITTEDFIELDS = "Port,BindToIPAddress,ConnectionTimeout,InitializationTimeout,Resource,UseSharedMemory,SSLConfigurationServer,SSLConfigurationClient,VerifySSLHostName";

/// <p>The object argument the tool adds back beside the derived literals.</p>
Parameter CUSTOMFIELD = "Custom";

/// <p>The running state the port adds to the read, which the body never carries.</p>
Parameter RUNNINGFIELD = "CurrentlyRunning";

/// <p>The pairs every language server write needs beyond the list's own
/// (<parameter>OcuPilot.Screen.Tool.LanguageServerCreate.MANAGERESOURCE</parameter>).</p>
Parameter MANAGERESOURCE = "%Admin_Manage";

Parameter MANAGEPERMISSION = "USE";

Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The classic page whose operation this tool performs beyond the list's own (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.ExternalLanguageServer";

/// <p>The refusal of a running server, published in EXPERIENCE.md's Fixed strings and pinned equal
/// to <code>languageServerRefusalRunningEdit</code> by <file>ui/tools/self-protection.test.mjs</file>.</p>
Parameter RUNNINGREASON = "This server is running. Stop it before changing or deleting it.";

/// <p>The consequence a changed <code>Custom</code> member carries on a Python server, published in
/// EXPERIENCE.md's Fixed strings, pinned equal to <code>languageServerPythonConsequence</code> and
/// carried in <parameter>DESCRIPTION</parameter>.</p>
Parameter PYTHONCONSEQUENCE = "Saving this also turns the server's virtual environment back on and clears its PYTHONPATH, which only the classic portal shows.";

/// <p>The rules this tool applies.</p>
Parameter RULES = "OcuPilot.Area.OsMgmt.LanguageServerRules";

ClassMethod Endpoint() As %String
{
    Quit "LanguageServer"
}

ClassMethod IdArgument() As %String
{
    Quit "Name"
}

ClassMethod IdParam() As %String
{
    Quit "name"
}

/// <p>The derived <code>ordinary</code> fields this tool admits, and <parameter>CUSTOMFIELD</parameter>.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#CUSTOMFIELD)
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema, described (<method>OcuPilot.Screen.Tool.LanguageServerCreate.Described</method>).</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ##class(OcuPilot.Screen.Tool.LanguageServerCreate).Described(##super(pDescriptor), 0)
}

/// <p>The editor's own rules over the agent's arguments, read against this tool's own fresh read of
/// <var>pIdValue</var> (AD-55). A server the read no longer finds is judged by no rule; the mint has
/// already refused one that was absent when it read.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) && (+$Get(tHttp) '= 404) Quit tSC
    If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") Quit $$$OK
    Set tSC = $ClassMethod(..#RULES, "Validate", pIdValue, pArgs, .tViolations, "update", 0, tFresh)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = $ClassMethod(..#RULES, "Problem", .tViolations)
    Quit $$$OK
}

/// <p>The merge over the fresh read <var>pFresh</var> (<method>OcuPilot.Kernel.Proposal.Mint.Merge</method>),
/// with <parameter>CUSTOMFIELD</parameter> merged member by member over the server's own and one
/// <code>Custom.&lt;member&gt;</code> row per member that changes. <parameter>RUNNINGFIELD</parameter> is
/// never in the body, and <parameter>CUSTOMFIELD</parameter> is left out of it when no member changes.
/// <var>pUnchanged</var> counts the body's keys no row names.</p>
/// <p>A running server that is not <code>Remote</code> is <var>pProblem</var>,
/// <parameter>RUNNINGREASON</parameter>, before anything is merged; so is a member the type does not
/// take or a file location, in the rules' own sentence.</p>
/// <p><b>Caller contract:</b> called by the mint, by the confirm's fingerprint re-merge and by the
/// editor's Save, so the three take one payload, one digest and one running refusal.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ""
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If $ClassMethod(..#RULES, "Running", pFresh) {
            Set pProblem = ..#RUNNINGREASON
            Quit
        }
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
        Set tCustomArg = ""
        Set tHasCustom = 0
        If tArgs.%GetTypeOf(..#CUSTOMFIELD) '= "unassigned" {
            Set tHasCustom = 1
            Set tCustomArg = tArgs.%Get(..#CUSTOMFIELD)
            Do tArgs.%Remove(..#CUSTOMFIELD)
        }
        Set tLiteral = ""
        For tI = 1:1:$ListLength(pSettable) {
            If $List(pSettable, tI) '= ..#CUSTOMFIELD Set tLiteral = tLiteral _ $ListBuild($List(pSettable, tI))
        }
        Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(pFresh, tArgs, pIdArgument, tLiteral, .pPayload, .pDiff, .tUnchanged, .pProblem)
        If $$$ISERR(tSC) || (pProblem '= "") Quit
        If pPayload.%GetTypeOf(..#RUNNINGFIELD) '= "unassigned" Do pPayload.%Remove(..#RUNNINGFIELD)
        Set tChanged = 0
        If tHasCustom && $ListFind(pSettable, ..#CUSTOMFIELD) {
            Set tSC = ..MergeCustom(pFresh, tCustomArg, pPayload, pDiff, .tChanged, .pProblem)
            If $$$ISERR(tSC) || (pProblem '= "") Quit
        }
        ; AD-4's named exception: a Custom no member of which changes is never sent.
        If 'tChanged && (pPayload.%GetTypeOf(..#CUSTOMFIELD) '= "unassigned") Do pPayload.%Remove(..#CUSTOMFIELD)
        Kill tSeen
        Set tRows = pDiff.%GetIterator()
        While tRows.%GetNext(.tIndex, .tRow) {
            Set tSeen($Piece(tRow.%Get("field"), ".", 1)) = ""
        }
        Set pUnchanged = 0
        Set tKeys = pPayload.%GetIterator()
        While tKeys.%GetNext(.tKey, .tValue) {
            If '$Data(tSeen(tKey)) Set pUnchanged = pUnchanged + 1
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) || (pProblem '= "") {
        Set pPayload = ""
        Set pDiff = []
        Set pUnchanged = 0
    }
    Quit tSC
}

/// <p>Merge the <parameter>CUSTOMFIELD</parameter> argument <var>pSupplied</var> member by member over
/// <var>pFresh</var>'s into <var>pPayload</var>, appending one row per changed member to
/// <var>pDiff</var>; <var>pChanged</var> is whether any changed. The whole object is sent, its file
/// locations as the instance holds them. A flag member is sent as the 0 or 1 the instance answers it
/// as.</p>
ClassMethod MergeCustom(pFresh As %DynamicObject, pSupplied, pPayload As %DynamicObject, pDiff As %DynamicArray, Output pChanged As %Boolean, Output pProblem As %String) As %Status [ Private ]
{
    Set pChanged = 0
    Set pProblem = ""
    If '$IsObject(pSupplied) || 'pSupplied.%IsA("%Library.DynamicObject") {
        Set pProblem = "'" _ ..#CUSTOMFIELD _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        Quit $$$OK
    }
    Set tSC = $ClassMethod(..#RULES, "Members", pFresh.%Get("Type"), .tSettable, .tPaths)
    If $$$ISERR(tSC) Quit tSC
    Set tHeld = {}
    If pFresh.%GetTypeOf(..#CUSTOMFIELD) = "object" Set tHeld = pFresh.%Get(..#CUSTOMFIELD)
    Set tMerged = ##class(%DynamicAbstractObject).%FromJSON(tHeld.%ToJSON())
    Set tFlags = $ListFromString($Parameter(..#RULES, "FLAGMEMBERS"))
    Set tIterator = pSupplied.%GetIterator()
    While tIterator.%GetNext(.tMember, .tValue) {
        Set tField = ..#CUSTOMFIELD _ "." _ tMember
        If '$ListFind(tSettable, tMember) {
            Set pProblem = $ClassMethod(..#RULES, "MemberProblem", tField, ''$ListFind(tPaths, tMember))
            Quit
        }
        Set tKind = pSupplied.%GetTypeOf(tMember)
        Set tBefore = ##class(OcuPilot.Kernel.Proposal.Mint).Display(tHeld.%Get(tMember), tHeld.%GetTypeOf(tMember))
        If $ListFind(tFlags, tMember) {
            If (tKind '= "boolean") && (tKind '= "number") {
                Set pProblem = "'" _ tField _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Quit
            }
            Set tAfter = $Select(tValue: "1", 1: "0")
            If tAfter = tBefore Continue
            Do tMerged.%Set(tMember, +tAfter, "number")
        } Else {
            If (tKind = "object") || (tKind = "array") {
                Set pProblem = "'" _ tField _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
                Quit
            }
            Set tAfter = ##class(OcuPilot.Kernel.Proposal.Mint).Display(tValue, tKind)
            If tAfter = tBefore Continue
            Do tMerged.%Set(tMember, tAfter, "string")
        }
        Set tRow = {}
        Do tRow.%Set("field", tField, "string")
        Do tRow.%Set("before", tBefore, "string")
        Do tRow.%Set("after", tAfter, "string")
        Do pDiff.%Push(tRow)
        Set pChanged = 1
    }
    If pProblem '= "" {
        Set pChanged = 0
        Quit $$$OK
    }
    If pChanged Do pPayload.%Set(..#CUSTOMFIELD, tMerged)
    Quit $$$OK
}

/// <p>What the caller must hold: the screen's own pairs, then
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter> and
/// <parameter>MANAGERESOURCE</parameter>:<parameter>MANAGEPERMISSION</parameter>, then the custom
/// resource of each <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    For tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION), $ListBuild(..#MANAGERESOURCE, ..#MANAGEPERMISSION) {
        If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    }
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
