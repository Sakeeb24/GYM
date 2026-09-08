// tools/check_live_deployment.mjs
const PROD_URL = 'https://sakeeb24.github.io/GYM/';

async function checkDeployment() {
  console.log(`Checking deployment status at: ${PROD_URL}`);
  
  const resp = await fetch(`${PROD_URL}main.dart.js?t=${Date.now()}`, {
    cache: 'no-store',
    headers: { 'Cache-Control': 'no-cache' }
  });
  
  if (!resp.ok) {
    console.log(`HTTP ${resp.status}`);
    return false;
  }
  
  const text = await resp.text();
  const hasResetPassword = text.includes('RESET YOUR PASSWORD') || text.includes('reset-password');
  const hasEmailReset = text.includes('Check your email') || text.includes('Send Reset Link');
  
  console.log(`Bundle length: ${text.length}`);
  console.log(`Contains /reset-password screen: ${hasResetPassword}`);
  console.log(`Contains email reset flow: ${hasEmailReset}`);
  
  return hasResetPassword && hasEmailReset;
}

checkDeployment().then(deployed => {
  console.log(`Is new commit deployed? ${deployed}`);
  process.exit(deployed ? 0 : 1);
}).catch(err => {
  console.error(err);
  process.exit(2);
});
