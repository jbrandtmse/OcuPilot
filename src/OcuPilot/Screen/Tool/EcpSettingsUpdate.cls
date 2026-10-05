/// <p>ECP settings' edit (Story 18.21, AD-4, AD-6, AD-52, AD-55): propose a change to how this instance
/// acts as an ECP application server and as an ECP data server. It reads the settings fresh through
/// <class>OcuPilot.Port.EcpPort</class>, merges the arguments over that read member by member and mints a
/// proposal the user confirms; the screen's Save (<class>OcuPilot.Area.OsMgmt.EcpSettingsSave</class>) is
/// its second caller. It writes nothing.</p>
/// <p><b>The first merge over a nested body</b> (AD-4): its two arguments are the objects
/// <code>AppServerSettings</code> and <code>DataServerSettings</code>, each merged member by member over the
/// fresh read's own, as <class>OcuPilot.Screen.Tool.LanguageServerUpdate</class> merges
/// <code>Custom</code>, with one <code>&lt;Object&gt;.&lt;member&gt;</code> diff row per member that
/// changes. The body is both objects complete: an unchanged member stores nothing, writes no event and sets
/// no pending restart (measured at Story 18.21's Task 0).</p>
/// <p><b>Every value is refused before the port is touched</b>
/// (<class>OcuPilot.Area.OsMgmt.EcpSettingsRules</class>), because the vendor's <code>PUT</code> does not
/// stop at a refused member; the port also refuses SSL/TLS without an enabled <code>%ECPServer</code> and
/// fewer data servers than the instance defines. A changed maximum number of application servers carries
/// <parameter>RESTARTCONSEQUENCE</parameter>: it takes effect only after the instance
/// restarts, and nothing claims it applied.</p>
/// <p><b>Its pairs</b> are ECP settings' own three and <code>%DB_IRISSYS:WRITE</code>, which the vendor's
/// <code>Config.ECP</code> and <code>Config.config</code> writes need (AD-8, measured at Task 0), refused
/// by name before any port call. The descriptor's own classic page performs the save, so it names no
/// other (AD-44).</p>
Class OcuPilot.Screen.Tool.EcpSettingsUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.ecpsettings.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EcpSettings";

Parameter DESCRIPTION = "Propose a change to this instance's ECP settings: as an ECP application server, the maximum number of data servers, the seconds to wait for recovery and the seconds between reconnections; as an ECP data server, the maximum number of application servers, the seconds before a data server is Troubled, and ECP SSL/TLS support. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal 'SYSTEM' as the name and only the members to change, inside AppServerSettings and DataServerSettings. A changed maximum number of application servers takes effect only after the instance restarts.";

/// <p>The port that sequences the settings read and write (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.EcpPort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The two object arguments, the only names this tool sets
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names them).</p>
Parameter PERMITTEDFIELDS = "AppServerSettings,DataServerSettings";

/// <p>The pair this tool requires beyond ECP settings' own (AD-8).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The rules this tool applies.</p>
Parameter RULES = "OcuPilot.Area.OsMgmt.EcpSettingsRules";

/// <p>The consequence a changed <parameter>RESTARTMEMBER</parameter> carries, pinned equal to
/// <parameter>OcuPilot.Api.EcpError.SETTINGSRESTART</parameter>; the card renders its published
/// sentence.</p>
Parameter RESTARTCONSEQUENCE = "ECP.SETTINGS.RESTART";

/// <p>The member whose change needs a restart, and the object it is in.</p>
Parameter RESTARTGROUP = "DataServerSettings";

Parameter RESTARTMEMBER = "MaxServerConn";

/// <p>The agent's own words, which the rules do not judge as settings.</p>
Parameter WORDARGUMENTS = "rationale,expectedImpact,reverse";

ClassMethod Endpoint() As %String
{
    Quit "ECP.Settings"
}

/// <p>The two object arguments: the kernel's field rows skip a dotted path, so they are named here.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The schema: the identifying property as the singleton's literal id, and the two objects described
/// in prose, member by member, with each range.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "Send the literal 'SYSTEM': the instance has one set of ECP settings.", "string")
    Set tApp = {"type": "object"}
    Do tApp.%Set("description", "This instance as an ECP application server, only the members to change, each a number: MaxServers, the maximum number of data servers, a whole number from 0 to 254 and at least the number of data servers the instance defines; ClientReconnectDuration, the seconds to wait for recovery, from 10 to 65535; ClientReconnectInterval, the seconds between reconnections, from 1 to 60.", "string")
    Do tProperties.%Set("AppServerSettings", tApp)
    Set tData = {"type": "object"}
    Do tData.%Set("description", "This instance as an ECP data server, only the members to change, each a number: MaxServerConn, the maximum number of application servers, a whole number from 0 to 254, which takes effect only after the instance restarts; ServerTroubleDuration, the seconds before a data server is Troubled, from 20 to 65535; SSLECPServer, ECP SSL/TLS support, 0 Disabled, 1 Enabled or 2 Required, where 1 and 2 need the %ECPServer SSL/TLS configuration created and enabled.", "string")
    Do tProperties.%Set("DataServerSettings", tData)
    Quit tSchema
}

/// <p>The names a call carries beside the two objects: the identifying property and the agent's own
/// words.</p>
ClassMethod Ignored() As %List
{
    Quit $ListBuild(..IdArgument()) _ $ListFromString(..#WORDARGUMENTS)
}

/// <p>The merge over the fresh read <var>pFresh</var>: the rules first, then each object
/// <var>pArgs</var> carries merged member by member over the read's own, one
/// <code>&lt;Object&gt;.&lt;member&gt;</code> row per member that changes. The payload is both objects
/// complete, each member a number; <var>pUnchanged</var> counts the objects no row names.</p>
/// <p><b>Caller contract:</b> called by the mint, by the confirm's fingerprint re-merge and by the Save,
/// so the three take one payload, one digest and one refusal.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ""
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        Set tSC = $ClassMethod(..#RULES, "Problem", pArgs, .pProblem, ..Ignored())
        If $$$ISERR(tSC) || (pProblem '= "") Quit
        If '$IsObject(pFresh) || 'pFresh.%IsA("%Library.DynamicObject") {
            Set tSC = $$$ERROR($$$GeneralError, "the ECP settings read answered no object")
            Quit
        }
        Set tPayload = {}
        Kill tSeen
        For tI = 1:1:$ListLength(pSettable) {
            Set tGroup = $List(pSettable, tI)
            Set tMembers = $ClassMethod(..#RULES, "Members", tGroup)
            If tMembers = "" Continue
            Set tHeld = $Select(pFresh.%GetTypeOf(tGroup) = "object": pFresh.%Get(tGroup), 1: {})
            Set tMerged = {}
            For tJ = 1:1:$ListLength(tMembers) {
                Set tMember = $List(tMembers, tJ)
                Do ..CopyMember(tHeld, tMember, tMerged)
            }
            If $IsObject(pArgs) && (pArgs.%GetTypeOf(tGroup) = "object") {
                Set tSupplied = pArgs.%Get(tGroup)
                For tJ = 1:1:$ListLength(tMembers) {
                    Set tMember = $List(tMembers, tJ)
                    If tSupplied.%GetTypeOf(tMember) = "unassigned" Continue
                    Set tBefore = ##class(OcuPilot.Kernel.Proposal.Mint).Display(tHeld.%Get(tMember), tHeld.%GetTypeOf(tMember))
                    Set tAfter = ##class(OcuPilot.Kernel.Proposal.Mint).Display(tSupplied.%Get(tMember), tSupplied.%GetTypeOf(tMember))
                    If tAfter = tBefore Continue
                    Do tMerged.%Set(tMember, +tSupplied.%Get(tMember), "number")
                    Set tRow = {}
                    Do tRow.%Set("field", tGroup _ "." _ tMember, "string")
                    Do tRow.%Set("before", tBefore, "string")
                    Do tRow.%Set("after", tAfter, "string")
                    Do pDiff.%Push(tRow)
                    Set tSeen(tGroup) = ""
                }
            }
            Do tPayload.%Set(tGroup, tMerged)
            If '$Data(tSeen(tGroup)) Set pUnchanged = pUnchanged + 1
        }
        Set pPayload = tPayload
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

/// <p>Copy <var>pFrom</var>'s member <var>pMember</var> to <var>pTo</var>, a number as a number and
/// anything else as the instance answered it; an absent member is not copied.</p>
ClassMethod CopyMember(pFrom As %DynamicObject, pMember As %String, pTo As %DynamicObject) [ Private ]
{
    Set tType = pFrom.%GetTypeOf(pMember)
    If (tType = "unassigned") || (tType = "null") Quit
    If (tType = "number") || (tType = "string") || (tType = "boolean") {
        Do pTo.%Set(pMember, pFrom.%Get(pMember), tType)
        Quit
    }
    Do pTo.%Set(pMember, pFrom.%Get(pMember))
}

/// <p>The rules over the agent's arguments (AD-55), then the port's own refusals of what they ask for:
/// SSL/TLS without an enabled <code>%ECPServer</code>, and fewer data servers than the instance
/// defines, each read as the caller through this tool's port.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $ClassMethod(..#RULES, "Problem", pArgs, .pProblem, ..Ignored())
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tSC = $ClassMethod(..PortClass(), "SettingsRefusal", pArgs, .tField, .tCode, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    If tCode '= "" Set pProblem = "'" _ tField _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
    Quit $$$OK
}

/// <p><parameter>RESTARTCONSEQUENCE</parameter> when the payload's
/// <parameter>RESTARTGROUP</parameter>.<parameter>RESTARTMEMBER</parameter> differs from the value the
/// instance holds now, read as the caller through this tool's port, and <code>""</code> otherwise. Nothing
/// claims such a change applied.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If '$IsObject(pPayload) || (pPayload.%GetTypeOf(..#RESTARTGROUP) '= "object") Quit ""
    If pPayload.%Get(..#RESTARTGROUP).%GetTypeOf(..#RESTARTMEMBER) = "unassigned" Quit ""
    Set tSent = pPayload.%Get(..#RESTARTGROUP).%Get(..#RESTARTMEMBER)
    Kill tQuery
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tHeld, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tHeld)) || (tHeld.%GetTypeOf(..#RESTARTGROUP) '= "object") Quit ..#RESTARTCONSEQUENCE
    If (tSent _ "") = (tHeld.%Get(..#RESTARTGROUP).%Get(..#RESTARTMEMBER) _ "") Quit ""
    Quit ..#RESTARTCONSEQUENCE
}

/// <p>What the caller must hold: ECP settings' own pairs, then
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, then the custom resource
/// of each <parameter>CLASSICPAGES</parameter> page, each pair once (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
