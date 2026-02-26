// Analytics stats endpoint
// Deploy to Vercel as /api/stats

export default function handler(request, response) {
  let analytics = { pageviews: [], daily: {} };
  try {
    analytics = JSON.parse(require('fs').readFileSync('/tmp/analytics.json', 'utf8'));
  } catch (e) {
    return response.status(200).json({ pageviews: 0, daily: {} });
  }

  const today = new Date().toISOString().split('T')[0];
  const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];
  
  const stats = {
    total: analytics.pageviews.length,
    today: analytics.daily[today] || 0,
    yesterday: analytics.daily[yesterday] || 0,
    daily: analytics.daily,
    topPages: getTopPages(analytics.pageviews, 10)
  };

  return response.status(200).json(stats);
}

function getTopPages(pageviews, limit) {
  const counts = {};
  pageviews.forEach(pv => {
    counts[pv.page] = (counts[pv.page] || 0) + 1;
  });
  return Object.entries(counts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([page, count]) => ({ page, count }));
}
