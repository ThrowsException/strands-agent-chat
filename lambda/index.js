import { BedrockRuntimeClient, ConverseCommand } from "@aws-sdk/client-bedrock-runtime";

const client = new BedrockRuntimeClient({ region: "us-east-2" });

export const handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));

  const { content, sender, sessionId } = event.arguments;

  try {
    const command = new ConverseCommand({
      modelId: "us.amazon.nova-micro-v1:0",
      inferenceConfig: { 
        maxTokens: 1024
      },
      messages: [
        {
          role: "user",
          content: [{
            text: content
          }]
        }
      ],
      serviceTier: 'flex'
    });

    const apiResponse = await client.send(command);
    // const responseBody = JSON.parse(new TextDecoder().decode(apiResponse.body));

    const bedrockContent = apiResponse.output.message.content[0].text;

    const response = {
      id: Date.now().toString(),
      content: bedrockContent,
      sender: "AI Assistant",
      sessionId: sessionId,
      timestamp: new Date().toISOString()
    };

    return response;
  } catch (error) {
    console.error('Error calling Bedrock:', error);

    return {
      id: Date.now().toString(),
      content: `Error: ${error.message}`,
      sender: "System",
      sessionId: sessionId,
      timestamp: new Date().toISOString()
    };
  }
};
