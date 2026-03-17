import 'package:flutter/material.dart';

class PasswordDialog extends StatefulWidget {
  final String title;
  final String? defaultKey;
  final String defaultKeyLabel;

  const PasswordDialog({
    super.key,
    this.title = '安全验证',
    this.defaultKey = 'ChaosCryptDefaultKey123',
    this.defaultKeyLabel = '使用全局默认密码',
  });

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _controller = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock_outline, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(widget.title),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            obscureText: _obscureText,
            decoration: InputDecoration(
              hintText: '输入加密/解密密码',
              labelText: '密码',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '请妥善保管密码，丢失后无法通过算法恢复数据。',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        if (widget.defaultKey != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context, widget.defaultKey);
            },
            child: Text(widget.defaultKeyLabel),
          ),
        ElevatedButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              Navigator.pop(context, _controller.text);
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
