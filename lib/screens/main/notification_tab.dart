import 'package:flutter/material.dart';

class NotificationTab extends StatelessWidget {
	const NotificationTab({super.key});

	@override
	Widget build(BuildContext context) {
		final isDark = Theme.of(context).brightness == Brightness.dark;
		final bg = isDark ? const Color(0xFF111111) : const Color(0xFFF4F4F4);
		final titleColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
		final notifications = <_NotificationItem>[
			const _NotificationItem(
				title: 'Security Alert',
				subtitle: 'Unusual activity detected near your device',
				time: '2 min ago',
				icon: Icons.error_outline,
				iconColor: Color(0xFFFF4D3D),
				showUnreadDot: true,
				accentColor: Color(0xFFFF7A1A),
			),
			const _NotificationItem(
				title: 'Route Completed',
				subtitle: 'You\'ve reached your destination: Office',
				time: '45 min ago',
				icon: Icons.location_on_outlined,
				iconColor: Color(0xFFFF8A2A),
				showUnreadDot: true,
				accentColor: Color(0xFFFF7A1A),
			),
			const _NotificationItem(
				title: 'Sync Complete',
				subtitle: 'All route data has been synced to cloud',
				time: '2 hours ago',
				icon: Icons.check_circle_outline,
				iconColor: Color(0xFF31D158),
			),
			const _NotificationItem(
				title: 'Battery Low',
				subtitle: 'Device battery is at 20%. Please charge soon.',
				time: '3 hours ago',
				icon: Icons.info_outline,
				iconColor: Color(0xFF2F8CFF),
			),
			const _NotificationItem(
				title: 'New Route Recorded',
				subtitle: 'A new 12.5 km route has been saved',
				time: 'Yesterday',
				icon: Icons.location_on_outlined,
				iconColor: Color(0xFFFF8A2A),
			),
		];

		return Scaffold(
			backgroundColor: bg,
			body: SafeArea(
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Padding(
							padding: EdgeInsets.fromLTRB(20, 16, 20, 18),
							child: Text(
								'Notifications',
								style: TextStyle(
									color: titleColor,
									fontSize: 28,
									fontWeight: FontWeight.w500,
								),
							),
						),
						Expanded(
							child: ListView.separated(
								padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
								itemCount: notifications.length,
								separatorBuilder: (context, index) => const SizedBox(height: 16),
								itemBuilder: (context, index) {
									final item = notifications[index];
									return _NotificationCard(item: item);
								},
							),
						),
					],
				),
			),
		);
	}
}

class _NotificationItem {
	const _NotificationItem({
		required this.title,
		required this.subtitle,
		required this.time,
		required this.icon,
		required this.iconColor,
		this.showUnreadDot = false,
		this.accentColor,
	});

	final String title;
	final String subtitle;
	final String time;
	final IconData icon;
	final Color iconColor;
	final bool showUnreadDot;
	final Color? accentColor;
}

class _NotificationCard extends StatelessWidget {
	const _NotificationCard({required this.item});

	final _NotificationItem item;

	@override
	Widget build(BuildContext context) {
		final isDark = Theme.of(context).brightness == Brightness.dark;
		final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
		final border = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE3E3E3);
		final primaryText = isDark ? Colors.white : const Color(0xFF1A1A1A);
		final secondaryText = isDark ? const Color(0xFF8E8E8E) : const Color(0xFF666666);

		return Container(
			decoration: BoxDecoration(
				color: cardBg,
				borderRadius: BorderRadius.circular(22),
				border: Border.all(color: border),
			),
			child: Stack(
				children: [
					if (item.accentColor != null)
						Positioned(
							left: 0,
							top: 0,
							bottom: 0,
							child: Container(
								width: 6,
								decoration: BoxDecoration(
									color: item.accentColor,
									borderRadius: const BorderRadius.only(
										topLeft: Radius.circular(22),
										bottomLeft: Radius.circular(22),
									),
								),
							),
						),
					Padding(
						padding: EdgeInsets.fromLTRB(item.accentColor != null ? 18 : 18, 18, 18, 18),
						child: Row(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Container(
									width: 48,
									height: 48,
									decoration: BoxDecoration(
										shape: BoxShape.circle,
										color: const Color(0xFF262626),
									),
									child: Icon(
										item.icon,
										color: item.iconColor,
										size: 28,
									),
								),
								const SizedBox(width: 14),
								Expanded(
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(
												item.title,
												style: TextStyle(
													color: primaryText,
													fontSize: 20,
													fontWeight: FontWeight.w700,
												),
											),
											const SizedBox(height: 6),
											Text(
												item.subtitle,
												style: TextStyle(
													color: secondaryText,
													fontSize: 16,
													height: 1.2,
												),
											),
											const SizedBox(height: 10),
											Text(
												item.time,
												style: TextStyle(
													color: secondaryText,
													fontSize: 14,
												),
											),
										],
									),
								),
								if (item.showUnreadDot)
									const Padding(
										padding: EdgeInsets.only(left: 8, top: 4),
										child: Icon(
											Icons.brightness_1,
											size: 12,
											color: Color(0xFFFF8A2A),
										),
									),
							],
						),
					),
				],
			),
		);
	}
}
