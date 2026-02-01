//
//  MCPCatalog.swift
//  MCP Contxt
//
//  Static catalog of MCP servers from Anthropic registry
//  No network requests needed - data embedded in app
//

import Foundation

struct MCPCatalogServer: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let url: String
    let transport: TransportType

    enum TransportType: String {
        case http
        case sse
    }
}

struct MCPCatalog {

    static func search(_ query: String) -> [MCPCatalogServer] {
        guard !query.isEmpty else { return servers }
        let q = query.lowercased()
        return servers.filter {
            $0.name.lowercased().contains(q) ||
            $0.description.lowercased().contains(q) ||
            $0.id.lowercased().contains(q)
        }
    }

    // MARK: - Server Catalog (91 servers from Anthropic registry)

    static let servers: [MCPCatalogServer] = [
        MCPCatalogServer(
            id: "ahrefs",
            name: "Ahrefs",
            description: "SEO & AI search analytics",
            url: "https://api.ahrefs.com/mcp/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "aiera",
            name: "Aiera",
            description: "Live events, filings, company publications, and more",
            url: "https://mcp-pub.aiera.com/",
            transport: .http
        ),
        MCPCatalogServer(
            id: "airops",
            name: "AirOps",
            description: "Craft content that wins AI search",
            url: "https://app.airops.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "amplitude",
            name: "Amplitude",
            description: "Search, access, and get insights on your Amplitude data",
            url: "https://mcp.amplitude.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "asana",
            name: "Asana",
            description: "Connect to Asana to coordinate tasks, projects, and goals",
            url: "https://mcp.asana.com/v2/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "atlassian",
            name: "Atlassian",
            description: "Access Jira & Confluence from Claude",
            url: "https://mcp.atlassian.com/v1/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "aura",
            name: "Aura",
            description: "Company intelligence & workforce analytics",
            url: "https://mcp.auraintelligence.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "aws-marketplace",
            name: "AWS Marketplace",
            description: "Discover, evaluate, and buy solutions for the cloud",
            url: "https://marketplace-mcp.us-east-1.api.aws/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "biorender",
            name: "BioRender",
            description: "Search for and use scientific templates and icons",
            url: "https://mcp.services.biorender.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "biorxiv",
            name: "bioRxiv",
            description: "Access bioRxiv and medRxiv preprint data",
            url: "https://mcp.deepsense.ai/biorxiv/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "bitly",
            name: "Bitly",
            description: "Shorten links, generate QR Codes, and track performance",
            url: "https://api-ssl.bitly.com/v4/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "blockscout",
            name: "Blockscout",
            description: "Access and analyze blockchain data",
            url: "https://mcp.blockscout.com/mcp/",
            transport: .http
        ),
        MCPCatalogServer(
            id: "box",
            name: "Box",
            description: "Search, access and get insights on your Box content",
            url: "https://mcp.box.com",
            transport: .http
        ),
        MCPCatalogServer(
            id: "canva",
            name: "Canva",
            description: "Search, create, autofill, and export Canva designs",
            url: "https://mcp.canva.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "cdata-connect-ai",
            name: "CData Connect AI",
            description: "Managed MCP platform for 350 sources",
            url: "https://mcp.cloud.cdata.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "chembl",
            name: "ChEMBL",
            description: "Access the ChEMBL Database",
            url: "https://mcp.deepsense.ai/chembl/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "circleback",
            name: "Circleback",
            description: "Search and access context from meetings",
            url: "https://app.circleback.ai/api/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "clay",
            name: "Clay",
            description: "Find prospects. Research accounts. Personalize outreach",
            url: "https://api.clay.com/v3/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "clickup",
            name: "ClickUp",
            description: "Project management & collaboration for teams & agents",
            url: "https://mcp.clickup.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "clinical-trials",
            name: "Clinical Trials",
            description: "Access ClinicalTrials.gov data",
            url: "https://mcp.deepsense.ai/clinical_trials/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "clockwise",
            name: "Clockwise",
            description: "Advanced scheduling and time management for work",
            url: "https://mcp.getclockwise.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "close",
            name: "Close",
            description: "Connect Claude to Close CRM to access and act on your sales data",
            url: "https://mcp.close.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "cloudflare",
            name: "Cloudflare",
            description: "Build applications with compute, storage, and AI",
            url: "https://bindings.mcp.cloudflare.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "cloudinary",
            name: "Cloudinary",
            description: "Manage, transform and deliver your images & videos",
            url: "https://asset-management.mcp.cloudinary.com/sse",
            transport: .sse
        ),
        MCPCatalogServer(
            id: "cms-coverage",
            name: "CMS Coverage",
            description: "Access the CMS Coverage Database",
            url: "https://mcp.deepsense.ai/cms_coverage/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "crossbeam",
            name: "Crossbeam",
            description: "Explore partner data and ecosystem insights in Claude",
            url: "https://mcp.crossbeam.com",
            transport: .http
        ),
        MCPCatalogServer(
            id: "crypto-com",
            name: "Crypto.com",
            description: "Real time prices, orders, charts, and more for crypto",
            url: "https://mcp.crypto.com/market-data/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "daloopa",
            name: "Daloopa",
            description: "Financial fundamental data and KPIs with hyperlinks",
            url: "https://mcp.daloopa.com/server/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "day-ai",
            name: "Day AI",
            description: "Analyze & update CRM records",
            url: "https://day.ai/api/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "devrev",
            name: "DevRev",
            description: "Search and update your company's knowledge graph",
            url: "https://api.devrev.ai/mcp/v1",
            transport: .http
        ),
        MCPCatalogServer(
            id: "egnyte",
            name: "Egnyte",
            description: "Securely access and analyze Egnyte content",
            url: "https://mcp-server.egnyte.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "fellow",
            name: "Fellow.ai",
            description: "Chat with your meetings to uncover actionable insights",
            url: "https://fellow.app/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "figma",
            name: "Figma",
            description: "Generate diagrams and better code from Figma context",
            url: "https://mcp.figma.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "fireflies",
            name: "Fireflies",
            description: "Analyze and generate insights from meeting transcripts",
            url: "https://api.fireflies.ai/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "gamma",
            name: "Gamma",
            description: "Create presentations, docs, socials, and sites with AI",
            url: "https://mcp.gamma.app/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "github",
            name: "GitHub",
            description: "Access GitHub repositories, issues, and pull requests",
            url: "https://api.githubcopilot.com/mcp/",
            transport: .http
        ),
        MCPCatalogServer(
            id: "godaddy",
            name: "GoDaddy",
            description: "Search domains and check availability",
            url: "https://api.godaddy.com/v1/domains/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "bigquery",
            name: "Google Cloud BigQuery",
            description: "BigQuery: Advanced analytical insights for agents",
            url: "https://bigquery.googleapis.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "guru",
            name: "Guru",
            description: "Search and interact with your company knowledge",
            url: "https://mcp.api.getguru.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "harmonic",
            name: "Harmonic",
            description: "Discover, research, and enrich companies and people",
            url: "https://mcp.api.harmonic.ai",
            transport: .http
        ),
        MCPCatalogServer(
            id: "hubspot",
            name: "HubSpot",
            description: "Chat with your CRM data to get personalized insights",
            url: "https://mcp.hubspot.com/anthropic",
            transport: .http
        ),
        MCPCatalogServer(
            id: "huggingface",
            name: "Hugging Face",
            description: "Access the Hugging Face Hub and thousands of Gradio Apps",
            url: "https://huggingface.co/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "icd-10-codes",
            name: "ICD-10 Codes",
            description: "Access ICD-10-CM and ICD-10-PCS code sets",
            url: "https://mcp.deepsense.ai/icd10_codes/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "indeed",
            name: "Indeed",
            description: "Search for jobs on Indeed",
            url: "https://mcp.indeed.com/claude/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "intercom",
            name: "Intercom",
            description: "Access to Intercom data for better customer insights",
            url: "https://mcp.intercom.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "jotform",
            name: "Jotform",
            description: "Create forms & analyze submissions inside Claude",
            url: "https://mcp.jotform.com/",
            transport: .http
        ),
        MCPCatalogServer(
            id: "kiwi",
            name: "Kiwi.com",
            description: "Search flights in Claude",
            url: "https://mcp.kiwi.com",
            transport: .http
        ),
        MCPCatalogServer(
            id: "klaviyo",
            name: "Klaviyo",
            description: "Report, strategize & create with real-time Klaviyo data",
            url: "https://mcp.klaviyo.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "lastminute",
            name: "lastminute.com",
            description: "Search, compare and book flights across global airlines",
            url: "https://mcp.lastminute.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "lilt",
            name: "LILT",
            description: "High-quality translation with human verification",
            url: "https://mcp.lilt.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "linear",
            name: "Linear",
            description: "Manage issues, projects & team workflows in Linear",
            url: "https://mcp.linear.app/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "lseg",
            name: "LSEG",
            description: "Access data & analytics across asset classes",
            url: "https://api.analytics.lseg.com/lfa/mcp/server-cl",
            transport: .http
        ),
        MCPCatalogServer(
            id: "lunarcrush",
            name: "LunarCrush",
            description: "Add real-time social media data to your searches",
            url: "https://lunarcrush.ai/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "make",
            name: "Make",
            description: "Run Make scenarios and manage your Make account",
            url: "https://mcp.make.com",
            transport: .http
        ),
        MCPCatalogServer(
            id: "medidata",
            name: "Medidata",
            description: "Clinical trial software and site ranking tools",
            url: "https://mcp.imedidata.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "melon",
            name: "Melon",
            description: "Browse music charts & your personalized music picks",
            url: "https://mcp.melon.com/mcp/",
            transport: .http
        ),
        MCPCatalogServer(
            id: "mercury",
            name: "Mercury",
            description: "Search, analyze and understand your finances on Mercury",
            url: "https://mcp.mercury.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "mermaid",
            name: "Mermaid Chart",
            description: "Validates & renders Mermaid diagrams as PNG images",
            url: "https://mcp.mermaidchart.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "monday",
            name: "monday.com",
            description: "Manage projects, boards, and workflows in monday.com",
            url: "https://mcp.monday.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "moodys",
            name: "Moody's",
            description: "Risk insights, analytics, and decision intelligence",
            url: "https://api.moodys.com/genai-ready-data/m1/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "morningstar",
            name: "Morningstar",
            description: "Up-to-date investment and market insights",
            url: "https://mcp.morningstar.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "motherduck",
            name: "MotherDuck",
            description: "Analyze your data with natural language",
            url: "https://api.motherduck.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "mt-newswires",
            name: "MT Newswires",
            description: "Trusted real-time global financial news provider",
            url: "https://vast-mcp.blueskyapi.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "netlify",
            name: "Netlify",
            description: "Create, deploy, manage, and secure websites on Netlify",
            url: "https://netlify-mcp.netlify.app/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "notion",
            name: "Notion",
            description: "Connect your Notion workspace to search and update",
            url: "https://mcp.notion.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "npi-registry",
            name: "NPI Registry",
            description: "Access US National Provider Identifier (NPI) Registry",
            url: "https://mcp.deepsense.ai/npi_registry/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "owkin",
            name: "Owkin",
            description: "Interact with AI agents built for biology",
            url: "https://mcp.k.owkin.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "paypal",
            name: "PayPal",
            description: "Access PayPal payments platform",
            url: "https://mcp.paypal.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "pitchbook",
            name: "PitchBook Premium",
            description: "PitchBook data, embedded in the way you work",
            url: "https://premium.mcp.pitchbook.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "plaid",
            name: "Plaid Developer Tools",
            description: "Monitor, debug, and optimize your Plaid integration",
            url: "https://api.dashboard.plaid.com/mcp/sse",
            transport: .sse
        ),
        MCPCatalogServer(
            id: "playmcp",
            name: "PlayMCP",
            description: "Connect and use PlayMCP servers in your toolbox",
            url: "https://playmcp.kakao.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "pubmed",
            name: "PubMed",
            description: "Search biomedical literature from PubMed",
            url: "https://pubmed.mcp.claude.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "ramp",
            name: "Ramp",
            description: "Search, access, and analyze your Ramp financial data",
            url: "https://ramp-mcp-remote.ramp.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "sp-global",
            name: "S&P Global",
            description: "Query a range of S&P Global datasets",
            url: "https://kfinance.kensho.com/integrations/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "scholar-gateway",
            name: "Scholar Gateway",
            description: "Enhance responses with scholarly research and citations",
            url: "https://connector.scholargateway.ai/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "sentry",
            name: "Sentry",
            description: "Monitor errors and debug production issues",
            url: "https://mcp.sentry.dev/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "similarweb",
            name: "Similarweb",
            description: "Real time web, mobile app, and market data",
            url: "https://mcp.similarweb.com",
            transport: .http
        ),
        MCPCatalogServer(
            id: "slack",
            name: "Slack",
            description: "Send messages, create canvases, and fetch Slack data",
            url: "https://mcp.slack.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "smartsheet",
            name: "Smartsheet",
            description: "Analyze and manage Smartsheet data with Claude",
            url: "https://mcp.smartsheet.com",
            transport: .http
        ),
        MCPCatalogServer(
            id: "square",
            name: "Square",
            description: "Search and manage transaction, merchant, and payment data",
            url: "https://mcp.squareup.com/sse",
            transport: .sse
        ),
        MCPCatalogServer(
            id: "stripe",
            name: "Stripe",
            description: "Payment processing and financial infrastructure tools",
            url: "https://mcp.stripe.com",
            transport: .http
        ),
        MCPCatalogServer(
            id: "supabase",
            name: "Supabase",
            description: "Manage databases, authentication, and storage",
            url: "https://mcp.supabase.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "ticket-tailor",
            name: "Ticket Tailor",
            description: "Event platform for managing tickets, orders & more",
            url: "https://mcp.tickettailor.ai/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "trivago",
            name: "Trivago",
            description: "Find your ideal hotel at the best price",
            url: "https://mcp.trivago.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "udemy",
            name: "Udemy Business",
            description: "Search and explore skill-building resources",
            url: "https://api.udemy.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "vercel",
            name: "Vercel",
            description: "Analyze, debug, and manage projects and deployments",
            url: "https://mcp.vercel.com/",
            transport: .http
        ),
        MCPCatalogServer(
            id: "vibe-prospecting",
            name: "Vibe Prospecting",
            description: "Find company & contact data",
            url: "https://vibeprospecting.explorium.ai/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "webflow",
            name: "Webflow",
            description: "Manage Webflow CMS, pages, assets and sites",
            url: "https://mcp.webflow.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "windsor",
            name: "Windsor.ai",
            description: "Connect 325+ marketing, analytics and CRM data sources",
            url: "https://mcp.windsor.ai",
            transport: .http
        ),
        MCPCatalogServer(
            id: "wix",
            name: "Wix",
            description: "Manage and build sites and apps on Wix",
            url: "https://mcp.wix.com/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "wordpress",
            name: "WordPress.com",
            description: "Secure AI access to manage your WordPress.com sites",
            url: "https://public-api.wordpress.com/wpcom/v2/mcp/v1",
            transport: .http
        ),
        MCPCatalogServer(
            id: "wyndham",
            name: "Wyndham Hotels",
            description: "Discover the right Wyndham Hotel for you, faster",
            url: "https://mcp.wyndhamhotels.com/claude/mcp",
            transport: .http
        ),
        MCPCatalogServer(
            id: "zoominfo",
            name: "ZoomInfo",
            description: "Enrich contacts & accounts with GTM intelligence",
            url: "https://mcp.zoominfo.com/mcp",
            transport: .http
        ),
    ]
}
