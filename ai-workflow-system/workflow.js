import { createOpenAIClient } from "./openai.js";

export async function runWorkflow() {
  const client = createOpenAIClient();
  return client;
}
