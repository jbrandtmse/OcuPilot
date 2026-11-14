/// <p>Interoperability's item change of class (AD-3, AD-6, AD-10, AD-22, AD-35, AD-51, AD-53, AD-62, Story 20.41): change the class of one
/// item of a production of the request's namespace. The classic Change Class action sets the item's class and then removes every stored
/// setting the new class does not take, which cannot be undone; this write does the same through
/// <class>OcuPilot.Port.InteropPort</class> (<method>OcuPilot.Port.InteropPort.DroppedSettings</method>) and changes the stored
/// configuration and the production class only, so a running production reads update pending until Productions' confirmed Update
/// applies it.</p>
/// <p>Two callers reach it: the Production items row action Change class, reviewed first (<parameter>DRYRUN</parameter>), and the agent's
/// proposal and confirmation. <b>The fresh read is composed from the chosen class</b> (<parameter>READSVALUES</parameter>,
/// <method>PortQuery</method>): the item with <code>NewClass</code>, <code>Dropped</code>, each setting the change removes, and
/// <code>Digest</code>, a hash of the change and of those settings. A person's action carries the digest it was reviewed at as
/// <code>Reviewed</code>; the agent's confirm carries the digest its proposal was read at. The port refuses a digest that moved,
/// <code>INTEROP.ITEM.REVIEWCHANGED</code>, before it writes anything.</p>
/// <p><b>It is destructive</b>: a dropped setting's value is lost and changing back does not restore it, so its card and its dialog draw
/// the destructive treatment, its row action types the item's name, and its governance key ships disabled (AD-22). The card lists the
/// class change and each dropped setting as a removed row; the value of a credential-named setting is never shown (AD-35).</p>
Class OcuPilot.Screen.Tool.InteropItemChangeClass Extends OcuPilot.Screen.Tool.InteropItemAction
{

Parameter TOOLNAME = "interop.items.changeclass";

Parameter DESCRIPTION = "Propose changing the class of one item of a production of the namespace the user is working in, as the classic Change Class action does. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the production as the Productions list reports it, the item as that production's Production items list reports it, and the new class (NewClass) as the item's Classes tab, interop.itemclasses.read, lists it: a compiled class of the item's own kind that is not the one it has. Changing the class removes every stored setting the new class does not take, and a removed setting cannot be restored; the proposal lists each one. The change is stored in the production's configuration; a running production applies it when it is next updated or started. A class the Classes tab does not list, the item's own class, a name the production holds more than once and a namespace under source control are refused.";

Parameter SCREENACTIONS = "changeclass";

Parameter WRITETYPE = "CHANGECLASS";

/// <p>Declared: each dropped setting's value is lost, and changing back does not restore it.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

/// <p>A person's action is reviewed through <code>POST /screens/:screen/dryrun</code> before it is sent, which lists what the change
/// removes.</p>
Parameter DRYRUN As BOOLEAN = 1;

/// <p>The chosen class and the digest the review was read at; a call without the digest is a dry run.</p>
Parameter SCREENVALUES = "changeclass=NewClass:Reviewed";

Parameter SCREENOPTIONAL = "changeclass=Reviewed";

/// <p>The classic Change Class dialog's resource (<code>EnsPortal.Dialog.ChangeClass</code>, AD-44).</p>
Parameter CLASSICPAGES = "EnsPortal.Dialog.ChangeClass";

Parameter CONSEQUENCECODE = "INTEROP.ITEM.CHANGECLASS";

/// <p>What <parameter>READTYPE</parameter> answers: the item's and the composed change's.</p>
Parameter READANSWERS = "Production,Name,ClassName,Type,Enabled,EnabledSource,PoolSize,Category,Comment,Namespace,Count,NewClass,Dropped,Digest,Reviewed";

/// <p>The read field a confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Dropped";

Parameter PRECONDITIONFIELD = "Dropped";

/// <p>The item's class and the change and the settings it removes. <code>Reviewed</code> is named because the stored payload is
/// narrowed to the subject and <method>PortQuery</method> reads the digest from that payload.</p>
Parameter FINGERPRINTSUBJECT = "ClassName,NewClass,Dropped,Digest,Reviewed,Namespace";

Parameter PRECONDITIONCODES = "INTEROP.ITEM.NEWCLASS,INTEROP.ITEM.SAMECLASS,INTEROP.ITEM.AMBIGUOUS,INTEROP.ITEM.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The argument carrying the chosen class.</p>
Parameter NEWCLASSARGUMENT = "NewClass";

/// <p>The argument carrying the digest a person reviewed the action at. Only a person's action carries it; the agent's proposal does
/// not, and its schema does not offer it.</p>
Parameter REVIEWEDARGUMENT = "Reviewed";

/// <p>The longest class name a change takes.</p>
Parameter CLASSBOUND = 128;

/// <p><class>OcuPilot.Screen.Tool.InteropItemChangeClassMint</class>, which refuses an unsound class before the instance is read.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.InteropItemChangeClassMint"
}

/// <p>The two values a call carries beyond the item.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#NEWCLASSARGUMENT, ..#REVIEWEDARGUMENT)
}

/// <p>What the schema says of the item's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The item whose class changes, named exactly as this production's Production items list reports it. An item the list does not report is refused."
}

/// <p>The derived schema with the new class added, described and required. <code>Reviewed</code> is not offered.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Do tSchema.%Get("properties").%Set(..#NEWCLASSARGUMENT, {"type": "string", "maxLength": (..#CLASSBOUND), "description": "The class the item changes to, as the item's Classes tab lists it (interop.itemclasses.read): a compiled class of the item's own kind other than the one it has. A class that tab does not list is refused."})
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push(..#NEWCLASSARGUMENT)
    Quit tSchema
}

/// <p>Compose the port's read (<method>OcuPilot.Screen.Tool.InteropItemAction.PortQuery</method>), then name the chosen class under
/// <parameter>OcuPilot.Port.InteropPort.NEWCLASSKEY</parameter> and the digest the change was reviewed at under
/// <parameter>OcuPilot.Port.InteropPort.DIGESTKEY</parameter>: the payload's <code>Reviewed</code>, else its <code>Digest</code>. An
/// empty one names nothing, so the agent's call, which carries neither, is read without a review to hold it to.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Do ##super(pPayload, .pQuery)
    If '$IsObject(pPayload) Quit
    If pPayload.%GetTypeOf(..#NEWCLASSARGUMENT) = "string" Set pQuery(##class(OcuPilot.Port.InteropPort).#NEWCLASSKEY) = pPayload.%Get(..#NEWCLASSARGUMENT)
    Set tDigest = ""
    If pPayload.%GetTypeOf(..#REVIEWEDARGUMENT) = "string" Set tDigest = pPayload.%Get(..#REVIEWEDARGUMENT)
    If (tDigest = "") && (pPayload.%GetTypeOf("Digest") = "string") Set tDigest = pPayload.%Get("Digest")
    If tDigest '= "" Set pQuery(##class(OcuPilot.Port.InteropPort).#DIGESTKEY) = tDigest
}

/// <p>What a reviewed action answers beside its rows: the digest the person's action carries back.</p>
ClassMethod DryRunReview(pFresh As %DynamicObject) As %DynamicObject
{
    Set tReview = {}
    Do tReview.%Set("Digest", $Select($IsObject(pFresh): pFresh.%Get("Digest"), 1: ""), "string")
    Quit tReview
}

/// <p>The fresh read as the payload and nothing to merge: the card's rows are <method>StateDiff</method>'s, and the arguments are
/// carried to the port by <method>PortQuery</method>.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set pPayload = ##class(%DynamicAbstractObject).%FromJSON(pFresh.%ToJSON())
    Set pDiff = []
    Set pUnchanged = 0
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The rows the card and the review show, from the fresh read <var>pFresh</var>: <code>ClassName</code>, from the item's class to
/// the new one, then one removed row for each setting the change drops, its <code>field</code> <code>&lt;Target&gt;.&lt;Name&gt;</code>
/// and its <code>before</code> the value, which is empty for a credential-named setting (AD-35). A read that answers no
/// <code>Dropped</code> is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Dropped") '= "array") || (pFresh.%GetTypeOf("NewClass") '= "string") {
            Set pProblem = "this instance did not report what the change of class would remove"
            Quit
        }
        Set tRow = {}
        Do tRow.%Set("field", "ClassName", "string")
        Do tRow.%Set("before", pFresh.%Get("ClassName"), "string")
        Do tRow.%Set("after", pFresh.%Get("NewClass"), "string")
        Do pRows.%Push(tRow)
        Set tIterator = pFresh.%Get("Dropped").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tDropped) {
            Set tRemoved = {}
            Do tRemoved.%Set("field", tDropped.%Get("Target") _ "." _ tDropped.%Get("Name"), "string")
            Do tRemoved.%Set("before", $Select(tDropped.%Get("Secret"): "", 1: tDropped.%Get("Value")), "string")
            Do tRemoved.%Set("after", "", "string")
            Do tRemoved.%Set("removed", 1, "boolean")
            Do pRows.%Push(tRemoved)
        }
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>What is wrong with the class <var>pValue</var> as the one an item changes to, as one sentence, or <code>""</code>: a string of 1 to
/// <parameter>CLASSBOUND</parameter> characters shaped like a class name. The port judges the rest, from the instance.</p>
ClassMethod ClassProblem(pValue As %String, pType As %String) As %String
{
    If pType '= "string" Quit "'" _ ..#NEWCLASSARGUMENT _ "' is the class the item changes to, as the item's Classes tab lists it"
    If '##class(OcuPilot.Port.InteropPort).NewClassShape(pValue) Quit "'" _ ..#NEWCLASSARGUMENT _ "' is a class name of 1 to " _ ..#CLASSBOUND _ " characters: letters, digits, dots, underscores and percent signs, beginning with a letter or a percent sign"
    Quit ""
}

/// <p>What is wrong with the call's own arguments, as one sentence, or <code>""</code>: the new class (<method>ClassProblem</method>). The
/// port judges the rest.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If '$IsObject(pArgs) Quit $$$OK
    Set pProblem = ..ClassProblem(pArgs.%Get(..#NEWCLASSARGUMENT), pArgs.%GetTypeOf(..#NEWCLASSARGUMENT))
    Quit $$$OK
}

/// <p>The class rule again at the write, so a confirm is refused what the mint would now refuse before the claim, leaving the proposal
/// live (AD-6, AD-40). A stored payload carries <code>Reviewed</code> and <code>Digest</code> as the port's, so only the class is
/// judged.</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If '$IsObject(pArgs) Quit $$$OK
    Set pProblem = ..ClassProblem(pArgs.%Get(..#NEWCLASSARGUMENT), pArgs.%GetTypeOf(..#NEWCLASSARGUMENT))
    Quit $$$OK
}

/// <p>The screen's values as this tool's arguments (AD-56 (ii)): <code>NewClass</code>, a string as sent, and <code>Reviewed</code>, the
/// digest a person's dry run answered, when the action carries one. A class that is not a string of the right shape is
/// <var>pProblem</var>.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) {
        Set pProblem = ..ClassProblem("", "unassigned")
        Quit $$$OK
    }
    Set pProblem = ..ClassProblem(pValues.%Get(..#NEWCLASSARGUMENT), pValues.%GetTypeOf(..#NEWCLASSARGUMENT))
    If pProblem '= "" Quit $$$OK
    Do pArgs.%Set(..#NEWCLASSARGUMENT, pValues.%Get(..#NEWCLASSARGUMENT), "string")
    If pValues.%GetTypeOf(..#REVIEWEDARGUMENT) = "string" Do pArgs.%Set(..#REVIEWEDARGUMENT, pValues.%Get(..#REVIEWEDARGUMENT), "string")
    Quit $$$OK
}

}
