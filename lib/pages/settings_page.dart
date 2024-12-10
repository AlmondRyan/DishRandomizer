import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:dish_randomizer/utils/settings_manager.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:xml/xml.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dish_randomizer/models/dish.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic> settings;
  final Function(Map<String, dynamic>) onSettingsChanged;

  const SettingsPage({
    Key? key,
    required this.settings,
    required this.onSettingsChanged,
  }) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  int _animationDuration = 5;
  bool _autoSave = true;
  String _defaultLanguage = 'English';
  
  // 代理设置
  bool _enableProxy = false;
  bool _autoDetectProxy = false;
  String _selectedProxyType = 'HTTP';
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _bypassListController = TextEditingController();
  bool _requireAuth = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;

  // 导入项目
  List<String> _importedItems = [];
  String _lastImportedFile = '';
  String _lastImportType = '';

  @override
  void initState() {
    super.initState();
    _loadSettingsFromProps();
  }

  void _loadSettingsFromProps() {
    final settings = widget.settings;
    setState(() {
      _darkMode = settings['darkMode'] ?? false;
      _animationDuration = settings['animationDuration'] ?? 5;
      _autoSave = settings['autoSave'] ?? true;
      _defaultLanguage = settings['defaultLanguage'] ?? 'English';

      final proxy = settings['proxy'] ?? {};
      _enableProxy = proxy['enabled'] ?? false;
      _autoDetectProxy = proxy['autoDetect'] ?? false;
      _selectedProxyType = proxy['type'] ?? 'HTTP';
      _hostController.text = proxy['host'] ?? '';
      _portController.text = proxy['port'] ?? '';
      _bypassListController.text = proxy['bypassList'] ?? '';
      _requireAuth = proxy['requireAuth'] ?? false;
      _usernameController.text = proxy['username'] ?? '';
      _passwordController.text = proxy['password'] ?? '';

      final importedItems = settings['importedItems'] ?? {};
      _importedItems = List<String>.from(importedItems['items'] ?? []);
      _lastImportedFile = importedItems['lastFile'] ?? '';
      _lastImportType = importedItems['lastType'] ?? '';
    });
  }

  void _saveAndNotify() async {
    final settings = {
      'darkMode': _darkMode,
      'animationDuration': _animationDuration,
      'autoSave': _autoSave,
      'defaultLanguage': _defaultLanguage,
      'proxy': {
        'enabled': _enableProxy,
        'autoDetect': _autoDetectProxy,
        'type': _selectedProxyType,
        'host': _hostController.text,
        'port': _portController.text,
        'bypassList': _bypassListController.text,
        'requireAuth': _requireAuth,
        'username': _usernameController.text,
        'password': _passwordController.text,
      },
      'importedItems': {
        'items': _importedItems,
        'lastFile': _lastImportedFile,
        'lastType': _lastImportType,
      },
    };

    // 保存设置到文件
    final success = await SettingsManager.saveSettings(settings);
    if (success) {
      widget.onSettingsChanged(settings);
      _showSnackBar('Settings saved successfully!');
    } else {
      _showSnackBar('Failed to save settings', isError: true);
    }
  }

  // 添加文件导入方法
  Future<void> _importFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv', 'xml', 'json'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final extension = result.files.single.extension?.toLowerCase() ?? '';
        List<String> items = [];

        switch (extension) {
          case 'xml':
            // 如果是 XML 文件，先复制到 AppData
            await SettingsManager.copyRecipesXml(file.path);
            items = await _parseXml(file);
            break;
          case 'xlsx':
            items = await _parseExcel(file);
            break;
          case 'csv':
            items = await _parseCsv(file);
            break;
          case 'json':
            items = await _parseJson(file);
            break;
          default:
            throw Exception('Unsupported file type');
        }

        setState(() {
          _importedItems = items;
          _lastImportedFile = file.path;
          _lastImportType = extension;
        });

        // 保存到 data.json
        final success = await SettingsManager.saveData(items);
        if (success) {
          _showSnackBar('Successfully imported ${items.length} items');
        } else {
          _showSnackBar('Failed to save imported items', isError: true);
        }
      }
    } catch (e) {
      _showSnackBar('Failed to import file: $e', isError: true);
    }
  }

  // Excel 解析
  Future<List<String>> _parseExcel(File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    List<String> items = [];

    for (var table in excel.tables.keys) {
      for (var row in excel.tables[table]!.rows) {
        if (row.isNotEmpty && row[0]?.value != null) {
          items.add(row[0]!.value.toString().trim());
        }
      }
    }
    return items.where((item) => item.isNotEmpty).toList();
  }

  // CSV 解析
  Future<List<String>> _parseCsv(File file) async {
    final contents = await file.readAsString();
    final rows = const CsvToListConverter().convert(contents);
    return rows
        .where((row) => row.isNotEmpty && row[0] != null)
        .map((row) => row[0].toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  // XML 解析
  Future<List<String>> _parseXml(File file) async {
    final contents = await file.readAsString();
    final document = XmlDocument.parse(contents);
    return document.findAllElements('instance')
        .map((node) => node.findElements('name').first.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }

  // 添加详细的菜谱解析方法
  Dish _parseDishFromXml(XmlElement instance) {
    final name = instance.findElements('name').first.text;
    final note = instance.findElements('note').first.text;

    // 解析配料
    final ingredients = instance.findElements('ingredients').first
        .findElements('ingredient')
        .map((ing) => Ingredient(
              name: ing.text.trim(),
              count: ing.getAttribute('count') ?? '适量',
              unit: ing.getAttribute('unit') ?? '',
              optional: ing.getAttribute('optional') == 'true',
            ))
        .toList();

    // 解析调味料
    final spices = instance.findElements('spices').first
        .findElements('spice')
        .map((spice) => Spice(
              name: spice.text.trim(),
              count: spice.getAttribute('count'),
              unit: spice.getAttribute('unit'),
              note: spice.getAttribute('note'),
              optional: spice.getAttribute('optional') == 'true',
            ))
        .toList();

    // 解析步骤
    final steps = instance.findElements('steps').first
        .findElements('zone')
        .map((zone) => Zone(
              id: zone.getAttribute('id') ?? '',
              text: zone.getAttribute('text') ?? '',
              steps: zone.findElements('step')
                  .map((step) => RecipeStep(
                        id: step.getAttribute('id') ?? '',
                        text: step.getAttribute('text') ?? '',
                      ))
                  .toList(),
            ))
        .toList();

    return Dish(
      name: name,
      note: note,
      ingredients: ingredients,
      spices: spices,
      steps: steps,
    );
  }

  // JSON 解析
  Future<List<String>> _parseJson(File file) async {
    final contents = await file.readAsString();
    final data = json.decode(contents);
    if (data is List) {
      return data.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
    } else if (data is Map && data.containsKey('items')) {
      return List<String>.from(data['items'])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    throw Exception('Invalid JSON format');
  }

  // 显示提示信息
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveAndNotify,
          ),
        ],
      ),
      body: ListView(
        children: [
          // 基本设置
          ListTile(
            title: const Text('Dark Mode'),
            trailing: Switch(
              value: _darkMode,
              onChanged: (value) {
                setState(() => _darkMode = value);
              },
            ),
          ),

          ListTile(
            title: const Text('Animation Duration'),
            subtitle: Slider(
              value: _animationDuration.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_animationDuration seconds',
              onChanged: (value) {
                setState(() => _animationDuration = value.round());
              },
            ),
          ),

          ListTile(
            title: const Text('Auto Save'),
            trailing: Switch(
              value: _autoSave,
              onChanged: (value) {
                setState(() => _autoSave = value);
              },
            ),
          ),

          // 代理设置
          ExpansionTile(
            title: const Text('Proxy Settings'),
            children: [
              SwitchListTile(
                title: const Text('Enable Proxy'),
                value: _enableProxy,
                onChanged: (value) {
                  setState(() => _enableProxy = value);
                },
              ),
              if (_enableProxy) ...[
                SwitchListTile(
                  title: const Text('Auto Detect'),
                  value: _autoDetectProxy,
                  onChanged: (value) {
                    setState(() => _autoDetectProxy = value);
                  },
                ),
                if (!_autoDetectProxy) ...[
                  ListTile(
                    title: const Text('Proxy Type'),
                    trailing: DropdownButton<String>(
                      value: _selectedProxyType,
                      items: const [
                        DropdownMenuItem(value: 'HTTP', child: Text('HTTP')),
                        DropdownMenuItem(value: 'SOCKS', child: Text('SOCKS')),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedProxyType = value!);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: 'Host',
                        hintText: 'Enter proxy host',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: 'Enter proxy port',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      controller: _bypassListController,
                      decoration: const InputDecoration(
                        labelText: 'Bypass List',
                        hintText: 'Enter addresses to bypass proxy (comma-separated)',
                      ),
                      maxLines: 3,
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Require Authentication'),
                    value: _requireAuth,
                    onChanged: (value) {
                      setState(() => _requireAuth = value);
                    },
                  ),
                  if (_requireAuth) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'Enter proxy username',
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter proxy password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() => _showPassword = !_showPassword);
                            },
                          ),
                        ),
                        obscureText: !_showPassword,
                      ),
                    ),
                  ],
                ],
              ],
            ],
          ),

          // 数据导入设置
          ExpansionTile(
            title: const Text('Data Import'),
            subtitle: _lastImportedFile.isNotEmpty
                ? Text('Last import: ${_lastImportedFile.split('/').last}')
                : null,
            children: [
              ListTile(
                title: const Text('Import from File'),
                subtitle: const Text('Support XLSX/CSV/XML/JSON'),
                trailing: IconButton(
                  icon: const Icon(Icons.file_upload),
                  onPressed: _importFile,
                ),
              ),
              if (_importedItems.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Imported Items:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _importedItems.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      dense: true,
                      title: Text(_importedItems[index]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          setState(() {
                            _importedItems.removeAt(index);
                            _saveAndNotify(); // 删除后保存更改
                          });
                        },
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _importedItems.clear();
                            _lastImportedFile = '';
                            _lastImportType = '';
                            _saveAndNotify();
                          });
                          _showSnackBar('All items cleared');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _bypassListController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}