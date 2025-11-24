import React from 'react';
import ReactDOM from 'react-dom/client';
import { Amplify } from 'aws-amplify';
import App from './App.jsx';
import { appSyncConfig } from './config.js';

Amplify.configure({
  API: {
    GraphQL: {
      endpoint: appSyncConfig.aws_appsync_graphqlEndpoint,
      region: appSyncConfig.aws_appsync_region,
      defaultAuthMode: appSyncConfig.aws_appsync_authenticationType,
      apiKey: appSyncConfig.aws_appsync_apiKey
    }
  }
});

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
