# Social Media Integration & Posting System Redesign — Design Brief

**Date**: 2026-04-12
**Scope**: Post creation overhaul, social media sharing, events tab redesign, hub PDF uploads
**Design System**: "Contender" — Josefin Sans + Mulish, Electric Blue + FBLA Gold, editorial dark/light

---

## 1. Feature Summary

A comprehensive upgrade to the content creation and distribution system in FBLA Connect. Advisors and admins get a redesigned posting flow (with image uploads and Instagram-style pre-upload), a maps-integrated event creator, social media sharing to Instagram Stories / X / native share, and a celebration screen after each publish. Members see subtle social platform badges on shared content. The events tab gets a proper interactive calendar in the top half with a scrollable event list below. The hub gains PDF upload support.

---

## 2. Systems Being Changed

### A. Post Creation (New)
### B. Event Creation (New — Maps Integration)
### C. Announcement Creation (Unchanged flow, gains share)
### D. Hub Item Creation (Gains PDF upload)
### E. Social Media Share Flow (New)
### F. Celebration Screen (New)
### G. Events Tab Layout (Redesigned)
### H. Share Badge on Cards (New — member-facing)
### I. Database Changes (New columns + tables)

---

## 3. Design Direction

**Tone**: Professional and clean. Matches the existing "Contender" aesthetic — editorial precision, sharp typography, earned gold moments. The celebration screen is the one place where the tone lifts (gold accents, a satisfying animation), but share buttons themselves are understated. The posting flow should feel like Instagram's — familiar, fast, confident — adapted to FBLA's visual language.

**Key principle**: Gold is earned. The celebration screen uses gold because the advisor just published something. The share buttons use the platform's own brand colors (Instagram gradient, X black) at small scale — they're guests in our UI, not dominant.

---

## 4. System A: Post Creation Redesign

### Flow (Instagram-inspired)

**Screen 1 — Media Selection**
- Full-screen image picker grid (device gallery)
- Camera option at top
- Selected image shows as large preview with crop handles
- "Next" button (top-right, electric blue) advances to Screen 2
- Skip option: "Text only" link below the grid for caption-only posts

**Screen 2 — Caption & Pre-Upload**
- Selected image shown as thumbnail (top-left, 64px, rounded corner)
- Large text field for caption (placeholder: "Write a caption...")
- Character counter (fades in at 1800/2000)
- **Critical — Instagram pre-upload pattern**: The moment this screen appears, the image begins uploading to Supabase Storage in the background. A subtle progress indicator (thin blue line at the top of the screen, like Instagram) shows upload progress. By the time the user finishes typing their caption, the image is already uploaded. When they tap "Share", only the metadata (caption + media_url) needs to POST — making it feel instant.
- Scope indicator: Shows "Posting to [Chapter Name]" in small text below the caption field
- "Share" button (top-right, gold fill — this is an earned action)

**Pre-upload implementation detail:**
```
User enters Screen 2
  → Immediately: POST image to /api/uploads → returns media_url
  → Store media_url in state
  → When user taps "Share": POST /api/posts with { caption, media_url }
  → If upload still in progress when "Share" tapped: show "Uploading..." on button, disable tap
  → If upload failed: show inline error, retry button
```

### States
- **Gallery loading**: Skeleton grid (8 placeholder rectangles)
- **No photos permission**: Empty state with "Allow access to photos" CTA
- **Upload in progress**: Thin animated blue line at top (width animates from 0% to 100%)
- **Upload failed**: Red line replaces blue, "Retry" appears next to thumbnail
- **Caption empty + Share tapped**: Gentle shake on text field, "Add a caption" tooltip
- **Success**: Navigate to Celebration Screen

### Design Specs
- Gallery grid: 4 columns, 1px gap, aspect ratio 1:1
- Caption field: Mulish 16px, line height 1.5, no border, just a hairline bottom separator
- Character counter: JetBrains Mono 12px, `FblaColors.darkTextTertiary`, right-aligned
- Upload progress bar: 2px height, `FblaColors.primary`, eased animation (300ms ease-out per chunk)
- "Share" button: Josefin Sans 600 weight, 15px, gold fill (`FblaColors.secondary`), `FblaColors.onSecondary` text

---

## 5. System B: Event Creation with Maps

### Flow

**Screen 1 — Event Details**
- Title field (Josefin Sans placeholder: "Event name")
- Description field (Mulish, multi-line, max 4000 chars)
- Date/time pickers: Start date+time, End date+time (Material date/time pickers, styled to match theme)
- Registration deadline picker (optional)

**Screen 2 — Location Search**
- Search bar at top with real-time autocomplete
- Uses Google Places Autocomplete API (or Apple MapKit search)
- As user types, dropdown shows place predictions with address previews
- Tapping a result:
  1. Fills the location field with the formatted address
  2. Fetches a place photo via Google Places Photos API (or static map image)
  3. The place photo becomes the event's background/hero image
  4. Shows a small map preview below the location field confirming the pin
- Manual entry fallback: "Enter address manually" link at bottom of dropdown

**Screen 3 — Review & Publish**
- Full preview of the event card as it will appear in the events list
- Location photo shown as background with gradient overlay + white text
- All details editable (tap to go back to relevant field)
- "Publish Event" button (gold fill)
- On publish → Celebration Screen

### Place Photo Integration
When a location is selected from the autocomplete:
1. Fetch place details (place_id → Place Details API → photos array)
2. Take the first photo reference → Places Photos API → image URL
3. Upload the image to Supabase Storage (same pre-upload pattern as posts)
4. Store as `location_image_url` on the event record
5. EventCard renders this image as a background with a dark gradient overlay for text legibility

### EventCard Update
Current: Navy gradient date column on the left
New: If `location_image_url` exists, the entire card background is the location photo with a gradient overlay (dark from bottom, 60% opacity). Date badge overlays in the top-left corner. Title, location, and urgency chip overlay in white at the bottom.
Fallback: If no location image, use the current clean card style with the navy date column.

### Database Changes for Events
```sql
ALTER TABLE events ADD COLUMN location_image_url TEXT;
ALTER TABLE events ADD COLUMN place_id TEXT;           -- Google Place ID for future reference
ALTER TABLE events ADD COLUMN registration_deadline TIMESTAMPTZ;
```

---

## 6. System C: Announcement Creation

Flow stays the same (title, body, scope selector). Gains the celebration screen + share prompt after publish. No other changes.

---

## 7. System D: Hub Item Creation — PDF Upload

### Addition to existing flow
- New "Attach File" button below the body text field
- Tapping opens a file picker filtered to PDFs only
- Selected PDF shows as a file chip: `📄 filename.pdf (2.3 MB)` with an X to remove
- Pre-upload pattern: PDF begins uploading to Supabase Storage immediately on selection
- `file_path` field stores the Supabase Storage URL
- Hub item card shows a PDF icon + filename when `file_path` is present
- Tapping a hub item with a PDF opens it in the system PDF viewer

### Database
No schema changes needed — `hub_items.file_path` already exists.

---

## 8. System E: Social Media Share Flow

### Trigger Points
1. **Post-creation**: After creating any content (post, event, announcement), the Celebration Screen appears with share options
2. **Persistent on cards**: Share icon on existing PostCard, EventCard, AnnouncementCard (advisor/admin only)

### Share Destinations

**Instagram Stories**
- Generates a branded 1080×1920 image using Flutter's `RepaintBoundary` + `dart:ui` canvas
- 3 template styles (user picks):
  - **"Bold"**: Full gold (#F5A623) background, white Josefin Sans title (32px), chapter name at bottom in Mulish, FBLA Connect logo watermark (bottom-right, 20% opacity)
  - **"Clean"**: White (#F8F7F3) background, electric blue title, gold accent line (2px, 120px wide) below title, date + chapter in Mulish 14px tertiary text, logo watermark
  - **"Dark"**: True dark (#09090E) background, gold Josefin Sans title, electric blue accent elements, feels premium/editorial, logo watermark
- For events: includes date, location, and location photo as a circular inset (if available)
- For posts: includes caption preview (first 3 lines) and post image (if available)
- For announcements: includes title and body preview (first 4 lines)
- Opens Instagram Stories via URL scheme: `instagram-stories://share` with image in UIPasteboard (iOS) or content provider (Android)
- Fallback if Instagram not installed: "Save image to gallery" option

**X / Twitter**
- Composes a text post with the content preview
- Text templates:
  - Posts: `"{caption first 100 chars}…" — via FBLA Connect`
  - Events: `"📅 {title} — {formatted date} at {location}. Join us! — via FBLA Connect"`
  - Announcements: `"📢 {title}: {body first 100 chars}…" — via FBLA Connect`
- Opens X via URL scheme: `twitter://post?message={encoded text}`
- Fallback: `https://twitter.com/intent/tweet?text={encoded text}`
- If neither works: copy text to clipboard with confirmation toast

**Native Share (More Options)**
- Uses `share_plus` package
- Shares the same text as X, plus the generated story image as an attachment
- Opens the system share sheet (any app: Messages, WhatsApp, email, etc.)

### Share Bottom Sheet (from existing cards)
- Compact modal bottom sheet (not full screen)
- 3 rows:
  - Instagram Stories icon + "Instagram Stories" + "Share a branded card"
  - X icon + "X / Twitter" + "Post with your chapter"
  - Share icon + "More options" + "Share via any app"
- Each row: 56px height, icon (24px) left-aligned, text in Mulish 15px, description in 13px tertiary
- Sheet background: `FblaColors.darkOverlay` with `FblaColors.darkOutline` top border
- Drag handle: 36px wide, 4px tall, `FblaColors.darkOutlineVar`, centered

### Template Picker (Instagram sub-flow)
- After tapping "Instagram Stories", the bottom sheet morphs (height animation, 300ms ease-out) to show:
  - "Choose a style" heading (Josefin Sans 18px)
  - Horizontal scrollable row of 3 template previews
  - Each preview: 120px wide × 213px tall (9:16 ratio), rounded 12px corners, with the actual generated content at small scale
  - Tapping a template → generates full-res image → opens Instagram
  - "Back" text button to return to platform selection

---

## 9. System F: Celebration Screen

### Layout (top to bottom)
1. **Background**: Solid `FblaColors.darkBg` (matches current scaffold)
2. **Success icon**: Gold checkmark in a circle, scales in from 0.85 → 1.0 with opacity 0 → 1 (300ms, strong ease-out: `cubic-bezier(0.23, 1, 0.32, 1)`)
3. **Headline**: "Published!" — Josefin Sans 600, 28px, `FblaColors.darkTextPrimary` — fades in 100ms after icon (stagger)
4. **Subline**: "Your [post/event/announcement] is now live for [Chapter Name]." — Mulish 15px, `FblaColors.darkTextSecond` — fades in 150ms after headline
5. **Spacer**: 48px
6. **Section label**: "Share with your community" — Josefin Sans 500, 13px, `FblaColors.darkTextTertiary`, letter-spacing 0.5px, uppercase
7. **Share cards**: 3 horizontal cards (each ~100px wide), evenly spaced
   - Each card: `FblaColors.darkSurface` background, `FblaColors.darkOutline` border, rounded 16px
   - Platform icon (28px) centered
   - Platform name below: Mulish 13px, `FblaColors.darkTextPrimary`
   - Cards stagger in: 50ms delay between each (total 100ms stagger)
8. **Spacer**: grows (Expanded)
9. **Done button**: "Done" — Mulish 15px, `FblaColors.darkTextSecond`, no fill, no border, text button only. Centered.

### Interactions
- Tapping a share card: scale(0.97) press feedback (100ms ease-out), then executes share flow
- After sharing to a platform, that card gains a small gold checkmark in its top-right corner (12px, fade in 200ms)
- "Done" pops the celebration screen, returns to the relevant list screen
- Back gesture / Android back button: same as "Done"
- No auto-dismiss timer — advisor controls when to leave

### Animation Timeline
```
0ms    — Screen appears (instant, no page transition animation)
0ms    — Gold checkmark begins scale+opacity animation (300ms)
100ms  — "Published!" fades in (200ms)
250ms  — Subline fades in (200ms)
400ms  — Share cards stagger in (3 cards × 50ms = done by 550ms)
```
Total: interface is fully visible by ~550ms. Tight but not rushed.

### Per Emil Kowalski
- No bounce/elastic easing — smooth deceleration only
- The celebration is "rare" (once per publish), so animation is justified
- No confetti — that's a party, this is an achievement. The gold checkmark is enough.
- Press feedback on share cards uses 100ms/160ms asymmetric timing (press fast, release slightly slower)

---

## 10. System G: Events Tab Redesign

### Layout

**Top half — Interactive Calendar**
- Fills approximately 45% of the screen height
- Month/year header: Josefin Sans 600, 20px, centered
- Navigation: Left/right chevron icons flanking the month name
- Day-of-week labels: Mulish 12px, `FblaColors.darkTextTertiary`, uppercase, single letter (M T W T F S S)
- Day cells: 7-column grid, each cell 44×44px (accessibility minimum)
  - Default: Mulish 15px, `FblaColors.darkTextPrimary`
  - Today: Electric blue circle fill, white text
  - Selected: Gold circle fill, `FblaColors.onSecondary` text
  - Has events: Small dot below the number (4px, `FblaColors.primary` or gold if selected)
  - Past days: `FblaColors.darkTextTertiary` (dimmed)
  - Outside current month: `FblaColors.darkTextTertiary` at 40% opacity
- Tapping a day: selects it, filters the event list below to that day. If no events on that day, show all upcoming events with a label "No events on [date]. Showing upcoming."
- Swipe left/right on calendar: navigates months (300ms ease-out transition)

**Divider**
- A subtle drag handle (36px × 4px, `FblaColors.darkOutlineVar`, centered) sits between calendar and list
- Optional: make the split resizable via drag (stretch goal)

**Bottom half — Event List (scrollable)**
- Takes remaining ~55% of screen
- Scope filter chips at top: "All" / "Chapter" / "District" — horizontal chip row
- Sort toggle: small icon button (ascending/descending) at right edge of chip row
- Event cards in a `ListView.builder`
- Pull-to-refresh on the list portion
- FAB for advisors/admins: "+" button to create new event (bottom-right, gold fill)

### Interaction
- Calendar month swipe uses `PageView` with `FblaMotion.standard` (300ms) curve
- Day selection: immediate, no animation (this is a high-frequency action per Emil — no animation)
- Event list filters reactively when day changes
- Scroll the list independently of the calendar (the calendar stays pinned at top)

---

## 11. System H: Shared Platforms Badge (Member View)

### Rendering
- Appears below the card's existing metadata line (timestamp, author, etc.)
- Row of platform icons: Instagram (gradient icon or simplified camera icon), X (𝕏 logo)
- Icons: 14px, `FblaColors.darkTextTertiary` color (muted, not branded)
- Spacing: 6px between icons
- Only renders if the item's `shared_platforms` array is non-empty
- No tooltip, no interaction — purely informational

### Database
```sql
ALTER TABLE posts ADD COLUMN shared_platforms TEXT[] DEFAULT '{}';
ALTER TABLE events ADD COLUMN shared_platforms TEXT[] DEFAULT '{}';
ALTER TABLE announcements ADD COLUMN shared_platforms TEXT[] DEFAULT '{}';
```

### Backend
New endpoint for each content type:
```
POST /api/posts/:id/share        { "platform": "instagram" | "twitter" | "native" }
POST /api/events/:id/share       { "platform": "instagram" | "twitter" | "native" }
POST /api/announcements/:id/share { "platform": "instagram" | "twitter" | "native" }
```
Appends the platform to `shared_platforms` array if not already present. Returns updated array.
Only accessible by the content's creator or admin.

---

## 12. Database Migration Summary

```sql
-- Events: location image and place data
ALTER TABLE events ADD COLUMN location_image_url TEXT;
ALTER TABLE events ADD COLUMN place_id TEXT;
ALTER TABLE events ADD COLUMN registration_deadline TIMESTAMPTZ;

-- Shared platforms tracking
ALTER TABLE posts ADD COLUMN shared_platforms TEXT[] DEFAULT '{}';
ALTER TABLE events ADD COLUMN shared_platforms TEXT[] DEFAULT '{}';
ALTER TABLE announcements ADD COLUMN shared_platforms TEXT[] DEFAULT '{}';

-- Posts: ensure media_url column exists (should already exist)
-- No change needed

-- Index for shared_platforms queries (GIN for array containment)
CREATE INDEX idx_posts_shared ON posts USING GIN (shared_platforms);
CREATE INDEX idx_events_shared ON events USING GIN (shared_platforms);
CREATE INDEX idx_announcements_shared ON announcements USING GIN (shared_platforms);
```

---

## 13. New Dependencies

```yaml
# Add to pubspec.yaml
dependencies:
  share_plus: ^7.2.2           # Native share sheet
  image_picker: ^1.0.7         # Camera + gallery access for post images
  file_picker: ^6.1.1          # PDF selection for hub items
  # Google Places handled via HTTP (Dio) — no separate package needed
```

---

## 14. Open Questions

1. **Google Places API key**: Need a key for Places Autocomplete + Photos. Who provisions this? Any billing concerns?
2. **Apple Maps alternative**: Should we use Apple MapKit on iOS instead of Google Places? (Simpler, free, but less data outside US)
3. **Image compression**: Should we compress images client-side before upload? (Recommend yes — max 1200px width, JPEG 85% quality to keep Storage costs down)
4. **Story template caching**: Should generated story images be cached locally or regenerated each time? (Recommend: cache the last generated image per item, invalidate on content edit)
5. **Offline post drafts**: Should partially-written posts persist if the app is backgrounded? (Recommend: yes, save to secure storage, restore on return)

---

## 15. Implementation Order (Recommended)

1. **Database migration** — add columns, indexes
2. **Backend endpoints** — upload, share tracking, places proxy
3. **Post creation flow** — new 2-screen flow with image picker + pre-upload
4. **Event creation flow** — maps integration + location photos
5. **Celebration screen** — post-creation success + share prompt
6. **Social share flow** — Instagram Stories templates, X, native share
7. **Events tab redesign** — interactive calendar + list split
8. **Hub PDF upload** — file picker + upload
9. **Share badge on cards** — member-facing platform icons
10. **Polish pass** — animations, edge cases, error states
