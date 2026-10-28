// Serves the static site in ./public exactly as written: page URLs keep their .html (html_handling
// is "none" in wrangler.jsonc), so links, canonicals and the sitemap never change. This Worker only
// adds what plain asset serving lacks: www -> apex, folder paths (/research) -> index.html,
// extensionless pages (/about) -> about.html, and the 404 page.
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.hostname.startsWith("www.")) {
      url.hostname = url.hostname.slice(4);
      return Response.redirect(url.toString(), 301);
    }
    const response = await env.ASSETS.fetch(request);
    if (response.status !== 404) return response;

    const path = url.pathname;
    if (!/\.[a-z0-9]+$/i.test(path)) {
      const candidates = [path.replace(/\/?$/, "/index.html")];
      if (!path.endsWith("/")) candidates.push(`${path}.html`);
      for (const candidate of candidates) {
        const found = await env.ASSETS.fetch(new Request(new URL(candidate, url), request));
        if (found.ok) return found;
      }
    }
    const notFound = await env.ASSETS.fetch(new Request(new URL("/404.html", url), request));
    return new Response(notFound.body, { status: 404, headers: notFound.headers });
  },
};
