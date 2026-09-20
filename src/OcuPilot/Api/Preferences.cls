/// <p>The handler behind <code>GET</code>/<code>POST /account/preferences</code> (Story 15.2,
/// FR-73, AD-50): the caller's own favorites and recent items.</p>
/// <p><b>Caller-own and ungated beyond the router</b>, like <class>OcuPilot.Api.Context</class>
/// and <class>OcuPilot.Api.Account</class>. Every read and every write is for
/// <code>$Username</code>; the route accepts no user name, so there is no other account this
/// handler can reach. It is shell chrome, not a declared read (AD-50): a per-user answer is a
/// different question from "resolve this screen's rows for whoever passes its gate", and AD-36's
/// contract takes no caller argument.</p>
/// <p><b>A stored route is a weak reference</b> (AD-37). It is validated against the screen
/// registry before it is written, and bound as a SQL parameter, never concatenated (AD-21,
/// NFR-4). A route that stops resolving later is still answered here; dropping it from a rendered
/// list is the client's job.</p>
/// <p><b>An empty route is never stored.</b> Home declares it, and a screen a user is already
/// looking at is not one they pin; more to the point IRIS SQL stores an empty <code>%String</code> as
/// <code>NULL</code>, so an empty <property>OcuPilot.Kernel.State.Pref.Name</property> could be
/// written and never matched again by the key lookup that removes it.</p>
Class OcuPilot.Api.Preferences Extends %RegisteredObject
{

/// <p>The body member naming which list a write is about.</p>
Parameter KINDMEMBER As %String = "kind";

/// <p>The body member naming what to do to it.</p>
Parameter ACTIONMEMBER As %String = "action";

/// <p>The body member naming the screen route, and the field a route or limit refusal lands
/// on.</p>
Parameter ROUTEMEMBER As %String = "route";

/// <p>The two actions that name a route.</p>
Parameter ACTIONADD As %String = "add";

Parameter ACTIONREMOVE As %String = "remove";

/// <p>The one action that must not name a route.</p>
Parameter ACTIONCLEAR As %String = "clear";

/// <p>The authenticated caller, as <code>$USERNAME</code> reads it.</p>
ClassMethod CallerUsername() As %String
{
    Quit $Username
}

/// <p>Answer <code>GET /account/preferences</code>:
/// <code>{"favorites":[{"route"}],"recents":[{"route"}]}</code>, favorites oldest-first and
/// recents newest-first, each capped by the store.</p>
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

/// <p>Answer <code>POST /account/preferences {kind, action, route}</code>: apply the change and
/// answer the same body <method>HandleRead</method> would.</p>
/// <p>A body carrying anything else -- missing, badly typed, an extra member, or a value outside
/// its enum -- is refused 422 <parameter>OcuPilot.Api.Error.PREFERENCESBODY</parameter> before
/// anything is written. A route that is not a built screen's is 422
/// <parameter>OcuPilot.Api.Error.PREFERENCESROUTE</parameter> on <code>route</code>, and a
/// twenty-first favorite is 422 <parameter>OcuPilot.Api.Error.PREFERENCESLIMIT</parameter> on the
/// same field.</p>
/// <p><b>Only an <parameter>ACTIONADD</parameter> requires a built screen's route.</b> A
/// <parameter>ACTIONREMOVE</parameter> takes any string and is the one way out of a row whose
/// screen stopped resolving -- which the client drops from its rendering (AD-37) and could
/// otherwise never remove. A route no row holds is the documented no-op answering 200.</p>
ClassMethod HandleUpdate() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tRequestBody, .tStage)
        If $$$ISERR(tReadSC) {
            ; A read or decode fault is the server's, not the caller's, so the raw status reaches
            ; the log before the refusal is rendered (Api/Account.RenderBodyRefusal's shape). The
            ; preferences body carries no secret, so the stage is logged with it.
            Do ##class(OcuPilot.Kernel.Fault).LogRaw("preferences", "preferences body refused", $$$ERROR($$$GeneralError, "the preferences body was refused at the " _ tStage _ " stage"), ##class(OcuPilot.Api.Error).#PREFERENCESBODY)
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
            If (tKey '= ..#KINDMEMBER) && (tKey '= ..#ACTIONMEMBER) && (tKey '= ..#ROUTEMEMBER) Set tExtra = 1
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
        Set tNamesRoute = (tAction '= ..#ACTIONCLEAR)
        Set tHasRoute = (tRequestBody.%GetTypeOf(..#ROUTEMEMBER) '= "unassigned")
        If tNamesRoute && (tRequestBody.%GetTypeOf(..#ROUTEMEMBER) '= "string") {
            Set tSC = ..RenderBodyRefusal()
            Quit
        }
        If 'tNamesRoute && tHasRoute {
            Set tSC = ..RenderBodyRefusal()
            Quit
        }
        Set tRoute = ""
        If tNamesRoute {
            Set tRoute = tRequestBody.%Get(..#ROUTEMEMBER)
            ; The registry gates what may be stored, never what may be removed: a row whose screen
            ; stopped resolving is dropped from the client's rendering (AD-37) and would otherwise
            ; be unremovable, holding one of the favorites slots for good.
            If (tAction = ..#ACTIONADD) && '..IsBuiltRoute(tRoute) {
                Set tSC = ..RenderViolation(##class(OcuPilot.Api.Error).#PREFERENCESROUTE)
                Quit
            }
        }
        Set tRequestBody = ""

        Set tUser = ..CallerUsername()
        Set tApplySC = ..Apply(tUser, tKind, tAction, tRoute, .tAtLimit)
        If $$$ISERR(tApplySC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tApplySC))
            Quit
        }
        If tAtLimit {
            Set tSC = ..RenderViolation(##class(OcuPilot.Api.Error).#PREFERENCESLIMIT)
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
/// everything past <parameter>OcuPilot.Kernel.State.Pref.RECENTMAX</parameter> is deleted.</p>
ClassMethod Apply(pUser As %String, pKind As %String, pAction As %String, pRoute As %String, Output pAtLimit As %Boolean) As %Status [ Private ]
{
    Set pAtLimit = 0
    If pAction = ..#ACTIONCLEAR {
        Quit ##class(OcuPilot.Kernel.State.Pref).GuardedClear(pUser, pKind)
    }
    If pAction = ..#ACTIONREMOVE {
        Quit ##class(OcuPilot.Kernel.State.Pref).GuardedRemove(pUser, pKind, pRoute)
    }
    If pKind = ##class(OcuPilot.Kernel.State.Pref).#KINDRECENT {
        Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedTouch(pUser, pKind, pRoute)
        If $$$ISERR(tSC) Quit tSC
        Quit ##class(OcuPilot.Kernel.State.Pref).GuardedTrim(pUser, pKind, ##class(OcuPilot.Kernel.State.Pref).#RECENTMAX)
    }
    Quit ##class(OcuPilot.Kernel.State.Pref).GuardedAdd(pUser, pKind, pRoute, ##class(OcuPilot.Kernel.State.Pref).#FAVORITEMAX, .pAtLimit)
}

/// <p>The body both verbs answer: <code>{favorites, recents}</code>, each an array of
/// <code>{route}</code>.</p>
ClassMethod Body(pUser As %String, Output pBody As %DynamicObject) As %Status [ Private ]
{
    Set pBody = ""
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedListForUser(pUser, ##class(OcuPilot.Kernel.State.Pref).#KINDFAVORITE, .tFavorites)
        If $$$ISERR(tSC) Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Pref).GuardedListForUser(pUser, ##class(OcuPilot.Kernel.State.Pref).#KINDRECENT, .tRecents)
        If $$$ISERR(tSC) Quit
        Set pBody = {}
        Do pBody.%Set("favorites", ..Routes(tFavorites))
        Do pBody.%Set("recents", ..Routes(tRecents))
    } Catch ex {
        Set pBody = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><var>pRows</var> narrowed to the one member the wire carries. The store also answers each
/// row's timestamp, which is what orders the list; the client renders order, never the stamp, so
/// it does not leave the instance.</p>
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

/// <p>Whether <var>pKind</var> is one of the two lists this route serves.</p>
ClassMethod IsKnownKind(pKind As %String) As %Boolean [ Private ]
{
    If pKind = ##class(OcuPilot.Kernel.State.Pref).#KINDFAVORITE Quit 1
    If pKind = ##class(OcuPilot.Kernel.State.Pref).#KINDRECENT Quit 1
    Quit 0
}

/// <p>Whether <var>pAction</var> is one of the three this route performs.</p>
ClassMethod IsKnownAction(pAction As %String) As %Boolean [ Private ]
{
    If pAction = ..#ACTIONADD Quit 1
    If pAction = ..#ACTIONREMOVE Quit 1
    If pAction = ..#ACTIONCLEAR Quit 1
    Quit 0
}

/// <p>Whether <var>pRoute</var> is a built screen's declared route, and short enough to store.
/// Asked of an <parameter>ACTIONADD</parameter> alone.</p>
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

/// <p>Refuse with <b>one</b> 422 carrying a single violation on <code>route</code> under
/// <var>pCode</var> (AD-39). The sentence is
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s, so the refusal copy is written once
/// on the server.</p>
ClassMethod RenderViolation(pCode As %String) As %Status [ Private ]
{
    Set tViolations = 1
    Set tViolations(1) = $ListBuild(..#ROUTEMEMBER, pCode, "")
    Set tDetail = {}
    Do tDetail.%Set("violations", ##class(OcuPilot.Kernel.AgentRules).ViolationsJson(.tViolations))
    Quit ##class(OcuPilot.Api.Error).Render(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.Error).ReasonForViolation(pCode), pCode, tDetail)
}

}
