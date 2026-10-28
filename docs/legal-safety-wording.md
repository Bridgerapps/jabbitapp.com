## Legal-safety wording (every page AND every X thread — MUST pass)

Added 2026-10-20 at Jon's request ("make sure we can't get sued"). We are not
lawyers; the goal is careful, source-backed wording, not a legal guarantee. Public
policy page: `/research/editorial-standards.html`.

- [ ] **Every statement about a named person, company or group is a verifiable fact
      with a linked primary source** (retraction/EoC notice, regulator letter or
      finding, registry entry, court filing, SEC filing, the company's own page,
      the person's own post). Re-open each one during THIS run.
- [ ] **Attribute, don't accuse.** Write "the journal retracted…", "its notice says
      the MHRA found…", "FDA's warning letter says…", "the registry entry lists…",
      "the company's website lists…". A finding belongs to whoever made it; never
      restate it as our own conclusion.
- [ ] **No motive, intent or character claims.** Nothing implying fraud, lying,
      hiding, scamming, intent to deceive, criminality, "paid to say", "would profit",
      "pushing", "shill", "spam", "grift", "snake oil". No mocking names or snark
      ("Oddly", "conveniently"). Describe what a document records, not why someone did it.
- [ ] **Conflicts = disclosed ties, quoted.** Quote the COI/funding statement and say
      where it is ("the review's conflict statement says all authors 'are affiliated
      with and/or receive salary support from…'"). Never upgrade "affiliated with
      and/or salaried by" to "paid by" or "employer".
- [ ] **Include the other side when the record has it.** "No misconduct alleged",
      "the authors dispute it", "the company says…", "an expression of concern is not
      a finding of misconduct", "the registry entry was last updated in 2019 and may be
      outdated".
- [ ] **Label our own analysis and opinion.** Cross-trial comparisons, dose math,
      database counts, scans: "our comparison", "by our estimate", "in our view",
      with the caveat (different patients/settings; assumes dose-proportional; scan
      only finds filed notices).
- [ ] **Hedge uncertainty and date everything that can change.** "appears to", "we
      could not find", "we did not find a mention of… in the text we checked",
      "as of Oct 20, 2026" for prices, view counts, registry statuses, web pages.
- [ ] **Don't overstate what a source argues.** Paraphrase the claim the way its
      authors would recognise it (e.g. "the case for testing them is strong" ≠ "the
      case is strong"); quote when in doubt.
- [ ] **Prices and marketing:** quote the price as listed on the seller's page on a
      date, and quote their wording verbatim if needed, with no characterization.
- [ ] **X threads:** same rules inside 280 characters. If a hedge or attribution
      doesn't fit, cut the claim rather than the hedge. Re-run the dry run after any
      edit (never `--confirm` without Jon's approval frontmatter).
- [ ] **Corrections:** errors reported by DM to @JabbitApp on X (see the editorial
      standards page; no working email yet, so never publish an email address,
      and never publish Jon's personal address). Fix fast, bump `dateModified`,
      re-run dateline-sync, and add a dated correction note on the page for anything
      substantive. Wrong X posts: draft a correction reply for Jon; never post it.
- [ ] **Interest disclosure:** footer says Jabbit sells the app it links to. Keep it.
- [ ] **Product claims:** describe only app features listed on the current App Store
      listing (id6756848719). No "never miss a dose", no trial-data features.
- [ ] **Storage claims (since Jabbit 1.0.4, released 2026-10-27):** records stay on
      the user's iPhone; there is no iCloud sync. Say "stays on your iPhone" or "stored on
      your iPhone, not on our servers"; mention Export My Data (Settings) for copies. Never
      write "syncs through iCloud", "private iCloud" or "on your devices". The privacy
      policy and terms live at bridgerapps.com/jabbit/privacy/ and /terms/ (jabbitapp.com
      /privacy and /terms redirect there); link those, don't recreate them here.
- [ ] **Footer legal links and tracking:** every page's footer links Privacy, Consumer
      health data (`/consumer-health-data`, which Washington's My Health My Data Act
      requires on the homepage) and Terms. Add no third-party scripts, pixels, ad tags,
      embeds or session replay (Meta Pixel, GA4, Hotjar, YouTube embeds and the like); Google
      Fonts is the only outside host allowed. The site is hosted on Cloudflare (`wrangler.jsonc`,
      `worker/index.js`); visits are counted only by Cloudflare Web Analytics, set up in the
      Cloudflare dashboard (cookieless, no page code), as section 8.5 of the privacy policy
      describes. Don't add tracking code to pages. Tools compute in the browser and never put
      what the user typed into the URL.
- [ ] **What belongs here (since 2026-10-28):** jabbitapp.com covers GLP-1 and other
      obesity medicines, TRT, IVF medicines, injection tracking and the app. Peptide, longevity,
      nootropic and wellness-trend teardowns belong on millenaut.com (repo
      Bridgerapps/millenaut.com), an independent site with no Jabbit links or CTAs; never
      publish them here. Pages that moved are listed in `_redirects` and `vercel.json`; don't
      recreate them. IVF pages follow the Jabbit app's `docs/IVF_DEVICE_BOUNDARY.md`: FDA label
      facts only (cited and dated), no dose or timing calculations, no technique guides.
- [ ] **Dated facts:** "only", "first", "no one else" claims about a live record
      (meeting logs, registries) must carry an "as of" date, and get re-checked
      before any X post that repeats them.
- [ ] **Doubt = cut or flag to Jon.** If a sentence about a person or company could
      read as an accusation and you can't attribute it to a document, delete it.

