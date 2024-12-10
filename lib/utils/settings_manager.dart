import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';
import '../models/dish.dart';

class SettingsManager {
  static const String _appFolderName = 'DishRandomation';
  static const String _settingsFileName = 'settings.json';
  static const String _dataFileName = 'data.json';
  static const String _recipesFileName = 'recipes.xml';

  static Future<String> get _appDataPath async {
    if (Platform.isWindows) {
      final String appData = Platform.environment['APPDATA'] ?? '';
      final String settingsPath = path.join(appData, _appFolderName);
      await Directory(settingsPath).create(recursive: true);
      return settingsPath;
    } else {
      throw UnsupportedError('Currently only supports Windows');
    }
  }

  static Future<bool> saveSettings(Map<String, dynamic> settings) async {
    try {
      final String appDataPath = await _appDataPath;
      final File file = File(path.join(appDataPath, _settingsFileName));
      await file.writeAsString(json.encode(settings));
      return true;
    } catch (e) {
      print('Error saving settings: $e');
      return false;
    }
  }

  static Future<bool> saveData(List<String> items) async {
    try {
      final String appDataPath = await _appDataPath;
      final File file = File(path.join(appDataPath, _dataFileName));
      await file.writeAsString(json.encode({'items': items}));
      return true;
    } catch (e) {
      print('Error saving data: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    try {
      final String appDataPath = await _appDataPath;
      final File file = File(path.join(appDataPath, _settingsFileName));
      
      if (await file.exists()) {
        final String contents = await file.readAsString();
        return json.decode(contents) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
    return _getDefaultSettings();
  }

  static Future<List<String>> loadData() async {
    try {
      final String appDataPath = await _appDataPath;
      final File file = File(path.join(appDataPath, _dataFileName));
      
      if (await file.exists()) {
        final String contents = await file.readAsString();
        final data = json.decode(contents);
        return List<String>.from(data['items'] ?? []);
      }
    } catch (e) {
      print('Error loading data: $e');
    }
    return [];
  }

  static Future<void> copyRecipesXml(String sourcePath) async {
    try {
      final String appDataPath = await _appDataPath;
      final File recipesFile = File(path.join(appDataPath, _recipesFileName));
      final File sourceFile = File(sourcePath);
      
      if (await sourceFile.exists()) {
        final String xmlContent = await sourceFile.readAsString();
        await recipesFile.writeAsString(xmlContent);
        print('Recipes file copied from: ${sourceFile.path} to ${recipesFile.path}');
      } else {
        print('Source recipes file not found at: ${sourceFile.path}');
      }
    } catch (e) {
      print('Error copying recipes XML: $e');
    }
  }

  static Future<Dish?> loadRecipe(String recipeName) async {
    try {
      final String appDataPath = await _appDataPath;
      final File file = File(path.join(appDataPath, _recipesFileName));
      
      if (await file.exists()) {
        final String contents = await file.readAsString();
        print('Loading recipe for: $recipeName');
        final document = XmlDocument.parse(contents);
        
        final recipeElement = document.findAllElements('instance')
            .firstWhere(
              (element) {
                final name = element.findElements('name').first.text;
                print('Found recipe: $name');
                return name == recipeName;
              },
              orElse: () => throw Exception('Recipe not found: $recipeName'),
            );
        
        return _parseRecipeFromXml(recipeElement);
      } else {
        print('Recipe file not found at: ${file.path}');
        return null;
      }
    } catch (e) {
      print('Error loading recipe: $e');
      return null;
    }
  }

  static Dish _parseRecipeFromXml(XmlElement instance) {
    final name = instance.findElements('name').first.text;
    final note = instance.findElements('note').first.text;

    final ingredients = instance.findElements('ingredients').first
        .findElements('ingredient')
        .map((ing) => Ingredient(
              name: ing.text.trim(),
              count: ing.getAttribute('count') ?? '适量',
              unit: ing.getAttribute('unit') ?? '',
              optional: ing.getAttribute('optional') == 'true',
            ))
        .toList();

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

  static Map<String, dynamic> _getDefaultSettings() {
    return {
      'darkMode': false,
      'animationDuration': 5,
      'autoSave': true,
      'defaultLanguage': 'English',
      'proxy': {
        'enabled': false,
        'autoDetect': false,
        'type': 'HTTP',
        'host': '',
        'port': '',
        'bypassList': '',
        'requireAuth': false,
        'username': '',
        'password': '',
      },
    };
  }
}