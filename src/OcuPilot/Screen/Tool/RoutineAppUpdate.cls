/// <p>The privileged routine applications' edit tool (AD-4, AD-6, AD-55, Stories 18.31 and 18.33): propose a change to
/// one application's description, enabled flag or resource, to its roles (<code>MatchRoles</code>) or to its routines
/// (<code>Routines</code>). It is <class>OcuPilot.Screen.Tool.DocDbAppUpdate</class> over the vendor's own
/// <code>Security.PrivilegedRoutine</code> endpoint, reached through <class>OcuPilot.Port.AdminPort</class>. It reads the
/// application fresh, merges the arguments over that object and mints a proposal the user confirms. It writes
/// nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read's complete set, with the changed arguments applied (AD-4). The
/// vendor replaces a sent <code>MatchRoles</code> and empties a <code>Routines</code> a <code>PUT</code> does not send,
/// so every update sends both lists, as read or as changed. The agent sends each list whole; the screen's six row
/// actions change one entry of one list at a time, by a delta over the fresh read (AD-56 (ii),
/// <method>ScreenActionDelta</method>). The name is the id and never changes.</p>
/// <p>A grant through a role, a matching role or a routine is confirmed as a delete is
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method>).</p>
/// <p>OcuPilot's own two routine applications are refused every change before a proposal is stored
/// (<method>RefusedBeforeState</method>).</p>
Class OcuPilot.Screen.Tool.RoutineAppUpdate Extends OcuPilot.Screen.Tool.DocDbAppUpdate
{

Parameter TOOLNAME = "webapp.routineapps.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RoutineAppList";

Parameter DESCRIPTION = "Propose a change to one privileged routine application. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the application exactly as the privileged routine applications list reports it and send only what to change: the description, whether it is enabled, the service, system or application resource that controls it, its roles (MatchRoles) or its routines and classes (Routines). MatchRoles and Routines are each the complete list after the change, so an entry left out is removed. Granting %All or a role that carries an administrative privilege, or adding a routine while such a role is granted, is proposable and is confirmed as a delete is. The application's name cannot be changed. Changes to OcuPilot's own two privileged routine applications are refused.";

Parameter PORTCLASS = "OcuPilot.Port.AdminPort";

/// <p>The classic editor whose operation this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Applications.PrivRoutine";

/// <p>The rules this tool applies.</p>
Parameter RULES = "OcuPilot.Area.WebApp.RoutineAppRules";

/// <p>The row actions this tool carries out (AD-5, AD-53): the four role actions of
/// <class>OcuPilot.Screen.Tool.WebAppUpdate</class> and the two routine actions. None sets a static argument; each takes
/// its values (<parameter>SCREENVALUES</parameter>) and changes one list by a delta over the fresh read
/// (<method>ScreenActionDelta</method>).</p>
Parameter SCREENACTIONS = "add-application-role,remove-application-role,add-matching-role,remove-matching-role,add-routine,remove-routine";

/// <p>The values each action admits: the role actions' as <class>OcuPilot.Screen.Tool.WebAppUpdate</class> declares
/// them, and a routine action's three members of one routine entry.</p>
Parameter SCREENVALUES = "add-application-role=Role,remove-application-role=Role,add-matching-role=MatchRole:Role,remove-matching-role=MatchRole:Role,add-routine=RoutineOrClass:Db:Type,remove-routine=RoutineOrClass:Db:Type";

/// <p>The two routine actions. The members of one routine entry are <parameter>RULES</parameter>'.</p>
Parameter ADDROUTINE = "add-routine";

Parameter REMOVEROUTINE = "remove-routine";

ClassMethod Endpoint() As %String
{
    Quit "Security.PrivilegedRoutine"
}

/// <p>The kernel's mint: the application's id is its name, so no composite is built.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Kernel.Proposal.Mint"
}

/// <p>The three settings and the two lists, which only the agent's update sends whole and a screen action changes by a
/// delta.</p>
ClassMethod SettableFields() As %List
{
    Quit ##super() _ $ListBuild("MatchRoles", "Routines")
}

/// <p>The derived schema with the name and the settings described, and no namespace
/// (<method>OcuPilot.Screen.Tool.RoutineAppCreate.Described</method>), and the two lists added, each an array whose
/// entries <method>ArgumentProblem</method> refuses when misshapen, because the schema subset a provider is sent
/// describes no member below a property.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##class(OcuPilot.Screen.Tool.RoutineAppCreate).Described(##super(pDescriptor), 0)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tRoles = {"type": "array", "description": "The application's roles after the change, replacing the whole list, so an entry left out is removed. Granting %All, or a role that carries an administrative privilege, is proposable and is confirmed as a delete is."}
    Do tRoles.%Set("items", {"type": "object", "description": "One entry, an object with exactly two members: MatchRole, empty to grant the target roles to every caller or a role a caller must hold to receive them, and TargetRoles, an array of role names as this instance's own roles list reports them."})
    Set tRoutines = {"type": "array", "description": "The routines and classes that may add roles for this application, after the change, replacing the whole list, so an entry left out is removed. Adding one while a role that carries an administrative privilege is granted is confirmed as a delete is."}
    Do tRoutines.%Set("items", {"type": "object", "description": "One entry, an object with exactly three string members: RoutineOrClass, a routine name or a class name as Package.Name, holding neither a comma nor a colon; Db, a database name as this instance's databases list reports it; and Type, Routine or Class."})
    Do tSchema.%Get("properties").%Set("MatchRoles", tRoles)
    Do tSchema.%Get("properties").%Set("Routines", tRoutines)
    Quit tSchema
}

/// <p>OcuPilot's own privileged routine applications are refused every change as
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTROUTINEAPP</parameter> before a proposal is stored or a write
/// is sent (AD-10, Story 18.10), so the screen's action and the agent's mint answer 403.</p>
ClassMethod RefusedBeforeState(pIdValue As %String, Output pCode As %String) As %Boolean
{
    Quit ##class(OcuPilot.Kernel.Proposal.Prohibited).RefusesBeforeState(pIdValue, .pCode)
}

/// <p>The arguments a screen action sends (AD-56 (ii)): for the four role actions,
/// <method>OcuPilot.Screen.Tool.WebAppUpdate.ScreenActionDelta</method>'s complete <code>MatchRoles</code>; for a
/// routine action, the complete <code>Routines</code> built from the fresh read <var>pFresh</var> with one entry added
/// or removed. An entry is held when its name and type are as given and its database is, without regard to case. Refused
/// in <var>pProblem</var>: an empty value, an add of an entry already held, a remove of one not held, and an added
/// entry the routines rule refuses (<method>OcuPilot.Area.WebApp.RoutineAppRules.RoutinesViolation</method>). No
/// problem sentence names a value, so a refused request echoes none. Whether a grant is privileged, or refused on one of
/// OcuPilot's own applications, is the prohibited set's question at the write, never this method's.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        ; OcuPilot's own two are refused 403 by the route's early refusal, whatever the values name; the delta answers
        ; nothing for them rather than a 400 about a role or an entry they happen not to hold.
        If $ListFind($ListFromString(..#SCREENACTIONS), pActionId) && $IsObject(pValues) && (pValues.%GetTypeOf(..IdArgument()) = "string") && ..RefusedBeforeState(pValues.%Get(..IdArgument())) {
            Set pArgs = {}
            Quit
        }
        If $ListFind($ListFromString("add-application-role,remove-application-role,add-matching-role,remove-matching-role"), pActionId) {
            Set tSC = ##class(OcuPilot.Screen.Tool.WebAppUpdate).ScreenActionDelta(pActionId, pValues, pFresh, .pArgs, .pProblem)
            Quit
        }
        If (pActionId '= ..#ADDROUTINE) && (pActionId '= ..#REMOVEROUTINE) {
            Set tSC = ##super(pActionId, pValues, pFresh, .pArgs, .pProblem)
            Quit
        }
        Set pArgs = {}
        Set tAdd = (pActionId = ..#ADDROUTINE)
        Set tNameKey = $Parameter(..#RULES, "ENTRYNAME")
        Set tDbKey = $Parameter(..#RULES, "ENTRYDB")
        Set tTypeKey = $Parameter(..#RULES, "ENTRYTYPE")
        For tMember = tNameKey, tDbKey, tTypeKey {
            Set tGiven(tMember) = $Select($IsObject(pValues) && (pValues.%GetTypeOf(tMember) = "string"): pValues.%Get(tMember), 1: "")
            If $ZStrip(tGiven(tMember), "<>W") = "" {
                Set pProblem = "'" _ tMember _ "' names " _ $Case(tMember, tNameKey: "the routine or class", tDbKey: "its database", : "its type, Routine or Class") _ " and cannot be empty"
                Quit
            }
        }
        If pProblem '= "" Quit
        Set tEntries = []
        Set tHeld = 0
        If $IsObject(pFresh) && (pFresh.%GetTypeOf("Routines") = "array") {
            Set tIterator = pFresh.%Get("Routines").%GetIterator()
            While tIterator.%GetNext(.tIndex, .tEntry) {
                If '$IsObject(tEntry) || 'tEntry.%IsA("%Library.DynamicObject") Continue
                If (tEntry.%Get(tNameKey) = tGiven(tNameKey)) && ($ZConvert(tEntry.%Get(tDbKey), "U") = $ZConvert(tGiven(tDbKey), "U")) && (tEntry.%Get(tTypeKey) = tGiven(tTypeKey)) {
                    Set tHeld = 1
                    If 'tAdd Continue
                }
                Do tEntries.%Push(##class(%DynamicAbstractObject).%FromJSON(tEntry.%ToJSON()))
            }
        }
        If 'tAdd {
            If 'tHeld Set pProblem = "the application does not list that routine or class"
            If pProblem '= "" Quit
        } Else {
            If tHeld {
                Set pProblem = "the application already lists that routine or class"
                Quit
            }
            Set tNew = {}
            Do tNew.%Set(tNameKey, tGiven(tNameKey), "string")
            Do tNew.%Set(tDbKey, tGiven(tDbKey), "string")
            Do tNew.%Set(tTypeKey, tGiven(tTypeKey), "string")
            Set tAlone = {"Routines": [(tNew)]}
            Kill tViolations
            Set tViolations = 0
            Set tSC = $ClassMethod(..#RULES, "RoutinesViolation", tAlone, .tViolations)
            If $$$ISERR(tSC) Quit
            If tViolations > 0 {
                Set pProblem = ##class(OcuPilot.Api.Error).ReasonForViolation($Parameter($Parameter(..#RULES, "ERRORCLASS"), "ROUTINES"))
                Quit
            }
            Do tEntries.%Push(tNew)
        }
        Do pArgs.%Set("Routines", tEntries)
    } Catch ex {
        Set pArgs = {}
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
