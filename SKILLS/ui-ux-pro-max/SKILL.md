---
name: ui-ux-pro-max
description: "UI/UX design intelligence for web and mobile apps. Use this skill when creating, designing, reviewing or improving any UI — including Flutter mobile/tablet apps, landing pages, dashboards, components, or design systems. Includes 50+ styles, 161 color palettes, 57 font pairings, 161 product types, 99 UX guidelines, and 25 chart types. Actions: plan, build, create, design, implement, review, fix, improve, optimize, enhance, refactor, and check UI/UX code. Projects: Flutter app, mobile app, landing page, dashboard, admin panel, e-commerce, SaaS, portfolio. Styles: glassmorphism, claymorphism, minimalism, brutalism, neumorphism, bento grid, dark mode, responsive, Material 3. Topics: color systems, accessibility, animation, layout, typography, spacing, interaction states."
---

# UI/UX Pro Max - Design Intelligence

Comprehensive design guide for web and mobile applications, with special focus on Flutter/Dart mobile and tablet apps. Contains 50+ styles, 161 color palettes, 57 font pairings, 161 product types with reasoning rules, 99 UX guidelines, and 25 chart types across 10 technology stacks including Flutter. Searchable database with priority-based recommendations.

## When to Apply

This Skill should be used when the task involves **UI structure, visual design decisions, interaction patterns, or user experience quality control**.

### Must Use

- Designing new screens/pages (Home, Dashboard, Onboarding, Settings, Profile)
- Creating or refactoring UI components (buttons, modals, forms, cards, navigation)
- Choosing color schemes, typography systems, spacing standards, or layout systems
- Reviewing UI code for user experience, accessibility, or visual consistency
- Implementing navigation structures, animations, or responsive behavior for mobile/tablet
- Making product-level design decisions (style, information hierarchy, brand expression)
- Improving perceived quality, clarity, or usability of Flutter apps

### Recommended

- UI looks "not professional enough" but the reason is unclear
- Receiving feedback on usability or experience
- Pre-launch UI quality optimization
- Aligning cross-platform design (iOS / Android / tablet)
- Building design systems or reusable widget libraries in Flutter

### Skip

- Pure backend/Dart logic without UI
- Only API or database design
- Infrastructure or DevOps work

**Decision criteria**: If the task will change how a feature **looks, feels, moves, or is interacted with**, this Skill should be used.

## Rule Categories by Priority

| Priority | Category | Impact | Key Checks |
|----------|----------|--------|------------|
| 1 | Accessibility | CRITICAL | Contrast 4.5:1, Semantic labels, Keyboard nav |
| 2 | Touch & Interaction | CRITICAL | Min size 44×44pt, Loading feedback, Haptics |
| 3 | Performance | HIGH | Lazy loading, Virtualized lists, Image optimization |
| 4 | Style Selection | HIGH | Match product type, Consistency, Vector icons |
| 5 | Layout & Responsive | HIGH | Mobile-first, Safe areas, Tablet breakpoints |
| 6 | Typography & Color | MEDIUM | Base 16sp, Line-height 1.5, Semantic tokens |
| 7 | Animation | MEDIUM | 150–300ms, Meaningful motion, Reduced-motion support |
| 8 | Forms & Feedback | MEDIUM | Visible labels, Error near field, Progressive disclosure |
| 9 | Navigation Patterns | HIGH | Predictable back, Bottom nav ≤5, Deep linking |
| 10 | Charts & Data | LOW | Legends, Tooltips, Accessible colors |

## Quick Reference — Flutter/Mobile Focus

### 1. Accessibility (CRITICAL)

- `color-contrast` — Minimum 4.5:1 ratio for normal text (large text 3:1)
- `focus-states` — Visible focus indicators for keyboard/switch access
- `semantic-labels` — Use `Semantics` widget; set `label`, `hint`, `button`, `header` properties
- `icon-labels` — Icon-only buttons must have `Tooltip` or `Semantics(label: ...)`
- `dynamic-type` — Support system text scaling; use `textScaleFactor` and avoid fixed sizes
- `reduced-motion` — Check `MediaQuery.of(context).disableAnimations`; reduce/disable animations

```dart
// Semantic label for icon button
Semantics(
  label: 'Add to favorites',
  button: true,
  child: IconButton(
    icon: const Icon(Icons.favorite_border),
    onPressed: onTap,
  ),
)

// Dynamic Type support
Text(
  title,
  style: Theme.of(context).textTheme.titleLarge,
  // Never use fixed fontSize without considering scale
)

// Respect reduced motion
final reduceMotion = MediaQuery.of(context).disableAnimations;
final duration = reduceMotion
  ? Duration.zero
  : const Duration(milliseconds: 300);
```

### 2. Touch & Interaction (CRITICAL)

- `touch-target-size` — Min 44×44pt (iOS) / 48×48dp (Android); use `hitTestBehavior` or padding
- `touch-spacing` — Minimum 8dp gap between touch targets
- `loading-buttons` — Disable during async; show `CircularProgressIndicator`
- `press-feedback` — Visual feedback via `InkWell`, `Ink`, or `Pressable` equivalent
- `haptic-feedback` — Use `HapticFeedback.lightImpact()` for confirmations
- `safe-area-awareness` — Wrap with `SafeArea`; account for notch, Dynamic Island, gesture bar

```dart
// Minimum touch target
SizedBox(
  width: 48,
  height: 48,
  child: IconButton(
    icon: const Icon(Icons.close, size: 24),
    onPressed: onClose,
    padding: EdgeInsets.zero,
  ),
)

// Loading button pattern
ElevatedButton(
  onPressed: isLoading ? null : onSubmit,
  child: isLoading
    ? const SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
    : const Text('Submit'),
)

// Safe area
Scaffold(
  body: SafeArea(
    child: YourContent(),
  ),
  bottomNavigationBar: SafeArea(
    child: BottomNavBar(),
  ),
)
```

### 3. Performance (HIGH)

- `virtualize-lists` — Use `ListView.builder` / `SliverList` for 20+ items
- `const-widgets` — Mark immutable widgets as `const`
- `image-caching` — Use `cached_network_image` or `Image.network` with caching
- `isolate-heavy-work` — Use `Isolate.run()` for parsing/computation off main thread
- `minimize-rebuilds` — Use `select` with Riverpod; `BlocSelector` with BLoC
- `repaint-boundary` — Wrap complex widgets in `RepaintBoundary`

```dart
// Virtualized list
ListView.builder(
  itemCount: products.length,
  itemBuilder: (context, index) => ProductCard(product: products[index]),
)

// Minimized rebuilds with Riverpod
final name = ref.watch(userProvider.select((u) => u.name));

// Background computation
final parsed = await Isolate.run(() => parseHeavyJson(raw));
```

### 4. Style Selection (HIGH)

Match your Flutter app style to product type:

| Product Type | Recommended Style | Colors | Typography |
|---|---|---|---|
| Fintech / Banking | Clean Minimalism | Navy, White, Gold accents | Inter + Roboto Mono |
| Health / Wellness | Soft Organic | Sage green, Cream, Coral | Nunito + Lora |
| Social / Entertainment | Vibrant Bold | Deep purple, Electric blue | Poppins + Inter |
| Productivity / SaaS | Professional Flat | Slate, Blue, Orange accents | Inter + Roboto |
| E-commerce | Modern Clean | White, Brand primary, Gray | Montserrat + Open Sans |
| Food & Lifestyle | Warm Inviting | Terracotta, Cream, Forest | Playfair + Source Sans |

**Style principles for Flutter:**
- Use Material 3 (`useMaterial3: true`) as the baseline
- Customize via `ThemeData` color seeds: `ColorScheme.fromSeed(seedColor: ...)`
- Use `TextTheme` roles: `displayLarge`, `titleMedium`, `bodyMedium`, `labelSmall`
- Avoid emoji as icons; use `Icons.*`, Lucide, or custom SVG

### 5. Layout & Responsive (HIGH)

```dart
// Flutter breakpoints (Material 3 WindowSizeClass)
// Compact: 0–599dp (phone portrait)
// Medium: 600–839dp (phone landscape, small tablet)
// Expanded: 840dp+ (tablet, desktop)

class AdaptiveLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return width >= 840
      ? Row(children: [SideNav(), Expanded(child: Content())])
      : Column(children: [Content(), BottomNav()]);
  }
}

// Adaptive padding
double get horizontalPadding {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 840) return 48;
  if (w >= 600) return 32;
  return 16;
}

// Adaptive grid (cards)
SliverGrid(
  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 300, // automatic columns
    childAspectRatio: 0.75,
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
  ),
  delegate: SliverChildBuilderDelegate(
    (context, i) => ProductCard(product: products[i]),
    childCount: products.length,
  ),
)
```

### 6. Typography & Color (MEDIUM)

```dart
// Material 3 Theme with custom colors
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1A73E8),
    brightness: Brightness.light,
  ),
  textTheme: GoogleFonts.interTextTheme(),
)

// Semantic text styles — never hardcode sizes
Text('Title', style: Theme.of(context).textTheme.titleLarge)
Text('Body', style: Theme.of(context).textTheme.bodyMedium)
Text('Label', style: Theme.of(context).textTheme.labelSmall)

// Dark mode
ThemeData.dark().copyWith(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1A73E8),
    brightness: Brightness.dark,
  ),
)
```

### 7. Animation (MEDIUM)

```dart
// Duration guidelines for Flutter
const micro = Duration(milliseconds: 150);    // Hover, press feedback
const standard = Duration(milliseconds: 300); // Most transitions
const complex = Duration(milliseconds: 400);  // Page transitions, modals

// Prefer implicit animations
AnimatedContainer(
  duration: standard,
  curve: Curves.easeOutCubic,
  decoration: BoxDecoration(
    color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
    borderRadius: BorderRadius.circular(12),
  ),
)

// Hero for shared element transitions
Hero(
  tag: 'product-image-${product.id}',
  child: ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.network(product.imageUrl, fit: BoxFit.cover),
  ),
)

// Page transition (slide from right)
Navigator.push(context, PageRouteBuilder(
  pageBuilder: (_, __, ___) => DetailScreen(),
  transitionsBuilder: (_, animation, __, child) => SlideTransition(
    position: Tween(begin: const Offset(1, 0), end: Offset.zero)
      .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
    child: child,
  ),
))
```

### 8. Forms & Feedback (MEDIUM)

```dart
// Form with validation
Form(
  key: _formKey,
  child: Column(
    children: [
      TextFormField(
        decoration: const InputDecoration(
          labelText: 'Email',           // Visible label (not just placeholder)
          helperText: 'Enter your email address',
        ),
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        validator: (v) => v!.contains('@') ? null : 'Enter a valid email',
        autovalidateMode: AutovalidateMode.onUserInteraction, // validate on blur
      ),
      const SizedBox(height: 16),
      TextFormField(
        decoration: InputDecoration(
          labelText: 'Password',
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        obscureText: _obscure,
        validator: (v) => v!.length >= 8 ? null : 'Minimum 8 characters',
      ),
    ],
  ),
)
```

### 9. Navigation Patterns (HIGH)

```dart
// Bottom navigation (max 5 items)
NavigationBar(
  selectedIndex: _currentIndex,
  onDestinationSelected: (i) => setState(() => _currentIndex = i),
  destinations: const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.search_outlined),
      selectedIcon: Icon(Icons.search),
      label: 'Search',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ],
)

// Adaptive navigation for tablet
class AdaptiveNavigation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 840) {
      return Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            labelType: NavigationRailLabelType.all,
            destinations: [...],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _pages[_currentIndex]),
        ],
      );
    }
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(...),
    );
  }
}
```

## Design System Generator

When asked to design a Flutter app, always start by generating a design system:

### Step 1: Identify the Product

Extract from user request:
- **Product type**: Fintech, Health, Social, Productivity, E-commerce, Food, Education
- **Target platform**: iOS, Android, or both
- **Style keywords**: minimal, vibrant, professional, playful, premium, modern

### Step 2: Generate Design System

```dart
// Complete ThemeData for Flutter
ThemeData buildTheme({bool isDark = false}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: primaryColor,
    brightness: isDark ? Brightness.dark : Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: GoogleFonts.interTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerHighest,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(88, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
```

### Step 3: Common Checks Before Delivery

**Pre-Delivery Checklist for Flutter:**

#### Visual Quality
- [ ] No emojis used as icons (use `Icons.*` or custom SVG)
- [ ] All icons come from a consistent icon family
- [ ] `useMaterial3: true` enabled
- [ ] Semantic color tokens used (no hardcoded hex in widgets)
- [ ] Cards/surfaces have proper elevation and contrast

#### Interaction
- [ ] All tappable elements ≥ 44×44pt with `InkWell` or `GestureDetector`
- [ ] Loading states on async operations
- [ ] Haptic feedback on important actions
- [ ] Disabled states visually clear and non-interactive

#### Responsive
- [ ] `SafeArea` wrapping all screens
- [ ] Tested at 375dp (small phone), 414dp (large phone), 768dp (tablet)
- [ ] Adaptive navigation (BottomNav for phone, NavigationRail for tablet)
- [ ] Grid adapts column count using `SliverGridDelegateWithMaxCrossAxisExtent`

#### Accessibility
- [ ] All icons have semantic labels
- [ ] Text supports dynamic type scaling
- [ ] Colors meet 4.5:1 contrast ratio
- [ ] Reduced motion respected

#### Dark Mode
- [ ] `ColorScheme.fromSeed` with both `Brightness.light` and `Brightness.dark`
- [ ] Tested independently in both modes
- [ ] No hardcoded colors that break in dark mode

## Common UI Patterns for Flutter Apps

### Empty State
```dart
Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.inbox_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
      const SizedBox(height: 16),
      Text('No items yet', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text('Add your first item to get started', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: onAddItem,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    ],
  ),
)
```

### Pull to Refresh
```dart
RefreshIndicator(
  onRefresh: () async => await ref.refresh(dataProvider.future),
  child: ListView.builder(...),
)
```

### Skeleton Loading
```dart
// Using shimmer package
Shimmer.fromColors(
  baseColor: Colors.grey[300]!,
  highlightColor: Colors.grey[100]!,
  child: ListTile(
    leading: CircleAvatar(backgroundColor: Colors.white, radius: 24),
    title: Container(height: 16, color: Colors.white),
    subtitle: Container(height: 12, color: Colors.white, width: 100),
  ),
)
```

### Bottom Sheet
```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.5,
    minChildSize: 0.25,
    maxChildSize: 0.9,
    builder: (_, controller) => YourContent(scrollController: controller),
  ),
)
```

---

**Pro tip**: Always start with `ThemeData(useMaterial3: true)` and `ColorScheme.fromSeed`. Design mobile-first, then adapt for tablet using `MediaQuery.sizeOf(context).width >= 600` or `>= 840`. Every interactive element needs a minimum 44pt touch target and visible press feedback.
