import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';

/// 设置页面
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  static final Uri _githubUri = Uri.parse('https://github.com/ArkPLN/MiniWordCards');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 外观设置
          _buildSectionHeader('外观'),
          _buildThemeTile(context),
          const Divider(),

          // 功能设置
          _buildSectionHeader('功能'),
          _buildOnlineDictionaryTile(context),
          _buildLazyLoadOptimizationTile(context),
          const Divider(),

          // 关于
          _buildSectionHeader('关于'),
          _buildAboutTile(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildThemeTile(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final themeMode = settings.themeMode;

    String themeName;
    IconData themeIcon;
    switch (themeMode) {
      case ThemeMode.light:
        themeName = '浅色模式';
        themeIcon = Icons.light_mode;
        break;
      case ThemeMode.dark:
        themeName = '深色模式';
        themeIcon = Icons.dark_mode;
        break;
      case ThemeMode.system:
        themeName = '跟随系统';
        themeIcon = Icons.brightness_auto;
        break;
    }

    return ListTile(
      leading: Icon(themeIcon),
      title: const Text('主题模式'),
      subtitle: Text(themeName),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeDialog(context),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择主题'),
          content: Consumer<SettingsService>(
            builder: (context, settings, _) {
              return RadioGroup<ThemeMode>(
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    settings.setThemeMode(value);
                    Navigator.pop(context);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<ThemeMode>(
                      secondary: const Icon(Icons.light_mode),
                      title: const Text('浅色模式'),
                      value: ThemeMode.light,
                    ),
                    RadioListTile<ThemeMode>(
                      secondary: const Icon(Icons.dark_mode),
                      title: const Text('深色模式'),
                      value: ThemeMode.dark,
                    ),
                    RadioListTile<ThemeMode>(
                      secondary: const Icon(Icons.brightness_auto),
                      title: const Text('跟随系统'),
                      value: ThemeMode.system,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOnlineDictionaryTile(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return SwitchListTile(
      secondary: const Icon(Icons.cloud_outlined),
      title: const Text('联网字典API (还没做)'),
      subtitle: const Text('使用 Free Dictionary API 获取单词释义'),
      value: settings.useOnlineDictionary,
      onChanged: (value) {
        settings.setUseOnlineDictionary(value);
      },
    );
  }

  Widget _buildLazyLoadOptimizationTile(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return SwitchListTile(
      secondary: const Icon(Icons.speed_outlined),
      title: const Text('单词卡懒加载优化'),
      subtitle: const Text('词库较大时分批加载，降低内存占用'),
      value: settings.enableLazyLoadOptimization,
      onChanged: (value) {
        settings.setEnableLazyLoadOptimization(value);
      },
    );
  }

  Widget _buildAboutTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('关于'),
      subtitle: const Text('小小词卡 v1.0.0'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showAboutDialog(context),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '小小词卡',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.style, size: 48, color: Colors.blue),
      children: [
        const Text('一款简洁的单词卡片学习应用。(内部测试版)'),
        const SizedBox(height: 16),
        const Text('功能特点：', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('• 单词卡片学习'),
        const Text('• 在线词典查询'),
        const Text('• 深色/浅色主题'),
        const SizedBox(height: 16),
        const Text(
          '使用 Free Dictionary API 提供词典服务。',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const FaIcon(FontAwesomeIcons.github, size: 18),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _openGithub(context),
              child: const Text('GitHub 项目地址'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openGithub(BuildContext context) async {
    final success = await launchUrl(
      _githubUri,
      mode: LaunchMode.externalApplication,
    );
    if (!success && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开 GitHub 链接')));
    }
  }
}
