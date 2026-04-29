import fs from "fs";
import { runPrompt } from "../openai.js";

const prompt = fs.readFileSync("./prompts/research.txt", "utf-8");

export async function researchAgent(input) {
  const raw = await runPrompt(prompt, input);

  try {
    return JSON.parse(raw);
  } catch (e) {
    console.error("RAW OUTPUT:\n", raw);
    throw new Error("JSON parsing failed in researchAgent");
  }
}
