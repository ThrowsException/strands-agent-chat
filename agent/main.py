import os
import json
from datetime import datetime, timezone
from typing import Dict, Any
from strands import Agent
from strands.session.s3_session_manager import S3SessionManager


# Global agent cache to reuse across Lambda invocations
_agent_cache: Dict[str, Agent] = {}


def get_agent(session_id: str, bucket_name: str) -> Agent:
    """Get or create a Strands agent with S3 session management."""
    if session_id not in _agent_cache:
        session_manager = S3SessionManager(
            session_id=session_id,
            bucket=bucket_name,
            prefix="agent_sessions"
        )

        _agent_cache[session_id] = Agent(
            system_prompt="You are a helpful assistant.",
            session_manager=session_manager
        )

    return _agent_cache[session_id]


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    AWS Lambda handler for AppSync GraphQL endpoint.

    Expected AppSync event structure:
    {
        "arguments": {
            "message": "User message here",
            "sessionId": "optional-session-id"
        },
        "identity": {
            "sub": "user-id"
        }
    }
    """
    try:
        # Log the event for debugging
        print(f"Received event: {json.dumps(event)}")

        # Check if event is None
        if event is None:
            raise ValueError("Event is None")

        # Extract arguments from AppSync event
        arguments = event.get('arguments', {})
        message = arguments.get('message')
        session_id = arguments.get('sessionId')

        # Get user ID from identity (for session management)
        identity = event.get('identity', {}) if event.get('identity') else {}
        user_id = identity.get('sub', 'anonymous') if identity else 'anonymous'

        # Validate required fields
        if not message:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Missing required field: message'
                })
            }

        # Generate session ID if not provided
        if not session_id:
            session_id = f"user_{user_id}_session"

        # Get configuration from environment
        bucket_name = os.environ.get('S3_BUCKET_NAME')
        if not bucket_name:
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': 'S3_BUCKET_NAME environment variable not set'
                })
            }

        # Get or create agent with session management
        agent = get_agent(session_id, bucket_name)

        # Send message to agent
        agent_result = agent(message)

        # Extract text response from AgentResult
        response_text = agent_result.content if hasattr(agent_result, 'content') else str(agent_result)

        # Return response in AppSync-compatible format
        return {
            'sessionId': session_id,
            'message': message,
            'response': response_text,
            'timestamp': datetime.now(timezone.utc).isoformat()
        }

    except Exception as e:
        print(f"Error processing request: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': f'Internal server error: {str(e)}'
            })
        }


# For local testing
def main():
    """Test the Lambda handler locally."""
    test_event = {
        'arguments': {
            'message': 'Hello! What can you help me with?',
            'sessionId': 'test_session_123'
        },
        'identity': {
            'sub': 'test-user-id'
        }
    }

    # Set environment variable for testing
    os.environ['S3_BUCKET_NAME'] = os.environ.get('S3_BUCKET_NAME', 'your-bucket-name')

    print("Testing Lambda handler locally...")
    print(f"Event: {json.dumps(test_event, indent=2)}\n")

    result = lambda_handler(test_event, None)
    print(f"Result: {json.dumps(result, indent=2)}")


if __name__ == "__main__":
    main()
