/// <p>Credentials' New credential (AD-55, AD-54, AD-35, Story 24.15): <code>POST /interop/credentials</code> adds one credential to the request's
/// namespace through <class>OcuPilot.Screen.Tool.InteropCredentialAdd</class>, the tool the agent's mint and confirm read. It is
/// <class>OcuPilot.Area.Interop.ItemSave</class>'s Save with no parent: a credential belongs to its namespace, so the member is the name alone
/// (<parameter>PRODUCTIONMEMBER</parameter> is empty), and the order of the Save, its hold on the credential's name, its absence read, the prohibited
/// set, the port's add and the read-back are the superclass's. The body's members are <code>Name</code> and, optionally, <code>Username</code>,
/// <code>BusinessPartner</code> and <code>Password</code>; any other member is 400 <code>PORT.FIELD.UNEXPECTED</code>, so a name cannot be changed
/// through this route.</p>
/// <p><b>The password is a composed secret</b> (<method>Create</method>): it is taken out of the fields before the prohibited set and the read-back
/// see them, and joins the body the port is sent, so it is in no payload the kernel judges and no read-back. The rules over the other fields are
/// <method>OcuPilot.Port.InteropPort.CredentialViolations</method>'s, without the calls that reach the vendor, which the port's add makes after its
/// gate (<method>Violations</method>).</p>
Class OcuPilot.Area.Interop.CredentialSave Extends OcuPilot.Area.Interop.ItemSave
{

/// <p>The tool class both callers resolve the add through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.InteropCredentialAdd";

/// <p>The screen whose declared pairs gate this route.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropCredentialList";

/// <p>Empty: a credential has no parent (<class>OcuPilot.Area.Interop.ItemSave</class>).</p>
Parameter PRODUCTIONMEMBER = "";

Parameter NAMEMEMBER = "Name";

Parameter NAMEEMPTYCODE = "INTEROP.CREDENTIAL.NAME";

Parameter TAKENCODE = "INTEROP.CREDENTIAL.TAKEN";

Parameter TAKENREASON = "This namespace already has a credential with that name, in some letter case.";

/// <p>The body member that carries the password, which the tool declares a composed secret.</p>
Parameter PASSWORDMEMBER = "Password";

/// <p>The rules over the credential's name and fields, which call no vendor class: whether the vendor accepts the user name and whether the
/// business partner is held are judged by the port's add, after its gate.</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Quit $ClassMethod(..PortClass(), "CredentialViolations", pNamespace, pName, pFields, .pViolations, 1, 0)
}

/// <p>The superclass's add, with the password held apart: the fields the rules, the prohibited set and the read-back see carry none, and the body
/// the port is sent carries it when one was typed. An empty password is no password (AD-54's create stores none).</p>
ClassMethod Create(pProduction As %String, pName As %String, pFields As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pViolations, Output pReadBack As %DynamicObject) As %Status
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set pReadBack = ""
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set tPassword = ""
    Try {
        Set tClass = ..#CREATETOOL
        Set tSC = ..Unexpected(tClass, pFields, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tPasswordType = pFields.%GetTypeOf(..#PASSWORDMEMBER)
        If tPasswordType = "string" Set tPassword = pFields.%Get(..#PASSWORDMEMBER)
        Set tPublic = ##class(%DynamicAbstractObject).%FromJSON(pFields.%ToJSON())
        If tPasswordType '= "unassigned" Do tPublic.%Remove(..#PASSWORDMEMBER)
        Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        If pName = "" {
            Set pViolations($Increment(pViolations)) = $ListBuild(..#NAMEMEMBER, ..#NAMEEMPTYCODE)
            Quit
        }
        Set tSC = ..Violations(tNamespace, pProduction, pName, tPublic, .pViolations)
        If $$$ISERR(tSC) Quit
        If (tPasswordType '= "string") && (tPasswordType '= "unassigned") Set pViolations($Increment(pViolations)) = $ListBuild(..#PASSWORDMEMBER, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        If pViolations > 0 Quit
        Set tId = ..IdOf(pProduction, pName, pFields)
        If tId = "" {
            Set pViolations($Increment(pViolations)) = $ListBuild(..#NAMEMEMBER, ..#NAMEEMPTYCODE)
            Quit
        }
        Set tSC = ..Absent(tClass, tId, tPublic, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(tPublic.%ToJSON())
        Do tArgs.%Set($ClassMethod(tClass, "IdArgument"), pName, "string")
        Set tSC = $ClassMethod(tClass, "ComposeCreate", tArgs, $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
        If $$$ISERR(tSC) Quit
        If tProblem '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "the credential's payload could not be composed after its rules passed: " _ tProblem)
            Quit
        }
        Set tSC = ..Prohibited(tClass, tId, tPayload, tDiff, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit
        Do $ClassMethod(tClass, "DerivedFields", tPayload)
        Set tBody = ##class(%DynamicAbstractObject).%FromJSON(tPayload.%ToJSON())
        If tPassword '= "" Do tBody.%Set(..#PASSWORDMEMBER, tPassword, "string")
        Do ##class(OcuPilot.Kernel.Proposal.Operation).Query(tClass, $ClassMethod(tClass, "IdParam"), tId, tPayload.%ToJSON(), .tQuery)
        Set tSC = $ClassMethod(..PortClass(), "Invoke", $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "WriteType"), .tQuery, tBody, .tWritten, .pHttpStatus, .pFault)
        Set tBody = ""
        ; AD-58: the credential read back through the tool's port and compared with what was sent, the password aside.
        If $$$ISOK(tSC) Set pReadBack = ##class(OcuPilot.Kernel.Proposal.ReadBack).ForSave(tClass, tId, tPayload, "", ..PortClass(), $Get(tWritten), pHttpStatus)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set tPassword = ""
    Quit tSC
}

}
