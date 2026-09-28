/// <p>One account's effective privileges, for the user editor's Effective privileges tab (Story 16.3,
/// FR-74, AD-8): <class>OcuPilot.Kernel.Shell.Effective</class>'s one composition over the account's
/// <code>Roles</code>, never its <code>EscalationRoles</code>, and what the resources it holds guard
/// in the Web applications, Databases and Services screens' own reads.</p>
/// <p><b>Every part is read as the caller</b> (AD-8, AD-29), through the owning screen's declared
/// read after that screen's pair gate. A part the caller cannot read answers <code>unchecked</code>
/// naming the pair it lacks, and a read cut at its cap answers <parameter>TRUNCATED</parameter>;
/// neither is ever reported as empty. The answer is names only and never enters screen context or
/// a tool result.</p>
Class OcuPilot.Kernel.Shell.EffectiveUser Extends %RegisteredObject
{

/// <p>The screen whose pairs gate the view: the user editor's.</p>
Parameter FORMDESCRIPTOR = "OcuPilot.Screen.Descriptor.UserForm";

Parameter WEBAPPDESCRIPTOR = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter DATABASEDESCRIPTOR = "OcuPilot.Screen.Descriptor.DatabaseList";

Parameter SERVICEDESCRIPTOR = "OcuPilot.Screen.Descriptor.ServiceList";

/// <p>The account read: <code>Security.User</code> <code>GET name=</code>.</p>
Parameter USERENDPOINT = "Security.User";

Parameter READTYPE = "GET";

Parameter IDPARAM = "name";

/// <p>The account field the composition starts from. Its escalation roles are never read.</p>
Parameter ROLESFIELD = "Roles";

/// <p>A section's <code>unchecked</code> when its read was cut at its cap.</p>
Parameter TRUNCATED = "truncated";

/// <p>The longest account name the instance stores (<class>%Library.Username</class>).</p>
Parameter NAMEMAXLENGTH As INTEGER = 160;

/// <p>The port the account is read through.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AdminPort"
}

/// <p>The effective privileges of account <var>pUser</var>, as
/// <code>{user, all, allVia, roles, resources, applications, databases, services}</code>, each
/// section <code>{rows, unchecked}</code>:</p>
/// <ul>
/// <li><code>roles</code>: <code>{name, through}</code> in closure order;</li>
/// <li><code>resources</code>: <code>{name, R?, W?, U?}</code> by name, each held letter naming the
/// role whose own grant it is, or <code>""</code> when public;</li>
/// <li><code>applications</code>: <code>{name, resource}</code>, each web application with a
/// <code>Resource</code> the account holds at <code>U</code>;</li>
/// <li><code>databases</code>: <code>{directory, resource, permissions}</code>, each database whose
/// <code>Resource</code> the account holds at <code>R</code>, <code>permissions</code>
/// <code>R</code> or <code>RW</code>;</li>
/// <li><code>services</code>: <code>{name}</code>, each service whose own name is a resource the
/// account holds at <code>U</code>.</li>
/// </ul>
/// <p>When <code>all</code> is true only <code>roles</code> is read. When the composition's own read
/// answers unchecked, every section carries that answer.</p>
/// <p>On success <var>pHttpStatus</var> is 200 and <var>pFault</var> <code>""</code>. A refusal is an
/// error status with the route's HTTP status and wire fault: 400 <code>TOOL.ARGUMENTS</code> for a
/// blank or overlong name, 403 <code>AUTH.NOPRIVILEGE</code> naming the pair the user editor's gate
/// lacks, 404 <code>USER.NAME.ABSENT</code>, or the port's own fault.</p>
ClassMethod Of(pUser As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Shell.Effective).Gate(..#FORMDESCRIPTOR, .tFailed)
        If $$$ISERR(tSC) Quit
        If tFailed '= "" {
            Set tSC = ..Denied(tFailed, .pHttpStatus, .pFault)
            Quit
        }
        If ($ZStrip(pUser, "<>W") = "") || ($Length(pUser) > ..#NAMEMAXLENGTH) {
            Set tSC = ..BadArgument("'name' is required and holds at most " _ ..#NAMEMAXLENGTH _ " characters", .pHttpStatus, .pFault)
            Quit
        }
        Kill tQuery
        Set tQuery(..#IDPARAM) = pUser
        Set tSC = $ClassMethod(..PortClass(), "Invoke", ..#USERENDPOINT, ..#READTYPE, .tQuery, "", .tAccount, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) || '$IsObject($Get(tAccount)) {
            If (+$Get(pHttpStatus) = 404) || $$$ISOK(tSC) Set tSC = ..Absent(.pHttpStatus, .pFault)
            Quit
        }
        Set tRoots = $Select(tAccount.%GetTypeOf(..#ROLESFIELD) = "array": tAccount.%Get(..#ROLESFIELD), 1: [])

        Set pAnswer = {}
        Do pAnswer.%Set("user", pUser, "string")
        Do pAnswer.%Set("all", 0, "boolean")
        Do pAnswer.%Set("allVia", "", "string")
        For tSection = "roles", "resources", "applications", "databases", "services" {
            Do pAnswer.%Set(tSection, ..Section())
        }

        Set tSC = ..EffectiveRead(tRoots, .tRows, .tPublic, .tUnchecked)
        If $$$ISERR(tSC) Quit
        If tUnchecked '= "" {
            For tSection = "roles", "resources", "applications", "databases", "services" {
                Do pAnswer.%Get(tSection).%Set("unchecked", tUnchecked, "string")
            }
            Set pHttpStatus = 200
            Quit
        }
        Set tComposed = ##class(OcuPilot.Kernel.Shell.Effective).Compose(tRoots, tRows, tPublic)
        Do pAnswer.%Get("roles").%Set("rows", tComposed.%Get("roles"))
        If tComposed.%Get("all") {
            Do pAnswer.%Set("all", 1, "boolean")
            Do pAnswer.%Set("allVia", tComposed.%Get("allVia"), "string")
            Set pHttpStatus = 200
            Quit
        }
        Do pAnswer.%Get("resources").%Set("rows", ..Resources(tComposed))
        Set tSC = ..Guarded(..#WEBAPPDESCRIPTOR, tComposed, pAnswer.%Get("applications"))
        If $$$ISERR(tSC) Quit
        Set tSC = ..Guarded(..#DATABASEDESCRIPTOR, tComposed, pAnswer.%Get("databases"))
        If $$$ISERR(tSC) Quit
        Set tSC = ..Guarded(..#SERVICEDESCRIPTOR, tComposed, pAnswer.%Get("services"))
        If $$$ISERR(tSC) Quit
        Set pHttpStatus = 200
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $$$ISERR(tSC) {
        Set pAnswer = ""
        If '$IsObject(pFault) {
            Set pHttpStatus = 500
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        }
    }
    Quit tSC
}

/// <p><method>OcuPilot.Kernel.Shell.Effective.Read</method> for <var>pRoots</var>. A seam, so a
/// fixture can answer role rows, public permissions or a cut read.</p>
ClassMethod EffectiveRead(pRoots As %DynamicArray, Output pRoleRows As %DynamicObject, Output pPublic As %DynamicObject, Output pUnchecked As %String) As %Status
{
    Quit ##class(OcuPilot.Kernel.Shell.Effective).Read(pRoots, .pRoleRows, .pPublic, .pUnchecked)
}

/// <p>The rows of <var>pDescriptor</var>'s declared read, after its pair gate, in <var>pRows</var>;
/// <var>pUnchecked</var> names the pair the caller lacks or <parameter>TRUNCATED</parameter>, and
/// <var>pRows</var> is then <code>""</code>. A seam, so a fixture can refuse a screen or answer
/// rows.</p>
ClassMethod ListRows(pDescriptor As %String, Output pRows As %DynamicArray, Output pUnchecked As %String) As %Status
{
    Set pRows = ""
    Set tSC = ##class(OcuPilot.Kernel.Shell.Effective).Gate(pDescriptor, .pUnchecked)
    If $$$ISERR(tSC) || (pUnchecked '= "") Quit tSC
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(pDescriptor, "", .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    If tResult.%Get("truncated") {
        Set pUnchecked = ..#TRUNCATED
        Quit $$$OK
    }
    Set pRows = tResult.%Get("rows")
    Quit $$$OK
}

/// <p>An empty section.</p>
ClassMethod Section() As %DynamicObject [ Private ]
{
    Set tSection = {}
    Do tSection.%Set("rows", [])
    Do tSection.%Set("unchecked", "", "string")
    Quit tSection
}

/// <p><var>pComposed</var>'s held resources as <code>[{name, R?, W?, U?}]</code> in name order,
/// each letter naming the role whose own grant it is, <code>""</code> when public.</p>
ClassMethod Resources(pComposed As %DynamicObject) As %DynamicArray [ Private ]
{
    Kill tSorted
    Set tRows = []
    Set tSources = pComposed.%Get("sources")
    Set tIterator = pComposed.%Get("resources").%GetIterator()
    While tIterator.%GetNext(.tResource, .tGranted) {
        If '$IsObject(tGranted) Continue
        Set tRow = {}
        Do tRow.%Set("name", tResource, "string")
        Set tBy = $Select($IsObject(tSources) && $IsObject(tSources.%Get(tResource)): tSources.%Get(tResource), 1: {})
        For tI = 1:1:$Length(##class(OcuPilot.Kernel.Shell.Effective).#LETTERS) {
            Set tLetter = $Extract(##class(OcuPilot.Kernel.Shell.Effective).#LETTERS, tI)
            If tGranted.%GetTypeOf(tLetter) = "unassigned" Continue
            Do tRow.%Set(tLetter, $Select(tGranted.%Get(tLetter) = "": "", 1: tBy.%Get(tLetter)), "string")
        }
        Set tSorted($ZConvert(tResource, "U"), tResource) = tRow
    }
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Set tSpelling = ""
        For {
            Set tSpelling = $Order(tSorted(tKey, tSpelling), 1, tRow)
            If tSpelling = "" Quit
            Do tRows.%Push(tRow)
        }
    }
    Quit tRows
}

/// <p>Fill <var>pSection</var> from <var>pDescriptor</var>'s declared read: the web applications
/// whose <code>Resource</code> <var>pComposed</var> holds at <code>U</code>, the databases whose
/// <code>Resource</code> it holds at <code>R</code>, or the services whose own <code>Name</code> it
/// holds at <code>U</code> (a service with no resource of its own name is gated by other means and
/// never listed), each in name order.</p>
ClassMethod Guarded(pDescriptor As %String, pComposed As %DynamicObject, pSection As %DynamicObject) As %Status [ Private ]
{
    Set tSC = ..ListRows(pDescriptor, .tRows, .tUnchecked)
    If $$$ISERR(tSC) Quit tSC
    If tUnchecked '= "" {
        Do pSection.%Set("unchecked", tUnchecked, "string")
        Quit $$$OK
    }
    If '$IsObject(tRows) Quit $$$OK
    Kill tSorted
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) Continue
        If pDescriptor = ..#WEBAPPDESCRIPTOR {
            Set tResource = tRow.%Get("Resource")
            If (tResource = "") || '##class(OcuPilot.Kernel.Shell.Effective).Holds(pComposed, tResource, "U").%Get("held") Continue
            Set tOne = {}
            Do tOne.%Set("name", tRow.%Get("Name"), "string")
            Do tOne.%Set("resource", tResource, "string")
            Set tSorted($ZConvert(tRow.%Get("Name"), "U"), tIndex) = tOne
        } ElseIf pDescriptor = ..#DATABASEDESCRIPTOR {
            Set tResource = tRow.%Get("Resource")
            If (tResource = "") || '##class(OcuPilot.Kernel.Shell.Effective).Holds(pComposed, tResource, "R").%Get("held") Continue
            Set tOne = {}
            Do tOne.%Set("directory", tRow.%Get("Directory"), "string")
            Do tOne.%Set("resource", tResource, "string")
            Do tOne.%Set("permissions", $Select(##class(OcuPilot.Kernel.Shell.Effective).Holds(pComposed, tResource, "W").%Get("held"): "RW", 1: "R"), "string")
            Set tSorted($ZConvert(tRow.%Get("Directory"), "U"), tIndex) = tOne
        } Else {
            Set tName = tRow.%Get("Name")
            If (tName = "") || '##class(OcuPilot.Kernel.Shell.Effective).Holds(pComposed, tName, "U").%Get("held") Continue
            Set tOne = {}
            Do tOne.%Set("name", tName, "string")
            Set tSorted($ZConvert(tName, "U"), tIndex) = tOne
        }
    }
    Set tOut = pSection.%Get("rows")
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Set tIndex = ""
        For {
            Set tIndex = $Order(tSorted(tKey, tIndex), 1, tOne)
            If tIndex = "" Quit
            Do tOut.%Push(tOne)
        }
    }
    Quit $$$OK
}

/// <p>403 <code>AUTH.NOPRIVILEGE</code> naming <var>pPair</var> (<class>OcuPilot.Kernel.Denial</class>).</p>
ClassMethod Denied(pPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = ##class(OcuPilot.Kernel.Denial).#STATUS
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Kernel.Denial).Slug(), ##class(OcuPilot.Kernel.Denial).Code(), ##class(OcuPilot.Kernel.Denial).Reason())
    Set tDetail = ##class(OcuPilot.Kernel.Denial).Detail(pPair)
    If $IsObject(tDetail) Do pFault.%Set("detail", tDetail)
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Kernel.Denial).Code() _ ": " _ pPair)
}

/// <p>404 <code>USER.NAME.ABSENT</code>.</p>
ClassMethod Absent(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 404
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#USERNAMEABSENT, ##class(OcuPilot.Api.Error).#REASONUSERNAMEABSENT)
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#USERNAMEABSENT)
}

/// <p>400 <code>TOOL.ARGUMENTS</code>, <var>pProblem</var> as <code>detail.problem</code>.</p>
ClassMethod BadArgument(pProblem As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 400
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, ##class(OcuPilot.Api.Error).#REASONTOOLARGUMENTS)
    Set tDetail = {}
    Do tDetail.%Set("problem", pProblem, "string")
    Do pFault.%Set("detail", tDetail)
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#TOOLARGUMENTS _ ": " _ pProblem)
}

}
