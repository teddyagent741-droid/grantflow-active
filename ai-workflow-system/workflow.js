import { intakeAgent } from "./agents/intake.js";
import { researchAgent } from "./agents/research.js";
import { draftAgent } from "./agents/draft.js";
import { editorAgent } from "./agents/editor.js";

export async function runWorkflow(input) {
  console.log("STEP 1: Intake");
  const intake = await intakeAgent(input);
  console.log("STEP 1 RESULT:\n", JSON.stringify(intake, null, 2));

  console.log("STEP 2: Research");
  const research = await researchAgent(intake);
  console.log("STEP 2 RESULT:\n", JSON.stringify(research, null, 2));

  console.log("STEP 3: Draft");
  const draft = await draftAgent({
    ...intake,
    ...research
  });
  console.log("STEP 3 RESULT:\n", JSON.stringify(draft, null, 2));

  console.log("STEP 4: Edit");
  const final = await editorAgent(draft);
  console.log("STEP 4 RESULT:\n", JSON.stringify(final, null, 2));

  return final;
}
