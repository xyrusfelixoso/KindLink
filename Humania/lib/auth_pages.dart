part of 'main.dart';

class RolePage extends StatelessWidget {
  const RolePage({
    super.key,
    required this.onRoleSelected,
    this.showAdmin = false,
  });
  final ValueChanged<String> onRoleSelected;
  final bool showAdmin;

  @override
  Widget build(BuildContext context) {
    const green = kindLinkEmerald;
    return Scaffold(
      backgroundColor: kindLinkNavy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/kindlink-community-hero.png',
            key: const Key('role-background-image'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x24000000),
                  Color(0x52000000),
                  Color(0xD9000000),
                ],
                stops: [0, 0.42, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 52,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          decoration: BoxDecoration(
                            color: kindLinkNavy.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Connecting kindness with those who need it.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  height: 1.15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Choose how you would like to join the community.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.84),
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _RoleButton(
                                label: 'I WANT TO DONATE',
                                icon: Icons.volunteer_activism_outlined,
                                color: green,
                                onPressed: () => onRoleSelected('Donor'),
                              ),
                              _RoleButton(
                                label: 'I NEED HELP!',
                                icon: Icons.pan_tool_alt_outlined,
                                color: green,
                                onPressed: () => onRoleSelected('Recipient'),
                              ),
                              _RoleButton(
                                label: 'I AM AN ORGANIZATION',
                                icon: Icons.apartment_outlined,
                                color: green,
                                onPressed: () => onRoleSelected('Organization'),
                              ),
                              if (showAdmin)
                                _RoleButton(
                                  label: 'ADMIN VERIFICATION',
                                  icon: Icons.admin_panel_settings_outlined,
                                  color: green,
                                  onPressed: () => onRoleSelected('Admin'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          minimumSize: const Size.fromHeight(62),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
