/// <p>ECP data servers' delete tool (AD-6, AD-8, AD-51, Story 18.20): propose removing one data server
/// from this instance's configuration. It reads the server fresh through the vendor's own
/// <code>ECP.DataServer</code> <code>GET</code> and mints a proposal whose card lists the address and
/// port it removes and whose impact names the remote databases that use it, read through Remote
/// databases' declared read (<class>OcuPilot.Kernel.Proposal.Impact</class>). It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>DELETE</code> reads no body, so the tool
/// admits no settable field. Its fingerprint covers the address and the port: a server's configuration
/// does not move by itself, so a change since the mint refuses the confirm. The vendor refuses the
/// delete while a remote database uses the server, which <class>OcuPilot.Port.EcpPort</class> answers
/// 409 <parameter>OcuPilot.Api.EcpError.INUSE</parameter>.</p>
Class OcuPilot.Screen.Tool.EcpDataServerDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.ecpdataservers.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EcpDataServerList";

Parameter DESCRIPTION = "Propose removing one ECP data server from this instance's configuration. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the server as the ECP data servers list reports it. The instance refuses the delete while a remote database uses the server.";

/// <p>The port that answers the vendor's in-use refusal (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.EcpPort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted server is gone from the configuration, and OcuPilot keeps no copy.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The row action the ECP data servers list's Delete carries out (AD-53).</p>
Parameter SCREENACTIONS = "delete";

/// <p>What <parameter>READTYPE</parameter> answers, read off the vendor's <code>ObjToJson</code>.</p>
Parameter READANSWERS = "Address,Port,MirrorConnection,SSLConfig,BatchMode";

Parameter PRECONDITIONFIELD = "Address";

Parameter FINGERPRINTSUBJECT = "Address,Port";

/// <p>The rows the card lists.</p>
Parameter REMOVALROWS = "Address,Port";

/// <p>The pair the write needs beyond the list's own
/// (<parameter>OcuPilot.Screen.Tool.EcpDataServerCreate.WRITERESOURCE</parameter>).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

ClassMethod Endpoint() As %String
{
    Quit "ECP.DataServer"
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
        Do tProperties.%Get(..IdArgument()).%Set("description", "The data server to delete, as this instance's own ECP data servers list reports it. A server this instance does not define is refused.", "string")
    }
    Quit tSchema
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per
/// <parameter>REMOVALROWS</parameter> name, carrying the value the instance holds and no after-state.
/// A read that answered no <parameter>PRECONDITIONFIELD</parameter> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf(..#PRECONDITIONFIELD) '= "string") {
            Set pProblem = "this instance did not report that data server's address, and a server whose address is unknown is not one to delete"
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

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each once. The delete
/// runs on the classic list page itself, so it declares no <code>CLASSICPAGES</code> (AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
