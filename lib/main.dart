import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const CountryApp());
}

class CountryApp extends StatelessWidget {
  const CountryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Country Information App',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const CountryHome(),
    );
  }
}

class CountryHome extends StatefulWidget {
  const CountryHome({super.key});

  @override
  State<CountryHome> createState() => _CountryHomeState();
}

class _CountryHomeState extends State<CountryHome> {
  List countries = [];
  bool loading = true;
  String error = '';
  String search = '';
  String region = 'All';
  bool ascending = true;

  @override
  void initState() {
    super.initState();
    fetchCountries();
  }

  String countryName(dynamic country) {
    return country['names']?['common']?.toString() ?? 'Unknown';
  }

  String countryCapital(dynamic country) {
    final capitals = country['capitals'];
    if (capitals is List && capitals.isNotEmpty) {
      return capitals.map((c) {
        if (c is Map) return c['name'] ?? '';
        return c.toString();
      }).where((c) => c.toString().isNotEmpty).join(', ');
    }
    return 'N/A';
  }

  String countryFlag(dynamic country) {
    return country['flag']?['emoji']?.toString() ?? '🏳️';
  }

  
Future<void> fetchCountries() async {
  setState(() {
    loading = true;
    error = '';
  });

  try {
    final List allCountries = [];
    const int limit = 100;
    int offset = 0;
    bool more = true;

    while (more) {
      final response = await http.get(
        Uri.parse(
          'https://api.restcountries.com/countries/v5?limit=$limit&offset=$offset',
        ),
        headers: {
          'Authorization': 'Bearer rc_live_cf1bf568f12f426bac74df2f6875aaa2',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception(
          'API Error ${response.statusCode}: ${response.body}',
        );
      }

      final decoded =
          jsonDecode(response.body) as Map<String, dynamic>;
      final responseData =
          decoded['data'] as Map<String, dynamic>;
      final List page = responseData['objects'] as List;
      final meta = responseData['meta'] as Map<String, dynamic>;

      allCountries.addAll(page);

      more = meta['more'] == true;
      offset += page.length;

      if (page.isEmpty) {
        more = false;
      }
    }

    allCountries.sort((a, b) =>
        countryName(a).compareTo(countryName(b)));

    if (!mounted) return;

    setState(() {
      countries = allCountries;
      loading = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      loading = false;
      error = 'Could not load countries.\n$e';
    });
  }
}


  List get filteredCountries {
    final result = countries.where((country) {
      final name = countryName(country).toLowerCase();
      final official =
          (country['names']?['official'] ?? '').toString().toLowerCase();
      final capital = countryCapital(country).toLowerCase();
      final selectedRegion =
          (country['region'] ?? '').toString();

      final query = search.toLowerCase().trim();

      final matchesSearch = name.contains(query) ||
          official.contains(query) ||
          capital.contains(query);

      final matchesRegion =
          region == 'All' || selectedRegion == region;

      return matchesSearch && matchesRegion;
    }).toList();

    result.sort((a, b) {
      final comparison =
          countryName(a).compareTo(countryName(b));
      return ascending ? comparison : -comparison;
    });

    return result;
  }

  String currencyNames(dynamic country) {
    final currencies = country['currencies'];

    if (currencies is Map) {
      return currencies.values.map((currency) {
        if (currency is Map) {
          return currency['name']?.toString() ?? '';
        }
        return '';
      }).where((name) => name.isNotEmpty).join(', ');
    }

    return 'N/A';
  }

  void showCountryDetails(dynamic country) {
    final name = countryName(country);
    final official =
        country['names']?['official'] ?? 'N/A';
    final capital = countryCapital(country);
    final population = country['population'] ?? 'N/A';
    final countryRegion = country['region'] ?? 'N/A';
    final currency = currencyNames(country);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$name ${countryFlag(country)}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Official Name: $official'),
              const SizedBox(height: 8),
              Text('Capital: $capital'),
              const SizedBox(height: 8),
              Text('Region: $countryRegion'),
              const SizedBox(height: 8),
              Text(
                'Population: ${population is num ? population.toString() : population}',
              ),
              const SizedBox(height: 8),
              Text('Currency: ${currency.isEmpty ? 'N/A' : currency}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Country Information'),
        actions: [
          IconButton(
            tooltip: 'Sort countries',
            icon: const Icon(Icons.sort_by_alpha),
            onPressed: () => setState(() {
              ascending = !ascending;
            }),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: fetchCountries,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) {
                setState(() => search = value);
              },
              decoration: InputDecoration(
                hintText: 'Search countries...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonFormField<String>(
              value: region,
              decoration: InputDecoration(
                labelText: 'Select Region',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: [
                'All',
                'Africa',
                'Americas',
                'Asia',
                'Europe',
                'Oceania',
              ].map((r) {
                return DropdownMenuItem(
                  value: r,
                  child: Text(r),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => region = value ?? 'All');
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : error.isNotEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                error,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: fetchCountries,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filteredCountries.isEmpty
                        ? const Center(
                            child: Text('No countries found'),
                          )
                        : ListView.builder(
                            itemCount: filteredCountries.length,
                            itemBuilder: (context, index) {
                              final country =
                                  filteredCountries[index];
                              final name = countryName(country);
                              final flag = countryFlag(country);
                              final capital =
                                  countryCapital(country);

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                child: ListTile(
                                  leading: SizedBox(
                                    width: 55,
                                    child: Center(
                                      child: Text(
                                        flag,
                                        style: const TextStyle(
                                          fontSize: 30,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(name),
                                  subtitle: Text(
                                    'Capital: $capital\n'
                                    'Region: ${country['region'] ?? 'N/A'}',
                                  ),
                                  isThreeLine: true,
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                  ),
                                  onTap: () =>
                                      showCountryDetails(country),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
