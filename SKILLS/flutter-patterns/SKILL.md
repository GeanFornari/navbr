---
name: flutter-patterns
description: Comprehensive Flutter development patterns covering widgets, testing, performance, security, and animations. Use when you need quick reference for Flutter best practices, common UI patterns, performance optimization techniques, security guidelines, or animation implementations.
---

# Flutter Patterns

A comprehensive collection of battle-tested Flutter patterns and best practices for building production-quality applications.

## Overview

This skill provides quick-reference patterns for:

- **Widget Patterns**: Common UI components (cards, lists, forms, dialogs, navigation)
- **Testing Patterns**: Unit, widget, and integration testing approaches
- **Performance Patterns**: Optimization techniques and performance checklists
- **Security Patterns**: Security best practices and vulnerability prevention
- **Animation Patterns**: Common animation implementations and transitions

## When to Use This Skill

Use this skill when you need:

- Quick reference for standard Flutter UI patterns
- Testing strategy guidance and examples
- Performance optimization checklists
- Security vulnerability prevention
- Animation implementation examples
- Best practices for common Flutter development scenarios

## Pattern Categories

### Widget Patterns

Includes patterns for:

- Card patterns (basic, image, custom)
- List patterns (lazy loading, sectioned)
- Form patterns with validation
- Dialog and bottom sheet patterns
- Loading and empty states
- Navigation patterns
- Material 3 widgets (SearchAnchor, SegmentedButton, NavigationBar, DropdownMenu)
- DecoratedSliver patterns
- Responsive layouts (with Material 3 WindowSizeClass breakpoints)

**Mobile & Tablet Layout:**
```dart
// Responsive layout using LayoutBuilder
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth >= 600) {
      return _TabletLayout();
    } else {
      return _PhoneLayout();
    }
  },
)

// Material 3 WindowSizeClass approach
final windowSize = MediaQuery.sizeOf(context);
final isTablet = windowSize.width >= 600;
```

**Common Widget Patterns:**
```dart
// Card with image
Card(
  clipBehavior: Clip.antiAlias,
  child: Column(
    children: [
      Image.network(imageUrl, fit: BoxFit.cover),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    ],
  ),
)

// Lazy loading list
ListView.builder(
  itemCount: items.length + (isLoading ? 1 : 0),
  itemBuilder: (context, index) {
    if (index == items.length) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListTile(title: Text(items[index].title));
  },
)

// Material 3 NavigationBar
NavigationBar(
  selectedIndex: _selectedIndex,
  onDestinationSelected: (index) => setState(() => _selectedIndex = index),
  destinations: const [
    NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
    NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
  ],
)
```

### Testing Patterns

Includes patterns for:

- Unit test structure and best practices
- Widget testing approaches
- Integration test patterns
- Mock and stub strategies (Mockito and Mocktail)
- BLoC testing with bloc_test
- Riverpod testing patterns
- Patrol testing for native interactions
- Golden test patterns
- Test organization and naming conventions
- Coverage best practices

**Unit Test Pattern:**
```dart
group('MyService', () {
  late MyService service;
  late MockRepository mockRepository;

  setUp(() {
    mockRepository = MockRepository();
    service = MyService(repository: mockRepository);
  });

  test('should return data when repository succeeds', () async {
    // Arrange
    when(() => mockRepository.getData()).thenAnswer((_) async => mockData);

    // Act
    final result = await service.getData();

    // Assert
    expect(result, equals(mockData));
    verify(() => mockRepository.getData()).called(1);
  });
});
```

**Widget Test Pattern:**
```dart
testWidgets('MyWidget shows correct content', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MyWidget(title: 'Test Title'),
    ),
  );

  expect(find.text('Test Title'), findsOneWidget);
  await tester.tap(find.byType(ElevatedButton));
  await tester.pump();
  expect(find.text('Button tapped'), findsOneWidget);
});
```

**Riverpod Testing:**
```dart
testWidgets('Counter increments', (tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );

  expect(container.read(counterProvider), 0);
  await tester.tap(find.byIcon(Icons.add));
  await tester.pump();
  expect(container.read(counterProvider), 1);
});
```

### Performance Patterns

Includes patterns for:

- Impeller rendering engine considerations
- Build method optimization
- Widget rebuilding minimization
- List and grid performance
- Image loading optimization (WebP/AVIF, caching)
- Memory leak prevention
- Isolate.run() for background computation
- Rendering performance tips

**Performance Checklist:**
```dart
// ✅ Use const constructors
const Text('Hello World')
const SizedBox(height: 16)

// ✅ Use RepaintBoundary for complex widgets
RepaintBoundary(child: ExpensiveWidget())

// ✅ Virtualize long lists
ListView.builder(  // Not ListView with many children
  itemCount: 10000,
  itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
)

// ✅ Cache images
CachedNetworkImage(
  imageUrl: url,
  placeholder: (context, url) => const CircularProgressIndicator(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
)

// ✅ Use Isolate for heavy computation
final result = await Isolate.run(() => heavyComputation(data));

// ✅ Minimize rebuilds with select
final userName = ref.watch(userProvider.select((u) => u.name));
```

**Memory Leak Prevention:**
```dart
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = stream.listen((_) {});
  }

  @override
  void dispose() {
    _subscription.cancel(); // Always cancel subscriptions
    super.dispose();
  }
}
```

### Security Patterns

Includes patterns for:

- Input validation and sanitization
- Secure storage practices (flutter_secure_storage)
- API security and certificate pinning (Dio 5.x)
- Authentication and authorization patterns
- Biometric authentication (Face ID, fingerprint)
- iOS Privacy Manifests (required since iOS 17)
- Data encryption approaches
- Common vulnerability prevention

**Secure Storage:**
```dart
// Using flutter_secure_storage
const storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

// Store token
await storage.write(key: 'auth_token', value: token);

// Read token
final token = await storage.read(key: 'auth_token');

// Delete on logout
await storage.delete(key: 'auth_token');
```

**Certificate Pinning with Dio 5.x:**
```dart
final dio = Dio();
(dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
  final client = HttpClient();
  client.badCertificateCallback = (cert, host, port) {
    final sha256 = sha256.convert(cert.der).toString();
    return pinnedCertHashes.contains(sha256);
  };
  return client;
};
```

**Biometric Auth:**
```dart
final auth = LocalAuthentication();
final canAuth = await auth.canCheckBiometrics;

if (canAuth) {
  final authenticated = await auth.authenticate(
    localizedReason: 'Authenticate to access your account',
    options: const AuthenticationOptions(biometricOnly: true),
  );
}
```

### Animation Patterns

Includes patterns for:

- Basic animation controllers
- Tween animations
- Hero animations
- Page transitions
- Implicit animations
- Material 3 motion patterns (shared axis, container transform)
- Impeller animation performance notes
- Custom animation patterns

**Basic Animation:**
```dart
class _AnimatedWidgetState extends State<AnimatedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

**Implicit Animations (preferred):**
```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  width: isExpanded ? 200 : 100,
  height: isExpanded ? 200 : 100,
  color: isExpanded ? Colors.blue : Colors.grey,
)

AnimatedOpacity(
  duration: const Duration(milliseconds: 200),
  opacity: isVisible ? 1.0 : 0.0,
  child: MyWidget(),
)
```

**Hero Animation:**
```dart
// Source screen
Hero(
  tag: 'product-${product.id}',
  child: Image.network(product.imageUrl),
)

// Destination screen
Hero(
  tag: 'product-${product.id}',
  child: Image.network(product.imageUrl, fit: BoxFit.cover),
)
```

**Page Transition:**
```dart
Navigator.push(
  context,
  PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => DetailsPage(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      );
    },
  ),
);
```

## Mobile & Tablet Responsive Design

```dart
// Using MediaQuery
class ResponsiveLayout extends StatelessWidget {
  final Widget phone;
  final Widget tablet;

  const ResponsiveLayout({required this.phone, required this.tablet});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 600 ? tablet : phone;
  }
}

// Adaptive padding
EdgeInsets get adaptivePadding {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1200) return const EdgeInsets.symmetric(horizontal: 64);
  if (width >= 600) return const EdgeInsets.symmetric(horizontal: 32);
  return const EdgeInsets.symmetric(horizontal: 16);
}

// Adaptive grid
SliverGrid(
  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 200,
    childAspectRatio: 1,
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
  ),
  delegate: SliverChildBuilderDelegate(
    (context, index) => ProductCard(product: products[index]),
    childCount: products.length,
  ),
)
```

## Usage Examples

**Example 1: Need a card UI pattern**
```
User: "I need to create a product card with an image and details"
→ Use the Card with image pattern from Widget Patterns
```

**Example 2: Writing tests**
```
User: "How should I structure my widget tests?"
→ Use the Widget Test Pattern from Testing Patterns
```

**Example 3: Performance issues**
```
User: "My list is laggy when scrolling"
→ Use ListView.builder + virtualization from Performance Patterns
```

**Example 4: Security concern**
```
User: "How do I securely store user credentials?"
→ Use flutter_secure_storage pattern from Security Patterns
```

**Example 5: Adding animations**
```
User: "I want to animate a page transition"
→ Use PageRouteBuilder pattern from Animation Patterns
```

## Pattern Quality

All patterns in this skill are:

- ✓ Production-tested and battle-proven
- ✓ Following Flutter best practices and official documentation
- ✓ Performance-optimized (Impeller-compatible)
- ✓ Security-conscious
- ✓ Responsive for mobile AND tablet
- ✓ Well-documented with runnable code examples

---

**Pro tip**: Combine patterns from different categories. For example, use Widget Patterns + Performance Patterns + Security Patterns together when building production features. Always consider tablet layouts alongside mobile layouts from the start.
