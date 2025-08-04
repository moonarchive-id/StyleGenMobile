import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/network_discovery_provider.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkDiscoveryProvider>(
      builder: (context, networkProvider, child) {
        IconData icon;
        Color color;
        String message;

        switch (networkProvider.state) {
          case DiscoveryState.found:
            icon = Icons.check_circle;
            color = Colors.green.shade700;
            message = 'Terhubung ke ${networkProvider.serverAddress}';
            break;
          case DiscoveryState.searching:
            icon = Icons.sync;
            color = Colors.blue.shade700;
            message = 'Mencari server di jaringan lokal...';
            break;
          case DiscoveryState.notFound:
            icon = Icons.error;
            color = Colors.red.shade700;
            message = 'Server tidak ditemukan. Coba mode manual.';
            break;
          case DiscoveryState.invalidFormat:
            icon = Icons.warning;
            color = Colors.orange.shade800;
            message = 'Format IP manual tidak valid. Periksa Pengaturan.';
            break;
          case DiscoveryState.error:
            icon = Icons.cloud_off;
            color = Colors.red.shade700;
            message = 'Gagal terhubung. Periksa firewall atau server.';
            break;
          case DiscoveryState.idle:
          default:
            icon = Icons.help_outline;
            color = Colors.grey.shade700;
            message = 'Status koneksi tidak diketahui.';
        }

        return Card(
          color: color.withOpacity(0.1),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: color.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: color, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}