/// <p>What Interoperability's three business partner writes share (AD-6, AD-35, AD-51, AD-52, AD-53, AD-62, Story 20.26): a write of
/// one business partner of the request's namespace through <class>OcuPilot.Port.InteropPort</class>, reached by two callers -- the
/// partners list's New business partner and its row actions Edit and Remove, and the agent's proposal and confirmation. A write
/// takes effect at once: a partner is information about an organization or an application and changes nothing in how a production
/// runs. The target is the partner's name, kept exactly (AD-13).</p>
/// <p><b>A rename cannot be expressed</b>: the name is the target, and the update's settable fields are the thirteen others, so a
/// call carrying any other argument is refused by the tool's schema or by the screen action's declared values before any port call.
/// The vendor would rename by deleting and creating, leaving every item's reference to the old name pointing at nothing.</p>
/// <p><b>It declares</b> <code>%Ens_ProductionConfig:WRITE</code> and WRITE on the namespace's globals database beyond the screen's
/// pairs (AD-8, AD-62), each refused by name before any port call. The classic <code>EnsPortal.BusinessPartners</code> page declares
/// no edit resource and so admits a holder of READ; this is stricter. The vendor checks no privilege of its own (measured). The
/// write runs on that page's own operation, whose resource the screen's pairs already name (AD-44), so no tool declares
/// <code>CLASSICPAGES</code>.</p>
Class OcuPilot.Screen.Tool.InteropPartnerAction Extends OcuPilot.Screen.Tool.InteropAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropBusinessPartnerList";

/// <p>The fresh read: one partner, composed for the action.</p>
Parameter READTYPE = "PARTNER";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Name,Description,PrimaryContact,PrimaryTitle,PrimaryEmail,PrimaryPhone,PrimaryMobile,PrimaryNotes,AlternativeContact,AlternativeTitle,AlternativeEmail,AlternativePhone,AlternativeMobile,AlternativeNotes,NamedBy,Namespace";

/// <p>The partner read the confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "NamedBy";

/// <p>Whether the rules over the call judge the partner's name: an add, whose name is new. A partner already held keeps the name it
/// has, whatever it holds.</p>
Parameter JUDGESNAME As BOOLEAN = 0;

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTBUSINESSPARTNERS
}

/// <p>The partner's name, which the card titles it by: the fresh read's <code>Name</code>, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Name") = "string") Quit pFresh.%Get("Name")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Name") = "string") Quit pArgs.%Get("Name")
    Quit ""
}

/// <p>What the schema says of the partner's name. The write the tool makes states it.</p>
ClassMethod NameDescription() As %String
{
    Quit "The business partner's name, exactly as the Business partners list reports it in its Name column. A partner the list does not report is refused."
}

/// <p>The derived schema with the name described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", ..NameDescription(), "string")
    }
    Quit tSchema
}

/// <p>The thirteen fields a partner holds beside its name, as the field rows the input schema is derived from: all strings (AD-3),
/// with the name first when <var>pWithName</var>. The port has no body template to derive them from.</p>
ClassMethod PartnerFieldRows(pWithName As %Boolean, Output pRows) As %Status
{
    Kill pRows
    Set pRows = 0
    Set tNames = $ListFromString(##class(OcuPilot.Port.InteropPort).#PARTNERSETFIELDS)
    If pWithName Set pRows($Increment(pRows)) = $ListBuild("Name", "string", 0)
    For tI = 1:1:$ListLength(tNames) {
        Set pRows($Increment(pRows)) = $ListBuild($List(tNames, tI), "string", 0)
    }
    Quit $$$OK
}

/// <p>The agent-facing description of each of the thirteen fields, in the schema.</p>
ClassMethod FieldDescription(pField As %String) As %String
{
    If pField = "Description" Quit "What this business partner is, as text, at most 5,000 characters."
    Set tLimit = ##class(OcuPilot.Port.InteropPort).PartnerLimit(pField)
    Set tContact = $Select($Extract(pField, 1, 7) = "Primary": "primary", 1: "alternative")
    Set tWhat = $Case($Piece(pField, $Select(tContact = "primary": "Primary", 1: "Alternative"), 2), "Contact": "name", "Title": "title", "Email": "email address", "Phone": "phone number", "Mobile": "mobile number", : "notes")
    Quit "The " _ tContact _ " contact's " _ tWhat _ ", at most " _ $FNumber(tLimit, ",") _ " characters. An empty string clears it."
}

/// <p>The derived schema with each field described.</p>
ClassMethod DescribeFields(pSchema As %DynamicObject) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    Set tNames = $ListFromString(##class(OcuPilot.Port.InteropPort).#PARTNERSETFIELDS)
    For tI = 1:1:$ListLength(tNames) {
        Set tField = $List(tNames, tI)
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", ..FieldDescription(tField), "string")
    }
    Quit pSchema
}

/// <p>The rules over the caller's fields, as one sentence naming each field and its published sentence, or <code>""</code>
/// (AD-55): <method>OcuPilot.Port.InteropPort.PartnerViolations</method> over the arguments' fields and, for an add
/// (<parameter>JUDGESNAME</parameter>), the id's name, a field
/// that is not a string being a shape violation. The screen's Save and the mint apply them alike.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tValues
    Set tNames = $ListFromString(##class(OcuPilot.Port.InteropPort).#PARTNERSETFIELDS)
    For tI = 1:1:$ListLength(tNames) {
        Set tField = $List(tNames, tI)
        If '$IsObject(pArgs) Quit
        Set tType = pArgs.%GetTypeOf(tField)
        If tType = "string" {
            Set tValues(tField) = pArgs.%Get(tField)
        } ElseIf tType '= "unassigned" {
            Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ tField _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }
    }
    Set tSC = $ClassMethod(..#PORTCLASS, "PartnerViolations", pIdValue, .tValues, .tViolations, ..#JUDGESNAME)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
    }
    Quit $$$OK
}

/// <p>The same rules again at the write, so a confirm is refused what the mint would now refuse before the claim, leaving the
/// proposal live (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

}
