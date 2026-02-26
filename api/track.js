// Simple analytics tracking endpoint
// Deploy to Vercel as /api/track

export default function handler(request, response) {
  if (request.method !== 'POST' && request.method !== 'GET') {
    return response.status(405).json({ error: 'Method not allowed' });
  }

  const { page, referrer, userAgent } = request.query;
  
  // Get existing data
  let analytics = { pageviews: [], daily: {} };
  try {
    analytics = JSON.parse(require('fs').readFileSync('/tmp/analytics.json', 'utf8'));
  } catch (e) {
    // File doesn't exist yet
  }

  const timestamp = new Date().toISOString();
  const date = timestamp.split('T')[0];
  
  // Add pageview
  analytics.pageviews.push({
    page: page || '/',
    timestamp,
    referrer: referrer || '',
    userAgent: userAgent || ''
  });

  // Update daily count
  analytics.daily[date] = (analytics.daily[date] || 0) + 1;

  // Keep only last 30 days
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  analytics.pageviews = analytics.pageviews.filter(pv => new Date(pv.timestamp) > thirtyDaysAgo);

  // Save (in production, use a database)
  try {
    require('fs').writeFileSync('/tmp/analytics.json', JSON.stringify(analytics, null, 2));
  } catch (e) {
    // In Vercel, use KV or database
  }

  return response.status(200).json({ success: true, total: analytics.pageviews.length });
}
