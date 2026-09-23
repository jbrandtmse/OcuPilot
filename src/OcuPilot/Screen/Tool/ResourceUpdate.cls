/// <p>The Resources list's edit tool (AD-4, AD-6, AD-10, AD-55): propose a change to one resource's
/// description or public permission. It reads the resource fresh through the vendor's own
/// <code>Security.Resource</code> <code>GET</code>, merges the arguments over that object, and mints
/// a proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read with the changed fields applied, so a field
/// the arguments omit keeps the instance's value (AD-4). The fingerprint covers every field the
/// body sends. A public permission that adds a letter on an administrative resource is permitted and
/// confirmed as a delete is (AD-10); one that adds a letter on OcuPilot's own resources is refused at
/// the write.</p>
Class OcuPilot.Screen.Tool.ResourceUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "permissions.resources.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ResourceList";

Parameter DESCRIPTION = "Propose a change to one resource on this instance: its description, its public permission, or both. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the resource exactly as the resources list reports it, and send only the fields to change.";

/// <p>The fresh read and the write: the vendor's single-object read, and its <code>PUT</code>, which
/// modifies a present resource.</p>
Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The derived top-level fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names the same two).
/// A test asserts the two agree.</p>
Parameter PERMITTEDFIELDS = "Description,PublicPermission";

/// <p>The field whose description this tool writes: the letters every user holds.</p>
Parameter PUBLICPERMISSIONARGUMENT = "PublicPermission";

/// <p>The pair a change requires: <code>%Admin_Secure:USE</code>, the vendor endpoint's own
/// <code>ResourcesOR()</code> resource and one the Resources list already declares (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.Resource"
}

/// <p>The field names the merge may set: the <code>ordinary</code> top-level fields this tool
/// admits, derived rather than transcribed (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The derived schema with the public permission described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ..Described(tSchema, 0)
}

/// <p><var>pSchema</var> with <parameter>PUBLICPERMISSIONARGUMENT</parameter>'s description
/// written: the letters, their order, the empty string for none, and the privileged grant. With
/// <var>pRequired</var> both fields are added to <code>required</code>, which a create needs.</p>
ClassMethod Described(pSchema As %DynamicObject, pRequired As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) Quit pSchema
    If pSchema.%GetTypeOf("properties") '= "object" Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    If tProperties.%GetTypeOf(..#PUBLICPERMISSIONARGUMENT) = "object" {
        Do tProperties.%Get(..#PUBLICPERMISSIONARGUMENT).%Set("description", "The permission every user holds on this resource: some of the letters R (read), W (write) and U (use), in that order, or an empty string for none. A database resource takes R and W; a service or administrative resource takes U; any other resource takes any of the three. A letter on an administrative resource grants every user that privilege, and is confirmed as a delete is.", "string")
    }
    If pRequired && (pSchema.%GetTypeOf("required") = "array") {
        For tField = "Description", ..#PUBLICPERMISSIONARGUMENT {
            If tProperties.%GetTypeOf(tField) = "object" Do pSchema.%Get("required").%Push(tField)
        }
    }
    Quit pSchema
}

/// <p>The editor's own field rules over the agent's arguments, name rules skipped (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..RuleProblem(pIdValue, pArgs, 0, .pProblem)
}

/// <p><method>OcuPilot.Area.Permissions.ResourceRules.Validate</method> over <var>pArgs</var> for
/// <var>pIdValue</var>, the name's own rules applied only with <var>pCheckName</var> and the look-up
/// never, as one <var>pProblem</var> naming each field and its published sentence.</p>
ClassMethod RuleProblem(pIdValue As %String, pArgs As %DynamicObject, pCheckName As %Boolean, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Area.Permissions.ResourceRules).Validate(pIdValue, pArgs, .tViolations, pCheckName, 0)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tField = $List(tViolations(tI), 1)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ tField _ "': " _ tReason
    }
    Quit $$$OK
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
