import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Экран отображения курсов валют от Monobank
/// 
/// Получает актуальные курсы валют через публичный API Monobank
/// и отображает их в виде списка с возможностью обновления
class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  // Список валютных пар, полученных от API
  List<dynamic> _currencies = [];
  
  // Флаг состояния загрузки данных
  bool _isLoading = true;
  
  // Сообщение об ошибке (если есть)
  String? _errorMessage;
  
  // Время последнего обновления данных
  DateTime? _lastUpdateTime;
  
  // Согласно документации Monobank API:
  // Курсы обновляются не чаще 1 раза в 5 минут
  static const int _minUpdateIntervalSeconds = 300; // 5 минут

  @override
  void initState() {
    super.initState();
    // Загружаем курсы валют при инициализации экрана
    _fetchCurrencyRates();
  }

  /// Проверяет, можно ли выполнить обновление данных
  /// 
  /// Возвращает true, если прошло более 5 минут с последнего обновления
  /// или если данные еще ни разу не загружались
  bool _canUpdate() {
    if (_lastUpdateTime == null) return true;
    
    final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
    return timeSinceLastUpdate.inSeconds >= _minUpdateIntervalSeconds;
  }

  /// Вычисляет количество секунд до следующего возможного обновления
  /// 
  /// Возвращает 0, если обновление уже можно выполнить
  int _getSecondsUntilNextUpdate() {
    if (_lastUpdateTime == null) return 0;
    
    final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
    final remainingSeconds = _minUpdateIntervalSeconds - timeSinceLastUpdate.inSeconds;
    return remainingSeconds > 0 ? remainingSeconds : 0;
  }

  /// Загружает курсы валют от Monobank API
  /// 
  /// Проверяет лимиты на частоту запросов (не чаще 1 раза в 5 минут).
  /// Обрабатывает различные коды ответов и возможные ошибки сети.
  Future<void> _fetchCurrencyRates() async {
    // Проверяем, не слишком ли рано делать запрос
    if (!_canUpdate()) {
      final secondsRemaining = _getSecondsUntilNextUpdate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Данные обновляются не чаще 1 раза в 5 минут. '
              'Следующее обновление через $secondsRemaining сек.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Устанавливаем состояние загрузки
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Выполняем GET запрос к публичному API Monobank
      final response = await http.get(
        Uri.parse('https://api.monobank.ua/bank/currency'),
      );

      if (response.statusCode == 200) {
        // Успешный ответ - декодируем JSON и сохраняем данные
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _currencies = data;
          _isLoading = false;
          _lastUpdateTime = DateTime.now();
        });
      } else if (response.statusCode == 429) {
        // Ошибка 429 - превышен лимит запросов
        setState(() {
          _errorMessage = 'Слишком много запросов (429). Повторите позже.';
          _isLoading = false;
        });
      } else {
        // Другие ошибки HTTP
        setState(() {
          _errorMessage = 'Ошибка: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      // Ошибка сети или другая непредвиденная ошибка
      setState(() {
        _errorMessage = 'Ошибка подключения: $e';
        _isLoading = false;
      });
    }
  }

  /// Преобразует код валюты ISO 4217 в буквенное обозначение
  /// 
  /// Для основных валют возвращает привычные аббревиатуры (USD, EUR и т.д.),
  /// для остальных возвращает числовой код в виде строки
  String _getCurrencyName(int code) {
    final Map<int, String> currencies = {
      840: 'USD', // Доллар США
      978: 'EUR', // Евро
      980: 'UAH', // Гривна
      826: 'GBP', // Фунт стерлингов
      392: 'JPY', // Йена
      756: 'CHF', // Швейцарский франк
      985: 'PLN', // Польский злотый
    };
    return currencies[code] ?? code.toString();
  }

  /// Формирует текст о времени последнего обновления данных
  /// 
  /// Возвращает человекочитаемую строку типа "Обновлено 5 мин назад"
  String _getLastUpdateText() {
    if (_lastUpdateTime == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(_lastUpdateTime!);
    
    if (difference.inMinutes < 1) {
      return 'Обновлено только что';
    } else if (difference.inMinutes < 60) {
      return 'Обновлено ${difference.inMinutes} мин назад';
    } else {
      return 'Обновлено ${difference.inHours} ч назад';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Шапка приложения с заголовком и кнопкой обновления
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Курсы валют Monobank'),
            // Показываем время последнего обновления, если оно есть
            if (_lastUpdateTime != null)
              Text(
                _getLastUpdateText(),
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Кнопка для ручного обновления курсов
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCurrencyRates,
            tooltip: 'Обновить (не чаще 1 раза в 5 мин)',
          ),
        ],
      ),
      // Основное содержимое экрана с тремя возможными состояниями
      body: _isLoading
          // Состояние 1: Загрузка данных - показываем индикатор прогресса
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              // Состояние 2: Ошибка - показываем сообщение об ошибке и кнопку повтора
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchCurrencyRates,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              // Состояние 3: Данные загружены - показываем список валют
              : RefreshIndicator(
                  // Pull-to-refresh для обновления данных свайпом вниз
                  onRefresh: _fetchCurrencyRates,
                  child: ListView.builder(
                    itemCount: _currencies.length,
                    itemBuilder: (context, index) {
                      // Получаем данные о валютной паре
                      final currency = _currencies[index];
                      final currencyA = _getCurrencyName(currency['currencyCodeA']);
                      final currencyB = _getCurrencyName(currency['currencyCodeB']);
                      
                      // Курсы обмена (могут быть null для кросс-курсов)
                      final rateBuy = currency['rateBuy'];
                      final rateSell = currency['rateSell'];
                      final rateCross = currency['rateCross'];

                      // Отображаем карточку с информацией о валютной паре
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          // Аватар с первой буквой валюты
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              currencyA.substring(0, 1),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          // Название валютной пары
                          title: Text(
                            '$currencyA → $currencyB',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          // Отображаем либо кросс-курс, либо курсы покупки/продажи
                          subtitle: rateCross != null
                              ? Text('Кросс-курс: ${rateCross.toStringAsFixed(4)}')
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (rateBuy != null)
                                      Text('Покупка: ${rateBuy.toStringAsFixed(2)}'),
                                    if (rateSell != null)
                                      Text('Продажа: ${rateSell.toStringAsFixed(2)}'),
                                  ],
                                ),
                          // Иконка обмена валют
                          trailing: Icon(
                            Icons.currency_exchange,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
