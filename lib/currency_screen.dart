import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  List<dynamic> _currencies = [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _lastUpdateTime;
  
  // Согласно документации Monobank API:
  // Курсы обновляются не чаще 1 раза в 5 минут
  static const int _minUpdateIntervalSeconds = 300; // 5 минут

  @override
  void initState() {
    super.initState();
    _fetchCurrencyRates();
  }

  bool _canUpdate() {
    if (_lastUpdateTime == null) return true;
    
    final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
    return timeSinceLastUpdate.inSeconds >= _minUpdateIntervalSeconds;
  }

  int _getSecondsUntilNextUpdate() {
    if (_lastUpdateTime == null) return 0;
    
    final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
    final remainingSeconds = _minUpdateIntervalSeconds - timeSinceLastUpdate.inSeconds;
    return remainingSeconds > 0 ? remainingSeconds : 0;
  }

  Future<void> _fetchCurrencyRates() async {
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.monobank.ua/bank/currency'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _currencies = data;
          _isLoading = false;
          _lastUpdateTime = DateTime.now();
        });
      } else if (response.statusCode == 429) {
        setState(() {
          _errorMessage = 'Слишком много запросов (429). Повторите позже.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Ошибка: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка подключения: $e';
        _isLoading = false;
      });
    }
  }

  String _getCurrencyName(int code) {
    final Map<int, String> currencies = {
      840: 'USD',
      978: 'EUR',
      980: 'UAH',
      826: 'GBP',
      392: 'JPY',
      756: 'CHF',
      985: 'PLN',
    };
    return currencies[code] ?? code.toString();
  }

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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Курсы валют Monobank'),
            if (_lastUpdateTime != null)
              Text(
                _getLastUpdateText(),
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCurrencyRates,
            tooltip: 'Обновить (не чаще 1 раза в 5 мин)',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
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
              : RefreshIndicator(
                  onRefresh: _fetchCurrencyRates,
                  child: ListView.builder(
                    itemCount: _currencies.length,
                    itemBuilder: (context, index) {
                      final currency = _currencies[index];
                      final currencyA = _getCurrencyName(currency['currencyCodeA']);
                      final currencyB = _getCurrencyName(currency['currencyCodeB']);
                      
                      final rateBuy = currency['rateBuy'];
                      final rateSell = currency['rateSell'];
                      final rateCross = currency['rateCross'];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              currencyA.substring(0, 1),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            '$currencyA → $currencyB',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
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
