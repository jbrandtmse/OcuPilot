/// <p>The OAuth 2.0 screen's add-mapping tool (AD-51, AD-56 (ii)): propose that one resource server
/// validate tokens for a Web Gateway application or an ODBC/JDBC namespace. It reads the server's
/// service mappings fresh through <class>OcuPilot.Port.OAuthResourceServerPort</class>'s
/// <code>MAPPINGS</code> read and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the tool sends no body, and the port builds the vendor's
/// mapping call from <code>Service</code> and <code>Key</code>, which travel in the port query
/// (<method>PortQuery</method>). Its target is the resource server, and so is its change event.</p>
/// <p><b>A mapping another server holds is moved, never refused</b>: the vendor's upsert reassigns it.
/// The move is the kernel's named effect (<parameter>OcuPilot.Kernel.Proposal.Prohibited.EFFECTMAPPINGMOVE</parameter>),
/// so the proposal is minted destructive and its card names the previous holder. The fingerprint
/// covers this server's mappings and every holder, so a mapping moved by anyone between the mint and
/// the confirm refuses the confirm.</p>
Class OcuPilot.Screen.Tool.OAuthResourceServerAddMapping Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.oauthresourceservers.addmapping";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.OAuthResourceServerTab";

Parameter DESCRIPTION = "Propose that one OAuth 2.0 resource server on this instance validates the access tokens of a Web Gateway application (Service %Service_WebGateway, Key its name) or of an ODBC/JDBC namespace (Service %Service_Bindings, Key the namespace). Key * maps every application or namespace of that service. It changes nothing by itself: it answers a proposal the user reviews and confirms. A mapping another resource server holds is moved to this one, and the card says so.";

/// <p>The port's mapping read and its mapping write (AD-51, AD-52).</p>
Parameter READTYPE = "MAPPINGS";

Parameter WRITETYPE = "ADDMAPPING";

Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>The top-level names the <code>MAPPINGS</code> read answers.</p>
Parameter READANSWERS = "IssuerEndpoint,Mappings,Held,Service,Key";

/// <p>What the precondition reads: which server holds the mapping.</p>
Parameter PRECONDITIONFIELD = "Held";

/// <p>This server's mappings, every holder, and the mapping named, which the port query and the
/// move effect read from the stored payload.</p>
Parameter FINGERPRINTSUBJECT = "Mappings,Held,Service,Key";

Parameter PORTCLASS = "OcuPilot.Port.OAuthResourceServerPort";

Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

/// <p>The two arguments: the service and the key the mapping names.</p>
Parameter SERVICEFIELD = "Service";

Parameter KEYFIELD = "Key";

/// <p>Which way the rules read the mapping.</p>
Parameter MAPPINGMODE = "add";

ClassMethod Endpoint() As %String
{
    Quit "Security.OAuth2.ResourceServer"
}

/// <p><parameter>SERVICEFIELD</parameter> and <parameter>KEYFIELD</parameter> alone: the tool sends no
/// body, and the two reach the port through <method>PortQuery</method>.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#SERVICEFIELD, ..#KEYFIELD)
}

/// <p>The identifying property, and the service and key, required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", "The resource server, by its name exactly as the resource servers list reports it.", "string")
    Set tService = {"type": "string", "enum": []}
    Set tServices = $Parameter(..#PORTCLASS, "SERVICES")
    For tI = 1:1:$Length(tServices, ",") Do tService.%Get("enum").%Push($Piece(tServices, ",", tI))
    Do tService.%Set("description", "%Service_WebGateway for a Web Gateway application, %Service_Bindings for an ODBC/JDBC namespace.", "string")
    Do tProperties.%Set(..#SERVICEFIELD, tService)
    Do tProperties.%Set(..#KEYFIELD, {"type": "string", "description": "The web application's name or the namespace, exactly as this instance's lists report it, or * for every one of that service. At most 64 characters."})
    Do tSchema.%Get("required").%Push(..#SERVICEFIELD)
    Do tSchema.%Get("required").%Push(..#KEYFIELD)
    Quit tSchema
}

/// <p>The stored payload's service and key, under the port's own query keys, so the confirm's write
/// and the Save's carry the mapping the user reviewed (AD-52).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#SERVICEFIELD) = "string" Set pQuery($Parameter(..#PORTCLASS, "SERVICEQUERY")) = pPayload.%Get(..#SERVICEFIELD)
    If pPayload.%GetTypeOf(..#KEYFIELD) = "string" Set pQuery($Parameter(..#PORTCLASS, "KEYQUERY")) = pPayload.%Get(..#KEYFIELD)
}

/// <p>The kernel's merge of the service and key over the <code>MAPPINGS</code> read, with the card's
/// rows replaced by <method>MappingRows</method>'s: this server's mappings before and after, and for a
/// move the previous holder.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Merge(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set pDiff = ..MappingRows($Select($IsObject(pArgs): pArgs.%Get(pIdArgument), 1: ""), pFresh, pPayload)
    Quit $$$OK
}

/// <p>The card's rows for server <var>pName</var>'s mapping named by <var>pPayload</var> over the
/// <code>MAPPINGS</code> read <var>pFresh</var>.</p>
ClassMethod MappingRows(pName As %String, pFresh As %DynamicObject, pPayload As %DynamicObject) As %DynamicArray
{
    Set tRules = "OcuPilot.Area.Security.OAuthResourceServerRules"
    Set tRows = []
    Set tMapping = $ClassMethod(..#PORTCLASS, "MappingName", pPayload.%Get(..#SERVICEFIELD), pPayload.%Get(..#KEYFIELD))
    Set tBefore = $ClassMethod(tRules, "MappingList", pFresh.%Get("Mappings"))
    Set tAfter = tBefore
    Set tFound = $ListFind(tAfter, tMapping)
    If ..#MAPPINGMODE = "add" {
        If 'tFound Set tAfter = tAfter _ $ListBuild(tMapping)
    } ElseIf tFound {
        Set tAfter = $List(tAfter, 1, tFound - 1) _ $List(tAfter, tFound + 1, *)
    }
    Set tRow = {}
    Do tRow.%Set("field", "Mappings", "string")
    Do tRow.%Set("before", $ListToString(tBefore, ", "), "string")
    Do tRow.%Set("after", $ListToString(tAfter, ", "), "string")
    Do tRows.%Push(tRow)
    Set tHolder = ""
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Held") = "object") && (pFresh.%Get("Held").%GetTypeOf(tMapping) = "string") Set tHolder = pFresh.%Get("Held").%Get(tMapping)
    If (..#MAPPINGMODE = "add") && (tHolder '= "") && (tHolder '= pName) {
        Set tRow = {}
        Do tRow.%Set("field", "Held", "string")
        Do tRow.%Set("before", tHolder, "string")
        Do tRow.%Set("after", pName, "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>No state row: <method>MergeUpdate</method>'s rows are the card's. A read that answered no
/// <parameter>PRECONDITIONFIELD</parameter> object is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Held") '= "object") || (pFresh.%GetTypeOf("Mappings") '= "array") {
        Set pProblem = "this instance did not report that resource server's service mappings, so none is changed"
    }
    Quit $$$OK
}

/// <p>The editor's own mapping rules over the agent's arguments, read against this tool's own
/// <code>MAPPINGS</code> read of <var>pIdValue</var> (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit $Select(+$Get(tHttp) = 404: $$$OK, 1: tSC)
    Set tRules = "OcuPilot.Area.Security.OAuthResourceServerRules"
    Set tSC = $ClassMethod(tRules, "MappingViolations", pIdValue, pArgs.%Get(..#SERVICEFIELD), pArgs.%Get(..#KEYFIELD), ..#MAPPINGMODE, $Get(tFresh), "", .tViolations)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = $ClassMethod(tRules, "Problem", .tViolations)
    Quit $$$OK
}

/// <p>The kernel-owned consequence of this payload: the move effect when
/// <method>OcuPilot.Kernel.Proposal.Prohibited.WeakensByEffect</method> answered it, and
/// <code>""</code> otherwise.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If pEffect = ##class(OcuPilot.Kernel.Proposal.Prohibited).#EFFECTMAPPINGMOVE Quit pEffect
    Quit ""
}

ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
