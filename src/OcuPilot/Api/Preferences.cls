/// <p>The handler behind <code>GET</code>/<code>POST /account/preferences</code> (Stories 15.2 and
/// 15.5, FR-73, AD-50): everything OcuPilot remembers about the caller.</p>
/// <p><b>Caller-own and ungated beyond the router</b>, like <class>OcuPilot.Api.Context</class>
/// and <class>OcuPilot.Api.Account</class>. Every read and every write is for
/// <code>$Username</code>; the route accepts no user name, so there is no other account this
/// handler can reach. It is shell chrome, not a declared read (AD-50): a per-user answer is a
/// different question from "resolve this screen's rows for whoever passes its gate", and AD-36's
/// contract takes no caller argument.</p>
/// <p><b>Two shapes of preference on one envelope.</b> The membership kinds answer
/// <code>{route}</code> rows; the value kinds -- one screen's table view, one screen's refresh
/// rate, one piece of shell chrome -- answer <code>{route, value}</code> or
/// <code>{name, value}</code>. One store, one route, one body (AD-50).</p>
/// <p><b>A stored route is a weak reference</b> (AD-37). It is validated against the screen
/// registry before it is written, and bound as a SQL parameter, never concatenated (AD-21,
/// NFR-4). A route that stops resolving later is still answered here; dropping it from a rendered
/// list is the client's job.</p>
/// <p><b>Neither an empty route nor an empty value is ever stored.</b> IRIS SQL stores an empty
/// <code>%String</code> as <code>NULL</code>, so an empty
/// <property>OcuPilot.Kernel.State.Pref.Name</property> could be written and never matched again
/// by the key lookup that removes it, and an empty
/// <property>OcuPilot.Kernel.State.Pref.Value</property> would read back as no preference at
/// all.</p>
Class OcuPilot.Api.Preferences Extends %RegisteredObject
{

/// <p>The body member naming which list a write is about.</p>
Parameter KINDMEMBER As %String = "kind";

/// <p>The body member naming what to do to it.</p>
Parameter ACTIONMEMBER As %String = "action";

/// <p>The body member naming the screen route, and the field a route or limit refusal lands
/// on.</p>
Parameter ROUTEMEMBER As %String = "route";

/// <p>The body member naming a shell member, and the field a name refusal lands on. A shell
/// preference is keyed by a member name from a closed set rather than by a route.</p>
Parameter NAMEMEMBER As %String = "name";

/// <p>The body member carrying what a value kind remembers, and the field a value refusal lands
/// on.</p>
Parameter VALUEMEMBER As %String = "value";

/// <p>The two actions that name a route.</p>
Parameter ACTIONADD As %String = "add";

Parameter ACTIONREMOVE As %String = "remove";

/// <p>The one action that must not name a key, and the one every kind takes.</p>
Parameter ACTIONCLEAR As %String = "clear";

/// <p>The action a value kind takes instead of an add or a remove: store this value at this key
/// (Story 15.5). A value kind keeps one row per key, so a second set replaces rather than adds.
/// <parameter>ACTIONCLEAR</parameter> serves every kind -- forgetting everything a kind remembers
/// is the same operation whatever the rows mean.</p>
Parameter ACTIONSET As %String = "set";

/// <p>The authenticated caller, as <code>$USERNAME</code> reads it.</p>
ClassMethod CallerUsername() As %String
{
    Quit $Username
}

/// <p>Answer <code>GET /account/preferences</code>: the five members
/// <method>Body</method> builds, favorites oldest-first and recents newest-first, each capped by
/// the store.</p>
ClassMethod HandleRead() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..Body(..CallerUsername(), .tBody)
        If $$$ISERR(tSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSC))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>POST /account/preferences {kind, action, route|name, value}</code>: apply the
/// change and answer the same body <method>HandleRead</method> would.</p>
/// <p>A body carrying anything else -- missing, badly typed, an extra member, a value outside its
/// enum, or a member the kind does not take -- is refused 422
/// <parameter>OcuPilot.Api.Error.PREFERENCESBODY</parameter> before anything is written. A route
/// that is not a built screen's is 422
/// <parameter>OcuPilot.Api.Error.PREFERENCESROUTE</parameter> on <code>route</code>; a shell
/// member outside the closed set is 422
/// <parameter>OcuPilot.Api.Error.PREFERENCESNAME</parameter> on <code>name</code>; an absent,
/// empty or over-long value is 422 <parameter>OcuPilot.Api.Error.PREFERENCESVALUE</parameter> on
/// <code>value</code>; a <code>theme</code> value other than <code>light</code> or
/// <code>dark</code> is 422 <parameter>OcuPilot.Api.Error.PREFERENCESCHOICE</parameter> on
/// <code>value</code>; and a twenty-first favorite is 422
/// <parameter>OcuPilot.Api.Error.PREFERENCESLIMIT</parameter> on <code>route</code>.</p>
/// <p><b>Only an <parameter>ACTIONADD</parameter> requires a built screen's route.</b> A
/// <parameter>ACTIONREMOVE</parameter> takes any string and is the one way out of a row whose
/// screen stopped resolving -- which the client drops from its rendering (AD-37) and could
/// otherwise never remove. A route no row holds is the documented no-op answering 200.</p>
/// <p>A write another write refused answers 409
/// <parameter>OcuPilot.Api.Error.STATECONFLICT</parameter>: it is a refusal, never a retry
/// (Consistency Conventions: concurrent writes to OcuPilot's own state). Both of
/// <class>OcuPilot.Kernel.State.Base</class>'s concurrency refusals take that arm -- a value write
/// that lost its conditional save (<method>OcuPilot.Kernel.State.Base.IsStaleSave</method>) and a
/// capped add that could not enter the cap's critical section
/// (<method>OcuPilot.Kernel.State.Base.IsCapBusy</method>). Neither is an internal error, so
/// neither may fall through to <method>OcuPilot.Api.Error.RenderInternal</method>.</p>
ClassMethod HandleUpdate() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tRequestBody, .tStage)
        If $$$ISERR(tReadSC) {
            ; A read or decode fault is the server's, not the caller's, so it is logged before the
            ; refusal is rendered. The status ReadRequestBody answered is logged with the stage,
            ; Api/Definitions.RenderBadBody's shape rather than Api/Account.RenderBodyRefusal's:
            ; Account withholds it because that parser exception can quote the document and its
            ; document is two passwords (AD-35), while this one is a kind, an action, a key and a
            ; remembered preference and carries no secret. Without it a genuine decode fault leaves
            ; no diagnostic at all.
            Do ##class(OcuPilot.Kernel.Fault).LogRaw("preferences", "preferences body refused at the " _ tStage _ " stage", tReadSC, ##class(OcuPilot.Api.Error).#PREFERENCESBODY)
            Set tSC = ..RenderBodyRefusal()
            Quit
        }
        If '$IsObject(tRequestBody) || 'tRequestBody.%IsA("%Library.DynamicObject") {
            Set tSC = ..RenderBodyRefusal()
            Quit
        }
        ; The iterator's value is bound to a variable nothing reads: %GetNext's second argument is
        ; where it lands whether or not it is wanted. The iterator holds its own reference to the
        ; parsed body, so it is released rather than left holding it.
        Set tExtra = 0
        Set tIterator = tRequestBody.%GetIterator()
        While tIterator.%GetNext(.tKey, .tIgnored) {
            If '..IsKnownMember(tKey) Set tExtra = 1
        }
        Set tIgnored = ""
        Set tIterator = ""
        If tExtra {
            Set tSC = ..RenderBodyRefusal()
            Quit
        }
        If (tRequestBody.%GetTypeOf(..#KINDMEMBER) '= "string") || (tRequestBody.%GetTypeOf(..#ACTIONMEMBER) '= "string") {
            Set tSC = ..RenderBodyRefusal()
            Quit
        }
        Set tKind = tRequestBody.%Get(..#KINDMEMBER)
        Set tAction = tRequestBody.%Get(..#ACTIONMEMBER)
        If '..IsKnownKind(tKind) || '..IsKnownAction(tAction) {
            Set tSC = ..RenderBodyRefusal()
            Quit
        }
        Set tIsValueKind = ..IsValueKind(tKind)
        Set tKeyMember = $Select(tKind = ##class(OcuPilot.Kernel.State.Pref).#KINDSHELL: ..#NAMEMEMBER, 1: ..#ROUTEMEMBER)
        Set tOtherKey = $Select(tKeyMember = ..#NAMEMEMBER: ..#ROUTEMEMBER, 1: ..#NAMEMEMBER)
        ; Which members this kind and action take, decided before any of them is read. A value
        ; kind takes set alone; a membership kind takes the other three and never a value.
        Set tNamesKey = (tAction '= ..#ACTIONCLEAR)
        If tIsValueKind && (tAction '= ..#ACTIONSET) && (tAction '= ..#ACTIONCLEAR) {
            Set tSC = ..RenderBodyRefusal()
            Quit
        }
        If 'tIsValueKind && (tAction = ..#ACTIONSET) {
            Set tSC = ..RenderBodyRefusal()
            Quit
        }
        If tRequestBody.%GetTypeOf(tOtherKey) '= "unassigned" {
            Set tSC = ..RenderBodyRefusal()
            Quit
        }
        If tNamesKey && (tRequestBody.%GetTypeOf(tKeyMember) '= "string") {
            Set tSC = ..RenderBodyRefusal()
            Quit
        }
        If 'tNamesKey && (tRequestBody.%GetTypeOf(tKeyMember) '= "unassigned") {
            Set tSC = ..RenderBodyRefusal()
            Quit
        }
        If (tAction '= ..#ACTIONSET) && (tRequestBody.%GetTypeOf(..#VALUEMEMBER) '= "unassigned") {
            Set tSC = ..RenderBodyRefusal()
            Quit
        }
        If (tAction = ..#ACTIONSET) && (tRequestBody.%GetTypeOf(..#VALUEMEMBER) '= "string") {
            Set tSC = ..RenderBodyRefusal()
            Quit
        }
        Set tKey = ""
        If tNamesKey Set tKey = tRequestBody.%Get(tKeyMember)
        Set tValue = ""
        If tAction = ..#ACTIONSET Set tValue = tRequestBody.%Get(..#VALUEMEMBER)
        Set tRequestBody = ""

        ; The registry gates what may be stored, never what may be removed: a row whose screen
        ; stopped resolving is dropped from the client's rendering (AD-37) and would otherwise
        ; be unremovable, holding one of the favorites slots for good.
        If (tKeyMember = ..#ROUTEMEMBER) && (tAction '= ..#ACTIONREMOVE) && tNamesKey && '..IsBuiltRoute(tKey) {
            Set tSC = ..RenderViolation(##class(OcuPilot.Api.Error).#PREFERENCESROUTE, ..#ROUTEMEMBER)
            Quit
        }
        If tNamesKey && (tKeyMember = ..#NAMEMEMBER) && '##class(OcuPilot.Kernel.State.Pref).IsShellMember(tKey) {
            Set tSC = ..RenderViolation(##class(OcuPilot.Api.Error).#PREFERENCESNAME, ..#NAMEMEMBER)
            Quit
        }
        If (tAction = ..#ACTIONSET) && ((tValue = "") || ($Length(tValue) > ##class(OcuPilot.Kernel.State.Pref).#VALUEMAXLENGTH)) {
            Set tSC = ..RenderViolation(##class(OcuPilot.Api.Error).#PREFERENCESVALUE, ..#VALUEMEMBER)
            Quit
        }
        ; The theme member takes one of a fixed set of values, refused before any write.
        If (tAction = ..#ACTIONSET) && (tKeyMember = ..#NAMEMEMBER) && (tKey = ##class(OcuPilot.Kernel.State.Pref).#SHELLTHEME) && '##class(OcuPilot.Kernel.State.Pref).IsThemeValue(tValue) {
            Set tSC = ..RenderViolation(##class(OcuPilot.Api.Error).#PREFERENCESCHOICE, ..#VALUEMEMBER)
            Quit
        }

        Set tUser = ..CallerUsername()
        Set tApplySC = ..Apply(tUser, tKind, tAction, tKey, tValue, .tAtLimit)
        If $$$ISERR(tApplySC) {
            If ##class(OcuPilot.Kernel.State.Base).IsStaleSave(tApplySC) || ##class(OcuPilot.Kernel.State.Base).IsCapBusy(tApplySC) {
                Set tSC = ..RenderConflict()
                Quit
            }
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tApplySC))
            Quit
        }
        If tAtLimit {
            Set tSC = ..RenderViolation(##class(OcuPilot.Api.Error).#PREFERENCESLIMIT, ..#ROUTEMEMBER)
            Quit
        }
        Set tSC = ..Body(tUser, .tBody)
        If $$$ISERR(tSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSC))
            Quit
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tIgnored = ""
        Set tIterator = ""
        Set tRequestBody = ""
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Perform one validated change. <var>pAtLimit</var> is 1 when a favorite was refused because
/// the caller already holds as many as the instance keeps; nothing was written in that case.</p>
/// <p>A recent visit is a refresh and a trim: the row's timestamp moves, the list re-orders, and
/// everything past <parameter>OcuPilot.Kernel.State.Pref.RECENTMAX</parameter> is deleted. A value
/// kind is never trimmed -- it holds one row per key.</p>
ClassMethod Apply(pUser As %String, pKind As %String, pAction As %String, pKey As %String, pValue As %String, Output pAtLimit As %Boolean) As %Status [ Private ]
{
    Set pAtLimit = 0
    If pAction = ..#ACTIONSET {
        Quit ##class(OcuPilot.Kernel.State.Pref).GuardedSetValue(pUser, pKind, pKey, pValue)
    }
    If pAction = ..#ACTIONCLEAR {
        Quit ##class(OcuPilot.Kernel.State.Pref).GuardedClear(pUser, pKind)
    }
    If pAction = ..#ACTIONREMOVE {
        Quit ##class(OcuPilot.Kernel.State.Pref).GuardedRemove(pUser, pKind, pKey)
    }
    If pKind = ##class(OcuPilot.Kernel.State.Pref).#KINDRECENT {
        Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedTouch(pUser, pKind, pKey)
        If $$$ISERR(tSC) Quit tSC
        Quit ##class(OcuPilot.Kernel.State.Pref).GuardedTrim(pUser, pKind, ##class(OcuPilot.Kernel.State.Pref).#RECENTMAX)
    }
    Quit ##class(OcuPilot.Kernel.State.Pref).GuardedAdd(pUser, pKind, pKey, ##class(OcuPilot.Kernel.State.Pref).#FAVORITEMAX, .pAtLimit)
}

/// <p>The body both verbs answer: <code>{favorites, recents, views, refreshRates, shell}</code>,
/// the first two arrays of <code>{route}</code>, the next two of <code>{route, value}</code>, and
/// the last of <code>{name, value}</code>.</p>
ClassMethod Body(pUser As %String, Output pBody As %DynamicObject) As %Status [ Private ]
{
    Set pBody = ""
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedListForUser(pUser, ##class(OcuPilot.Kernel.State.Pref).#KINDFAVORITE, .tFavorites)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedListForUser(pUser, ##class(OcuPilot.Kernel.State.Pref).#KINDRECENT, .tRecents)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedListForUser(pUser, ##class(OcuPilot.Kernel.State.Pref).#KINDSCREENVIEW, .tViews)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedListForUser(pUser, ##class(OcuPilot.Kernel.State.Pref).#KINDREFRESH, .tRates)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedListForUser(pUser, ##class(OcuPilot.Kernel.State.Pref).#KINDSHELL, .tShell)
        If $$$ISERR(tSC) Quit
        Set pBody = {}
        Do pBody.%Set("favorites", ..Routes(tFavorites))
        Do pBody.%Set("recents", ..Routes(tRecents))
        Do pBody.%Set("views", ..Valued(tViews, ..#ROUTEMEMBER))
        Do pBody.%Set("refreshRates", ..Valued(tRates, ..#ROUTEMEMBER))
        Do pBody.%Set("shell", ..Valued(tShell, ..#NAMEMEMBER))
    } Catch ex {
        Set pBody = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><var>pRows</var> narrowed to the one member a membership kind's wire carries. The store also
/// answers each row's timestamp, which is what orders the list, and a value column the membership
/// kinds ignore; the client renders order, never the stamp, so neither leaves the instance.</p>
ClassMethod Routes(pRows As %DynamicArray) As %DynamicArray [ Private ]
{
    Set tOut = []
    If '$IsObject(pRows) Quit tOut
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tEntry = {}
        Do tEntry.%Set(..#ROUTEMEMBER, tRow.route, "string")
        Do tOut.%Push(tEntry)
    }
    Quit tOut
}

/// <p><var>pRows</var> as a value kind's wire carries them: the key under <var>pKeyMember</var>
/// -- <code>route</code> for a screen-scoped kind, <code>name</code> for a shell one -- and what
/// the user chose. The timestamp is dropped here as it is for a membership kind.</p>
ClassMethod Valued(pRows As %DynamicArray, pKeyMember As %String) As %DynamicArray [ Private ]
{
    Set tOut = []
    If '$IsObject(pRows) Quit tOut
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tEntry = {}
        Do tEntry.%Set(pKeyMember, tRow.route, "string")
        Do tEntry.%Set(..#VALUEMEMBER, tRow.value, "string")
        Do tOut.%Push(tEntry)
    }
    Quit tOut
}

/// <p>Whether <var>pMember</var> is one of the five members this route's grammar admits. Which of
/// them a given kind and action take is decided in <method>HandleUpdate</method>; this is the
/// closed set outside which a member is an extra one.</p>
ClassMethod IsKnownMember(pMember As %String) As %Boolean [ Private ]
{
    If pMember = ..#KINDMEMBER Quit 1
    If pMember = ..#ACTIONMEMBER Quit 1
    If pMember = ..#ROUTEMEMBER Quit 1
    If pMember = ..#NAMEMEMBER Quit 1
    If pMember = ..#VALUEMEMBER Quit 1
    Quit 0
}

/// <p>Whether <var>pKind</var> is one of the five this route serves.</p>
ClassMethod IsKnownKind(pKind As %String) As %Boolean [ Private ]
{
    If pKind = ##class(OcuPilot.Kernel.State.Pref).#KINDFAVORITE Quit 1
    If pKind = ##class(OcuPilot.Kernel.State.Pref).#KINDRECENT Quit 1
    Quit ..IsValueKind(pKind)
}

/// <p>Whether <var>pKind</var> carries a value rather than set membership -- the three Story 15.5
/// added. A value kind takes <parameter>ACTIONSET</parameter> and nothing else.</p>
ClassMethod IsValueKind(pKind As %String) As %Boolean [ Private ]
{
    If pKind = ##class(OcuPilot.Kernel.State.Pref).#KINDSCREENVIEW Quit 1
    If pKind = ##class(OcuPilot.Kernel.State.Pref).#KINDREFRESH Quit 1
    If pKind = ##class(OcuPilot.Kernel.State.Pref).#KINDSHELL Quit 1
    Quit 0
}

/// <p>Whether <var>pAction</var> is one of the four this route performs.</p>
ClassMethod IsKnownAction(pAction As %String) As %Boolean [ Private ]
{
    If pAction = ..#ACTIONADD Quit 1
    If pAction = ..#ACTIONREMOVE Quit 1
    If pAction = ..#ACTIONCLEAR Quit 1
    If pAction = ..#ACTIONSET Quit 1
    Quit 0
}

/// <p>Whether <var>pRoute</var> is a built screen's declared route, and short enough to store.
/// Asked of an <parameter>ACTIONADD</parameter> and of a screen-scoped
/// <parameter>ACTIONSET</parameter>, never of a remove.</p>
/// <p>Answered by the screen registry, which is the one source for what routes exist (AD-5), and
/// never by matching a pattern here.</p>
ClassMethod IsBuiltRoute(pRoute As %String) As %Boolean [ Private ]
{
    Set tBuilt = 0
    Try {
        If pRoute = "" Quit
        If $Length(pRoute) > ##class(OcuPilot.Kernel.State.Pref).#ROUTEMAXLENGTH Quit
        Set tClass = ##class(OcuPilot.Screen.Registry).DescriptorForRoute(pRoute)
        If tClass = "" Quit
        Set tBuilt = ''$ClassMethod(tClass, "IsBuilt")
    } Catch {
        Set tBuilt = 0
    }
    Quit tBuilt
}

/// <p>Refuse the body with 422 <parameter>OcuPilot.Api.Error.PREFERENCESBODY</parameter> and no
/// <code>detail</code>: no field was reached, so there is nothing to name one on.</p>
ClassMethod RenderBodyRefusal() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).#REASONPREFERENCESBODY, ##class(OcuPilot.Api.Error).#PREFERENCESBODY)
}

/// <p>Refuse a value write that lost its conditional save with 409
/// <parameter>OcuPilot.Api.Error.STATECONFLICT</parameter> -- a refusal the caller reloads and
/// repeats, never a retry this handler makes.</p>
ClassMethod RenderConflict() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#REASONSTATECONFLICT, ##class(OcuPilot.Api.Error).#STATECONFLICT)
}

/// <p>Refuse with <b>one</b> 422 carrying a single violation on <var>pField</var> under
/// <var>pCode</var> (AD-39). The sentence is
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s, so the refusal copy is written once
/// on the server.</p>
ClassMethod RenderViolation(pCode As %String, pField As %String) As %Status [ Private ]
{
    Set tViolations = 1
    Set tViolations(1) = $ListBuild(pField, pCode, "")
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.tViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).ReasonForViolation(pCode), pCode, tDetail)
}

}
