import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/github_auth.dart';
import '../platform/device.dart';

class GitHubSignInDialog extends StatefulWidget {
  const GitHubSignInDialog({
    super.key,
    required this.auth,
    required this.device,
  });
  final GitHubAuth auth;
  final Device device;

  @override
  State<GitHubSignInDialog> createState() => _GitHubSignInDialogState();
}

class _GitHubSignInDialogState extends State<GitHubSignInDialog> {
  GitHubDeviceCode? code;
  String? error;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  Future<void> _begin() async {
    final current = ++generation;
    setState(() {
      code = null;
      error = null;
    });
    try {
      final pending = await widget.auth.start();
      if (!mounted || current != generation) return;
      setState(() => code = pending);
      final credentials = await widget.auth.poll(
        pending,
        cancelled: () => !mounted || current != generation,
      );
      if (mounted && current == generation && credentials != null) {
        Navigator.pop(context, credentials);
      }
    } catch (e) {
      if (mounted && current == generation) {
        setState(() => error = e.toString());
      }
    }
  }

  Future<void> _open() async {
    final pending = code;
    if (pending == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: pending.userCode));
      await widget.device.open(pending.verificationUrl);
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              'Could not open GitHub. Copy the code and visit github.com/login/device.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sign in to GitHub'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (code == null && error == null) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Requesting a sign-in code…'),
          ],
          if (code != null) ...[
            const Text(
              'Enter this code on GitHub. It has been copied when you open the link.',
            ),
            const SizedBox(height: 16),
            SelectableText(
              code!.userCode,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            const Text(
              'Core will continue automatically after you approve access.',
            ),
          ],
          if (error != null) ...[
            if (code != null) const SizedBox(height: 12),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      if (error != null)
        TextButton(onPressed: _begin, child: const Text('Try again')),
      if (code != null)
        FilledButton(
          onPressed: _open,
          child: const Text('Copy code and open GitHub'),
        ),
    ],
  );
}
