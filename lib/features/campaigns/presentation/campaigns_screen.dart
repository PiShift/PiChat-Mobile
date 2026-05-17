import 'package:flutter/material.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_theme.dart';

class CampaignsManagementScreen extends StatelessWidget {
  const CampaignsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: PiColors.of(context).background,
      appBar: AppBar(
        backgroundColor: PiColors.of(context).background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Campaigns',
          style: TextStyle(
            fontSize: size.width * 0.045,
            fontWeight: FontWeight.bold,
            color: PiColors.of(context).textPrimary,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, size: size.width * 0.15, color: PiColors.of(context).ink400),
            SizedBox(height: size.height * 0.02),
            Text(
              'Campaigns',
              style: TextStyle(fontSize: size.width * 0.045, fontWeight: FontWeight.bold, color: PiColors.of(context).textPrimary),
            ),
            SizedBox(height: size.height * 0.008),
            Text(
              'Manage and schedule your WhatsApp campaigns here.',
              style: TextStyle(fontSize: size.width * 0.033, color: PiColors.of(context).textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
