import fs from "fs";
import { runPrompt } from "../openai.js";

const prompt = fs.readFileSync("./prompts/intake.txt", "utf-8");

export async function intakeAgent(input) {
  const raw = await runPrompt(prompt, input);

  try {
    return JSON.parse(raw);
  } catch (e) {
    console.error("RAW OUTPUT:\n", raw);
    throw new Error("JSON parsing failed in intakeAgent");
  }
}
