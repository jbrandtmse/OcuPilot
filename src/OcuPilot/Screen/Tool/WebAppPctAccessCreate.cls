/// <p>The percent-class access create tool (AD-6, AD-8, AD-54, Story 18.10): propose adding one class access entry to a
/// web application. It reads the entry fresh through <class>OcuPilot.Port.PctAccessPort</class>'s <code>STATE</code>, so
/// the proposal fingerprints the entry's absence, and mints a proposal whose card lists the access it grants. It writes
/// nothing.</p>
/// <p>The vendor's <code>PUT</code> is an upsert, so the create fingerprints the entry's absence (AD-54): an entry the
/// instance already holds is refused by the mint, not overwritten. The classic dialog is
/// <code>%CSP.UI.Portal.Dialog.WebAppPctAccess</code> (AD-44).</p>
Class OcuPilot.Screen.Tool.WebAppPctAccessCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "webapp.pctaccess.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WebAppPctAccessList";

Parameter DESCRIPTION = "Propose giving a web application access to one percent class or package of classes. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the web application, as the Web applications list shows it, or all-applications for every application; the allow type, AllowClass for one class or AllowPrefix for a package; and the class or package name, which begins with a percent sign. An entry the instance already holds is refused.";

Parameter PORTCLASS = "OcuPilot.Port.PctAccessPort";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "STATE";

Parameter WRITETYPE = "PUT";

/// <p>The one settable field: the entry's access, which the vendor's body carries.</p>
Parameter PERMITTEDFIELDS = "AllowAccess";

Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.WebAppPctAccess";

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

ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.WebAppPctAccessMint"
}

/// <p>The derived schema with the entry's three id arguments described (AD-59's Snippet reads them from here).</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ..Described(##super(pDescriptor))
}

ClassMethod Described(pSchema As %DynamicObject) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    Do tProperties.%Set("Name", {"type": "string", "description": "The web application the entry applies to, as the Web applications list shows its name, or all-applications for every application."})
    Do tProperties.%Set("AllowType", {"type": "string", "description": "AllowClass to grant one class, or AllowPrefix to grant a package of classes."})
    Do tProperties.%Set("Class", {"type": "string", "description": "The class or package name, beginning with a percent sign, such as %Utility or %Utility.Example."})
    Quit pSchema
}

ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
