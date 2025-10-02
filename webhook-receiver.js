#!/usr/bin/env node
/**
 * Simple GitHub webhook receiver
 * Listens for push events and triggers deploy-hook.sh
 * 
 * Setup:
 * 1. Install dependencies: npm install express
 * 2. Run: node webhook-receiver.js
 * 3. Configure GitHub webhook to POST to http://your-server:3001/webhook
 * 4. Optional: Set WEBHOOK_SECRET environment variable for security
 */

const express = require('express');
const { exec } = require('child_process');
const crypto = require('crypto');
const path = require('path');

const app = express();
const PORT = process.env.WEBHOOK_PORT || 3001;
const SECRET = process.env.WEBHOOK_SECRET || '';
const DEPLOY_SCRIPT = path.join(__dirname, 'deploy-hook.sh');

// Parse JSON body
app.use(express.json());

// Verify GitHub webhook signature
function verifySignature(req) {
  if (!SECRET) {
    console.warn('⚠️  WARNING: WEBHOOK_SECRET not set - skipping signature verification');
    return true;
  }

  const signature = req.headers['x-hub-signature-256'];
  if (!signature) {
    return false;
  }

  const hmac = crypto.createHmac('sha256', SECRET);
  const digest = 'sha256=' + hmac.update(JSON.stringify(req.body)).digest('hex');
  
  return crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(digest));
}

// Webhook endpoint
app.post('/webhook', (req, res) => {
  console.log('\n======================================');
  console.log('📥 Webhook received:', new Date().toISOString());
  
  // Verify signature
  if (!verifySignature(req)) {
    console.error('❌ Invalid signature');
    return res.status(401).send('Invalid signature');
  }

  const event = req.headers['x-github-event'];
  const payload = req.body;

  console.log('Event:', event);
  console.log('Repository:', payload.repository?.full_name);
  console.log('Ref:', payload.ref);

  // Only trigger on push to main branch
  if (event === 'push' && payload.ref === 'refs/heads/main') {
    console.log('✅ Push to main detected - triggering deployment');
    
    // Send immediate response
    res.status(200).send('Deployment triggered');

    // Execute deploy script asynchronously
    exec(`bash ${DEPLOY_SCRIPT}`, (error, stdout, stderr) => {
      if (error) {
        console.error('❌ Deployment failed:', error);
        console.error(stderr);
        return;
      }
      console.log('✅ Deployment completed');
      console.log(stdout);
    });
  } else {
    console.log('ℹ️  Ignoring event (not push to main)');
    res.status(200).send('Event ignored');
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Start server
app.listen(PORT, () => {
  console.log('======================================');
  console.log('🎣 GitHub Webhook Receiver');
  console.log('======================================');
  console.log(`Listening on port ${PORT}`);
  console.log(`Webhook URL: http://your-server:${PORT}/webhook`);
  console.log(`Health check: http://your-server:${PORT}/health`);
  console.log(`Deploy script: ${DEPLOY_SCRIPT}`);
  console.log(`Secret configured: ${SECRET ? 'Yes' : 'No (WARNING: Insecure!)'}`);
  console.log('======================================\n');
});
