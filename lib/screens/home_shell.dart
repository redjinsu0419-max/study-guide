import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'admin_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'wrong_notes_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.firebaseUser,
    required this.isAdmin,
    this.appUser,
  });

  final User firebaseUser;
  final AppUser? appUser;
  final bool isAdmin;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(defaultUser: widget.appUser),
      HistoryScreen(uid: widget.firebaseUser.uid),
      WrongNotesScreen(uid: widget.firebaseUser.uid),
      if (widget.isAdmin) const AdminScreen(),
    ];
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: '홈',
      ),
      const NavigationDestination(
        icon: Icon(Icons.history_rounded),
        label: '풀이 기록',
      ),
      const NavigationDestination(
        icon: Icon(Icons.bookmark_outline_rounded),
        selectedIcon: Icon(Icons.bookmark_rounded),
        label: '오답 노트',
      ),
      if (widget.isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings_rounded),
          label: '승인 관리',
        ),
    ];
    if (_index >= pages.length) _index = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAdmin ? '공부 가이드 관리자' : '공부 가이드'),
        actions: <Widget>[
          IconButton(
            tooltip: '로그아웃',
            onPressed: AuthService().signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: destinations,
      ),
    );
  }
}

