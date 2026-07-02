import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'workspace_definition.dart';

class WorkspaceNavigationItem {
  const WorkspaceNavigationItem({
    required this.name,
    required this.entityType,
    required this.entityId,
  });

  final String name;
  final WorkspaceEntityType entityType;
  final String entityId;
}

class WorkspaceNavigationNotifier extends Notifier<List<WorkspaceNavigationItem>> {
  @override
  List<WorkspaceNavigationItem> build() => [];

  void push(WorkspaceNavigationItem item) {
    state = [...state, item];
  }

  void pop() {
    if (state.isNotEmpty) {
      state = state.sublist(0, state.length - 1);
    }
  }

  void reset(WorkspaceNavigationItem item) {
    state = [item];
  }
}

final workspaceNavigationProvider = NotifierProvider<WorkspaceNavigationNotifier, List<WorkspaceNavigationItem>>(
  WorkspaceNavigationNotifier.new,
);

class ContextDrawerState {
  const ContextDrawerState({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;
}

class ContextDrawerNotifier extends Notifier<List<ContextDrawerState>> {
  @override
  List<ContextDrawerState> build() => [];

  void push(String title, Widget child) {
    state = [...state, ContextDrawerState(title: title, child: child)];
  }

  void pop() {
    if (state.isNotEmpty) {
      state = state.sublist(0, state.length - 1);
    }
  }

  void clear() {
    state = [];
  }
}

final contextDrawerProvider = NotifierProvider<ContextDrawerNotifier, List<ContextDrawerState>>(
  ContextDrawerNotifier.new,
);
