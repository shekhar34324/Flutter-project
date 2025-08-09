import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const MyApp());
}

class Task {
  final String id;
  String text;
  final int createdAt;
  int? doneAt;

  Task({required this.id, required this.text, required this.createdAt, this.doneAt});

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt,
        'doneAt': doneAt,
      };

  static Task fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        text: j['text'] as String,
        createdAt: j['createdAt'] as int,
        doneAt: j['doneAt'] as int?,
      );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bestest To-Do (Mobile)',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const ToDoHome(),
    );
  }
}

class ToDoHome extends StatefulWidget {
  const ToDoHome({super.key});

  @override
  State<ToDoHome> createState() => _ToDoHomeState();
}

class _ToDoHomeState extends State<ToDoHome> {
  final List<Task> _todos = [];
  final List<Task> _done = [];
  final TextEditingController _controller = TextEditingController();
  late SharedPreferences _prefs;

  static const _storageKey = 'flutter_todo_mobile_v1';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final todos = (data['todos'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        final done = (data['done'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
        setState(() {
          _todos.clear();
          _done.clear();
          _todos.addAll(todos.map((e) => Task.fromJson(Map.from(e))));
          _done.addAll(done.map((e) => Task.fromJson(Map.from(e))));
        });
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final data = {
      'todos': _todos.map((t) => t.toJson()).toList(),
      'done': _done.map((t) => t.toJson()).toList(),
    };
    await _prefs.setString(_storageKey, jsonEncode(data));
  }

  void _addTask(String text) {
    if (text.trim().isEmpty) return;
    final t = Task(id: const Uuid().v4(), text: text.trim(), createdAt: DateTime.now().millisecondsSinceEpoch);
    setState(() {
      _todos.insert(0, t);
    });
    _save();
  }

  void _removeTask(String id) {
    setState(() {
      _todos.removeWhere((t) => t.id == id);
      _done.removeWhere((t) => t.id == id);
    });
    _save();
  }

  void _markDone(String id) {
    final idx = _todos.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final item = _todos.removeAt(idx);
    item.doneAt = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _done.insert(0, item);
    });
    _save();
  }

  void _markUndone(String id) {
    final idx = _done.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final item = _done.removeAt(idx);
    item.doneAt = null;
    setState(() {
      _todos.insert(0, item);
    });
    _save();
  }

  Future<void> _editTask(BuildContext ctx, Task task) async {
    final tc = TextEditingController(text: task.text);
    final res = await showDialog<String?>(
      context: ctx,
      builder: (ctx2) => AlertDialog(
        title: const Text('Edit task'),
        content: TextField(
          controller: tc,
          decoration: const InputDecoration(hintText: 'Task text'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx2).pop(null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx2).pop(tc.text), child: const Text('Save')),
        ],
      ),
    );
    if (res == null) return;
    setState(() {
      task.text = res.trim();
    });
    _save();
  }

  Widget _buildTaskTile(Task t, {required bool isDone}) {
    return LongPressDraggable<Map<String, String>>(
      data: {'id': t.id, 'origin': isDone ? 'done' : 'todos'},
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Opacity(
            opacity: 0.95,
            child: _taskCard(t, isDone: isDone),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: _taskCard(t, isDone: isDone)),
      child: _taskCard(t, isDone: isDone),
    );
  }

  Widget _taskCard(Task t, {required bool isDone}) {
    return Card(
      elevation: 2,
      color: Colors.white.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: IconButton(
          icon: Icon(isDone ? Icons.undo : Icons.check, color: Colors.white),
          onPressed: () => isDone ? _markUndone(t.id) : _markDone(t.id),
        ),
        title: Text(
          t.text,
          style: TextStyle(
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          isDone
              ? 'Done ${_ago(t.doneAt!)}'
              : 'Added ${_ago(t.createdAt)}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.edit, color: Colors.white70), onPressed: () => _editTask(context, t)),
          IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _removeTask(t.id)),
        ]),
      ),
    );
  }

  String _ago(int ms) {
    final s = (DateTime.now().millisecondsSinceEpoch - ms) ~/ 1000;
    if (s < 60) return '${s}s ago';
    final m = s ~/ 60;
    if (m < 60) return '${m}m ago';
    final h = m ~/ 60;
    if (h < 24) return '${h}h ago';
    final d = h ~/ 24;
    return '${d}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0), Color(0xFFFFA726)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 28),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Bestest To-Do', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.info_outline, color: Colors.white70),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.12),
                      hintText: 'Add a new task...',
                      hintStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (v) {
                      _addTask(v);
                      _controller.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                    onPressed: () {
                      _addTask(_controller.text);
                      _controller.clear();
                    },
                    child: const Text('Add')),
              ]),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildDropArea(title: 'To Do', items: _todos, isDone: false)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDropArea(title: 'Done', items: _done, isDone: true)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropArea({required String title, required List<Task> items, required bool isDone}) {
    return DragTarget<Map<String, String>>(
      onWillAccept: (data) => data != null,
      onAcceptWithDetails: (details) {
        final data = details.data;
        final id = data['id']!;
        final origin = data['origin']!;
        if (origin == 'todos' && isDone) {
          _markDone(id);
        } else if (origin == 'done' && !isDone) {
          _markUndone(id);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                Text('${items.length} items', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text(isDone ? 'No finished tasks yet.' : 'Drop tasks here or add one above.', style: const TextStyle(color: Colors.white70)))
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: items.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final element = items.removeAt(oldIndex);
                            items.insert(newIndex, element);
                          });
                          _save();
                        },
                        itemBuilder: (context, index) {
                          final t = items[index];
                          return Padding(
                            key: ValueKey(t.id),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: _buildTaskTile(t, isDone: isDone),
                          );
                        },
                      ),
              )
            ],
          ),
        );
      },
    );
  }
}