import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/network_discovery_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _ipController;
  late NetworkDiscoveryProvider _networkProvider;

  @override
  void initState() {
    super.initState();
    _networkProvider = Provider.of<NetworkDiscoveryProvider>(context, listen: false);
    _ipController = TextEditingController(text: _networkProvider.manualIpAddress);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _showConnectionResultSnackBar(bool success, NetworkDiscoveryProvider networkProvider, {String? customMessage}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    String message;
    if (customMessage != null) {
      message = customMessage;
    } else if (success) {
      message = '✅ Server terhubung: ${networkProvider.serverAddress}';
    } else {
      if (networkProvider.state == DiscoveryState.invalidFormat) {
        message = '❌ Gagal terhubung: Format IP/URL tidak valid.';
      } else if (networkProvider.connectionMode == ConnectionMode.manual && (networkProvider.manualIpAddress == null || networkProvider.manualIpAddress!.isEmpty)) {
        message = '❌ Gagal terhubung: IP manual belum disetel.';
      } else if (networkProvider.state == DiscoveryState.notFound) {
        message = '❌ Gagal terhubung: Server tidak ditemukan.';
      } else {
        message = '❌ Terjadi error saat mencoba koneksi. Periksa izin atau server.';
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark ||
        (themeProvider.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: Consumer<NetworkDiscoveryProvider>(
        builder: (context, networkProvider, child) {
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Mode Gelap'),
                secondary: Icon(isDarkMode ? Icons.nightlight_round : Icons.wb_sunny),
                value: isDarkMode,
                onChanged: (value) {
                  Provider.of<ThemeProvider>(context, listen: false).toggleTheme(value);
                },
              ),
              const Divider(),
              ListTile(
                title: const Text('Pengaturan Server AI'),
                subtitle: Text(
                  networkProvider.connectionMode == ConnectionMode.auto
                      ? 'Deteksi otomatis (Zeroconf)'
                      : 'Manual (IP: ${networkProvider.manualIpAddress ?? 'Belum disetel'})',
                ),
              ),
              SwitchListTile(
                title: const Text('Deteksi Server Otomatis'),
                subtitle: const Text('Gunakan deteksi jaringan lokal (Zeroconf)'),
                value: networkProvider.connectionMode == ConnectionMode.auto,
                onChanged: (value) {
                  networkProvider.setConnectionMode(value ? ConnectionMode.auto : ConnectionMode.manual);
                },
              ),
              if (networkProvider.connectionMode == ConnectionMode.manual)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: TextField(
                    controller: _ipController,
                    decoration: InputDecoration(
                      labelText: 'Alamat IP Server Manual (contoh: http://192.168.1.7:5000)',
                      hintText: 'Misal: http://192.168.1.7:5000',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _ipController.clear();
                          networkProvider.setManualIpAddress('');
                        },
                      ),
                    ),
                    keyboardType: TextInputType.url,
                    onChanged: (text) {
                      networkProvider.setManualIpAddress(text);
                    },
                    onSubmitted: (text) async {
                      _showConnectionResultSnackBar(false, networkProvider, customMessage: 'Memverifikasi IP manual...');
                      bool success = await networkProvider.discoverService();
                      _showConnectionResultSnackBar(success, networkProvider);
                    },
                  ),
                ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: () async {
                    _showConnectionResultSnackBar(false, networkProvider, customMessage: 'Mencoba menyambungkan kembali server...');
                    bool success = await networkProvider.discoverService();
                    _showConnectionResultSnackBar(success, networkProvider);
                  },
                  child: const Text('Coba Sambungkan Kembali Server'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}