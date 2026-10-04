/// <p>ECP application servers' SSL/TLS authorize (Story 18.21, AD-6, AD-8, AD-51, AD-53): propose letting
/// the application server that presents a certificate connect to this instance over ECP. Two callers
/// reach it: the SSL/TLS authorizations tab's Authorize row action and the agent's proposal and
/// confirmation. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>AUTHORIZE</code> reads no body and takes the
/// SSL/TLS computer name as <code>name</code>. The fresh read is the vendor's
/// <code>ECP.AppServerSSLConnection</code> <code>LIST</code>, filtered to the row whose
/// <code>SSLComputerName</code> is the id, compared exactly, because the vendor stores and matches the
/// distinguished name as given (measured at Task 0). The vendor answers OK for any name, so a row that
/// does not read <code>Pending</code> is refused in <method>StateDiff</method>, on both callers, before
/// anything is sent, with <parameter>NOTPENDINGREASON</parameter>. Its
/// fingerprint covers the row's <code>Status</code>.</p>
/// <p><b>Its pairs</b> are the tab's and <code>%DB_IRISSYS:WRITE</code>: the vendor writes
/// <code>^SYS("ECPSSL")</code>, measured for the delete and inferred for this action from the same
/// structure (AD-8). It is not destructive; the screen confirms it with a warning stating
/// <parameter>CONSEQUENCECODE</parameter>'s sentence. No vendor event records it
/// (AD-15, AD-53).</p>
Class OcuPilot.Screen.Tool.EcpSslConnectionAuthorize Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.ecpsslconnections.authorize";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EcpSslConnectionTab";

Parameter DESCRIPTION = "Propose authorizing one ECP application server's pending SSL/TLS connection, so the application server that presents that certificate can connect to this instance over ECP. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the SSL computer name exactly as the SSL/TLS authorizations list reports it. Only a request that reads Pending can be authorized.";

/// <p>The port the tab's actions go through (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.EcpPort";

/// <p>The fresh read: the vendor's list, filtered to the one row by its exact name.</p>
Parameter READTYPE = "LIST";

Parameter READROWKEY = "SSLComputerName";

Parameter READROWKEYEXACT As BOOLEAN = 1;

/// <p>What this tool's own list row answers.</p>
Parameter READANSWERS = "SSLComputerName,ClientIP,Status";

Parameter WRITETYPE = "AUTHORIZE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "updated";

/// <p>The row action the SSL/TLS authorizations tab's Authorize carries out (AD-53).</p>
Parameter SCREENACTIONS = "authorize";

/// <p>The field the action's precondition reads, and what the user reviewed: this row, in this
/// state.</p>
Parameter PRECONDITIONFIELD = "Status";

Parameter FINGERPRINTSUBJECT = "Status";

/// <p>The status the action needs, and the refusal of a row in any other, published once and pinned
/// equal to <parameter>OcuPilot.Api.EcpError.REASONSSLNOTPENDING</parameter> and to the
/// <code>ecp-ssl-pending</code> rule's reason.</p>
Parameter NEEDEDSTATUS = "Pending";

Parameter NOTPENDINGREASON = "This application server is not waiting for authorization.";

/// <p>The consequence the card states, pinned equal to
/// <parameter>OcuPilot.Api.EcpError.SSLAUTHORIZE</parameter>.</p>
Parameter CONSEQUENCECODE = "ECP.SSL.AUTHORIZE";

/// <p>The pair the write needs beyond the tab's own (AD-8).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

ClassMethod Endpoint() As %String
{
    Quit "ECP.AppServerSSLConnection"
}

/// <p>The list's row key.</p>
ClassMethod IdArgument() As %String
{
    Quit "SSLComputerName"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p>The identifying property described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The application server's SSL computer name, the certificate's distinguished name, exactly as this instance's SSL/TLS authorizations list reports it, case included. A name the list does not report is refused.", "string")
    }
    Quit tSchema
}

/// <p>No row: the action moves the request out of the pending list, which the read can see. A row that
/// does not read <parameter>NEEDEDSTATUS</parameter> is <var>pProblem</var>,
/// <parameter>NOTPENDINGREASON</parameter>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") || (pFresh.%Get(..#PRECONDITIONFIELD) '= ..#NEEDEDSTATUS) {
        Set pProblem = ..#NOTPENDINGREASON
    }
    Quit $$$OK
}

/// <p><parameter>CONSEQUENCECODE</parameter>, the warning the card states.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

/// <p>What the caller must hold: the tab's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each once. The action runs
/// on the classic Application Servers page itself, so it declares no <code>CLASSICPAGES</code>
/// (AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
