/// <p>License servers' delete tool (AD-6, AD-51, Story 18.6): propose removing one license server from
/// this instance's configuration. It reads the server fresh through the vendor's own
/// <code>License.Server</code> <code>GET</code> and mints a proposal whose card lists what would go. It
/// writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>DELETE</code> reads no body, so the tool
/// admits no settable field. Its fingerprint covers the address, the port and the key directory: a
/// server's configuration does not move by itself, so any change since the mint refuses the
/// confirm.</p>
/// <p><b>Its consequence names a multi-server key</b> (<method>Consequence</method>): when this
/// instance's license key reads <code>Server</code> <code>Multi</code>, removing a server it uses can
/// leave it unable to obtain license units (inference: never measured, every instance here is
/// Single).</p>
Class OcuPilot.Screen.Tool.LicenseServerDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.licenseservers.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LicenseServerList";

Parameter DESCRIPTION = "Propose removing one license server from this instance's configuration. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the server as the license servers list reports it.";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a deleted server is gone from the configuration, and OcuPilot keeps no copy.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The row action the License servers list's Delete carries out (AD-53).</p>
Parameter SCREENACTIONS = "delete";

/// <p>What <parameter>READTYPE</parameter> answers, read off the vendor's <code>ObjToJson</code>.</p>
Parameter READANSWERS = "Address,Port,KeyDirectory";

Parameter PRECONDITIONFIELD = "Address";

Parameter FINGERPRINTSUBJECT = "Address,Port,KeyDirectory";

/// <p>The rows the card lists.</p>
Parameter REMOVALROWS = "Address,Port";

/// <p>The pair the write needs beyond the list's own
/// (<parameter>OcuPilot.Screen.Tool.LicenseServerCreate.WRITERESOURCE</parameter>).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The consequence code a proposal carries when the license key is a multi-server key.</p>
Parameter CONSEQUENCEMULTIKEY = "LICENSE.SERVER.MULTIKEY";

/// <p>The license key's <code>Server</code> value that names a multi-server key.</p>
Parameter MULTISERVER = "Multi";

ClassMethod Endpoint() As %String
{
    Quit "License.Server"
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
        Do tProperties.%Get(..IdArgument()).%Set("description", "The license server to delete, as this instance's own license servers list reports it. A server this instance does not define is refused.", "string")
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
            Set pProblem = "this instance did not report that license server's address, and a server whose address is unknown is not one to delete"
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

/// <p><parameter>CONSEQUENCEMULTIKEY</parameter> when this instance's license key reads
/// <parameter>MULTISERVER</parameter> (<method>KeyServer</method>), and <code>""</code> otherwise or
/// when the key cannot be read.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If ..KeyServer() = ..#MULTISERVER Quit ..#CONSEQUENCEMULTIKEY
    Quit ""
}

/// <p>The license key's <code>Server</code> as the caller reads it through
/// <class>OcuPilot.Port.LicensePort</class>, or <code>""</code>.</p>
ClassMethod KeyServer() As %String
{
    Set tServer = ""
    Try {
        Kill tQuery
        Set tSC = ##class(OcuPilot.Port.LicensePort).Invoke(##class(OcuPilot.Port.LicensePort).#KEYENDPOINT, "GET", .tQuery, "", .tKey, .tHttp, .tFault)
        If $$$ISOK(tSC) && $IsObject($Get(tKey)) && (tKey.%GetTypeOf("Server") = "string") Set tServer = tKey.%Get("Server")
    } Catch {
        Set tServer = ""
    }
    Quit tServer
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
