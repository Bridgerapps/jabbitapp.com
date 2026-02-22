#!/bin/bash
# Generate hero images for all 12 blog posts using Gemini Flash Image via OpenRouter
set -e

OR_KEY="REDACTED_OPENROUTER_KEY"
OUTDIR="/home/jabbit/.openclaw/workspace/jabbitapp.com/blog/images"
mkdir -p "$OUTDIR"

generate_image() {
    local slug="$1"
    local prompt="$2"
    local outfile="$OUTDIR/${slug}.png"
    
    if [ -f "$outfile" ]; then
        echo "SKIP: $slug (already exists)"
        return
    fi
    
    echo "Generating: $slug..."
    
    # Escape the prompt for JSON
    local json_prompt=$(python3 -c "import json; print(json.dumps('$prompt'))")
    
    response=$(curl -s --max-time 120 https://openrouter.ai/api/v1/chat/completions \
      -H "Authorization: Bearer $OR_KEY" \
      -H "Content-Type: application/json" \
      -d "{
        \"model\": \"google/gemini-2.5-flash-image\",
        \"messages\": [{\"role\": \"user\", \"content\": \"Generate an image: ${prompt}\"}]
      }")
    
    # Extract base64 image data and save
    echo "$response" | python3 -c "
import sys, json, base64
try:
    resp = json.load(sys.stdin)
    images = resp.get('choices', [{}])[0].get('message', {}).get('images', [])
    if images:
        url = images[0].get('image_url', {}).get('url', '')
        if url.startswith('data:image/png;base64,'):
            b64 = url.split(',', 1)[1]
            data = base64.b64decode(b64)
            with open('$outfile', 'wb') as f:
                f.write(data)
            print(f'OK: $slug ({len(data)} bytes)')
        else:
            print(f'WARN: Unexpected URL format for $slug')
            print(url[:100])
    else:
        # Try content field
        content = resp.get('choices', [{}])[0].get('message', {}).get('content', '')
        print(f'NO IMAGE: $slug - content: {content[:200]}')
        if resp.get('error'):
            print(f'ERROR: {resp[\"error\"]}')
except Exception as e:
    print(f'ERROR: $slug - {e}')
    print(sys.stdin.read()[:500] if hasattr(sys.stdin, 'read') else '')
"
    
    # Rate limit - be nice
    sleep 2
}

# Generate all 12 images
generate_image "glp1-injection-tracking" \
    "A clean minimal lifestyle photo of a modern smartphone showing a health tracking app interface with colorful charts, placed on a white marble surface next to a GLP-1 injection pen. Soft natural morning light from the left. Teal and white color palette. Editorial photography style. No text overlays. 1200x630 aspect ratio."

generate_image "semaglutide-vs-tirzepatide" \
    "Two modern medication auto-injector pens side by side on a clean white surface, one with a blue cap and one with a purple-pink cap. Minimalist medical product photography. Soft shadows. Clean white background. No text or labels. 1200x630 aspect ratio."

generate_image "compounded-tirzepatide" \
    "A sterile pharmaceutical lab scene: a clear glass medication vial next to bacteriostatic water and a sterile syringe on a spotless white surface. Professional medical supply photography. Cool blue-teal lighting accents. No text. 1200x630 aspect ratio."

generate_image "glp1-side-effects" \
    "An abstract wellness concept: a calm person meditating in soft teal light, with a subtle glow emanating from their midsection representing gut health and the gut-brain connection. Ethereal, peaceful mood. Teal and warm gold tones. Artistic editorial style. No text. 1200x630 aspect ratio."

generate_image "semaglutide-half-life" \
    "An abstract data visualization artwork: a smooth glowing teal curve against a dark navy background, representing drug concentration levels over time. Elegant pharmacokinetics-inspired design. Glowing particles along the curve. Data dashboard aesthetic. No text or numbers. 1200x630 aspect ratio."

generate_image "peptide-site-rotation" \
    "A clean modern medical illustration showing a human body silhouette with highlighted injection zones marked by soft glowing teal circles on the abdomen, thighs, and arms. Clean white background. Medical textbook style but contemporary. No text. 1200x630 aspect ratio."

generate_image "peptide-reconstitution" \
    "Close-up product photography of peptide reconstitution supplies: a small lyophilized peptide vial with white powder, a vial of bacteriostatic water, and an insulin syringe, arranged neatly on a clean white surface. Soft studio lighting. Medical blue-teal color grading. No text. 1200x630 aspect ratio."

generate_image "bpc-157" \
    "Abstract biological art showing cellular healing and regeneration at the molecular level. Glowing teal and gold particles forming new tissue connections. Dark background with bioluminescent elements. Scientific but artistic style. No text. 1200x630 aspect ratio."

generate_image "tb-500" \
    "Abstract biological art depicting muscle and tendon fiber repair at the cellular level. Interweaving blue-green fibers being reconstructed with copper-gold energy particles. Dark background. Scientific visualization style. No text. 1200x630 aspect ratio."

generate_image "injection-site-rotation-science" \
    "A modern medical illustration showing a cross-section of skin tissue layers with a subcutaneous injection depicted. Clean anatomical art style with teal and gray color scheme. Shows epidermis, dermis, and subcutaneous fat layers clearly. No text or labels. 1200x630 aspect ratio."

generate_image "glp1-serum-levels" \
    "A beautiful data visualization on a dark background: smooth glowing teal and cyan lines showing serum concentration curves with peaks and troughs over a weekly period. Futuristic health dashboard aesthetic. Subtle grid pattern. No text or numbers. 1200x630 aspect ratio."

generate_image "peptide-storage" \
    "Inside a clean medical refrigerator: neatly organized small peptide vials on a glass shelf, with soft cool blue-teal LED lighting. Temperature-controlled pharmaceutical storage. Clean, organized. Professional photography. No text. 1200x630 aspect ratio."

echo ""
echo "Done! Generated images:"
ls -la "$OUTDIR/"
