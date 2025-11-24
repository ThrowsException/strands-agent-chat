export const sendMessage = /* GraphQL */ `
  mutation SendMessage($content: String!, $sender: String!, $sessionId: String!) {
    sendMessage(content: $content, sender: $sender, sessionId: $sessionId) {
      id
      content
      sender
      sessionId
      timestamp
    }
  }
`;

export const onMessageReceived = /* GraphQL */ `
  subscription OnMessageReceived($sessionId: String!) {
    onMessageReceived(sessionId: $sessionId) {
      id
      content
      sender
      sessionId
      timestamp
    }
  }
`;

export const chat = /* GraphQL */ `
  mutation Chat($message: String!, $sessionId: String) {
    chat(message: $message, sessionId: $sessionId) {
      sessionId
      message
      response
      timestamp
    }
  }
`;

export const onChatResponse = /* GraphQL */ `
  subscription OnChatResponse($sessionId: String!) {
    onChatResponse(sessionId: $sessionId) {
      sessionId
      message
      response
      timestamp
    }
  }
`;
