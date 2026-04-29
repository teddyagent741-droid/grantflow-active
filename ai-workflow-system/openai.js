import OpenAI from "openai";

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export async function runPrompt(prompt, input) {
  const response = await client.chat.completions.create({
    model: "gpt-4o-mini",
    temperature: 0.2,
    messages: [
      { role: "system", content: prompt },
      { role: "user", content: JSON.stringify(input) }
    ],
  });

  return response.choices[0].message.content;
}
