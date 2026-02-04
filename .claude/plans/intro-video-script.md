# MCP Contxt - Intro Video Script

## Overview

A 3-5 minute walkthrough video demonstrating MCP Contxt's core functionality. The video will show adding MCP servers (Linear, Notion, GoDaddy), authenticating them in Claude Code, and using them together in a real workflow: brainstorming domain names with Claude, checking availability via GoDaddy, and creating a follow-up ticket in Linear.

**Target audience:** Developers and non-technical users who want to connect Claude to external tools.

**Where to publish:**
- mcpcontxt.com (homepage hero or dedicated page)
- GitHub README (embedded or linked)
- YouTube/Vimeo for hosting

---

## Video Script

### Opening (0:00 - 0:15)

**[Screen: Desktop with menu bar visible]**

> "Managing MCP servers for Claude Code usually means editing JSON config files. MCP Contxt makes it simple - browse, add, and manage your servers from a clean interface. Let me show you how it works."

---

### Part 1: Installing MCP Servers (0:15 - 1:30)

**[Action: Click MCP Contxt icon in menu bar]**

> "MCP Contxt lives in your menu bar. Click to see your configured servers - right now I don't have any."

**[Action: Click "Browse" button]**

> "Let's add some. Click Browse to see all available MCP servers."

**[Action: Scroll through the catalog]**

> "There are over 100 servers here - project management, CRMs, databases, and more. Let's add a few."

**[Action: Search for "Linear", click Add]**

> "First, Linear for project management. Just click Add."

**[Action: Search for "Notion", click Add]**

> "Notion for documentation..."

**[Action: Search for "GoDaddy", click Add]**

> "And GoDaddy for domain lookups. That's it - three servers added in seconds."

**[Action: Click Done, show menu bar popover with 3 servers]**

> "Now they show up in my menu bar. But before Claude can use them, we need to authenticate."

---

### Part 2: Authenticating in Claude Code (1:30 - 2:15)

**[Action: Open terminal, type `claude`]**

> "Open your terminal and start Claude Code."

**[Action: Type `/mcp`]**

> "Type `/mcp` to see your MCP servers."

**[Screen: Shows list of servers with auth status]**

> "Here are our three servers. Linear and Notion need authentication - see the indicators."

**[Action: Select Linear from the list]**

> "Select Linear..."

**[Screen: Browser opens with Linear OAuth]**

> "...and it opens your browser to complete the OAuth flow. Authorize the connection..."

**[Action: Complete OAuth, return to terminal]**

> "Done. Linear is now connected. I'll do the same for Notion."

**[Action: Authenticate Notion quickly (can speed up in editing)]**

> "Same process - select, authorize, done."

**[Action: Show `/mcp` again with green checkmarks]**

> "Now both show as connected. GoDaddy works without auth - it's ready to go."

---

### Part 3: Real Workflow Demo (2:15 - 4:00)

**[Action: Start a new Claude conversation]**

> "Now let's use these together. I'm working on a new side project and need a domain name."

**[Action: Type prompt]**

**Prompt:** "I'm building a tool that helps developers track their coffee consumption and correlate it with their coding productivity. Can you brainstorm 10 creative domain name ideas?"

**[Screen: Claude responds with domain suggestions]**

> "Claude gives me some ideas. Let's see which ones are actually available."

**[Action: Type follow-up]**

**Prompt:** "Check if any of these are available as .com domains using GoDaddy"

**[Screen: Claude uses GoDaddy MCP to check domains]**

> "Claude automatically uses the GoDaddy server to check availability. Nice - looks like 'brewmetrics.com' is available."

**[Action: Type follow-up]**

**Prompt:** "Great! Create a ticket in Linear to register brewmetrics.com. Put it in my 'Side Projects' project with high priority."

**[Screen: Claude uses Linear MCP to create ticket]**

> "And just like that, Claude creates the ticket in Linear. Let me verify..."

**[Action: Open Linear in browser, show the ticket]**

> "There it is - complete with the details. That entire workflow - brainstorming, domain checking, and task creation - all from one conversation."

---

### Closing (4:00 - 4:30)

**[Action: Click MCP Contxt icon, show servers]**

> "MCP Contxt makes it easy to manage which tools Claude can access. Add servers in seconds, authenticate once, and let Claude handle the rest."

**[Screen: Show mcpcontxt.com or GitHub]**

> "Download MCP Contxt for free at mcpcontxt.com, or find it on GitHub. Links in the description."

**[End card with links]**

---

## B-Roll / Cutaway Suggestions

- Close-up of menu bar icon
- The Browse catalog scrolling (sped up)
- OAuth flow completion animation
- Linear ticket appearing in the app
- Split screen: Claude conversation + Linear/GoDaddy results

---

## Recording Notes

### Technical Setup
- Resolution: 1920x1080 or 2560x1440 (Retina)
- Clean desktop - hide personal files/bookmarks
- Use a demo Linear workspace (not production)
- Have domains ready that you know are available/unavailable for consistent results

### Pacing
- Keep it brisk - this is a demo, not a tutorial
- Speed up repetitive actions (second OAuth flow)
- Pause briefly on key moments (server added confirmation, ticket created)

### Audio
- Record voiceover separately for cleaner audio
- Background music: subtle, upbeat, tech-friendly

### Editing
- Add subtle zoom on important UI elements
- Use transitions between major sections
- Add captions for accessibility

---

## Alternative Demo Ideas

If the GoDaddy → Linear flow doesn't work smoothly, alternatives:

1. **Notion + Linear**: "Summarize this Notion doc and create action items in Linear"
2. **Multiple domain checks**: Just focus on GoDaddy - check 10 domains, show results
3. **Linear only**: Create a ticket, then ask Claude to break it into subtasks

---

## Pre-Recording Checklist

- [ ] MCP Contxt installed and working
- [ ] Clean Linear workspace with "Side Projects" project
- [ ] Notion connected with some test content
- [ ] GoDaddy server working (test domain lookup)
- [ ] Test the exact prompts to ensure they work
- [ ] Desktop cleaned up (hide sensitive tabs, bookmarks)
- [ ] Screen recording software ready (OBS, ScreenFlow, etc.)
- [ ] Microphone tested
- [ ] Caffeine/Amphetamine running (prevent sleep during recording)
