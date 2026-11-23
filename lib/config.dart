/// Local USB test default. Set DATA_API_URL to an HTTPS address for deployment.
const dataApiUrl = String.fromEnvironment(
  'DATA_API_URL',
  defaultValue: 'http://127.0.0.1:8100',
);
