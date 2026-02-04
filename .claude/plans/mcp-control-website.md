# MCP Contxt Website - Laravel 12 + Inertia + React

## Project Info

- **Domain**: mcpcontxt.com
- **Repository**: github.com/carlweis/mcpcontxt-website
- **Tech Stack**: Laravel 12, Inertia.js, React, TypeScript, Tailwind CSS v4, SQLite

## Summary

A simple marketing website for MCP Contxt with:
- Coming soon landing page → Download page (post-launch)
- Email waitlist collection
- Download tracking
- Admin dashboard for stats

**Intentionally simple.** Show 5-7 featured MCP servers as a preview to incentivize app downloads. Users get the full catalog in the app itself.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Backend | Laravel 12 |
| Frontend | React 18, TypeScript |
| Bridge | Inertia.js |
| Styling | Tailwind CSS v4 |
| Database | PostgreSQL |
| Starter | Laravel React Starter Kit |

**Project setup:** You'll create the initial project with `laravel new` using the React starter kit. Claude builds out the app from there.

---

## Pages

| Route | Page | Description |
|-------|------|-------------|
| `/` | Home | Coming soon → Download page |
| `/admin` | Dashboard | Stats overview |
| `/admin/subscribers` | Subscribers | View/export waitlist |
| `/admin/downloads` | Downloads | Download analytics |

That's it. Four pages.

---

## Database Schema

Only two tables (plus Laravel's default users table for admin auth):

```php
// database/migrations/xxxx_create_subscribers_table.php
Schema::create('subscribers', function (Blueprint $table) {
    $table->id();
    $table->string('email')->unique();
    $table->string('source')->default('website');
    $table->timestamps();
});

// database/migrations/xxxx_create_downloads_table.php
Schema::create('downloads', function (Blueprint $table) {
    $table->id();
    $table->string('version');
    $table->string('referrer')->nullable();
    $table->timestamps();
});
```

---

## Home Page Layout

```
┌─────────────────────────────────────────────────────────────┐
│  Navigation                                                 │
│  [Logo] MCP Contxt                            [GitHub]     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Hero                                                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  [App Icon]                                          │   │
│  │                                                      │   │
│  │  MCP Contxt                                         │   │
│  │  The missing management interface for                │   │
│  │  MCP servers in Claude Code                          │   │
│  │                                                      │   │
│  │  [Download for macOS]  or  [Join Waitlist]           │   │
│  │                                                      │   │
│  │  Requires macOS 15.0+ • Free & Open Source           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  Screenshots (3 images in a row)                            │
│  [Menu Bar]    [Browse Servers]    [Server Detail]          │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  Featured Servers Preview                                   │
│  "Works with 100+ MCP servers including:"                   │
│                                                             │
│  [Linear]  [Notion]  [Figma]  [Slack]  [GitHub]  [+95 more] │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  Features (4 cards)                                         │
│  [Browse]  [One-Click]  [Status]  [Auto-Sync]               │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  How It Works (3 steps)                                     │
│  1. Download & Install                                      │
│  2. Browse & Add Servers                                    │
│  3. Authenticate in Claude Code                             │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  Footer                                                     │
│  [GitHub] • MIT License • Built for the Claude community    │
└─────────────────────────────────────────────────────────────┘
```

---

## Featured Servers (Hardcoded)

Just display these as logos/cards on the home page:

```typescript
const featuredServers = [
  { name: 'Linear', icon: '/images/servers/linear.svg', url: 'https://linear.app' },
  { name: 'Notion', icon: '/images/servers/notion.svg', url: 'https://notion.com' },
  { name: 'Figma', icon: '/images/servers/figma.svg', url: 'https://figma.com' },
  { name: 'Slack', icon: '/images/servers/slack.svg', url: 'https://slack.com' },
  { name: 'GitHub', icon: '/images/servers/github.svg', url: 'https://github.com' },
  { name: 'Stripe', icon: '/images/servers/stripe.svg', url: 'https://stripe.com' },
];
```

No database, no sync, no management. Just static content.

---

## Implementation

### Models

```php
// app/Models/Subscriber.php
class Subscriber extends Model
{
    protected $fillable = ['email', 'source'];
}

// app/Models/Download.php
class Download extends Model
{
    protected $fillable = ['version', 'referrer'];
}
```

### Controllers

```php
// app/Http/Controllers/HomeController.php
class HomeController extends Controller
{
    public function index()
    {
        return Inertia::render('Home', [
            'launched' => config('app.launched', false),
            'version' => config('app.version', '1.0.0'),
        ]);
    }
}

// app/Http/Controllers/SubscriberController.php
class SubscriberController extends Controller
{
    public function store(Request $request)
    {
        $request->validate(['email' => 'required|email|unique:subscribers']);

        Subscriber::create([
            'email' => $request->email,
            'source' => $request->source ?? 'website',
        ]);

        return back()->with('success', 'You're on the list!');
    }
}

// app/Http/Controllers/DownloadController.php
class DownloadController extends Controller
{
    public function download(Request $request)
    {
        $version = config('app.version', '1.0.0');

        Download::create([
            'version' => $version,
            'referrer' => $request->header('referer'),
        ]);

        // Redirect to GitHub release
        return redirect("https://github.com/carlweis/mcpcontxt/releases/download/v{$version}/MCPControl-{$version}.dmg");
    }
}
```

### Admin Controllers

```php
// app/Http/Controllers/Admin/DashboardController.php
class DashboardController extends Controller
{
    public function index()
    {
        return Inertia::render('Admin/Dashboard', [
            'stats' => [
                'subscribers' => Subscriber::count(),
                'subscribers_today' => Subscriber::whereDate('created_at', today())->count(),
                'downloads' => Download::count(),
                'downloads_today' => Download::whereDate('created_at', today())->count(),
            ],
            'recentSubscribers' => Subscriber::latest()->take(10)->get(),
            'recentDownloads' => Download::latest()->take(10)->get(),
        ]);
    }
}
```

### Routes

```php
// routes/web.php
Route::get('/', [HomeController::class, 'index'])->name('home');
Route::post('/subscribe', [SubscriberController::class, 'store'])->name('subscribe');
Route::get('/download', [DownloadController::class, 'download'])->name('download');

Route::middleware(['auth'])->prefix('admin')->name('admin.')->group(function () {
    Route::get('/', [Admin\DashboardController::class, 'index'])->name('dashboard');
    Route::get('/subscribers', [Admin\SubscriberController::class, 'index'])->name('subscribers');
    Route::get('/subscribers/export', [Admin\SubscriberController::class, 'export'])->name('subscribers.export');
    Route::get('/downloads', [Admin\DownloadController::class, 'index'])->name('downloads');
});
```

### CSV Export

```php
// app/Http/Controllers/Admin/SubscriberController.php
public function export()
{
    $subscribers = Subscriber::all();

    $callback = function () use ($subscribers) {
        $file = fopen('php://output', 'w');
        fputcsv($file, ['email', 'source', 'signed_up']);

        foreach ($subscribers as $subscriber) {
            fputcsv($file, [
                $subscriber->email,
                $subscriber->source,
                $subscriber->created_at->toDateString(),
            ]);
        }

        fclose($file);
    };

    return response()->stream($callback, 200, [
        'Content-Type' => 'text/csv',
        'Content-Disposition' => 'attachment; filename="subscribers-' . now()->format('Y-m-d') . '.csv"',
    ]);
}
```

Export the CSV, upload to Mailchimp, send your launch email. Done.

---

## React Pages

### Home.tsx

```tsx
import { Head, useForm } from '@inertiajs/react';

interface Props {
  launched: boolean;
  version: string;
}

export default function Home({ launched, version }: Props) {
  const { data, setData, post, processing, recentlySuccessful } = useForm({
    email: '',
  });

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    post('/subscribe');
  };

  return (
    <>
      <Head title="MCP Contxt - Manage MCP Servers for Claude" />

      {/* Hero */}
      <section className="py-20 text-center">
        <img src="/images/app-icon.png" alt="MCP Contxt" className="w-24 h-24 mx-auto mb-8" />
        <h1 className="text-5xl font-bold mb-6">MCP Contxt</h1>
        <p className="text-xl text-gray-600 mb-8 max-w-2xl mx-auto">
          The missing management interface for MCP servers in Claude Code
        </p>

        {launched ? (
          <a href="/download" className="btn-primary">
            Download for macOS
          </a>
        ) : (
          <form onSubmit={submit} className="max-w-md mx-auto flex gap-2">
            <input
              type="email"
              value={data.email}
              onChange={e => setData('email', e.target.value)}
              placeholder="you@example.com"
              className="input flex-1"
            />
            <button type="submit" disabled={processing} className="btn-primary">
              {recentlySuccessful ? '✓ Added!' : 'Join Waitlist'}
            </button>
          </form>
        )}

        <p className="mt-4 text-sm text-gray-500">
          Requires macOS 15.0+ • Free & Open Source
        </p>
      </section>

      {/* Screenshots */}
      <section className="py-16 bg-gray-50">
        {/* ... */}
      </section>

      {/* Featured Servers */}
      <section className="py-16">
        <h2 className="text-center text-2xl font-bold mb-2">
          Works with 100+ MCP servers
        </h2>
        <p className="text-center text-gray-600 mb-8">Including:</p>
        <div className="flex justify-center gap-8">
          {featuredServers.map(server => (
            <div key={server.name} className="text-center">
              <img src={server.icon} alt={server.name} className="w-12 h-12 mx-auto mb-2" />
              <span className="text-sm text-gray-600">{server.name}</span>
            </div>
          ))}
          <div className="text-center">
            <div className="w-12 h-12 rounded-full bg-gray-200 flex items-center justify-center mx-auto mb-2">
              <span className="text-gray-500 text-sm">+95</span>
            </div>
            <span className="text-sm text-gray-600">more</span>
          </div>
        </div>
      </section>

      {/* Features, How It Works, Footer... */}
    </>
  );
}
```

### Admin/Dashboard.tsx

```tsx
import { Head } from '@inertiajs/react';

interface Props {
  stats: {
    subscribers: number;
    subscribers_today: number;
    downloads: number;
    downloads_today: number;
  };
  recentSubscribers: Array<{ id: number; email: string; created_at: string }>;
  recentDownloads: Array<{ id: number; version: string; created_at: string }>;
}

export default function Dashboard({ stats, recentSubscribers, recentDownloads }: Props) {
  return (
    <>
      <Head title="Dashboard" />

      <h1 className="text-2xl font-bold mb-8">Dashboard</h1>

      {/* Stats */}
      <div className="grid grid-cols-4 gap-6 mb-8">
        <StatCard label="Total Subscribers" value={stats.subscribers} />
        <StatCard label="Today" value={stats.subscribers_today} />
        <StatCard label="Total Downloads" value={stats.downloads} />
        <StatCard label="Today" value={stats.downloads_today} />
      </div>

      {/* Recent activity tables */}
      <div className="grid grid-cols-2 gap-6">
        <RecentSubscribers subscribers={recentSubscribers} />
        <RecentDownloads downloads={recentDownloads} />
      </div>
    </>
  );
}
```

---

## Config

```php
// config/app.php
return [
    // ...existing config...

    'launched' => env('APP_LAUNCHED', false),
    'version' => env('APP_VERSION', '1.0.0'),
];
```

```env
# .env
APP_LAUNCHED=false
APP_VERSION=1.0.0
```

When ready to launch, flip `APP_LAUNCHED=true` and the home page switches from waitlist form to download button.

---

## Files to Create

| File | Purpose |
|------|---------|
| `app/Models/Subscriber.php` | Waitlist model |
| `app/Models/Download.php` | Download tracking model |
| `app/Http/Controllers/HomeController.php` | Home page |
| `app/Http/Controllers/SubscriberController.php` | Email signup |
| `app/Http/Controllers/DownloadController.php` | Track & redirect |
| `app/Http/Controllers/Admin/DashboardController.php` | Admin stats |
| `app/Http/Controllers/Admin/SubscriberController.php` | View subscribers |
| `app/Http/Controllers/Admin/DownloadController.php` | View downloads |
| `resources/js/pages/Home.tsx` | Landing page |
| `resources/js/pages/Admin/Dashboard.tsx` | Admin dashboard |
| `resources/js/pages/Admin/Subscribers.tsx` | Subscriber list |
| `resources/js/pages/Admin/Downloads.tsx` | Download list |
| `database/migrations/*_create_subscribers_table.php` | |
| `database/migrations/*_create_downloads_table.php` | |

---

## Assets Needed

- `public/images/app-icon.png` - App icon (512x512)
- `public/images/screenshot-menu.png` - Menu bar screenshot
- `public/images/screenshot-browse.png` - Browse view screenshot
- `public/images/screenshot-detail.png` - Server detail screenshot
- `public/images/og-image.png` - Social preview (1200x630)
- `public/images/servers/*.svg` - Logos for featured servers (Linear, Notion, etc.)

---

## Launch Checklist

### Phase 1: Coming Soon
- [ ] Laravel 12 project created with React starter kit
- [ ] Migrations created and run
- [ ] Home page with waitlist form
- [ ] Admin dashboard working
- [ ] Deployed to Forge
- [ ] Domain configured
- [ ] Screenshots added

### Phase 2: Launch
- [ ] Video recorded and embedded
- [ ] `APP_LAUNCHED=true`
- [ ] Download tracking verified
- [ ] Announce on socials

---

## Deployment

Laravel Forge + DigitalOcean ($6/mo droplet with PostgreSQL)

1. Create droplet
2. Add site in Forge (provision with PostgreSQL)
3. Connect GitHub repo
4. Set environment variables
5. Enable SSL
6. Deploy

Done.
