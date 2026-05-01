// ignore_for_file: dangling_library_doc_comments
// Contém código gerado por IA

import 'package:flutter/material.dart';
import 'package:navbr/theme/app_colors.dart';
import 'package:navbr/screens/navigation_map_screen.dart';

/// MainScreen
/// Gerencia a navegação principal do aplicativo através de um BottomNavigationBar persistente.
class MainScreen extends StatefulWidget {
  final Widget Function(VoidCallback onNavigateToMap) chartsTabBuilder;

  const MainScreen({super.key, required this.chartsTabBuilder});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 2; // Começa na aba "Cartas"

  // Chaves para os navegadores de cada aba para manter o estado e persistência
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  void _navigateToMap() {
    setState(() {
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final NavigatorState? currentNavigator = _navigatorKeys[_currentIndex].currentState;
        if (currentNavigator != null && currentNavigator.canPop()) {
          currentNavigator.pop();
        } else if (_currentIndex != 2) {
          setState(() {
            _currentIndex = 2;
          });
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildTabNavigator(0, const PlaceholderScreen(title: 'Aeroportos', icon: Icons.local_airport)),
            _buildTabNavigator(1, const NavigationMapScreen()),
            _buildTabNavigator(2, widget.chartsTabBuilder(_navigateToMap)),
            _buildTabNavigator(3, const PlaceholderScreen(title: 'Voos', icon: Icons.flight_takeoff)),
            _buildTabNavigator(4, const PlaceholderScreen(title: 'Opções', icon: Icons.settings)),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (index == _currentIndex) {
                _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
              } else {
                setState(() {
                  _currentIndex = index;
                });
              }
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.black,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white.withAlpha(150),
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.local_airport_outlined),
                activeIcon: Icon(Icons.local_airport),
                label: 'Aeroportos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: 'Map/Nav',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.layers_outlined),
                activeIcon: Icon(Icons.layers),
                label: 'Cartas',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.flight_outlined),
                activeIcon: Icon(Icons.flight),
                label: 'Voos',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Opções',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabNavigator(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(builder: (context) => child);
      },
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderScreen({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.disabled),
            const SizedBox(height: 16),
            Text(
              'Tela de $title\n(Em desenvolvimento)',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
