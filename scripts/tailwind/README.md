Built Tailwind CSS (replaces cdn.tailwindcss.com on index, features, privacy, terms, tools/glp1-injection-log, calculator).
Rebuild after changing classes on those pages:
  npx tailwindcss@3 -c scripts/tailwind/site.config.js -i scripts/tailwind/in.css -o assets/tw-site.css --minify
  npx tailwindcss@3 -c scripts/tailwind/calc.config.js -i scripts/tailwind/in.css -o assets/tw-calc.css --minify
