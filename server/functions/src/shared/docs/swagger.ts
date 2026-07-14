import swaggerJsdoc from 'swagger-jsdoc';

const options: swaggerJsdoc.Options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'CodeSapiens API',
      version: '1.0.0',
      description: 'API documentation for the CodeSapiens student super app',
    },
    servers: [
      {
        url: 'http://127.0.0.1:5001/codesapien-college/asia-south1/api',
        description: 'Local development server',
      },
      {
        url: 'https://asia-south1-codesapien-college.cloudfunctions.net/api',
        description: 'Firebase Functions HTTPS endpoint',
      },
      {
        url: 'https://api.codesapiens.in',
        description: 'Production server',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
        appCheck: {
          type: 'apiKey',
          in: 'header',
          name: 'X-Firebase-AppCheck',
          description:
            'Firebase App Check token. Disabled only for local emulator/test environments.',
        },
      },
    },
  },
  apis: ['./src/app/**/*.route.ts', './src/app/**/*.openapi.ts', './src/**/*.model.ts'], // Path to the API docs
};

export const specs = swaggerJsdoc(options);
