import { useState, useEffect, useMemo } from 'react';
import { generateClient } from 'aws-amplify/api';
import { chat, onChatResponse } from './graphql/queries';
import './App.css';

const client = generateClient();

function App() {
  const [messages, setMessages] = useState([]);
  const [inputValue, setInputValue] = useState('');

  // Generate a unique session ID for this browser tab
  const sessionId = useMemo(() => {
    return `session-${Date.now()}-${Math.random().toString(36).substring(2, 11)}`;
  }, []);

  useEffect(() => {
    // Subscribe to chat responses for this session
    const subscription = client.graphql({
      query: onChatResponse,
      variables: { sessionId }
    }).subscribe({
      next: ({ data }) => {
        console.log('Chat response received:', data);
        if (data.onChatResponse) {
          const { message, response, timestamp } = data.onChatResponse;
          setMessages(prev => [
            ...prev,
            { type: 'user', content: message, timestamp },
            { type: 'assistant', content: response, timestamp }
          ]);
        }
      },
      error: (error) => console.error('Subscription error:', error)
    });

    return () => subscription.unsubscribe();
  }, [sessionId]);

  const handleSendMessage = async (e) => {
    e.preventDefault();
    if (!inputValue.trim()) return;

    try {
      await client.graphql({
        query: chat,
        variables: {
          message: inputValue,
          sessionId: sessionId
        }
      });
      setInputValue('');
    } catch (error) {
      console.error('Error sending message:', error);
    }
  };

  return (
    <div className="app">
      <div className="chat-container">
        <h1>Strands AI Agent Chat</h1>

        <div className="messages">
          {messages.map((msg, index) => (
            <div key={index} className={`message ${msg.type}`}>
              <strong>{msg.type === 'user' ? 'You' : 'Assistant'}:</strong> {msg.content}
              <span className="timestamp">
                {new Date(msg.timestamp).toLocaleTimeString()}
              </span>
            </div>
          ))}
        </div>

        <form onSubmit={handleSendMessage} className="message-form">
          <input
            type="text"
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            placeholder="Type a message..."
          />
          <button type="submit">Send</button>
        </form>
      </div>
    </div>
  );
}

export default App;
