import { runWorkflow } from "./workflow.js";

const testInput = {
  description: "Nonprofit providing free after-school STEM programs for underserved high school students, focused on robotics and coding.",
  budget_requested: 50000,
  timeline_months: 12
};

async function main() {
  try {
    console.log("Starting workflow...\n");

    const result = await runWorkflow(testInput);

    console.log("\nFINAL OUTPUT:\n");
    console.log(JSON.stringify(result, null, 2));
  } catch (error) {
    console.error("ERROR:\n", error.message);
  }
}

main();
