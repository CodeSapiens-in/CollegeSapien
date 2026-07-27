import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';

const sesClient = new SESClient({
  region: process.env.AWS_REGION || 'us-east-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'MOCK_KEY',
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'MOCK_SECRET',
  },
});

export const sendOtpEmail = async (toEmail: string, otp: string, type: 'signup' | 'reset') => {
  const subject =
    type === 'signup' ? 'Verify your CodeSapiens Account' : 'Reset your CodeSapiens Password';
  const body = `Your OTP is: ${otp}. It is valid for 10 minutes.`;

  const command = new SendEmailCommand({
    Source: process.env.SES_SENDER_EMAIL || 'noreply@codesapiens.in',
    Destination: {
      ToAddresses: [toEmail],
    },
    Message: {
      Subject: { Data: subject },
      Body: {
        Text: { Data: body },
      },
    },
  });

  try {
    if (process.env.AWS_ACCESS_KEY_ID === 'MOCK_KEY' || !process.env.AWS_ACCESS_KEY_ID) {
      console.log(`[MOCK EMAIL] To: ${toEmail}, Subject: ${subject}, Body: ${body}`);
      return true;
    }
    await sesClient.send(command);
    return true;
  } catch (error) {
    console.error('Error sending email via SES:', error);
    throw error;
  }
};
