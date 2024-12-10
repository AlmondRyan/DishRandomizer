import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'pages/settings_page.dart';  // 确保这一行已经存在
import 'utils/settings_manager.dart';
import 'models/dish.dart';
import 'package:flutter/services.dart'; // 添加这个导入

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    home: PrizeWheel(),
    theme: ThemeData(
      primarySwatch: Colors.blue,
    ),
  ));
}

class PrizeWheel extends StatefulWidget {
  @override
  _PrizeWheelState createState() => _PrizeWheelState();
}

class _PrizeWheelState extends State<PrizeWheel> with SingleTickerProviderStateMixin {
  final List<String> _cards = [];  // 存储卡片内容
  final Random _random = Random();
  String? _selectedCard;  // 存储被选中的卡片
  late AnimationController _controller;
  late Animation<double> _animation;
  int _selectedIndex = 0;
  int _selectedCardIndex = -1;  // 选中卡片的索引，初始为-1表示未选中
  bool _isAnimating = false;  // 添加动画状态标记
  Timer? _resetTimer;        // 添加定时器
  Map<String, dynamic> _settings = {};
  Dish? _selectedDish;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refreshData(); // 加载数据
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutExpo,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reset();
        setState(() {
          _selectedCard = _cards[_selectedCardIndex];
          _isAnimating = false;
        });

        // 设置20秒后重置选中卡片的状态
        _resetTimer?.cancel();  // 取消之前的定时器
        _resetTimer = Timer(const Duration(seconds: 20), () {
          setState(() {
            _selectedCard = null;
          });
        });
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsManager.loadSettings();
      setState(() {
        _settings = settings;
        // 根据设置更新状态
        _controller.duration = Duration(seconds: _settings['animationDuration'] ?? 5);
        // 如果有导入的项目，加载它们
        if (_settings['importedItems'] != null) {
          _cards.clear(); // 清除现有项目
          _cards.addAll(List<String>.from(_settings['importedItems']['items'] ?? []));
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    try {
      // 更新设置
      _settings['importedItems'] = {
        'items': _cards,
        'lastFile': '', // 更新最后导入的文件信息
        'lastType': '', // 更新最后导入的类型
      };

      final success = await SettingsManager.saveSettings(_settings);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _refreshData() async {
    final items = await SettingsManager.loadData();
    setState(() {
      _cards.clear();
      _cards.addAll(items);
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // 添加新卡片
  void _addCard(String content) {
    if (content.isNotEmpty) {
      setState(() {
        _cards.add(content);
      });
      SettingsManager.saveData(_cards); // 保存到 data.json
    }
  }

  // 删除卡片
  void _removeCard(int index) {
    if (index >= 0 && index < _cards.length) {
      setState(() {
        _cards.removeAt(index);
      });
      SettingsManager.saveData(_cards); // 保存到 data.json
    }
  }

  // 显示没有卡片的提示对话框
  void _showNoCardsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ayy'),
          content: const Text("There's no dishes in the list!"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // 随机选择卡片（带动画）
  void _selectRandomCard() {
    if (_cards.isEmpty) {
      _showNoCardsDialog();
      return;
    }

    setState(() {
      _selectedCardIndex = _random.nextInt(_cards.length);
      _isAnimating = true;
    });
    _controller.forward(from: 0.0);
  }

  // 添加显示菜谱对话框的方法
  void _showRecipeDialog(Dish recipe) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  recipe.note,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '配料',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...recipe.ingredients.map((ing) => Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ${ing.count}${ing.unit} ${ing.name}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (ing.optional)
                                const Text(
                                  '  (可选)',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        )),
                        const SizedBox(height: 16),
                        const Text(
                          '调料',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...recipe.spices.map((spice) => Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ${spice.count ?? '适量'}${spice.unit ?? ''} ${spice.name}'
                                '${spice.note != null ? ' (${spice.note})' : ''}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (spice.optional)
                                const Text(
                                  '  (可选)',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        )),
                        const SizedBox(height: 16),
                        const Text(
                          '步骤',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...recipe.steps.expand((zone) => [
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 8),
                            child: Text(
                              zone.text,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...zone.steps.map((step) => Padding(
                            padding: const EdgeInsets.only(left: 16, bottom: 4),
                            child: Text(
                              '${step.id}. ${step.text}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          )),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 计算每个卡片的动画缩放值
  double _calculateScale(int index, double animationValue) {
    if (!_isAnimating && _selectedCard == null) {
      return 1.0;
    }

    if (!_isAnimating && _selectedCard != null && index == _selectedCardIndex) {
      return 1.005;
    }

    if (_isAnimating) {
      double cycleCount = 15;
      double currentCycle = animationValue * cycleCount;
      int currentIndex;

      if (animationValue > 0.8) {
        currentIndex = _selectedCardIndex;
      } else {
        currentIndex = (currentCycle % _cards.length).floor();
      }

      if (index == currentIndex) {
        double scaleAmount = 0.3 * (1 - animationValue);
        return 1.0 + scaleAmount;
      }

      return 0.95;
    }

    return 1.0;
  }

  // 计算卡片阴影值
  double _calculateElevation(int index, double animationValue) {
    if (!_isAnimating && _selectedCard != null && index == _selectedCardIndex) {
      return 4;
    }

    if (_isAnimating) {
      double cycleCount = 15;
      double currentCycle = animationValue * cycleCount;
      int currentIndex;

      if (animationValue > 0.8) {
        currentIndex = _selectedCardIndex;
      } else {
        currentIndex = (currentCycle % _cards.length).floor();
      }

      return index == currentIndex ? 8 : 1;
    }

    return 1;
  }

  // 添加键盘事件处理
  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f5) {
        _refreshData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKey: _handleKeyEvent,
      child: Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                if (index != _selectedIndex) {
                  setState(() {
                    _selectedIndex = index;
                  });
                }
              },
              labelType: NavigationRailLabelType.selected,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: _selectedIndex == 0
                  ? _buildMainContent()
                  : SettingsPage(
                      settings: _settings,
                      onSettingsChanged: (newSettings) {
                        setState(() {
                          _settings = newSettings;
                          _controller.duration = Duration(
                            seconds: _settings['animationDuration'] ?? 5,
                          );
                        });
                        _saveSettings();
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        AppBar(
          title: const Text('Dish Randomizer'),
          actions: [
            Tooltip(
              message: 'Refresh (F5)',
              child: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshData,
              ),
            ),
          ],
        ),
        // 将原来 Scaffold body 中的内容移到这里
        Expanded(
          child: Column(
            children: [
              // 添加卡片的输入区域
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'I would like...',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: _addCard,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _selectRandomCard,
                      child: const Text('Randomly Choose!'),
                    ),
                  ],
                ),
              ),

              // 显示选中的卡片
              if (_selectedCard != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: Colors.yellow[100],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '选中的菜品: $_selectedCard',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  try {
                                    final recipe = await SettingsManager.loadRecipe(_selectedCard!);
                                    if (recipe != null) {
                                      setState(() {
                                        _selectedDish = recipe;
                                      });
                                      _showRecipeDialog(recipe);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Recipe not found'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error loading recipe: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.menu_book),
                                label: const Text('Show Recipe'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 显示所有卡片（带动画）
              Expanded(
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return ListView.builder(
                      itemCount: _cards.length,
                      itemBuilder: (context, index) {
                        return TweenAnimationBuilder(
                          duration: const Duration(milliseconds: 200),
                          tween: Tween<double>(
                            begin: 1.0,
                            end: _calculateScale(index, _animation.value),
                          ),
                          builder: (context, double scale, child) {
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                  horizontal: 8.0,
                                ),
                                child: Card(
                                  // 使用新的阴影计算方法
                                  elevation: _calculateElevation(index, _animation.value),
                                  child: ListTile(
                                    title: Text(_cards[index]),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _removeCard(index),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
