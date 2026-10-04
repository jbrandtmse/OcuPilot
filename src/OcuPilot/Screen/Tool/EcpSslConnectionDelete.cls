/// <p>ECP application servers' SSL/TLS authorization delete (Story 18.21, AD-6, AD-8, AD-51, AD-53):
/// propose removing one authorized SSL/TLS computer name, so the application server that presents that
/// certificate must be authorized again the next time it connects. Two callers reach it: the SSL/TLS
/// authorizations tab's Delete row action, through the typed-name dialog, and the agent's proposal and
/// confirmation. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>DELETE</code> reads no body and takes the
/// name as <code>name</code>. The fresh read is the vendor's <code>LIST</code> row whose
/// <code>SSLComputerName</code> is the id, compared exactly (measured at Task 0). The vendor answers OK for
/// any name, so a row that does not read <code>Authorized</code> is refused in <method>StateDiff</method>,
/// on both callers, before anything is sent, with
/// <parameter>NOTAUTHORIZEDREASON</parameter>; the card lists the name it
/// removes. Its fingerprint covers the row's <code>Status</code>.</p>
/// <p><b>Its pairs</b> are the tab's and <code>%DB_IRISSYS:WRITE</code>: without it the vendor's delete
/// fails <code>&lt;PROTECT&gt;</code> on <code>^SYS("ECPSSL","Authorized",...)</code> and keeps the row
/// (measured at Task 0). It is destructive. No vendor event records it (AD-15, AD-53).</p>
Class OcuPilot.Screen.Tool.EcpSslConnectionDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.ecpsslconnections.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EcpSslConnectionTab";

Parameter DESCRIPTION = "Propose deleting one authorized ECP application server SSL/TLS name, so the application server that presents that certificate must be authorized again the next time it connects; its current connection is not affected. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the SSL computer name exactly as the SSL/TLS authorizations list reports it. Only a name that reads Authorized can be deleted.";

/// <p>The port the tab's actions go through (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.EcpPort";

/// <p>The fresh read: the vendor's list, filtered to the one row by its exact name.</p>
Parameter READTYPE = "LIST";

Parameter READROWKEY = "SSLComputerName";

Parameter READROWKEYEXACT As BOOLEAN = 1;

/// <p>What this tool's own list row answers.</p>
Parameter READANSWERS = "SSLComputerName,ClientIP,Status";

Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted authorization is gone, and OcuPilot keeps no copy.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The row action the SSL/TLS authorizations tab's Delete carries out (AD-53).</p>
Parameter SCREENACTIONS = "delete";

/// <p>The field the action's precondition reads, and what the user reviewed: this row, in this
/// state.</p>
Parameter PRECONDITIONFIELD = "Status";

Parameter FINGERPRINTSUBJECT = "Status";

/// <p>The status the action needs, and the refusal of a row in any other, published once and pinned
/// equal to <parameter>OcuPilot.Api.EcpError.REASONSSLNOTAUTHORIZED</parameter> and to the
/// <code>ecp-ssl-authorized</code> rule's reason.</p>
Parameter NEEDEDSTATUS = "Authorized";

Parameter NOTAUTHORIZEDREASON = "This application server is not authorized.";

/// <p>The rows the card lists.</p>
Parameter REMOVALROWS = "SSLComputerName";

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
        Do tProperties.%Get(..IdArgument()).%Set("description", "The authorized SSL computer name to delete, the certificate's distinguished name, exactly as this instance's SSL/TLS authorizations list reports it, case included. A name the list does not report is refused.", "string")
    }
    Quit tSchema
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// <parameter>REMOVALROWS</parameter> name, carrying the value the instance holds and no after-state. A
/// row that does not read <parameter>NEEDEDSTATUS</parameter> is <var>pProblem</var>,
/// <parameter>NOTAUTHORIZEDREASON</parameter>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") || (pFresh.%Get(..#PRECONDITIONFIELD) '= ..#NEEDEDSTATUS) {
            Set pProblem = ..#NOTAUTHORIZEDREASON
            Quit
        }
        Set tNames = $ListFromString(..#REMOVALROWS)
        For tI = 1:1:$ListLength(tNames) {
            Set tField = $List(tNames, tI)
            Set tRow = {}
            Do tRow.%Set("field", tField, "string")
            Do tRow.%Set("before", ##class(OcuPilot.Kernel.Proposal.Mint).Display(pFresh.%Get(tField), pFresh.%GetTypeOf(tField)), "string")
            Do tRow.%Set("after", "", "string")
            Do tRow.%Set("removed", 1, "boolean")
            Do pRows.%Push(tRow)
        }
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>What the caller must hold: the tab's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each once. The delete runs
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
