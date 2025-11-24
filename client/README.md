# AppSync Chat Client

Simple React chat application using AWS AppSync GraphQL API with WebSocket subscriptions.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Update `src/config.js` with your AppSync endpoint and API key:
```javascript
export const appSyncConfig = {
  aws_appsync_graphqlEndpoint: 'YOUR_APPSYNC_ENDPOINT',
  aws_appsync_region: 'us-east-2',
  aws_appsync_authenticationType: 'API_KEY',
  aws_appsync_apiKey: 'YOUR_API_KEY'
};
```

You can get these values after running `terraform apply` in the terraform directory.

3. Run the development server:
```bash
npm run dev
```

## Build

```bash
npm run build
```
