import 'package:flutter/material.dart';

class ManageClassesDialog extends StatefulWidget {
  final List<String> availableClasses;
  final List<String> initialSelection;
  final Function(List<String>) onSave;

  const ManageClassesDialog({
    super.key,
    required this.availableClasses,
    required this.initialSelection,
    required this.onSave,
  });

  @override
  State<ManageClassesDialog> createState() => _ManageClassesDialogState();
}

class _ManageClassesDialogState extends State<ManageClassesDialog> {
  late List<String> _selectedClasses;
  late Set<String> _displayClasses; // Combined set to show
  final _customClassController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedClasses = List.from(widget.initialSelection);
    // Combine global available with any custom ones already selected
    _displayClasses = {...widget.availableClasses, ...widget.initialSelection}; 
  }
  
  void _addCustomClass() {
      final val = _customClassController.text.trim();
      if (val.isNotEmpty) {
          setState(() {
              _displayClasses.add(val);
              if (!_selectedClasses.contains(val)) {
                  _selectedClasses.add(val);
              }
              _customClassController.clear();
          });
      }
  }

  void _deleteClass(String cls) {
    setState(() {
      _displayClasses.remove(cls);
      _selectedClasses.remove(cls);
    });
  }

  void _editClass(String oldName) {
    final controller = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename Tag'),
        content: TextField(
            controller: controller, 
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter new name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
             final newName = controller.text.trim();
             if (newName.isNotEmpty && newName != oldName) {
                if (_displayClasses.contains(newName)) {
                    // Prevent duplicates
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tag already exists!')));
                    return;
                }
                setState(() {
                   _displayClasses.remove(oldName);
                   _displayClasses.add(newName);
                   if (_selectedClasses.contains(oldName)) {
                      _selectedClasses.remove(oldName);
                      _selectedClasses.add(newName);
                   }
                });
             }
             Navigator.pop(c);
          }, 
          child: const Text('Rename')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Convert to list for display, maybe sorted
    final sortedClasses = _displayClasses.toList()..sort();

    return AlertDialog(
      title: const Text('Manage Enabled Classes'),
      content: SizedBox(
        width: 350, // Slightly wider
        height: 500, // Taller
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: Text(
                'Define which classes/tags are active for your institution. You can select standard classes or add custom tags.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
            
            // Add Custom Class Input
            Row(
                children: [
                    Expanded(
                        child: TextField(
                            controller: _customClassController,
                            decoration: InputDecoration(
                                hintText: 'New Class Tag (e.g. "Biology 101")',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onSubmitted: (_) => _addCustomClass(),
                        ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                        onPressed: _addCustomClass, 
                        icon: const Icon(Icons.add),
                        tooltip: 'Add Tag',
                    ),
                ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sortedClasses.length,
                itemBuilder: (context, index) {
                   final cls = sortedClasses[index];
                   final isSelected = _selectedClasses.contains(cls);
                   final isCustom = !widget.availableClasses.contains(cls);

                   return ListTile(
                     leading: Checkbox(
                       value: isSelected,
                       activeColor: Theme.of(context).primaryColor,
                       onChanged: (val) {
                         setState(() {
                           if (val == true) {
                             _selectedClasses.add(cls);
                           } else {
                             _selectedClasses.remove(cls);
                           }
                         });
                       },
                     ),
                     title: Text(cls),
                     trailing: isCustom 
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey),
                                tooltip: 'Rename Tag',
                                onPressed: () => _editClass(cls),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                tooltip: 'Remove Tag',
                                onPressed: () => _deleteClass(cls),
                              ),
                            ],
                          )
                        : null,
                     onTap: () {
                         setState(() {
                           if (isSelected) {
                             _selectedClasses.remove(cls);
                           } else {
                             _selectedClasses.add(cls);
                           }
                         });
                     },
                   );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => widget.onSave(_selectedClasses),
          child: const Text('Save Changes'),
        ),
      ],
    );
  }
}
