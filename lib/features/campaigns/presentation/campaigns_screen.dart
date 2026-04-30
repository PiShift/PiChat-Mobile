import 'package:flutter/material.dart';
import 'package:pichat/core/theme/app_theme.dart';

class CampaignsManagementScreen extends StatelessWidget {
  const CampaignsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Campaigns',
          style: TextStyle(
            fontSize: size.width * 0.045,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined, size: size.width * 0.15, color: Colors.grey[300]),
            SizedBox(height: size.height * 0.02),
            Text(
              'Campaigns',
              style: TextStyle(fontSize: size.width * 0.045, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            SizedBox(height: size.height * 0.008),
            Text(
              'Manage and schedule your WhatsApp campaigns here.',
              style: TextStyle(fontSize: size.width * 0.033, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
