const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Follow this checkout's backend configuration, including its isolated DB name.
require('../wallet-backend-server/node_modules/dotenv').config({
	path: path.join(__dirname, '../wallet-backend-server/.env'), quiet: true,
});
const database = process.env.DB_NAME || 'wallet_single_key';
const port = process.env.DB_PORT || '3307';
const username = process.env.DB_USER || 'root';
const password = process.env.DB_PASSWORD || 'root';
const certificate = fs.readFileSync(path.join(__dirname, 'keystore/wwwallet_org_iaca.pem'), 'utf8')
	.replace(/-----BEGIN CERTIFICATE-----|-----END CERTIFICATE-----|\s/g, '');
const sql = `
	DELETE FROM credential_issuer;
	INSERT INTO credential_issuer (credentialIssuerIdentifier, clientId, visible) VALUES ('http://localhost:8003/openid', '1233', 1);
	DELETE FROM trusted_root_certificate;
	INSERT INTO trusted_root_certificate (certificate) VALUES ('${certificate}');
	DELETE FROM verifier;
	INSERT INTO verifier (name, url) VALUES ('ACME Verifier', 'http://localhost:8005');
`;
execFileSync('docker', ['compose', 'exec', '-T', 'wallet-db', 'mariadb', '--protocol=TCP', '-h127.0.0.1',
	`-P${port}`, `-u${username}`, `-p${password}`, database], { input: sql, stdio: ['pipe', 'inherit', 'inherit'] });
console.log(`Initialized defaults in ${database}`);
