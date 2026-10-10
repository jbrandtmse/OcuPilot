/// <p>The privileged routine application editor's Save (AD-55, Story 18.31): <code>POST /routine-application</code>
/// creates one application through <class>OcuPilot.Screen.Tool.RoutineAppCreate</class>, and <code>PUT
/// /routine-application/:id</code> changes one through <class>OcuPilot.Screen.Tool.RoutineAppUpdate</class>, the tools
/// the agent's mint and confirm read. It is <class>OcuPilot.Area.WebApp.DocDbAppSave</class> over an application keyed
/// by its name alone: the body names no namespace, the id is the name and the answer is <code>{id, name, readBack}</code>.
/// The delete is a row action (<class>OcuPilot.Screen.Tool.RoutineAppDelete</class>) and has no route here.</p>
/// <p>An update merges the settings over a fresh read of the whole application, so the roles and routines the read
/// answered go back unchanged (AD-4).</p>
Class OcuPilot.Area.WebApp.RoutineAppSave Extends OcuPilot.Area.WebApp.DocDbAppSave
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.RoutineAppCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.RoutineAppUpdate";

/// <p>The screen whose declared pairs gate these routes, and whose entity type and scope the prohibited set's
/// reference carries (AD-8, AD-13).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RoutineAppForm";

Parameter RULES = "OcuPilot.Area.WebApp.RoutineAppRules";

}
