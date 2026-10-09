/// <p>The percent-class access delete tool (AD-6, AD-8, AD-10, AD-51, Story 18.10): propose removing one class access
/// entry from a web application. It reads the entry fresh through <class>OcuPilot.Port.PctAccessPort</class>'s
/// <code>STATE</code> and mints a proposal whose card lists the access it removes. It writes nothing.</p>
/// <p><b>It is action-style</b> (AD-51): the vendor's <code>DELETE</code> reads no body, so the tool admits no settable
/// field, and its three id arguments are authored in its schema. An entry the instance marks as its own
/// (<code>System</code>) goes only with its application, so <method>StateDiff</method> refuses it
/// <code>PCTACCESS.SYSTEM</code> before anything is sent, and the port refuses it again on the call.</p>
Class OcuPilot.Screen.Tool.WebAppPctAccessDelete Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "webapp.pctaccess.delete";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WebAppPctAccessList";

Parameter DESCRIPTION = "Propose removing one percent-class access entry from a web application. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the entry by its web application, its allow type and its class, exactly as the Percent class access list shows them. An entry the instance marks as its own goes only with its application, so it cannot be removed here.";

Parameter PORTCLASS = "OcuPilot.Port.PctAccessPort";

Parameter READTYPE = "STATE";

Parameter WRITETYPE = "DELETE";

/// <p>No body: the vendor reads none for this type (AD-51).</p>
Parameter SENDSBODY As BOOLEAN = 0;

Parameter CHANGEACTION = "deleted";

/// <p>Declared: a removed entry no longer grants its access.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>The row action the percent-class access list's Delete carries out (AD-53).</p>
Parameter SCREENACTIONS = "delete";

/// <p>What <parameter>READTYPE</parameter> answers that the card lists.</p>
Parameter READANSWERS = "AllowAccess,System";

Parameter PRECONDITIONFIELD = "System";

Parameter FINGERPRINTSUBJECT = "AllowAccess,System";

Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "WebApp.PctClassAccess"
}

ClassMethod IdArgument() As %String
{
    Quit "Name"
}

ClassMethod IdParam() As %String
{
    Quit "name"
}

/// <p>None: the write sends no body (AD-51).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.WebAppPctAccessMint"
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ##class(OcuPilot.Screen.Tool.WebAppPctAccessCreate).Described(##super(pDescriptor))
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>. An entry the instance marks as
/// its own is a problem with the sentence <code>PCTACCESS.SYSTEM</code> carries, and no row is shown for it.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("System") = "unassigned") {
            Set pProblem = "this instance did not report whether that entry belongs to it, and an entry whose origin is unknown is not one to remove"
            Quit
        }
        If pFresh.%Get("System") = 1 {
            Set pProblem = ##class(OcuPilot.Port.PctAccessPort).SystemReason()
            Quit
        }
        Set tNames = ..ReadAnswers()
        For tI = 1:1:$ListLength(tNames) {
            Set tField = $List(tNames, tI)
            If pFresh.%GetTypeOf(tField) = "unassigned" Continue
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

ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
